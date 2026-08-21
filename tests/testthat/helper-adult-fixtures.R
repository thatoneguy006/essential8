adult_example_fixture <- function() {
  path <- system.file(
    "extdata",
    "le8-adult-example.csv",
    package = "essential8"
  )

  if (!nzchar(path)) {
    path <- testthat::test_path(
      "..",
      "..",
      "inst",
      "extdata",
      "le8-adult-example.csv"
    )
  }

  utils::read.csv(
    path,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

adult_input_fixture <- function() {
  fixture <- adult_example_fixture()
  fixture[!startsWith(names(fixture), "expected_")]
}

adult_example_row <- function(...) {
  row <- adult_input_fixture()[1, , drop = FALSE]
  changes <- list(...)

  for (column in names(changes)) {
    row[[column]] <- changes[[column]]
  }

  if (
    "diet_value" %in% names(changes) &&
      "diet_value" %in% names(row) &&
      tolower(as.character(row$diet_method)) == "mepa"
  ) {
    profile <- adult_mepa_profile(row$diet_value, row$sex)
    for (column in adult_mepa_columns()) {
      row[[column]] <- profile[[column]]
    }

    # Explicit screener overrides should win over the generated total profile.
    for (column in intersect(names(changes), adult_mepa_columns())) {
      row[[column]] <- changes[[column]]
    }
    row$diet_value <- NA_real_
  }

  row
}

adult_mepa_columns <- function() {
  c(
    "olive_oil",
    "green_leafy_vegetables",
    "other_vegetables",
    "berries",
    "other_fruit",
    "meat",
    "fish",
    "chicken",
    "cheese",
    "butter_cream",
    "beans",
    "whole_grains",
    "sweets_and_pastries",
    "nuts",
    "fast_food",
    "alcohol"
  )
}

adult_mepa_boundary_values <- function() {
  c(
    olive_oil = 2,
    green_leafy_vegetables = 1,
    other_vegetables = 2,
    berries = 2,
    other_fruit = 7,
    meat = 3,
    fish = 1,
    chicken = 5,
    cheese = 4,
    butter_cream = 5,
    beans = 3,
    whole_grains = 3,
    sweets_and_pastries = 4,
    nuts = 4,
    fast_food = 1,
    alcohol = 0
  )
}

adult_mepa_passing_values <- function() {
  c(
    olive_oil = 2,
    green_leafy_vegetables = 1,
    other_vegetables = 2,
    berries = 2,
    other_fruit = 7,
    meat = 3,
    fish = 1,
    chicken = 5,
    cheese = 4,
    butter_cream = 5,
    beans = 3,
    whole_grains = 3,
    sweets_and_pastries = 4,
    nuts = 4,
    fast_food = 1,
    alcohol = 1
  )
}

adult_mepa_failing_values <- function() {
  c(
    olive_oil = 1,
    green_leafy_vegetables = 0,
    other_vegetables = 1,
    berries = 1,
    other_fruit = 6,
    meat = 4,
    fish = 0,
    chicken = 6,
    cheese = 5,
    butter_cream = 6,
    beans = 2,
    whole_grains = 2,
    sweets_and_pastries = 5,
    nuts = 3,
    fast_food = 2,
    alcohol = 0
  )
}

adult_mepa_profile <- function(total = 16L, sex = "male") {
  if (
    length(total) != 1L ||
      is.na(total) ||
      total < 0 ||
      total > 16 ||
      total != floor(total)
  ) {
    stop("`total` must be a whole number from 0 to 16.", call. = FALSE)
  }

  values <- adult_mepa_failing_values()
  if (total > 0L) {
    passing <- adult_mepa_passing_values()
    passing_items <- seq_len(total)
    values[passing_items] <- passing[passing_items]
  }

  profile <- as.data.frame(
    as.list(values),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  profile$sex <- sex
  profile[c("sex", adult_mepa_columns())]
}

adult_mepa_row <- function(total = 16L, sex = "male", ...) {
  row <- adult_example_row(...)
  row$diet_method <- "mepa"
  row$diet_value <- NULL

  profile <- adult_mepa_profile(total, sex)
  for (column in c("sex", adult_mepa_columns())) {
    row[[column]] <- profile[[column]]
  }

  row
}

adult_component_score_columns <- function() {
  c(
    "le8_diet_score",
    "le8_physical_activity_score",
    "le8_nicotine_score",
    "le8_sleep_score",
    "le8_bmi_score",
    "le8_blood_lipids_score",
    "le8_blood_glucose_score",
    "le8_blood_pressure_score"
  )
}
