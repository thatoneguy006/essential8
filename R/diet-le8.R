# LE8 diet component -----------------------------------------------------------
#
# One diet method applies to every row in a call:
#   * "mepa": individual screeners from one set of MEPA inputs; see
#     `diet-mepa.R` for the age-specific screeners.
#   * "dash" / "hei2015": population indices, from raw intake, a precomputed
#     index, or a percentile in `diet_value`.
#   * "percentile": a percentile in `diet_value` for any population index.

.le8_diet_methods <- function() c("mepa", "dash", "hei2015", "percentile")

.normalize_diet_method <- function(diet_method) {
  supported_type <- is.character(diet_method) || is.factor(diet_method)
  if (!supported_type || length(diet_method) != 1L || anyNA(diet_method)) {
    .abort_input(c(
      "{.arg diet_method} must be one complete string.",
      "i" = "Choose {.val mepa}, {.val dash}, {.val hei2015}, or {.val percentile}."
    ))
  }

  normalized <- tolower(trimws(as.character(diet_method)))
  if (!nzchar(normalized)) {
    .abort_input("{.arg diet_method} must not be empty.")
  }

  .check_choices(normalized, "diet_method", .le8_diet_methods())
  normalized
}

# Method-specific arguments are rejected under other methods so a typo in
# `diet_method` cannot silently ignore them.
.check_diet_arguments <- function(
  diet_method,
  mepa_columns,
  dash_columns,
  dash_cutpoints,
  hei2015_columns,
  hei2015_cutpoints
) {
  if (diet_method != "dash" &&
      (!is.null(dash_columns) || !is.null(dash_cutpoints))) {
    .abort_input("DASH arguments require {.code diet_method = 'dash'}.")
  }
  if (diet_method != "hei2015" &&
      (!is.null(hei2015_columns) || !is.null(hei2015_cutpoints))) {
    .abort_input("HEI-2015 arguments require {.code diet_method = 'hei2015'}.")
  }
  if (diet_method != "mepa" && !is.null(mepa_columns)) {
    .abort_input("MEPA arguments require {.code diet_method = 'mepa'}.")
  }
}

.score_le8_diet <- function(
  data,
  age,
  diet_method,
  input_columns,
  mepa_columns = NULL,
  dash_columns = NULL,
  dash_cutpoints = NULL,
  hei2015_columns = NULL,
  hei2015_cutpoints = NULL,
  reference = "nhanes_2015_2018"
) {
  n <- nrow(data)
  result <- list(
    score = rep(NA_real_, n),
    mepa_total = rep(NA_integer_, n),
    dash_total = rep(NA_integer_, n),
    hei2015_total = rep(NA_real_, n),
    components = NULL
  )

  if (diet_method %in% c("mepa", "percentile") &&
      any(c("dash", "hei2015") %in% input_columns)) {
    .abort_input(c(
      "DASH and HEI-2015 index columns cannot be used with {.code diet_method = '{diet_method}'}.",
      "i" = "Use {.code diet_method = 'dash'} or {.code diet_method = 'hei2015'}, or remove the column."
    ))
  }

  if (diet_method == "mepa") {
    return(.score_mepa_diet(data, age, mepa_columns, result))
  }
  if (diet_method == "percentile") {
    result$score <- .score_diet_percentile(data$diet_value)
    return(result)
  }
  .score_population_diet(
    data, age, diet_method, input_columns, dash_columns, dash_cutpoints,
    hei2015_columns, hei2015_cutpoints, reference, result
  )
}

.score_population_diet <- function(
  data,
  age,
  method,
  input_columns,
  dash_columns,
  dash_cutpoints,
  hei2015_columns,
  hei2015_cutpoints,
  reference,
  result
) {
  other_method <- if (method == "dash") "hei2015" else "dash"
  if (other_method %in% input_columns) {
    .abort_input("{.field {other_method}} is unrelated to {.arg diet_method}.")
  }

  raw_fields <- if (method == "dash") {
    paste0("dash_", c(.adult_dash_fields(), "energy_kcal"))
  } else {
    paste0("hei2015_", .adult_hei2015_fields())
  }
  columns <- if (method == "dash") dash_columns else hei2015_columns
  cutpoints <- if (method == "dash") dash_cutpoints else hei2015_cutpoints
  raw <- !is.null(columns) || !is.null(cutpoints) ||
    any(tolower(input_columns) %in% raw_fields)
  has_index <- method %in% input_columns

  if (raw && (has_index || any(!is.na(data$diet_value)))) {
    .abort_input(
      "Supply either raw intake inputs or a precomputed index/percentile; do not combine them."
    )
  }

  if (raw || has_index) {
    .check_population_reference_ages(age, raw, cutpoints, reference)
  }

  if (raw && method == "dash") {
    dash <- .compute_adult_dash(data, dash_columns, dash_cutpoints, reference)
    result$dash_total <- dash$total
    result$score <- dash$score
    result$components <- .named_components(dash$components, "dash")
  } else if (raw) {
    hei2015 <- .compute_adult_hei2015(
      data, hei2015_columns, hei2015_cutpoints, reference
    )
    result$hei2015_total <- hei2015$total
    result$score <- hei2015$score
    result$components <- .named_components(hei2015$components, "hei2015")
  } else {
    result$score <- .score_supplied_population_diet(
      data, method, reference, input_columns
    )
  }
  result
}

.named_components <- function(components, prefix) {
  components <- as.data.frame(components)
  names(components) <- paste0(prefix, "_", names(components), "_score")
  components
}

# Reference cutpoints describe one population. The packaged NHANES references
# describe adults aged 20+, and one custom reference cannot describe adults
# and children at once. Percentiles in `diet_value` are already
# population-relative and are accepted at any age.
.check_population_reference_ages <- function(age, raw, cutpoints, reference) {
  if (!any(age$pediatric)) {
    return(invisible(NULL))
  }
  packaged <- is.character(reference) && (!raw || is.null(cutpoints))
  if (packaged) {
    .abort_pediatric(c(
      "The packaged NHANES 2015-2018 diet references describe adults aged 20 or older.",
      "i" = "For children, supply pediatric cutpoints or a pediatric {.fn diet_reference}, or percentiles in {.field diet_value}."
    ))
  }
  if (any(age$adult)) {
    .abort_pediatric(c(
      "One diet reference cannot describe both adults and children.",
      "i" = "Score adults and children in separate calls, each with its own reference."
    ))
  }
  invisible(NULL)
}
