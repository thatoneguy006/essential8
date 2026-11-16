# Summarise LE8 scores with dplyr

With dplyr loaded, calling
[`summarise()`](https://dplyr.tidyverse.org/reference/summarise.html)
(or
[`summarize()`](https://dplyr.tidyverse.org/reference/summarise.html))
on scores from
[`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
*without* any summary expressions returns the statistics in
[summary()](https://thatoneguy006.github.io/essential8/reference/summary.essential8_scores.md)
as a data frame, one row per measure and group. Calls *with*
expressions, such as
`summarise(scores, mean = mean(le8_composite_score))`, are passed to
dplyr unchanged.

Groups come from `.by`, or from the grouping of a grouped tibble passed
to
[`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md).
Because
[`group_by()`](https://dplyr.tidyverse.org/reference/group_by.html)
drops the `essential8_scores` class, use `.by` for grouped summaries of
scored data, or restore the class with
[`as_le8_scores()`](https://thatoneguy006.github.io/essential8/reference/as_le8_scores.md).

## Usage

``` r
# S3 method for class 'essential8_scores'
summarise(.data, ..., .by = NULL, .groups = NULL)
```

## Arguments

- .data:

  An `essential8_scores` object returned by
  [`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md).

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

Without expressions, an ungrouped data frame of the same type as `.data`
(a tibble for tibble input) with the grouping columns, `measure` (a
factor: `composite`, then the eight components in AHA order), and the
statistics `n` (available scores), `n_missing`, `mean`, `sd`, `min`,
`q25`, `median`, `q75`, and `max`. With expressions, the result of
[`dplyr::summarise()`](https://dplyr.tidyverse.org/reference/summarise.html).

## See also

[`summary.essential8_scores()`](https://thatoneguy006.github.io/essential8/reference/summary.essential8_scores.md),
[`tidy.essential8_scores()`](https://thatoneguy006.github.io/essential8/reference/tidy.essential8_scores.md)

## Examples

``` r
library(dplyr)

adults <- read.csv(system.file(
  "extdata", "le8-adult-example.csv", package = "essential8"
))
scores <- adults |>
  select(!starts_with("expected_")) |>
  score_le8()

summarise(scores)
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
summarise(scores, .by = bmi_profile)
#>      bmi_profile           measure n n_missing     mean       sd    min     q25
#> 1        general         composite 7         0 44.28571 32.61883  0.000 25.0000
#> 2        general              diet 7         0 50.71429 43.82052  0.000 12.5000
#> 3        general physical_activity 7         0 52.85714 37.73340  0.000 30.0000
#> 4        general          nicotine 7         0 41.42857 35.20349  0.000 25.0000
#> 5        general             sleep 7         0 48.57143 38.48314  0.000 20.0000
#> 6        general               bmi 7         0 45.00000 35.70714  0.000 22.5000
#> 7        general      blood_lipids 7         0 37.14286 37.28909  0.000 10.0000
#> 8        general     blood_glucose 7         0 37.14286 34.01680  0.000 15.0000
#> 9        general    blood_pressure 7         0 41.42857 36.36783  0.000 17.5000
#> 10 asian_pacific         composite 3         0 54.37500 20.37730 33.125 44.6875
#> 11 asian_pacific              diet 3         0 51.66667 27.53785 25.000 37.5000
#> 12 asian_pacific physical_activity 3         0 76.66667 15.27525 60.000 70.0000
#> 13 asian_pacific          nicotine 3         0 36.66667 35.47299  5.000 17.5000
#> 14 asian_pacific             sleep 3         0 70.00000 30.00000 40.000 55.0000
#> 15 asian_pacific               bmi 3         0 50.00000 43.30127  0.000 37.5000
#> 16 asian_pacific      blood_lipids 3         0 40.00000 34.64102 20.000 20.0000
#> 17 asian_pacific     blood_glucose 3         0 66.66667 11.54701 60.000 60.0000
#> 18 asian_pacific    blood_pressure 3         0 43.33333 16.07275 25.000 37.5000
#>    median     q75    max
#> 1  44.375 57.8125 100.00
#> 2  50.000 90.0000 100.00
#> 3  40.000 85.0000 100.00
#> 4  30.000 55.0000 100.00
#> 5  40.000 80.0000 100.00
#> 6  30.000 70.0000 100.00
#> 7  20.000 60.0000 100.00
#> 8  30.000 50.0000 100.00
#> 9  30.000 62.5000 100.00
#> 10 56.250 65.0000  73.75
#> 11 50.000 65.0000  80.00
#> 12 80.000 85.0000  90.00
#> 13 30.000 52.5000  75.00
#> 14 70.000 85.0000 100.00
#> 15 75.000 75.0000  75.00
#> 16 20.000 50.0000  80.00
#> 17 60.000 70.0000  80.00
#> 18 50.000 52.5000  55.00

# Ordinary dplyr summaries work as usual.
summarise(scores, mean_le8 = mean(le8_composite_score), .by = bmi_profile)
#>     bmi_profile mean_le8
#> 1       general 44.28571
#> 2 asian_pacific 54.37500
```
