test_that("deterministic deductions are retained when no model is needed", {
  skip_if_not_installed("mice")
  inputs <- data.frame(age = 40, smoking_status = "current",
                       current_inhaled_nds = NA, secondhand_smoke_home = FALSE)
  scores <- suppressMessages(suppressWarnings(score_le8(
    inputs, min_components = 1, impute = le8_imputation_control(m = 2)
  )))
  expect_identical(scores$current_inhaled_nds, c(FALSE, FALSE))
  expect_equal(scores$nicotine_score, c(0, 0))
})

test_that("imputation handles sparse tobacco inputs and resolved MEPA names", {
  sparse <- le8_imputation_setup(data.frame(age = 40:42, years_since_quit = c(1, 2, NA)))
  expect_false(any(sparse$where[, "years_since_quit"]))
  data <- read.csv(system.file("extdata", "le8-adult-example.csv", package = "essential8"))
  data <- data[!startsWith(names(data), "expected_")]
  names(data)[names(data) == "fish"] <- "Fish"
  data$female <- as.character(data$sex) %in% c("f", "female")
  data$sex <- NULL
  data$Fish[1] <- NA
  data$female[2] <- NA
  setup <- le8_imputation_setup(data)
  expect_identical(setup$method[["Fish"]], "pmm")
  expect_identical(setup$method[["female"]], "logreg")
  expect_true(setup$where[1, "Fish"])
  expect_true(setup$where[2, "female"])
  skip_if_not_installed("mice")
  scored <- suppressWarnings(score_le8(data, impute = le8_imputation_control(m = 2, maxit = 1, seed = 2)))
  expect_false(anyNA(scored$Fish))
  expect_type(scored$female, "logical")
  expect_false(anyNA(scored$female))
  expect_false(anyNA(scored$diet_score))
})

test_that("pooled scores validate flags and align participant IDs irrespective of order", {
  d <- data.frame(age = 40, .imp = c(1, 1, 2, 2), .id = c("a", "b", "b", "a"),
                  sleep_hours = c(4, 4, 8, 8), current_inhaled_nds = "FALSE")
  scored <- suppressWarnings(score_le8_imputed(d, min_components = 1))
  expect_identical(scored$current_inhaled_nds, rep(FALSE, 4))
  pooled <- expect_no_warning(summary(scored))
  row <- pooled$statistics[pooled$statistics$measure == "sleep", ]
  expect_equal(row$mean, 60)
  expect_equal(row$std.error, sqrt(4800))
  expect_identical(row$fmi, 1)
  expect_identical(row$conf.low, NA_real_)
  expect_identical(row$conf.high, NA_real_)
  for (last in c("b", "new", NA_character_)) {
    bad <- d
    bad$.id[4] <- last
    expect_error(score_le8_imputed(bad), class = "essential8_imputation_error")
  }
  d$current_inhaled_nds[3] <- "Yes"
  expect_error(score_le8_imputed(d), "Yes", class = "essential8_input_error")
})

test_that("blood-pressure donor masks and replacements respect reference ordering", {
  skip_if_not_installed("mice")
  d <- data.frame(age = rep(8, 10), systolic_bp_p90 = c(100:108, 125),
                  systolic_bp_p95 = c(110:118, NA))
  expect_warning(setup <- le8_imputation_setup(d), class = "essential8_imputation_warning")
  expect_false(setup$where[10, "systolic_bp_p95"])
  scores <- suppressMessages(suppressWarnings(score_le8(d, impute = le8_imputation_control(m = 2))))
  expect_true(all(is.na(scores$systolic_bp_p95[scores$.id == 10])))
  for (kind in c("systolic", "diastolic")) {
    pair <- paste0(kind, "_bp_p", c(90, 95))
    data <- setNames(data.frame(c(95, 115, NA, 115), c(100, 120, 100, NA)), pair)
    r <- !is.na(data)
    expect_equal(.le8_post_bp(pair[1], 115, 3, data, r), 95)
    expect_equal(.le8_post_bp(pair[2], 100, 4, data, r), 120)
  }
})

test_that("glucose measure fallback uses donors with matching diabetes status", {
  data <- data.frame(diabetes = c(FALSE, TRUE, FALSE),
                     glucose_measure = c("fasting_glucose", "hba1c", NA),
                     glucose_value = c(90, 8, NA))
  r <- !is.na(data)
  expect_equal(.le8_post_impute("glucose_measure", "hba1c", data, r, !r), "fasting_glucose")
})

test_that("default reference age falls back per row and low infant percentiles score", {
  skip_if_not_installed("cdcanthro")
  skip_if_not_installed("pedbp")
  data <- data.frame(age = c(5, 5/12), age_months = c(NA, 5), height_cm = c(110, 64),
                     weight_kg = c(19, 5.25), sex = c("f", "m"))
  ref <- add_pediatric_references(data)
  by_year <- add_pediatric_references(data[1, names(data) != "age_months"])
  expect_equal(ref$bmi_percentile[1], by_year$bmi_percentile)
  expect_equal(ref$systolic_bp_p90[1], by_year$systolic_bp_p90)
  expect_gt(ref$infant_weight_percentile[2], 0)
  expect_lt(ref$infant_weight_percentile[2], 1)
  expect_warning(
    .check_percentile_column(ref$infant_weight_percentile[2], "infant_weight_percentile"),
    class = "essential8_percentile_scale_warning"
  )
  infant <- suppressMessages(suppressWarnings(score_le8(ref[2, ], min_components = 1)))
  expect_equal(infant$bmi_score, 100)
})

test_that("population grouping and forest column collisions preserve the measures", {
  skip_if_not_installed("dplyr")
  s <- suppressWarnings(score_le8(data.frame(age = 40:43, sleep_hours = 7:10,
                                             n = rep(c("A", "B"), each = 2)),
                                  min_components = 1))
  grouped <- as_le8_scores(dplyr::group_by(tibble::as_tibble(s), le8_population))
  long <- tidy(grouped)
  expect_identical(sum(names(long) == "le8_population"), 1L)
  expect_equal(nrow(long), 9 * nrow(s))
  forest <- .le8_forest_data(s, "n", 0.95)
  expect_true(all(forest$n == 2))
  expect_identical(levels(forest$.le8_group), c("A", "B"))
  skip_if_not_installed("ggforestplotR")
  p <- plot(s, type = "forest", by = "n")
  expect_identical(p$labels$colour, "n")
  expect_no_error(ggplot2::ggplot_build(p))
})
