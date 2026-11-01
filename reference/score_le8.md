# Score Life's Essential 8 cardiovascular health

Computes the eight adult Life's Essential 8 (LE8) component scores and
the composite score using the American Heart Association's 2022
Presidential Advisory. Component scores are calculated wherever
sufficient inputs are available, without imputing missing values. This
implementation applies only to adults aged 20 years or older.

## Usage

``` r
score_le8(
  data,
  diet_method = "mepa",
  mepa_columns = NULL,
  min_components = 7L,
  dash_columns = NULL,
  dash_cutpoints = NULL,
  hei2015_columns = NULL,
  hei2015_cutpoints = NULL,
  reference = "nhanes_2015_2018"
)
```

## Arguments

- data:

  A data frame with one row per adult and the input columns described
  below.

- diet_method:

  A single diet-scoring method applied to every row in `data`: `"mepa"`
  (the default), `"dash"`, `"hei2015"`, or `"percentile"`. Values are
  matched case-insensitively. Score data that use different methods in
  separate calls.

- mepa_columns:

  `NULL`, or a named character vector mapping canonical MEPA fields to
  columns in `data`. The names are canonical fields and the values are
  actual column names. Unmapped fields use their canonical names.

- min_components:

  A single integer from 1 to 8 specifying the minimum number of
  non-missing LE8 component scores required to calculate
  `le8_composite_score`. The default is 7. Available component scores
  are averaged without imputation; observations below the threshold
  receive `NA_real_`.

- dash_columns, hei2015_columns:

  `NULL`, or named character vectors mapping canonical DASH or HEI-2015
  fields to columns in `data`. Unmapped fields default to the canonical
  name prefixed with `dash_` or `hei2015_`. Names and input column names
  are matched case-insensitively.

- dash_cutpoints:

  `NULL` to use the packaged DASH intake quintiles and total-score
  cutpoints, or a named list containing the eight canonical DASH fields
  and `total`. Each intake vector contains four nondecreasing reference
  quintile cutpoints (20th, 40th, 60th, 80th percentiles), in the same
  units as the inputs. `total` contains four nondecreasing reference
  DASH-total cutpoints (25th, 50th, 75th, 95th percentiles), each from 8
  to 40. Tied cutpoints are allowed. Explicit cutpoints bypass
  `reference` and use inputs in their supplied units, without energy
  standardization, preserving existing calls.

- hei2015_cutpoints:

  `NULL` to use `reference`, or four nondecreasing reference
  HEI-2015-total cutpoints (25th, 50th, 75th, 95th percentiles), each
  from 0 to 100. Tied cutpoints are allowed.

