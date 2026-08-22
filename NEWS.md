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
