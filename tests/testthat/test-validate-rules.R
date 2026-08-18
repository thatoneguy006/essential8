test_that("a structurally valid transcribed rule passes", {
  rules <- minimal_rule_table()

  expect_invisible(essential8:::.validate_rule_table(rules))
})

test_that("empty schema templates require an explicit opt-in", {
  rules <- minimal_rule_table()[0, ]

  expect_error(
    essential8:::.validate_rule_table(rules),
    class = "essential8_rule_schema_error"
  )
  expect_invisible(
    essential8:::.validate_rule_table(rules, allow_empty = TRUE)
  )
})

test_that("missing schema columns produce a classed error", {
  rules <- minimal_rule_table()
  rules$source_locator <- NULL

  expect_error(
    essential8:::.validate_rule_table(rules),
    class = "essential8_rule_schema_error"
  )
})

test_that("rule identifiers must be present and unique", {
  rules <- rbind(minimal_rule_table(), minimal_rule_table())

  expect_error(
    essential8:::.validate_rule_table(rules),
    class = "essential8_rule_schema_error"
  )

  rules <- minimal_rule_table()
  rules$rule_id <- ""
  expect_error(
    essential8:::.validate_rule_table(rules),
    class = "essential8_rule_schema_error"
  )
})

test_that("scores and age intervals are bounded", {
  rules <- minimal_rule_table()
  rules$score <- 101
  expect_error(
    essential8:::.validate_rule_table(rules),
    class = "essential8_rule_schema_error"
  )

  rules <- minimal_rule_table()
  rules$age_max <- 19
  expect_error(
    essential8:::.validate_rule_table(rules),
    class = "essential8_rule_schema_error"
  )
})

test_that("verified rules require verifier identity and date", {
  rules <- minimal_rule_table()
  rules$verification_status <- "verified"

  expect_error(
    essential8:::.validate_rule_table(rules),
    class = "essential8_rule_schema_error"
  )

  rules$verified_by <- "independent-reviewer"
  rules$verification_date <- "2026-08-18"
  expect_invisible(essential8:::.validate_rule_table(rules))
})

