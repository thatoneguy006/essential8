scored_adults <- function() {
  adults <- adult_input_fixture()
  suppressWarnings(score_le8(adults))
}

measure_keys <- c(
  "composite", "diet", "physical_activity", "nicotine", "sleep", "bmi",
  "blood_lipids", "blood_glucose", "blood_pressure"
)

# Class and output names ------------------------------------------------------

test_that("score_le8() returns an essential8_scores object with short names", {
  result <- scored_adults()

  expect_s3_class(result, c("essential8_scores", "data.frame"), exact = TRUE)
  expect_true(all(
    c(paste0(measure_keys[-1], "_score"), "n_components") %in% names(result)
  ))
  expect_false(any(startsWith(names(result), "le8_") &
    endsWith(names(result), "_score") &
    names(result) != "le8_composite_score"))
  expect_false("le8_n_components" %in% names(result))
  expect_identical(
    attr(result, "essential8_settings"),
    list(diet_method = "mepa", min_components = 7L)
  )
})

test_that("tibble and grouped tibble classes are kept beneath the new class", {
  skip_if_not_installed("dplyr")
  tbl <- dplyr::as_tibble(adult_input_fixture())

  expect_identical(
    class(suppressWarnings(score_le8(tbl))),
    c("essential8_scores", class(tbl))
  )
  grouped <- dplyr::group_by(tbl, sex)
  expect_identical(
    class(suppressWarnings(score_le8(grouped))),
    c("essential8_scores", class(grouped))
  )
})

test_that("pre-0.4.0 output names are rejected as inputs", {
  for (column in c("le8_diet_score", "le8_n_components", "sleep_score")) {
    input <- adult_input_fixture()
    input[[column]] <- 1
    expect_error(
      score_le8(input),
      class = "essential8_input_error",
      info = column
    )
  }
})

test_that("as_le8_scores() restores the class without changing values", {
  result <- scored_adults()
  plain <- .drop_le8_scores_class(result)
  expect_false(inherits(plain, "essential8_scores"))

  restored <- as_le8_scores(plain)
  expect_s3_class(restored, "essential8_scores")
  expect_identical(.drop_le8_scores_class(restored), plain)
  expect_identical(as_le8_scores(result), result)
})

test_that("methods and as_le8_scores() require the score columns", {
  result <- scored_adults()
  expect_error(as_le8_scores(1:3), class = "essential8_scores_error")
  expect_error(
    as_le8_scores(data.frame(age = 40)),
    class = "essential8_scores_error"
  )
  reduced <- result[c("id", "diet_score")]
  expect_s3_class(reduced, "essential8_scores")
  expect_error(summary(reduced), class = "essential8_scores_error")
  expect_error(tidy(reduced), class = "essential8_scores_error")
  expect_error(plot(reduced), class = "essential8_scores_error")

  legacy <- .drop_le8_scores_class(result)
  names(legacy)[names(legacy) == "diet_score"] <- "le8_diet_score"
  expect_error(as_le8_scores(legacy), "0.3.0 or earlier")
})

# summary() -------------------------------------------------------------------

test_that("summary() reports counts, statistics, and categories", {
  result <- scored_adults()
  result$sleep_score[1:2] <- NA
  result$le8_composite_score[1] <- NA
  result$le8_category[1] <- NA
  sumry <- summary(result)

  expect_s3_class(sumry, "summary.essential8_scores")
  expect_identical(sumry$n, nrow(result))
  expect_identical(sumry$population, c(adult = nrow(result), pediatric = 0L))
  expect_identical(sumry$n_composite, nrow(result) - 1L)

  stats <- sumry$statistics
  expect_identical(levels(stats$measure), measure_keys)
  sleep <- stats[stats$measure == "sleep", ]
  observed <- result$sleep_score[!is.na(result$sleep_score)]
  expect_identical(sleep$n, length(observed))
  expect_identical(sleep$n_missing, 2L)
  expect_equal(sleep$mean, mean(observed))
  expect_equal(sleep$sd, stats::sd(observed))
  expect_equal(sleep$median, stats::median(observed))
  expect_equal(c(sleep$min, sleep$max), range(observed))

  categories <- sumry$categories
  expect_identical(as.character(categories$category), c("low", "moderate", "high"))
  expect_identical(
    categories$n,
    as.vector(table(factor(result$le8_category, c("low", "moderate", "high"))))
  )
  expect_equal(sum(categories$percent), 100)
})

