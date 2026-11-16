# Restore LE8 score methods to a data frame

[`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
returns an `essential8_scores` object: the input data frame (or tibble),
with its original class, plus the score columns. The extra class
provides
[summary()](https://thatoneguy006.github.io/essential8/reference/summary.essential8_scores.md),
[tidy()](https://thatoneguy006.github.io/essential8/reference/tidy.essential8_scores.md),
[plot()](https://thatoneguy006.github.io/essential8/reference/plot.essential8_scores.md),
and, with dplyr loaded,
[summarise()](https://thatoneguy006.github.io/essential8/reference/summarise.essential8_scores.md).

Row-wise operations such as
[`filter()`](https://dplyr.tidyverse.org/reference/filter.html),
[`mutate()`](https://dplyr.tidyverse.org/reference/mutate.html),
[`arrange()`](https://dplyr.tidyverse.org/reference/arrange.html),
joins, and
[`bind_rows()`](https://dplyr.tidyverse.org/reference/bind_rows.html)
keep the class.
[`group_by()`](https://dplyr.tidyverse.org/reference/group_by.html),
[`summarise()`](https://dplyr.tidyverse.org/reference/summarise.html)
with expressions,
[`as_tibble()`](https://tibble.tidyverse.org/reference/as_tibble.html),
`pivot_longer()`, and saving to and reading from a file drop it.
`as_le8_scores()` adds the class back to any data frame that still
contains the score columns. It does not rescore or change any values.

A data frame with an `.imp` column, such as saved results from
[`score_le8_imputed()`](https://thatoneguy006.github.io/essential8/reference/score_le8_imputed.md),
becomes an `essential8_imputed_scores` object, so its methods pool
across imputations again.

## Usage

``` r
as_le8_scores(x)
```

## Arguments

- x:

  A data frame containing the columns returned by
  [`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md):
  the eight component scores (`diet_score`, `physical_activity_score`,
  `nicotine_score`, `sleep_score`, `bmi_score`, `blood_lipids_score`,
  `blood_glucose_score`, and `blood_pressure_score`), `n_components`,
  `le8_composite_score`, `le8_category`, and `le8_population`.

## Value

`x`, with the class `essential8_scores` added, and
`essential8_imputed_scores` too when `x` has an `.imp` column.

## See also

[`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)

## Examples

``` r
scores <- score_le8(
  data.frame(age = 45, sleep_hours = 7.5, bmi = 24, bmi_profile = "general"),
  min_components = 2
)
#> Warning: ! Some LE8 components could not be calculated for any observations.
#> ✖ Diet
#> ✖ Physical activity
#> ✖ Nicotine exposure
#> ✖ Blood lipids
#> ✖ Blood glucose
#> ✖ Blood pressure
#> ℹ Overall LE8 composite scores will use the available components, subject to
#>   `min_components`.
plain <- as.data.frame(scores)
summary(as_le8_scores(plain))
#> LE8 scores: 1 row (1 adult)
#> Diet method: mepa; min_components: 2
#> Composite score available for 1 of 1; all 8 components for 0.
#> 
#>                   n  mean sd median         IQR       range
#> LE8 composite     1 100.0  -  100.0 100.0-100.0 100.0-100.0
#> Diet              0     -  -      -           -           -
#> Physical activity 0     -  -      -           -           -
#> Nicotine exposure 0     -  -      -           -           -
#> Sleep             1 100.0  -  100.0 100.0-100.0 100.0-100.0
#> BMI               1 100.0  -  100.0 100.0-100.0 100.0-100.0
#> Blood lipids      0     -  -      -           -           -
#> Blood glucose     0     -  -      -           -           -
#> Blood pressure    0     -  -      -           -           -
#> 
#> Category (rows with a composite score):
#>            n percent
#>   low      0    0.0%
#>   moderate 0    0.0%
#>   high     1  100.0%
```
