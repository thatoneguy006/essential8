test_that("raw diets use packaged references and preserve auditable totals", {
  dash <- rbind(adult_dash_row(FALSE), adult_dash_row(TRUE))
  dash$dash_energy_kcal <- c(2000, 2000)
  hei <- rbind(adult_hei2015_row("worst"), adult_hei2015_row("best"))

  for (method in c("dash", "hei2015")) {
    input <- if (method == "dash") dash else hei
    result <- score_le8(input, method, reference = "nhanes_2015_2018")
    total <- result[[paste0(method, "_total")]]
    expect_equal(total, if (method == "dash") c(8, 40) else c(0, 100))
    expect_equal(result$le8_diet_score, c(0, 100))
    expect_equal(result$le8_composite_score, c(87.5, 100))
    expect_identical(result[names(input)], input)

    # The same indices must receive the same points through either route.
    indices <- input[!startsWith(names(input), paste0(method, "_"))]
    indices[[method]] <- total
    index_result <- score_le8(indices, method)
    expect_equal(result$le8_diet_score, index_result$le8_diet_score)
    if (method == "hei2015") {
      components <- paste0("hei2015_", .hei2015_component_names(), "_score")
      expect_length(components, 13L)
      expect_equal(rowSums(result[components]), total)
    }
  }
})

test_that("reference DASH standardizes sodium using observed energy", {
  input <- rbind(adult_dash_row(), adult_dash_row())
  input$dash_sodium <- c(2500, 5000)
  input$dash_energy_kcal <- c(1000, 2000)
  result <- score_le8(input, "dash")
  # All other components are maximal; sodium earns one point in each row.
  expect_identical(result$dash_total, c(36L, 36L))
  expect_equal(result$le8_diet_score[1], result$le8_diet_score[2])

  names(input)[names(input) == "dash_energy_kcal"] <- "Reported Energy"
  mapped <- score_le8(input, "dash",
                     dash_columns = c(energy_kcal = "reported energy"))
  expect_identical(mapped$dash_total, result$dash_total)
  for (energy in list(0, -1, Inf, "2000")) {
    bad <- adult_dash_row()
    bad$dash_energy_kcal <- energy
    expect_error(score_le8(bad, "dash"),
                 class = "essential8_adult_input_error")
  }
})

test_that("reference DASH matches explicit scoring of standardized intakes", {
  ref <- .resolve_diet_reference("dash", "nhanes_2015_2018")
  cuts <- c(ref$provenance$component_cutpoints,
            list(total = unlist(ref[c("p25", "p50", "p75", "p95")])))
  input <- rbind(adult_dash_row(FALSE), adult_dash_row())
  input$dash_energy_kcal <- c(1600, 2400)
  actual <- score_le8(input, "dash")
  standardized <- input
  standardized$dash_sodium <- input$dash_sodium / input$dash_energy_kcal * 2000
  standardized$dash_energy_kcal <- NULL
  expected <- score_le8(standardized, "dash", dash_cutpoints = cuts)
  expect_identical(actual$dash_total, expected$dash_total)
  expect_identical(actual$le8_diet_score, expected$le8_diet_score)
})

test_that("raw HEI supports custom references without explicit cutpoints", {
  ref <- diet_reference(40, 50, 60, 80, "hei2015")
  result <- score_le8(adult_hei2015_row("midpoint"), "hei2015",
                      reference = ref)
  expect_equal(result$hei2015_total, 50)
  expect_equal(result$le8_diet_score, 50)
  expect_error(score_le8(adult_hei2015_row(), "hei2015",
                        reference = diet_reference(10, 20, 30, 40, "dash")),
               class = "essential8_adult_input_error")
  expect_error(score_le8(adult_dash_row(), "dash",
                        reference = diet_reference(16, 24, 32, 39)),
               "intake quintiles", class = "essential8_adult_input_error")
})

test_that("explicit raw cutpoints still bypass reference lookup", {
  dash <- score_le8(adult_dash_row(), "dash",
                    dash_cutpoints = dash_reference_fixture(),
                    reference = "unused")
  hei <- score_le8(adult_hei2015_row(), "hei2015",
                   hei2015_cutpoints = hei2015_reference_fixture(),
                   reference = "unused")
  expect_equal(dash$dash_total, 40)
  expect_equal(hei$hei2015_total, 100)
  expect_equal(c(dash$le8_diet_score, hei$le8_diet_score), c(100, 100))
})

test_that("raw reference scoring retains missing and empty data semantics", {
  for (method in c("dash", "hei2015")) {
    input <- if (method == "dash") adult_dash_row() else adult_hei2015_row()
    if (method == "dash") input$dash_energy_kcal <- 2000
    missing <- input
    field <- paste0(method, "_energy_kcal")
    missing[[field]] <- NA_real_
    result <- score_le8(rbind(input, missing), method, min_components = 8)
    expect_equal(result$le8_n_components, c(8, 7))
    expect_true(is.na(result[[paste0(method, "_total")]][2]))
    expect_true(is.na(result$le8_composite_score[2]))
    missing[[field]] <- NULL
    expect_warning(score_le8(missing, method),
                   class = "essential8_missing_component")

    empty <- expect_no_warning(score_le8(input[0, ], method))
    expect_identical(empty$dash_total, integer())
    expect_identical(empty$hei2015_total, numeric())
    expect_identical(empty$le8_diet_score, numeric())
  }
})

test_that("raw references do not depend on cohort size or row ordering", {
  for (method in c("dash", "hei2015")) {
    input <- if (method == "dash") adult_dash_row() else adult_hei2015_row()
    if (method == "dash") input$dash_energy_kcal <- 2000
    single <- score_le8(input, method)
    repeated <- score_le8(input[rep(1L, 3), ], method)
    expect_equal(repeated$le8_diet_score, rep(single$le8_diet_score, 3))
    for (column in c(method, "diet_value")) {
      mixed <- input
      mixed[[column]] <- 95
      expect_error(score_le8(mixed, method), "either",
                   class = "essential8_adult_input_error")
    }
    input[[if (method == "dash") "hei2015" else "dash"]] <- 30
    expect_error(score_le8(input, method), "unrelated",
                 class = "essential8_adult_input_error")
  }
})

test_that("population index metadata does not trigger raw intake scoring", {
  for (method in c("dash", "hei2015")) {
    input <- adult_example_row()
    input[[method]] <- if (method == "dash") 40 else 100
    input[[paste0(method, "_source")]] <- "Study metadata"
    result <- score_le8(input, method)
    expect_equal(result$le8_diet_score, 100)
    expect_identical(result[names(input)], input)
  }
})
