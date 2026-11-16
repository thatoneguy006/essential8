# Input and output column registry ---------------------------------------------
#
# A single table describes every case-sensitive `score_le8()` input. It drives
# completion of omitted columns, type validation, and the case-mismatch guard,
# so adding an input means adding one entry here. Diet screener and raw-intake
# fields are matched case-insensitively and are resolved by the diet modules.

.le8_input_spec <- function() {
  spec <- list(
    required = "age",
    numeric = c(
      "age_months",
      "moderate_activity_minutes",
      "vigorous_activity_minutes",
      "active_play_minutes",
      "years_since_quit",
      "sleep_hours",
      "bmi",
      "bmi_percentile",
      "bmi_percent_of_p95",
      "infant_weight_percentile",
      "infant_weight_z_change",
      "non_hdl_cholesterol",
      "glucose_value",
      "systolic_bp",
      "diastolic_bp",
      "systolic_bp_p90",
      "systolic_bp_p95",
      "diastolic_bp_p90",
      "diastolic_bp_p95"
    ),
    logical = c(
      "current_inhaled_nds",
      "secondhand_smoke_home",
      "lipid_lowering_treatment",
      "diabetes",
      "antihypertensive_treatment"
    ),
    character = c(
      "smoking_status",
      "bmi_profile",
      "glucose_measure"
    ),
    # Optional caller-adjudicated clinical-judgment flags; absent means FALSE.
    flag = c(
      "apply_lean_muscular_bmi_override",
      "apply_sleep_apnea_penalty",
      "apply_prediabetes_metformin_penalty"
    ),
    # Diet pathway inputs, validated by the diet modules.
    diet = c("diet_value", "dash", "hei2015")
  )
  data.frame(
    column = unlist(spec, use.names = FALSE),
    type = rep(names(spec), lengths(spec)),
    stringsAsFactors = FALSE
  )
}

.le8_inputs_of_type <- function(type) {
  spec <- .le8_input_spec()
  spec$column[spec$type %in% type]
}

.le8_choices <- function() {
  list(
    smoking_status = c("never", "former", "current"),
    bmi_profile = c("general", "asian_pacific"),
    glucose_measure = c("fasting_glucose", "hba1c")
  )
}

.le8_component_score_columns <- function() {
  c(
    "diet_score",
    "physical_activity_score",
    "nicotine_score",
    "sleep_score",
    "bmi_score",
    "blood_lipids_score",
    "blood_glucose_score",
    "blood_pressure_score"
  )
}

# Output names used before 0.4.0, when every score carried the `le8_` prefix.
.le8_legacy_output_columns <- function() {
  c(paste0("le8_", .le8_component_score_columns()), "le8_n_components")
}

# Short component keys ("diet", "bmi", ...) in AHA order, named by score column.
.le8_component_keys <- function() {
  columns <- .le8_component_score_columns()
  stats::setNames(sub("_score$", "", columns), columns)
}

.le8_component_labels <- function() {
  stats::setNames(
    c(
      "Diet",
      "Physical activity",
      "Nicotine exposure",
      "Sleep",
      "BMI",
      "Blood lipids",
      "Blood glucose",
      "Blood pressure"
    ),
    .le8_component_score_columns()
  )
}

.le8_output_columns <- function() {
  c(
    "mepa_total",
    "dash_total",
    "hei2015_total",
    paste0("dash_", .adult_dash_fields(), "_score"),
    paste0("hei2015_", .hei2015_component_names(), "_score"),
    "physical_activity_moderate_equivalent_minutes",
    .le8_component_score_columns(),
    "n_components",
    "le8_composite_score",
    "le8_complete",
    # Reserve pre-rename output names to prevent ambiguous results.
    "le8_score",
    .le8_legacy_output_columns(),
    "le8_category",
    "le8_population"
  )
}

# Preparation ------------------------------------------------------------------

