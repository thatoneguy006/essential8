# essential8 0.3.0

## New features

- Added DASH and HEI-2015 pathways for already-computed indices or direct
  percentiles through `score_le8()`. Index inputs use the explicit default
  `reference = "nhanes_2015_2018"`, or a validated, method-tagged
  `diet_reference()` object. Direct percentiles bypass reference lookup (#9).
- Built and reproduced compact references for both indices from public
  NHANES 2015-2018/FPED data using the survey design and combined-cycle two-day
  dietary weights. The maintainer pipeline records source hashes, sample
  counts, index definitions, software versions, and exclusions; runtime scoring
  uses no downloads or cohort ranking.
- Shared percentile mapping accepts 0-100 points, preserves missing/empty
  numeric outputs, and rejects apparent fractional proportions in 0-1.
  MEPA results, argument order, and existing explicit raw-intake routes are
  preserved; the new index/percentile routes add no output columns.

- Added adult `diet_method = "dash"` scoring from eight daily intake fields
  using the Fung quintile index, with an auditable 8-to-40 `dash_total` (#9).
- Added adult `diet_method = "hei2015"` scoring from food-pattern equivalents,
  energy, and nutrients. Returns all 13 component scores and the 0-to-100
  `hei2015_total` (#9).
- Both methods use explicit reference-population total-score cutpoints to
  calculate LE8 diet points. DASH additionally requires intake quintile
  cutpoints. The package never estimates reference cutpoints from the rows
  being scored or treats an HEI-2015 total as a percentile.
- Added `dash_columns` and `hei2015_columns` for custom input column mappings.
  New inputs support the existing missing-data and `min_components` behavior;
  incomplete diets do not produce partial raw totals.
- Added source notes, worked synthetic examples, and boundary/validation tests.

## Output changes

- `score_le8()` now always appends `dash_total` and `hei2015_total`, with typed
  missing values when the corresponding method is not selected. HEI-2015 calls
  also append `hei2015_<component>_score` columns. These names are reserved
  against input collisions. Existing positional arguments retain their order.

# essential8 0.2.0

## Major Changes

- `score_le8()` can now work with data that have missing values (#7).
- Added `min_components`, an argument to control how many available
  components are required for `le8_composite_score`. Valid options range from
  1-8.

## Minor Changes

- Added `le8_n_components` and `le8_complete` outputs for transparent reporting
  of the available components for LE8 composite scores.
- Added consolidated, classed warnings when one or more LE8 components cannot
  be calculated for any observation, including a stronger warning when
  structural missingness makes `min_components` impossible to reach.

# essential8 0.1.0

## Adult Life's Essential 8 scoring

- Added `score_le8()` for complete adult records aged 20 years or
  older, using the eight component definitions in the AHA 2022 Presidential
  Advisory.
- Added raw 16-item MEPA derivation with exact case-insensitive screener-column
  matching, optional explicit column mappings, an auditable `mepa_total`, and
  population-percentile diet scoring.
- Added moderate-equivalent activity minutes, general or Asian-Pacific BMI
  profiles, and explicit glucose-measure selection.
- Changed `score_le8()` to take one scalar `diet_method` argument per call,
  defaulting to `"mepa"`; percentile calls require `diet_value`, and data using
  both methods must be scored in separate calls.
- Renamed the composite output from `le8_score` to `le8_composite_score`.
- Expanded MEPA sex input to accept trimmed, case-insensitive `m`/`f` and
  `male`/`female`, plus numeric or character `0`/`1` (`0` is male and `1` is
  female). The default field is `sex`, `female` is recognized when `sex` is
  absent, and other field names can be supplied through `mepa_columns`.
- Added a reproducible Get Started vignette.
