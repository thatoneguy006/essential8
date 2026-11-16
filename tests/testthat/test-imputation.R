# Setup ---------------------------------------------------------------------------

test_that("setup imputes only inputs each row's age uses", {
  data <- imputation_fixture()
  data$bmi[data$age < 20][1] <- 30 # a child's adult-BMI value is unused
  setup <- le8_imputation_setup(data)
  where <- setup$where
  child <- data$age < 20

  expect_s3_class(setup, "essential8_imputation_setup")
  expect_false(any(where[child, "bmi"]))
  expect_false(any(where[!child, "bmi_percentile"]))
  expect_false(any(where[data$age >= 13, "systolic_bp_p90"]))
  expect_false(any(where[data$age >= 6, "active_play_minutes"]))
  expect_true(all(where[, "bmi"] == (is.na(data$bmi) & !child)))

  # Unused observed values are blanked in the prepared data.
  expect_true(all(is.na(setup$data$bmi[child])))

  former_or_unknown <- is.na(data$smoking_status) | data$smoking_status == "former"
  expect_false(any(where[!former_or_unknown, "years_since_quit"]))

  # Nothing outside the inputs is ever imputed.
  expect_false(any(where[, c("id", "age", "group")]))
})

test_that("preschool MEPA items outside the 10-item screener are not imputed", {
  data <- imputation_fixture()
  preschool <- which(data$age < 6)[1:2]
  data$alcohol[preschool] <- NA
  data$cheese[preschool] <- NA
  data$fish[preschool] <- NA
  setup <- le8_imputation_setup(data)

  expect_false(any(setup$where[preschool, c("alcohol", "cheese")]))
  expect_true(all(setup$where[preschool, "fish"]))
})

test_that("predictors are limited to inputs defined for every target row", {
  setup <- le8_imputation_setup(imputation_fixture(), auxiliary = "group")
  pm <- setup$predictorMatrix

  # Adult BMI cannot predict sleep, which children also need.
  expect_identical(pm["sleep_hours", "bmi"], 0L)
  expect_identical(pm["sleep_hours", "age"], 1L)
  expect_identical(pm["sleep_hours", "group"], 1L)
  expect_identical(pm["bmi", "sleep_hours"], 1L)
  expect_identical(pm["bmi", "bmi"], 0L)
  expect_true(all(pm[setdiff(rownames(pm), names(setup$method)[setup$method != ""]), ] == 0L))

  adults <- imputation_fixture()
  adults <- adults[adults$age >= 20, ]
  adult_setup <- le8_imputation_setup(adults)
  expect_identical(adult_setup$predictorMatrix["sleep_hours", "bmi"], 1L)
})

test_that("setup chooses methods by type and orders constrained inputs first", {
  setup <- le8_imputation_setup(imputation_fixture())

  expect_identical(unname(setup$method["sleep_hours"]), "pmm")
  expect_identical(unname(setup$method["diabetes"]), "logreg")
  expect_identical(unname(setup$method["smoking_status"]), "polyreg")
  expect_identical(unname(setup$method["id"]), "")
  expect_s3_class(setup$data$current_inhaled_nds, "factor")
  expect_identical(
    setup$visitSequence[1:5],
    c("smoking_status", "current_inhaled_nds", "diabetes", "glucose_measure", "glucose_value")
  )
  expect_match(setup$post[["glucose_value"]], "\\.le8_post_impute")
  expect_identical(setup$post[["sleep_hours"]], "")
})

test_that("setup fills values that follow from observed data", {
  data <- imputation_fixture()
  diabetic <- which(data$diabetes %in% TRUE)[1]
  data$glucose_measure[diabetic] <- NA
  data$glucose_value[diabetic] <- NA
  smoker <- which(data$smoking_status %in% "current")[1]
  data$current_inhaled_nds[smoker] <- NA
  setup <- le8_imputation_setup(data)

  expect_identical(as.character(setup$data$glucose_measure[diabetic]), "hba1c")
  expect_identical(as.character(setup$data$current_inhaled_nds[smoker]), "FALSE")
  expect_false(setup$where[diabetic, "glucose_measure"])
  expect_gte(setup$deduced[["glucose_measure"]], 1L)
  expect_output(print(setup), "Filled in from observed values")
})

