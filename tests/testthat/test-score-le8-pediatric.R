# Expected values in the pediatric fixture are literal hand calculations from
# Table 1 (children column) and Supplemental Appendix 2 of Lloyd-Jones et al.
# (2022), not package output.

test_that("the hand-scored pediatric and mixed-age example is reproduced", {
  fixture <- pediatric_example_fixture()
  result <- score_le8(pediatric_input_fixture(), min_components = 3)

  component <- c(
    "diet", "physical_activity", "nicotine", "sleep", "bmi",
    "blood_lipids", "blood_glucose", "blood_pressure"
  )
  expect_equal(
    unname(as.matrix(result[paste0(component, "_score")])),
    unname(as.matrix(fixture[paste0("expected_", component, "_score")]))
  )
  expect_equal(result$mepa_total, fixture$expected_mepa_total)
  expect_equal(
    result$physical_activity_moderate_equivalent_minutes,
    fixture$expected_activity_minutes
  )
  expect_identical(result$n_components, fixture$expected_n_components)
  expect_equal(result$le8_composite_score, fixture$expected_le8_composite_score)
  expect_identical(result$le8_category, fixture$expected_le8_category)
  expect_identical(result$le8_population, fixture$expected_le8_population)
})

test_that("the fixture's hand calculations are internally consistent", {
  fixture <- pediatric_example_fixture()
  scores <- fixture[setdiff(
    grep("^expected_.*_score$", names(fixture), value = TRUE),
    "expected_le8_composite_score"
  )]
  expect_equal(
    rowSums(scores, na.rm = TRUE),
    fixture$expected_component_sum
  )
  expect_equal(rowSums(!is.na(scores)), fixture$expected_n_components)
})

test_that("AHA supplemental Example 2 (Alex B, age 16) scores 470/7", {
  alex <- score_pediatric(pediatric_row("aha_example_2_alex"))
  expect_equal(alex$le8_composite_score, 470 / 7)
  expect_identical(round(alex$le8_composite_score), 67)
  expect_identical(alex$le8_category, "moderate")
})

test_that("adult scoring is unchanged by pediatric rows in the same call", {
  adults <- adult_input_fixture()
  alone <- score_pediatric(adults)
  children <- pediatric_input_fixture()[1:9, ]
  mixed <- suppressWarnings(
    score_pediatric(merge(adults, children, all = TRUE, sort = FALSE),
              min_components = 3)
  )
  mixed <- mixed[match(adults$id, mixed$id), ]
  columns <- c(adult_component_score_columns(), "le8_composite_score")
  expect_equal(
    unname(as.matrix(mixed[columns])),
    unname(as.matrix(alone[columns]))
  )
  expect_true(all(mixed$le8_population == "adult"))
})

test_that("pediatric age-band boundaries follow the AHA tables", {
  base <- pediatric_row("school_8_years")

  sleep <- function(age, hours) {
    suppressWarnings(score_le8(with_values(base, age = age, sleep_hours = hours)))$sleep_score
  }
  # 6-12 years: optimal 9-12 h, closed at both ends.
  expect_equal(sleep(8, c(9, 12, 12.5, 13, 8.5, 8, 7, 6)), c(100, 100, 90, 40, 70, 40, 20, 0))
  # 13 years switches to 8-10 h; 19 years keeps it.
  expect_equal(sleep(c(12.99, 13, 19), 8.5), c(70, 100, 100))
  # Age 20 is adult (7 to <9 h optimal).
  adult <- suppressWarnings(score_le8(with_values(base, age = 20, sleep_hours = 7)))
  expect_equal(adult$sleep_score, 100)

  lipids <- function(non_hdl, treated = FALSE) {
    score_pediatric(with_values(base, non_hdl_cholesterol = non_hdl,
                        lipid_lowering_treatment = treated))$blood_lipids_score
  }
  expect_equal(lipids(c(99.9, 100, 119.9, 120, 144.9, 145, 189.9, 190)),
               c(100, 60, 60, 40, 40, 20, 20, 0))
  expect_equal(lipids(c(99, 190), treated = TRUE), c(80, 0))

  activity <- function(moderate, vigorous = 0) {
    score_pediatric(with_values(base, moderate_activity_minutes = moderate,
                        vigorous_activity_minutes = vigorous))$physical_activity_score
  }
  expect_equal(activity(c(0, 0.5, 119, 120, 240, 300, 360, 419, 420)),
               c(0, 20, 20, 40, 60, 80, 90, 90, 100))
  # Vigorous minutes are not doubled for children.
  expect_equal(activity(200, 100), 80)
})

