# Changelog

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