test_that("summary() handles rows with no available scores", {
  result <- scored_adults()[1, ]
  result[c(.le8_component_score_columns(), "le8_composite_score")] <- NA_real_
  result$le8_category <- NA_character_
  sumry <- summary(result)

  expect_identical(sumry$n_composite, 0L)
  expect_true(all(is.na(sumry$statistics$mean)))
  expect_output(print(sumry), "Composite score available for 0 of 1")
})

test_that("summary() prints a readable report", {
  output <- capture.output(print(summary(scored_adults())))

  expect_match(output[1], "^LE8 scores: \\d+ rows \\(\\d+ adult\\)$")
  expect_match(output[2], "Diet method: mepa; min_components: 7")
  expect_true(any(grepl("^LE8 composite", output)))
  expect_true(any(grepl("^Blood pressure", output)))
  expect_true(any(grepl("Category", output)))
})

# summarise() -----------------------------------------------------------------

test_that("summarise() without expressions matches summary() statistics", {
  skip_if_not_installed("dplyr")
  result <- scored_adults()

  out <- dplyr::summarise(result)
  expect_false(inherits(out, "essential8_scores"))
  expect_equal(out, summary(result)$statistics)
  expect_equal(dplyr::summarize(result), out)
})

test_that("summarise() groups by .by and by a grouped tibble", {
  skip_if_not_installed("dplyr")
  input <- dplyr::as_tibble(adult_input_fixture())
  result <- suppressWarnings(score_le8(input))

  by_bmi_profile <- dplyr::summarise(result, .by = bmi_profile)
  bmi_profilees <- unique(result$bmi_profile)
  expect_s3_class(by_bmi_profile, "tbl_df")
  expect_identical(nrow(by_bmi_profile), length(bmi_profilees) * length(measure_keys))
  first <- by_bmi_profile[by_bmi_profile$bmi_profile == bmi_profilees[1] & by_bmi_profile$measure == "composite", ]
  expect_equal(
    first$mean,
    mean(result$le8_composite_score[result$bmi_profile == bmi_profilees[1]], na.rm = TRUE)
  )

  grouped <- suppressWarnings(score_le8(dplyr::group_by(input, bmi_profile)))
  from_groups <- dplyr::summarise(grouped)
  expect_false(dplyr::is_grouped_df(from_groups))
  expect_equal(
    dplyr::arrange(from_groups, bmi_profile, measure),
    dplyr::arrange(by_bmi_profile, bmi_profile, measure)
  )
})

test_that("summarise() with expressions is ordinary dplyr", {
  skip_if_not_installed("dplyr")
  result <- scored_adults()

  out <- dplyr::summarise(
    result,
    mean_le8 = mean(le8_composite_score),
    .by = bmi_profile
  )
  expected <- dplyr::summarise(
    .drop_le8_scores_class(result),
    mean_le8 = mean(le8_composite_score),
    .by = bmi_profile
  )
  expect_identical(out, expected)
  expect_false(inherits(out, "essential8_scores"))
})

# tidy() ----------------------------------------------------------------------

test_that("tidy() returns one row per input row and measure", {
  result <- scored_adults()
  long <- tidy(result)

  expect_identical(names(long), c("row", "le8_population", "measure", "score"))
  expect_identical(nrow(long), nrow(result) * length(measure_keys))
  expect_identical(levels(long$measure), measure_keys)
  expect_identical(long$row, rep(seq_len(nrow(result)), each = 9L))
  expect_identical(
    long$score[long$measure == "bmi"],
    result$bmi_score
  )
  expect_identical(
    long$score[long$measure == "composite"],
    result$le8_composite_score
  )
  expect_false(inherits(long, "essential8_scores"))
})

test_that("tidy() carries id columns and can omit the composite", {
  result <- scored_adults()
  long <- tidy(result, id_cols = c("id", "sex"), composite = FALSE)

  expect_identical(
    names(long),
    c("row", "id", "sex", "le8_population", "measure", "score")
  )
  expect_identical(levels(long$measure), measure_keys[-1])
  expect_identical(long$id, rep(result$id, each = 8L))

  expect_error(tidy(result, id_cols = "nope"), class = "essential8_scores_error")
  expect_error(tidy(result, id_cols = "score"), class = "essential8_scores_error")
  expect_error(tidy(result, id_cols = 1), class = "essential8_scores_error")
  expect_error(tidy(result, composite = NA), class = "essential8_scores_error")
})

test_that("tidy() keeps tibbles and uses grouping columns as ids", {
  skip_if_not_installed("dplyr")
  input <- dplyr::group_by(dplyr::as_tibble(adult_input_fixture()), bmi_profile)
  long <- tidy(suppressWarnings(score_le8(input)))

  expect_s3_class(long, "tbl_df")
  expect_false(dplyr::is_grouped_df(long))
  expect_identical(names(long)[1:2], c("row", "bmi_profile"))
})

