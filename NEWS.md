# essential8 0.1.0

## Adult Life's Essential 8 scoring

- Added `score_le8()` for complete adult records aged 20 years or
  older, using the eight component definitions in the AHA 2022 Presidential
  Advisory.
- Added raw 16-item MEPA derivation with exact case-insensitive screener-column
  matching, optional explicit column mappings, an auditable `mepa_total`, and
  population-percentile diet scoring.
- Documented and boundary-tested the MEPA alcohol policy as a bounded positive
  interval: `(0, 14]` weekly servings for men and `(0, 7]` for women.
- Added moderate-equivalent activity minutes, general or Asian-Pacific BMI
  profiles, and explicit glucose-measure selection.
- Added strict validation for source-undefined combinations instead of
  silently inferring clinical status or measurement precedence.
- Added a manually scored 10-subject example data set, AHA worked-example
  tests, and cut-point, modifier, compound-condition, and validation tests.
- Transcribed 69 source-located adult LE8 rules across all eight metrics and a
  separate 17-row ledger representing the 16 MEPA screener criteria. These
  remain unverified, with source interpretations explicitly documented, until
  independent human verification is recorded.
- Added a reproducible Get Started vignette and reduced the README to a basic
  `score_le8()` workflow.

## Initial development version

- Created the initial package structure and development metadata.
- Added the rule schema, structured rule-validation errors, and unit tests.
- Added source hierarchy, evidence ledger, adult and pediatric transcription
  workspaces, and verification-gated build scripts.
- Added cross-platform R CMD check automation and repository governance files.
