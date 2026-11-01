.normalize_population_diet_columns <- function(columns, fields, method) {
  resolved <- stats::setNames(paste0(method, "_", fields), fields)
  if (is.null(columns)) {
    return(resolved)
  }

  argument <- paste0(method, "_columns")
  if (!is.character(columns) || !is.null(dim(columns)) ||
      is.null(names(columns)) ||
      anyNA(columns) || anyNA(names(columns)) ||
      any(columns == "") || any(names(columns) == "")) {
    .abort_adult_scoring(
      "{.arg {argument}} must be a named character vector with complete, nonempty names and values."
    )
  }
  map_names <- tolower(names(columns))
  if (anyDuplicated(map_names) || any(!map_names %in% fields)) {
    .abort_adult_scoring(
      "{.arg {argument}} must name unique canonical {toupper(method)} fields."
    )
  }
  resolved[map_names] <- unname(columns)
  if (anyDuplicated(tolower(resolved))) {
    .abort_adult_scoring(
      "{.arg {argument}} must map each field to a different column."
    )
  }
  resolved
}

.population_diet_inputs <- function(data, columns, fields, method) {
  requested <- .normalize_population_diet_columns(columns, fields, method)
  index <- match(tolower(requested), tolower(names(data)))
  explicitly_mapped <- tolower(names(columns))
  if (any(is.na(index) & fields %in% explicitly_mapped)) {
    .abort_adult_scoring(
      "Explicit {toupper(method)} column mappings must refer to columns in {.arg data}."
    )
  }

  values <- lapply(seq_along(fields), function(i) {
    if (is.na(index[i])) {
      return(rep(NA_real_, nrow(data)))
    }
    column <- names(data)[index[i]]
    data[[column]] <- .coerce_all_na_logical(data[[column]], "numeric")
    .validate_adult_numeric_column(data, column)
    value <- data[[column]]
    if (any(value < 0, na.rm = TRUE)) {
      .abort_adult_scoring(
        "{toupper(method)} field {.field {column}} cannot be negative."
      )
    }
    value
  })
  stats::setNames(values, fields)
}

.validate_diet_cutpoints <- function(value, argument, lower, upper = Inf) {
  if (!is.numeric(value) || !is.null(dim(value)) || length(value) != 4L ||
      anyNA(value) || any(!is.finite(value)) ||
      any(value < lower | value > upper) || any(diff(value) < 0)) {
    .abort_adult_scoring(
      "{.arg {argument}} must contain four finite, nondecreasing numbers from {lower} to {upper}."
    )
  }
  unname(value)
}

.score_population_diet_total <- function(total, cutpoints) {
  # Each threshold is the inclusive lower bound of the next LE8 band.
  band <- rep(1L, length(total))
  for (cutpoint in cutpoints) {
    band <- band + (total >= cutpoint)
  }
  c(0, 25, 50, 80, 100)[band]
}
