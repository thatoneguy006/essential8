test_that("direct diet percentiles share a vectorized, NA-preserving scorer", {
  examples <- c(12, 35, 60, 82, 98, NA_real_)
  expect_identical(.score_diet_percentile(examples), c(0, 25, 50, 80, 100, NA_real_))
  expect_identical(.score_diet_percentile(c(0, 100)), c(0, 100))
  expect_identical(.score_diet_percentile(NA), NA_real_)
  expect_identical(.score_diet_percentile(numeric()), numeric())
  for (boundary in c(25, 50, 75, 95)) {
    scores <- .score_diet_percentile(c(boundary - 0.001, boundary))
    expect_true(scores[1] < scores[2])
  }
  for (bad in list(-1, 101, Inf, "95", matrix(95, 1), 0.95, c(0, 0.5, 1))) {
    expect_error(.score_diet_percentile(bad), class = "essential8_adult_input_error")
  }
})

test_that("references carry method tags and validate scalar cutpoints", {
  ref <- diet_reference(40, 55, 65, 80, "hei2015", label = "Synthetic")
  expect_s3_class(ref, "essential8_diet_reference")
  expect_identical(.resolve_diet_reference("hei2015", ref), ref)
  expect_output(print(ref), "Synthetic")
  for (bad in list(NA_real_, Inf, "40", numeric(), c(1, 2))) {
    expect_error(diet_reference(bad, 55, 65, 80),
                 class = "essential8_adult_input_error")
  }
  expect_error(diet_reference(60, 55, 65, 80),
               class = "essential8_adult_input_error")
  expect_error(diet_reference(-1, 55, 65, 80, "hei2015"),
               class = "essential8_adult_input_error")
  expect_error(diet_reference(40, 55, 65, 101, "hei2015"),
               class = "essential8_adult_input_error")
  expect_error(diet_reference(1, 2, 3, 4, "HEI-15"),
               class = "essential8_adult_input_error")
  expect_error(.resolve_diet_reference("dash", ref), "for hei2015",
               class = "essential8_adult_input_error")
  expect_error(.resolve_diet_reference("dash", "nhanes_current"),
               class = "essential8_adult_input_error")
  expect_error(.resolve_diet_reference("dash", NULL),
               class = "essential8_adult_input_error")
  ref$p50 <- -10
  expect_error(.resolve_diet_reference("hei2015", ref),
               class = "essential8_adult_input_error")
  ref <- diet_reference(40, 55, 65, 80, "hei2015")
  ref$score_range <- NULL
  validated <- .resolve_diet_reference("hei2015", ref)
  expect_error(.diet_index_to_score(101, validated),
               class = "essential8_adult_input_error")
})

test_that("custom references permit ties and keep metadata outside scoring", {
  ref <- diet_reference(10, 10, 20, 30, "dash")
  score <- c(9, 10, 19, 20, 30, NA)
  expected <- c(0, 50, 50, 80, 100, NA)
  expect_equal(.diet_index_to_score(score, ref), expected)
  ref$label <- "Different label"
  ref$source <- "Different source"
  expect_equal(.diet_index_to_score(score, ref), expected)
  # Custom DASH variants have no invented global 8-to-40 range.
  ref <- diet_reference(0.2, 0.4, 0.6, 0.8, "dash")
  expect_equal(.diet_index_to_score(c(0, 1), ref), c(0, 100))
})

