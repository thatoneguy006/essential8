# LE8 example fixtures

## Adults

`le8-adult-example.csv` contains 10 hypothetical adults with complete raw MEPA
and adult LE8 input data. It contains no observations from real people.

Columns beginning with `expected_` are literal, manually calculated
expectations derived from the adult AHA 2022 scoring table. They are not inputs
to `score_le8()`. This includes `expected_mepa_total`, the manually calculated
sum of the 16 raw screener criteria. The package tests remove those columns,
score the raw inputs, compare all eight component scores and the exact
composite with the literal expectations, and separately verify the fixture's
component-sum arithmetic.

Rows exercising a discretionary AHA rule use an explicit `apply_` flag. A
`TRUE` value asserts that the caller has already adjudicated every clinical
condition named by that flag; the package does not infer those conditions.

## Children and mixed ages

`le8-pediatric-example.csv` contains 10 hypothetical people aged 5 months to
20 years: one row for each pediatric age band (infant, toddler, preschool,
school age, adolescent, and a 19-year-old), one adult at the 20-year
boundary, and the AHA's own worked pediatric example (Supplemental
Appendix 3, Example 2: a 16-year-old with a composite of 470/7). It contains
no observations from real people.

As in the adult fixture, `expected_` columns are literal hand calculations
from the children column of Table 1 and Supplemental Appendix 2 of the 2022
advisory. Blank (`NA`) expectations mark components that are missing or that
AHA does not define at that age. The package tests score the file with
`min_components = 3`.
