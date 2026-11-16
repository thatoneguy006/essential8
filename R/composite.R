# Composite score -------------------------------------------------------------
#
# The composite is the unweighted mean of the available component scores
# (AHA 2022), required to include at least `min_components` of them. For
# children, AHA recommends averaging the metrics that are available and
# appropriate for measurement at the child's age.

.add_le8_composite <- function(scores, min_components, applicable) {
  score_columns <- .le8_component_score_columns()
  score_matrix <- as.matrix(scores[score_columns])
  component_count <- as.integer(rowSums(!is.na(score_matrix)))
  component_mean <- rowMeans(score_matrix, na.rm = TRUE)

  eligible <- component_count >= min_components & component_count > 0L
  composite_score <- rep(NA_real_, nrow(scores))
  composite_score[eligible] <- component_mean[eligible]

  scores$n_components <- component_count
  scores$le8_composite_score <- composite_score
  scores$le8_complete <- component_count == 8L

  if (nrow(scores) > 0L) {
    .warn_unavailable_components(score_matrix, applicable, min_components)
  }
  scores
}

.le8_category <- function(composite_score) {
  category <- .score_bands(
    composite_score,
    lower = c(-Inf, 50, 80),
    points = c(1, 2, 3)
  )
  c("low", "moderate", "high")[category]
}

# Warn when a component is missing for every row where AHA defines it, and
# when `min_components` cannot be met by any row (or by pediatric rows whose
# age has too few defined components).
.warn_unavailable_components <- function(score_matrix, applicable, min_components) {
  defined_somewhere <- colSums(applicable) > 0
  observed_somewhere <- colSums(!is.na(score_matrix) & applicable) > 0
  structurally_missing <- defined_somewhere & !observed_somewhere

  possible <- applicable
  possible[, structurally_missing] <- FALSE
  max_possible_components <- max(rowSums(possible))

  labels <- .le8_component_labels()
  missing_components <- unname(labels[structurally_missing])

  if (length(missing_components) > 0L) {
    component_bullets <- stats::setNames(
      missing_components,
      rep("x", length(missing_components))
    )
    missing_header <- "Some LE8 components could not be calculated for any observations."

    if (min_components > max_possible_components) {
      .warn_le8(
        c(
          "!" = missing_header,
          component_bullets,
          "i" = "Only {max_possible_components} LE8 components are available, but {.arg min_components} is {min_components}.",
          "i" = "No LE8 composite scores can be calculated."
        ),
        class = "essential8_insufficient_components"
      )
      return(invisible(NULL))
    }
    .warn_le8(
      c(
        "!" = missing_header,
        component_bullets,
        "i" = "Overall LE8 composite scores will use the available components, subject to {.arg min_components}."
      ),
      class = "essential8_missing_component"
    )
  }

  defined_count <- rowSums(applicable)
  too_few_defined <- sum(defined_count < min_components)
  if (too_few_defined > 0L) {
    .warn_le8(
      c(
        "!" = "{too_few_defined} pediatric row{?s} {?has/have} fewer LE8 components defined at that age than {.arg min_components} ({min_components}).",
        "i" = "Their composite scores are {.val NA}. AHA suggests averaging the components available for a child; consider a lower {.arg min_components}."
      ),
      class = "essential8_insufficient_components"
    )
  }
  invisible(NULL)
}

# Inputs supplied for a component AHA does not define at a pediatric row's age
# (for example, blood pressure before age 1) are not scored.
.inform_not_applicable <- function(data, applicable) {
  key_inputs <- list(
    diet_score = c("diet_value", "dash", "hei2015"),
    physical_activity_score = c(
      "moderate_activity_minutes",
      "vigorous_activity_minutes",
      "active_play_minutes"
    ),
    blood_pressure_score = c("systolic_bp", "diastolic_bp")
  )
  ignored <- vapply(names(key_inputs), function(component) {
    columns <- intersect(key_inputs[[component]], names(data))
    supplied <- Reduce(
      `|`,
      lapply(data[columns], function(x) !is.na(x)),
      init = rep(FALSE, nrow(data))
    )
    any(supplied & !applicable[, component])
  }, logical(1))

  if (any(ignored)) {
    components <- unname(.le8_component_labels()[names(key_inputs)[ignored]])
    cli::cli_inform(
      c(
        "i" = "AHA 2022 defines no score at some pediatric ages for: {components}.",
        " " = "Those inputs were not scored; see {.code ?score_le8}."
      ),
      class = c("essential8_not_applicable", "essential8_message")
    )
  }
  invisible(NULL)
}
