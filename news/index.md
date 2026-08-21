# Changelog

## essential8 0.1.0

### Adult Life’s Essential 8 scoring

- Added
  [`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
  for complete adult records aged 20 years or older, using the eight
  component definitions in the AHA 2022 Presidential Advisory.
- Added raw 16-item MEPA derivation with exact case-insensitive
  screener-column matching, optional explicit column mappings, an
  auditable `mepa_total`, and population-percentile diet scoring.
- Added moderate-equivalent activity minutes, general or Asian-Pacific
  BMI profiles, and explicit glucose-measure selection.
- Added a manually scored 10-subject example data set, AHA
  worked-example tests, and cut-point, modifier, compound-condition, and
  validation tests.
- Added a reproducible Get Started vignette.

## essential8 0.0.0.9000

### Initial development version

- Created the initial package structure and development metadata.
- Added the rule schema, structured rule-validation errors, and unit
  tests.
- Added source hierarchy, evidence ledger, adult and pediatric
  transcription workspaces, and verification-gated build scripts.
- Added cross-platform R CMD check automation and repository governance
  files.
