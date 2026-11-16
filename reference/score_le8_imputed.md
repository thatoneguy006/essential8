# Score multiply imputed LE8 inputs

Scores every completed data set from a multiple imputation and returns
them stacked, with the imputation number in `.imp`. Methods for the
result pool across imputations with Rubin's rules:
[`summary()`](https://rdrr.io/r/base/summary.html) and, with dplyr,
[`summarise()`](https://dplyr.tidyverse.org/reference/summarise.html)
report pooled means with confidence intervals, and
`plot(type = "forest")` draws pooled intervals.

## Usage

``` r
score_le8_imputed(data, ...)
```

## Arguments

- data:

  A `mids` object from
  [`mice::mice()`](https://amices.org/mice/reference/mice.html) (for
  example, run with the settings from
  [`le8_imputation_setup()`](https://thatoneguy006.github.io/essential8/reference/le8_imputation_setup.md)),
  or a data frame of stacked completed data sets with an integer `.imp`
  column numbering them from 1 (for example, from
  `mice::complete(imputed, "long")` or another imputation package). To
  impute and score in one call, use `score_le8(impute = TRUE)` instead.

- ...:

  Arguments passed to
  [`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md),
  such as `min_components`.

## Value

An `essential8_imputed_scores` object: the stacked scored data sets, a
subclass of `essential8_scores`. Its
[`summary()`](https://rdrr.io/r/base/summary.html),
[`summarise()`](https://dplyr.tidyverse.org/reference/summarise.html),
[`tidy()`](https://generics.r-lib.org/reference/tidy.html), and
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) methods account
for the imputations.

## Pooling

Each statistic is estimated in every imputed data set and combined with
Rubin's rules. Means are pooled with total variance \\T = \bar{U} + (1 +
1/m) B\\ and Barnard-Rubin degrees of freedom; the fraction of missing
information (`fmi`) describes how much the imputations add to the
uncertainty. Category percentages are pooled the same way. Standard
deviations and quantiles are averaged across imputations, which
describes the distribution but carries no interval.

## See also

[`le8_imputation_setup()`](https://thatoneguy006.github.io/essential8/reference/le8_imputation_setup.md)

## Examples

``` r
adults <- read.csv(system.file(
  "extdata", "le8-adult-example.csv", package = "essential8"
))
adults <- adults[!startsWith(names(adults), "expected_")]
adults$non_hdl_cholesterol[c(2, 5)] <- NA

# Stacked completed data sets, as any imputation software might return.
completed <- function(imp, value) {
  out <- adults
  out$non_hdl_cholesterol[is.na(out$non_hdl_cholesterol)] <- value
  cbind(.imp = imp, out)
}
stacked <- rbind(completed(1L, 150), completed(2L, 170))
summary(score_le8_imputed(stacked))
#> LE8 scores: 10 participants (10 adult), pooled over 2 imputations
#> Diet method: mepa; min_components: 7
#> Composite score available for 10 of 10 (average over imputations).
#> 
#>                    n mean    95% CI  fmi   sd median
#> LE8 composite     10 48.1 27.2-68.9 0.19 28.2   49.1
#> Diet              10 51.0 22.9-79.1 0.19 38.1   50.0
#> Physical activity 10 60.0 35.2-84.8 0.19 33.7   70.0
#> Nicotine exposure 10 40.0 15.4-64.6 0.19 33.3   30.0
#> Sleep             10 55.0 28.5-81.5 0.19 36.0   55.0
#> BMI               10 46.5 20.2-72.8 0.19 35.7   50.0
#> Blood lipids      10 44.0 18.3-69.7 0.30 31.6   40.0
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
