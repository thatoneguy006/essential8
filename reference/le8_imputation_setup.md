# Prepare LE8 inputs for multiple imputation with mice

`le8_imputation_setup()` returns the settings
[`mice::mice()`](https://amices.org/mice/reference/mice.html) needs to
multiply impute missing
[`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
inputs in a way the AHA scoring rules can use.
`score_le8(impute = TRUE)` uses them to impute and score in one call;
call `le8_imputation_setup()` yourself to inspect the settings, or to
adjust them and run mice directly, then score the result with
[`score_le8_imputed()`](https://thatoneguy006.github.io/essential8/reference/score_le8_imputed.md).

Imputing the inputs, rather than the 0-100 scores, keeps the
relationships between measurements that the AHA bands then summarize.
The setup encodes what is specific to LE8:

- **Only inputs a person's age uses are imputed.** For example, adult
  BMI is never imputed for a child, nor blood-pressure percentile
  thresholds for an adult, nor a MEPA item that a preschooler's screener
  does not include. Observed values in such structurally unused cells
  are set to `NA` in the prepared data so they cannot distort the
  imputation models. `years_since_quit` is imputed only for adults who
  are, or may be imputed as, former smokers.

- **Predictors are limited to inputs available (observed or imputed) for
  everyone the target applies to**, plus `age` and any `auxiliary`
  columns, so no model relies on structurally missing values.

- **Methods:** predictive mean matching (`"pmm"`) for numeric inputs,
  which imputes only observed values and so respects their range and
  skew; logistic regression (`"logreg"`) for two-level inputs; and
  multinomial regression (`"polyreg"`) otherwise. Logical and character
  inputs are converted to factors for mice;
  [`score_le8_imputed()`](https://thatoneguy006.github.io/essential8/reference/score_le8_imputed.md)
  converts them back.

- **Combinations AHA does not score are never imputed.** Diagnosed
  diabetes implies an HbA1c measure. Current combustible smoking is
  never paired with current inhaled-NDS use. An observed fasting glucose
  implies no diagnosed diabetes, and an observed HbA1c of 6.5% or more
  implies diagnosed diabetes. Each imputed glucose value comes from
  donors with the same measure and diabetes status, and a measure is
  imputed only if such donors exist. These rules run in mice's `post`
  step of every iteration, so the other imputation models condition on
  consistent values.

Two values that follow from observed data are filled in before
imputation (deductive imputation): `glucose_measure` is `"hba1c"` when
`diabetes` is `TRUE`, and `current_inhaled_nds` is `FALSE` for current
smokers.

## Usage

``` r
le8_imputation_setup(data, auxiliary = NULL, diet_method = "mepa")
```

## Arguments

- data:

  A data frame of
  [`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
  inputs.

- auxiliary:

  Optional character vector of other columns in `data` to use as
  predictors, such as analysis outcomes, exposures, or survey design
  variables. They must be complete; they are not imputed.

- diet_method:

  The diet scoring method; only `"mepa"` is supported.

## Value

An `essential8_imputation_setup` object, a list with the prepared `data`
and the mice arguments `method`, `predictorMatrix`, `where`,
`visitSequence`, and `post`, plus `inputs`, a data frame describing each
input: the rows it applies to, the values to impute, and the method.

## Details

Observed values are validated with
[`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
first, so data that cannot be scored stop here rather than after
imputation. Every observed `glucose_value` needs its `glucose_measure`.

Only the MEPA diet screener is supported. Inputs must use the default
column names, and `age` must be complete.

With adults and children in one data set, inputs that apply to only one
population cannot predict inputs that apply to both. To use richer
models, impute each population separately and combine the results with
[`rbind()`](https://rdrr.io/r/base/cbind.html), which mice provides for
`mids` objects.

Imputation models should include the variables used in later analyses,
such as exposures and outcomes. Pass them in `auxiliary`.

`score_le8(impute = TRUE)` calls
[`mice::mice()`](https://amices.org/mice/reference/mice.html) with
`remove.collinear = FALSE` and `remove.constant = FALSE`. mice's
defaults would stop imputing an input that is constant or collinear in
the observed data, leaving values that scoring needs missing. Each
imputation model still drops such predictors on its own. When calling
[`mice::mice()`](https://amices.org/mice/reference/mice.html) directly
with a setup, pass the same two arguments.

Glucose values mix units (mg/dL for fasting glucose, % for HbA1c), so
`glucose_measure` and `glucose_value` predict only each other;
`diabetes` represents glucose status in the other models.

## See also

[`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
and its `impute` argument to impute and score in one call;
[`le8_imputation_control()`](https://thatoneguy006.github.io/essential8/reference/le8_imputation_control.md);
[`score_le8_imputed()`](https://thatoneguy006.github.io/essential8/reference/score_le8_imputed.md)
to score your own mice run.

## Examples

``` r
adults <- read.csv(system.file(
  "extdata", "le8-adult-example.csv", package = "essential8"
))
adults <- adults[!startsWith(names(adults), "expected_")]
adults$non_hdl_cholesterol[c(2, 5)] <- NA
adults$sleep_hours[3] <- NA

setup <- le8_imputation_setup(adults)
setup
#> LE8 imputation setup: 10 rows; 3 missing input values to impute in 2 inputs
#> 
#>                input applies_to missing impute method
#>          sleep_hours         10       1      1    pmm
#>  non_hdl_cholesterol         10       2      2    pmm

# Adjust the settings, then run mice yourself: here, sleep hours are no
# longer predicted from age. Keep predictive mean matching for numeric
# inputs; methods such as "norm" can impute values outside their valid
# range, which score_le8() then rejects.
setup$predictorMatrix["sleep_hours", "age"] <- 0
imputed <- mice::mice(
  setup$data,
  m = 5,
  method = setup$method,
  predictorMatrix = setup$predictorMatrix,
  where = setup$where,
  visitSequence = setup$visitSequence,
  post = setup$post,
  remove.collinear = FALSE,
  remove.constant = FALSE,
  seed = 1,
  printFlag = FALSE
)
#> Warning: Number of logged events: 110
summary(score_le8_imputed(imputed))
#> LE8 scores: 10 participants (10 adult), pooled over 5 imputations
#> Diet method: mepa; min_components: 7
#> Composite score available for 10 of 10 (average over imputations).
#> 
#>                    n mean    95% CI  fmi   sd median
#> LE8 composite     10 48.6 27.1-70.1 0.19 29.1   50.9
#> Diet              10 51.0 22.9-79.1 0.19 38.1   50.0
#> Physical activity 10 60.0 35.2-84.8 0.19 33.7   70.0
#> Nicotine exposure 10 40.0 15.4-64.6 0.19 33.3   30.0
#> Sleep             10 58.0 31.0-85.0 0.26 34.8   64.0
#> BMI               10 46.5 20.2-72.8 0.19 35.7   50.0
#> Blood lipids      10 45.2 17.5-72.9 0.23 36.3   40.0
#> Blood glucose     10 46.0 22.6-69.4 0.19 31.7   50.0
#> Blood pressure    10 42.0 19.4-64.6 0.19 30.7   40.0
#> Means pooled with Rubin's rules; fmi = fraction of missing information.
#> 
#> Category (rows with a composite score):
#>            n percent    95% CI
#>   low      5   50.0% 13.1-86.9
#>   moderate 4   40.0%  3.9-76.1
#>   high     1   10.0%  0.0-32.1
```
