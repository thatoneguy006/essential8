test_that("the hand-scored 10-subject example is reproduced", {
  fixture <- adult_example_fixture()
  input <- fixture[!startsWith(names(fixture), "expected_")]

  result <- score_le8(input)

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
  expect_equal(result$le8_score, fixture$expected_le8_score)
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
    fixture$expected_le8_score
  )
})

test_that("AHA Supplemental Appendix 3 adult examples are reproduced", {
  aha_examples <- rbind(
    adult_example_row(
      id = "mrs_a_baseline",
      age = 56,
      diet_value = 12,
      moderate_activity_minutes = 90,
      smoking_status = "never",
      years_since_quit = 0,
      current_inhaled_nds = FALSE,
      secondhand_smoke_home = FALSE,
      sleep_hours = 6.5,
      apply_sleep_apnea_penalty = FALSE,
      bmi = 31,
      bmi_profile = "general",
      non_hdl_cholesterol = 136,
      lipid_lowering_treatment = TRUE,
      diabetes = FALSE,
      glucose_measure = "fasting_glucose",
      glucose_value = 107,
      apply_prediabetes_metformin_penalty = FALSE,
      systolic_bp = 135,
      diastolic_bp = 76,
      antihypertensive_treatment = TRUE
    ),
    adult_example_row(
      id = "mrs_a_follow_up",
      age = 57,
      diet_value = 15,
      moderate_activity_minutes = 210,
      smoking_status = "never",
      years_since_quit = 0,
      current_inhaled_nds = FALSE,
      secondhand_smoke_home = FALSE,
      sleep_hours = 8,
      apply_sleep_apnea_penalty = FALSE,
      bmi = 28,
      bmi_profile = "general",
      non_hdl_cholesterol = 118,
      lipid_lowering_treatment = TRUE,
      diabetes = FALSE,
      glucose_measure = "fasting_glucose",
      glucose_value = 92,
      apply_prediabetes_metformin_penalty = FALSE,
      systolic_bp = 125,
      diastolic_bp = 72,
      antihypertensive_treatment = TRUE
    ),
    adult_example_row(
      id = "mr_c",
      age = 45,
      diet_value = 2,
      moderate_activity_minutes = 0,
      smoking_status = "former",
      years_since_quit = 3,
      current_inhaled_nds = FALSE,
      secondhand_smoke_home = FALSE,
      sleep_hours = 5,
      apply_sleep_apnea_penalty = FALSE,
      bmi = 38,
      bmi_profile = "general",
      non_hdl_cholesterol = 185,
      lipid_lowering_treatment = FALSE,
      diabetes = TRUE,
      glucose_measure = "hba1c",
      glucose_value = 9.2,
      apply_prediabetes_metformin_penalty = FALSE,
      systolic_bp = 137,
      diastolic_bp = 84,
      antihypertensive_treatment = TRUE
    ),
    adult_example_row(
      id = "ms_d",
      age = 75,
      diet_value = 15,
      moderate_activity_minutes = 140,
      smoking_status = "never",
      years_since_quit = 0,
      current_inhaled_nds = FALSE,
      secondhand_smoke_home = FALSE,
      sleep_hours = 7,
      apply_sleep_apnea_penalty = FALSE,
      bmi = 24,
      bmi_profile = "general",
      non_hdl_cholesterol = 120,
      lipid_lowering_treatment = FALSE,
      diabetes = FALSE,
      glucose_measure = "fasting_glucose",
      glucose_value = 96,
      apply_prediabetes_metformin_penalty = FALSE,
      systolic_bp = 132,
      diastolic_bp = 68,
      antihypertensive_treatment = TRUE
    )
  )

  result <- score_le8(aha_examples)
  expected_components <- rbind(
    c(80, 80, 100, 70, 30, 40, 60, 30),
    c(100, 100, 100, 100, 70, 80, 100, 55),
    c(0, 0, 50, 40, 15, 40, 10, 30),
    c(100, 90, 100, 100, 100, 100, 100, 30)
  )

  expect_equal(
    unname(as.matrix(result[adult_component_score_columns()])),
    expected_components
  )
  expect_equal(result$le8_score, c(61.25, 88.125, 23.125, 90))
  expect_equal(round(result$le8_score), c(61, 88, 23, 90))
})

test_that("public scoring supports population diet and optional-column defaults", {
  percentile_input <- adult_example_row(
    diet_method = "percentile",
    diet_value = 95
  )
  percentile_result <- score_le8(percentile_input)

  expect_equal(percentile_result$le8_diet_score, 100)
  expect_equal(percentile_result$le8_score, 100)

  default_input <- adult_example_row()
  default_input$apply_sleep_apnea_penalty <- NULL
  default_input$apply_prediabetes_metformin_penalty <- NULL
  default_result <- score_le8(default_input)

  expect_equal(default_result$le8_sleep_score, 100)
  expect_equal(default_result$le8_blood_glucose_score, 100)
})

test_that("public scoring supports the explicit lean muscular BMI override", {
  input <- adult_example_row(
    bmi = 25,
    apply_lean_muscular_bmi_override = TRUE
  )
  result <- score_le8(input)

  expect_equal(result$le8_bmi_score, 100)
  expect_equal(result$le8_score, 100)
})
