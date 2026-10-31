# Get started with essential8

## Overview

`essential8` computes component and composite Life’s Essential 8 (LE8)
cardiovascular health scores. The current implementation scores adults
aged 20 years or older using the American Heart Association’s 2022
definition. Pediatric scoring is not yet available.

This vignette shows how to score complete and incomplete data. The
examples use `dplyr` and the native pipe (`|>`, available in R 4.1+).
See
[`?score_le8`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
for all input requirements and scoring details.

## Create an adult data frame

Supply one row per person. The example includes two adults with
responses to the 16-item Mediterranean Eating Pattern for Americans
(MEPA) screener. It shows both BMI profiles and both glucose measures.

``` r

library(essential8)
library(dplyr)
#> 
#> Attaching package: 'dplyr'
#> The following objects are masked from 'package:stats':
#> 
#>     filter, lag
#> The following objects are masked from 'package:base':
#> 
#>     intersect, setdiff, setequal, union

adult_data <- tibble(
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
derived activity measure, eight component scores, the number of
contributing components, composite score, completeness indicator, and
category.

``` r

scored <- adult_data |>
  score_le8(diet_method = "mepa")

scored |>
  select(id, mepa_total, le8_diet_score, le8_composite_score, le8_category)
#>          id mepa_total le8_diet_score le8_composite_score le8_category
#> 1 patient_1         14             80              97.500         high
#> 2 patient_2          4             25              54.375     moderate
```

Each vigorous activity minute counts as two moderate activity minutes
and is recorded as `physical_activity_moderate_equivalent_minutes`. The
`le8_composite_score` is the mean of the eight component scores for
complete records. Categories are `"low"` below 50, `"moderate"` from 50
to less than 80, and `"high"` at 80 or higher.

The component scores are available for analysis and quality checks:

``` r

scored |>
  select(id, starts_with("le8_") & ends_with("_score"), -le8_composite_score)
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

The MEPA response columns use the 16 screener-item labels shown above.
Use `mepa_columns` to map different column names to these labels.

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
- For `diet_method = "percentile"`, MEPA columns are ignored. Supply
  `diet_value` as a DASH or HEI-2015 percentile from 0 to 100,
  calculated against the relevant reference population before calling
  [`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md).
  If it is absent or missing, the diet component cannot be scored.
- Set `bmi_profile` to either `"general"` or `"asian_pacific"`. The
  function does not infer a BMI profile from race or ethnicity.
- Set `glucose_measure` to `"fasting_glucose"` for a value in mg/dL or
  `"hba1c"` for a percentage. Diagnosed diabetes requires HbA1c for
  scoring.

The percentile workflow is executable without removing the unused MEPA
columns:

``` r

adult_data |>
  mutate(diet_value = c(35, 95)) |>
  score_le8(diet_method = "percentile") |>
  select(id, diet_value, le8_diet_score, le8_composite_score)
#>          id diet_value le8_diet_score le8_composite_score
#> 1 patient_1         35             25              90.625
#> 2 patient_2         95            100              63.750
```

Use `diet_method = "dash"` or `"hei2015"` with raw food and nutrient
inputs, an existing diet score, or a percentile. See
[`vignette("population-diets", package = "essential8")`](https://thatoneguy006.github.io/essential8/articles/population-diets.md)
for the background, scoring rules, and examples.

Three optional flags apply adjustments that require clinical judgment:
`apply_lean_muscular_bmi_override`, `apply_sleep_apnea_penalty`, and
`apply_prediabetes_metformin_penalty`. When these columns are absent,
their adjustments are not applied.

## Work with incomplete component data

Component inputs may be missing or their columns may be omitted. Missing
values are not filled in, and measurements are not rounded. Supply
values in the documented units. `age` must be complete and at least 20
for every row.

By default,
[`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
calculates the composite when at least seven of the eight component
scores are available. Choose any threshold from 1 through 8 with
`min_components`. The composite is the mean of the available components
when the threshold is met.

``` r

adult_data |>
  mutate(sleep_hours = c(NA_real_, 6.5)) |>
  score_le8(min_components = 7) |>
  select(id, le8_composite_score, le8_n_components, le8_complete)
#>          id le8_composite_score le8_n_components le8_complete
#> 1 patient_1            97.14286                7        FALSE
#> 2 patient_2            54.37500                8         TRUE
```

`le8_n_components` reports how many components were scored.
`le8_complete` is `TRUE` when all eight are available. Missing values in
individual rows do not trigger warnings. If a component cannot be scored
for anyone, a warning names it. The warning also explains when too few
components are available to calculate any composite scores.

## Source-defined inputs

[`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
returns an error when the AHA definition does not assign a score.
Examples include a BMI below 18.5, which requires clinical judgment; a
glucose value in the diabetes range with no recorded diabetes diagnosis;
and current use of both combustible tobacco and an inhaled
nicotine-delivery system. Review these records before scoring.
