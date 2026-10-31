# Construct a reference for population diet scoring

Creates a small, method-specific reference for DASH or HEI-2015 indices,
including HEI-2015 totals calculated from raw inputs. Raw DASH with
custom definitions requires explicit `dash_cutpoints` in
[`score_le8()`](https://thatoneguy006.github.io/essential8/reference/score_le8.md)
to specify intake quintiles as well. The four values are index-score
cutpoints at the indicated percentiles, not percentiles themselves. No
observations are stored or ranked.

## Usage

``` r
diet_reference(
  p25,
  p50,
  p75,
  p95,
  method = "dash",
  label = NULL,
  source = NULL,
  score_range = NULL
)
```

## Arguments

- p25, p50, p75, p95:

  Single finite numeric cutpoints, in nondecreasing order.

- method:

  Either `"dash"` or `"hei2015"`, matched case-insensitively.

- label, source:

  Optional single nonempty strings describing the reference population
  and its source. These do not change scoring.

- score_range:

  Optional numeric vector of two finite bounds identifying the index's
  theoretical range. HEI-2015 always uses 0 to 100. DASH has multiple
  definitions, so a custom DASH reference has no implicit range.

## Value

An `essential8_diet_reference` object containing the method, cutpoints,
optional metadata, and index range. It identifies percentile bands, not
an exact continuous percentile distribution.

## Examples

``` r
ref <- diet_reference(40, 55, 65, 80, method = "hei2015",
                      label = "Synthetic example")
ref
#> Diet reference: hei2015 
#> Population: Synthetic example 
#> p25 p50 p75 p95 
#>  40  55  65  80 
```
