# essential8 <img src="man/figures/essential8_favicon.png" align="right" height="160" alt="" />

<!-- badges: start -->
[![R-CMD-check](https://github.com/thatoneguy006/essential8/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/thatoneguy006/essential8/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/thatoneguy006/essential8/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/thatoneguy006/essential8/actions/workflows/pkgdown.yaml)
[![CRAN version](https://www.r-pkg.org/badges/version/essential8)](https://CRAN.R-project.org/package=essential8)
<!-- badges: end -->

## Overview

`essential8` provides reproducible R implementations of the American Heart
Association Life's Essential 8 cardiovascular health scoring framework.

The current release implements adult scoring for people aged 20 years or
older. Pediatric scoring is planned but not yet implemented.

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

The American Heart Association Life's Essential 8 (LE8) framework combines
eight lifestyle and health components into a composite cardiovascular health
score from 0 to 100. `essential8` applies the published adult scoring bands
in one validated workflow and returns all eight component scores plus the
composite.

Version 0.3.0 supports adult DASH and HEI-2015 diet scoring alongside MEPA.
It supports incomplete adult records without imputing raw inputs or
component scores. By default, the composite is calculated when at least seven
components are available; `min_components` can set a threshold from 1 through
8. Optional AHA clinical-judgment adjustments are applied only when the user
supplies explicit adjudication flags; see `?score_le8` for details.

## Basic use

Read the AHA advisory and `?score_le8` before using the package, particularly
the input units, population-percentile diet requirements, and optional
clinical-judgment adjustments.

Pass a data frame containing adult inputs for the eight AHA metrics. Missing
component values are allowed, and component-specific columns may be omitted
when a domain is unavailable:

- diet (MEPA, DASH, HEI-2015, or externally supplied percentiles)
- physical activity (moderate and vigorous activity)
- smoking
- sleep
- BMI
- blood lipids
- blood glucose and diabetes status
- blood pressure (requires both systolic and diastolic measures)

The following example contains one record and uses
`score_le8(patient, diet_method = "mepa")`:

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

The `diet_method` argument accepts `"mepa"`, `"dash"`, `"hei2015"`, or
`"percentile"`. The `min_components` argument defaults to 7.
For `diet_method = "mepa"`, the function calculates `mepa_total` directly from
the 16 screener responses. Their column names must be the screener labels shown
above. Matching is case-insensitive.

The default MEPA sex field is `sex`; if it is absent, a `female` column is
recognized automatically. Map any other field with, for example,
`mepa_columns = c(sex = "reported_sex", alcohol = "alc")`. For sex, values are
trimmed and matched case-insensitively as `m`/`f` or `male`/`female`.
Numeric or character `0`/`1` values are also accepted, where `0` is male and `1` is female.

For data that use different diet methods, split the rows into separate data frames
and call `score_le8()` separately. Percentile calls use `diet_value`, containing
a DASH or HEI-2015 percentile from 0 to 100. The result appends all eight
component scores, `le8_n_components`, `le8_complete`, the composite score, and
its cardiovascular health category. See `?score_le8` for more information.

## DASH and HEI-2015 population pathways

Use `diet_method = "dash"` or `"hei2015"` for population research with an
already-computed index or percentile. Calculate the index with an established
method appropriate for your analysis before passing it to `essential8`.
MEPA remains the existing individual assessment pathway shown above.

```r
# Already-computed HEI-2015 index, with the fixed packaged reference.
hei_data <- patient
hei_data$hei2015 <- 70
score_le8(hei_data, diet_method = "hei2015",
          reference = "nhanes_2015_2018")

# Already-computed DASH percentile; no reference lookup is needed.
dash_data <- patient
dash_data$diet_value <- 82
score_le8(dash_data, diet_method = "dash")

# A synthetic custom reference for an already-computed HEI-2015 index.
custom <- diet_reference(40, 55, 65, 80, method = "hei2015",
                         label = "Synthetic example")
score_le8(hei_data, diet_method = "hei2015", reference = custom)
```

Index columns are named `dash` or `hei2015`. Direct percentiles use
`diet_value` on the **0-100 scale**, and must not be supplied together with an
index column. A proportion such as `0.95` is never rescaled to 95.

Both methods have compact, locally packaged NHANES 2015-2018 references,
derived using the complex survey design and two-day dietary weights. The
built-in DASH reference requires the specific Fung-style FPED index and
weighted intake quintiles documented in the diet vignette; another DASH
definition needs its own reference. The HEI-2015 reference uses individual
scoring of two-recall mean constituents and energy. These adult references
are derived estimates with provenance, not AHA-published cutpoint tables or
usual-intake distributions. They never rank the current cohort or download
data during scoring. Name the reference explicitly for reproducibility.

Missing values remain missing. Existing explicit raw-intake workflows and
their column mappings/cutpoints remain supported for compatibility with
PR #15; the new pathway adds no dietary-recall processing API.
See `vignette("population-diets", package = "essential8")` and `?score_le8`
for reference definitions, units, provenance, validation, and compatibility.

## Incomplete component data

`score_le8()` preserves ordinary row-level missingness.
The composite is the mean of the available component scores when the selected
threshold is met:

```r
incomplete <- rbind(patient, patient)
incomplete$id <- c("complete", "sleep_missing")
incomplete$sleep_hours[2] <- NA_real_

incomplete_scores <- score_le8(incomplete, min_components = 7)
incomplete_scores[
  c(
    "id",
    "le8_composite_score",
    "le8_n_components",
    "le8_complete"
  )
]
```

`le8_n_components` reports how many component scores contributed, while
`le8_complete` is `TRUE` only when all eight were available. If a
component cannot be calculated for any observation, the function emits one
consolidated warning identifying every structurally unavailable component.

## Learn more
- Package website: https://thatoneguy006.github.io/essential8/index.html
- Get started: https://thatoneguy006.github.io/essential8/articles/essential8-get-started.html

## Disclaimer

`essential8` is independent research software and is not affiliated with,
sponsored by, approved by, or endorsed by the American Heart Association.
It is not intended for clinical decision-making or diagnosis of health
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
