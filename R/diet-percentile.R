.validate_diet_percentile <- function(percentile) {
  if (is.logical(percentile) && all(is.na(percentile))) {
    percentile <- as.numeric(percentile)
  }
  if (!is.numeric(percentile) || !is.null(dim(percentile)) ||
      any(!is.finite(percentile[!is.na(percentile)])) ||
      any(percentile < 0 | percentile > 100, na.rm = TRUE)) {
    .abort_adult_scoring(
      "Diet percentiles must be numeric values between 0 and 100, with missing values allowed."
    )
  }
  observed <- percentile[!is.na(percentile)]
  if (length(observed) && all(observed >= 0 & observed <= 1) &&
      any(observed > 0 & observed < 1)) {
    .abort_adult_scoring(c(
      "Diet percentiles appear to be proportions.",
      "i" = "Use the 0 to 100 scale, for example 95 for the 95th percentile."
    ))
  }
  as.numeric(percentile)
}

.score_diet_percentile <- function(percentile) {
  percentile <- .validate_diet_percentile(percentile)
  as.numeric(ifelse(percentile >= 95, 100,
         ifelse(percentile >= 75, 80,
                ifelse(percentile >= 50, 50,
                       ifelse(percentile >= 25, 25, 0)))))
}

.score_supplied_population_diet <- function(data, method, reference, input_columns) {
  other_method <- if (method == "dash") "hei2015" else "dash"
  if (other_method %in% names(data)) {
    .abort_adult_scoring("{.field {other_method}} is unrelated to {.arg diet_method}.")
  }
  has_index <- method %in% names(data)
  has_percentile <- "diet_value" %in% input_columns &&
    any(!is.na(data$diet_value))
  if (has_index && has_percentile) {
    .abort_adult_scoring(
      "Supply either {.field {method}} or percentile {.field diet_value}, not both."
    )
  }
  if (!has_index) {
    return(.score_diet_percentile(data$diet_value))
  }
  .validate_adult_column_shape(data, method)
  reference <- .resolve_diet_reference(method, reference)
  .diet_index_to_score(data[[method]], reference)
}
