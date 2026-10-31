# Synthetic inputs and reference cutpoints; these are not NHANES estimates.
dash_reference_fixture <- function() {
  list(
    fruits = c(1, 2, 3, 4),
    vegetables = c(1, 2, 3, 4),
    nuts_and_legumes = c(1, 2, 3, 4),
    whole_grains = c(1, 2, 3, 4),
    low_fat_dairy = c(1, 2, 3, 4),
    sodium = c(1000, 2000, 3000, 4000),
    red_and_processed_meat = c(1, 2, 3, 4),
    sweetened_beverages = c(1, 2, 3, 4),
    total = c(16, 24, 32, 39)
  )
}

adult_dash_row <- function(best = TRUE) {
  row <- adult_example_row()
  row$diet_value <- NULL
  row[c("sex", adult_mepa_columns())] <- NULL
  values <- if (best) {
    c(5, 5, 5, 5, 5, 0, 0, 0)
  } else {
    c(0, 0, 0, 0, 0, 5000, 5, 5)
  }
  fields <- c(
    "fruits", "vegetables", "nuts_and_legumes", "whole_grains",
    "low_fat_dairy", "sodium", "red_and_processed_meat",
    "sweetened_beverages"
  )
  for (i in seq_along(fields)) {
    row[[paste0("dash_", fields[i])]] <- values[i]
  }
  row
}

hei2015_reference_fixture <- function() c(40, 60, 80, 95)

adult_hei2015_row <- function(level = c("best", "midpoint", "worst")) {
  level <- match.arg(level)
  row <- adult_example_row()
  row$diet_value <- NULL
  row[c("sex", adult_mepa_columns())] <- NULL
  # All 13 components independently earn their maximum, half, or zero.
  values <- switch(
    level,
    best = c(1000, 0.8, 0.4, 1.1, 0.2, 1.5, 1.3, 2.5, 0.8,
             30, 0, 8 * 1000 / 900, 1.8, 1100, 6.5 * 1000 / 1600),
    midpoint = c(1000, 0.4, 0.2, 0.55, 0.1, 0.75, 0.65, 1.25, 0.4,
                 1.85 * 12 * 1000 / 900, 0, 12 * 1000 / 900,
                 3.05, 1550, 16.25 * 1000 / 1600),
    worst = c(1000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
              16 * 1000 / 900, 4.3, 2000, 26 * 1000 / 1600)
  )
  fields <- c(
    "energy_kcal", "total_fruits", "whole_fruits", "total_vegetables",
    "greens_and_beans", "whole_grains", "dairy", "total_protein_foods",
    "seafood_and_plant_proteins", "polyunsaturated_fat",
    "monounsaturated_fat", "saturated_fat", "refined_grains", "sodium",
    "added_sugars"
  )
  for (i in seq_along(fields)) {
    row[[paste0("hei2015_", fields[i])]] <- values[i]
  }
  row
}
