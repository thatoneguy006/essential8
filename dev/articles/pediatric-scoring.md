# Scoring children

[`score_le8()`](https://thatoneguy006.github.io/essential8/dev/reference/score_le8.md)
scores children aged 4 months to 19 years with the pediatric Life’s
Essential 8 (LE8) definitions from the American Heart Association’s 2022
advisory: the children column of its Table 1, and the suggestions for
younger children in its Supplemental Appendix 2. Adults and children can
be scored in the same call; each row’s `age` chooses the definitions,
and `le8_population` records which were used.

This article covers what changes for children, which inputs to supply,
and how to derive growth-chart and blood-pressure percentiles.

``` r

library(essential8)
library(dplyr)
```

## What changes for children

Each component uses an age-appropriate rule. Some are defined only from
a certain age; before then, the component is `NA` and does not count
toward `min_components`.

| Component | Pediatric rule | Ages scored |
|----|----|----|
| Diet | MEPA from the same columns as adults: 6 items (6-23 months), 10 items (2-5 years), all 16 (6-19 years); or population percentiles | 6 months+ (percentiles: 2 years+) |
| Physical activity | Daily active play (1-5 years); weekly moderate or vigorous minutes, not doubled (6-19 years) | 1 year+ |
| Nicotine exposure | Never tried, tried over 30 days ago, current inhaled NDS, current combustible; secondhand smoke at any age | All |
| Sleep | Distance from the age-appropriate range (12-16 h at 4-11 months to 8-10 h at 13-19 years) | All |
| BMI | WHO weight-for-length percentile and rapid gain (under 2); CDC BMI percentile and % of 95th percentile (2-19 years) | All |
| Blood lipids | Pediatric non-HDL bands (\<100, 100-119, 120-144, 145-189, 190+ mg/dL) | All |
| Blood glucose | Same as adults | All |
| Blood pressure | AAP 2017 percentile categories (1-12 years); adult bands (13-19 years) | 1 year+ |

AHA suggests that the composite for a child be the average of whatever
components are available and appropriate for measurement. Laboratory
values are often unavailable in children, and the NHANES analysis that
accompanied the advisory averaged as few as three components, so
pediatric analyses usually set `min_components` below the default of 7.

## A preschool child

Children use the same MEPA columns as adults. At ages 2-5, ten of the
items are scored, at 10 points per item met, with child-sized
thresholds:

- vegetables: `green_leafy_vegetables + other_vegetables`, 2+ per day
- fruit: `berries + other_fruit`, 14+ per week (2 per day)
- `whole_grains` 3+ and `olive_oil` 1+ per day
- `fish` 1+ and `nuts` 4+ per week
- `meat`, `butter_cream`, and `sweets_and_pastries` 3 or fewer per week;
  for children under 6, sweets should include sugar-sweetened beverages
- `fast_food` 2 or fewer times per month (at most 24/52 per week)

`chicken`, `cheese`, `beans`, `alcohol`, and `sex` are not used before
age 6 and may be omitted from data containing only young children.

The example also uses active play in minutes per day and blood-pressure
percentiles. The 90th and 95th percentiles (`systolic_bp_p90` and so on)
are the child’s reference values for age, sex, and height, in mm Hg.

``` r

preschooler <- tibble(
  id = "preschooler",
  age = 4,
  # Servings per day
  green_leafy_vegetables = 1,
  other_vegetables = 1,
  whole_grains = 2,
  olive_oil = 1,
  # Servings per week
  berries = 7,
  other_fruit = 14,
  sweets_and_pastries = 2,
  meat = 2,
  fish = 1,
  nuts = 2,
  butter_cream = 1,
  # Times per week
  fast_food = 0.25,
  active_play_minutes = 160,
  smoking_status = "never",
  current_inhaled_nds = FALSE,
  secondhand_smoke_home = FALSE,
  sleep_hours = 13.5,
  bmi_percentile = 60,
  bmi_percent_of_p95 = 82,
  systolic_bp = 108,
  diastolic_bp = 60,
  systolic_bp_p90 = 103,
  systolic_bp_p95 = 107,
  diastolic_bp_p90 = 63,
  diastolic_bp_p95 = 67,
  antihypertensive_treatment = FALSE
)

preschooler |>
  score_le8(min_components = 5) |>
  select(mepa_total, starts_with("le8_"))
#> Warning: ! Some LE8 components could not be calculated for any observations.
#> ✖ Blood lipids
#> ✖ Blood glucose
#> ℹ Overall LE8 composite scores will use the available components, subject to
#>   `min_components`.
#> # A tibble: 1 × 14
#>   mepa_total le8_diet_score le8_physical_activity_score le8_nicotine_score
#>        <int>          <dbl>                       <dbl>              <dbl>
#> 1          8             80                          90                100
#> # ℹ 10 more variables: le8_sleep_score <dbl>, le8_bmi_score <dbl>,
#> #   le8_blood_lipids_score <dbl>, le8_blood_glucose_score <dbl>,
#> #   le8_blood_pressure_score <dbl>, le8_n_components <int>,
#> #   le8_composite_score <dbl>, le8_complete <lgl>, le8_category <chr>,
#> #   le8_population <chr>
```

Eight of the ten items are met (80 points); `mepa_total` counts items
met on the screener for the child’s age. Sleep is half an hour above the
10-13 hour range (90 points). The systolic pressure of 108 mm Hg is at
or above this child’s 95th percentile (107 mm Hg) but below 95th + 12 mm
Hg, which is stage 1 (50 points). Lipids and glucose were not measured,
so the composite averages six components; the warning says so.

## Infants and toddlers

From 6 to 23 months, diet uses six items: vegetables, fruit, and whole
grains (at least once a day before 12 months, twice a day from 12
months), no sweets or sugar-sweetened beverages, no fast food, and the
milk source recommended for age. `milk_source` is the one column used
only at these ages: `"human"`, `"cow"`, `"formula"`, or `"other"`. Human
milk meets the item before 12 months, and human or cow’s milk from 12
months.

Weight uses the WHO weight-for-length (or BMI-for-age) percentile
together with the change in its z-score since the prior routine visit.
An increase of 0.67 or more counts as rapid weight gain.

``` r

infant <- tibble(
  id = "infant",
  age = 0.75,
  age_months = 9,
  green_leafy_vegetables = 0.5,
  other_vegetables = 0.5,
  berries = 3,
  other_fruit = 4,
  whole_grains = 1,
  sweets_and_pastries = 0,
  fast_food = 0,
  milk_source = "human",
  smoking_status = "never",
  current_inhaled_nds = FALSE,
  secondhand_smoke_home = TRUE,
  sleep_hours = 13,
  infant_weight_percentile = 98.5,
  infant_weight_z_change = 0.4
)

infant |>
  score_le8(min_components = 4) |>
  select(mepa_total, starts_with("le8_"))
#> Warning: ! Some LE8 components could not be calculated for any observations.
#> ✖ Blood lipids
#> ✖ Blood glucose
#> ℹ Overall LE8 composite scores will use the available components, subject to
#>   `min_components`.
#> # A tibble: 1 × 14
#>   mepa_total le8_diet_score le8_physical_activity_score le8_nicotine_score
#>        <int>          <dbl>                       <dbl>              <dbl>
#> 1          6            100                          NA                 80
#> # ℹ 10 more variables: le8_sleep_score <dbl>, le8_bmi_score <dbl>,
#> #   le8_blood_lipids_score <dbl>, le8_blood_glucose_score <dbl>,
#> #   le8_blood_pressure_score <dbl>, le8_n_components <int>,
#> #   le8_composite_score <dbl>, le8_complete <lgl>, le8_category <chr>,
#> #   le8_population <chr>
```

`age_months` is optional; when supplied it sets the pediatric age bands
more precisely than `age * 12`. Physical activity and blood pressure are
not scored before age 1, so they are `NA` here regardless of the inputs.

## School-age children and adolescents

From age 6, diet uses all 16 MEPA items and the adult bands, so `sex`
(for the alcohol item) is needed from this age. Weekly moderate and
vigorous minutes count once each (adults count vigorous minutes twice).
The pediatric nicotine categories describe any nicotine product:
`"never"` means never tried, `"former"` means tried but not within 30
days, and `"current"` means combustible use within 30 days. Blood
pressure switches to the adult bands at 13, while the other components
stay pediatric through age 19.

## Deriving growth-chart and blood-pressure percentiles

[`add_pediatric_references()`](https://thatoneguy006.github.io/essential8/dev/reference/add_pediatric_references.md)
derives the percentile inputs from raw measurements, using the suggested
packages [cdcanthro](https://CRAN.R-project.org/package=cdcanthro) (CDC
and WHO growth charts) and
[pedbp](https://CRAN.R-project.org/package=pedbp) (AAP 2017
blood-pressure percentiles). It needs sex, height, and weight, and uses
`age_months` or `age * 12`.

``` r

measurements <- tibble(
  id = c("toddler", "school_age", "teen"),
  age = c(1.5, 8.25, 15.5),
  sex = c("male", "female", "male"),
  height_cm = c(82, 128, 172),
  weight_kg = c(11.5, 27, 64)
)

measurements |>
  add_pediatric_references() |>
  select(id, bmi_percentile, bmi_percent_of_p95, infant_weight_percentile,
         systolic_bp_p90, systolic_bp_p95)
#> # A tibble: 3 × 6
#>   id    bmi_percentile bmi_percent_of_p95 infant_weight_percen…¹ systolic_bp_p90
#>   <chr>          <dbl>              <dbl>                  <dbl>           <dbl>
#> 1 todd…           NA                 NA                     76.3            99.7
#> 2 scho…           60.9               78.8                   NA             110. 
#> 3 teen            68.5               79.6                   NA              NA  
#> # ℹ abbreviated name: ¹​infant_weight_percentile
#> # ℹ 1 more variable: systolic_bp_p95 <dbl>
```

Blood-pressure references are returned only for ages 1 to 12, and only
when height is known: without height, pedbp would assume a median-height
child, which is a form of imputation the package avoids.

Rapid infant weight gain compares visits, so it cannot be derived from
one row. With longitudinal data, compute it from `infant_weight_z`
within each child:

``` r

visits |>
  add_pediatric_references() |>
  arrange(child_id, age) |>
  mutate(
    infant_weight_z_change = infant_weight_z - lag(infant_weight_z),
    .by = child_id
  )
```

AHA compares against the z-score at prior routine visits, for example
since age 1 month; choose the comparison visit to match your study
design.

## Where the sources conflict

The advisory’s main table and its supplement are not always consistent.
The package follows the more specific rule and documents each choice in
[`?score_le8`](https://thatoneguy006.github.io/essential8/dev/reference/score_le8.md):

- Ages 2-5 use the supplement’s 10 points per item met rather than Table
  1’s banded 0-10 scale (for example, 7 items score 70 rather than 80).
- The supplement calls the 16-item MEPA the screener “used in older
  children and adults”, so ages 6-19 use it with the adult bands.
- At 6-23 months, weight at or above the 99.7th percentile with rapid
  gain scores 0, the supplement’s explicit worst state, rather than the
  25 its listed decrements would give.
- Nineteen-year-olds use the 13-18 year sleep range (8-10 hours), the
  last range AHA lists for the pediatric column.
- The packaged NHANES diet references describe adults, so they are
  refused for children. Use percentiles in `diet_value` or a pediatric
  reference.
