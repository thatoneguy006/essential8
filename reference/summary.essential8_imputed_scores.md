# Summarize multiply imputed LE8 scores

Pools the scores from `score_le8(impute = TRUE)` or
[`score_le8_imputed()`](https://thatoneguy006.github.io/essential8/reference/score_le8_imputed.md)
across imputations with Rubin's rules. Means and category percentages
get pooled confidence intervals and the fraction of missing information;
standard deviations and quantiles are averaged across imputations.
Counts are per participant (averaged across imputations), not per
stacked row.

## Usage

``` r
# S3 method for class 'essential8_imputed_scores'
summary(object, conf_level = 0.95, ...)

# S3 method for class 'summary.essential8_imputed_scores'
print(x, digits = 1, ...)
```

## Arguments

- object:

  An `essential8_imputed_scores` object from
  [`score_le8_imputed()`](https://thatoneguy006.github.io/essential8/reference/score_le8_imputed.md).

- conf_level:

  Confidence level for the pooled intervals.

- ...:

  Not used.

- x:

  A `summary.essential8_imputed_scores` object.

- digits:

  Number of decimal places to print.

## Value

[`summary()`](https://rdrr.io/r/base/summary.html) returns a
`summary.essential8_imputed_scores` object, a list with `n`
(participants), `m` (imputations), `population`, `n_composite`,
`n_complete`, `statistics` (one row per measure with `n`, `n_missing`,
pooled `mean`, `std.error`, `conf.low`, `conf.high`, `df`, and `fmi`,
and averaged `sd`, `min`, `q25`, `median`, `q75`, and `max`),
`categories` (pooled percentages with confidence intervals),
`conf_level`, and `settings`.
[`print()`](https://rdrr.io/r/base/print.html) returns `x` invisibly.

## See also

[`score_le8_imputed()`](https://thatoneguy006.github.io/essential8/reference/score_le8_imputed.md),
[`summary.essential8_scores()`](https://thatoneguy006.github.io/essential8/reference/summary.essential8_scores.md)

## Examples

``` r
adults <- read.csv(system.file(
  "extdata", "le8-adult-example.csv", package = "essential8"
))
adults <- adults[!startsWith(names(adults), "expected_")]
adults$non_hdl_cholesterol[c(2, 5)] <- NA

scores <- score_le8(
  adults,
  impute = le8_imputation_control(m = 5, seed = 1)
)
#> Warning: Number of logged events: 55
summary(scores)
#> LE8 scores: 10 participants (10 adult), pooled over 5 imputations
#> Diet method: mepa; min_components: 7
#> Composite score available for 10 of 10 (average over imputations).
#> 
#>                    n mean    95% CI  fmi   sd median
#> LE8 composite     10 48.4 27.0-69.7 0.19 28.9   49.1
#> Diet              10 51.0 22.9-79.1 0.19 38.1   50.0
#> Physical activity 10 60.0 35.2-84.8 0.19 33.7   70.0
#> Nicotine exposure 10 40.0 15.4-64.6 0.19 33.3   30.0
#> Sleep             10 55.0 28.5-81.5 0.19 36.0   55.0
#> BMI               10 46.5 20.2-72.8 0.19 35.7   50.0
#> Blood lipids      10 46.4 17.6-75.2 0.26 37.0   42.0
#> Blood glucose     10 46.0 22.6-69.4 0.19 31.7   50.0
#> Blood pressure    10 42.0 19.4-64.6 0.19 30.7   40.0
#> Means pooled with Rubin's rules; fmi = fraction of missing information.
#> 
#> Category (rows with a composite score):
#>            n percent    95% CI
#>   low      5   50.0% 13.1-86.9
#>   moderate 4   40.0%  3.9-76.1
#>   high     1   10.0%  0.0-32.1
summary(scores)$statistics
#>             measure  n n_missing    mean std.error conf.low conf.high       df
#> 1         composite 10         0 48.3625  9.153674 26.99869  69.72631 7.485177
#> 2              diet 10         0 51.0000 12.036980 22.91725  79.08275 7.500000
#> 3 physical_activity 10         0 60.0000 10.645813 35.16290  84.83710 7.500000
#> 4          nicotine 10         0 40.0000 10.540926 15.40760  64.59240 7.500000
#> 5             sleep 10         0 55.0000 11.377365 28.45616  81.54384 7.500000
#> 6               bmi 10         0 46.5000 11.280514 20.18211  72.81789 7.500000
#> 7      blood_lipids 10         0 46.4000 12.142853 17.60321  75.19679 6.901248
#> 8     blood_glucose 10         0 46.0000 10.022198 22.61782  69.38218 7.500000
#> 9    blood_pressure 10         0 42.0000  9.695360 19.38034  64.61966 7.500000
#>         fmi       sd min     q25  median      q75 max
#> 1 0.1923391 28.91606 1.5 33.4375 49.0625 64.46875 100
#> 2 0.1904762 38.06427 0.0 25.0000 50.0000 80.00000 100
#> 3 0.1904762 33.66502 0.0 40.0000 70.0000 87.50000 100
#> 4 0.1904762 33.33333 0.0 25.0000 30.0000 63.75000 100
#> 5 0.1904762 35.97839 0.0 25.0000 55.0000 85.00000 100
#> 6 0.1904762 35.67212 0.0 18.7500 50.0000 73.75000 100
#> 7 0.2591463 36.95696 0.0 20.0000 42.0000 72.00000 100
#> 8 0.1904762 31.69297 0.0 22.5000 50.0000 60.00000 100
#> 9 0.1904762 30.65942 0.0 26.2500 40.0000 53.75000 100
```
