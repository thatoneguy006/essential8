test_that("raw MEPA inputs flow through diet and composite scoring", {
  totals <- c(0, 8, 16)
  input <- do.call(
    rbind,
    lapply(totals, adult_mepa_row)
  )

  result <- score_le8(input)

  expect_false("diet_value" %in% names(input))
  expect_equal(result$mepa_total, totals)
  expect_equal(result$le8_diet_score, c(0, 50, 100))
  expect_equal(result$le8_composite_score, c(87.5, 93.75, 100))
})

test_that("MEPA allows only absent or all-missing diet_value", {
  input <- adult_mepa_row(total = 16)
  input$diet_value <- NA

  result <- score_le8(input)

  expect_identical(result$diet_value, NA)
  expect_equal(result$mepa_total, 16)

  input$diet_value <- 16
  expect_error(
    score_le8(input),
    "must not supply",
    class = "essential8_adult_input_error"
  )
})

test_that("percentile-only scoring does not require MEPA inputs", {
  input <- adult_example_row(diet_value = 95)
  input[c("sex", adult_mepa_columns())] <- NULL

  result <- score_le8(input, diet_method = "percentile")

  expect_false(any(c("sex", adult_mepa_columns()) %in% names(result)))
  expect_equal(result$mepa_total, NA_integer_)
  expect_equal(result$le8_diet_score, 100)
})

test_that("zero-row diet dispatch preserves diet output types", {
  input <- adult_input_fixture()[0, , drop = FALSE]
  complete_mepa_result <- expect_no_warning(score_le8(input))
  expect_type(complete_mepa_result$mepa_total, "integer")
  expect_type(complete_mepa_result$le8_diet_score, "double")

  input[c("sex", adult_mepa_columns())] <- NULL
  mepa_result <- expect_no_warning(
    score_le8(input, diet_method = "mepa")
  )
  percentile_result <- expect_no_warning(
    score_le8(input, diet_method = "percentile")
  )

  expect_type(mepa_result$mepa_total, "integer")
  expect_type(mepa_result$le8_diet_score, "double")
  expect_type(percentile_result$mepa_total, "integer")
  expect_type(percentile_result$le8_diet_score, "double")

  input$diet_value <- numeric()
  result <- score_le8(input, diet_method = "percentile")

  expect_type(result$mepa_total, "integer")
  expect_type(result$le8_diet_score, "double")
})

test_that("zero-row MEPA scoring validates column types", {
  input <- adult_input_fixture()[0, , drop = FALSE]
  input$fish <- character()
  expect_error(
    score_le8(input, diet_method = "mepa"),
    class = "essential8_adult_input_error"
  )

  input <- adult_input_fixture()[0, , drop = FALSE]
  input$sex <- logical()
  expect_error(
    score_le8(input, diet_method = "mepa"),
    class = "essential8_adult_input_error"
  )
})

test_that("MEPA food criteria include the source-table thresholds", {
  items <- c(
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
    "fast_food"
  )
  boundary <- adult_mepa_boundary_values()[items]
  direction <- c(
    1,
    1,
    1,
    1,
    1,
    -1,
    1,
    -1,
    -1,
    -1,
    1,
    1,
    -1,
    1,
    -1
  )

  rows <- vector("list", length(items) * 2L)
  row <- adult_mepa_row(total = 0)
  for (index in seq_along(items)) {
    at_boundary <- row
    just_failing <- row
    at_boundary[[items[index]]] <- boundary[index]
    just_failing[[items[index]]] <-
      boundary[index] - direction[index] * 0.001

    rows[[2L * index - 1L]] <- at_boundary
    rows[[2L * index]] <- just_failing
  }

  result <- score_le8(do.call(rbind, rows))

  labels <- paste(
    rep(items, each = 2L),
    c("at boundary", "just failing")
  )
  expect_equal(
    stats::setNames(result$mepa_total, labels),
    stats::setNames(rep(c(1, 0), length(items)), labels)
  )
})

test_that("MEPA alcohol uses a bounded positive weekly range", {
  alcohol_values <- c(0, 0.001, 14, 14.001, 0, 0.001, 7, 7.001)
  sex <- c(
    rep("male", 4),
    rep("female", 4)
  )
  row <- adult_mepa_row(total = 0)
  input <- row[rep(1L, length(alcohol_values)), , drop = FALSE]
  input$sex <- sex
  input$alcohol <- alcohol_values
  labels <- paste(sex, "alcohol =", alcohol_values)

  result <- score_le8(input)

  expect_equal(
    stats::setNames(result$mepa_total, labels),
    stats::setNames(c(0, 1, 1, 0, 0, 1, 1, 0), labels)
  )
  expect_equal(
    stats::setNames(result$le8_diet_score, labels),
    stats::setNames(rep(0, 8), labels)
  )
})

