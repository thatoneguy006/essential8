# Diet percentile implementation report

This follow-up implements the supplied diet-percentile specification against
`dev`, which already contains PR #15. Package version remains 0.3.0, as on
the base branch. The new PR is intentionally a draft for methodological review.

## Files changed

- Runtime: `R/score-le8.R`, `R/diet-percentile.R`, `R/diet-reference.R`, and
  the compact generated `R/sysdata.rda`.
- Build/provenance: `data-raw/build_diet_references.R`,
  `data-raw/source-manifest.csv`, `data-raw/README.md`, and this report.
- Tests: `tests/testthat/test-diet-references.R`.
- Documentation: `README.md`, `NEWS.md`, `man/score_le8.Rd`,
  `man/diet_reference.Rd`, `vignettes/population-diets.Rmd`, and
  `vignettes/essential8-get-started.Rmd`.
- Package metadata: `DESCRIPTION`, `NAMESPACE`, and `.Rbuildignore`.

## Public API and compatibility

The existing public orchestrator is `score_le8()`, not the specification's
conceptual `p_diet()`. Its existing positional arguments are preserved, with
one appended argument: `reference = "nhanes_2015_2018"`.

- `diet_method = "dash"`: an already-computed `dash` index column, or direct
  percentile points in `diet_value`.
- `diet_method = "hei2015"`: an already-computed `hei2015` index column, or
  direct percentile points in `diet_value`.
- Index inputs use the selected built-in or custom reference; direct
  percentiles bypass reference lookup completely. Do not supply both columns.
- `diet_reference(p25, p50, p75, p95, method, label, source, score_range)` is
  the new exported constructor, with a small S3 print method.
- Existing MEPA code and its raw-item rules were not changed; all existing
  MEPA and hand-scored adult regression tests pass.
- Existing generic `diet_method = "percentile"` remains supported, now with
  the specified 0-100 domain and proportion safeguard.
- The raw-intake routes already merged in PR #15 retain their helpers,
  explicit mappings/cutpoints, units, and outputs. Their presence activates
  a separate compatibility route; mixed raw/index/percentile inputs error.
- No new output columns are introduced for the index or percentile routes.
  No raw-recall parser, pediatric implementation, or usual-intake model is added.

## Reference objects and actual NHANES build

Both DASH and HEI-2015 now have locally packaged `nhanes_2015_2018` references.
They were actually generated and rebuilt, not manually populated placeholders.

Each `essential8_diet_reference` stores the method, four scalar cutpoints,
optional label/source, index bounds, and provenance. Built-ins include a
reference version, cycles, index definition, counts, weighting/design,
exclusions, percentile estimator, software version, build-script hash, and
SHA-256 hashes/URLs of input sources. The DASH object also retains its eight
weighted intake-quintile vectors as compact construction metadata. No exact
continuous percentiles are claimed or returned.

The build used CDC NHANES 2015-2016 and 2017-2018 demographic, total-nutrient,
and individual-food files, plus matching USDA FPED releases. It requires two
reliable recalls, positive energy and dietary weights, complete inputs, age
20+, and no known pregnancy. The adult domain contains 8,241 observations:
4,149 from 2015-2016 and 4,092 from 2017-2018.

The four-year dietary weight is `WTDR2D / 2`; strata combine cycle and
`SDMVSTRA`, PSU is `SDMVPSU`, and `survey::svydesign(..., nest=TRUE)` represents
the survey. Adult eligibility is a domain restriction. Both intake and total
quantiles use `survey::svyquantile(qrule="math", ci=FALSE)`.

The DASH definition is `essential8_fung_fped_v1`, using documented serving
conversions and pinned dietaryindex 2.1 food-code lists. Weighted pooled
quintiles follow averaging of the same two recalls' intake constituents.
The HEI definition is `hei2015_individual_two_recall_v1`, using individual
NCI scoring after averaging constituent amounts and energy. Complete
methodology and source references are in `data-raw/README.md`.

Custom references are method-tagged, revalidated when used, and cannot be
exchanged between instruments. Tied cutpoints are allowed. There is no
implicit theoretical range for custom DASH variants; HEI-2015 uses 0-100.
Neither default nor custom references rank a scoring cohort automatically.

## Validation and verification

New checks cover finite numeric scores/percentiles, scalar ordered cutpoints,
reference keywords/classes/methods, index bounds, input exclusivity, unrelated
inputs, missingness, and one-dimensional columns. Fractional-only batches in
0-1 are rejected as apparent proportions, with the documented limitation
that this also rejects genuine sub-first-percentile-only batches.

Tests exercise direct percentile boundaries, typed methods, fixed-reference
batch invariance, built-in object provenance and cutpoints, custom references,
tampering/revalidation, NA/empty outputs, and integration with the LE8
composite. All pre-existing MEPA/raw diet tests remain in place and pass.

Validation on Windows / R 4.6.0:

```text
devtools::document()
  Documentation generated successfully, with no outstanding warnings.

devtools::test(stop_on_failure = TRUE)
  All tests pass. Installed-package check: PASS 655, FAIL 0, WARN 0, SKIP 0.

devtools::check(document = FALSE, manual = FALSE, error_on = "note")
  0 errors | 0 warnings | 0 notes
  Includes installed-package tests, examples, and rebuilt vignettes.

build_diet_references(..., verify = TRUE)
  Rebuilt cutpoints, sample counts, and all source hashes match.

git diff --check
  Passed.
```

The development test process temporarily restored a host-installed pkgload
helper-loader stub; no installed library files were changed. The clean
installed-package test run needed no workaround. Rtools was explicitly
configured at the user's `C:/RBuildTools/rtools45` location. The reference
builder's dependencies are Suggests only; runtime Imports remain unchanged.

## Scientific review and copyright

The draft needs methodological review of the documented DASH adaptation,
particularly the fixed 2017-2018 food-code lists applied to both cycles,
pooled weighted intake quintiles, and tie convention. Other DASH definitions
require their own reference even when they share an 8-to-40 range. The
references are not claimed to be official AHA cutpoints or exact replications
of a published prevalence estimate. Reproducibility is established; independent
external scientific validation is not claimed.

No AHA scoring tables were reproduced or stored. Scoring rules remain
executable code with independently written documentation and citations.
No raw NHANES files or participant score vectors are shipped. Runtime scoring
and offline tests make no NHANES downloads, and ordinary CRAN checks do not
rebuild the reference data.
