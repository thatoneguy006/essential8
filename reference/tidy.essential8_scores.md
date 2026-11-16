# Tidy LE8 scores into long format

Reshapes the composite and component scores returned by
[`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
into long format, with one row per input row and measure. This is the
shape ggplot2 and grouped summaries expect.

## Usage

``` r
# S3 method for class 'essential8_scores'
tidy(x, id_cols = NULL, composite = TRUE, ...)
```

## Arguments

- x:

  An `essential8_scores` object returned by
  [`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md).

- id_cols:

  Optional character vector of columns in `x` to carry into the result,
  such as a participant identifier. Defaults to the grouping columns
  when `x` is a grouped tibble, and to none otherwise. Scores from
  [`score_le8_imputed()`](https://thatoneguy006.github.io/essential8/reference/score_le8_imputed.md)
  always carry `.imp` (and `.id`, when present).

- composite:

  Whether to include the composite score as a measure.

- ...:

  Not used.

## Value

A data frame of the same type as `x` (a tibble for tibble input),
ungrouped, with the columns:

- `row`: the row of `x` the score comes from.

- the `id_cols`.

- `le8_population`: `"adult"` or `"pediatric"`.

- `measure`: a factor; `composite` (when included), then `diet`,
  `physical_activity`, `nicotine`, `sleep`, `bmi`, `blood_lipids`,
  `blood_glucose`, and `blood_pressure`.

- `score`: the score, from 0 to 100, or `NA` when unavailable.

## See also

[`summary.essential8_scores()`](https://thatoneguy006.github.io/essential8/reference/summary.essential8_scores.md),
[`plot.essential8_scores()`](https://thatoneguy006.github.io/essential8/reference/plot.essential8_scores.md)

## Examples

``` r
adults <- read.csv(system.file(
  "extdata", "le8-adult-example.csv", package = "essential8"
))
adults <- adults[!startsWith(names(adults), "expected_")]
scores <- score_le8(adults)
head(tidy(scores, id_cols = "id"), 9)
#>   row              id le8_population           measure score
#> 1   1 optimal_general          adult         composite   100
#> 2   1 optimal_general          adult              diet   100
#> 3   1 optimal_general          adult physical_activity   100
#> 4   1 optimal_general          adult          nicotine   100
#> 5   1 optimal_general          adult             sleep   100
#> 6   1 optimal_general          adult               bmi   100
#> 7   1 optimal_general          adult      blood_lipids   100
#> 8   1 optimal_general          adult     blood_glucose   100
#> 9   1 optimal_general          adult    blood_pressure   100
```
