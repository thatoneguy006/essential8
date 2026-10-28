.adult_dash_fields <- function() {
  c(
    "fruits", "vegetables", "nuts_and_legumes", "whole_grains",
    "low_fat_dairy", "sodium", "red_and_processed_meat",
    "sweetened_beverages"
  )
}

.validate_dash_cutpoints <- function(dash_cutpoints) {
  fields <- c(.adult_dash_fields(), "total")
  if (!is.list(dash_cutpoints) || is.data.frame(dash_cutpoints) ||
      is.null(names(dash_cutpoints)) || anyNA(names(dash_cutpoints)) ||
      anyDuplicated(tolower(names(dash_cutpoints))) ||
      !setequal(tolower(names(dash_cutpoints)), fields)) {
    .abort_adult_scoring(c(
      "{.arg dash_cutpoints} must be a named list of eight intake cutpoint vectors and {.field total}.",
      "i" = "Supply reference-population intake quintiles and total-score percentiles; no reference is inferred from data."
    ))
  }
  names(dash_cutpoints) <- tolower(names(dash_cutpoints))
  for (field in fields) {
    dash_cutpoints[[field]] <- .validate_diet_cutpoints(
      dash_cutpoints[[field]],
      paste0("dash_cutpoints$", field),
      lower = if (field == "total") 8 else 0,
      upper = if (field == "total") 40 else Inf
    )
  }
  dash_cutpoints
}

.compute_adult_dash <- function(data, dash_columns, dash_cutpoints) {
  cutpoints <- .validate_dash_cutpoints(dash_cutpoints)
  inputs <- .population_diet_inputs(
    data, dash_columns, .adult_dash_fields(), "dash"
  )
  reverse <- c("sodium", "red_and_processed_meat", "sweetened_beverages")
  item_scores <- lapply(names(inputs), function(field) {
    value <- inputs[[field]]
    quintile <- rep(1L, length(value))
    # Intake equal to a quintile cutpoint remains in the lower quintile.
    for (cutpoint in cutpoints[[field]]) {
      quintile <- quintile + (value > cutpoint)
    }
    if (field %in% reverse) 6L - quintile else quintile
  })
  total <- as.integer(rowSums(do.call(cbind, item_scores)))
  list(
    total = total,
    score = .score_population_diet_total(total, cutpoints$total)
  )
}
