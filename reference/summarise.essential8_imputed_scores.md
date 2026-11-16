# Summarise multiply imputed LE8 scores with dplyr

The
[summarise()](https://thatoneguy006.github.io/essential8/reference/summarise.essential8_scores.md)
method for scores from
[`score_le8_imputed()`](https://thatoneguy006.github.io/essential8/reference/score_le8_imputed.md).
Without expressions, it returns the pooled statistics in
[summary()](https://thatoneguy006.github.io/essential8/reference/summary.essential8_imputed_scores.md),
one row per measure and group. With expressions, it is ordinary dplyr on
the stacked data sets; add `.imp` to `.by` to summarise each imputation
separately.

## Usage

``` r
# S3 method for class 'essential8_imputed_scores'
summarise(.data, ..., .by = NULL, .groups = NULL)
```

## Arguments

- .data:

  An `essential8_imputed_scores` object.

- ...:

  Summary expressions. If any are supplied, the call is handled by
  [`dplyr::summarise()`](https://dplyr.tidyverse.org/reference/summarise.html).

- .by:

  \<[`tidy-select`](https://dplyr.tidyverse.org/reference/dplyr_tidy_select.html)\>
  Optional columns to group by for this summary.

- .groups:

  Passed to
  [`dplyr::summarise()`](https://dplyr.tidyverse.org/reference/summarise.html)
  when `...` is supplied. Otherwise ignored; the LE8 summary is always
  ungrouped.

## Value

Without expressions, an ungrouped data frame with the grouping columns,
`measure`, and the pooled statistics: `n`, `n_missing`, `mean`,
`std.error`, `conf.low`, `conf.high` (95%), `df`, `fmi`, and the
averaged `sd`, `min`, `q25`, `median`, `q75`, and `max`. With
expressions, the result of
[`dplyr::summarise()`](https://dplyr.tidyverse.org/reference/summarise.html).

## See also

[`summary.essential8_imputed_scores()`](https://thatoneguy006.github.io/essential8/reference/summary.essential8_imputed_scores.md)