- reference:

  `"nhanes_2015_2018"` (the default), or a method-matched
  [`diet_reference()`](https://thatoneguy006.github.io/essential8/reference/diet_reference.md)
  object. Used for already-computed indices and raw intake scoring when
  explicit cutpoints are absent. Raw DASH requires the packaged
  reference's intake quintiles; for other DASH definitions, supply
  `dash_cutpoints`. Direct percentiles and explicit raw cutpoints bypass
  reference lookup. The built-in references describe nonpregnant adults
  aged 20+ with two reliable recalls; they are derived estimates, not
  AHA-published cutpoints.

## Value

An object of the same class as `data`, containing the original columns
plus `mepa_total`, `dash_total`, and `hei2015_total` (missing unless
calculated from the corresponding raw inputs),
`physical_activity_moderate_equivalent_minutes`, the eight component
score columns prefixed with `le8_`, `le8_n_components`,
`le8_composite_score`, `le8_complete`, and `le8_category`. The component
count reports how many scores contributed to the composite score;
`le8_complete` is `TRUE` only when all eight components are available.
Categories are `"low"` for scores below 50, `"moderate"` for scores from
50 to less than 80, and `"high"` for scores of at least 80. The category
is missing when the composite score is missing. For raw DASH calls, the
eight component scores (1 to 5 points each) are also appended as
`dash_<field>_score`; they sum to `dash_total`. For raw HEI-2015 calls,
the 13 component scores are also appended as
`hei2015_<component>_score`, including `fatty_acids` and
`saturated_fats`. The result has the same class as `data`, so tibbles
and grouped tibbles are returned as such.

## Diet scoring methods

MEPA retains the individual assessment pathway. For population research,
`diet_method = "dash"` accepts an already-computed index in `dash`, and
`diet_method = "hei2015"` accepts an already-computed index in
`hei2015`. Either method alternatively accepts a percentile in
`diet_value` (0 to 100). Both methods also calculate raw totals from the
intake fields below, using the packaged reference by default. Raw
HEI-2015 also accepts a custom
[`diet_reference()`](https://thatoneguy006.github.io/essential8/reference/diet_reference.md);
raw DASH supports custom definitions via `dash_cutpoints`. Do not supply
both the index column and an observed percentile; an entirely missing
`diet_value` column is ignored. Data with no diet inputs retain the
package's usual missing-component behavior. Once raw scoring is
selected, every raw input column must be present (values may be
missing); an absent column is an error rather than a silently missing
diet score.

An index is compared with fixed reference cutpoints to identify its
percentile category. The package does not estimate an exact percentile
from four cutpoints, or rank the current cohort against itself. Specify
`reference = "nhanes_2015_2018"` explicitly in reproducible analyses.

The built-in DASH reference is specifically the 8-to-40 Fung-style FPED
construction identified as `essential8_fung_fped_v1`; it requires
matching food definitions, pooled weighted intake quintiles, and tie
handling. Other DASH definitions need a custom reference. HEI-2015
indices must be constructed using an appropriate established method; the
built-in reference uses individual scoring after averaging the same two
recalls' constituents and energy. It is not a usual-intake or
population-ratio estimate. Both references use NHANES 2015-2016 and
2017-2018, two-day dietary weights divided by two, and the NHANES strata
and PSU design. Detailed methodology, source URLs, hashes, sample
counts, and index definitions accompany the references and the
maintainer script `data-raw/build_diet_references.R` in the repository.

Fractional inputs confined to 0-1 (other than endpoints alone) are
rejected as apparent proportions; supply percentile points, such as 95,
not 0.95. This safeguard also rejects a batch consisting only of genuine
fractional percentiles below 1. Values are never automatically
multiplied by 100.

Supply one input pathway per call: raw intake, a precomputed index, or a
percentile. Raw intake fields cannot be combined with a precomputed
index or observed percentile. Raw fields are food-group and nutrient
summaries, prepared before scoring; the function does not parse
dietary-recall files. See
[`vignette("population-diets")`](https://thatoneguy006.github.io/essential8/articles/population-diets.md)
for executable examples and units.

## Input columns

The column names below are case-sensitive; a name that differs only by
case (for example `BMI`) is an error. MEPA, DASH, and HEI-2015 diet
fields are matched case-insensitively. A column whose values are all
missing may be logical `NA` (as
[`read.csv()`](https://rdrr.io/r/utils/read.table.html) produces for a
blank column).

- `age`: Age in years; must be present, complete, and at least 20.

- For `diet_method = "mepa"`, the 16 Table C screener-item columns named
  below and `sex` (or `female` when `sex` is absent). The item names are
  matched exactly after case normalization. If any screener item is
  present, all 16 items and sex are required; omitting every item leaves
  the diet component missing. Supply daily servings in `olive_oil`,
  `green_leafy_vegetables`, `other_vegetables`, and `whole_grains`;
  supply weekly servings or frequency in `berries`, `other_fruit`,
  `meat`, `fish`, `chicken`, `cheese`, `butter_cream`, `beans`,
  `sweets_and_pastries`, `nuts`, and `alcohol`; supply the number of
  times per week that fast-food meals are consumed in `fast_food`. Sex
  may be encoded as `"m"`/`"f"`, `"male"`/`"female"`, or `0`/`1`, where
  `0` is male and `1` is female. Character encodings are matched
  case-insensitively, and character `"0"`/`"1"` values are also
  accepted. A logical `female` column (`TRUE` for female) is also
  accepted.

- `dash` or `hei2015`: An already-computed index for the selected
  population diet method. HEI-2015 is bounded by 0 to 100. The built-in
  DASH reference requires its documented 8-to-40 definition; custom DASH
  references can specify other index ranges. These columns are unrelated
  to MEPA.

- For raw DASH scoring, supply daily intakes in `dash_fruits`,
  `dash_vegetables`, `dash_nuts_and_legumes`, `dash_whole_grains`,
  `dash_low_fat_dairy`, `dash_red_and_processed_meat`, and
  `dash_sweetened_beverages`; supply sodium in mg/day in `dash_sodium`.
  Canonical mapping fields omit the `dash_` prefix. Fruits include
  juice; vegetables exclude potatoes and legumes. Food groups and
  serving definitions must match the reference. With the packaged
  reference, also supply positive kcal/day in `dash_energy_kcal`; sodium
  is standardized to 2,000 kcal before scoring. Other fields must use
  the FPED-derived units and definitions in
  [`vignette("population-diets")`](https://thatoneguy006.github.io/essential8/articles/population-diets.md),
  including fruit cup equivalents, whole-grain ounce equivalents, and
  the specified vegetable, dairy, protein, and beverage conversions.
  With explicit `dash_cutpoints`, energy is not required and no
  standardization is applied.

- For raw HEI-2015 scoring, supply `hei2015_energy_kcal` (positive
  kcal/day, including alcohol); cup equivalents/day in
  `hei2015_total_fruits`, `hei2015_whole_fruits`,
  `hei2015_total_vegetables`, `hei2015_greens_and_beans`, and
  `hei2015_dairy`; ounce equivalents/day in `hei2015_whole_grains`,
  `hei2015_total_protein_foods`, `hei2015_seafood_and_plant_proteins`,
  and `hei2015_refined_grains`; grams/day in
  `hei2015_polyunsaturated_fat`, `hei2015_monounsaturated_fat`, and
  `hei2015_saturated_fat`; mg/day in `hei2015_sodium`; and teaspoon
  equivalents/day in `hei2015_added_sugars`. Canonical mapping fields
  omit the `hei2015_` prefix. Food-group totals must already include
  legumes in both vegetable and protein components as specified by
  HEI-2015. Total fruits include juice; whole fruits do not.

- `diet_value`: A direct percentile for `"dash"`, `"hei2015"`, or the
  backward-compatible generic `"percentile"` method. Supply a DASH or
  HEI-2015 percentile from 0 to 100, calculated against the relevant
  reference distribution. The function does not rank supplied rows
  against one another. If this column is absent or missing, the diet
  score is missing. MEPA and raw-intake calls require it to be absent or
  entirely missing.

- `moderate_activity_minutes` and `vigorous_activity_minutes`: Weekly
  minutes. Each vigorous minute counts as two moderate-equivalent
  minutes.

- `smoking_status`: One of `"never"`, `"former"`, or `"current"`.

- `years_since_quit`: Years since quitting combustible tobacco. This is
  used only when `smoking_status` is `"former"`.

- `current_inhaled_nds`: Whether an inhaled nicotine-delivery system is
  currently used.

- `secondhand_smoke_home`: Whether the adult lives with an active indoor
  smoker.

- `sleep_hours`: Average hours of sleep per night.

- `bmi`: Body mass index in kg/m^2. Values below 18.5 are not scored
  because the AHA advisory defers to clinician judgment for underweight
  adults.

- `bmi_profile`: Either `"general"` or `"asian_pacific"`. The function
  never infers a profile from race or ethnicity.

- `non_hdl_cholesterol`: Non-HDL cholesterol in mg/dL.

- `lipid_lowering_treatment`: Whether the lipid value is drug treated.

- `diabetes`: Whether diabetes has been diagnosed.

- `glucose_measure`: Either `"fasting_glucose"` or `"hba1c"`.

- `glucose_value`: Fasting glucose in mg/dL or HbA1c in percent, as
  named by `glucose_measure`. Diagnosed diabetes requires HbA1c. A
  record with no diabetes diagnosis but a value in the diagnostic
  diabetes range is rejected because the AHA scoring table does not
  assign that combination.

- `systolic_bp` and `diastolic_bp`: Blood pressure in mm Hg.

- `antihypertensive_treatment`: Whether the blood pressure is treated.

Component input columns may contain missing values or be omitted. A
component score is `NA_real_` when its available inputs are
insufficient. Missing values are never imputed. A warning is emitted
when an entire LE8 component cannot be calculated for any observation.

## Optional clinical-judgment columns

- `apply_lean_muscular_bmi_override`: A caller-adjudicated flag
  asserting that a lean, higher-muscle-mass adult in the general BMI
  profile has a BMI from 25 to less than 30 and should receive 100 BMI
  points. If absent, the standard BMI band is used.

- `apply_sleep_apnea_penalty`: If `TRUE`, subtract 20 points for
  untreated or undertreated sleep apnea. If absent, no discretionary
  penalty is applied.

- `apply_prediabetes_metformin_penalty`: A caller-adjudicated flag
  asserting that the adult has a history of prediabetes, is taking
  metformin to prevent diabetes, is currently normoglycemic, and the
  clinician chose to apply the AHA's discretionary 20-point decrement.
  If absent, no discretionary penalty is applied.

## Source-constrained behavior

The function derives the 0-to-16 MEPA total from the 16 raw screener
responses. Raw DASH scoring uses the eight-component Fung index: five
food groups receive 1 to 5 points by intake quintile; sodium,
red/processed meat, and sweetened beverages receive 5 to 1. Intakes
equal to a quintile cutpoint stay in the lower quintile. Their sum is
`dash_total` (8 to 40).

Raw HEI-2015 calls compute 13 density, fatty-acid-ratio, and
energy-percentage components with proportional scoring between the
published standards. Added sugars use 16 kcal per teaspoon equivalent;
saturated fat uses 9 kcal per gram. Scores are capped at each
component's maximum. Their sum is `hei2015_total` (0 to 100), which is
distinct from the LE8 diet score. With zero saturated fat and positive
unsaturated fat, the fatty-acid component receives 10 points; with all
three fats zero it receives zero, following the NCI scoring macro.
Missing inputs are never treated as zero; a total requires all of its
diet components, regardless of `min_components`.

Raw DASH and HEI-2015 totals are converted to LE8 scores of 0, 25, 50,
80, or 100 using fixed reference total-score cutpoints. Equality enters
the higher LE8 band. Explicit cutpoints override the packaged reference
and must come from a suitable fixed reference population, using
appropriate survey weights and strata where applicable. Cutpoints are
never inferred from `data`. For references requiring different cutpoints
by stratum, score strata in separate calls. Alternatively,
`diet_method = "percentile"` accepts externally calculated DASH or
HEI-2015 percentiles. The rows in `data` are never ranked against one
another.

The AHA table applies 20-point treatment decrements to blood-lipid and
blood-pressure scores. These components are floored at zero, consistent
with the AHA's 0-to-100 metric definition. Optional sleep-apnea and
prediabetes/metformin decrements are applied only through explicit
flags. Inputs are not rounded. The documented MEPA daily/weekly
equivalences are applied where the source question and criterion use
different timeframes. Combinations without a source-defined score,
including simultaneous current combustible smoking and current
inhaled-NDS use, produce a structured error.

## References

Lloyd-Jones DM, Allen NB, Anderson CAM, et al. (2022). Life's Essential
8: Updating and Enhancing the American Heart Association's Construct of
Cardiovascular Health. *Circulation*, 146(5), e18-e43.
[doi:10.1161/CIR.0000000000001078](https://doi.org/10.1161/CIR.0000000000001078)

Lloyd-Jones DM, Ning H, Labarthe D, et al. (2022). Status of
Cardiovascular Health in US Adults and Children Using the American Heart
Association's New Life's Essential 8 Metrics. *Circulation*, 146(11),
822-835.
[doi:10.1161/CIRCULATIONAHA.122.060911](https://doi.org/10.1161/CIRCULATIONAHA.122.060911)

Fung TT, Chiuve SE, McCullough ML, et al. (2008). Adherence to a
DASH-Style Diet and Risk of Coronary Heart Disease and Stroke in Women.
*Archives of Internal Medicine*, 168(7), 713-720.
[doi:10.1001/archinte.168.7.713](https://doi.org/10.1001/archinte.168.7.713)

Krebs-Smith SM, Pannucci TE, Subar AF, et al. (2018). Update of the
Healthy Eating Index: HEI-2015. *Journal of the Academy of Nutrition and
Dietetics*, 118(9), 1591-1602.
[doi:10.1016/j.jand.2018.05.021](https://doi.org/10.1016/j.jand.2018.05.021)
See also the National Cancer Institute's [scoring
standards](https://epi.grants.cancer.gov/hei/developing.html) and
[algorithm](https://epi.grants.cancer.gov/hei/hei-scoring-method.html).

## Examples

``` r
library(dplyr)
#> 
#> Attaching package: ‘dplyr’
#> The following objects are masked from ‘package:stats’:
#> 
#>     filter, lag
#> The following objects are masked from ‘package:base’:
#> 
#>     intersect, setdiff, setequal, union

patient <- tibble(
  id = "patient_1",
  age = 55,
  sex = "female",
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
  moderate_activity_minutes = 90,
  vigorous_activity_minutes = 0,
  smoking_status = "former",
  years_since_quit = 6,
  current_inhaled_nds = FALSE,
  secondhand_smoke_home = FALSE,
  sleep_hours = 7.5,
  bmi = 27.5,
  bmi_profile = "general",
  non_hdl_cholesterol = 145,
  lipid_lowering_treatment = FALSE,
  diabetes = FALSE,
  glucose_measure = "fasting_glucose",
  glucose_value = 95,
  systolic_bp = 128,
  diastolic_bp = 78,
  antihypertensive_treatment = FALSE
)

scores <- score_le8(patient, diet_method = "mepa")
select(scores, id, mepa_total, le8_diet_score, le8_composite_score,
       le8_category)
#> # A tibble: 1 × 5
#>   id        mepa_total le8_diet_score le8_composite_score le8_category
#>   <chr>          <int>          <dbl>               <dbl> <chr>       
#> 1 patient_1         14             80                  80 high        
```
