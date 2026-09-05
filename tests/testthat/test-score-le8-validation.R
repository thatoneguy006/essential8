test_that("adult scoring requires a data frame and canonical columns", {
  expect_error(
    score_le8(list()),
    class = "essential8_adult_input_error"
  )

  input <- adult_input_fixture()
  input$age <- NULL
  expect_error(
    score_le8(input),
    class = "essential8_adult_input_error"
  )
})

test_that("adult scoring allows missing values but rejects malformed values", {
  input <- adult_input_fixture()
  input$glucose_value[1] <- NA_real_
  result <- expect_no_warning(score_le8(input))
  expect_true(is.na(result$le8_blood_glucose_score[1]))
  expect_equal(result$le8_n_components[1], 7L)

  input <- adult_input_fixture()
  input$current_inhaled_nds <- as.integer(input$current_inhaled_nds)
  expect_error(
    score_le8(input),
    class = "essential8_adult_input_error"
  )

  input <- adult_input_fixture()
  input$smoking_status[1] <- "unknown"
  expect_error(
    score_le8(input),
    class = "essential8_adult_input_error"
  )
})

test_that("adult scoring rejects dimensioned input columns", {
  dimensioned_columns <- c(
    "current_inhaled_nds",
    "smoking_status",
    "fish",
    "sex"
  )

  for (column in dimensioned_columns) {
    input <- adult_input_fixture()
    input[[column]] <- I(
      matrix(
        rep(input[[column]], 2L),
        nrow = nrow(input),
        ncol = 2L
      )
    )

    expect_error(
      score_le8(input),
      "one-dimensional",
      class = "essential8_adult_input_error",
      info = paste("dimensioned column:", column)
    )
  }

  single_column_matrix <- adult_input_fixture()
  single_column_matrix$moderate_activity_minutes <- I(
    matrix(single_column_matrix$moderate_activity_minutes, ncol = 1L)
  )
  expect_error(
    score_le8(single_column_matrix),
    "one-dimensional",
    class = "essential8_adult_input_error"
  )

  percentile <- adult_example_row(diet_value = 95)
  percentile$diet_value <- I(matrix(c(95, 95), nrow = 1L))
  expect_error(
    score_le8(percentile, diet_method = "percentile"),
    "one-dimensional",
    class = "essential8_adult_input_error"
  )
})

test_that("adult age and source-defined measurement domains are enforced", {
  cases <- list(
    list(
      name = "age below adult range",
      changes = list(age = 19.999),
      diet_method = "mepa"
    ),
    list(
      name = "BMI below source-defined scored range",
      changes = list(bmi = 18.499),
      diet_method = "mepa"
    ),
    list(
      name = "percentile below source-defined scored range",
      changes = list(diet_value = 0.999),
      diet_method = "percentile"
    ),
    list(
      name = "negative physical activity",
      changes = list(moderate_activity_minutes = -1),
      diet_method = "mepa"
    )
  )
  valid_input <- adult_example_row()

  for (case in cases) {
    input <- valid_input
    input[names(case$changes)] <- case$changes
    expect_error(
      score_le8(input, diet_method = case$diet_method),
      class = "essential8_adult_input_error",
      info = case$name
    )
  }
})

test_that("undefined AHA blood-glucose combinations are not guessed", {
  cases <- data.frame(
    name = c(
      "diabetes with fasting glucose",
      "no diabetes with fasting glucose at 126",
      "no diabetes with HbA1c at 6.5"
    ),
    diabetes = c(TRUE, FALSE, FALSE),
    glucose_measure = c("fasting_glucose", "fasting_glucose", "hba1c"),
    glucose_value = c(110, 126, 6.5)
  )
  valid_input <- adult_example_row()

  for (i in seq_len(nrow(cases))) {
    case <- cases[i, ]
    input <- valid_input
    input$diabetes <- case$diabetes
    input$glucose_measure <- case$glucose_measure
    input$glucose_value <- case$glucose_value

    expect_error(
      score_le8(input),
      class = "essential8_adult_input_error",
      info = case$name
    )
  }
})

test_that("undefined current combustible and inhaled-NDS dual use is not guessed", {
  expect_error(
    score_le8(
      adult_example_row(
        smoking_status = "current",
        current_inhaled_nds = TRUE
      )
    ),
    class = "essential8_adult_input_error"
  )
})

