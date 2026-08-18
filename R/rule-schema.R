.le8_rule_schema <- data.frame(
  field = c(
    "standard_id",
    "rule_set_version",
    "rule_id",
    "metric",
    "population",
    "age_min",
    "age_min_inclusive",
    "age_max",
    "age_max_inclusive",
    "age_unit",
    "measurement_method",
    "reference_method",
    "condition_group",
    "condition_id",
    "condition_operator",
    "lower",
    "lower_inclusive",
    "upper",
    "upper_inclusive",
    "score",
    "modifier",
    "modifier_order",
    "priority",
    "source_citation",
    "source_locator",
    "verification_status",
    "verified_by",
    "verification_date",
    "notes"
  ),
  type = c(
    rep("character", 5),
    "double",
    "logical",
    "double",
    "logical",
    rep("character", 6),
    "double",
    "logical",
    "double",
    "logical",
    "double",
    "character",
    "integer",
    "integer",
    rep("character", 6)
  ),
  required = c(
    rep(TRUE, 5),
    FALSE,
    FALSE,
    FALSE,
    FALSE,
    TRUE,
    TRUE,
    TRUE,
    FALSE,
    TRUE,
    FALSE,
    FALSE,
    FALSE,
    FALSE,
    FALSE,
    TRUE,
    FALSE,
    FALSE,
    TRUE,
    TRUE,
    TRUE,
    TRUE,
    FALSE,
    FALSE,
    FALSE
  ),
  stringsAsFactors = FALSE
)

.le8_rule_fields <- function() {
  .le8_rule_schema$field
}

.le8_metrics <- function() {
  c(
    "diet",
    "physical_activity",
    "nicotine",
    "sleep",
    "bmi",
    "blood_lipids",
    "blood_glucose",
    "blood_pressure"
  )
}

.le8_populations <- function() {
  c("adult", "pediatric")
}

.le8_verification_statuses <- function() {
  c("planned", "transcribed", "verified", "disputed", "retired")
}
