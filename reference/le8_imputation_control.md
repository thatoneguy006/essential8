# Options for imputing missing LE8 inputs

Sets how
[`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
imputes missing inputs when `impute` is used. Pass the result as
`score_le8(impute = le8_imputation_control(...))`; `impute = TRUE` uses
the defaults.

## Usage

``` r
le8_imputation_control(m = 20, maxit = 5, seed = NA, auxiliary = NULL, ...)
```

## Arguments

- m:

  Number of imputed data sets, at least 2. A common rule of thumb for
  final analyses is at least as many imputations as the percentage of
  participants with any missing input.

- maxit:

  Number of mice iterations.

- seed:

  A whole number to make the imputations reproducible, or `NA` (the
  default) to use the session's random number stream.

- auxiliary:

  Optional character vector of other complete columns to use as
  predictors, such as analysis outcomes, exposures, or survey design
  variables; see
  [`le8_imputation_setup()`](https://thatoneguy006.github.io/essential8/reference/le8_imputation_setup.md).

- ...:

  Further arguments to
  [`mice::mice()`](https://amices.org/mice/reference/mice.html), such as
  `printFlag = TRUE` to show mice's iteration log. Arguments with the
  same names as the imputation settings (for example, `method` or
  `predictorMatrix`) replace them.

## Value

An `essential8_imputation_control` object.

## See also

[`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md),
[`le8_imputation_setup()`](https://thatoneguy006.github.io/essential8/reference/le8_imputation_setup.md)

## Examples

``` r
le8_imputation_control(m = 50, seed = 2026)
#> LE8 imputation: m = 50, maxit = 5, seed = 2026
```