# plot() ----------------------------------------------------------------------

test_that("plot() returns ggplot objects for each type", {
  skip_if_not_installed("ggplot2")
  result <- scored_adults()

  for (type in c("components", "distribution", "composite")) {
    p <- plot(result, type = type)
    expect_s3_class(p, "ggplot")
    expect_no_error(ggplot2::ggplot_build(p))
  }
  expect_match(plot(result[1, ])$labels$title, "^LE8 scores$")
  expect_error(plot(result, type = "pie"))
})

test_that("composite histogram bins never straddle a category cutpoint", {
  skip_if_not_installed("ggplot2")
  result <- scored_adults()
  built <- ggplot2::ggplot_build(plot(result, type = "composite"))$data[[1]]
  built <- built[built$count > 0, ]

  expect_equal(sum(built$count), sum(!is.na(result$le8_composite_score)))
  straddles <- (built$xmin < 50 & built$xmax > 50) |
    (built$xmin < 80 & built$xmax > 80)
  expect_false(any(straddles))
})

test_that("plot() errors when there is nothing to draw", {
  skip_if_not_installed("ggplot2")
  result <- scored_adults()[1, ]
  result$le8_composite_score <- NA_real_
  expect_error(plot(result, type = "composite"), class = "essential8_scores_error")
})

# Forest plots ----------------------------------------------------------------

test_that("forest data give a mean and t interval per measure and group", {
  result <- scored_adults()
  forest <- .le8_forest_data(result, by = "bmi_profile", conf_level = 0.9)

  expect_identical(
    names(forest),
    c("measure", "label", "estimate", "conf.low", "conf.high", "n", "bmi_profile")
  )
  profiles <- sort(unique(result$bmi_profile))
  expect_identical(levels(forest$bmi_profile), profiles)

  sleep <- result$sleep_score[result$bmi_profile == profiles[1]]
  sleep <- sleep[!is.na(sleep)]
  row <- forest[forest$measure == "sleep" & forest$bmi_profile == profiles[1], ]
  half <- stats::qt(0.95, length(sleep) - 1) * stats::sd(sleep) / sqrt(length(sleep))
  expect_equal(row$estimate, mean(sleep))
  expect_equal(c(row$conf.low, row$conf.high), mean(sleep) + c(-1, 1) * half)
  expect_identical(row$n, length(sleep))
  expect_identical(row$label, "Sleep")
})

test_that("forest data drop measures without an interval and missing groups", {
  result <- scored_adults()
  result$blood_glucose_score[-1] <- NA
  result$bmi_profile[1:2] <- NA
  forest <- .le8_forest_data(result, by = "bmi_profile", conf_level = 0.95)

  expect_false("blood_glucose" %in% forest$measure)
  expect_false(anyNA(forest$bmi_profile))
  expect_error(
    .le8_forest_data(result[1, ], by = NULL, conf_level = 0.95),
    class = "essential8_scores_error"
  )
  expect_error(
    .le8_forest_data(result, by = "nope", conf_level = 0.95),
    class = "essential8_scores_error"
  )
})

test_that("plot(type = 'forest') calls ggforestplotR and forwards arguments", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("ggforestplotR", "0.6.0")
  result <- scored_adults()

  p <- plot(result, type = "forest")
  expect_s3_class(p, "ggplot")
  expect_no_error(ggplot2::ggplot_build(p))

  grouped <- plot(
    result,
    type = "forest",
    by = "bmi_profile",
    striped_rows = TRUE,
    conf.level = 0.9
  )
  expect_no_error(ggplot2::ggplot_build(grouped))
  expect_match(grouped$labels$x, "90% CI")
  expect_match(grouped$labels$title, "by bmi_profile")
})

test_that("plot() validates forest-only arguments", {
  skip_if_not_installed("ggplot2")
  result <- scored_adults()

  expect_error(plot(result, by = "sex"), class = "essential8_scores_error")
  expect_error(plot(result, striped_rows = TRUE), class = "rlib_error_dots_nonempty")

  skip_if_not_installed("ggforestplotR", "0.6.0")
  expect_error(
    plot(result, type = "forest", estimate = "mean"),
    class = "essential8_scores_error"
  )
  expect_error(plot(result, type = "forest", TRUE), class = "essential8_scores_error")
  expect_error(
    plot(result, type = "forest", conf.level = 95),
    class = "essential8_scores_error"
  )
})