test_that("pediatric BMI uses percentile and percent-of-95th bands", {
  base <- pediatric_row("school_8_years")
  bmi <- function(percentile, percent_of_p95 = NA_real_) {
    score_pediatric(with_values(base, bmi_percentile = percentile,
                        bmi_percent_of_p95 = percent_of_p95))$bmi_score
  }
  expect_equal(bmi(c(5, 84.9, 85, 94.9)), c(100, 100, 70, 70))
  expect_equal(bmi(95, c(100, 119.9, 120, 139.9, 140)), c(30, 30, 15, 15, 0))
  expect_true(is.na(bmi(96)))
  expect_error(bmi(4.9), class = "essential8_pediatric_input_error")
  expect_error(bmi(0.5), "proportions", class = "essential8_input_error")
})

test_that("infant weight scores size and rapid gain", {
  base <- pediatric_row("infant_9_months")
  weight <- function(percentile, z_change) {
    score_pediatric(with_values(base, infant_weight_percentile = percentile,
                        infant_weight_z_change = z_change))$bmi_score
  }
  expect_equal(
    weight(c(97.6, 97.7, 99.7, 97.6, 97.7, 99.7), c(0, 0, 0, 0.67, 0.67, 0.67)),
    c(100, 75, 50, 75, 50, 0)
  )
  expect_true(is.na(weight(50, NA)))

  young <- pediatric_row("infant_5_months")
  young_score <- function(percentile) {
    score_pediatric(with_values(young, infant_weight_percentile = percentile),
              min_components = 1)$bmi_score
  }
  # No rapid-gain term before 6 months; z change is not required.
  expect_equal(young_score(c(97.6, 97.7, 99.7)), c(100, 75, 50))
})

test_that("pediatric blood pressure applies AAP 2017 'whichever is lower'", {
  base <- pediatric_row("school_8_years",
                        systolic_bp_p90 = 110, systolic_bp_p95 = 114,
                        diastolic_bp_p90 = 70, diastolic_bp_p95 = 74)
  bp <- function(systolic, diastolic = 60, treated = FALSE) {
    score_pediatric(with_values(base, systolic_bp = systolic, diastolic_bp = diastolic,
                        antihypertensive_treatment = treated))$blood_pressure_score
  }
  # Thresholds 110 (elevated), 114 (stage 1), 126 (stage 2), 144 (0 points).
  expect_equal(bp(c(109.9, 110, 113.9, 114, 125.9, 126, 143.9, 144)),
               c(100, 75, 75, 50, 50, 25, 25, 0))
  # Diastolic: 70, 74, 86, 94; the worse of the two readings counts.
  expect_equal(bp(100, c(69.9, 70, 74, 86, 94)), c(100, 75, 50, 25, 0))
  expect_equal(bp(114, 86), 25)
  expect_equal(bp(c(100, 144), treated = TRUE), c(80, 0))

  # Absolute caps apply when lower than the percentile-based thresholds.
  tall <- with_values(base, systolic_bp_p90 = 125, systolic_bp_p95 = 135,
                    diastolic_bp_p90 = 82, diastolic_bp_p95 = 86)
  capped <- function(systolic, diastolic) {
    score_pediatric(with_values(tall, systolic_bp = systolic,
                        diastolic_bp = diastolic))$blood_pressure_score
  }
  expect_equal(capped(c(119, 120, 130, 140, 160), 60), c(100, 75, 50, 25, 0))
  expect_equal(capped(100, c(79, 80, 90, 100)), c(100, 50, 25, 0))

  # Missing references leave ages 1-12 unscored; age 13 uses adult bands.
  expect_true(is.na(suppressWarnings(
    score_pediatric(with_values(base, systolic_bp_p95 = NA))
  )$blood_pressure_score))
  teen <- score_pediatric(with_values(base, age = 13, systolic_bp = 125,
                              diastolic_bp = 70))
  expect_equal(teen$blood_pressure_score, 75)
})

