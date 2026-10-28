test_that("DASH totals and LE8 composite scores follow hand-scored profiles", {
  input <- rbind(adult_dash_row(FALSE), adult_dash_row(TRUE))
  result <- score_le8(
    input, diet_method = " DASH ", dash_cutpoints = dash_reference_fixture()
  )
  expect_identical(result$dash_total, c(8L, 40L))
  expect_equal(result$le8_diet_score, c(0, 100))
  expect_equal(result$le8_composite_score, c(87.5, 100))
  expect_identical(result$le8_n_components, c(8L, 8L))
  expect_true(all(is.na(result$mepa_total)))
  expect_true(all(is.na(result$hei2015_total)))
  expect_identical(result[names(input)], input)
})

test_that("every DASH quintile boundary and reverse-scored item is correct", {
  reference <- dash_reference_fixture()
  fields <- setdiff(names(reference), "total")
  reverse <- c("sodium", "red_and_processed_meat", "sweetened_beverages")
  for (field in fields) {
    # Each other item stays at its minimum, contributing seven points.
    rows <- lapply(c(0, 1, 1.001, 2, 2.001, 3, 3.001, 4, 4.001), function(x) {
      row <- adult_dash_row(FALSE)
      row[[paste0("dash_", field)]] <- x * if (field == "sodium") 1000 else 1
      row
    })
    quintile <- c(1, 1, 2, 2, 3, 3, 4, 4, 5)
    expected <- if (field %in% reverse) 6 - quintile else quintile
    result <- score_le8(
      do.call(rbind, rows), "dash", dash_cutpoints = reference
    )
    expect_equal(result$dash_total, 7 + expected, info = field)
  }
})

test_that("DASH total reference thresholds are inclusive and allow ties", {
  row <- adult_dash_row()
  for (i in 1:4) {
    reference <- dash_reference_fixture()
    reference$total <- c(rep(39, i), rep(40, 4 - i))
    row$dash_fruits <- 4 # 39 total
    result <- score_le8(row, "dash", dash_cutpoints = reference)
    expect_equal(result$dash_total, 39)
    expect_equal(result$le8_diet_score, c(25, 50, 80, 100)[i])
  }
  reference <- dash_reference_fixture()
  reference$fruits <- c(0, 0, 2, 2)
  row$dash_fruits <- 0
  expect_equal(score_le8(row, "dash", dash_cutpoints = reference)$dash_total, 36)
  row$dash_fruits <- 0.001
  expect_equal(score_le8(row, "dash", dash_cutpoints = reference)$dash_total, 38)
})

test_that("DASH scores are independent of batch composition and row order", {
  reference <- dash_reference_fixture()
  one <- score_le8(adult_dash_row(), "dash", dash_cutpoints = reference)
  many <- score_le8(
    rbind(adult_dash_row(FALSE), adult_dash_row(), adult_dash_row()),
    "dash", dash_cutpoints = reference
  )
  expect_equal(many$dash_total[2:3], rep(one$dash_total, 2))
  expect_equal(many$le8_diet_score[2:3], rep(one$le8_diet_score, 2))
})

test_that("DASH missing inputs preserve composite missing-data semantics", {
  row <- adult_dash_row()
  missing <- row
  missing$dash_fruits <- NA_real_
  result <- expect_no_warning(score_le8(
    rbind(row, missing), "dash", dash_cutpoints = dash_reference_fixture()
  ))
  expect_identical(result$dash_total, c(40L, NA_integer_))
  expect_equal(result$le8_n_components, c(8, 7))
  expect_equal(result$le8_composite_score, c(100, 100))
  strict <- score_le8(
    rbind(row, missing), "dash", min_components = 8,
    dash_cutpoints = dash_reference_fixture()
  )
  expect_true(is.na(strict$le8_composite_score[2]))
  missing$dash_fruits <- NULL
  expect_warning(
    result <- score_le8(missing, "dash", dash_cutpoints = dash_reference_fixture()),
    class = "essential8_missing_component"
  )
  expect_true(is.na(result$dash_total))
  missing$dash_sodium <- -1
  expect_error(
    score_le8(missing, "dash", dash_cutpoints = dash_reference_fixture()),
    class = "essential8_adult_input_error"
  )
})

test_that("DASH validates all reference cutpoints", {
  invalid <- list(NULL, list(), 1, data.frame(fruits = 1:4))
  reference <- dash_reference_fixture()
  for (field in names(reference)) {
    for (value in list(1:3, c(1, 3, 2, 4), c(1, 2, NA, 4),
                       c(1, 2, 3, Inf), letters[1:4], c(-1, 0, 1, 2),
                       matrix(1:4, nrow = 1))) {
      bad <- reference
      bad[[field]] <- value
      invalid[[length(invalid) + 1L]] <- bad
    }
  }
  bad <- reference
  bad$total <- c(8, 20, 30, 41)
  invalid[[length(invalid) + 1L]] <- bad
  bad <- reference
  names(bad)[1] <- "total"
  invalid[[length(invalid) + 1L]] <- bad
  bad <- reference
  bad$unknown <- 1:4
  invalid[[length(invalid) + 1L]] <- bad
  for (value in invalid) {
    expect_error(
      score_le8(adult_dash_row(), "dash", dash_cutpoints = value),
      class = "essential8_adult_input_error"
    )
  }
})
