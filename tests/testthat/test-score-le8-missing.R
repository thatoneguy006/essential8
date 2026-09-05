.capture_score_warnings <- function(expr) {
  warnings <- list()
  value <- withCallingHandlers(
    expr,
    warning = function(condition) {
      warnings[[length(warnings) + 1L]] <<- condition
      invokeRestart("muffleWarning")
    }
  )

  list(value = value, warnings = warnings)
}

make_missing_component_input <- function(columns = character(), n = 2L) {
  row <- adult_mepa_row(total = 16)
  input <- row[rep(1L, n), , drop = FALSE]

  for (column in columns) {
    input[[column]][1] <- NA
  }

  input
}

test_that("min_components controls composite eligibility", {
  missing_columns <- list(
    "sleep_hours",
    c("sleep_hours", "bmi"),
    c("sleep_hours", "bmi", "non_hdl_cholesterol")
  )
  inputs <- lapply(missing_columns, make_missing_component_input)
  cases <- data.frame(
    name = c(
      "seven available at threshold seven",
      "six available below threshold seven",
      "five available below threshold eight",
      "five available below threshold seven",
      "five available at threshold five",
      "five available above threshold one"
    ),
    input = c(1L, 2L, 3L, 3L, 3L, 3L),
    min_components = c(7L, 7L, 8L, 7L, 5L, 1L),
    n_components = c(7L, 6L, 5L, 5L, 5L, 5L),
    eligible = c(TRUE, FALSE, FALSE, FALSE, TRUE, TRUE)
  )

  for (i in seq_len(nrow(cases))) {
    case <- cases[i, ]
    captured <- .capture_score_warnings(
      score_le8(inputs[[case$input]], min_components = case$min_components)
    )
    result <- captured$value

    expect_equal(length(captured$warnings), 0L, info = case$name)
    expect_equal(
      result$le8_n_components, c(case$n_components, 8L),
      info = case$name
    )
    expect_identical(result$le8_complete, c(FALSE, TRUE), info = case$name)
    expect_identical(
      !is.na(result$le8_composite_score), c(case$eligible, TRUE),
      info = case$name
    )
    expect_identical(
      !is.na(result$le8_category), c(case$eligible, TRUE),
      info = case$name
    )
    expect_equal(result$le8_composite_score[2], 100, info = case$name)

    if (i == 1L) {
      # Independently verify the mean of the seven available components.
      expected_mean <- mean(
        unlist(result[1, adult_component_score_columns()]),
        na.rm = TRUE
      )
      expect_true(is.na(result$le8_sleep_score[1]), info = case$name)
      expect_equal(result$le8_sleep_score[2], 100, info = case$name)
      expect_equal(
        result$le8_composite_score[1], expected_mean,
        info = case$name
      )
    }
  }
})

test_that("structural missingness emits one informative warning", {
  cases <- list(
    list(
      name = "Sleep missing with seven required",
      columns = "sleep_hours",
      components = "Sleep",
      scores = "le8_sleep_score",
      min_components = 7L,
      n_components = 7L,
      warning_class = "essential8_missing_component",
      eligible = TRUE
    ),
    list(
      name = "Sleep and BMI missing with six required",
      columns = c("sleep_hours", "bmi"),
      components = c("Sleep", "BMI"),
      scores = c("le8_sleep_score", "le8_bmi_score"),
      min_components = 6L,
      n_components = 6L,
      warning_class = "essential8_missing_component",
      eligible = TRUE
    ),
    list(
      name = "Sleep and BMI missing with impossible threshold seven",
      columns = c("sleep_hours", "bmi"),
      components = c("Sleep", "BMI"),
      scores = c("le8_sleep_score", "le8_bmi_score"),
      min_components = 7L,
      n_components = 6L,
      warning_class = "essential8_insufficient_components",
      eligible = FALSE
    )
  )
  complete_input <- make_missing_component_input()

  for (case in cases) {
    input <- complete_input
    for (column in case$columns) {
      input[[column]][] <- NA
    }
    captured <- .capture_score_warnings(
      score_le8(input, min_components = case$min_components)
    )
    result <- captured$value

    expect_equal(length(captured$warnings), 1L, info = case$name)
    warning <- captured$warnings[[1]]
    expect_true(inherits(warning, case$warning_class), info = case$name)
    warning_message <- conditionMessage(warning)
    for (component in case$components) {
      expect_match(
        warning_message, component,
        info = paste(case$name, component)
      )
    }
    if (!case$eligible) {
      expect_match(warning_message, "Only 6", info = case$name)
      expect_match(
        warning_message, "No LE8 composite scores",
        info = case$name
      )
    }
    expect_true(all(is.na(result[case$scores])), info = case$name)
    expect_identical(
      result$le8_n_components, rep(case$n_components, 2L),
      info = case$name
    )
    expect_identical(
      !is.na(result$le8_composite_score), rep(case$eligible, 2L),
      info = case$name
    )
  }
})

test_that("all missing components yield NA rather than NaN", {
  captured <- .capture_score_warnings(
    score_le8(data.frame(age = c(40, 50)), min_components = 1)
  )
  result <- captured$value

  expect_length(captured$warnings, 1L)
  expect_s3_class(
    captured$warnings[[1]],
    "essential8_insufficient_components"
  )
  expect_identical(result$le8_n_components, c(0L, 0L))
  expect_identical(result$le8_composite_score, rep(NA_real_, 2L))
  expect_false(any(is.nan(result$le8_composite_score)))
  expect_false(any(result$le8_complete))
})

test_that("missing treatment status is not interpreted as untreated", {
  input <- make_missing_component_input("antihypertensive_treatment")
  result <- expect_no_warning(score_le8(input, min_components = 7))

  expect_true(is.na(result$le8_blood_pressure_score[1]))
  expect_equal(result$le8_blood_pressure_score[2], 100)
  expect_equal(result$le8_n_components[1], 7L)
})

test_that("missing-value support does not relax input validation", {
  expect_error(
    score_le8(adult_example_row(sleep_hours = Inf)),
    class = "essential8_adult_input_error"
  )
})

test_that("scattered row-level missingness does not warn", {
  input <- adult_input_fixture()[1:8, , drop = FALSE]
  input$berries[1] <- NA_real_
  input$moderate_activity_minutes[2] <- NA_real_
  input$smoking_status[3] <- NA_character_
  input$sleep_hours[4] <- NA_real_
  input$bmi[5] <- NA_real_
  input$lipid_lowering_treatment[6] <- NA
  input$diabetes[7] <- NA
  input$antihypertensive_treatment[8] <- NA

  result <- expect_no_warning(score_le8(input, min_components = 7))

  expect_true(all(result$le8_n_components == 7L))
  expect_false(any(result$le8_complete))
  expect_true(all(!is.na(result$le8_composite_score)))
})

test_that("omitted component columns do not block unrelated scoring", {
  input <- adult_input_fixture()[1:2, , drop = FALSE]
  input[c("sleep_hours", "bmi", "bmi_profile")] <- NULL

  captured <- .capture_score_warnings(
    score_le8(input, min_components = 6)
  )
  result <- captured$value

  expect_length(captured$warnings, 1L)
  expect_true(all(is.na(result$le8_sleep_score)))
  expect_true(all(is.na(result$le8_bmi_score)))
  expect_true(all(!is.na(result$le8_blood_pressure_score)))
  expect_true(all(result$le8_n_components == 6L))
  expect_true(all(!is.na(result$le8_composite_score)))
})
