test_that("HEI-2015 endpoints and midpoints reproduce manual totals", {
  input <- do.call(rbind, lapply(
    c("worst", "midpoint", "best"), adult_hei2015_row
  ))
  result <- score_le8(
    input, " HEI2015 ", hei2015_cutpoints = hei2015_reference_fixture()
  )
  maximum <- c(5, 5, 5, 5, 10, 10, 5, 5, 10, 10, 10, 10, 10)
  component_names <- c(
    "total_fruits", "whole_fruits", "total_vegetables", "greens_and_beans",
    "whole_grains", "dairy", "total_protein_foods",
    "seafood_and_plant_proteins", "fatty_acids", "refined_grains", "sodium",
    "added_sugars", "saturated_fats"
  )
  actual <- as.matrix(result[paste0("hei2015_", component_names, "_score")])
  expect_equal(unname(actual), unname(rbind(maximum * 0, maximum / 2, maximum)))
  expect_equal(result$hei2015_total, c(0, 50, 100))
  expect_equal(result$le8_diet_score, c(0, 25, 100))
  expect_equal(result$le8_composite_score, c(87.5, 90.625, 100))
  expect_true(all(is.na(result$dash_total)))
  expect_true(all(is.na(result$mepa_total)))
})

test_that("HEI-2015 densities and ratios are invariant to intake scaling", {
  row <- adult_hei2015_row("midpoint")
  scaled <- row
  fields <- grep("^hei2015_", names(row), value = TRUE)
  scaled[fields] <- lapply(scaled[fields], function(x) x * 2)
  result <- score_le8(
    rbind(row, scaled), "hei2015",
    hei2015_cutpoints = hei2015_reference_fixture()
  )
  expect_equal(result$hei2015_total, c(50, 50))
})

test_that("HEI-2015 components clamp beyond both scoring endpoints", {
  best <- adult_hei2015_row()
  adequacy <- paste0("hei2015_", c(
    "total_fruits", "whole_fruits", "total_vegetables", "greens_and_beans",
    "whole_grains", "dairy", "total_protein_foods", "seafood_and_plant_proteins"
  ))
  best[adequacy] <- lapply(best[adequacy], function(x) x * 2)
  best$hei2015_refined_grains <- 0
  best$hei2015_sodium <- 0
  best$hei2015_added_sugars <- 0
  worst <- adult_hei2015_row("worst")
  worst$hei2015_sodium <- 3000
  worst$hei2015_refined_grains <- 6
  worst$hei2015_added_sugars <- 25
  worst$hei2015_saturated_fat <- 25
  result <- score_le8(
    rbind(best, worst), "hei2015",
    hei2015_cutpoints = hei2015_reference_fixture()
  )
  expect_equal(result$hei2015_total, c(100, 0))
})

test_that("HEI-2015 missing nutrients propagate without partial totals", {
  best <- adult_hei2015_row()
  missing <- best
  missing$hei2015_sodium <- NA_real_
  result <- expect_no_warning(score_le8(
    rbind(best, missing), "hei2015",
    hei2015_cutpoints = hei2015_reference_fixture()
  ))
  expect_true(is.na(result$hei2015_total[2]))
  expect_true(is.na(result$hei2015_sodium_score[2]))
  expect_equal(result$hei2015_total_fruits_score, c(5, 5))
  expect_equal(result$le8_n_components, c(8, 7))
  expect_equal(result$le8_composite_score, c(100, 100))
  missing$hei2015_sodium <- NULL
  expect_warning(
    score_le8(missing, "hei2015",
              hei2015_cutpoints = hei2015_reference_fixture()),
    class = "essential8_missing_component"
  )
})

test_that("HEI-2015 energy and zero-fat edge cases are explicit", {
  row <- adult_hei2015_row()
  row$hei2015_saturated_fat <- 0
  result <- score_le8(
    row, "hei2015", hei2015_cutpoints = hei2015_reference_fixture()
  )
  expect_equal(result$hei2015_fatty_acids_score, 10)
  expect_equal(result$hei2015_total, 100)
  row$hei2015_polyunsaturated_fat <- 0
  result <- suppressWarnings(score_le8(
    row, "hei2015", hei2015_cutpoints = hei2015_reference_fixture()
  ))
  expect_identical(result$hei2015_fatty_acids_score, 0)
  expect_equal(result$hei2015_total, 90)
  row$hei2015_energy_kcal <- NA_real_
  result <- suppressWarnings(score_le8(
    row, "hei2015", hei2015_cutpoints = hei2015_reference_fixture()
  ))
  components <- grep("^hei2015_.*_score$", names(result), value = TRUE)
  expect_true(all(is.na(result[components])))
  for (energy in c(0, -1, Inf)) {
    row$hei2015_energy_kcal <- energy
    expect_error(
      score_le8(row, "hei2015",
                hei2015_cutpoints = hei2015_reference_fixture()),
      class = "essential8_adult_input_error"
    )
  }
})

test_that("HEI-2015 fatty-acid endpoints include MUFA and PUFA", {
  rows <- lapply(c(1.2, 1.85, 2.5), function(ratio) {
    row <- adult_hei2015_row()
    row$hei2015_saturated_fat <- 10
    row$hei2015_monounsaturated_fat <- 5
    row$hei2015_polyunsaturated_fat <- ratio * 10 - 5
    row
  })
  result <- score_le8(
    do.call(rbind, rows), "hei2015",
    hei2015_cutpoints = hei2015_reference_fixture()
  )
  expect_equal(result$hei2015_fatty_acids_score, c(0, 5, 10))
  rows[[1]]$hei2015_polyunsaturated_fat <- NA_real_
  missing <- suppressWarnings(score_le8(
    rows[[1]], "hei2015", hei2015_cutpoints = hei2015_reference_fixture()
  ))
  expect_true(is.na(missing$hei2015_fatty_acids_score))
  expect_true(is.na(missing$hei2015_total))
})

test_that("HEI-2015 uses fixed reference thresholds with inclusive equality", {
  row <- adult_hei2015_row()
  result <- score_le8(row, "hei2015", hei2015_cutpoints = rep(100, 4))
  expect_equal(result$le8_diet_score, 100)
  # Totals of 95/97.5/100 from a single 0/2.5/5 point fruit component.
  rows <- lapply(c(0, 0.4, 0.64, 0.8), function(x) {
    row <- adult_hei2015_row()
    row$hei2015_total_fruits <- x
    row
  })
  result <- score_le8(
    do.call(rbind, rows), "hei2015", hei2015_cutpoints = c(95, 97.5, 99, 100)
  )
  expect_equal(result$hei2015_total, c(95, 97.5, 99, 100))
  expect_equal(result$le8_diet_score, c(25, 50, 80, 100))
  singleton <- score_le8(rows[[2]], "hei2015",
                        hei2015_cutpoints = c(95, 97.5, 99, 100))
  expect_equal(singleton$le8_diet_score, result$le8_diet_score[2])
})

test_that("explicit HEI-2015 reference cutpoints are validated", {
  for (reference in list(numeric(), c(0, 50, 101, 101),
                         c(0, 50, NA, 100), c(0, 70, 50, 100),
                         c(0, 50, 80, Inf), letters[1:4])) {
    expect_error(
      score_le8(adult_hei2015_row(), "hei2015", hei2015_cutpoints = reference),
      class = "essential8_adult_input_error"
    )
  }
})
