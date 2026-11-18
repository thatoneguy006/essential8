# Changelog

## essential8 0.9.1

CRAN release: 2026-11-17

### Minor Changes

- Added Rhub checks

### Bug Fixes

- Fixed failing test on Intel MKL platform

## essential8 0.9.0

CRAN release: 2026-11-14

### Major Changes

- [`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
  now scores children aged 4 months to 19 years with the pediatric LE8
  definitions (Table 1 and Supplemental Appendix 2 of the 2022
  advisory). Rows are routed by `age`, so adults and children can be
  scored in one call, and the new `le8_population` column records which
  definitions were used. Components AHA does not define at a child’s age
  (for example, blood pressure before age 1) are `NA` and are excluded
  from `min_components`.
- Pediatric MEPA uses the same input columns as adults, plus
  `milk_source` at 6-23 months: 6 items at 6-23 months, 10 items at 2-5
  years (10 points per item), and all 16 items with adult bands from
  age 6. `mepa_total` reports items met on the age-appropriate screener.
- New pediatric inputs: `age_months`, `milk_source`,
  `active_play_minutes`, `bmi_percentile`, `bmi_percent_of_p95`,
  `infant_weight_percentile`, `infant_weight_z_change`, and the AAP 2017
  blood-pressure references `systolic_bp_p90`, `systolic_bp_p95`,
  `diastolic_bp_p90`, and `diastolic_bp_p95`.
- New
  [`add_pediatric_references()`](https://thatoneguy006.github.io/essential8/reference/add_pediatric_references.md)
  derives the growth-chart and blood-pressure reference inputs from sex,
  age, height, and weight using the suggested packages cdcanthro and
  pedbp.
- New
  [`vignette("pediatric-scoring")`](https://thatoneguy006.github.io/essential8/articles/pediatric-scoring.md).
- [`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
  results now carry the class `essential8_scores` on top of the input’s
  class (data frames, tibbles, and grouped tibbles are otherwise
  unchanged), with new methods:
  - [`summary()`](https://rdrr.io/r/base/summary.html) reports the
    number of rows scored, the distribution of the composite and each
    component score, and the cardiovascular health categories.
  - [`tidy()`](https://generics.r-lib.org/reference/tidy.html) reshapes
    the scores into long format, one row per input row and measure.
    [`tidy()`](https://generics.r-lib.org/reference/tidy.html) is
    re-exported from generics.
  - [`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws the
    mean scores, their distributions (`type = "distribution"`), or a
    histogram of the composite score by category (`type = "composite"`)
    with ggplot2. `type = "forest"` draws the mean scores with
    confidence intervals, optionally compared across the groups in `by`,
    using
    [`ggforestplotR::ggforestplot()`](https://thatoneguy006.github.io/ggforestplotR/reference/ggforestplot.html);
    other arguments to
    [`plot()`](https://rdrr.io/r/graphics/plot.default.html) are passed
    on to `ggforestplot()`.
  - With dplyr,
    [`summarise()`](https://dplyr.tidyverse.org/reference/summarise.html)
    (or
    [`summarize()`](https://dplyr.tidyverse.org/reference/summarise.html))
    without expressions returns the
    [`summary()`](https://rdrr.io/r/base/summary.html) statistics as a
    data frame, by group with `.by`. Summaries with expressions are
    handled by dplyr as before.
- Multiple imputation of missing inputs with mice:
  - `score_le8(impute = TRUE)` imputes missing inputs, scores every
    imputed data set, and returns them stacked with an `.imp` column.
    [`summary()`](https://rdrr.io/r/base/summary.html),
    [`summarise()`](https://dplyr.tidyverse.org/reference/summarise.html),
    [`tidy()`](https://generics.r-lib.org/reference/tidy.html), and
    [`plot()`](https://rdrr.io/r/graphics/plot.default.html) on the
    result pool across imputations with Rubin’s rules.
  - [`le8_imputation_control()`](https://thatoneguy006.github.io/essential8/reference/le8_imputation_control.md)
    sets the number of imputations, iterations, a seed, auxiliary
    predictors, and other
    [`mice::mice()`](https://amices.org/mice/reference/mice.html)
    arguments:
    `score_le8(impute = le8_imputation_control(m = 50, seed = 1))`.
  - The imputation imputes an input only for participants whose age uses
    it, limits each model’s predictors to inputs available for everyone
    it applies to, and never imputes a combination AHA does not score
    (for example, diagnosed diabetes without an HbA1c value, or current
    combustible smoking with current inhaled-NDS use).
    [`le8_imputation_setup()`](https://thatoneguy006.github.io/essential8/reference/le8_imputation_setup.md)
    shows these settings, and
    [`score_le8_imputed()`](https://thatoneguy006.github.io/essential8/reference/score_le8_imputed.md)
    scores a mice run of your own.
- New
  [`vignette("case-study")`](https://thatoneguy006.github.io/essential8/articles/case-study.md)
  works through a complete project: scoring 500 simulated children and
  adults, choosing `min_components`, imputing missing laboratory values,
  and summarizing and plotting the results.
- New
  [`as_le8_scores()`](https://thatoneguy006.github.io/essential8/reference/as_le8_scores.md)
  restores the `essential8_scores` class to scored data after
  [`group_by()`](https://dplyr.tidyverse.org/reference/group_by.html),
  [`as_tibble()`](https://tibble.tidyverse.org/reference/as_tibble.html),
  or reading saved results.

### Breaking Changes

- Component score columns no longer have the `le8_` prefix: they are now
  `diet_score`, `physical_activity_score`, `nicotine_score`,
  `sleep_score`, `bmi_score`, `blood_lipids_score`,
  `blood_glucose_score`, and `blood_pressure_score`. `le8_n_components`
  is now `n_components`. Columns that describe the LE8 composite keep
  the prefix: `le8_composite_score`, `le8_complete`, `le8_category`, and
  `le8_population`.
- Because output names are reserved, `data` that already contains one of
  the new names (for example, a `sleep_score` from another instrument)
  or one of the old `le8_`-prefixed names now raises an error. Rename
  those columns before scoring.

### Minor Changes

- Errors now report
  [`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
  as the call rather than an internal helper.

## essential8 0.3.0

### Major Changes

- Added DASH and HEI-2015 support to
  [`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md).
  Both methods accept raw food and nutrient inputs, existing diet
  scores, or percentiles
  ([\#9](https://github.com/thatoneguy006/essential8/issues/9)).
- Added packaged NHANES 2015-2018 references to convert diet scores to
  LE8 points, with options to supply a custom reference or scoring
  cutpoints.
- Raw scoring returns `dash_total` or `hei2015_total`. HEI-2015 also
  returns all 13 component scores.

### Bug Fixes

- Diagnosed diabetes with a missing `glucose_measure` is no longer
  scored as though `glucose_value` were HbA1c; the glucose score is now
  missing.
- `apply_lean_muscular_bmi_override = TRUE` no longer awards 100 BMI
  points when `bmi` or `bmi_profile` is missing.
- Missing values in `apply_lean_muscular_bmi_override` and
  `apply_prediabetes_metformin_penalty` now blank a score only for
  records where the adjustment could apply.
- Entirely missing input columns stored as logical `NA` (such as blank
  CSV columns) are treated as missing instead of raising a type error.
- `le8_physical_activity_score` is now always double, including when
  activity inputs are entirely missing.
- [`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
  now returns an object of the same class as `data`, so tibbles and
  grouped tibbles are preserved.

### Breaking Changes

- Input column names that differ from a case-sensitive LE8 input name
  only by case (for example `BMI`) now raise an error instead of being
  ignored.
- Supplying some but not all 16 MEPA items, or omitting any raw DASH or
  HEI-2015 column once raw scoring is selected, now raises an error
  naming the missing columns instead of silently returning missing diet
  scores.
- `mepa_columns` now requires `diet_method = "mepa"`, and `dash` or
  `hei2015` index columns are rejected under
  `diet_method = "percentile"`.

### Minor Changes

- Raw DASH scoring now returns the eight `dash_<field>_score` component
  scores, matching the raw HEI-2015 output.
- An entirely missing `diet_value` column no longer blocks scoring of a
  `dash` or `hei2015` index column.
- A logical `female` column is accepted as the MEPA sex field.
- Removed unused internal rule-schema scaffolding.
- Expanded the diet vignette to explain MEPA, DASH, and HEI-2015, their
  role in LE8, and how their scores are calculated.
- Simplified the README and examples, using consistent tidy workflows.

## essential8 0.2.0

CRAN release: 2026-10-10

### Major Changes

- [`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
  can now work with data that have missing values
  ([\#7](https://github.com/thatoneguy006/essential8/issues/7)).
- Added `min_components`, an argument to control how many available
  components are required for `le8_composite_score`. Valid options range
  from 1-8.

### Minor Changes

- Added `le8_n_components` and `le8_complete` outputs for transparent
  reporting of the available components for LE8 composite scores.
- Added consolidated, classed warnings when one or more LE8 components
  cannot be calculated for any observation, including a stronger warning
  when structural missingness makes `min_components` impossible to
  reach.

## essential8 0.1.0

CRAN release: 2026-09-03

### Major Changes

- Added
  [`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
  for complete adult records aged 20 years or older, using the eight
  component definitions in the AHA 2022 Presidential Advisory.
- Added raw 16-item MEPA derivation with exact case-insensitive
  screener-column matching, optional explicit column mappings, an
  auditable `mepa_total`, and population-percentile diet scoring.
- Added moderate-equivalent activity minutes, general or Asian-Pacific
  BMI profiles, and explicit glucose-measure selection.
- Changed
  [`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
  to take one scalar `diet_method` argument per call, defaulting to
  `"mepa"`; percentile calls require `diet_value`, and data using both
  methods must be scored in separate calls.
- Renamed the composite output from `le8_score` to
  `le8_composite_score`.
- Expanded MEPA sex input to accept trimmed, case-insensitive `m`/`f`
  and `male`/`female`, plus numeric or character `0`/`1` (`0` is male
  and `1` is female). The default field is `sex`, `female` is recognized
  when `sex` is absent, and other field names can be supplied through
  `mepa_columns`.
- Added a reproducible Get Started vignette.
