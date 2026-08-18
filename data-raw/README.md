# Scientific rule-development workspace

Files under `data-raw/` are development artifacts. They are excluded from the
built package and are not executable scoring rules.

## Required workflow

1. Register each metric and population in `evidence-ledger.csv`.
2. Identify the normative source and an exact page, table, row, or supplement
   locator before transcription begins.
3. Transcribe rules into the applicable `*-rules.csv` file using the canonical
   columns in `rule-transcription-template.csv`.
4. Mark new rows `transcribed`; never mark your own transcription `verified`.
5. Have a second reviewer compare every value and interval boundary directly
   with the source.
6. Record the reviewer identity and verification date.
7. Run `Rscript data-raw/validate-rule-transcription.R`.
8. Create independently calculated golden fixtures before building package
   data.

`data-raw/build-rules.R` refuses to build package data when any row is not
verified. This gate must not be weakened to make development more convenient.

## Copyright and provenance

Record scientific facts and rule parameters in the package's normalized
schema. Do not copy source prose, graphics, logos, or table presentation. Keep
citations and precise locators so every executable rule can be audited.

