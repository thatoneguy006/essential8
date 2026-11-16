# essential8 ![](reference/figures/essential8_favicon.png)

## Overview

`essential8` provides a reproducible R implementation of the American
Heart Association Life’s Essential 8 cardiovascular health scoring
framework.

It scores both adults aged 20 years or older and children aged 4 months
to 19 years, choosing the adult or pediatric AHA definitions row by row
from `age`. See
[`vignette("pediatric-scoring")`](https://thatoneguy006.github.io/essential8/articles/pediatric-scoring.md)
for pediatric-specific rules.

## Installation

### CRAN

``` r

install.packages("essential8")
```

### Development

``` r

# install.packages("pak")
pak::pak("thatoneguy006/essential8")
```

## Background

The American Heart Association Life’s Essential 8 (LE8) framework
combines eight lifestyle and health components into a composite
cardiovascular health score from 0 to 100. `essential8` applies the
published adult and pediatric scoring bands in one tested workflow and
returns all eight component scores plus the composite.

The scoring components are as follows:

- diet (MEPA, DASH, HEI-2015, or externally supplied percentiles)
- physical activity (moderate and vigorous activity)
- smoking
- sleep
- BMI
- blood lipids
- blood glucose and diabetes status
- blood pressure (requires both systolic and diastolic measures)

Diet can be scored with one of three measures:

- MEPA \[[1](#ref-cerwinske2017mepa)\]
- DASH \[[2](#ref-fung2008dash)\]
- HEI-2015 \[[3](#ref-krebssmith2018hei)\]

MEPA is based on a 16-item questionnaire. DASH and HEI-2015 are based on
population indices. More information about the nuances with diet scoring
can be found in [Diet scoring in Life’s Essential
8](https://thatoneguy006.github.io/essential8/vignettes/population-diets.Rmd),
also available through
[`vignette("population-diets", package = "essential8")`](https://thatoneguy006.github.io/essential8/articles/population-diets.md).

## Basic use

If this is your first time working with Life Essential 8 scores, you
should read the AHA advisory \[[4](#ref-lloydjones2022le8)\] and
[`?score_le8`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
before using the package, particularly the input units,
population-percentile diet requirements, and optional clinical-judgment
adjustments.

Pass a data frame containing inputs for the eight AHA metrics. Missing
component values are allowed, and component-specific columns may be
omitted when a domain is unavailable. By default, the composite score is
calculated when at least seven components are available; this can be
changed via `min_components` with valid thresholds from 1 through 8.

The examples use `dplyr` and the native pipe (`|>`, available in R
4.1+). The first scores one adult using MEPA:

``` r

library(essential8)
library(dplyr)

patient <- tibble(
  id = "patient_1",
  age = 55,
  sex = "female",

  # MEPA items
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

  # Physical activity
  moderate_activity_minutes = 90,
  vigorous_activity_minutes = 0,

  # Smoking
  smoking_status = "former",
  years_since_quit = 6,
  current_inhaled_nds = FALSE,
  secondhand_smoke_home = FALSE,

  # Sleep
  sleep_hours = 7.5,

  # BMI
  bmi = 27.5,
  bmi_profile = "general",

  # Blood lipids
  non_hdl_cholesterol = 145,
  lipid_lowering_treatment = FALSE,

  # Diabetes & Glucose
  diabetes = FALSE,
  glucose_measure = "fasting_glucose",
  glucose_value = 95,

  # Blood Pressure
  systolic_bp = 128,
  diastolic_bp = 78,
  antihypertensive_treatment = FALSE
)
```

``` r

patient |>
  score_le8(diet_method = "mepa") |>
  select(id, mepa_total, diet_score, le8_composite_score, le8_category)
#> # A tibble: 1 × 5
#>   id        mepa_total diet_score le8_composite_score le8_category
#>   <chr>          <int>      <dbl>               <dbl> <chr>       
#> 1 patient_1         14         80                  80 high
```

The `diet_method` argument accepts `"mepa"`, `"dash"`, `"hei2015"`, or
`"percentile"`. The `min_components` argument defaults to 7. For
`diet_method = "mepa"`, the function calculates `mepa_total` directly
from the 16 screener questions. Their column names must be the column
labels shown above. Matching of MEPA, DASH, and HEI-2015 diet columns is
case-insensitive; all other input column names are case-sensitive.

The default MEPA sex field is `sex`; if it is absent, a `female` column
is recognized automatically. Map any other field with, for example,
`mepa_columns = c(sex = "reported_sex", alcohol = "alc")`. For sex,
values are trimmed and matched case-insensitively as `m`/`f` or
`male`/`female`. Numeric or character `0`/`1` values are also accepted,
where `0` is male and `1` is female.

For data that use different diet methods, split the rows into separate
data frames and call
[`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
separately. Percentile calls use `diet_value`, containing a DASH or
HEI-2015 percentile from 0 to 100. The result appends all eight
component scores, `n_components`, `le8_complete`, the composite score,
and its cardiovascular health category. See
[`?score_le8`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
for more information.

## DASH and HEI-2015

For population research, use `diet_method = "dash"` or `"hei2015"` with
raw food and nutrient inputs, an existing diet score, or a percentile.
For example, add an existing HEI-2015 score to the adult record above:

``` r

patient |>
  mutate(hei2015 = 70) |>
  score_le8(diet_method = "hei2015", reference = "nhanes_2015_2018") |>
  select(id, hei2015, diet_score, le8_composite_score)
#> # A tibble: 1 × 4
#>   id        hei2015 diet_score le8_composite_score
#>   <chr>       <dbl>      <dbl>               <dbl>
#> 1 patient_1      70         80                  80
```

The diet score is converted to LE8 points using the selected reference.
See [Diet scoring in Life’s Essential
8](https://thatoneguy006.github.io/essential8/vignettes/population-diets.Rmd),
also available through
[`vignette("population-diets", package = "essential8")`](https://thatoneguy006.github.io/essential8/articles/population-diets.md),
for the background, scoring rules, input units, and examples.

## Incomplete component data

[`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
preserves ordinary row-level missingness. The composite is the mean of
the available component scores when the selected threshold is met:

``` r

bind_rows(
  patient,
  patient |> 
    mutate(id = "sleep_missing", sleep_hours = NA_real_)
  ) |>
  score_le8(min_components = 7) |>
  select(id, le8_composite_score, n_components, le8_complete)
#> # A tibble: 2 × 4
#>   id            le8_composite_score n_components le8_complete
#>   <chr>                       <dbl>        <int> <lgl>       
#> 1 patient_1                    80              8 TRUE        
#> 2 sleep_missing                77.1            7 FALSE
```

`n_components` reports how many component scores contributed, while
`le8_complete` is `TRUE` only when all eight were available. If a
component cannot be calculated for any observation, the function emits
one consolidated warning identifying every structurally unavailable
component.

## Imputing missing inputs

By default, `score_le8(impute = FALSE)` never fills in missing values:
the composite averages whichever components are available, which treats
a missing component as equal to the average of that person’s other
components. With `impute = TRUE`,
[`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
instead uses multiple imputation \[[5](#ref-rubin1987multiple)\] with
mice \[[6](#ref-vanbuuren2011mice)\]:

1.  **Check.** Observed values are validated first, so data that cannot
    be scored stop before any imputation.
2.  **Impute the inputs, not the scores.** Each missing input, such as
    non-HDL cholesterol or sleep hours, is imputed from age, the
    participant’s other inputs, and any auxiliary variables you supply.
    Numeric inputs use predictive mean matching, which only ever imputes
    values observed in other participants; categorical inputs use
    logistic or multinomial regression.
3.  **Follow the scoring rules.** An input is imputed only for
    participants whose age uses it (adult BMI is never imputed for a
    child, for example), and combinations the AHA rules do not score,
    such as diagnosed diabetes without an HbA1c, are never imputed.
4.  **Score and pool.** Each completed data set is scored and the
    results are stacked with an `.imp` column.
    [`summary()`](https://rdrr.io/r/base/summary.html),
    [`summarise()`](https://dplyr.tidyverse.org/reference/summarise.html),
    and [`plot()`](https://rdrr.io/r/graphics/plot.default.html) pool
    them with Rubin’s rules, so confidence intervals include the
    uncertainty from the missing values.

``` r

adults <- read.csv(
  system.file("extdata", "le8-adult-example.csv", package = "essential8")
  ) |>
  select(!starts_with("expected_")) |>
  mutate(non_hdl_cholesterol = replace(non_hdl_cholesterol, c(2, 5, 8), NA))

imputed <- adults |>
  score_le8(impute = le8_imputation_control(m = 20, seed = 2026))

summarise(imputed) |>
  filter(measure %in% c("composite", "blood_lipids")) |>
  select(measure, mean, conf.low, conf.high, fmi) |>
  mutate(across(where(is.numeric), \(x) round(x, 2)))
#>        measure  mean conf.low conf.high  fmi
#> 1    composite 49.06    28.48     69.64 0.19
#> 2 blood_lipids 52.00    24.49     79.51 0.30
```

The fraction of missing information (`fmi`) shows how much of each
interval’s width comes from the imputed values.
[`le8_imputation_control()`](https://thatoneguy006.github.io/essential8/reference/le8_imputation_control.md)
sets the number of imputations, a seed, and auxiliary predictors such as
an analysis outcome;
[`le8_imputation_setup()`](https://thatoneguy006.github.io/essential8/reference/le8_imputation_setup.md)
shows exactly what will be imputed and how.
[`vignette("case-study")`](https://thatoneguy006.github.io/essential8/articles/case-study.md)
compares complete cases, averaged components, and multiple imputation on
simulated data.

## Summarize and plot scores

The scored data keep their original class and gain methods for
[`summary()`](https://rdrr.io/r/base/summary.html),
[`tidy()`](https://generics.r-lib.org/reference/tidy.html) (long
format), [`plot()`](https://rdrr.io/r/graphics/plot.default.html) (with
ggplot2), and, with dplyr,
[`summarise()`](https://dplyr.tidyverse.org/reference/summarise.html)
without expressions for grouped summaries:

``` r

scored <- bind_rows(
  patient,
  patient |> mutate(id = "patient_2", sleep_hours = 5, bmi = 31)
) |>
  score_le8()
```

``` r

summary(scored)
#> LE8 scores: 2 rows (2 adult)
#> Diet method: mepa; min_components: 7
#> Composite score available for 2 of 2; all 8 components for 2.
#> 
#>                   n  mean   sd median         IQR       range
#> LE8 composite     2  73.8  8.8   73.8   70.6-76.9   67.5-80.0
#> Diet              2  80.0  0.0   80.0   80.0-80.0   80.0-80.0
#> Physical activity 2  80.0  0.0   80.0   80.0-80.0   80.0-80.0
#> Nicotine exposure 2  75.0  0.0   75.0   75.0-75.0   75.0-75.0
#> Sleep             2  70.0 42.4   70.0   55.0-85.0  40.0-100.0
#> BMI               2  50.0 28.3   50.0   40.0-60.0   30.0-70.0
#> Blood lipids      2  60.0  0.0   60.0   60.0-60.0   60.0-60.0
#> Blood glucose     2 100.0  0.0  100.0 100.0-100.0 100.0-100.0
#> Blood pressure    2  75.0  0.0   75.0   75.0-75.0   75.0-75.0
#> 
#> Category (rows with a composite score):
#>            n percent
#>   low      0    0.0%
#>   moderate 1   50.0%
#>   high     1   50.0%
```

``` r

summarise(scored)
#> # A tibble: 9 × 10
#>   measure               n n_missing  mean    sd   min   q25 median   q75   max
#>   <fct>             <int>     <int> <dbl> <dbl> <dbl> <dbl>  <dbl> <dbl> <dbl>
#> 1 composite             2         0  73.8  8.84  67.5  70.6   73.8  76.9    80
#> 2 diet                  2         0  80    0     80    80     80    80      80
#> 3 physical_activity     2         0  80    0     80    80     80    80      80
#> 4 nicotine              2         0  75    0     75    75     75    75      75
#> 5 sleep                 2         0  70   42.4   40    55     70    85     100
#> 6 bmi                   2         0  50   28.3   30    40     50    60      70
#> 7 blood_lipids          2         0  60    0     60    60     60    60      60
#> 8 blood_glucose         2         0 100    0    100   100    100   100     100
#> 9 blood_pressure        2         0  75    0     75    75     75    75      75
```

## Learn more

- Package website:
  <https://thatoneguy006.github.io/essential8/index.html>
- Get started:
  <https://thatoneguy006.github.io/essential8/articles/essential8-get-started.html>

## Disclaimer

`essential8` is independent research software and is not affiliated
with, sponsored by, approved by, or endorsed by the American Heart
Association. It is not intended for clinical decision-making or
diagnosis of health problems.

## References

1\.

Cerwinske LA, Rasmussen HE, Lipson S, Volgman AS, Tangney CC. Evaluation
of a dietary screener: The Mediterranean Eating Pattern for Americans
tool. J Hum Nutr Diet. 2017;30(5):596–603.
<doi:%5B10.1111/jhn.12451>\](<https://doi.org/10.1111/jhn.12451>)

2\.

Fung TT, Chiuve SE, McCullough ML, Rexrode KM, Logroscino G, Hu FB.
Adherence to a DASH-style diet and risk of coronary heart disease and
stroke in women. Arch Intern Med. 2008;168(7):713–20.
<doi:%5B10.1001/archinte.168.7.713>\](<https://doi.org/10.1001/archinte.168.7.713>)

3\.

Krebs-Smith SM, Pannucci TE, Subar AF, Kirkpatrick SI, Lerman JL, Tooze
JA, et al. Update of the Healthy Eating Index: HEI-2015. J Acad Nutr
Diet. 2018;118(9):1591–602.
<doi:%5B10.1016/j.jand.2018.05.021>\](<https://doi.org/10.1016/j.jand.2018.05.021>)

4\.

Lloyd-Jones DM, Allen NB, Anderson CAM, Black T, Brewer LC, Foraker RE,
et al. Life’s Essential 8: Updating and enhancing the American Heart
Association’s construct of cardiovascular health: A presidential
advisory from the American Heart Association. Circulation.
2022;146(5):e18–43.
<doi:%5B10.1161/CIR.0000000000001078>\](<https://doi.org/10.1161/CIR.0000000000001078>)

5\.

Rubin DB. Multiple imputation for nonresponse in surveys. New York: John
Wiley & Sons; 1987.
<doi:%5B10.1002/9780470316696>\](<https://doi.org/10.1002/9780470316696>)

6\.

van Buuren S, Groothuis-Oudshoorn K. mice: Multivariate imputation by
chained equations in R. J Stat Softw. 2011;45(3):1–67.
<doi:%5B10.18637/jss.v045.i03>\](<https://doi.org/10.18637/jss.v045.i03>)
