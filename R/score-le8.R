#' Score Life's Essential 8 cardiovascular health
#'
#' @description
#' Computes the eight adult Life's Essential 8 (LE8) component scores and
#' their unweighted mean using the American Heart Association's 2022
#' Presidential Advisory. This initial implementation requires complete data
#' for every required input and applies only to adults aged 20 years or older.
#'
#' @param data A data frame with one row per adult and the required columns
#'   described below.
#' @param diet_method A single diet-scoring method applied to every row in
#'   `data`: `"mepa"` (the default) or `"percentile"`. Values are matched
#'   case-insensitively. Score data that use different methods in separate
#'   calls.
#' @param mepa_columns `NULL`, or a named character vector mapping canonical
#'   MEPA fields to columns in `data`. The names are canonical fields and the
#'   values are actual column names. Unmapped fields use their canonical names.
#'
#' @section Required columns:
#' * `age`: Age in years; must be at least 20.
#' * For `diet_method = "mepa"`, the 16 Table C screener-item columns named
#'   below and `sex` (or `female` when `sex` is absent).
#'   The item names are matched exactly after case normalization. Supply daily
#'   servings in `olive_oil`, `green_leafy_vegetables`, `other_vegetables`, and
#'   `whole_grains`; supply weekly servings or frequency in `berries`,
#'   `other_fruit`, `meat`, `fish`, `chicken`, `cheese`, `butter_cream`,
#'   `beans`, `sweets_and_pastries`, `nuts`, and `alcohol`; supply the number
#'   of times per week that fast-food meals are consumed in `fast_food`.
#'   Sex may be encoded as `"m"`/`"f"`, `"male"`/`"female"`, or `0`/`1`,
#'   where `0` is male and `1` is female. Character encodings are matched
#'   case-insensitively, and character `"0"`/`"1"` values are also accepted.
#' * `diet_value`: Required only when `diet_method = "percentile"`. Supply a
#'   DASH or HEI-2015 percentile from 1 to 100, calculated against the relevant
#'   reference distribution. The function does not rank supplied rows against
#'   one another. If this column is present for MEPA data, all its values must
#'   be missing.
#' * `moderate_activity_minutes` and `vigorous_activity_minutes`: Weekly
#'   minutes. Each vigorous minute counts as two moderate-equivalent minutes.
#' * `smoking_status`: One of `"never"`, `"former"`, or `"current"`.
#' * `years_since_quit`: Years since quitting combustible tobacco. This is
#'   used only when `smoking_status` is `"former"`.
#' * `current_inhaled_nds`: Whether an inhaled nicotine-delivery system is
#'   currently used.
#' * `secondhand_smoke_home`: Whether the adult lives with an active indoor
#'   smoker.
#' * `sleep_hours`: Average hours of sleep per night.
#' * `bmi`: Body mass index in kg/m^2. Values below 18.5 are not scored because
#'   the AHA advisory defers to clinician judgment for underweight adults.
#' * `bmi_profile`: Either `"general"` or `"asian_pacific"`. The function
#'   never infers a profile from race or ethnicity.
#' * `non_hdl_cholesterol`: Non-HDL cholesterol in mg/dL.
#' * `lipid_lowering_treatment`: Whether the lipid value is drug treated.
#' * `diabetes`: Whether diabetes has been diagnosed.
#' * `glucose_measure`: Either `"fasting_glucose"` or `"hba1c"`.
#' * `glucose_value`: Fasting glucose in mg/dL or HbA1c in percent, as named
#'   by `glucose_measure`. Diagnosed diabetes requires HbA1c. A record with no
#'   diabetes diagnosis but a value in the diagnostic diabetes range is
#'   rejected because the AHA scoring table does not assign that combination.
#' * `systolic_bp` and `diastolic_bp`: Blood pressure in mm Hg.
#' * `antihypertensive_treatment`: Whether the blood pressure is treated.
#'
#' @section Optional clinical-judgment columns:
#' * `apply_lean_muscular_bmi_override`: A caller-adjudicated flag asserting
#'   that a lean, higher-muscle-mass adult in the general BMI profile has a BMI
#'   from 25 to less than 30 and should receive 100 BMI points. If absent, the
#'   standard BMI band is used.
#' * `apply_sleep_apnea_penalty`: If `TRUE`, subtract 20 points for untreated
#'   or undertreated sleep apnea. If absent, no discretionary penalty is
#'   applied.
#' * `apply_prediabetes_metformin_penalty`: A caller-adjudicated flag asserting
#'   that the adult has a history of prediabetes, is taking metformin to
#'   prevent diabetes, is currently normoglycemic, and the clinician chose to
#'   apply the AHA's discretionary 20-point decrement. If absent, no
#'   discretionary penalty is applied.
#'
#' @section Source-constrained behavior:
#' The function derives the 0-to-16 MEPA total from the 16 raw screener
#' responses. For population scoring, callers must supply a
#' DASH or HEI-2015 percentile calculated against the relevant reference
#' population; the rows in `data` are not their own reference distribution.
#'
#' The AHA table applies 20-point treatment decrements to blood-lipid and
#' blood-pressure scores. These components are floored at zero, consistent
#' with the AHA's 0-to-100 metric definition and the non-negative possible
#' scores shown in its applied NHANES implementation. Optional sleep-apnea and
#' prediabetes/metformin decrements are applied only through explicit flags.
#' Inputs are not rounded. The documented MEPA daily/weekly equivalences are
#' applied where the source question and criterion use different timeframes.
#' Combinations without a source-defined score, including simultaneous current
#' combustible smoking and current inhaled-NDS use, produce a structured error.
#'
#' @return
#' A data frame containing the original columns plus
#' `mepa_total` (missing for population-percentile rows),
#' `physical_activity_moderate_equivalent_minutes`, the eight component score
#' columns prefixed with `le8_`, `le8_composite_score`, and `le8_category`.
#' The composite score is the exact, unrounded mean. Categories are `"low"`
#' for scores below 50, `"moderate"` for scores from 50 to less than 80, and
#' `"high"` for scores of at least 80.
#'
#' @references
#' Lloyd-Jones DM, Allen NB, Anderson CAM, et al. (2022). Life's Essential 8:
#' Updating and Enhancing the American Heart Association's Construct of
#' Cardiovascular Health. *Circulation*, 146(5), e18-e43.
#' \doi{10.1161/CIR.0000000000001078}
#'
#' Lloyd-Jones DM, Ning H, Labarthe D, et al. (2022). Status of Cardiovascular
#' Health in US Adults and Children Using the American Heart Association's New
#' Life's Essential 8 Metrics. *Circulation*, 146(11), 822-835.
#' \doi{10.1161/CIRCULATIONAHA.122.060911}
#'
#' @examples
#' patient <- data.frame(
#'   id = "patient_1",
#'   age = 55,
#'   sex = "female",
#'   # Daily servings
#'   olive_oil = 2,
#'   green_leafy_vegetables = 1,
#'   other_vegetables = 2,
#'   whole_grains = 2,
#'   # Weekly servings
#'   berries = 3,
#'   other_fruit = 5,
#'   meat = 2,
#'   fish = 3,
#'   chicken = 2,
#'   cheese = 1,
#'   butter_cream = 1,
#'   beans = 3,
#'   sweets_and_pastries = 1,
#'   nuts = 4,
#'   alcohol = 4,
#'   # Fast-food meals per week
#'   fast_food = 0,
#'   moderate_activity_minutes = 90,
#'   vigorous_activity_minutes = 0,
#'   smoking_status = "former",
#'   years_since_quit = 6,
#'   current_inhaled_nds = FALSE,
#'   secondhand_smoke_home = FALSE,
#'   sleep_hours = 7.5,
#'   bmi = 27.5,
#'   bmi_profile = "general",
#'   non_hdl_cholesterol = 145,
#'   lipid_lowering_treatment = FALSE,
#'   diabetes = FALSE,
#'   glucose_measure = "fasting_glucose",
#'   glucose_value = 95,
#'   systolic_bp = 128,
#'   diastolic_bp = 78,
#'   antihypertensive_treatment = FALSE
#' )
#'
#' scores <- score_le8(patient, diet_method = "mepa")
#' scores[
#'   c(
#'     "id",
#'     "mepa_total",
#'     "le8_diet_score",
#'     "le8_composite_score",
#'     "le8_category"
#'   )
#' ]
#'
#' @export
score_le8 <- function(data, diet_method = "mepa", mepa_columns = NULL) {
  diet_method <- .normalize_adult_diet_method(diet_method)
  data <- .validate_le8_adult_data(data, diet_method)

  sleep_apnea_penalty <- .optional_adult_flag(
    data,
    "apply_sleep_apnea_penalty"
  )
  prediabetes_metformin_penalty <- .optional_adult_flag(
    data,
    "apply_prediabetes_metformin_penalty"
  )
  lean_muscular_bmi_override <- .optional_adult_flag(
    data,
    "apply_lean_muscular_bmi_override"
  )

  diet_methods <- rep(diet_method, nrow(data))
  smoking_status <- as.character(data$smoking_status)
  bmi_profile <- as.character(data$bmi_profile)
  glucose_measure <- as.character(data$glucose_measure)

  activity_minutes <- data$moderate_activity_minutes +
    2 * data$vigorous_activity_minutes

  mepa_rows <- diet_methods == "mepa"
  percentile_rows <- diet_methods == "percentile"
  mepa_total <- .compute_adult_mepa_total(
    data = data,
    rows = mepa_rows,
    mepa_columns = mepa_columns,
    require_schema = diet_method == "mepa"
  )
  diet_value <- rep(NA_real_, nrow(data))
  diet_value[mepa_rows] <- mepa_total[mepa_rows]
  if (any(percentile_rows)) {
    diet_value[percentile_rows] <- data$diet_value[percentile_rows]
  }
  diet_score <- .score_adult_diet(method = diet_methods, value = diet_value)
  physical_activity_score <- .score_adult_physical_activity(
    activity_minutes
  )
  nicotine_score <- .score_adult_nicotine(
    smoking_status = smoking_status,
    years_since_quit = data$years_since_quit,
    current_inhaled_nds = data$current_inhaled_nds,
    secondhand_smoke_home = data$secondhand_smoke_home
  )
  sleep_score <- .score_adult_sleep(
    hours = data$sleep_hours,
    apply_apnea_penalty = sleep_apnea_penalty
  )
  bmi_score <- .score_adult_bmi(
    bmi = data$bmi,
    profile = bmi_profile,
    apply_lean_muscular_override = lean_muscular_bmi_override
  )
  blood_lipids_score <- .score_adult_blood_lipids(
    non_hdl = data$non_hdl_cholesterol,
    treated = data$lipid_lowering_treatment
  )
  blood_glucose_score <- .score_adult_blood_glucose(
    diabetes = data$diabetes,
    measure = glucose_measure,
    value = data$glucose_value,
    apply_prevention_penalty = prediabetes_metformin_penalty
  )
  blood_pressure_score <- .score_adult_blood_pressure(
    systolic = data$systolic_bp,
    diastolic = data$diastolic_bp,
    treated = data$antihypertensive_treatment
  )

  score_matrix <- cbind(
    diet_score,
    physical_activity_score,
    nicotine_score,
    sleep_score,
    bmi_score,
    blood_lipids_score,
    blood_glucose_score,
    blood_pressure_score
  )
  le8_composite_score <- rowMeans(score_matrix)
  le8_category <- character(length(le8_composite_score))
  le8_category[le8_composite_score < 50] <- "low"
  le8_category[
    le8_composite_score >= 50 & le8_composite_score < 80
  ] <- "moderate"
  le8_category[le8_composite_score >= 80] <- "high"

  scores <- data.frame(
    mepa_total = mepa_total,
    physical_activity_moderate_equivalent_minutes = activity_minutes,
    le8_diet_score = diet_score,
    le8_physical_activity_score = physical_activity_score,
    le8_nicotine_score = nicotine_score,
    le8_sleep_score = sleep_score,
    le8_bmi_score = bmi_score,
    le8_blood_lipids_score = blood_lipids_score,
    le8_blood_glucose_score = blood_glucose_score,
    le8_blood_pressure_score = blood_pressure_score,
    le8_composite_score = le8_composite_score,
    le8_category = le8_category,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  cbind(data, scores)
}

.le8_adult_required_columns <- function() {
  c(
    "age",
    "moderate_activity_minutes",
    "vigorous_activity_minutes",
    "smoking_status",
    "years_since_quit",
    "current_inhaled_nds",
    "secondhand_smoke_home",
    "sleep_hours",
    "bmi",
    "bmi_profile",
    "non_hdl_cholesterol",
    "lipid_lowering_treatment",
    "diabetes",
    "glucose_measure",
    "glucose_value",
    "systolic_bp",
    "diastolic_bp",
    "antihypertensive_treatment"
  )
}

.le8_adult_output_columns <- function() {
  c(
    "mepa_total",
    "physical_activity_moderate_equivalent_minutes",
    "le8_diet_score",
    "le8_physical_activity_score",
    "le8_nicotine_score",
    "le8_sleep_score",
    "le8_bmi_score",
    "le8_blood_lipids_score",
    "le8_blood_glucose_score",
    "le8_blood_pressure_score",
    "le8_composite_score",
    # Reserve the pre-rename output name to prevent ambiguous results.
    "le8_score",
    "le8_category"
  )
}

.normalize_adult_diet_method <- function(diet_method) {
  supported_type <- is.character(diet_method) || is.factor(diet_method)
  if (!supported_type || length(diet_method) != 1L || anyNA(diet_method)) {
    .abort_adult_scoring(c(
      "{.arg diet_method} must be one complete string.",
      "i" = "Choose {.val mepa} or {.val percentile}."
    ))
  }

  normalized <- tolower(trimws(as.character(diet_method)))
  if (!nzchar(normalized)) {
    .abort_adult_scoring(
      "{.arg diet_method} must not be empty."
    )
  }

  .validate_adult_choices(
    normalized,
    "diet_method",
    c("mepa", "percentile")
  )
  normalized
}

.validate_legacy_adult_diet_method <- function(data, diet_method) {
  index <- match("diet_method", tolower(names(data)))
  if (is.na(index)) {
    return(invisible(NULL))
  }

  column <- names(data)[index]
  .validate_adult_character_column(data, column)
  legacy_method <- tolower(trimws(as.character(data[[column]])))
  .validate_adult_choices(
    legacy_method,
    column,
    c("mepa", "percentile")
  )

  if (any(legacy_method != diet_method)) {
    .abort_adult_scoring(c(
      "{.field {column}} conflicts with {.arg diet_method}.",
      "x" = "A single diet method must apply to every row in one call.",
      "i" = "Remove the legacy column and pass {.arg diet_method} directly."
    ))
  }

  invisible(NULL)
}

.validate_le8_adult_data <- function(data, diet_method) {
  if (!is.data.frame(data)) {
    .abort_adult_scoring(c(
      "{.arg data} must be a data frame.",
      "x" = "You supplied {.cls {class(data)}}."
    ))
  }

  normalized_names <- tolower(names(data))
  duplicated_columns <- unique(
    names(data)[duplicated(normalized_names)]
  )
  if (length(duplicated_columns) > 0L) {
    .abort_adult_scoring(c(
      "{.arg data} must have unique column names.",
      "x" = "Duplicated after case normalization: {paste(duplicated_columns, collapse = ', ')}."
    ))
  }

  .validate_legacy_adult_diet_method(data, diet_method)

  missing_columns <- setdiff(.le8_adult_required_columns(), names(data))
  if (length(missing_columns) > 0L) {
    .abort_adult_scoring(c(
      "{.arg data} is missing required adult LE8 columns.",
      "x" = "Missing: {paste(missing_columns, collapse = ', ')}."
    ))
  }

  conflicting_columns <- names(data)[
    tolower(names(data)) %in% tolower(.le8_adult_output_columns())
  ]
  if (length(conflicting_columns) > 0L) {
    .abort_adult_scoring(c(
      "{.arg data} already contains adult LE8 output columns.",
      "x" = "Conflicting: {paste(conflicting_columns, collapse = ', ')}."
    ))
  }

  numeric_columns <- c(
    "age",
    "moderate_activity_minutes",
    "vigorous_activity_minutes",
    "years_since_quit",
    "sleep_hours",
    "bmi",
    "non_hdl_cholesterol",
    "glucose_value",
    "systolic_bp",
    "diastolic_bp"
  )
  for (column in numeric_columns) {
    .validate_adult_numeric_column(data, column)
  }

  logical_columns <- c(
    "current_inhaled_nds",
    "secondhand_smoke_home",
    "lipid_lowering_treatment",
    "diabetes",
    "antihypertensive_treatment"
  )
  for (column in logical_columns) {
    .validate_adult_logical_column(data, column)
  }

  optional_flags <- c(
    "apply_lean_muscular_bmi_override",
    "apply_sleep_apnea_penalty",
    "apply_prediabetes_metformin_penalty"
  )
  for (column in intersect(optional_flags, names(data))) {
    .validate_adult_logical_column(data, column)
  }

  character_columns <- c(
    "smoking_status",
    "bmi_profile",
    "glucose_measure"
  )
  for (column in character_columns) {
    .validate_adult_character_column(data, column)
  }

  .validate_adult_choices(
    data$smoking_status,
    "smoking_status",
    c("never", "former", "current")
  )
  .validate_adult_choices(
    data$bmi_profile,
    "bmi_profile",
    c("general", "asian_pacific")
  )
  .validate_adult_choices(
    data$glucose_measure,
    "glucose_measure",
    c("fasting_glucose", "hba1c")
  )

  if (any(data$age < 20)) {
    .abort_adult_scoring(
      "{.field age} must be at least 20 for adult AHA scoring."
    )
  }
  if (any(data$moderate_activity_minutes < 0) ||
      any(data$vigorous_activity_minutes < 0)) {
    .abort_adult_scoring(
      "Weekly physical-activity minutes cannot be negative."
    )
  }
  if (any(data$years_since_quit < 0)) {
    .abort_adult_scoring(
      "{.field years_since_quit} cannot be negative."
    )
  }

  smoking_status <- as.character(data$smoking_status)
  if (any(smoking_status == "current" & data$current_inhaled_nds)) {
    .abort_adult_scoring(c(
      "AHA 2022 does not specify precedence for simultaneous current combustible smoking and current inhaled-NDS use.",
      "i" = "Resolve the dual-use state before scoring rather than assuming a tie-break."
    ))
  }
  if (any(data$sleep_hours < 0 | data$sleep_hours > 24)) {
    .abort_adult_scoring(
      "{.field sleep_hours} must be between 0 and 24."
    )
  }
  if (any(data$bmi < 18.5)) {
    .abort_adult_scoring(c(
      "BMI values below 18.5 require clinical judgment under AHA 2022.",
      "i" = "This implementation does not guess an underweight score."
    ))
  }

  bmi_profile <- as.character(data$bmi_profile)
  lean_muscular_bmi_override <- .optional_adult_flag(
    data,
    "apply_lean_muscular_bmi_override"
  )
  valid_lean_muscular_override <-
    bmi_profile == "general" & data$bmi >= 25 & data$bmi < 30
  if (any(lean_muscular_bmi_override & !valid_lean_muscular_override)) {
    .abort_adult_scoring(c(
      "The lean muscular BMI override requires the general BMI profile and BMI from 25 to less than 30.",
      "i" = "Set the flag only after the AHA clinical-judgment condition is met."
    ))
  }
  if (any(data$non_hdl_cholesterol < 0)) {
    .abort_adult_scoring(
      "{.field non_hdl_cholesterol} cannot be negative."
    )
  }
  if (any(data$glucose_value <= 0)) {
    .abort_adult_scoring(
      "{.field glucose_value} must be greater than 0."
    )
  }
  if (any(data$systolic_bp <= 0) || any(data$diastolic_bp <= 0)) {
    .abort_adult_scoring(
      "Blood-pressure values must be greater than 0."
    )
  }

  mepa <- diet_method == "mepa"
  percentile <- diet_method == "percentile"
  if (percentile && !"diet_value" %in% names(data)) {
    .abort_adult_scoring(c(
      "Population-percentile scoring requires {.field diet_value}.",
      "i" = "Supply a DASH or HEI-2015 percentile from 1 to 100."
    ))
  }
  if ("diet_value" %in% names(data)) {
    if (!is.numeric(data$diet_value)) {
      .abort_adult_scoring(
        "Percentile {.field diet_value} must be numeric."
      )
    }
    if (mepa && any(!is.na(data$diet_value))) {
      .abort_adult_scoring(c(
        "MEPA data must not supply a precomputed {.field diet_value}.",
        "i" = "Provide the 16 raw MEPA screener responses; the package derives {.field mepa_total}."
      ))
    }
    percentile_value <- data$diet_value[
      rep(percentile, nrow(data))
    ]
    if (anyNA(percentile_value) || any(!is.finite(percentile_value))) {
      .abort_adult_scoring(
        "Percentile {.field diet_value} must be complete and finite."
      )
    }
    if (any(percentile_value < 1 | percentile_value > 100)) {
      .abort_adult_scoring(
        "Percentile {.field diet_value} must be from 1 to 100."
      )
    }
  }

  diabetes <- data$diabetes
  glucose_measure <- as.character(data$glucose_measure)
  if (any(diabetes & glucose_measure != "hba1c")) {
    .abort_adult_scoring(c(
      "Diagnosed diabetes requires an HbA1c value for AHA 2022 scoring.",
      "i" = "Use {.val hba1c} in {.field glucose_measure}."
    ))
  }

  no_diabetes_fbg_range <- !diabetes &
    glucose_measure == "fasting_glucose" &
    data$glucose_value >= 126
  no_diabetes_hba1c_range <- !diabetes &
    glucose_measure == "hba1c" &
    data$glucose_value >= 6.5
  if (any(no_diabetes_fbg_range | no_diabetes_hba1c_range)) {
    .abort_adult_scoring(c(
      "The AHA table does not score a diagnostic-range glucose value with no diabetes diagnosis.",
      "i" = "Reconcile {.field diabetes} and the laboratory value before scoring."
    ))
  }

  prevention_penalty <- .optional_adult_flag(
    data,
    "apply_prediabetes_metformin_penalty"
  )
  normoglycemic <- !diabetes & (
    (glucose_measure == "fasting_glucose" & data$glucose_value < 100) |
      (glucose_measure == "hba1c" & data$glucose_value < 5.7)
  )
  if (any(prevention_penalty & !normoglycemic)) {
    .abort_adult_scoring(c(
      "The optional prediabetes/metformin penalty requires a normoglycemic value and no diabetes diagnosis.",
      "i" = "Set the flag only after every caller-attested AHA condition is met."
    ))
  }

  as.data.frame(data, stringsAsFactors = FALSE)
}

.validate_adult_numeric_column <- function(data, column) {
  value <- data[[column]]
  if (!is.numeric(value)) {
    .abort_adult_scoring(
      "{.field {column}} must be numeric."
    )
  }
  if (anyNA(value) || any(!is.finite(value))) {
    .abort_adult_scoring(c(
      "{.field {column}} must contain complete, finite values.",
      "i" = "Missing-value scoring is not part of this initial implementation."
    ))
  }
}

.validate_adult_logical_column <- function(data, column) {
  value <- data[[column]]
  if (!is.logical(value)) {
    .abort_adult_scoring(
      "{.field {column}} must be logical."
    )
  }
  if (anyNA(value)) {
    .abort_adult_scoring(c(
      "{.field {column}} must not contain missing values.",
      "i" = "Missing-value scoring is not part of this initial implementation."
    ))
  }
}

.validate_adult_character_column <- function(data, column) {
  value <- data[[column]]
  if (!is.character(value) && !is.factor(value)) {
    .abort_adult_scoring(
      "{.field {column}} must be character or factor."
    )
  }
  if (anyNA(value) || any(as.character(value) == "")) {
    .abort_adult_scoring(c(
      "{.field {column}} must contain complete, nonempty values.",
      "i" = "Missing-value scoring is not part of this initial implementation."
    ))
  }
}

.validate_adult_choices <- function(value, column, choices) {
  value <- as.character(value)
  unknown <- setdiff(unique(value), choices)
  if (length(unknown) > 0L) {
    .abort_adult_scoring(c(
      "{.field {column}} contains unsupported values.",
      "x" = "Unsupported: {paste(unknown, collapse = ', ')}.",
      "i" = "Allowed: {paste(choices, collapse = ', ')}."
    ))
  }
}

.optional_adult_flag <- function(data, column) {
  if (!column %in% names(data)) {
    return(rep(FALSE, nrow(data)))
  }
  data[[column]]
}

.score_adult_diet <- function(method, value) {
  score <- numeric(length(value))

  mepa <- method == "mepa"
  score[mepa] <- ifelse(
    value[mepa] >= 15,
    100,
    ifelse(
      value[mepa] >= 12,
      80,
      ifelse(value[mepa] >= 8, 50, ifelse(value[mepa] >= 4, 25, 0))
    )
  )

  percentile <- method == "percentile"
  score[percentile] <- ifelse(
    value[percentile] >= 95,
    100,
    ifelse(
      value[percentile] >= 75,
      80,
      ifelse(
        value[percentile] >= 50,
        50,
        ifelse(value[percentile] >= 25, 25, 0)
      )
    )
  )

  score
}

.score_adult_physical_activity <- function(minutes) {
  ifelse(
    minutes >= 150,
    100,
    ifelse(
      minutes >= 120,
      90,
      ifelse(
        minutes >= 90,
        80,
        ifelse(
          minutes >= 60,
          60,
          ifelse(minutes >= 30, 40, ifelse(minutes > 0, 20, 0))
        )
      )
    )
  )
}

.score_adult_nicotine <- function(
  smoking_status,
  years_since_quit,
  current_inhaled_nds,
  secondhand_smoke_home
) {
  score <- ifelse(
    smoking_status == "never",
    100,
    ifelse(
      smoking_status == "current",
      0,
      ifelse(years_since_quit >= 5, 75, ifelse(years_since_quit >= 1, 50, 25))
    )
  )

  score[current_inhaled_nds & score > 25] <- 25
  score[secondhand_smoke_home & score > 0] <-
    score[secondhand_smoke_home & score > 0] - 20
  score
}

.score_adult_sleep <- function(hours, apply_apnea_penalty) {
  score <- ifelse(
    hours < 4,
    0,
    ifelse(
      hours < 5,
      20,
      ifelse(
        hours < 6,
        40,
        ifelse(
          hours < 7,
          70,
          ifelse(hours < 9, 100, ifelse(hours < 10, 90, 40))
        )
      )
    )
  )

  pmax(0, score - ifelse(apply_apnea_penalty, 20, 0))
}

.score_adult_bmi <- function(
  bmi,
  profile,
  apply_lean_muscular_override = rep(FALSE, length(bmi))
) {
  score <- numeric(length(bmi))

  general <- profile == "general"
  score[general] <- ifelse(
    bmi[general] < 25,
    100,
    ifelse(
      bmi[general] < 30,
      70,
      ifelse(bmi[general] < 35, 30, ifelse(bmi[general] < 40, 15, 0))
    )
  )

  asian_pacific <- profile == "asian_pacific"
  score[asian_pacific] <- ifelse(
    bmi[asian_pacific] < 23,
    100,
    ifelse(
      bmi[asian_pacific] < 25,
      75,
      ifelse(
        bmi[asian_pacific] < 30,
        50,
        ifelse(bmi[asian_pacific] < 35, 25, 0)
      )
    )
  )

  score[apply_lean_muscular_override] <- 100

  score
}

.score_adult_blood_lipids <- function(non_hdl, treated) {
  score <- ifelse(
    non_hdl < 130,
    100,
    ifelse(
      non_hdl < 160,
      60,
      ifelse(non_hdl < 190, 40, ifelse(non_hdl < 220, 20, 0))
    )
  )

  pmax(0, score - ifelse(treated, 20, 0))
}

.score_adult_blood_glucose <- function(
  diabetes,
  measure,
  value,
  apply_prevention_penalty
) {
  score <- numeric(length(value))

  no_diabetes_fbg <- !diabetes & measure == "fasting_glucose"
  score[no_diabetes_fbg] <- ifelse(
    value[no_diabetes_fbg] < 100,
    100,
    60
  )

  no_diabetes_hba1c <- !diabetes & measure == "hba1c"
  score[no_diabetes_hba1c] <- ifelse(
    value[no_diabetes_hba1c] < 5.7,
    100,
    60
  )

  with_diabetes <- diabetes
  score[with_diabetes] <- ifelse(
    value[with_diabetes] < 7,
    40,
    ifelse(
      value[with_diabetes] < 8,
      30,
      ifelse(
        value[with_diabetes] < 9,
        20,
        ifelse(value[with_diabetes] < 10, 10, 0)
      )
    )
  )

  pmax(0, score - ifelse(apply_prevention_penalty, 20, 0))
}

.score_adult_blood_pressure <- function(systolic, diastolic, treated) {
  systolic_score <- ifelse(
    systolic < 120,
    100,
    ifelse(
      systolic < 130,
      75,
      ifelse(systolic < 140, 50, ifelse(systolic < 160, 25, 0))
    )
  )
  diastolic_score <- ifelse(
    diastolic < 80,
    100,
    ifelse(diastolic < 90, 50, ifelse(diastolic < 100, 25, 0))
  )
  score <- pmin(systolic_score, diastolic_score)

  pmax(0, score - ifelse(treated, 20, 0))
}
