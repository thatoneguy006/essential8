# Column validators ------------------------------------------------------------

.check_column_shape <- function(data, column) {
  value <- data[[column]]
  if (!is.null(dim(value)) || length(value) != nrow(data)) {
    .abort_input(
      "{.field {column}} must be a one-dimensional column with one value per row."
    )
  }
}

.check_numeric_column <- function(data, column, allow_missing = TRUE) {
  value <- data[[column]]
  .check_column_shape(data, column)
  if (!is.numeric(value)) {
    .abort_input("{.field {column}} must be numeric.")
  }
  if (!allow_missing && anyNA(value)) {
    .abort_input("{.field {column}} must contain complete values.")
  }
  if (any(!is.finite(value[!is.na(value)]))) {
    .abort_input("Observed values in {.field {column}} must be finite.")
  }
}

.check_logical_column <- function(data, column) {
  .check_column_shape(data, column)
  if (!is.logical(data[[column]])) {
    .abort_input("{.field {column}} must be logical.")
  }
}

.check_character_column <- function(data, column) {
  value <- data[[column]]
  .check_column_shape(data, column)
  if (!is.character(value) && !is.factor(value)) {
    .abort_input("{.field {column}} must be character or factor.")
  }
  observed <- as.character(value[!is.na(value)])
  if (any(trimws(observed) == "")) {
    .abort_input("Observed values in {.field {column}} must not be empty.")
  }
}

.check_choices <- function(value, column, choices) {
  value <- as.character(value)
  unknown <- setdiff(unique(value[!is.na(value)]), choices)
  if (length(unknown) > 0L) {
    .abort_input(c(
      "{.field {column}} contains unsupported values.",
      "x" = "Unsupported: {paste(unknown, collapse = ', ')}.",
      "i" = "Allowed: {paste(choices, collapse = ', ')}."
    ))
  }
}

# Low percentile points can look like proportions. Flag the ambiguity while
# preserving the supplied values and the documented 0-100 scale.
.check_percentile_column <- function(value, column, label = column) {
  if (any(value < 0 | value > 100, na.rm = TRUE)) {
    .abort_input("{.field {column}} must be between 0 and 100.")
  }
  observed <- value[!is.na(value)]
  if (length(observed) && all(observed <= 1) &&
      any(observed > 0 & observed < 1)) {
    .warn_le8(c(
      "{.field {column}} contains only values at or below 1.",
      "i" = "Scoring uses percentile points. Check the units if these are proportions."
    ), class = "essential8_percentile_scale_warning")
  }
}

.validate_min_components <- function(min_components) {
  invalid <- length(min_components) != 1L ||
    anyNA(min_components) ||
    !is.numeric(min_components) ||
    !is.finite(min_components) ||
    min_components %% 1 != 0 ||
    min_components < 1 ||
    min_components > 8

  if (invalid) {
    .abort_input(
      "{.arg min_components} must be a single integer between 1 and 8."
    )
  }

  as.integer(min_components)
}

# Domain rules -----------------------------------------------------------------
#
# Values outside a source-defined measurement domain, and combinations for which
# AHA 2022 defines no score, are errors rather than guesses. Rules are grouped
# by LE8 component and restricted to the rows (adult or pediatric) they govern.

.check_le8_domains <- function(data, age, diet_method) {
  .check_age_domain(data, age)
  .check_activity_domain(data)
  .check_nicotine_domain(data)
  .check_sleep_domain(data)
  .check_bmi_domain(data, age)
  .check_lipid_domain(data)
  .check_glucose_domain(data)
  .check_blood_pressure_domain(data)
  .check_diet_value_domain(data, diet_method)
  invisible(data)
}

.check_age_domain <- function(data, age) {
  if (any(age$months < .le8_minimum_age_months())) {
    .abort_input(c(
      "{.field age} must be at least 4 months.",
      "i" = "AHA 2022 suggests pediatric LE8 scoring from 4 months of age."
    ))
  }
  both <- !is.na(data$age_months)
  if (any(floor(data$age_months[both] / 12) != floor(data$age[both]))) {
    .abort_input(c(
      "{.field age} and {.field age_months} disagree.",
      "i" = "{.field age} is in years and {.field age_months} in months; they must describe the same completed year of age."
    ))
  }
}

.check_activity_domain <- function(data) {
  if (any(data$moderate_activity_minutes < 0, na.rm = TRUE) ||
      any(data$vigorous_activity_minutes < 0, na.rm = TRUE)) {
    .abort_input("Weekly physical-activity minutes cannot be negative.")
  }
  if (any(data$active_play_minutes < 0 | data$active_play_minutes > 1440,
          na.rm = TRUE)) {
    .abort_pediatric(
      "{.field active_play_minutes} must be daily minutes between 0 and 1440."
    )
  }
}

.check_nicotine_domain <- function(data) {
  if (any(data$years_since_quit < 0, na.rm = TRUE)) {
    .abort_input("{.field years_since_quit} cannot be negative.")
  }
  dual_use <- as.character(data$smoking_status) == "current" &
    data$current_inhaled_nds
  if (any(dual_use, na.rm = TRUE)) {
    .abort_input(c(
      "AHA 2022 does not specify precedence for simultaneous current combustible smoking and current inhaled-NDS use.",
      "i" = "Resolve the dual-use state before scoring rather than assuming a tie-break."
    ))
  }
}

