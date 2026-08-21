test_that("adult diet cut points are inclusive on the sourced boundary", {
  mepa <- c(0, 3, 4, 7, 8, 11, 12, 14, 15, 16)
  expect_equal(
    essential8:::.score_adult_diet(rep("mepa", length(mepa)), mepa),
    c(0, 0, 25, 25, 50, 50, 80, 80, 100, 100)
  )

  percentile <- c(
    1,
    24.999,
    25,
    49.999,
    50,
    74.999,
    75,
    94.999,
    95,
    100
  )
  expect_equal(
    essential8:::.score_adult_diet(
      rep("percentile", length(percentile)),
      percentile
    ),
    c(0, 0, 25, 25, 50, 50, 80, 80, 100, 100)
  )
})

test_that("adult physical activity uses moderate-equivalent minute bands", {
  minutes <- c(
    0,
    1,
    29.999,
    30,
    59.999,
    60,
    89.999,
    90,
    119.999,
    120,
    149.999,
    150
  )

  expect_equal(
    essential8:::.score_adult_physical_activity(minutes),
    c(0, 20, 20, 40, 40, 60, 60, 80, 80, 90, 90, 100)
  )
})

test_that("adult nicotine rules compose status and exposure modifiers", {
  expect_equal(
    essential8:::.score_adult_nicotine(
      smoking_status = c(
        "never",
        "former",
        "former",
        "former",
        "current",
        "never",
        "former",
        "current"
      ),
      years_since_quit = c(0, 5, 1, 0.999, 0, 0, 5, 0),
      current_inhaled_nds = c(
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        FALSE
      ),
      secondhand_smoke_home = c(
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        TRUE,
        TRUE
      )
    ),
    c(100, 75, 50, 25, 0, 25, 55, 0)
  )
})

test_that("adult sleep duration bands cover short and long sleep", {
  hours <- c(
    0,
    3.999,
    4,
    4.999,
    5,
    5.999,
    6,
    6.999,
    7,
    8.999,
    9,
    9.999,
    10,
    24
  )
  expected <- c(0, 0, 20, 20, 40, 40, 70, 70, 100, 100, 90, 90, 40, 40)

  expect_equal(
    essential8:::.score_adult_sleep(hours, rep(FALSE, length(hours))),
    expected
  )
  expect_equal(
    essential8:::.score_adult_sleep(hours, rep(TRUE, length(hours))),
    pmax(0, expected - 20)
  )
})

test_that("adult BMI bands support explicit general and Asian-Pacific profiles", {
  general_bmi <- c(18.5, 24.999, 25, 29.999, 30, 34.999, 35, 39.999, 40)
  expect_equal(
    essential8:::.score_adult_bmi(
      general_bmi,
      rep("general", length(general_bmi)),
      rep(FALSE, length(general_bmi))
    ),
    c(100, 100, 70, 70, 30, 30, 15, 15, 0)
  )

  asian_pacific_bmi <- c(
    18.5,
    22.999,
    23,
    24.999,
    25,
    29.999,
    30,
    34.999,
    35
  )
  expect_equal(
    essential8:::.score_adult_bmi(
      asian_pacific_bmi,
      rep("asian_pacific", length(asian_pacific_bmi)),
      rep(FALSE, length(asian_pacific_bmi))
    ),
    c(100, 100, 75, 75, 50, 50, 25, 25, 0)
  )

  expect_equal(
    essential8:::.score_adult_bmi(
      bmi = c(25, 29.999),
      profile = c("general", "general"),
      apply_lean_muscular_override = c(TRUE, TRUE)
    ),
    c(100, 100)
  )
})

test_that("adult blood-lipid bands and treatment modifier are bounded", {
  non_hdl <- c(
    0,
    129.999,
    130,
    159.999,
    160,
    189.999,
    190,
    219.999,
    220
  )
  untreated <- c(100, 100, 60, 60, 40, 40, 20, 20, 0)

  expect_equal(
    essential8:::.score_adult_blood_lipids(
      non_hdl,
      rep(FALSE, length(non_hdl))
    ),
    untreated
  )
  expect_equal(
    essential8:::.score_adult_blood_lipids(
      non_hdl,
      rep(TRUE, length(non_hdl))
    ),
    pmax(0, untreated - 20)
  )
})

test_that("adult blood-glucose bands use diagnosis and explicit measure", {
  expect_equal(
    essential8:::.score_adult_blood_glucose(
      diabetes = rep(FALSE, 6),
      measure = c(
        "fasting_glucose",
        "fasting_glucose",
        "fasting_glucose",
        "hba1c",
        "hba1c",
        "hba1c"
      ),
      value = c(99.999, 100, 125.999, 5.699, 5.7, 6.499),
      apply_prevention_penalty = rep(FALSE, 6)
    ),
    c(100, 60, 60, 100, 60, 60)
  )

  hba1c <- c(6.999, 7, 7.999, 8, 8.999, 9, 9.999, 10)
  expect_equal(
    essential8:::.score_adult_blood_glucose(
      diabetes = rep(TRUE, length(hba1c)),
      measure = rep("hba1c", length(hba1c)),
      value = hba1c,
      apply_prevention_penalty = rep(FALSE, length(hba1c))
    ),
    c(40, 30, 30, 20, 20, 10, 10, 0)
  )

  expect_equal(
    essential8:::.score_adult_blood_glucose(
      diabetes = FALSE,
      measure = "fasting_glucose",
      value = 90,
      apply_prevention_penalty = TRUE
    ),
    80
  )
})

test_that("adult blood-pressure boundaries use the less favorable level", {
  systolic <- c(119.999, 120, 129.999, 130, 139.999, 140, 159.999, 160)
  expect_equal(
    essential8:::.score_adult_blood_pressure(
      systolic,
      rep(70, length(systolic)),
      rep(FALSE, length(systolic))
    ),
    c(100, 75, 75, 50, 50, 25, 25, 0)
  )

  diastolic <- c(79.999, 80, 89.999, 90, 99.999, 100)
  expect_equal(
    essential8:::.score_adult_blood_pressure(
      rep(110, length(diastolic)),
      diastolic,
      rep(FALSE, length(diastolic))
    ),
    c(100, 50, 50, 25, 25, 0)
  )

  base_scores <- c(100, 75, 50, 25, 0)
  expect_equal(
    essential8:::.score_adult_blood_pressure(
      systolic = c(110, 120, 120, 140, 160),
      diastolic = c(70, 70, 80, 80, 70),
      treated = rep(TRUE, 5)
    ),
    pmax(0, base_scores - 20)
  )
})
