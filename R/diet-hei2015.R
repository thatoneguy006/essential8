.adult_hei2015_fields <- function() {
  c(
    "energy_kcal", "total_fruits", "whole_fruits", "total_vegetables",
    "greens_and_beans", "whole_grains", "dairy", "total_protein_foods",
    "seafood_and_plant_proteins", "polyunsaturated_fat",
    "monounsaturated_fat", "saturated_fat", "refined_grains", "sodium",
    "added_sugars"
  )
}

.hei2015_component_names <- function() {
  c(
    "total_fruits", "whole_fruits", "total_vegetables", "greens_and_beans",
    "whole_grains", "dairy", "total_protein_foods",
    "seafood_and_plant_proteins", "fatty_acids", "refined_grains", "sodium",
    "added_sugars", "saturated_fats"
  )
}

.compute_adult_hei2015 <- function(data, hei2015_columns, hei2015_cutpoints) {
  cutpoints <- .validate_diet_cutpoints(
    hei2015_cutpoints, "hei2015_cutpoints", 0, 100
  )
  inputs <- .population_diet_inputs(
    data, hei2015_columns, .adult_hei2015_fields(), "hei2015"
  )
  energy <- inputs$energy_kcal
  if (any(energy <= 0, na.rm = TRUE)) {
    .abort_adult_scoring(
      "HEI-2015 {.field energy_kcal} must be greater than zero when observed."
    )
  }

  density <- function(field) inputs[[field]] / energy * 1000
  adequacy <- function(value, maximum, points) {
    pmin(points, pmax(0, value / maximum * points))
  }
  moderation <- function(value, best, worst) {
    pmin(10, pmax(0, (worst - value) / (worst - best) * 10))
  }
  fatty_acid_ratio <- (inputs$polyunsaturated_fat +
    inputs$monounsaturated_fat) / inputs$saturated_fat

  components <- cbind(
    total_fruits = adequacy(density("total_fruits"), 0.8, 5),
    whole_fruits = adequacy(density("whole_fruits"), 0.4, 5),
    total_vegetables = adequacy(density("total_vegetables"), 1.1, 5),
    greens_and_beans = adequacy(density("greens_and_beans"), 0.2, 5),
    whole_grains = adequacy(density("whole_grains"), 1.5, 10),
    dairy = adequacy(density("dairy"), 1.3, 10),
    total_protein_foods = adequacy(density("total_protein_foods"), 2.5, 5),
    seafood_and_plant_proteins = adequacy(
      density("seafood_and_plant_proteins"), 0.8, 5
    ),
    fatty_acids = adequacy(fatty_acid_ratio - 1.2, 2.5 - 1.2, 10),
    refined_grains = moderation(density("refined_grains"), 1.8, 4.3),
    sodium = moderation(density("sodium") / 1000, 1.1, 2),
    added_sugars = moderation(inputs$added_sugars * 16 / energy * 100, 6.5, 26),
    saturated_fats = moderation(inputs$saturated_fat * 9 / energy * 100, 8, 16)
  )
  # NCI's HEI-2015 macro explicitly assigns zero when all fats are zero.
  zero_fats <- inputs$saturated_fat == 0 &
    inputs$polyunsaturated_fat == 0 & inputs$monounsaturated_fat == 0
  components[which(zero_fats), "fatty_acids"] <- 0
  # Missing energy invalidates even the otherwise energy-independent fat ratio.
  components[is.na(energy), ] <- NA_real_
  components[is.nan(components)] <- NA_real_
  total <- rowSums(components)
  list(
    total = total,
    components = components,
    score = .score_population_diet_total(total, cutpoints)
  )
}