test_that("pediatric nicotine categories and modifiers follow Table 1", {
  base <- pediatric_row("school_8_years")
  nicotine <- function(status, nds = FALSE, secondhand = FALSE) {
    score_pediatric(with_values(base, smoking_status = status,
                        current_inhaled_nds = nds,
                        secondhand_smoke_home = secondhand))$nicotine_score
  }
  expect_equal(nicotine(c("never", "former", "current")), c(100, 50, 0))
  expect_equal(nicotine(c("never", "former"), nds = TRUE), c(25, 25))
  expect_equal(nicotine(c("never", "former", "current"), secondhand = TRUE),
               c(80, 30, 0))
  # years_since_quit is not used for children.
  expect_equal(
    score_pediatric(with_values(base, smoking_status = "former",
                        years_since_quit = NA))$nicotine_score,
    50
  )
})

test_that("young children's MEPA screeners reuse the adult columns", {
  preschool <- pediatric_row("preschool_4_years")
  expect_identical(score_pediatric(preschool)$mepa_total, 8L)
  expect_equal(score_pediatric(preschool)$diet_score, 80)
  all_met <- with_values(preschool, whole_grains = 3, nuts = 4)
  expect_equal(score_pediatric(all_met)$diet_score, 100)

  diet <- function(row, ...) score_pediatric(with_values(row, ...))$diet_score
  # Vegetables are the daily sum of the two vegetable items.
  expect_equal(diet(preschool, green_leafy_vegetables = c(1, 0.9)), c(80, 70))
  # Fruit is the weekly sum of berries and other fruit, 14/week = 2/day.
  expect_equal(diet(preschool, berries = c(0, 0), other_fruit = c(14, 13.9)),
               c(80, 70))
  # Fast food is at most 2 times per month (24 times per 52 weeks).
  expect_equal(diet(preschool, fast_food = c(24 / 52, 0.47, 1)), c(80, 70, 70))
  # Items not on the preschool screener do not matter.
  expect_equal(diet(preschool, cheese = 20, chicken = 20, beans = 0), 80)

  toddler <- pediatric_row("toddler_18_months")
  expect_equal(diet(toddler, milk_source = "human"), 70)
  expect_equal(diet(toddler, milk_source = "formula"), 55)
  expect_equal(diet(toddler, milk_source = "Cow"), 70)
  expect_error(diet(toddler, milk_source = "goat"),
               class = "essential8_input_error")

  infant <- pediatric_row("infant_9_months")
  expect_equal(diet(infant, milk_source = "human"), 85)
  # Six items met: the 1-a-day thresholds (7 fruit per week) before 12 months.
  expect_equal(diet(infant, other_fruit = 7, milk_source = "human"), 100)
  expect_equal(diet(infant, other_fruit = 7, milk_source = "cow"), 85)
  expect_equal(
    diet(infant, green_leafy_vegetables = 0, other_vegetables = 0,
         whole_grains = 0, sweets_and_pastries = 1, fast_food = 1),
    0
  )
})

test_that("ages 6 to 19 use the adult MEPA screener and bands", {
  row <- pediatric_row("school_8_years")
  result <- score_pediatric(row)
  expect_identical(result$mepa_total, 9L)
  expect_equal(result$diet_score, 50)
})

test_that("young-child MEPA needs only the fields its ages use", {
  # Preschool rows alone need neither sex, milk_source, nor the other items.
  preschool <- pediatric_row("preschool_4_years")
  preschool[c("sex", "milk_source", "chicken", "cheese", "beans",
              "alcohol")] <- NULL
  expect_equal(score_pediatric(preschool)$diet_score, 80)

  # A missing field the ages need is a naming error, not a missing score.
  missing <- preschool
  names(missing)[names(missing) == "fish"] <- "fish_per_week"
  expect_error(score_pediatric(missing), "fish -> fish",
               class = "essential8_input_error")
  mapped <- score_pediatric(missing, mepa_columns = c(fish = "fish_per_week"))
  expect_equal(mapped$diet_score, 80)

  toddler <- pediatric_row("toddler_18_months")
  toddler$milk_source <- NULL
  expect_error(score_pediatric(toddler), "milk_source",
               class = "essential8_input_error")
  expect_error(score_pediatric(with_values(preschool, fish = -1)),
               class = "essential8_input_error")
})