test_that("setup rejects data it cannot prepare", {
  data <- imputation_fixture()

  expect_error(le8_imputation_setup(1), class = "essential8_imputation_error")
  expect_error(
    le8_imputation_setup(data, diet_method = "dash"),
    class = "essential8_imputation_error"
  )
  no_age <- data
  no_age$age[1] <- NA
  expect_error(le8_imputation_setup(no_age), class = "essential8_imputation_error")

  unlabeled <- data
  row <- which(!is.na(unlabeled$glucose_value) & !unlabeled$diabetes %in% TRUE)[1]
  unlabeled$glucose_measure[row] <- NA
  expect_error(le8_imputation_setup(unlabeled), "needs its")

  expect_error(
    le8_imputation_setup(data, auxiliary = "nope"),
    class = "essential8_imputation_error"
  )
  expect_error(
    le8_imputation_setup(data, auxiliary = "bmi"),
    class = "essential8_imputation_error"
  )
  incomplete <- data
  incomplete$group[1] <- NA
  expect_error(
    le8_imputation_setup(incomplete, auxiliary = "group"),
    class = "essential8_imputation_error"
  )

  # Observed values are validated by the scorer.
  invalid <- data
  invalid$bmi[which(invalid$age >= 20)[1]] <- 15
  expect_error(le8_imputation_setup(invalid), class = "essential8_input_error")
})

# Post-processing ---------------------------------------------------------------

post_state <- function(data) {
  list(data = data, r = !is.na(data))
}

test_that("post rules never impute dual nicotine use", {
  data <- data.frame(
    smoking_status = factor(c("current", "never", "current"), levels = c("never", "former", "current")),
    current_inhaled_nds = factor(c("TRUE", "TRUE", "FALSE"), levels = c("FALSE", "TRUE"))
  )
  state <- post_state(data)
  state$r[, "current_inhaled_nds"] <- FALSE
  where <- !state$r

  out <- .le8_post_impute("current_inhaled_nds", data$current_inhaled_nds, data, state$r, where)
  expect_identical(as.character(out), c("FALSE", "TRUE", "FALSE"))
  expect_s3_class(out, "factor")

  # An observed NDS user is never imputed as a current smoker.
  state <- post_state(data)
  state$r[, "smoking_status"] <- FALSE
  where <- !state$r
  set.seed(1)
  out <- .le8_post_impute("smoking_status", data$smoking_status, data, state$r, where)
  expect_false(any(as.character(out)[c(1, 2)] == "current"))
  expect_identical(as.character(out)[3], "current")
})

test_that("post rules keep diabetes, measure, and value consistent", {
  data <- data.frame(
    diabetes = factor(c("TRUE", "TRUE", "FALSE", "FALSE"), levels = c("FALSE", "TRUE")),
    glucose_measure = factor(c("fasting_glucose", "hba1c", "hba1c", "fasting_glucose"),
                             levels = c("fasting_glucose", "hba1c")),
    glucose_value = c(90, 7.2, 6.9, 95)
  )
  r <- !is.na(data)
  r[, "diabetes"] <- FALSE
  where <- !r
  out <- .le8_post_impute("diabetes", data$diabetes, data, r, where)
  # Fasting glucose implies no diabetes; HbA1c >= 6.5 implies diabetes.
  expect_identical(as.character(out), c("FALSE", "TRUE", "TRUE", "FALSE"))

  r <- !is.na(data)
  r[, "glucose_measure"] <- FALSE
  where <- !r
  out <- .le8_post_impute("glucose_measure", data$glucose_measure, data, r, where)
  expect_identical(as.character(out)[1:2], c("hba1c", "hba1c"))
})

