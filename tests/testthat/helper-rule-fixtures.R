minimal_rule_table <- function() {
  values <- list(
    standard_id = "TEST_STANDARD",
    rule_set_version = "TEST.1",
    rule_id = "test-adult-sleep-interval-001",
    metric = "sleep",
    population = "adult",
    age_min = 42,
    age_min_inclusive = TRUE,
    age_max = NA_real_,
    age_max_inclusive = NA,
    age_unit = "years",
    measurement_method = "average_hours_per_24h",
    reference_method = "none",
    condition_group = "duration",
    condition_id = "optimal_duration",
    condition_operator = "interval",
    lower = 6.25,
    lower_inclusive = TRUE,
    upper = 8.75,
    upper_inclusive = FALSE,
    score = 37,
    modifier = "none",
    modifier_order = 0L,
    priority = 1L,
    source_citation = "SYNTHETIC-TEST-NOT-A-SOURCE",
    source_locator = "SYNTHETIC-TEST-LOCATOR",
    verification_status = "planned",
    verified_by = NA_character_,
    verification_date = NA_character_,
    notes = "Synthetic fixture; not a verified scientific rule."
  )

  as.data.frame(values, stringsAsFactors = FALSE)
}