test_that("MEPA method, screener names, and sex are case-insensitive", {
  input <- adult_mepa_row(total = 16, sex = "FEMALE")

  case_insensitive_names <- c(
    sex = "SeX",
    stats::setNames(toupper(adult_mepa_columns()), adult_mepa_columns())
  )
  names(input)[match(names(case_insensitive_names), names(input))] <-
    unname(case_insensitive_names)

  result <- score_le8(input, diet_method = "MePa")

  expect_identical(result$SeX, "FEMALE")
  expect_equal(result$mepa_total, 16)
  expect_equal(result$le8_diet_score, 100)
})

test_that("a named MEPA mapping adapts existing data column names", {
  input <- adult_mepa_row(total = 16)
  names(input)[names(input) == "fish"] <- "Fish Screener #7"
  names(input)[names(input) == "sex"] <- "Reported Sex"

  result <- score_le8(
    input,
    mepa_columns = c(
      FISH = "fish screener #7",
      sex = "REPORTED SEX"
    )
  )

  expect_equal(result$mepa_total, 16)
  expect_equal(result$le8_diet_score, 100)
})

test_that("MEPA mappings reject unsupported or ambiguous specifications", {
  input <- adult_mepa_row(total = 16)

  expect_error(
    score_le8(input, mepa_columns = "fish"),
    class = "essential8_adult_input_error"
  )
  expect_error(
    score_le8(input, mepa_columns = c(not_an_item = "fish")),
    class = "essential8_adult_input_error"
  )
  expect_error(
    score_le8(
      input,
      mepa_columns = c(fish = "fish", meat = "FISH")
    ),
    class = "essential8_adult_input_error"
  )
  expect_error(
    score_le8(input, mepa_columns = c(fish = "not present")),
    class = "essential8_adult_input_error"
  )

  input$sex <- NULL
  input$female <- input$alcohol
  expect_error(
    score_le8(input, mepa_columns = c(alcohol = "female")),
    class = "essential8_adult_input_error"
  )
})

test_that("omitted MEPA inputs make diet structurally unavailable", {
  complete_input <- adult_mepa_row(total = 16)

  for (column in c("fish", "sex")) {
    input <- complete_input
    input[[column]] <- NULL
    label <- paste("omitted MEPA column:", column)

    expect_warning(
      result <- score_le8(input),
      "Diet",
      class = "essential8_missing_component",
      info = label
    )
    expect_true(is.na(result$le8_diet_score), info = label)
    expect_equal(result$le8_n_components, 7L, info = label)
  }
})

test_that("female is auto-resolved when the sex column is absent", {
  input <- rbind(
    adult_mepa_row(total = 0),
    adult_mepa_row(total = 0)
  )
  input$female <- c(0, 1)
  input$sex <- NULL
  input$alcohol <- 10

  result <- score_le8(input)

  expect_equal(result$mepa_total, c(1, 0))
  expect_identical(result$female, c(0, 1))
  expect_false("sex" %in% names(result))
})

test_that("MEPA accepts and preserves supported sex encodings", {
  sex_encodings <- list(
    shorthand = c(" m ", "F"),
    full_labels = c(" MALE", "female "),
    numeric = c(0, 1),
    character_digits = c(" 0 ", "1"),
    factor_digits = factor(c("0", "1"))
  )
  row <- adult_mepa_row(total = 0)
  input <- row[c(1L, 1L), , drop = FALSE]
  input$alcohol <- 10

  for (name in names(sex_encodings)) {
    input$sex <- sex_encodings[[name]]
    result <- score_le8(input)

    expect_equal(result$mepa_total, c(1, 0), info = name)
    expect_identical(result$sex, sex_encodings[[name]], info = name)
  }
})

test_that("observed MEPA responses must be finite nonnegative numbers", {
  malformed <- list(
    character = function(data) {
      data$fish <- as.character(data$fish)
      data
    },
    infinite = function(data) {
      data$beans <- Inf
      data
    },
    negative = function(data) {
      data$meat <- -0.001
      data
    }
  )
  input <- adult_mepa_row(total = 16)

  for (name in names(malformed)) {
    expect_error(
      score_le8(malformed[[name]](input)),
      class = "essential8_adult_input_error",
      info = paste("MEPA response:", name)
    )
  }
})

test_that("MEPA rejects blank or unsupported sex encodings", {
  malformed_sex <- list(
    blank = "   ",
    unsupported_label = "other",
    unsupported_numeric = 2,
    unsupported_digit = "2",
    fractional = 0.5,
    logical = TRUE
  )
  input <- adult_mepa_row(total = 16)

  for (name in names(malformed_sex)) {
    input$sex <- malformed_sex[[name]]

    expect_error(
      score_le8(input),
      class = "essential8_adult_input_error",
      info = paste("sex encoding:", name)
    )
  }
})