test_that("imputed glucose values come from the matching stratum", {
  data <- data.frame(
    diabetes = factor(c(rep("FALSE", 4), rep("TRUE", 2), "FALSE", "FALSE", "TRUE"), levels = c("FALSE", "TRUE")),
    glucose_measure = factor(
      c("fasting_glucose", "fasting_glucose", "hba1c", "hba1c", "hba1c", "hba1c",
        "fasting_glucose", "hba1c", "hba1c"),
      levels = c("fasting_glucose", "hba1c")
    ),
    glucose_value = c(88, 101, 5.4, 5.9, 7.1, 8.4, NA, NA, NA)
  )
  r <- !is.na(data)
  where <- !r
  # Draws from the wrong stratum: an HbA1c for a fasting row, a diabetic
  # HbA1c for a non-diabetic row, and a fasting value for a diabetic row.
  imputed <- c(5.4, 8.4, 101)
  set.seed(1)
  out <- .le8_post_impute("glucose_value", imputed, data, r, where)

  expect_true(out[1] %in% c(88, 101))
  expect_true(out[2] %in% c(5.4, 5.9))
  expect_true(out[3] %in% c(7.1, 8.4))
  # Valid draws are kept.
  kept <- .le8_post_impute("glucose_value", c(101, 5.9, 7.1), data, r, where)
  expect_identical(kept, c(101, 5.9, 7.1))
})

# Rubin's rules -------------------------------------------------------------------

test_that("Rubin pooling matches mice::pool.scalar()", {
  skip_if_not_installed("mice")
  q <- c(65.2, 66.1, 64.8, 65.9, 66.4)
  u <- c(0.81, 0.84, 0.79, 0.83, 0.80)
  ours <- .rubin_pool(q, u, n = 120)
  theirs <- mice::pool.scalar(q, u, n = 120, k = 1)

  expect_equal(ours$estimate, theirs$qbar)
  expect_equal(ours$std.error, sqrt(theirs$t))
  expect_equal(ours$df, theirs$df)
  expect_equal(ours$fmi, theirs$fmi)
})

test_that("pooling with no between-imputation variance reduces to one data set", {
  pooled <- .rubin_pool(rep(50, 4), rep(4, 4), n = 100)
  expect_equal(pooled$estimate, 50)
  expect_equal(pooled$std.error, 2)
  expect_lt(pooled$fmi, 0.05)
  expect_true(is.na(.rubin_pool(50, 4, n = 100)$std.error))
})

# Imputation, scoring, and pooled methods ---------------------------------------

# Imputation is slow, so the fixture is imputed once per test run.
imputation_cache <- new.env(parent = emptyenv())

imputed_fixture_scores <- function(m = 3) {
  if (!is.null(imputation_cache$result)) {
    return(imputation_cache$result)
  }
  data <- imputation_fixture()
  # Small samples make some logistic models separate; mice warns about it.
  scores <- suppressWarnings(score_le8(
    data,
    min_components = 7,
    impute = le8_imputation_control(m = m, maxit = 3, seed = 42, auxiliary = "group")
  ))
  imputation_cache$result <- list(
    data = data,
    imputed = attr(scores, "mids"),
    scores = scores
  )
  imputation_cache$result
}

test_that("score_le8(impute =) fills needed inputs, keeps observed values, and obeys the rules", {
  skip_if_not_installed("mice")
  result <- imputed_fixture_scores()
  data <- result$data
  long <- mice::complete(result$imputed, "long")
  setup <- le8_imputation_setup(data, auxiliary = "group")

  for (column in c("sleep_hours", "non_hdl_cholesterol", "glucose_value", "smoking_status", "bmi")) {
    needed <- setup$where[, column]
    expect_false(anyNA(long[[column]][rep(needed, 3)]), info = column)
  }
  observed <- !is.na(data$sleep_hours)
  expect_identical(long$sleep_hours[rep(observed, 3)], rep(data$sleep_hours[observed], 3))
  expect_true(all(le8_rule_violations(long) == 0L))
})

