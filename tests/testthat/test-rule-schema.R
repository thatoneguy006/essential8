test_that("rule schema contains execution and provenance fields", {
  fields <- essential8:::.le8_rule_fields()

  expect_true(all(c(
    "standard_id",
    "rule_set_version",
    "rule_id",
    "lower_inclusive",
    "upper_inclusive",
    "condition_operator",
    "modifier_order",
    "source_locator",
    "verification_status"
  ) %in% fields))
  expect_identical(anyDuplicated(fields), 0L)
})

test_that("the eight metric identifiers are stable and unique", {
  metrics <- essential8:::.le8_metrics()

  expect_length(metrics, 8L)
  expect_identical(anyDuplicated(metrics), 0L)
})
