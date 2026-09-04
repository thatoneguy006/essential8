# Score Life's Essential 8 cardiovascular health

Computes the eight adult Life's Essential 8 (LE8) component scores and
the composite score using the American Heart Association's 2022
Presidential Advisory. Component scores are calculated wherever
sufficient inputs are available, without imputing missing values. This
implementation applies only to adults aged 20 years or older.

## Usage

``` r
score_le8(data, diet_method = "mepa", mepa_columns = NULL, min_components = 7L)
```

## Arguments

- data:

  A data frame with one row per adult and the input columns described
  below.

- diet_method:

  A single diet-scoring method applied to every row in `data`: `"mepa"`
  (the default) or `"percentile"`. Values are matched
  case-insensitively. Score data that use different methods in separate
  calls.

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

## Value

A data frame containing the original columns plus `mepa_total` (missing
for population-percentile rows),
`physical_activity_moderate_equivalent_minutes`, the eight component
score columns prefixed with `le8_`, `le8_n_components`,
`le8_composite_score`, `le8_complete`, and `le8_category`. The component
count reports how many scores contributed to the composite score;
`le8_complete` is `TRUE` only when all eight components are available.
Categories are `"low"` for scores below 50, `"moderate"` for scores from
50 to less than 80, and `"high"` for scores of at least 80. The category
is missing when the composite score is missing.

## Input columns

- `age`: Age in years; must be present, complete, and at least 20.

- For `diet_method = "mepa"`, the 16 Table C screener-item columns named
  below and `sex` (or `female` when `sex` is absent). The item names are
  matched exactly after case normalization. Supply daily servings in
  `olive_oil`, `green_leafy_vegetables`, `other_vegetables`, and
  `whole_grains`; supply weekly servings or frequency in `berries`,
  `other_fruit`, `meat`, `fish`, `chicken`, `cheese`, `butter_cream`,
  `beans`, `sweets_and_pastries`, `nuts`, and `alcohol`; supply the
  number of times per week that fast-food meals are consumed in
  `fast_food`. Sex may be encoded as `"m"`/`"f"`, `"male"`/`"female"`,
  or `0`/`1`, where `0` is male and `1` is female. Character encodings
  are matched case-insensitively, and character `"0"`/`"1"` values are
  also accepted.

- `diet_value`: Used when `diet_method = "percentile"`. Supply a DASH or
  HEI-2015 percentile from 1 to 100, calculated against the relevant
  reference distribution. The function does not rank supplied rows
  against one another. If this column is absent or missing, the diet
  score is missing. If it is present for MEPA data, all its values must
  be missing.

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
responses. For population scoring, callers must supply a DASH or
HEI-2015 percentile calculated against the relevant reference
population; the rows in `data` are not their own reference distribution.

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

## Examples

``` r
patient <- data.frame(
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
scores[
  c(
    "id",
    "mepa_total",
    "le8_diet_score",
    "le8_composite_score",
    "le8_category"
  )
]
#>          id mepa_total le8_diet_score le8_composite_score le8_category
#> 1 patient_1         14             80                  80         high
```
