# Adult LE8 example fixture

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
