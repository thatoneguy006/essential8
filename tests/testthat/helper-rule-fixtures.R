minimal_rule_table <- function() {
  values <- list(
    standard_id = "AHA2022",
    rule_set_version = "2022.1",
    rule_id = "aha2022-adult-sleep-001",
    metric = "sleep",
    population = "adult",
    age_min = 20,
    age_min_inclusive = TRUE,
    age_max = NA_real_,
    age_max_inclusive = NA,
    age_unit = "years",
    measurement_method = "average_hours_per_24h",
    reference_method = "none",
    condition_group = "duration",
    condition_id = "optimal_duration",
    condition_operator = "interval",
    lower = 7,
    lower_inclusive = TRUE,
    upper = 9,
    upper_inclusive = FALSE,
    score = 100,
    modifier = "none",
    modifier_order = 0L,
    priority = 1L,
    source_citation = "doi:10.1161/CIR.0000000000001078",
    source_locator = "TEST-ONLY",
    verification_status = "transcribed",
    verified_by = NA_character_,
    verification_date = NA_character_,
    notes = "Synthetic fixture; not a verified scientific rule."
  )

  as.data.frame(values, stringsAsFactors = FALSE)
}

