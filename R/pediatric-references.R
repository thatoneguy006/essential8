#' Add pediatric growth-chart and blood-pressure reference values
#'
#' @description
#' Derives the reference inputs that [score_le8()] needs for pediatric BMI and
#' blood-pressure scoring from raw measurements:
#'
#' * `bmi_percentile` and `bmi_percent_of_p95` (ages 2 to 19): CDC 2000
#'   BMI-for-age percentile, using the CDC extended BMI method above the 95th
#'   percentile, and BMI as a percentage of the 95th percentile, from
#'   [cdcanthro::cdc_z()].
#' * `infant_weight_z` and `infant_weight_percentile` (under age 2): WHO
#'   weight-for-length (or BMI-for-age) z-score and percentile, from
#'   [cdcanthro::who_z()].
#' * `systolic_bp_p90`, `systolic_bp_p95`, `diastolic_bp_p90`, and
#'   `diastolic_bp_p95` (ages 1 to 12): the AAP 2017 (Flynn et al.) 90th and
#'   95th blood-pressure percentiles for the child's age, sex, and height, from
#'   [pedbp::q_bp()].
#'
#' Requires the suggested packages \pkg{cdcanthro} (for growth charts) and
#' \pkg{pedbp} (for blood pressure); each is needed only when `data` contains
#' rows of the corresponding ages. Values are left missing outside the stated
#' ages and wherever a required measurement is missing. In particular, the
#' blood-pressure references are not computed without height: \pkg{pedbp}
#' would otherwise assume a median-height child.
#'
#' `infant_weight_z_change`, the change in the infant z-score since the prior
#' routine visit, needs longitudinal data and is not derived here. Compute it
#' from `infant_weight_z` within each child; see
#' `vignette("pediatric-scoring")`.
#'
#' @param data A data frame. Rows aged 20 or older are returned unchanged.
#' @param sex Name of the sex column: `"m"`/`"f"`, `"male"`/`"female"`, or
#'   `0`/`1` (0 = male), or a logical column named `female`.
#' @param height Name of the column holding height in cm (recumbent length
#'   before age 2).
#' @param weight Name of the column holding weight in kg.
#' @param bmi Optional name of a BMI column in kg/m^2. When `NULL` (the
#'   default), BMI is calculated from `weight` and `height`.
#' @param age_months Optional name of a column holding age in months. When
#'   `NULL`, observed `age_months` values take precedence. Missing months
#'   use `age * 12` when age in years is available.
#' @param completed_months If `FALSE` (the default), ages are exact, so
#'   54 months means exactly 4.5 years. If `TRUE`, ages are completed months
#'   (as in NHANES) and 0.5 is added before every reference lookup. Unlike
#'   calling \pkg{cdcanthro} directly, whose midpoint adjustment depends on
#'   whether every age in the batch is a whole number, the result for one row
#'   never depends on the other rows.
#' @param infant_measure Under age 2, `"weight_for_length"` (the default, the
#'   more common clinical measure) or `"bmi_for_age"`; AHA 2022 accepts either.
#' @param bp_source The \pkg{pedbp} blood-pressure reference. The default,
#'   `"flynn2017"`, is the AAP 2017 guideline that LE8 cites.
#'
#' @return `data`, with the eight reference columns described above appended.
#'   It is an error for `data` to contain any of them already.
#'
#' @references
#' Lloyd-Jones DM, Allen NB, Anderson CAM, et al. (2022). Life's Essential 8.
#' *Circulation*, 146(5), e18-e43. \doi{10.1161/CIR.0000000000001078}
#'
#' Flynn JT, Kaelber DC, Baker-Smith CM, et al. (2017). Clinical Practice
#' Guideline for Screening and Management of High Blood Pressure in Children
#' and Adolescents. *Pediatrics*, 140(3), e20171904.
#' \doi{10.1542/peds.2017-1904}
#'
#' Wei R, Ogden CL, Parsons VL, Freedman DS, Hales CM (2020). A method for
#' calculating BMI z-scores and percentiles above the 95th percentile of the
#' CDC growth charts. *Annals of Human Biology*, 47(6), 514-521.
#' \doi{10.1080/03014460.2020.1808065}
#'
#' @seealso [score_le8()]
#'
#' @examplesIf requireNamespace("cdcanthro", quietly = TRUE) && requireNamespace("pedbp", quietly = TRUE)
#' children <- data.frame(
#'   id = c("a", "b"),
#'   age = c(5.5, 14),
#'   sex = c("female", "male"),
#'   height_cm = c(112, 165),
#'   weight_kg = c(19, 70)
#' )
#' add_pediatric_references(children)
#'
#' @export
add_pediatric_references <- function(
  data,
  sex = "sex",
  height = "height_cm",
  weight = "weight_kg",
  bmi = NULL,
  age_months = NULL,
  completed_months = FALSE,
  infant_measure = c("weight_for_length", "bmi_for_age"),
  bp_source = "flynn2017"
) {
  if (!is.data.frame(data)) {
    .abort_input("{.arg data} must be a data frame.")
  }
  infant_measure <- match.arg(infant_measure)
  if (!is.character(bp_source) || length(bp_source) != 1L || is.na(bp_source)) {
    .abort_input("{.arg bp_source} must be a single string.")
  }

  outputs <- .pediatric_reference_columns()
  existing <- intersect(tolower(outputs), tolower(names(data)))
  if (length(existing) > 0L) {
    .abort_input(c(
      "{.arg data} already contains pediatric reference columns.",
      "x" = "Existing: {paste(existing, collapse = ', ')}."
    ))
  }

  if (!is.logical(completed_months) || length(completed_months) != 1L ||
      is.na(completed_months)) {
    .abort_input("{.arg completed_months} must be {.val TRUE} or {.val FALSE}.")
  }
  months <- .reference_age_months(data, age_months)
  if (completed_months) {
    months <- months + 0.5
  }
  sex_value <- .normalize_sex(
    .reference_column(data, sex, "sex"), sex, label = "Sex field"
  )
  height_cm <- .reference_measurement(data, height, "height")
  weight_kg <- .reference_measurement(data, weight, "weight", required = FALSE)
  bmi_value <- if (is.null(bmi)) {
    weight_kg / (height_cm / 100)^2
  } else {
    .reference_measurement(data, bmi, "bmi")
  }

  n <- nrow(data)
  reference <- stats::setNames(
    replicate(length(outputs), rep(NA_real_, n), simplify = FALSE),
    outputs
  )
  known <- !is.na(sex_value) & !is.na(months)

  growth_chart <- which(known & months >= 24 & months < 240 & !is.na(bmi_value))
  if (length(growth_chart) > 0L) {
    bmi_reference <- .cdc_bmi_reference(
      sex_value[growth_chart], months[growth_chart], bmi_value[growth_chart]
    )
    reference$bmi_percentile[growth_chart] <- bmi_reference$percentile
    reference$bmi_percent_of_p95[growth_chart] <- bmi_reference$percent_of_p95
  }

  infant <- which(known & months < 24)
  if (length(infant) > 0L) {
    infant_z <- .who_infant_weight_z(
      sex_value[infant], months[infant], weight_kg[infant], height_cm[infant],
      bmi_value[infant], infant_measure
    )
    reference$infant_weight_z[infant] <- infant_z
    reference$infant_weight_percentile[infant] <- 100 * stats::pnorm(infant_z)
  }

  blood_pressure <- which(known & months >= 12 & months < 156 & !is.na(height_cm))
  if (length(blood_pressure) > 0L) {
    bp_reference <- .pedbp_reference(
      sex_value[blood_pressure], months[blood_pressure],
      height_cm[blood_pressure], bp_source
    )
    for (column in names(bp_reference)) {
      reference[[column]][blood_pressure] <- bp_reference[[column]]
    }
  }

  data[outputs] <- reference
  data
}

