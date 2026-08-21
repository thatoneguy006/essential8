# essential8 ![](reference/figures/essential8_favicon.png)

## Overview

`essential8` provides reproducible R implementations of the American
Heart Association Life’s Essential 8 cardiovascular health scoring
framework.

The current development version implements complete-data adult scoring
for people aged 20 years or older. Pediatric scoring is planned but not
yet implemented.

## Installation

``` r

install.packages("essential8")
```

Install the development version from GitHub with:

``` r

# install.packages("remotes")
remotes::install_github("thatoneguy006/essential8")
```

## Basic use

Create one row per person, then pass the data frame to
[`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md):

``` r

library(essential8)

patient <- data.frame(
  id = "patient_1",
  age = 55,
  sex = "female",
  diet_method = "mepa",
  # Daily servings
  olive_oil = 2,
  green_leafy_vegetables = 1,
  other_vegetables = 2,
  whole_grains = 2,
  # Weekly servings
  berries = 3,
  other_fruit = 5,
  meat = 2,
  fish = 3,
  chicken = 2,
  cheese = 1,
  butter_cream = 1,
  beans = 3,
  sweets_and_pastries = 1,
  nuts = 4,
  alcohol = 4,
  # Fast-food meals per week
  fast_food = 0,
  moderate_activity_minutes = 90,
  vigorous_activity_minutes = 0,
  smoking_status = "former",
  years_since_quit = 6,
  current_inhaled_nds = FALSE,
  secondhand_smoke_home = FALSE,
  sleep_hours = 7.5,
  bmi = 27.5,
  bmi_profile = "general",
  non_hdl_cholesterol = 145,
  lipid_lowering_treatment = FALSE,
  diabetes = FALSE,
  glucose_measure = "fasting_glucose",
  glucose_value = 95,
  systolic_bp = 128,
  diastolic_bp = 78,
  antihypertensive_treatment = FALSE
)

scores <- score_le8(patient)
scores[c("id", "mepa_total", "le8_diet_score", "le8_score", "le8_category")]
```

For `diet_method = "mepa"`, the package calculates `mepa_total` directly
from the 16 screener responses. Their column names must be the screener
labels shown above, with underscores between words. Matching is
case-insensitive but does not guess alternative names. The result also
appends all eight component scores, the exact unrounded composite score,
and its cardiovascular health category. See
[`?score_le8`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
for the complete input contract and optional clinical-judgment flags.

For a guided introduction with reproducible multi-person examples, run:

``` r

vignette("get-started", package = "essential8")
```

## Disclaimer

`essential8` is independent research software and is not affiliated
with, sponsored by, approved by, or endorsed by the American Heart
Association. It is not intended for clinical decision support.

## References

- Lloyd-Jones, D. M., Allen, N. B., Anderson, C. A. M., et al. (2022).
  Life’s Essential 8: Updating and Enhancing the American Heart
  Association’s Construct of Cardiovascular Health: A Presidential
  Advisory From the American Heart Association. *Circulation*, 146(5),
  e18-e43. <https://doi.org/10.1161/CIR.0000000000001078>
- Lloyd-Jones, D. M., Ning, H., Labarthe, D., et al. (2022). Status of
  Cardiovascular Health in US Adults and Children Using the American
  Heart Association’s New Life’s Essential 8 Metrics. *Circulation*,
  146(11), 822-835. <https://doi.org/10.1161/CIRCULATIONAHA.122.060911>
