test_that("raw MEPA items produce the sourced totals and LE8 diet bands", {
  totals <- c(0, 3, 4, 7, 8, 11, 12, 14, 15, 16)
  input <- do.call(
    rbind,
    lapply(totals, adult_mepa_row)
  )

  result <- score_le8(input)

  expect_false("diet_value" %in% names(input))
  expect_equal(result$mepa_total, totals)
  expect_equal(
    result$le8_diet_score,
    c(0, 0, 25, 25, 50, 50, 80, 80, 100, 100)
  )
  expect_equal(
    result$le8_composite_score,
    c(87.5, 87.5, 90.625, 90.625, 93.75, 93.75, 97.5, 97.5, 100, 100)
  )
})

test_that("different diet methods are scored in separate calls", {
  mepa <- adult_mepa_row(total = 16)
  percentile <- adult_example_row(diet_value = 25)
  percentile[c("sex", adult_mepa_columns())] <- NULL

  mepa_result <- score_le8(mepa, diet_method = "mepa")
  percentile_result <- score_le8(
    percentile,
    diet_method = "percentile"
  )

  expect_equal(mepa_result$mepa_total, 16)
  expect_equal(mepa_result$le8_diet_score, 100)
  expect_equal(percentile_result$mepa_total, NA_integer_)
  expect_equal(percentile_result$le8_diet_score, 25)
  expect_false("diet_method" %in% names(mepa_result))
  expect_false("diet_method" %in% names(percentile_result))
})

test_that("percentile-only scoring does not require MEPA inputs", {
  input <- adult_example_row(diet_value = 95)
  input[c("sex", adult_mepa_columns())] <- NULL

  result <- score_le8(input, diet_method = "percentile")

  expect_false(any(c("sex", adult_mepa_columns()) %in% names(result)))
  expect_equal(result$mepa_total, NA_integer_)
  expect_equal(result$le8_diet_score, 100)
})

test_that("zero-row scoring validates only the selected diet schema", {
  input <- adult_input_fixture()[0, , drop = FALSE]
  input[c("sex", adult_mepa_columns())] <- NULL

  expect_error(
    score_le8(input, diet_method = "mepa"),
    class = "essential8_adult_input_error"
  )
  expect_error(
    score_le8(input, diet_method = "percentile"),
    class = "essential8_adult_input_error"
  )

  input$diet_value <- numeric()
  result <- score_le8(input, diet_method = "percentile")

  expect_equal(nrow(result), 0L)
  expect_type(result$mepa_total, "integer")
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
  for (index in seq_along(items)) {
    at_boundary <- adult_mepa_row(total = 0)
    just_failing <- adult_mepa_row(total = 0)
    at_boundary[[items[index]]] <- boundary[index]
    just_failing[[items[index]]] <-
      boundary[index] - direction[index] * 0.001

    rows[[2L * index - 1L]] <- at_boundary
    rows[[2L * index]] <- just_failing
  }

  result <- score_le8(do.call(rbind, rows))

  expect_equal(result$mepa_total, rep(c(1, 0), length(items)))
})

test_that("MEPA alcohol uses a bounded positive weekly range", {
  alcohol_values <- c(0, 0.001, 14, 14.001, 0, 0.001, 7, 7.001)
  sex <- c(
    rep("male", 4),
    rep("female", 4)
  )
  rows <- lapply(seq_along(alcohol_values), function(index) {
    row <- adult_mepa_row(total = 0, sex = sex[index])
    row$alcohol <- alcohol_values[index]
    row
  })

  result <- score_le8(do.call(rbind, rows))

  expect_equal(result$mepa_total, c(0, 1, 1, 0, 0, 1, 1, 0))
  expect_equal(result$le8_diet_score, rep(0, 8))
})

test_that("MEPA alcohol uses the sex-specific upper threshold", {
  input <- rbind(
    adult_mepa_row(total = 0, sex = "male"),
    adult_mepa_row(total = 0, sex = "female")
  )
  input$alcohol <- 10

  result <- score_le8(input)

  expect_equal(result$mepa_total, c(1, 0))
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

test_that("MEPA rejects ambiguous case-insensitive column matches", {
  input <- adult_mepa_row(total = 16)
  input$OLIVE_OIL <- input$olive_oil

  expect_error(
    score_le8(input),
    class = "essential8_adult_input_error"
  )
})

test_that("MEPA requires every screener item and sex", {
  missing_fish <- adult_mepa_row(total = 16)
  missing_fish$fish <- NULL
  expect_error(
    score_le8(missing_fish),
    "fish",
    class = "essential8_adult_input_error"
  )

  missing_sex <- adult_mepa_row(total = 16)
  missing_sex$sex <- NULL
  expect_error(
    score_le8(missing_sex),
    "sex",
    class = "essential8_adult_input_error"
  )
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

  for (encoding in sex_encodings) {
    input <- rbind(
      adult_mepa_row(total = 0),
      adult_mepa_row(total = 0)
    )
    input$sex <- encoding
    input$alcohol <- 10

    result <- score_le8(input)

    expect_equal(result$mepa_total, c(1, 0))
    expect_identical(result$sex, encoding)
  }
})

test_that("MEPA screener responses must be complete nonnegative numbers", {
  malformed <- list(
    character = function(data) {
      data$fish <- as.character(data$fish)
      data
    },
    missing = function(data) {
      data$berries <- NA_real_
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

  for (make_malformed in malformed) {
    expect_error(
      score_le8(make_malformed(adult_mepa_row(total = 16))),
      class = "essential8_adult_input_error"
    )
  }
})

test_that("MEPA rejects incomplete or unsupported sex encodings", {
  malformed_sex <- list(
    NA_character_,
    "   ",
    "other",
    2,
    "2",
    0.5,
    TRUE
  )

  for (sex in malformed_sex) {
    input <- adult_mepa_row(total = 16)
    input$sex <- sex

    expect_error(
      score_le8(input),
      class = "essential8_adult_input_error"
    )
  }
})