test_that("packaged NHANES references have reproducible provenance and bounds", {
  for (method in c("dash", "hei2015")) {
    ref <- .resolve_diet_reference(method, "nhanes_2015_2018")
    cutpoints <- unlist(ref[c("p25", "p50", "p75", "p95")])
    expect_true(all(is.finite(cutpoints)))
    expect_true(all(diff(cutpoints) >= 0))
    expect_true(all(cutpoints >= ref$score_range[1]))
    expect_true(all(cutpoints <= ref$score_range[2]))
    expect_identical(ref$provenance$nhanes_cycles, c("2015-2016", "2017-2018"))
    expect_true(ref$provenance$n > 1000)
    expect_match(ref$provenance$weighting, "WTDR2D / 2", fixed = TRUE)
    expect_match(ref$provenance$build_script_sha256, "^[a-f0-9]{64}$")
    expect_true(all(grepl("^[a-f0-9]{64}$", ref$provenance$sources$sha256)))
    expect_match(ref$provenance$percentile_method, "svyquantile", fixed = TRUE)
    expect_equal(sum(unlist(ref$provenance$n_by_cycle)), ref$provenance$n)
    # Boundaries come from the derived object, not a copied source-table fixture.
    for (cutpoint in cutpoints) {
      pair <- .diet_index_to_score(c(cutpoint - 1e-7, cutpoint), ref)
      expect_true(pair[1] < pair[2])
    }
    expect_equal(.diet_index_to_score(NA_real_, ref), NA_real_)
    expect_error(.diet_index_to_score(ref$score_range[2] + 1, ref),
                 class = "essential8_adult_input_error")
  }
})

test_that("typed direct-percentile calls bypass reference lookup", {
  for (method in c("dash", "hei2015")) {
    input <- adult_example_row(diet_value = 82)
    input[c("sex", adult_mepa_columns())] <- NULL
    result <- score_le8(input, method, reference = "not_used_for_percentiles")
    expect_equal(result$le8_diet_score, 80)
    expect_equal(result$le8_n_components, 8)
    expect_false(any(grepl("^hei2015_.*_score$", names(result))))
    expect_identical(result[names(input)], input)
    input$diet_value <- 0
    expect_equal(score_le8(input, method)$le8_diet_score, 0)
  }
})

test_that("precomputed indices integrate with LE8 without cohort ranking", {
  for (method in c("dash", "hei2015")) {
    ref <- .resolve_diet_reference(method, "nhanes_2015_2018")
    row <- adult_example_row()
    row$diet_value <- NULL
    row[c("sex", adult_mepa_columns())] <- NULL
    row[[method]] <- ref$p75
    original <- score_le8(row, method)
    extreme <- row
    extreme[[method]] <- ref$score_range[1]
    combined <- score_le8(rbind(extreme, row, extreme), method)
    expect_equal(original$le8_diet_score, 80)
    expect_equal(combined$le8_diet_score[2], original$le8_diet_score)
    expect_equal(original$le8_composite_score, 97.5)
    expect_identical(original[names(row)], row)
    row[[method]] <- NA_real_
    missing <- suppressWarnings(score_le8(row, method))
    expect_identical(missing$le8_diet_score, NA_real_)
    expect_equal(missing$le8_n_components, 7)
    row <- row[0, ]
    empty <- expect_no_warning(score_le8(row, method))
    expect_identical(empty$le8_diet_score, numeric())
  }
})

test_that("population inputs are exclusive and method compatible", {
  for (method in c("dash", "hei2015")) {
    row <- adult_example_row(diet_value = 95)
    row[c("sex", adult_mepa_columns())] <- NULL
    row[[method]] <- 30
    expect_error(score_le8(row, method), "either",
                 class = "essential8_adult_input_error")
    row$diet_value <- NULL
    other <- if (method == "dash") "hei2015" else "dash"
    row[[other]] <- 50
    expect_error(score_le8(row, method), "unrelated",
                 class = "essential8_adult_input_error")
    row[[other]] <- NULL
    expect_error(score_le8(row, "mepa"),
                 class = "essential8_adult_input_error")
    bad_ref <- diet_reference(10, 20, 30, 40, other)
    expect_error(score_le8(row, method, reference = bad_ref),
                 class = "essential8_adult_input_error")
  }
})

test_that("custom references work through the public scorer", {
  row <- adult_example_row()
  row$diet_value <- NULL
  row$hei2015 <- 70
  ref <- diet_reference(40, 50, 60, 80, "hei2015", label = "Synthetic")
  expect_equal(score_le8(row, "hei2015", reference = ref)$le8_diet_score, 80)
})
