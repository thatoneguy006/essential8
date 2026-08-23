test_that("the hand-scored 10-subject example is reproduced", {
  fixture <- adult_example_fixture()
  input <- adult_input_fixture()

  result <- score_le8(input, diet_method = "mepa")

  actual_columns <- adult_component_score_columns()
  expected_columns <- c(
    "expected_diet_score",
    "expected_physical_activity_score",
    "expected_nicotine_score",
    "expected_sleep_score",
    "expected_bmi_score",
    "expected_blood_lipids_score",
    "expected_blood_glucose_score",
    "expected_blood_pressure_score"
  )

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 10L)
  expect_equal(
    result$physical_activity_moderate_equivalent_minutes,
    fixture$expected_activity_minutes
  )
  expect_equal(result$mepa_total, fixture$expected_mepa_total)
  expect_equal(
    unname(as.matrix(result[actual_columns])),
    unname(as.matrix(fixture[expected_columns]))
  )
  expect_equal(result$le8_composite_score, fixture$expected_le8_composite_score)
  expect_true("le8_composite_score" %in% names(result))
  expect_false("le8_score" %in% names(result))
  expect_identical(result$le8_category, fixture$expected_le8_category)
})

test_that("manual fixture arithmetic is internally consistent", {
  fixture <- adult_example_fixture()
  expected_columns <- c(
    "expected_diet_score",
    "expected_physical_activity_score",
    "expected_nicotine_score",
    "expected_sleep_score",
    "expected_bmi_score",
    "expected_blood_lipids_score",
    "expected_blood_glucose_score",
    "expected_blood_pressure_score"
  )

  expect_equal(
    rowSums(fixture[expected_columns]),
    fixture$expected_component_sum
  )
  expect_equal(
    fixture$expected_component_sum / 8,
    fixture$expected_le8_composite_score
  )
})

test_that("public scoring uses optional-column defaults", {
  input <- adult_example_row()
  input$apply_sleep_apnea_penalty <- NULL
  input$apply_prediabetes_metformin_penalty <- NULL
  result <- score_le8(input)

  expect_equal(result$le8_sleep_score, 100)
  expect_equal(result$le8_blood_glucose_score, 100)
})

test_that("public scoring supports the explicit lean muscular BMI override", {
  input <- adult_example_row(
    bmi = 25,
    apply_lean_muscular_bmi_override = TRUE
  )
  result <- score_le8(input)

  expect_equal(result$le8_bmi_score, 100)
  expect_equal(result$le8_composite_score, 100)
})
