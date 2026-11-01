test_that("population diet column maps are case-insensitive and partial", {
  for (method in c("dash", "hei2015")) {
    row <- if (method == "dash") adult_dash_row() else adult_hei2015_row()
    field <- if (method == "dash") "fruits" else "total_fruits"
    original <- paste0(method, "_", field)
    row$custom <- row[[original]]
    row[[original]] <- NULL
    names(row) <- toupper(names(row))
    names(row)[names(row) == "AGE"] <- "age"
    arguments <- list(data = row, diet_method = method)
    arguments[[paste0(method, "_columns")]] <-
      stats::setNames("CUSTOM", toupper(field))
    arguments[[paste0(method, "_cutpoints")]] <- if (method == "dash") {
      dash_reference_fixture()
    } else {
      hei2015_reference_fixture()
    }
    # Other LE8 inputs are case-sensitive; restore their original names.
    base_names <- names(adult_example_row())
    index <- match(toupper(names(row)), toupper(base_names))
    names(row)[!is.na(index)] <- base_names[index[!is.na(index)]]
    arguments$data <- row
    result <- do.call(score_le8, arguments)
    expect_equal(result$le8_diet_score, 100, info = method)
  }
})

test_that("population diet inputs validate numeric values and column shapes", {
  for (method in c("dash", "hei2015")) {
    row <- if (method == "dash") adult_dash_row() else adult_hei2015_row()
    arguments <- list(diet_method = method)
    arguments[[paste0(method, "_cutpoints")]] <- if (method == "dash") {
      dash_reference_fixture()
    } else {
      hei2015_reference_fixture()
    }
    fields <- grep(paste0("^", method, "_"), names(row), value = TRUE)
    for (field in fields) {
      for (bad in list("1", TRUE, Inf, -1, matrix(1, nrow = 1))) {
        input <- row
        input[[field]] <- bad
        expect_error(
          do.call(score_le8, c(list(data = input), arguments)),
          class = "essential8_adult_input_error", info = field
        )
      }
    }
    row$diet_value <- 95
    expect_error(
      do.call(score_le8, c(list(data = row), arguments)),
      "precomputed", class = "essential8_adult_input_error"
    )
    row$diet_value <- NA_real_
    expect_equal(
      do.call(score_le8, c(list(data = row), arguments))$le8_diet_score, 100
    )
    row$age <- 19
    expect_error(
      do.call(score_le8, c(list(data = row), arguments)),
      "at least 20", class = "essential8_adult_input_error"
    )
  }
})

test_that("population diet mappings reject ambiguous and unknown fields", {
  for (method in c("dash", "hei2015")) {
    row <- if (method == "dash") adult_dash_row() else adult_hei2015_row()
    field <- if (method == "dash") "fruits" else "total_fruits"
    other <- if (method == "dash") "vegetables" else "whole_fruits"
    maps <- list(
      "column", c(unknown = "column"),
      stats::setNames(c("a", "b"), c(field, toupper(field))),
      stats::setNames(c("same", "SAME"), c(field, other)),
      stats::setNames("", field), stats::setNames(NA_character_, field),
      stats::setNames("missing_column", field),
      stats::setNames(paste0(method, "_", other), field)
    )
    for (map in maps) {
      arguments <- list(data = row, diet_method = method)
      arguments[[paste0(method, "_columns")]] <- map
      arguments[[paste0(method, "_cutpoints")]] <- if (method == "dash") {
        dash_reference_fixture()
      } else {
        hei2015_reference_fixture()
      }
      expect_error(do.call(score_le8, arguments),
                   class = "essential8_adult_input_error")
    }
  }
})

test_that("population diets handle empty inputs with stable output types", {
  for (method in c("dash", "hei2015")) {
    row <- if (method == "dash") adult_dash_row() else adult_hei2015_row()
    arguments <- list(data = row[0, ], diet_method = method)
    arguments[[paste0(method, "_cutpoints")]] <- if (method == "dash") {
      dash_reference_fixture()
    } else {
      hei2015_reference_fixture()
    }
    result <- expect_no_warning(do.call(score_le8, arguments))
    expect_equal(nrow(result), 0)
    expect_type(result$dash_total, "integer")
    expect_type(result$hei2015_total, "double")
    expect_type(result$le8_diet_score, "double")
    arguments$data <- data.frame(age = numeric())
    # Explicit cutpoints select raw scoring, so absent raw columns are an error.
    expect_error(
      do.call(score_le8, arguments),
      class = "essential8_adult_input_error"
    )
  }
})

test_that("population diet arguments cannot be silently used in other methods", {
  expect_error(
    score_le8(adult_mepa_row(), dash_cutpoints = dash_reference_fixture()),
    class = "essential8_adult_input_error"
  )
  expect_error(
    score_le8(adult_mepa_row(), hei2015_cutpoints = hei2015_reference_fixture()),
    class = "essential8_adult_input_error"
  )
  for (column in c("DASH_TOTAL", "hei2015_total", "hei2015_fatty_acids_score")) {
    row <- adult_mepa_row()
    row[[column]] <- 1
    expect_error(score_le8(row), class = "essential8_adult_input_error")
  }
})

test_that("legacy method columns accept matching population diet methods", {
  row <- adult_dash_row()
  row$diet_method <- "DASH"
  expect_equal(
    score_le8(row, "dash", dash_cutpoints = dash_reference_fixture())$dash_total,
    40
  )
  row <- adult_hei2015_row()
  row$diet_method <- " HEI2015 "
  expect_equal(
    score_le8(row, "hei2015",
              hei2015_cutpoints = hei2015_reference_fixture())$hei2015_total,
    100
  )
})
