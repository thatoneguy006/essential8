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

test_that("one participant-level missing component is scored transparently", {
  input <- rbind(
    adult_mepa_row(total = 16),
    adult_mepa_row(total = 16)
  )
  input$sleep_hours[1] <- NA_real_

  result <- expect_no_warning(score_le8(input, min_components = 7))
  expected_mean <- mean(
    unlist(result[1, adult_component_score_columns()]),
    na.rm = TRUE
  )

  expect_true(is.na(result$le8_sleep_score[1]))
  expect_equal(result$le8_sleep_score[2], 100)
  expect_equal(result$le8_n_components, c(7L, 8L))
  expect_equal(result$le8_composite_score[1], expected_mean)
  expect_identical(result$le8_complete, c(FALSE, TRUE))
})

test_that("participants below min_components do not receive a composite", {
  input <- rbind(
    adult_mepa_row(total = 16),
    adult_mepa_row(total = 16)
  )
  input$sleep_hours[1] <- NA_real_
  input$bmi[1] <- NA_real_

  result <- expect_no_warning(score_le8(input, min_components = 7))

  expect_equal(result$le8_n_components[1], 6L)
  expect_true(is.na(result$le8_composite_score[1]))
  expect_true(is.na(result$le8_category[1]))
  expect_false(result$le8_complete[1])
})

test_that("user-selected component thresholds control composite eligibility", {
  input <- rbind(
    adult_mepa_row(total = 16),
    adult_mepa_row(total = 16)
  )
  input$sleep_hours[1] <- NA_real_
  input$bmi[1] <- NA_real_
  input$non_hdl_cholesterol[1] <- NA_real_

  results <- lapply(c(8L, 7L, 5L, 1L), function(threshold) {
    expect_no_warning(score_le8(input, min_components = threshold))
  })

  expect_true(is.na(results[[1]]$le8_composite_score[1]))
  expect_true(is.na(results[[2]]$le8_composite_score[1]))
  expect_false(is.na(results[[3]]$le8_composite_score[1]))
  expect_false(is.na(results[[4]]$le8_composite_score[1]))
  expect_equal(results[[3]]$le8_n_components[1], 5L)
})

test_that("min_components accepts only one whole number from 1 to 8", {
  invalid_values <- list(
    0,
    9,
    NA_real_,
    7.5,
    c(7, 8),
    "7"
  )

  for (value in invalid_values) {
    expect_error(
      score_le8(adult_mepa_row(total = 16), min_components = value),
      "single integer between 1 and 8",
      class = "essential8_adult_input_error"
    )
  }

  for (value in 1:8) {
    expect_no_warning(
      score_le8(adult_mepa_row(total = 16), min_components = value)
    )
  }
})

test_that("one structurally missing component produces one warning", {
  input <- rbind(
    adult_mepa_row(total = 16),
    adult_mepa_row(total = 16)
  )
  input$sleep_hours <- NA_real_

  captured <- .capture_score_warnings(
    score_le8(input, min_components = 7)
  )
  result <- captured$value

  expect_length(captured$warnings, 1L)
  expect_s3_class(
    captured$warnings[[1]],
    "essential8_missing_component"
  )
  expect_match(conditionMessage(captured$warnings[[1]]), "Sleep")
  expect_true(all(is.na(result$le8_sleep_score)))
  expect_true(all(!is.na(result$le8_composite_score)))
  expect_true(all(result$le8_n_components == 7L))
})

test_that("multiple structurally missing components are consolidated", {
  input <- rbind(
    adult_mepa_row(total = 16),
    adult_mepa_row(total = 16)
  )
  input$sleep_hours <- NA_real_
  input$bmi <- NA_real_

  captured <- .capture_score_warnings(
    score_le8(input, min_components = 6)
  )

  expect_length(captured$warnings, 1L)
  expect_s3_class(
    captured$warnings[[1]],
    "essential8_missing_component"
  )
  warning_message <- conditionMessage(captured$warnings[[1]])
  expect_match(warning_message, "Sleep")
  expect_match(warning_message, "BMI")
  expect_true(all(captured$value$le8_n_components == 6L))
  expect_true(all(!is.na(captured$value$le8_composite_score)))
})

test_that("structural missingness warns when the threshold is impossible", {
  input <- rbind(
    adult_mepa_row(total = 16),
    adult_mepa_row(total = 16)
  )
  input$sleep_hours <- NA_real_
  input$bmi <- NA_real_

  captured <- .capture_score_warnings(
    score_le8(input, min_components = 7)
  )

  expect_length(captured$warnings, 1L)
  expect_s3_class(
    captured$warnings[[1]],
    "essential8_insufficient_components"
  )
  expect_match(conditionMessage(captured$warnings[[1]]), "Only 6")
  expect_match(
    conditionMessage(captured$warnings[[1]]),
    "No LE8 composite scores"
  )
  expect_true(all(is.na(captured$value$le8_composite_score)))
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
  expect_true(all(is.na(result$le8_composite_score)))
  expect_false(any(is.nan(result$le8_composite_score)))
  expect_false(any(result$le8_complete))
})

test_that("missing treatment status is not interpreted as untreated", {
  input <- rbind(
    adult_mepa_row(total = 16),
    adult_mepa_row(total = 16)
  )
  input$antihypertensive_treatment[1] <- NA

  result <- expect_no_warning(score_le8(input, min_components = 7))

  expect_true(is.na(result$le8_blood_pressure_score[1]))
  expect_equal(result$le8_blood_pressure_score[2], 100)
  expect_equal(result$le8_n_components[1], 7L)
})

test_that("observed invalid values still fail validation", {
  expect_error(
    score_le8(adult_example_row(moderate_activity_minutes = -1)),
    class = "essential8_adult_input_error"
  )
  expect_error(
    score_le8(adult_example_row(sleep_hours = Inf)),
    class = "essential8_adult_input_error"
  )
  expect_error(
    score_le8(adult_example_row(smoking_status = "unknown")),
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