.check_sleep_domain <- function(data) {
  if (any(data$sleep_hours < 0 | data$sleep_hours > 24, na.rm = TRUE)) {
    .abort_input("{.field sleep_hours} must be between 0 and 24.")
  }
}

.check_bmi_domain <- function(data, age) {
  adult <- age$adult
  if (any(data$bmi[adult] < 18.5, na.rm = TRUE)) {
    .abort_input(c(
      "BMI values below 18.5 require clinical judgment under AHA 2022.",
      "i" = "This implementation does not guess an underweight score."
    ))
  }

  override <- .optional_flag(data, "apply_lean_muscular_bmi_override")
  valid_override <- as.character(data$bmi_profile) == "general" &
    data$bmi >= 25 & data$bmi < 30
  if (any((override & !valid_override)[adult], na.rm = TRUE)) {
    .abort_input(c(
      "The lean muscular BMI override requires the general BMI profile and BMI from 25 to less than 30.",
      "i" = "Set the flag only after the AHA clinical-judgment condition is met."
    ))
  }
  if (any(override[age$pediatric], na.rm = TRUE)) {
    .abort_pediatric(
      "The lean muscular BMI override is defined only for adults aged 20 or older."
    )
  }

  .check_percentile_column(data$bmi_percentile, "bmi_percentile")
  .check_percentile_column(
    data$infant_weight_percentile, "infant_weight_percentile"
  )
  growth_chart_ages <- .pediatric_ages(age, 24, Inf)
  if (any(data$bmi_percentile[growth_chart_ages] < 5, na.rm = TRUE)) {
    .abort_pediatric(c(
      "BMI percentiles below the 5th require clinical judgment under AHA 2022.",
      "i" = "This implementation does not guess an underweight score."
    ))
  }
  if (any(data$bmi_percent_of_p95 <= 0, na.rm = TRUE)) {
    .abort_pediatric("{.field bmi_percent_of_p95} must be greater than 0.")
  }
}

.check_lipid_domain <- function(data) {
  if (any(data$non_hdl_cholesterol < 0, na.rm = TRUE)) {
    .abort_input("{.field non_hdl_cholesterol} cannot be negative.")
  }
}

.check_glucose_domain <- function(data) {
  if (any(data$glucose_value <= 0, na.rm = TRUE)) {
    .abort_input("{.field glucose_value} must be greater than 0.")
  }

  diabetes <- data$diabetes
  measure <- as.character(data$glucose_measure)
  value <- data$glucose_value
  if (any(diabetes & measure != "hba1c", na.rm = TRUE)) {
    .abort_input(c(
      "Diagnosed diabetes requires an HbA1c value for AHA 2022 scoring.",
      "i" = "Use {.val hba1c} in {.field glucose_measure}."
    ))
  }

  diagnostic_range <- !diabetes & (
    (measure == "fasting_glucose" & value >= 126) |
      (measure == "hba1c" & value >= 6.5)
  )
  if (any(diagnostic_range, na.rm = TRUE)) {
    .abort_input(c(
      "The AHA table does not score a diagnostic-range glucose value with no diabetes diagnosis.",
      "i" = "Reconcile {.field diabetes} and the laboratory value before scoring."
    ))
  }

  penalty <- .optional_flag(data, "apply_prediabetes_metformin_penalty")
  if (any(penalty & !.is_normoglycemic(diabetes, measure, value),
          na.rm = TRUE)) {
    .abort_input(c(
      "The optional prediabetes/metformin penalty requires a normoglycemic value and no diabetes diagnosis.",
      "i" = "Set the flag only after every caller-attested AHA condition is met."
    ))
  }
}

.is_normoglycemic <- function(diabetes, measure, value) {
  !diabetes & (
    (measure == "fasting_glucose" & value < 100) |
      (measure == "hba1c" & value < 5.7)
  )
}

.check_blood_pressure_domain <- function(data) {
  if (any(data$systolic_bp <= 0, na.rm = TRUE) ||
      any(data$diastolic_bp <= 0, na.rm = TRUE)) {
    .abort_input("Blood-pressure values must be greater than 0.")
  }
  references <- c(
    "systolic_bp_p90", "systolic_bp_p95", "diastolic_bp_p90", "diastolic_bp_p95"
  )
  if (any(vapply(data[references], function(x) any(x <= 0, na.rm = TRUE),
                 logical(1)))) {
    .abort_pediatric("Blood-pressure reference percentiles must be greater than 0.")
  }
  if (any(data$systolic_bp_p90 > data$systolic_bp_p95, na.rm = TRUE) ||
      any(data$diastolic_bp_p90 > data$diastolic_bp_p95, na.rm = TRUE)) {
    .abort_pediatric(
      "Each 90th-percentile blood-pressure reference must not exceed the matching 95th percentile."
    )
  }
}

.check_diet_value_domain <- function(data, diet_method) {
  .check_column_shape(data, "diet_value")
  if (diet_method == "mepa" && any(!is.na(data$diet_value))) {
    .abort_input(c(
      "MEPA data must not supply a precomputed {.field diet_value}.",
      "i" = "Provide the raw MEPA screener responses; the package derives {.field mepa_total}."
    ))
  }
}
