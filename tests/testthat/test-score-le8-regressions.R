# Regression tests for defects found in the October 2026 dev-branch review.
# Expected values are literal AHA 2022 table values, not package output.

test_that("diabetes with an unknown glucose measure is not scored as HbA1c", {
  input <- adult_input_fixture()[c(1, 1), ]
  input$diabetes <- TRUE
  input$glucose_measure <- NA_character_
  input$glucose_value <- c(150, 6.8)

  result <- suppressWarnings(score_le8(input))

  expect_equal(result$le8_blood_glucose_score, c(NA_real_, NA_real_))
})

test_that("diabetes with a known HbA1c is still scored", {
  input <- adult_input_fixture()[c(1, 1), ]
  input$diabetes <- TRUE
  input$glucose_measure <- "hba1c"
  input$glucose_value <- c(6.8, 10)

  expect_equal(score_le8(input)$le8_blood_glucose_score, c(40, 0))
})

test_that("lean muscular override never scores a missing BMI or profile", {
  input <- adult_input_fixture()[c(1, 1, 1), ]
  input$apply_lean_muscular_bmi_override <- TRUE
  input$bmi <- c(NA, 27, 27)
  input$bmi_profile <- c("general", NA, "general")

  result <- suppressWarnings(score_le8(input))

  expect_equal(result$le8_bmi_score, c(NA, NA, 100))
})

test_that("an NA lean muscular flag only blanks BMIs it could change", {
  input <- adult_input_fixture()[c(1, 1, 1), ]
  input$apply_lean_muscular_bmi_override <- NA
  input$bmi_profile <- "general"
  input$bmi <- c(22, 27, 32)

  result <- suppressWarnings(score_le8(input))

  expect_equal(result$le8_bmi_score, c(100, NA, 30))
})

test_that("an NA prediabetes flag only blanks scores it could change", {
  input <- adult_input_fixture()[c(1, 1, 1), ]
  input$apply_prediabetes_metformin_penalty <- NA
  input$diabetes <- c(TRUE, FALSE, FALSE)
  input$glucose_measure <- c("hba1c", "fasting_glucose", "fasting_glucose")
  input$glucose_value <- c(6.8, 110, 90)

  result <- suppressWarnings(score_le8(input))

  # Diabetic and prediabetic-range rows cannot receive the penalty;
  # the normoglycemic row could, so its score stays unknown.
  expect_equal(result$le8_blood_glucose_score, c(40, 60, NA))
})

test_that("entirely missing columns read as logical NA are treated as missing", {
  input <- adult_input_fixture()[1:2, ]
  input$vigorous_activity_minutes <- NA
  input$glucose_measure <- NA
  input$glucose_value <- NA

  # Two structurally missing components leave six, below the default seven.
  expect_warning(
    result <- score_le8(input),
    class = "essential8_insufficient_components"
  )

  expect_equal(result$le8_physical_activity_score, c(NA_real_, NA_real_))
  expect_equal(result$le8_blood_glucose_score, c(NA_real_, NA_real_))
  expect_identical(result$vigorous_activity_minutes, c(NA, NA))
})

test_that("an entirely missing MEPA item column is treated as missing", {
  input <- adult_input_fixture()[1:2, ]
  input$fish <- NA

  result <- suppressWarnings(score_le8(input))

  expect_equal(result$mepa_total, c(NA_integer_, NA_integer_))
})

test_that("an entirely missing raw HEI-2015 column is treated as missing", {
  row <- adult_hei2015_row()
  row$hei2015_sodium <- NA

  result <- suppressWarnings(score_le8(
    row, "hei2015", hei2015_cutpoints = hei2015_reference_fixture()
  ))

  expect_true(is.na(result$hei2015_total))
  expect_true(is.na(result$hei2015_sodium_score))
})

test_that("case variants of case-sensitive input names are rejected", {
  for (column in c("bmi", "diet_value", "glucose_value")) {
    input <- adult_input_fixture()[1, ]
    if (!column %in% names(input)) input[[column]] <- NA_real_
    names(input)[names(input) == column] <- toupper(column)

    expect_error(
      score_le8(input),
      "case-sensitive",
      class = "essential8_adult_input_error",
      info = column
    )
  }
})

test_that("MEPA mappings cannot be silently ignored by other methods", {
  input <- adult_input_fixture()[1, ]
  input$diet_value <- 60

  expect_error(
    score_le8(input, "percentile", mepa_columns = c(fish = "fish")),
    class = "essential8_adult_input_error"
  )
})

test_that("index columns cannot be silently ignored by percentile scoring", {
  input <- adult_input_fixture()[1, ]
  input$diet_value <- 60
  input$dash <- 25

  expect_error(
    score_le8(input, "percentile"),
    class = "essential8_adult_input_error"
  )
})

test_that("an all-missing diet_value column does not block index scoring", {
  input <- adult_input_fixture()[1:2, ]
  input[c("sex", adult_mepa_columns())] <- NULL
  input$hei2015 <- c(45, 70)
  input$diet_value <- NA_real_

  result <- score_le8(input, "hei2015", reference = "nhanes_2015_2018")

  expect_equal(result$le8_diet_score, c(25, 80))
})

test_that("raw DASH returns its eight component scores", {
  result <- score_le8(
    adult_dash_row(), "dash", dash_cutpoints = dash_reference_fixture()
  )
  component_columns <- paste0(
    "dash_", essential8:::.adult_dash_fields(), "_score"
  )

  expect_true(all(component_columns %in% names(result)))
  expect_equal(
    sum(unlist(result[component_columns])),
    result$dash_total
  )
})

test_that("DASH component output names are reserved", {
  input <- adult_dash_row()
  input$dash_fruits_score <- 1

  expect_error(
    score_le8(input, "dash", dash_cutpoints = dash_reference_fixture()),
    class = "essential8_adult_input_error"
  )
})

test_that("the caller's data frame class and row names are preserved", {
  skip_if_not_installed("dplyr")
  input <- adult_input_fixture()[3:4, ]

  expect_identical(rownames(score_le8(input)), c("3", "4"))

  tbl <- dplyr::as_tibble(input)
  expect_s3_class(score_le8(tbl), "tbl_df")

  grouped <- dplyr::group_by(tbl, sex)
  result <- score_le8(grouped)
  expect_s3_class(result, "grouped_df")
  expect_identical(dplyr::group_vars(result), "sex")
})

test_that("a logical female column is accepted for MEPA sex", {
  input <- adult_input_fixture()[1:2, ]
  expected <- score_le8(input)$mepa_total
  input$female <- tolower(input$sex) %in% c("f", "female")
  input$sex <- NULL

  expect_identical(score_le8(input)$mepa_total, expected)
})

test_that("component scores stay double when a component is entirely missing", {
  input <- adult_input_fixture()[1:2, ]
  input[c("moderate_activity_minutes", "vigorous_activity_minutes")] <- NULL

  result <- suppressWarnings(score_le8(input))

  for (column in grep("^le8_.*_score$", names(result), value = TRUE)) {
    expect_type(result[[column]], "double")
  }
})
