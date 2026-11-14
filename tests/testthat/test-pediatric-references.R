reference_input <- function() {
  data.frame(
    id = c("infant", "preschool", "school", "teen", "adult", "no_height"),
    age = c(0.75, 4.5, 8.25, 15.5, 30, 6.5),
    sex = c("m", "female", "male", "f", "male", "female"),
    height_cm = c(72, 105, 130, 160, 180, NA),
    weight_kg = c(9.5, 17, 30, 60, 80, 22)
  )
}

test_that("growth-chart values match cdcanthro", {
  skip_if_not_installed("cdcanthro")
  skip_if_not_installed("pedbp")
  result <- add_pediatric_references(reference_input())

  rows <- 2:4
  bmi <- with(reference_input(), weight_kg / (height_cm / 100)^2)
  # Fractional sentinel age so cdc_z() keeps the exact ages.
  direct <- cdcanthro::cdc_z(
    data.frame(sex = c(2, 1, 2, 1), agemos = c(54, 99, 186, 100.25),
               bmi = c(bmi[rows], NA)),
    age = "agemos", bmi = "bmi"
  )[1:3, ]
  expect_equal(result$bmi_percentile[rows], direct$bmip)
  expect_equal(result$bmi_percent_of_p95[rows], direct$bmip95)
  expect_true(all(is.na(result$bmi_percentile[c(1, 5)])))

  who <- cdcanthro::who_z(
    data.frame(sex = 1, agedays = round(9 * 30.4375), wt = 9.5, lenhei = 72),
    agedays = "agedays", wt = "wt", lenhei = "lenhei"
  )
  expect_equal(result$infant_weight_z[1], who$who_wflz)
  expect_equal(result$infant_weight_percentile[1], 100 * pnorm(who$who_wflz))
  expect_true(all(is.na(result$infant_weight_z[-1])))
})

test_that("blood-pressure references match pedbp and require height", {
  skip_if_not_installed("cdcanthro")
  skip_if_not_installed("pedbp")
  result <- add_pediatric_references(reference_input())

  direct <- function(p) {
    unclass(pedbp::q_bp(p_sbp = p, p_dbp = p, age = c(54, 99),
                        male = c(0, 1), height = c(105, 130),
                        source = "flynn2017"))
  }
  expect_equal(result$systolic_bp_p90[2:3], direct(0.90)$sbp)
  expect_equal(result$diastolic_bp_p95[2:3], direct(0.95)$dbp)
  expect_true(all(result$systolic_bp_p90[2:3] < result$systolic_bp_p95[2:3]))
  # Under 1 year, 13 and older, adults, and unknown height get no reference.
  expect_true(all(is.na(result$systolic_bp_p90[c(1, 4, 5, 6)])))
})

test_that("reference output feeds score_le8()", {
  skip_if_not_installed("cdcanthro")
  skip_if_not_installed("pedbp")
  child <- add_pediatric_references(reference_input()[3, ])
  child$systolic_bp <- 100
  child$diastolic_bp <- 60
  child$antihypertensive_treatment <- FALSE
  scored <- score_pediatric(child, min_components = 1)
  expect_false(is.na(scored$bmi_score))
  expect_equal(scored$blood_pressure_score, 100)
})

test_that("reference arguments are validated", {
  input <- reference_input()
  expect_error(add_pediatric_references(input, height = "missing"),
               class = "essential8_input_error")
  expect_error(add_pediatric_references(input, sex = "id"),
               "unsupported", class = "essential8_input_error")
  input$bmi_percentile <- 50
  expect_error(add_pediatric_references(input), "already contains",
               class = "essential8_input_error")
  expect_error(add_pediatric_references(as.list(reference_input())),
               class = "essential8_input_error")
})

test_that("an explicit age_months column is used", {
  skip_if_not_installed("cdcanthro")
  skip_if_not_installed("pedbp")
  input <- reference_input()[2, ]
  input$months <- 54.6
  explicit <- add_pediatric_references(input, age_months = "months")
  direct <- cdcanthro::cdc_z(
    data.frame(sex = 2, agemos = 54.6, bmi = 17 / 1.05^2),
    age = "agemos", bmi = "bmi"
  )
  expect_equal(explicit$bmi_percentile, direct$bmip)
})

test_that("one row's reference never depends on the other rows", {
  skip_if_not_installed("cdcanthro")
  skip_if_not_installed("pedbp")
  input <- reference_input()[2:3, ]
  together <- add_pediatric_references(input)
  alone <- add_pediatric_references(input[1, ])
  expect_equal(alone$bmi_percentile, together$bmi_percentile[1])

  # Completed months are shifted to their midpoint before lookup.
  completed <- add_pediatric_references(input[1, ], completed_months = TRUE)
  shifted <- input[1, ]
  shifted$age_months <- 54.5
  expect_equal(
    completed$bmi_percentile,
    add_pediatric_references(shifted)$bmi_percentile
  )
  expect_error(add_pediatric_references(input, completed_months = NA),
               class = "essential8_input_error")
})
