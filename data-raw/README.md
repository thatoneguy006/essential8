# NHANES diet reference build

`build_diet_references.R` is a maintainer-only pipeline. It creates the two
compact objects in `R/sysdata.rda`, named `nhanes_2015_2018` at runtime.
These are derived NHANES estimates, not copied AHA tables. No raw NHANES
records or participant index vectors are committed or packaged.

## Reproduce

From the package root, install `haven`, `survey`, and `digest`, and make
7-Zip's `7z` available on PATH. The builder reads USDA self-extracting
archives with 7-Zip; it never executes downloaded binaries.

```r
source("data-raw/build_diet_references.R")
build_diet_references(cache = "tmp/nhanes-cache")
build_diet_references(cache = "tmp/nhanes-cache", verify = TRUE)
```

Equivalent shell commands:

```sh
Rscript data-raw/build_diet_references.R tmp/nhanes-cache
Rscript data-raw/build_diet_references.R tmp/nhanes-cache --verify
```

The first run downloads official public files into the ignored cache. The
verification run recomputes indices and compares cutpoints, cycle sample
counts, and source hashes with the packaged objects. Updating sources,
index definitions, exclusions, or estimator requires a new reference version,
not silently changing an existing reference. CRAN and ordinary tests do not
run this pipeline or need a network connection.

## Inputs and eligibility

The exact URLs and SHA-256 hashes are recorded in `source-manifest.csv` and
in each packaged object's `provenance$sources`.

- NHANES 2015-2016 (`I`) and 2017-2018 (`J`): `DEMO`, `DR1TOT`, `DR2TOT`,
  `DR1IFF`, and `DR2IFF` transport files from CDC.
- USDA's matching 2015-2016 and 2017-2018 FPED day-one/day-two total and
  individual-food SAS datasets. The 2017-March-2020 files are not substituted.
- The numeric food-code lists in dietaryindex 2.1's `DASH_NHANES_FPED.R`,
  pinned to revision `b98cb9e4a5c514eeb4becf8fcd21d5da135b470c` and checked
  against its SHA-256 before extracting static numeric assignments.

Both recall status flags must equal 1; both energies and `WTDR2D` must be
positive; all needed constituents and design variables must be observed.
The survey design is constructed from complete reliable two-recall records,
then restricted to the domain aged 20+ without known pregnancy (`RIDEXPRG=1`).
Unknown pregnancy status is not labeled pregnant. No arbitrary energy
plausibility bounds, fasting restrictions, or requirements for other LE8
components are imposed. This yields 8,241 adult records. Counts by cycle are
stored in the reference object.

## Survey design and percentile estimation

The four-year weight is `WTDR2D / 2`, combining two standard two-year cycles.
Cycle is incorporated in the stratum identifier to prevent cross-cycle
stratum collisions. The design uses `survey::svydesign(ids = ~psu,
strata = ~stratum, weights = ~weight, nest = TRUE)`, with PSU from `SDMVPSU`
and stratum from `SDMVSTRA`. Adult eligibility is a survey-domain restriction.

Both intake quintiles and index-total cutpoints use
`survey::svyquantile(qrule = "math", ci = FALSE)`. The resulting point
quantiles use the dietary weights; their design representation also retains
the NHANES strata/PSUs. No unweighted quantiles or implicit ranking of a
user's cohort are used.

## Index definitions

Daily constituents and energy are averaged over the same two recalls before
any ratio or index calculation. This is a defined two-recall individual
scoring workflow, not usual-intake modeling or a population-ratio estimator.

### HEI-2015: `hei2015_individual_two_recall_v1`

The existing, tested HEI-2015 calculator supplies the 13 components, following
NCI standards and the reference macro's zero-fat convention. FPED totals
provide food-pattern equivalents, and nutrient totals provide energy, sodium,
and fats. The builder supplies the following constituent definitions:

- Whole fruit is citrus/melon/berries plus other intact fruit; total fruit
  includes juice.
- Total vegetables include vegetable legumes; greens/beans combine dark
  green vegetables and vegetable legumes.
- Total protein combines meat/poultry/seafood, eggs, nuts/seeds, soy, and
  protein-equivalent legumes. Seafood/plant proteins combine seafood,
  nuts/seeds, soy, and protein-equivalent legumes.
