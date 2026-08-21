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

test_that("adult scoring rejects missing or malformed values", {
  input <- adult_input_fixture()
  input$glucose_value[1] <- NA_real_
  expect_error(
    score_le8(input),
    class = "essential8_adult_input_error"
  )

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

test_that("adult age and source-defined measurement domains are enforced", {
  expect_error(
    score_le8(adult_example_row(age = 19.999)),
    class = "essential8_adult_input_error"
  )
  expect_error(
    score_le8(adult_example_row(bmi = 18.499)),
    class = "essential8_adult_input_error"
  )
  expect_error(
    score_le8(
      adult_example_row(
        diet_method = "percentile",
        diet_value = 0.999
      )
    ),
    class = "essential8_adult_input_error"
  )
})

test_that("undefined AHA blood-glucose combinations are not guessed", {
  expect_error(
    score_le8(
      adult_example_row(
        diabetes = TRUE,
        glucose_measure = "fasting_glucose",
        glucose_value = 110
      )
    ),
    class = "essential8_adult_input_error"
  )
  expect_error(
    score_le8(
      adult_example_row(
        diabetes = FALSE,
        glucose_measure = "fasting_glucose",
        glucose_value = 126
      )
    ),
    class = "essential8_adult_input_error"
  )
  expect_error(
    score_le8(
      adult_example_row(
        diabetes = FALSE,
        glucose_measure = "hba1c",
        glucose_value = 6.5
      )
    ),
    class = "essential8_adult_input_error"
  )
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

test_that("existing output columns cannot be silently overwritten", {
  input <- adult_input_fixture()
  input$le8_score <- 0

  expect_error(
    score_le8(input),
    class = "essential8_adult_input_error"
  )
})

test_that("duplicate input column names are rejected", {
  input <- adult_input_fixture()
  input <- cbind(input, duplicate_age = input$age)
  names(input)[ncol(input)] <- "age"

  expect_error(
    score_le8(input),
    class = "essential8_adult_input_error"
  )
})

test_that("zero-row adult input has type-stable output", {
  input <- adult_input_fixture()[0, , drop = FALSE]
  result <- score_le8(input)

  expect_equal(nrow(result), 0L)
  expect_type(result$le8_score, "double")
  expect_type(result$le8_category, "character")
})
