# A small mixed-age cohort with realistic missing inputs, for imputation tests.
# Observed values always satisfy the scoring rules.
imputation_fixture <- function(n_adult = 60, n_child = 40, seed = 1) {
  set.seed(seed)
  n <- n_adult + n_child
  age <- c(sample(20:79, n_adult, replace = TRUE), sample(2:19, n_child, replace = TRUE))
  child <- age < 20
  under_13 <- age < 13
  preschool <- age < 6
  diabetes <- !child & stats::runif(n) < 0.15
  smoking_status <- ifelse(
    age < 13,
    "never",
    sample(c("never", "former", "current"), n, replace = TRUE, prob = c(0.6, 0.25, 0.15))
  )
  pick <- function(p) stats::runif(n) < p

  data <- data.frame(
    id = sprintf("P%03d", seq_len(n)),
    age = age,
    sex = sample(c("female", "male"), n, replace = TRUE),
    group = sample(c("a", "b"), n, replace = TRUE),
    olive_oil = stats::rpois(n, 0.8),
    green_leafy_vegetables = stats::rpois(n, 0.8),
    other_vegetables = stats::rpois(n, 1.2),
    berries = stats::rpois(n, 2),
    other_fruit = stats::rpois(n, 5),
    meat = stats::rpois(n, 4),
    fish = stats::rpois(n, 1.2),
    chicken = stats::rpois(n, 2.5),
    cheese = stats::rpois(n, 3),
    butter_cream = stats::rpois(n, 3),
    beans = stats::rpois(n, 1.5),
    whole_grains = stats::rpois(n, 1.6),
    sweets_and_pastries = stats::rpois(n, 4),
    nuts = stats::rpois(n, 2),
    fast_food = stats::rpois(n, 1.2),
    alcohol = ifelse(age < 18, 0L, stats::rpois(n, 3)),
    active_play_minutes = ifelse(preschool, round(stats::rgamma(n, 6, scale = 25)), NA),
    moderate_activity_minutes = ifelse(preschool, NA, round(stats::rgamma(n, 1.3, scale = 90))),
    vigorous_activity_minutes = ifelse(preschool, NA, round(stats::rgamma(n, 1.2, scale = 40))),
    smoking_status = smoking_status,
    years_since_quit = ifelse(!child & smoking_status == "former", round(stats::runif(n, 0, 20), 1), NA),
    current_inhaled_nds = smoking_status != "current" & age >= 13 & pick(0.1),
    secondhand_smoke_home = pick(0.1),
    sleep_hours = round(2 * stats::rnorm(n, ifelse(child, 9.5, 7), 1)) / 2,
    bmi = ifelse(child, NA, round(pmax(exp(stats::rnorm(n, log(28), 0.17)), 18.5), 1)),
    bmi_profile = ifelse(child, NA, "general"),
    bmi_percentile = ifelse(child, round(pmin(pmax(stats::rbeta(n, 2.2, 1.2) * 100, 5), 99.9), 1), NA),
    bmi_percent_of_p95 = NA_real_,
    non_hdl_cholesterol = round(pmax(stats::rnorm(n, ifelse(child, 112, 140), 30), 50)),
    lipid_lowering_treatment = !child & pick(0.2),
    diabetes = diabetes,
    glucose_measure = ifelse(diabetes, "hba1c", ifelse(pick(0.3), "hba1c", "fasting_glucose")),
    glucose_value = NA_real_,
    systolic_bp = round(stats::rnorm(n, ifelse(child, 100 + age, 125), 12)),
    diastolic_bp = round(stats::rnorm(n, ifelse(child, 60 + 0.8 * age, 78), 8)),
    systolic_bp_p90 = ifelse(under_13, round(100 + 1.3 * age), NA),
    systolic_bp_p95 = ifelse(under_13, round(104 + 1.3 * age), NA),
    diastolic_bp_p90 = ifelse(under_13, round(62 + 0.9 * age), NA),
    diastolic_bp_p95 = ifelse(under_13, round(66 + 0.9 * age), NA),
    antihypertensive_treatment = !child & pick(0.2),
    stringsAsFactors = FALSE
  )
  data$bmi_percent_of_p95 <- ifelse(
    child,
    ifelse(data$bmi_percentile >= 95, round(100 + stats::rexp(n, 1 / 10), 1), 85),
    NA
  )
  hba1c <- data$glucose_measure == "hba1c"
  data$glucose_value <- ifelse(
    hba1c,
    ifelse(diabetes, round(pmax(stats::rnorm(n, 7.4, 1), 6.5), 1), round(pmin(stats::rnorm(n, 5.4, 0.4), 6.4), 1)),
    round(pmin(pmax(stats::rnorm(n, 92, 10), 65), 125))
  )

  # Missing values: whole lab panels, single measurements, and status fields.
  no_labs <- pick(0.25)
  data$non_hdl_cholesterol[no_labs] <- NA
  data$glucose_value[no_labs] <- NA
  data$glucose_measure[no_labs & !diabetes] <- NA
  data$diabetes[pick(0.05) & !no_labs & data$glucose_measure == "hba1c"] <- NA
  data$sleep_hours[pick(0.1)] <- NA
  data$bmi[pick(0.1)] <- NA
  data$bmi_percentile[pick(0.1)] <- NA
  data$systolic_bp[pick(0.1)] <- NA
  data$smoking_status[pick(0.08) & age >= 13] <- NA
  data$current_inhaled_nds[pick(0.08)] <- NA
  data
}

# Columns whose observed values must survive imputation unchanged.
le8_rule_violations <- function(completed) {
  status <- as.character(completed$smoking_status)
  nds <- as.logical(as.character(completed$current_inhaled_nds))
  diabetes <- as.logical(as.character(completed$diabetes))
  measure <- as.character(completed$glucose_measure)
  value <- completed$glucose_value
  c(
    dual_use = sum(status == "current" & nds, na.rm = TRUE),
    diabetes_without_hba1c = sum(diabetes & measure != "hba1c", na.rm = TRUE),
    diagnostic_without_diabetes = sum(
      !diabetes & ((measure == "fasting_glucose" & value >= 126) | (measure == "hba1c" & value >= 6.5)),
      na.rm = TRUE
    ),
    hba1c_scale = sum(measure == "hba1c" & value > 20, na.rm = TRUE),
    fasting_scale = sum(measure == "fasting_glucose" & value < 20, na.rm = TRUE)
  )
}