# Validates the structure of `data`, adds typed missing columns for omitted
# inputs, and checks types and categorical values. Domain rules that depend on
# age or on combinations of inputs live in `.check_le8_domains()`.
.prepare_le8_data <- function(data, diet_method) {
  if (!is.data.frame(data)) {
    .abort_input(c(
      "{.arg data} must be a data frame.",
      "x" = "You supplied {.cls {class(data)}}."
    ))
  }

  .check_unique_names(data)
  .check_input_name_case(data)
  .validate_legacy_diet_method(data, diet_method)

  if (!"age" %in% names(data)) {
    .abort_input(c(
      "{.arg data} is missing a required LE8 eligibility column.",
      "x" = "Missing: age."
    ))
  }

  conflicting_columns <- names(data)[
    tolower(names(data)) %in% tolower(.le8_output_columns())
  ]
  if (length(conflicting_columns) > 0L) {
    .abort_input(c(
      "{.arg data} already contains LE8 output columns.",
      "x" = "Conflicting: {paste(conflicting_columns, collapse = ', ')}.",
      "i" = "Rename or remove these columns before scoring."
    ))
  }

  data <- .complete_le8_data(data)

  for (column in .le8_inputs_of_type(c("required", "numeric"))) {
    .check_numeric_column(data, column, allow_missing = column != "age")
  }
  for (column in .le8_inputs_of_type("logical")) {
    .check_logical_column(data, column)
  }
  for (column in intersect(.le8_inputs_of_type("flag"), names(data))) {
    .check_logical_column(data, column)
  }
  choices <- .le8_choices()
  for (column in names(choices)) {
    .check_character_column(data, column)
    .check_choices(data[[column]], column, choices[[column]])
  }

  as.data.frame(data, stringsAsFactors = FALSE)
}

.check_unique_names <- function(data) {
  duplicated_columns <- unique(names(data)[duplicated(tolower(names(data)))])
  if (length(duplicated_columns) > 0L) {
    .abort_input(c(
      "{.arg data} must have unique column names.",
      "x" = "Duplicated after case normalization: {paste(duplicated_columns, collapse = ', ')}."
    ))
  }
}

# A column differing from a known input only by case (e.g., `BMI`) would
# otherwise be ignored and silently scored as missing.
.check_input_name_case <- function(data) {
  known_inputs <- .le8_input_spec()$column
  case_mismatches <- names(data)[
    tolower(names(data)) %in% known_inputs & !names(data) %in% known_inputs
  ]
  if (length(case_mismatches) > 0L) {
    renames <- paste0(case_mismatches, " -> ", tolower(case_mismatches))
    .abort_input(c(
      "LE8 input column names are case-sensitive.",
      "x" = "Rename: {paste(renames, collapse = ', ')}.",
      "i" = "Otherwise these columns would be ignored and scored as missing."
    ))
  }
}

.validate_legacy_diet_method <- function(data, diet_method) {
  index <- match("diet_method", tolower(names(data)))
  if (is.na(index)) {
    return(invisible(NULL))
  }

  column <- names(data)[index]
  .check_character_column(data, column)
  if (anyNA(data[[column]])) {
    .abort_input(
      "Legacy {.field {column}} values must be complete when the column is supplied."
    )
  }
  legacy_method <- tolower(trimws(as.character(data[[column]])))
  .check_choices(legacy_method, column, .le8_diet_methods())

  if (any(legacy_method != diet_method)) {
    .abort_input(c(
      "{.field {column}} conflicts with {.arg diet_method}.",
      "x" = "A single diet method must apply to every row in one call.",
      "i" = "Remove the legacy column and pass {.arg diet_method} directly."
    ))
  }

  invisible(NULL)
}

# Omitted inputs become typed missing columns so every scorer can assume they
# exist. A column that is entirely missing is often read as logical NA (for
# example, a blank CSV column); it is coerced to the column's declared type.
.complete_le8_data <- function(data) {
  numeric_columns <- c(.le8_inputs_of_type("numeric"), "diet_value")
  character_columns <- .le8_inputs_of_type("character")

  for (column in intersect(numeric_columns, names(data))) {
    data[[column]] <- .coerce_all_na_logical(data[[column]], "numeric")
  }
  for (column in intersect(character_columns, names(data))) {
    data[[column]] <- .coerce_all_na_logical(data[[column]], "character")
  }

  n <- nrow(data)
  for (column in setdiff(numeric_columns, names(data))) {
    data[[column]] <- rep(NA_real_, n)
  }
  for (column in setdiff(.le8_inputs_of_type("logical"), names(data))) {
    data[[column]] <- rep(NA, n)
  }
  for (column in setdiff(character_columns, names(data))) {
    data[[column]] <- rep(NA_character_, n)
  }

  data
}

.coerce_all_na_logical <- function(value, to = c("numeric", "character")) {
  to <- match.arg(to)
  if (is.logical(value) && is.null(dim(value)) && all(is.na(value))) {
    return(if (to == "numeric") as.numeric(value) else as.character(value))
  }
  value
}

.optional_flag <- function(data, column) {
  if (!column %in% names(data)) {
    return(rep(FALSE, nrow(data)))
  }
  data[[column]]
}