.pediatric_reference_columns <- function() {
  c(
    "bmi_percentile",
    "bmi_percent_of_p95",
    "infant_weight_z",
    "infant_weight_percentile",
    "systolic_bp_p90",
    "systolic_bp_p95",
    "diastolic_bp_p90",
    "diastolic_bp_p95"
  )
}

.reference_column <- function(data, column, argument) {
  if (!is.character(column) || length(column) != 1L || is.na(column) ||
      !column %in% names(data)) {
    .abort_input(
      "{.arg {argument}} must name a column in {.arg data}."
    )
  }
  data[[column]]
}

.reference_measurement <- function(data, column, argument, required = TRUE) {
  if (!required && !column %in% names(data)) {
    return(rep(NA_real_, nrow(data)))
  }
  value <- .coerce_all_na_logical(
    .reference_column(data, column, argument),
    "numeric"
  )
  check <- stats::setNames(data.frame(value), column)
  .check_numeric_column(check, column)
  if (any(value <= 0, na.rm = TRUE)) {
    .abort_input("{.field {column}} must be greater than 0.")
  }
  value
}

.reference_age_months <- function(data, age_months) {
  if (!is.null(age_months)) {
    months <- .reference_measurement(data, age_months, "age_months")
  } else if ("age_months" %in% names(data)) {
    months <- .reference_measurement(data, "age_months", "age_months")
    missing <- is.na(months)
    if (any(missing) && "age" %in% names(data)) {
      months[missing] <- 12 * .reference_measurement(data[missing, , drop = FALSE], "age", "age")
    }
  } else {
    months <- .reference_measurement(data, "age", "age") * 12
  }
  months
}