test_that("score_le8(impute =) returns stacked scored imputations", {
  skip_if_not_installed("mice")
  scores <- imputed_fixture_scores()$scores

  expect_s3_class(scores, c("essential8_imputed_scores", "essential8_scores", "data.frame"), exact = TRUE)
  expect_identical(sort(unique(scores$.imp)), 1:3)
  expect_identical(nrow(scores), 300L)
  expect_type(scores$current_inhaled_nds, "logical")
  expect_type(scores$smoking_status, "character")
  expect_false(anyNA(scores$blood_lipids_score))
  expect_s3_class(attr(scores, "mids"), "mids")
  expect_equal(attr(scores, "mids")$m, 3)
  expect_identical(attr(scores, "essential8_settings")$min_components, 7L)
  expect_true(is.symbol(attr(scores, "mids")$call$data))

  # score_le8_imputed() gives the same scores from the mids object, and from
  # stacked completed data as any imputation software might return.
  expect_equal(
    .drop_le8_scores_class(score_le8_imputed(attr(scores, "mids"), min_components = 7)),
    .drop_le8_scores_class(scores),
    ignore_attr = TRUE
  )
  stacked <- mice::complete(imputed_fixture_scores()$imputed, "long")
  expect_equal(
    .drop_le8_scores_class(score_le8_imputed(stacked, min_components = 7)),
    .drop_le8_scores_class(scores),
    ignore_attr = TRUE
  )
})

test_that("score_le8(impute =) is reproducible with a seed and keeps tibbles", {
  skip_if_not_installed("mice")
  skip_if_not_installed("tibble")
  adults <- tibble::as_tibble(adult_input_fixture())
  adults$non_hdl_cholesterol[c(2, 5)] <- NA
  adults$sleep_hours[3] <- NA
  run <- function(seed) {
    suppressWarnings(score_le8(
      adults,
      impute = le8_imputation_control(m = 2, maxit = 2, seed = seed)
    ))
  }
  first <- run(1)

  expect_s3_class(first, c("essential8_imputed_scores", "essential8_scores", "tbl_df"))
  expect_true(all(c(".imp", ".id") %in% names(first)))
  expect_identical(first$blood_lipids_score, run(1)$blood_lipids_score)
  expect_false(identical(first$sleep_score, run(2)$sleep_score))
})

test_that("score_le8(impute =) handles one input to impute, and none", {
  skip_if_not_installed("mice")
  adults <- adult_input_fixture()
  adults$non_hdl_cholesterol[c(2, 5)] <- NA
  expect_null(le8_imputation_setup(adults)$visitSequence)

  scores <- suppressWarnings(score_le8(
    adults,
    impute = le8_imputation_control(m = 2, maxit = 2, seed = 1)
  ))
  expect_false(anyNA(scores$blood_lipids_score))

  # Complete data: every imputed data set is the observed data.
  expect_message(
    complete <- score_le8(adult_input_fixture(), impute = le8_imputation_control(m = 3)),
    class = "essential8_imputation_message"
  )
  expect_s3_class(complete, "essential8_imputed_scores")
  expect_identical(complete$.id, rep(seq_len(nrow(adult_input_fixture())), 3))
  expect_null(attr(complete, "mids"))
  observed <- score_le8(adult_input_fixture())
  expect_identical(
    complete$le8_composite_score,
    rep(observed$le8_composite_score, 3)
  )
  sleep <- summary(complete)$statistics
  sleep <- sleep[sleep$measure == "sleep", ]
  expect_equal(sleep$mean, mean(observed$sleep_score))
})

test_that("score_le8() validates the impute argument and its options", {
  data <- adult_input_fixture()
  expect_error(score_le8(data, impute = "yes"), class = "essential8_imputation_error")
  expect_error(score_le8(data, impute = NA), class = "essential8_imputation_error")
  expect_error(le8_imputation_control(m = 1), class = "essential8_imputation_error")
  expect_error(le8_imputation_control(m = 2.5), class = "essential8_imputation_error")
  expect_error(le8_imputation_control(maxit = 0), class = "essential8_imputation_error")
  expect_error(le8_imputation_control(seed = "a"), class = "essential8_imputation_error")
  expect_error(le8_imputation_control(auxiliary = 1), class = "essential8_imputation_error")
  expect_error(le8_imputation_control(TRUE), class = "essential8_imputation_error")
  expect_error(le8_imputation_control(data = data), class = "essential8_imputation_error")

  control <- le8_imputation_control(m = 30, seed = 4, auxiliary = "group", printFlag = TRUE)
  expect_s3_class(control, "essential8_imputation_control")
  expect_identical(control$m, 30L)
  expect_identical(control$mice_args, list(printFlag = TRUE))
  expect_output(print(control), "m = 30, maxit = 5, seed = 4, auxiliary = group")

  skip_if_not_installed("mice")
  expect_error(
    score_le8(data, mepa_columns = c(olive_oil = "olive_oil"), impute = TRUE),
    class = "essential8_imputation_error"
  )
  expect_error(
    score_le8(data, diet_method = "percentile", impute = TRUE),
    class = "essential8_imputation_error"
  )
})

