# Summarize LE8 scores

Summarizes the composite and component scores returned by
[`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md):
how many rows were scored, the distribution of each score, and the
cardiovascular health categories. Grouping is ignored; use
[summarise()](https://thatoneguy006.github.io/essential8/reference/summarise.essential8_scores.md)
for summaries by group.

## Usage

``` r
# S3 method for class 'essential8_scores'
summary(object, ...)

# S3 method for class 'summary.essential8_scores'
print(x, digits = 1, ...)
```

## Arguments

- object:

  An `essential8_scores` object returned by
  [`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md).

- ...:

  Not used.

- x:

  A `summary.essential8_scores` object.

- digits:

  Number of decimal places to print.

## Value

[`summary()`](https://rdrr.io/r/base/summary.html) returns a
`summary.essential8_scores` object, a list with:

- `n`: the number of rows.

- `population`: the number of adult and pediatric rows.

- `n_composite`: rows with a composite score.

- `n_complete`: rows with all eight component scores.

- `statistics`: a data frame with one row per measure (the composite and
  each component) and the columns `measure`, `n` (available scores),
  `n_missing`, `mean`, `sd`, `min`, `q25`, `median`, `q75`, and `max`.

- `categories`: a data frame with the count and percentage of rows in
  each category among rows with a composite score.

- `settings`: the `diet_method` and `min_components` used for scoring,
  or `NULL` when unknown (for example, after
  [`as_le8_scores()`](https://thatoneguy006.github.io/essential8/reference/as_le8_scores.md),
  or after dplyr verbs on a plain data frame, which drop custom
  attributes).

[`print()`](https://rdrr.io/r/base/print.html) returns `x` invisibly.

## See also

[`tidy.essential8_scores()`](https://thatoneguy006.github.io/essential8/reference/tidy.essential8_scores.md),
[`summarise.essential8_scores()`](https://thatoneguy006.github.io/essential8/reference/summarise.essential8_scores.md),
[`plot.essential8_scores()`](https://thatoneguy006.github.io/essential8/reference/plot.essential8_scores.md)

## Examples

``` r
adults <- read.csv(system.file(
  "extdata", "le8-adult-example.csv", package = "essential8"
))
adults <- adults[!startsWith(names(adults), "expected_")]
scores <- score_le8(adults)
summary(scores)
#> LE8 scores: 10 rows (10 adult)
#> Diet method: mepa; min_components: 7
#> Composite score available for 10 of 10; all 8 components for 10.
#> 
#>                    n mean   sd median       IQR     range
#> LE8 composite     10 47.3 28.7   49.1 33.4-60.5 0.0-100.0
#> Diet              10 51.0 38.1   50.0 25.0-80.0 0.0-100.0
#> Physical activity 10 60.0 33.7   70.0 40.0-87.5 0.0-100.0
#> Nicotine exposure 10 40.0 33.3   30.0 25.0-63.8 0.0-100.0
#> Sleep             10 55.0 36.0   55.0 25.0-85.0 0.0-100.0
#> BMI               10 46.5 35.7   50.0 18.8-73.8 0.0-100.0
#> Blood lipids      10 38.0 34.6   20.0 20.0-60.0 0.0-100.0
#> Blood glucose     10 46.0 31.7   50.0 22.5-60.0 0.0-100.0
#> Blood pressure    10 42.0 30.7   40.0 26.2-53.8 0.0-100.0
#> 
#> Category (rows with a composite score):
#>            n percent
#>   low      5   50.0%
#>   moderate 4   40.0%
#>   high     1   10.0%

# The statistics are also available as a data frame.
summary(scores)$statistics
#>             measure  n n_missing    mean       sd min     q25  median      q75
#> 1         composite 10         0 47.3125 28.72893   0 33.4375 49.0625 60.46875
#> 2              diet 10         0 51.0000 38.06427   0 25.0000 50.0000 80.00000
#> 3 physical_activity 10         0 60.0000 33.66502   0 40.0000 70.0000 87.50000
#> 4          nicotine 10         0 40.0000 33.33333   0 25.0000 30.0000 63.75000
#> 5             sleep 10         0 55.0000 35.97839   0 25.0000 55.0000 85.00000
#> 6               bmi 10         0 46.5000 35.67212   0 18.7500 50.0000 73.75000
#> 7      blood_lipids 10         0 38.0000 34.57681   0 20.0000 20.0000 60.00000
#> 8     blood_glucose 10         0 46.0000 31.69297   0 22.5000 50.0000 60.00000
#> 9    blood_pressure 10         0 42.0000 30.65942   0 26.2500 40.0000 53.75000
#>   max
#> 1 100
#> 2 100
#> 3 100
#> 4 100
#> 5 100
#> 6 100
#> 7 100
#> 8 100
#> 9 100
```
