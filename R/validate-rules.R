.validate_rule_table <- function(rules, allow_empty = FALSE) {
  if (!is.data.frame(rules)) {
    .abort_rule_schema(c(
      "{.arg rules} must be a data frame.",
      "x" = "You supplied {.cls {class(rules)}}."
    ))
  }

  missing_fields <- setdiff(.le8_rule_fields(), names(rules))
  if (length(missing_fields) > 0L) {
    .abort_rule_schema(c(
      "The rule table is missing required schema columns.",
      "x" = "Missing: {paste(missing_fields, collapse = ', ')}."
    ))
  }

  if (nrow(rules) == 0L) {
    if (isTRUE(allow_empty)) {
      return(invisible(rules))
    }

    .abort_rule_schema(c(
      "The rule table cannot be empty.",
      "i" = "Use {.code allow_empty = TRUE} only for schema templates."
    ))
  }

  unknown_metrics <- setdiff(unique(rules$metric), .le8_metrics())
  if (length(unknown_metrics) > 0L) {
    .abort_rule_schema(c(
      "The rule table contains unknown metrics.",
      "x" = "Unknown: {paste(unknown_metrics, collapse = ', ')}."
    ))
  }

  unknown_populations <- setdiff(
    unique(rules$population),
    .le8_populations()
  )
  if (length(unknown_populations) > 0L) {
    .abort_rule_schema(c(
      "The rule table contains unknown populations.",
      "x" = "Unknown: {paste(unknown_populations, collapse = ', ')}."
    ))
  }

  unknown_statuses <- setdiff(
    unique(rules$verification_status),
    .le8_verification_statuses()
  )
  if (length(unknown_statuses) > 0L) {
    .abort_rule_schema(c(
      "The rule table contains unknown verification statuses.",
      "x" = "Unknown: {paste(unknown_statuses, collapse = ', ')}."
    ))
  }

  missing_rule_ids <- is.na(rules$rule_id) | rules$rule_id == ""
  if (any(missing_rule_ids)) {
    .abort_rule_schema(
      "Every rule must have a nonmissing {.field rule_id}."
    )
  }

  duplicated_rule_ids <- unique(rules$rule_id[duplicated(rules$rule_id)])
  if (length(duplicated_rule_ids) > 0L) {
    .abort_rule_schema(c(
      "Each {.field rule_id} must be unique.",
      "x" = "Duplicated: {paste(duplicated_rule_ids, collapse = ', ')}."
    ))
  }

  invalid_scores <- is.na(rules$score) |
    !is.finite(rules$score) |
    rules$score < 0 |
    rules$score > 100
  if (any(invalid_scores)) {
    .abort_rule_schema(
      "Every {.field score} must be finite and between 0 and 100."
    )
  }

  invalid_age_intervals <- !is.na(rules$age_min) &
    !is.na(rules$age_max) &
    rules$age_min > rules$age_max
  if (any(invalid_age_intervals)) {
    .abort_rule_schema(
      "Every {.field age_min} must be less than or equal to {.field age_max}."
    )
  }

  verified <- rules$verification_status == "verified"
  missing_verifier <- is.na(rules$verified_by) | rules$verified_by == ""
  missing_date <- is.na(rules$verification_date) |
    rules$verification_date == ""
  if (any(verified & (missing_verifier | missing_date))) {
    .abort_rule_schema(c(
      "Verified rules require verification metadata.",
      "x" = paste0(
        "Supply both {.field verified_by} and ",
        "{.field verification_date}."
      )
    ))
  }

  invisible(rules)
}