test_that("components AHA does not define at an age are not scored", {
  row <- pediatric_row(
    "infant_9_months",
    systolic_bp = 90, diastolic_bp = 50,
    systolic_bp_p90 = 100, systolic_bp_p95 = 104,
    diastolic_bp_p90 = 55, diastolic_bp_p95 = 59,
    antihypertensive_treatment = FALSE,
    moderate_activity_minutes = 100
  )
  expect_message(
    result <- score_pediatric(row, min_components = 3),
    class = "essential8_not_applicable"
  )
  expect_true(is.na(result$blood_pressure_score))
  expect_true(is.na(result$physical_activity_score))
  expect_identical(result$n_components, 4L)

  # Population diet percentiles are defined from age 2.
  infant <- pediatric_row("infant_9_months")
  infant[c(adult_mepa_columns(), "sex", "milk_source")] <- NULL
  infant$diet_value <- 80
  expect_message(
    percentile <- score_pediatric(infant, diet_method = "percentile",
                            min_components = 3),
    class = "essential8_not_applicable"
  )
  expect_true(is.na(percentile$diet_score))
  older <- with_values(infant, age = 2)
  older$age_months <- NULL
  expect_equal(
    suppressWarnings(score_le8(older, diet_method = "percentile"))$diet_score,
    80
  )
})

test_that("min_components warns when pediatric ages define too few components", {
  row <- pediatric_row("infant_5_months")
  expect_warning(
    result <- score_le8(row),
    class = "essential8_insufficient_components"
  )
  expect_true(is.na(result$le8_composite_score))
  expect_equal(score_pediatric(row, min_components = 3)$le8_composite_score, 85)

  # With complete adults in the call, the pediatric-specific warning applies.
  mixed <- merge(adult_input_fixture()[1, ], row, all = TRUE, sort = FALSE)
  expect_warning(
    mixed_result <- score_le8(mixed),
    "fewer LE8 components defined",
    class = "essential8_insufficient_components"
  )
  expect_equal(mixed_result$le8_composite_score, c(100, NA))
})

test_that("pediatric validation rejects undefined inputs", {
  base <- pediatric_row("school_8_years")
  expect_error(score_pediatric(with_values(base, age = 0.3)), "4 months",
               class = "essential8_adult_input_error")
  expect_error(score_pediatric(with_values(base, age_months = 120)), "disagree",
               class = "essential8_input_error")
  expect_error(score_pediatric(with_values(base, active_play_minutes = -1)),
               class = "essential8_pediatric_input_error")
  expect_error(score_pediatric(with_values(base, systolic_bp_p90 = 120)),
               "90th", class = "essential8_pediatric_input_error")
  expect_error(score_pediatric(with_values(base, apply_lean_muscular_bmi_override = TRUE)),
               "only for adults", class = "essential8_pediatric_input_error")
  expect_error(score_pediatric(with_values(base, smoking_status = "current",
                                   current_inhaled_nds = TRUE)),
               "dual-use", class = "essential8_input_error")
  # Adult-only BMI rules do not apply to children's raw BMI.
  expect_no_error(score_pediatric(with_values(base, bmi = 15)))
})

test_that("packaged adult diet references are refused for children", {
  child <- pediatric_row("school_8_years")
  child[c("sex", adult_mepa_columns())] <- NULL
  child$hei2015 <- 70
  expect_error(score_pediatric(child, diet_method = "hei2015"),
               "adults aged 20", class = "essential8_pediatric_input_error")

  reference <- diet_reference(40, 55, 65, 80, method = "hei2015",
                              label = "Synthetic pediatric reference")
  expect_equal(
    score_pediatric(child, diet_method = "hei2015", reference = reference)$diet_score,
    80
  )

  adult <- with_values(child, age = 30, bmi = 24, bmi_profile = "general")
  expect_error(
    suppressWarnings(score_le8(rbind(child, adult), diet_method = "hei2015",
                               reference = reference)),
    "separate calls", class = "essential8_pediatric_input_error"
  )

  child$hei2015 <- NULL
  child$diet_value <- 95
  expect_equal(score_pediatric(child, diet_method = "hei2015")$diet_score, 100)
})

test_that("pediatric errors report score_pediatric() as the call", {
  base <- pediatric_row("school_8_years", active_play_minutes = -1)
  error <- tryCatch(score_le8(base), error = identity)
  expect_identical(deparse(error$call[[1]]), "score_le8")
})

test_that("ages just below 20 are pediatric and 20 is adult", {
  base <- pediatric_row("teen_19_years")
  result <- score_pediatric(with_values(base, age = c(19.999, 20)))
  expect_identical(result$le8_population, c("pediatric", "adult"))
  # Sleep of 7.5 h: 0.5 h short of the 8-10 h pediatric range, optimal for adults.
  expect_equal(result$sleep_score, c(70, 100))
})