test_that("score_le8_imputed() checks the stacked imputations", {
  data <- imputation_fixture()
  expect_error(score_le8_imputed(data), class = "essential8_imputation_error")
  stacked <- rbind(cbind(data, .imp = 1L), cbind(data, .imp = 2L))
  expect_error(score_le8_imputed(transform(stacked, .imp = 0L)), class = "essential8_imputation_error")
  expect_error(score_le8_imputed(stacked[stacked$.imp == 1L, ]), class = "essential8_imputation_error")
  expect_error(score_le8_imputed(stacked[-1, ]), class = "essential8_imputation_error")
})

test_that("summary() pools means across imputations", {
  skip_if_not_installed("mice")
  scores <- imputed_fixture_scores()$scores
  sumry <- summary(scores)

  expect_s3_class(sumry, "summary.essential8_imputed_scores")
  expect_identical(sumry$m, 3L)
  expect_equal(sumry$n, 100)
  lipids <- sumry$statistics[sumry$statistics$measure == "blood_lipids", ]
  per_imputation <- tapply(scores$blood_lipids_score, scores$.imp, mean)
  expect_equal(lipids$mean, mean(per_imputation))
  expect_true(lipids$conf.low < lipids$mean && lipids$mean < lipids$conf.high)
  expect_gt(lipids$fmi, 0)
  expect_equal(sum(sumry$categories$percent), 100)
  expect_output(print(sumry), "pooled over 3 imputations")
  expect_output(print(sumry), "fraction of missing information")
})

test_that("summarise() pools by group and passes expressions to dplyr", {
  skip_if_not_installed("mice")
  skip_if_not_installed("dplyr")
  scores <- imputed_fixture_scores()$scores

  overall <- dplyr::summarise(scores)
  expect_equal(overall, summary(scores)$statistics)

  by_group <- dplyr::summarise(scores, .by = group)
  expect_identical(nrow(by_group), 2L * 9L)
  expect_true(all(c("std.error", "conf.low", "conf.high", "fmi") %in% names(by_group)))

  per_imp <- dplyr::summarise(scores, mean = mean(le8_composite_score, na.rm = TRUE), .by = .imp)
  expect_identical(nrow(per_imp), 3L)
})

test_that("tidy(), plot(), and as_le8_scores() handle imputations", {
  skip_if_not_installed("mice")
  scores <- imputed_fixture_scores()$scores

  long <- tidy(scores, id_cols = "id")
  expect_identical(names(long)[1:4], c("row", ".imp", ".id", "id"))
  expect_identical(nrow(long), 300L * 9L)

  restored <- as_le8_scores(.drop_le8_scores_class(scores))
  expect_s3_class(restored, "essential8_imputed_scores")

  skip_if_not_installed("ggplot2")
  for (type in c("components", "distribution", "composite")) {
    expect_no_error(ggplot2::ggplot_build(plot(scores, type = type)))
  }
  built <- ggplot2::ggplot_build(plot(scores, type = "composite"))$data[[1]]
  expect_equal(sum(built$count), sum(!is.na(scores$le8_composite_score)) / 3)

  skip_if_not_installed("ggforestplotR", "0.6.0")
  forest <- .le8_forest_data(scores, by = "group", conf_level = 0.95, imputed = TRUE)
  pooled <- dplyr::summarise(scores, .by = group)
  row <- forest[forest$measure == "blood_lipids" & forest$group == "a", ]
  expected <- pooled[pooled$measure == "blood_lipids" & pooled$group == "a", ]
  expect_equal(c(row$conf.low, row$conf.high), c(expected$conf.low, expected$conf.high))
  expect_no_error(ggplot2::ggplot_build(plot(scores, type = "forest", by = "group")))
})