.require_reference_package <- function(package, purpose) {
  if (!requireNamespace(package, quietly = TRUE)) {
    .abort_input(c(
      "Package {.pkg {package}} is required for {purpose}.",
      "i" = "Install it with {.code install.packages(\"{package}\")}, or supply the reference columns yourself."
    ))
  }
}

.cdc_bmi_reference <- function(sex, months, bmi) {
  .require_reference_package("cdcanthro", "CDC BMI-for-age percentiles")
  input <- data.frame(
    sex = ifelse(sex == "male", 1L, 2L),
    agemos = months,
    bmi = bmi
  )
  # cdc_z() adds 0.5 months when every age in a batch is a whole number. A
  # fractional-age sentinel row (dropped below) keeps ages as supplied, so
  # one row's result never depends on the other rows.
  input <- rbind(input, data.frame(sex = 1L, agemos = 100.25, bmi = NA_real_))
  output <- cdcanthro::cdc_z(input, age = "agemos", bmi = "bmi")
  keep <- seq_len(nrow(input) - 1L)
  list(
    percentile = as.numeric(output$bmip[keep]),
    percent_of_p95 = as.numeric(output$bmip95[keep])
  )
}

.who_infant_weight_z <- function(sex, months, weight, length, bmi, measure) {
  .require_reference_package("cdcanthro", "WHO infant growth standards")
  input <- data.frame(
    sex = ifelse(sex == "male", 1L, 2L),
    agedays = round(months * 30.4375)
  )
  if (measure == "weight_for_length") {
    input$wt <- weight
    input$lenhei <- length
    output <- cdcanthro::who_z(input, agedays = "agedays", wt = "wt",
                               lenhei = "lenhei")
    return(as.numeric(output$who_wflz))
  }
  input$bmi <- bmi
  output <- cdcanthro::who_z(input, agedays = "agedays", bmi = "bmi")
  as.numeric(output$who_bmiz)
}

.pedbp_reference <- function(sex, months, height, source) {
  .require_reference_package("pedbp", "pediatric blood-pressure percentiles")
  male <- as.integer(sex == "male")
  quantiles <- function(p) {
    unclass(pedbp::q_bp(
      p_sbp = rep(p, length(months)),
      p_dbp = rep(p, length(months)),
      age = months,
      male = male,
      height = height,
      source = source
    ))
  }
  p90 <- quantiles(0.90)
  p95 <- quantiles(0.95)
  list(
    systolic_bp_p90 = as.numeric(p90$sbp),
    systolic_bp_p95 = as.numeric(p95$sbp),
    diastolic_bp_p90 = as.numeric(p90$dbp),
    diastolic_bp_p95 = as.numeric(p95$dbp)
  )
}
