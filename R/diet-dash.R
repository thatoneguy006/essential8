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

.compute_adult_dash <- function(
  data,
  dash_columns,
  dash_cutpoints,
  reference = "nhanes_2015_2018"
) {
  use_reference <- is.null(dash_cutpoints)
  fields <- .adult_dash_fields()
  if (use_reference) {
    reference <- .resolve_diet_reference("dash", reference)
    if (!identical(reference$provenance$index_definition,
                   "essential8_fung_fped_v1") ||
        is.null(reference$provenance$component_cutpoints)) {
      .abort_adult_scoring(c(
        "Raw DASH scoring requires reference intake quintiles.",
        "i" = "Use {.val nhanes_2015_2018} or supply {.arg dash_cutpoints} with all eight intake quintiles and total-score cutpoints."
      ))
    }
    dash_cutpoints <- c(
      reference$provenance$component_cutpoints,
      list(total = unlist(reference[c("p25", "p50", "p75", "p95")]))
    )
    fields <- c(fields, "energy_kcal")
  }
  cutpoints <- .validate_dash_cutpoints(dash_cutpoints)
  inputs <- .population_diet_inputs(
    data, dash_columns, fields, "dash"
  )
  if (use_reference) {
    if (any(inputs$energy_kcal <= 0, na.rm = TRUE)) {
      .abort_adult_scoring(
        "DASH {.field energy_kcal} must be greater than zero when observed."
      )
    }
    # The packaged FPED definition uses sodium standardized to 2,000 kcal.
    inputs$sodium <- inputs$sodium / inputs$energy_kcal * 2000
    inputs$energy_kcal <- NULL
  }
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
