# Get started with essential8

## Overview

`essential8` computes component and composite Life’s Essential 8 (LE8)
cardiovascular health scores. The current implementation scores adults
aged 20 years or older using the American Heart Association’s 2022
definition. Pediatric scoring is not yet available.

This vignette shows the basic complete-data workflow. See
[`?score_le8`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
for the full input contract and scoring details.

## Create an adult data frame

Supply one row per person. The example below uses base R and includes
two adults with raw responses to the 16-item Mediterranean Eating
Pattern for Americans (MEPA) screener. It also demonstrates both
possible BMI profiles and both possible glucose measures.

``` r

library(essential8)

adult_data <- data.frame(
  id = c("patient_1", "patient_2"),
  age = c(42, 61),
  sex = c("female", "male"),
  # Daily servings
  olive_oil = c(2, 1),
  green_leafy_vegetables = c(1, 0.5),
  other_vegetables = c(2, 1),
  whole_grains = c(2, 1),
  # Weekly servings
  berries = c(3, 1),
  other_fruit = c(5, 2),
  meat = c(2, 5),
  fish = c(3, 1),
  chicken = c(2, 4),
  cheese = c(1, 4),
  butter_cream = c(1, 5),
  beans = c(3, 1),
  sweets_and_pastries = c(1, 5),
  nuts = c(4, 1),
  fast_food = c(0, 2),
  alcohol = c(4, 0),
  moderate_activity_minutes = c(100, 60),
  vigorous_activity_minutes = c(25, 0),
  smoking_status = c("never", "former"),
  years_since_quit = c(0, 6),
  current_inhaled_nds = c(FALSE, FALSE),
  secondhand_smoke_home = c(FALSE, FALSE),
  sleep_hours = c(7.5, 6.5),
  bmi = c(24.2, 24.0),
  bmi_profile = c("general", "asian_pacific"),
  non_hdl_cholesterol = c(125, 145),
  lipid_lowering_treatment = c(FALSE, TRUE),
  diabetes = c(FALSE, FALSE),
  glucose_measure = c("fasting_glucose", "hba1c"),
  glucose_value = c(95, 6.0),
  systolic_bp = c(118, 132),
  diastolic_bp = c(76, 84),
  antihypertensive_treatment = c(FALSE, TRUE)
)
```

## Compute LE8 scores

Pass the data frame to
[`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md).
The returned data frame retains the input columns and appends the
derived activity measure, eight component scores, composite score, and
category.

``` r

scored <- score_le8(adult_data, diet_method = "mepa")

scored[c(
  "id",
  "mepa_total",
  "le8_diet_score",
  "physical_activity_moderate_equivalent_minutes",
  "le8_composite_score",
  "le8_category"
)]
#>          id mepa_total le8_diet_score
#> 1 patient_1         14             80
#> 2 patient_2          4             25
#>   physical_activity_moderate_equivalent_minutes le8_composite_score
#> 1                                           150              97.500
#> 2                                            60              54.375
#>   le8_category
#> 1         high
#> 2     moderate
```

Each vigorous activity minute counts as two moderate activity minutes
and is recorded as `physical_activity_moderate_equivalent_minutes`. The
`le8_composite_score` is the mean of the eight component scores.
Categories are `"low"` below 50, `"moderate"` from 50 to less than 80,
and `"high"` at 80 or higher.

The component scores are available for analysis and quality checks:

``` r

component_columns <- setdiff(
  grep("^le8_.*_score$", names(scored), value = TRUE),
  "le8_composite_score"
)

scored[c("id", component_columns)]
#>          id le8_diet_score le8_physical_activity_score le8_nicotine_score
#> 1 patient_1             80                         100                100
#> 2 patient_2             25                          60                 75
#>   le8_sleep_score le8_bmi_score le8_blood_lipids_score le8_blood_glucose_score
#> 1             100           100                    100                     100
#> 2              70            75                     40                      60
#>   le8_blood_pressure_score
#> 1                      100
#> 2                       30
```

## Understand the MEPA inputs

The MEPA response columns use the 16 screener-item labels in snake case.
The column names should reflect as seen below, but you can map custom
columns using `mepa_columns = c()`.

- `olive_oil`, `green_leafy_vegetables`, `other_vegetables`, and
  `whole_grains` are servings per day.
- `berries`, `other_fruit`, `meat`, `fish`, `chicken`, `cheese`,
  `butter_cream`, `beans`, `sweets_and_pastries`, `nuts`, and `alcohol`
  are servings per week.
- `fast_food` is the number of times per week that meals are consumed
  from fast-food restaurants.

The screener defines `meat` as red meat, hamburger, bacon, or sausage;
`fish` includes fish, shellfish, or seafood; and `cheese` means full-fat
or regular cheese or cream cheese.

[`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
evaluates each criterion and returns their sum as `mepa_total` so that
the derived diet input can be audited. The default MEPA sex field is
`sex`. If `sex` is absent, a field named `female` is recognized
automatically; map any other name with, for example,
`mepa_columns = c(sex = "reported_sex")`. Values are trimmed and matched
case-insensitively as `"m"`/`"f"` or `"male"`/`"female"`. Numeric or
character `0`/`1` values are also accepted, where `0` is male and `1` is
female.

## Choose other input methods explicitly

The `diet_method` argument defaults to `"mepa"`. If a source data set
contains both MEPA and percentile inputs, split the rows into separate
data frames and call
[`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
separately for each method.

- For `diet_method = "mepa"`, `diet_value` must be absent or contain
  only missing values.
- For `diet_method = "percentile"`, `diet_value` is required; MEPA
  columns are ignored. Supply a DASH or HEI-2015 percentile from 1 to
  100, calculated against the relevant reference population before
  calling
  [`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md).
- Set `bmi_profile` to either `"general"` or `"asian_pacific"`. The
  function does not infer a BMI profile from race or ethnicity.
- Set `glucose_measure` to `"fasting_glucose"` for a value in mg/dL or
  `"hba1c"` for a percentage. Diagnosed diabetes requires HbA1c for
  scoring.

The percentile workflow is executable without removing the unused MEPA
columns:

``` r

percentile_data <- adult_data[1, , drop = FALSE]
percentile_data$diet_value <- 95
percentile_scores <- score_le8(
  percentile_data,
  diet_method = "percentile"
)
percentile_scores[
  c("diet_value", "le8_diet_score", "le8_composite_score")
]
#>   diet_value le8_diet_score le8_composite_score
#> 1         95            100                 100
```

Three optional, caller-adjudicated flags control clinical-judgment
adjustments: `apply_lean_muscular_bmi_override`,
`apply_sleep_apnea_penalty`, and `apply_prediabetes_metformin_penalty`.
When these columns are absent, their adjustments are not applied.

## Complete and source-defined inputs

The current implementation requires complete, finite values for every
required input. It does not impute missing data, convert units, or round
raw measurements before scoring.

[`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
also rejects combinations for which the AHA source does not define a
score. Examples include an underweight BMI that requires clinical
judgment, a diagnostic-range glucose value paired with no diabetes
diagnosis, and simultaneous current combustible smoking and inhaled
nicotine-delivery-system use. Reconcile these records before scoring.
