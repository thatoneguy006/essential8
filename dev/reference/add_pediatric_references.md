# Add pediatric growth-chart and blood-pressure reference values

Derives the reference inputs that
[`score_le8()`](https://thatoneguy006.github.io/essential8/dev/reference/score_le8.md)
needs for pediatric BMI and blood-pressure scoring from raw
measurements:

- `bmi_percentile` and `bmi_percent_of_p95` (ages 2 to 19): CDC 2000
  BMI-for-age percentile, using the CDC extended BMI method above the
  95th percentile, and BMI as a percentage of the 95th percentile, from
  [`cdcanthro::cdc_z()`](https://rdrr.io/pkg/cdcanthro/man/cdc_z.html).

- `infant_weight_z` and `infant_weight_percentile` (under age 2): WHO
  weight-for-length (or BMI-for-age) z-score and percentile, from
  [`cdcanthro::who_z()`](https://rdrr.io/pkg/cdcanthro/man/who_z.html).

- `systolic_bp_p90`, `systolic_bp_p95`, `diastolic_bp_p90`, and
  `diastolic_bp_p95` (ages 1 to 12): the AAP 2017 (Flynn et al.) 90th
  and 95th blood-pressure percentiles for the child's age, sex, and
  height, from
  [`pedbp::q_bp()`](http://www.peteredewitt.com/pedbp/reference/bp_distribution.md).

Requires the suggested packages cdcanthro (for growth charts) and pedbp
(for blood pressure); each is needed only when `data` contains rows of
the corresponding ages. Values are left missing outside the stated ages
and wherever a required measurement is missing. In particular, the
blood-pressure references are not computed without height: pedbp would
otherwise assume a median-height child.

`infant_weight_z_change`, the change in the infant z-score since the
prior routine visit, needs longitudinal data and is not derived here.
Compute it from `infant_weight_z` within each child; see
[`vignette("pediatric-scoring")`](https://thatoneguy006.github.io/essential8/dev/articles/pediatric-scoring.md).

## Usage

``` r
add_pediatric_references(
  data,
  sex = "sex",
  height = "height_cm",
  weight = "weight_kg",
  bmi = NULL,
  age_months = NULL,
  completed_months = FALSE,
  infant_measure = c("weight_for_length", "bmi_for_age"),
  bp_source = "flynn2017"
)
```

## Arguments

- data:

  A data frame. Rows aged 20 or older are returned unchanged.

- sex:

  Name of the sex column: `"m"`/`"f"`, `"male"`/`"female"`, or `0`/`1`
  (0 = male), or a logical column named `female`.

- height:

  Name of the column holding height in cm (recumbent length before age
  2).

- weight:

  Name of the column holding weight in kg.

- bmi:

  Optional name of a BMI column in kg/m^2. When `NULL` (the default),
  BMI is calculated from `weight` and `height`.

- age_months:

  Optional name of a column holding age in months. When `NULL`,
  `age_months` is used if present, otherwise `age * 12`.

- completed_months:

  If `FALSE` (the default), ages are exact, so 54 months means exactly
  4.5 years. If `TRUE`, ages are completed months (as in NHANES) and 0.5
  is added before every reference lookup. Unlike calling cdcanthro
  directly, whose midpoint adjustment depends on whether every age in
  the batch is a whole number, the result for one row never depends on
  the other rows.

- infant_measure:

  Under age 2, `"weight_for_length"` (the default, the more common
  clinical measure) or `"bmi_for_age"`; AHA 2022 accepts either.

- bp_source:

  The pedbp blood-pressure reference. The default, `"flynn2017"`, is the
  AAP 2017 guideline that LE8 cites.

## Value

`data`, with the eight reference columns described above appended. It is
an error for `data` to contain any of them already.

## References

Lloyd-Jones DM, Allen NB, Anderson CAM, et al. (2022). Life's Essential
8. *Circulation*, 146(5), e18-e43.
[doi:10.1161/CIR.0000000000001078](https://doi.org/10.1161/CIR.0000000000001078)

Flynn JT, Kaelber DC, Baker-Smith CM, et al. (2017). Clinical Practice
Guideline for Screening and Management of High Blood Pressure in
Children and Adolescents. *Pediatrics*, 140(3), e20171904.
[doi:10.1542/peds.2017-1904](https://doi.org/10.1542/peds.2017-1904)

Wei R, Ogden CL, Parsons VL, Freedman DS, Hales CM (2020). A method for
calculating BMI z-scores and percentiles above the 95th percentile of
the CDC growth charts. *Annals of Human Biology*, 47(6), 514-521.
[doi:10.1080/03014460.2020.1808065](https://doi.org/10.1080/03014460.2020.1808065)

## See also

[`score_le8()`](https://thatoneguy006.github.io/essential8/dev/reference/score_le8.md)

## Examples

``` r
children <- data.frame(
  id = c("a", "b"),
  age = c(5.5, 14),
  sex = c("female", "male"),
  height_cm = c(112, 165),
  weight_kg = c(19, 70)
)
add_pediatric_references(children)
#>   id  age    sex height_cm weight_kg bmi_percentile bmi_percent_of_p95
#> 1  a  5.5 female       112        19       49.65858           81.93710
#> 2  b 14.0   male       165        70       94.53158           98.84544
#>   infant_weight_z infant_weight_percentile systolic_bp_p90 systolic_bp_p95
#> 1              NA                       NA        106.7036        110.5857
#> 2              NA                       NA              NA              NA
#>   diastolic_bp_p90 diastolic_bp_p95
#> 1         67.15812         70.60702
#> 2               NA               NA
```