- Dairy, whole/refined grains, and added sugars use the corresponding FPED
  components. Added sugars remain teaspoon equivalents; fats are grams and
  sodium is mg.

Legumes are counted in both vegetable and protein components using the
appropriate equivalents, as required by HEI-2015. The builder does not
average two separately calculated daily HEI scores.

### DASH: `essential8_fung_fped_v1`

This is a particular eight-component, 8-to-40 Fung-style FPED construction.
It is not interchangeable with every DASH index. Its preprocessing follows
the published dietaryindex implementation's food definitions and serving
conversions; its ranking is deliberately different and documented below.

- Fruit: FPED total fruit cup equivalents, including juice.
- Vegetables: dark-green cup equivalents plus twice the sum of red/orange,
  other, and other-starchy vegetables; white potatoes and legumes are excluded.
- Nuts/legumes: protein-equivalent legumes, nuts/seeds, and soy.
- Whole grains: FPED whole-grain ounce equivalents.
- Low-fat dairy: milk equivalents for the pinned skim-milk codes, four times
  cheese equivalents for the pinned low-fat cheese codes, plus yogurt.
- Sodium: nutrient sodium standardized to 2,000 kcal using the ratio of the
  two-recall mean sodium to mean energy.
- Red/processed meat: cured-meat equivalents divided by 1.5, plus meat/organ
  equivalents divided by 4.
- Sweetened beverages: added-sugar teaspoon equivalents in the pinned beverage
  code list, converted to servings by multiplying by 4/26.

The pinned lists are from the source's 2017-2018 FNDDS definitions and are
applied consistently to both cycles. This explicit choice is part of the
reference definition and needs scientific review; the reference is not
claimed to reproduce a separate investigator's cycle-specific classification.

Unlike dietaryindex's function, the builder does not calculate unweighted
quintiles separately by day or average separately scored days. It calculates
pooled, survey-weighted adult intake quintiles after averaging the two days,
then reuses the existing essential8 component scorer. Equality stays in the
lower intake quintile. Five components increase with intake; three decrease.
Quintiles are pooled across sexes; no implicit sex stratification is applied.
Their cutpoints are retained as compact construction metadata.

Only scores constructed with these definitions and quintiles should use the
built-in DASH reference. Use `diet_reference()` for a different DASH variant,
food grouping, population, or ranking scheme. An 8-to-40 range alone does
not establish compatibility.

## Output and verification

`R/sysdata.rda` contains `.nhanes_diet_references`, a list with `dash` and
`hei2015` references. Each has a method tag, four scalar cutpoints, bounds,
label/source, and provenance containing the reference version, sample counts,
cycle names, weighting/design, index definition, exclusions, estimator,
source hashes, build-script hash, and software version. It stores no exact
empirical percentile function and no participant data.

The derived cutpoints are generated by the script, never manually entered
into scoring code. The packaged object is validated in offline unit tests.
The initial build and an independent rerun of the pipeline produced identical
cutpoints and cycle counts. These checks establish reproducibility, not an
independent external scientific validation of this particular DASH adaptation.

## Primary sources

- Lloyd-Jones et al. (2022), LE8 advisory and official supplementary
  Appendix 1: <https://doi.org/10.1161/CIR.0000000000001078>.
- CDC NHANES dietary documentation:
  <https://wwwn.cdc.gov/Nchs/Nhanes/Search/DataPage.aspx?Component=Dietary>.
- USDA FPED files and cycle-specific user guides:
  <https://www.ars.usda.gov/northeast-area/beltsville-md-bhnrc/beltsville-human-nutrition-research-center/food-surveys-research-group/docs/fped-databases/>.
- Fung et al. (2008), DASH index:
  <https://doi.org/10.1001/archinte.168.7.713>.
- NCI HEI-2015 standards, algorithm, and reference SAS macro:
  <https://epi.grants.cancer.gov/hei/developing.html>,
  <https://epi.grants.cancer.gov/hei/hei-scoring-method.html>,
  <https://epi.grants.cancer.gov/hei/sas-code.html>.
- Zhan and Hodge, dietaryindex preprocessing source (MIT), pinned revision:
  <https://github.com/jamesjiadazhan/dietaryindex/blob/b98cb9e4a5c514eeb4becf8fcd21d5da135b470c/R/DASH_NHANES_FPED.R>.