test_that("clinical-judgment penalties must be explicitly applicable", {
  expect_error(
    score_le8(
      adult_example_row(
        diabetes = FALSE,
        glucose_measure = "hba1c",
        glucose_value = 5.7,
        apply_prediabetes_metformin_penalty = TRUE
      )
    ),
    class = "essential8_adult_input_error"
  )

  expect_error(
    score_le8(
      adult_example_row(
        bmi = 30,
        apply_lean_muscular_bmi_override = TRUE
      )
    ),
    class = "essential8_adult_input_error"
  )
})

test_that("diet_method is a scalar, case-insensitive call-level argument", {
  input <- rbind(
    adult_example_row(diet_value = 25),
    adult_example_row(diet_value = 95)
  )

  result <- score_le8(input, diet_method = "  PeRcEnTiLe  ")

  expect_equal(result$le8_diet_score, c(25, 100))
  expect_equal(result$le8_composite_score[2], 100)
  expect_false("diet_method" %in% names(result))
})

test_that("diet_method rejects non-scalar and unsupported values", {
  invalid_methods <- list(
    empty = character(),
    multiple = c("mepa", "percentile"),
    missing = NA_character_,
    blank = "",
    unsupported = "unknown",
    numeric = 1,
    logical = TRUE
  )
  input <- adult_example_row()

  for (name in names(invalid_methods)) {
    expect_error(
      score_le8(input, diet_method = invalid_methods[[name]]),
      class = "essential8_adult_input_error",
      info = paste("diet_method:", name)
    )
  }
})

test_that("matching legacy diet_method columns are accepted unchanged", {
  input <- rbind(
    adult_mepa_row(total = 16),
    adult_mepa_row(total = 15)
  )
  input$diet_method <- c(" MePa ", "MEPA")

  result <- score_le8(input, diet_method = "mepa")

  expect_identical(result$diet_method, input$diet_method)
  expect_equal(result$mepa_total, c(16, 15))
})

test_that("legacy diet_method conflicts and mixed methods are rejected", {
  legacy_values <- list(
    conflicting = c("percentile", "percentile"),
    mixed = c("mepa", "percentile")
  )
  input <- rbind(
    adult_mepa_row(total = 16),
    adult_mepa_row(total = 15)
  )

  for (name in names(legacy_values)) {
    input$diet_method <- legacy_values[[name]]

    expect_error(
      score_le8(input, diet_method = "mepa"),
      class = "essential8_adult_input_error",
      info = paste("legacy diet_method:", name)
    )
  }
})

test_that("existing current or legacy composite columns are rejected", {
  for (column in c("le8_composite_score", "le8_score")) {
    input <- adult_input_fixture()
    input[[column]] <- 0

    expect_error(
      score_le8(input),
      class = "essential8_adult_input_error",
      info = paste("existing output column:", column)
    )
  }
})

test_that("duplicate input column names are rejected case-insensitively", {
  input <- adult_input_fixture()
  input <- cbind(input, duplicate_age = input$age)
  names(input)[ncol(input)] <- "AGE"

  expect_error(
    score_le8(input),
    class = "essential8_adult_input_error"
  )
})

test_that("zero-row adult input has type-stable output", {
  input <- adult_input_fixture()[0, , drop = FALSE]
  result <- score_le8(input)

  expect_equal(nrow(result), 0L)
  expect_type(result$le8_composite_score, "double")
  expect_type(result$le8_category, "character")
})

test_that("min_components accepts only one whole number from 1 to 8", {
  invalid_values <- list(
    below_range = 0,
    above_range = 9,
    missing = NA_real_,
    fractional = 7.5,
    multiple = c(7, 8),
    character = "7"
  )
  input <- adult_mepa_row(total = 16)

  for (name in names(invalid_values)) {
    expect_error(
      score_le8(input, min_components = invalid_values[[name]]),
      "single integer between 1 and 8",
      class = "essential8_adult_input_error",
      info = paste("min_components:", name)
    )
  }

  for (value in 1:8) {
    warnings <- testthat::capture_warnings(
      score_le8(input, min_components = value)
    )
    expect_equal(
      length(warnings), 0L,
      info = paste("valid min_components:", value)
    )
  }
})
