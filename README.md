# essential8 <img src="man/figures/essential8_favicon.png" align="right" height="160" alt="" />

<!-- badges: start -->
[![R-CMD-check](https://github.com/thatoneguy006/essential8/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/thatoneguy006/essential8/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/thatoneguy006/essential8/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/thatoneguy006/essential8/actions/workflows/pkgdown.yaml)
<!-- badges: end -->

## Overview

`essential8` provides reproducible R implementations of the American Heart
Association Life's Essential 8 cardiovascular health scoring framework.

The current development version implements complete-data adult scoring for
people aged 20 years or older. Pediatric scoring is planned but not yet
implemented.

## Installation

```r
install.packages("essential8")
```

Install the development version from GitHub with:

```r
# install.packages("remotes")
remotes::install_github("thatoneguy006/essential8")
```

## Background
The American Heart Association Life's Essential 8 (LE8) score is made up of 8 lifestyle
components which are combined to create a composite outlook of an individual's
overall cardiovascular health profile. Currently, the only way to compute the
LE8 score is to define a custom function or use the official tool online.
This can be tedious to do, especially given that the online tool can only be used
on a per-individual basis, and if you decide to create a custom function,
the difference in scoring methods for adult and pediatric populations can be burdensome
to program correctly.


The purpose of this package is to streamline the ability to compute not only the composite LE8
score, but also the sub-components, taking into account all of the nuances specific
to the adult and pediatric populations. This package also allows for some provider-specific
alterations to the scores, outlined in Lloyd-Jones et. al. (2022).


The composite LE8 score is simply the mean of all user provided scores. So,
if a user only has 4/8 subscores, the composite is calculated based on these 4
sub-components. However, it is planned for this package to also allow you to
choose how to deal with subjects who don't complete all 8 components
(call an error, warn, or propagate).

## Basic use

**NOTE:** Prior to using this package, I **HIGHLY** recommend you read the
AHA advisory (linked below). There are several options and nuances you need to
be aware of, otherwise you will (or may) compute incorrect scores.


To begin, pass a data-frame with at least **one** of the eight AHA metrics:

- diet (can be MEPA or percentile based, see below for more info)
- physical activity (moderate and vigorous activity)
- smoking
- sleep
- BMI
- blood lipids
- blood glucose & diabetes
- blood pressure (requires both systolic and diastolic measures)

to the function. This example uses
`score_le8(patient, diet_method = "mepa")`:

For simplicity, this example only contains one record.

```r
library(essential8)

patient <- data.frame(
  id = "patient_1",
  age = 55,
  sex = "female",

  # MEPA items --------------------------
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
  # -------------------------------------

  # Physical activity -------------------
  moderate_activity_minutes = 90,
  vigorous_activity_minutes = 0,
  # -------------------------------------

  # Smoking -----------------------------
  smoking_status = "former",
  years_since_quit = 6,
  current_inhaled_nds = FALSE,
  secondhand_smoke_home = FALSE,
  # --------------------------------------

  # Sleep --------------------------------
  sleep_hours = 7.5,
  # --------------------------------------

  # BMI ----------------------------------
  bmi = 27.5,
  bmi_profile = "general",
  # --------------------------------------

  # Blood lipids -------------------------
  non_hdl_cholesterol = 145,
  lipid_lowering_treatment = FALSE,
  # --------------------------------------

  # Diabetes & Glucose -------------------
  diabetes = FALSE,
  glucose_measure = "fasting_glucose",
  glucose_value = 95,
  # --------------------------------------

  # Blood Pressure -----------------------
  systolic_bp = 128,
  diastolic_bp = 78,
  antihypertensive_treatment = FALSE
  # --------------------------------------
)

scores <- score_le8(patient, diet_method = "mepa")
scores[
  c(
    "id",
    "mepa_total",
    "le8_diet_score",
    "le8_composite_score",
    "le8_category"
  )
]
```

`score_le8(data, diet_method = "mepa", mepa_columns = NULL)` applies one
scalar diet method to every row in a call. The `diet_method` argument can be
specified either as `"mepa"` or `"percentile"` corresponding to the 16
MEPA items seen above or the DASH percentile alternative scores.
For `diet_method = "mepa"`, the function calculates `mepa_total` directly from
the 16 screener responses. Their column names must be the screener labels shown
above, with underscores between words. Matching is case-insensitive.

The default MEPA sex field is `sex`; if it is absent, a `female` column is
recognized automatically. Map any other field with, for example,
`mepa_columns = c(sex = "reported_sex", alcohol = "alc")`. For sex, values are
trimmed and matched case-insensitively as `m`/`f` or `male`/`female`.
Numeric or character `0`/`1` values are also accepted, where `0` is male and `1` is female.

For data that use both diet methods, split the rows into separate data-frames
and call `score_le8()` separately. Percentile calls require `diet_value`, containing a
DASH or HEI-2015 percentile from 1 to 100. The result appends all eight
component scores, the composite score, and its cardiovascular
health category. See `?score_le8` for more information.

## Learn more
- Package website: https://thatoneguy006.github.io/essential8/index.html
- Get started: https://thatoneguy006.github.io/essential8/articles/essential8-get-started.html

## Disclaimer

`essential8` is independent research software and is not affiliated with,
sponsored by, approved by, or endorsed by the American Heart Association.
It is not intended for supporting clinical decision making or diagnosis of health
problems.

## References

- Lloyd-Jones, D. M., Allen, N. B., Anderson, C. A. M., et al. (2022).
  Life's Essential 8: Updating and Enhancing the American Heart Association's
  Construct of Cardiovascular Health: A Presidential Advisory From the
  American Heart Association. *Circulation*, 146(5), e18-e43.
  <https://doi.org/10.1161/CIR.0000000000001078>
- Lloyd-Jones, D. M., Ning, H., Labarthe, D., et al. (2022). Status of
  Cardiovascular Health in US Adults and Children Using the American Heart
  Association's New Life's Essential 8 Metrics. *Circulation*, 146(11),
  822-835. <https://doi.org/10.1161/CIRCULATIONAHA.122.060911>
