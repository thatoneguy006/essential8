#' Score Life's Essential 8 cardiovascular health
#'
#' @description
#' Computes the eight Life's Essential 8 (LE8) component scores and the
#' composite score using the American Heart Association's 2022 Presidential
#' Advisory. Rows aged 20 years or older are scored with the adult
#' definitions; rows aged 4 months to 19 years are scored with the pediatric
#' definitions. Component scores are calculated wherever sufficient inputs are
#' available, without imputing missing values.
#'
#' @param data A data frame with one row per person (or visit) and the input
#'   columns described below. Adults and children may be mixed.
#' @param diet_method A single diet-scoring method applied to every row in
#'   `data`: `"mepa"` (the default), `"dash"`, `"hei2015"`, or `"percentile"`.
#'   Values are matched case-insensitively. Score data that use different
#'   methods in separate calls.
#' @param mepa_columns `NULL`, or a named character vector mapping canonical
#'   MEPA fields to columns in `data`. The names are canonical fields (the 16
#'   screener items, `sex`, and `milk_source`) and the values are actual
#'   column names. Unmapped fields use their canonical names.
#' @param min_components A single integer from 1 to 8 specifying the minimum
#'   number of non-missing LE8 component scores required to calculate
#'   `le8_composite_score`. The default is 7. Available component scores are
#'   averaged without imputation, which treats a missing component as equal
#'   to the average of the others; observations below the threshold receive
#'   `NA_real_`. Pediatric data usually need a lower value; see
#'   *Pediatric scoring*. To account for missing inputs instead, use
#'   `impute`.
#' @param dash_columns,hei2015_columns `NULL`, or named character vectors
#'   mapping canonical DASH or HEI-2015 fields to columns in `data`. Unmapped
#'   fields default to the canonical name prefixed with `dash_` or `hei2015_`.
#'   Names and input column names are matched case-insensitively.
#' @param dash_cutpoints `NULL` to use the packaged DASH intake quintiles and
#'   total-score cutpoints, or a named list
#'   containing the eight canonical DASH fields and `total`. Each intake
#'   vector contains four nondecreasing reference quintile cutpoints (20th,
#'   40th, 60th, 80th percentiles), in the same units as the inputs. `total`
#'   contains four nondecreasing reference DASH-total cutpoints (25th, 50th,
#'   75th, 95th percentiles), each from 8 to 40. Tied cutpoints are allowed.
#'   Explicit cutpoints bypass `reference` and use inputs in their supplied
#'   units, without energy standardization, preserving existing calls.
#' @param hei2015_cutpoints `NULL` to use `reference`, or four
#'   nondecreasing reference HEI-2015-total cutpoints (25th, 50th, 75th, 95th
#'   percentiles), each from 0 to 100. Tied cutpoints are allowed.
#' @param impute Whether to multiply impute missing inputs before scoring:
#'   `FALSE` (the default), `TRUE` for the default settings, or
#'   [le8_imputation_control()] to set the number of imputations, a seed,
#'   auxiliary predictors, and other [mice::mice()] arguments. Requires the
#'   mice package and `diet_method = "mepa"`. See *Multiple imputation*.
#' @param reference `"nhanes_2015_2018"` (the default), or a method-matched
#'   [diet_reference()] object. Used for already-computed indices and raw
#'   intake scoring when explicit cutpoints are absent. Raw DASH requires the
#'   packaged reference's intake quintiles; for other DASH definitions, supply
#'   `dash_cutpoints`. Direct percentiles and explicit raw cutpoints bypass
#'   reference lookup.
#'   The built-in references describe nonpregnant adults aged 20+ with two
#'   reliable recalls; they are derived estimates, not AHA-published cutpoints,
#'   and are refused for pediatric rows.
#'
#' @section Diet scoring methods:
#' MEPA retains the individual assessment pathway. For population research,
#' `diet_method = "dash"` accepts an already-computed index in `dash`, and
#' `diet_method = "hei2015"` accepts an already-computed index in `hei2015`.
#' Either method alternatively accepts a percentile in `diet_value` (0 to 100).
#' Both methods also calculate raw totals from the intake fields below, using
#' the packaged reference by default. Raw HEI-2015 also accepts a custom
#' `diet_reference()`; raw DASH supports custom definitions via `dash_cutpoints`.
#' Do not supply both the index column and an observed percentile; an
#' entirely missing `diet_value` column is ignored. Data with no diet inputs
#' retain the package's usual missing-component behavior. Once raw scoring is
#' selected, every raw input column must be present (values may be missing);
#' an absent column is an error rather than a silently missing diet score.
#'
#' An index is compared with fixed reference cutpoints to identify its
#' percentile category. The package does not estimate an exact percentile
#' from four cutpoints, or rank the current cohort against itself. Specify
#' `reference = "nhanes_2015_2018"` explicitly in reproducible analyses.
#'
#' The built-in DASH reference is specifically the 8-to-40 Fung-style FPED
#' construction identified as `essential8_fung_fped_v1`; it requires matching
#' food definitions, pooled weighted intake quintiles, and tie handling.
#' Other DASH definitions need a custom reference. HEI-2015 indices must be
#' constructed using an appropriate established method; the built-in reference
#' uses individual scoring after averaging the same two recalls' constituents
#' and energy. It is not a usual-intake or population-ratio estimate. Both
#' references use NHANES 2015-2016 and 2017-2018, two-day dietary weights divided
#' by two, and the NHANES strata and PSU design. Detailed methodology, source
#' URLs, hashes, sample counts, and index definitions accompany the references
#' and the maintainer script `data-raw/build_diet_references.R` in the repository.
#'
#' Fractional inputs confined to 0-1 (other than endpoints alone) are rejected
#' as apparent proportions; supply percentile points, such as 95, not 0.95.
#' This safeguard also rejects a batch consisting only of genuine fractional
#' percentiles below 1. Values are never automatically multiplied by 100.
#'
#' Supply one input pathway per call: raw intake, a precomputed index, or a
#' percentile. Raw intake fields cannot be combined with a precomputed index
#' or observed percentile. Raw fields are food-group and nutrient summaries,
#' prepared before scoring; the function does not parse dietary-recall files.
#' See `vignette("population-diets")` for executable examples and units.
#'
#' @section Input columns:
#' The column names below are case-sensitive; a name that differs only by
#' case (for example `BMI`) is an error. MEPA, DASH, and HEI-2015 diet fields
#' are matched case-insensitively. A column whose values are all missing may
#' be logical `NA` (as `read.csv()` produces for a blank column). Columns that
#' only apply to adults or only to children are ignored for other rows.
#'
#' * `age`: Age in years; must be present, complete, and at least 4 months
#'   (1/3 year). Rows aged 20 or older are scored as adults.
#' * `age_months`: Optional age in months, used for the pediatric age bands
#'   when observed. It must fall within the same completed year as `age`.
#' * For `diet_method = "mepa"`, the 16 Table C screener-item columns named
#'   below and `sex` (or `female` when `sex` is absent). The same columns
#'   serve children; see *Pediatric input columns* for which items each age
#'   uses. The item names are matched exactly after case normalization. If any
#'   screener item is present, every field used at the ages in `data` is
#'   required (all 16 items and sex when any row is aged 6 or older); omitting
#'   every item leaves the diet component missing. Supply daily
#'   servings in `olive_oil`, `green_leafy_vegetables`, `other_vegetables`, and
#'   `whole_grains`; supply weekly servings or frequency in `berries`,
#'   `other_fruit`, `meat`, `fish`, `chicken`, `cheese`, `butter_cream`,
#'   `beans`, `sweets_and_pastries`, `nuts`, and `alcohol`; supply the number
#'   of times per week that fast-food meals are consumed in `fast_food`.
#'   Sex may be encoded as `"m"`/`"f"`, `"male"`/`"female"`, or `0`/`1`,
#'   where `0` is male and `1` is female. Character encodings are matched
#'   case-insensitively, and character `"0"`/`"1"` values are also accepted.
#'   A logical `female` column (`TRUE` for female) is also accepted.
#' * `dash` or `hei2015`: An already-computed index for the selected population
#'   diet method. HEI-2015 is bounded by 0 to 100. The built-in DASH reference
#'   requires its documented 8-to-40 definition; custom DASH references can
#'   specify other index ranges. These columns are unrelated to MEPA.
#' * For raw DASH scoring, supply daily intakes in `dash_fruits`,
#'   `dash_vegetables`, `dash_nuts_and_legumes`, `dash_whole_grains`,
#'   `dash_low_fat_dairy`, `dash_red_and_processed_meat`, and
#'   `dash_sweetened_beverages`; supply sodium in mg/day in `dash_sodium`.
#'   Canonical mapping fields omit the `dash_` prefix. Fruits include juice;
#'   vegetables exclude potatoes and legumes. Food groups and serving
#'   definitions must match the reference. With the packaged reference, also
#'   supply positive kcal/day in `dash_energy_kcal`; sodium is standardized to
#'   2,000 kcal before scoring. Other fields must use the FPED-derived units
#'   and definitions in `vignette("population-diets")`, including fruit cup
#'   equivalents, whole-grain ounce equivalents, and the specified vegetable,
#'   dairy, protein, and beverage conversions. With explicit `dash_cutpoints`,
#'   energy is not required and no standardization is applied.
#' * For raw HEI-2015 scoring, supply `hei2015_energy_kcal` (positive
#'   kcal/day, including alcohol); cup equivalents/day in
#'   `hei2015_total_fruits`, `hei2015_whole_fruits`,
#'   `hei2015_total_vegetables`, `hei2015_greens_and_beans`, and
#'   `hei2015_dairy`; ounce equivalents/day in `hei2015_whole_grains`,
#'   `hei2015_total_protein_foods`, `hei2015_seafood_and_plant_proteins`, and
#'   `hei2015_refined_grains`; grams/day in `hei2015_polyunsaturated_fat`,
#'   `hei2015_monounsaturated_fat`, and `hei2015_saturated_fat`; mg/day in
#'   `hei2015_sodium`; and teaspoon equivalents/day in `hei2015_added_sugars`.
#'   Canonical mapping fields omit the `hei2015_` prefix. Food-group totals
#'   must already include legumes in both vegetable and protein components
#'   as specified by HEI-2015. Total fruits include juice; whole fruits do not.
#' * `diet_value`: A direct percentile for `"dash"`, `"hei2015"`, or the
#'   backward-compatible generic `"percentile"` method. Supply a DASH or
#'   HEI-2015 percentile from 0 to 100, calculated against the relevant
#'   reference distribution. The function does not rank supplied rows against
#'   one another. If this column is absent or missing, the diet score is
#'   missing. MEPA and raw-intake calls require it to be absent
#'   or entirely missing.
#' * `moderate_activity_minutes` and `vigorous_activity_minutes`: Weekly
#'   minutes. For adults, each vigorous minute counts as two
#'   moderate-equivalent minutes; for children aged 6 to 19, every minute
#'   counts once.
#' * `smoking_status`: One of `"never"`, `"former"`, or `"current"`. See
#'   *Pediatric input columns* for the pediatric meaning.
#' * `years_since_quit`: Years since quitting combustible tobacco. This is
#'   used only for adults whose `smoking_status` is `"former"`.
#' * `current_inhaled_nds`: Whether an inhaled nicotine-delivery system is
#'   currently used.
#' * `secondhand_smoke_home`: Whether the person lives with an active indoor
#'   smoker.
#' * `sleep_hours`: Average hours of sleep per night (per 24 hours, including
#'   naps, for children aged 5 or younger).
#' * `bmi`: Adult body mass index in kg/m^2. Values below 18.5 are not scored
#'   because the AHA advisory defers to clinician judgment for underweight
#'   adults.
#' * `bmi_profile`: Either `"general"` or `"asian_pacific"` (adults). The
#'   function never infers a profile from race or ethnicity.
#' * `non_hdl_cholesterol`: Non-HDL cholesterol in mg/dL.
#' * `lipid_lowering_treatment`: Whether the lipid value is drug treated.
#' * `diabetes`: Whether diabetes has been diagnosed.
#' * `glucose_measure`: Either `"fasting_glucose"` or `"hba1c"`.
#' * `glucose_value`: Fasting glucose in mg/dL or HbA1c in percent, as named
#'   by `glucose_measure`. Diagnosed diabetes requires HbA1c. A record with no
#'   diabetes diagnosis but a value in the diagnostic diabetes range is
#'   rejected because the AHA scoring table does not assign that combination.
#' * `systolic_bp` and `diastolic_bp`: Blood pressure in mm Hg.
#' * `antihypertensive_treatment`: Whether the blood pressure is treated.
#'
#' Component input columns may contain missing values or be omitted. A
#' component score is `NA_real_` when its available inputs are insufficient.
#' Missing values are never imputed. A warning is emitted when an entire LE8
#' component cannot be calculated for any observation where AHA defines it.
#'
#' @section Pediatric scoring:
#' Rows aged 4 months to 19 years use the children column of Table 1 of the
#' advisory and the suggested rules for younger children in its Supplemental
#' Appendix 2:
#'
#' * Diet: MEPA (the adult 16-item screener and adult bands at ages 6-19; a
#'   10-item subset at 10 points per item at ages 2-5; a 6-item subset at
#'   ages 6-23 months), or population percentiles at ages 2-19. Not scored
#'   before 6 months.
#' * Physical activity: daily active play at ages 1-5; weekly moderate or
#'   vigorous minutes at ages 6-19. Not scored before 1 year.
#' * Nicotine exposure, sleep, BMI, blood lipids, and blood glucose: all
#'   pediatric ages, with age-appropriate sleep ranges, growth-chart BMI
#'   (weight-for-length or BMI percentile before age 2), and pediatric non-HDL
#'   cholesterol bands. Glucose uses the adult table.
#' * Blood pressure: AAP 2017 percentile categories at ages 1-12, adult bands
#'   at ages 13-19. Not scored before 1 year.
#'
#' Components AHA does not define at a row's age are `NA` and are not counted
#' toward `min_components`; a message notes any such inputs that were
#' supplied. AHA recommends averaging the components that are available and
#' appropriate for measurement in children (the NHANES analysis averaged as few
#' as three), so pediatric analyses usually set a lower `min_components`.
#' [add_pediatric_references()] can derive the growth-chart and
#' blood-pressure reference inputs. See `vignette("pediatric-scoring")`.
#'
#' Where the sources conflict, the package follows the more specific rule:
#' the supplement's 2-5 year diet rule (10 points per item) rather than the
#' Table 1 bands; and, for 6-23 month weight, the supplement's explicit 0-point worst state
#' (at or above the 99.7th percentile with rapid gain) rather than its
#' decrements, which would leave 25. Nineteen-year-olds use the 13-18 year
#' sleep range (8 to 10 hours), the last range AHA lists.
#'
#' @section Pediatric input columns:
#' * `smoking_status`: `"never"` (never tried any nicotine product),
#'   `"former"` (tried a nicotine product, but not within 30 days), or
#'   `"current"` (combustible use within 30 days). `current_inhaled_nds` is
#'   inhaled-NDS use within 30 days and caps the score at 25. Record
#'   `"never"` and `FALSE` for young children without exposure;
#'   `secondhand_smoke_home` applies at every age.
#' * `active_play_minutes`: Ages 1-5. Average daily minutes of active play of
#'   any intensity over 7 days.
#' * `bmi_percentile` and `bmi_percent_of_p95`: Ages 2-19. CDC BMI-for-age
#'   percentile (0-100) and BMI as a percentage of the 95th percentile (for
#'   example, 125). The latter is used only at or above the 95th percentile.
#'   Percentiles below the 5th are rejected because AHA defers to clinician
#'   judgment.
#' * `infant_weight_percentile` and `infant_weight_z_change`: Under age 2.
#'   WHO weight-for-length (or BMI-for-age) percentile, and the increase in
#'   the matching z-score since the prior routine visit (for example, since
#'   age 1 month). The change is required from 6 months; 0.67 or more counts
#'   as rapid weight gain.
#' * `systolic_bp_p90`, `systolic_bp_p95`, `diastolic_bp_p90`, and
#'   `diastolic_bp_p95`: Ages 1-12. The child's AAP 2017 90th and 95th
#'   blood-pressure percentiles in mm Hg for age, sex, and height.
#' * MEPA, ages 2-5: ten of the adult items. Vegetables are
#'   `green_leafy_vegetables + other_vegetables` (at least 2 per day) and
#'   fruit is `berries + other_fruit` (at least 14 per week, i.e. 2 per day);
#'   `whole_grains` (3+ per day), `olive_oil` (1+ per day), `fish` (1+ per
#'   week), `nuts` (4+ per week), `meat` (3 or fewer per week),
#'   `butter_cream` (3 or fewer per week), `sweets_and_pastries` (3 or fewer
#'   per week), and `fast_food` (2 or fewer per month, i.e. at most 24/52 per
#'   week). For children under 6, `sweets_and_pastries` should include
#'   sugar-sweetened beverages.
#' * MEPA, ages 6-23 months: vegetables and fruit as above (at least 1 per
#'   day before 12 months, 2 per day from 12 months), `whole_grains` (same
#'   thresholds), no sweets or sugar-sweetened beverages, no fast food, and
#'   `milk_source`: `"human"`, `"cow"`, `"formula"`, or `"other"`. Human milk
#'   meets the item before 12 months; human or cow's milk from 12 months.
#'
#' @section Optional clinical-judgment columns:
#' * `apply_lean_muscular_bmi_override`: A caller-adjudicated flag asserting
#'   that a lean, higher-muscle-mass adult in the general BMI profile has a BMI
#'   from 25 to less than 30 and should receive 100 BMI points. If absent, the
#'   standard BMI band is used. Not defined for children.
#' * `apply_sleep_apnea_penalty`: If `TRUE`, subtract 20 points for untreated
#'   or undertreated sleep apnea (adults or children). If absent, no
#'   discretionary penalty is applied.
#' * `apply_prediabetes_metformin_penalty`: A caller-adjudicated flag asserting
#'   that the person has a history of prediabetes, is taking metformin to
#'   prevent diabetes, is currently normoglycemic, and the clinician chose to
#'   apply the AHA's discretionary 20-point decrement. If absent, no
#'   discretionary penalty is applied.
#'
#' @section Source-constrained behavior:
#' The function derives the 0-to-16 MEPA total from the 16 raw screener
#' responses. Raw DASH scoring uses the eight-component Fung index: five food
#' groups receive 1 to 5 points by intake quintile; sodium, red/processed meat,
#' and sweetened beverages receive 5 to 1. Intakes equal to a quintile cutpoint
#' stay in the lower quintile. Their sum is `dash_total` (8 to 40).
#'
#' Raw HEI-2015 calls compute 13 density, fatty-acid-ratio, and energy-percentage
#' components with proportional scoring between the published standards.
#' Added sugars use 16 kcal per teaspoon equivalent; saturated fat uses
#' 9 kcal per gram. Scores are capped at each component's maximum. Their sum
#' is `hei2015_total` (0 to 100), which is distinct from the LE8 diet score.
#' With zero saturated fat and positive unsaturated fat, the fatty-acid
#' component receives 10 points; with all three fats zero it receives zero,
#' following the NCI scoring macro. Missing inputs are never treated as zero;
#' a total requires all of its diet components, regardless of `min_components`.
#'
#' Raw DASH and HEI-2015 totals are converted to LE8 scores of 0, 25, 50, 80,
#' or 100 using fixed reference total-score cutpoints. Equality enters the
#' higher LE8 band. Explicit cutpoints override the packaged reference and
#' must come from a suitable fixed reference population, using appropriate
#' survey weights and strata where applicable. Cutpoints are never inferred
#' from `data`. For references requiring
#' different cutpoints by stratum, score strata in separate calls. Alternatively,
#' `diet_method = "percentile"` accepts externally calculated DASH or HEI-2015
#' percentiles. The rows in `data` are never ranked against one another.
#'
#' The AHA table applies 20-point treatment decrements to blood-lipid and
#' blood-pressure scores. These components are floored at zero, consistent
#' with the AHA's 0-to-100 metric definition. Optional sleep-apnea and
#' prediabetes/metformin decrements are applied only through explicit flags.
#' Inputs are not rounded. The documented MEPA daily/weekly equivalences are
#' applied where the source question and criterion use different timeframes.
#' Combinations without a source-defined score, including simultaneous current
#' combustible smoking and current inhaled-NDS use, produce a structured error.
#'
#' Input errors inherit from `essential8_input_error` and `essential8_error`.
#' General and adult errors also carry `essential8_adult_input_error`, as in
#' earlier versions; pediatric-only errors carry
#' `essential8_pediatric_input_error`.
#'
#' @section Multiple imputation:
#' With `impute`, `score_le8()` fills in missing inputs with [mice::mice()]
#' several times, scores every completed data set, and returns them stacked.
#' The imputation:
#'
#' 1. checks the observed values, so data that cannot be scored stop before
#'    imputation;
#' 2. imputes an input only for participants whose age uses it (adult BMI is
#'    never imputed for a child, for example), predicting it from age, the
#'    other inputs available for the same participants, and any `auxiliary`
#'    columns;
#' 3. uses predictive mean matching for numeric inputs, so imputed values are
#'    always values observed in someone else, and logistic or multinomial
#'    regression for categorical inputs;
#' 4. never imputes a combination the AHA scoring rules do not score, such as
#'    diagnosed diabetes without an HbA1c, current smoking with current
#'    inhaled-NDS use, or a fasting glucose of 126 mg/dL or more without
#'    diagnosed diabetes.
#'
#' `min_components` then applies to each completed data set as usual.
#' [summary()][summary.essential8_imputed_scores()], dplyr
#' [summarise()][summarise.essential8_imputed_scores()], and `plot()` pool
#' the results across imputations with Rubin's rules. See
#' [le8_imputation_setup()] for the full rules, and to inspect or adjust them.
#'
#' Imputation assumes values are missing at random given the variables in the
#' imputation models; include the variables used in later analyses, such as
#' exposures and outcomes, with `le8_imputation_control(auxiliary = )`.
#'
#' @return
#' An `essential8_scores` object: `data`, with its original class (so tibbles
#' and grouped tibbles are returned as such) and columns, plus
#' `mepa_total` (items met on the age-appropriate MEPA screener: 0-16 from
#' age 6, 0-10 at ages 2-5, 0-6 at 6-23 months), `dash_total`, and
#' `hei2015_total` (missing unless calculated from the corresponding raw
#' inputs), `physical_activity_moderate_equivalent_minutes` (weekly minutes
#' used for adults and children aged 6+), the eight component scores
#' (`diet_score`, `physical_activity_score`, `nicotine_score`, `sleep_score`,
#' `bmi_score`, `blood_lipids_score`, `blood_glucose_score`, and
#' `blood_pressure_score`), `n_components`, `le8_composite_score`,
#' `le8_complete`, `le8_category`, and `le8_population` (`"adult"` or
#' `"pediatric"`). The component count reports how many
#' scores contributed to the composite score; `le8_complete` is `TRUE`
#' only when all eight components are available. Categories are `"low"` for
#' scores below 50, `"moderate"` for scores from 50 to less than 80, and
#' `"high"` for scores of at least 80. The category is missing when the
#' composite score is missing.
#' For raw DASH calls, the eight component scores (1 to 5 points each) are
#' also appended as `dash_<field>_score`; they sum to `dash_total`.
#' For raw HEI-2015 calls, the 13 component scores are also appended as
#' `hei2015_<component>_score`, including `fatty_acids` and `saturated_fats`.
#'
#' With `impute`, an `essential8_imputed_scores` object instead: the scored
#' completed data sets stacked, with the imputation number in `.imp` and the
#' row of `data` in `.id`. It is a data frame, or a tibble for tibble input
#' (ungrouped). The `mids` object from mice is kept as `attr(x, "mids")` for
#' diagnostics, for example `plot(attr(x, "mids"))` to check convergence.
#'
#' `data` must not already contain any of these output columns (compared
#' case-insensitively), or the `le8_`-prefixed component names used by
#' essential8 0.3.0 and earlier; rename or remove them first.
#'
#' The `essential8_scores` class adds [summary()][summary.essential8_scores()],
#' [tidy()][tidy.essential8_scores()], [plot()][plot.essential8_scores()], and
#' dplyr [summarise()][summarise.essential8_scores()] methods. See
#' [as_le8_scores()] for when the class is kept and how to restore it.
#'
#' @references
#' Lloyd-Jones DM, Allen NB, Anderson CAM, et al. (2022). Life's Essential 8:
#' Updating and Enhancing the American Heart Association's Construct of
#' Cardiovascular Health. *Circulation*, 146(5), e18-e43.
#' \doi{10.1161/CIR.0000000000001078}
#'
#' Lloyd-Jones DM, Ning H, Labarthe D, et al. (2022). Status of Cardiovascular
#' Health in US Adults and Children Using the American Heart Association's New
#' Life's Essential 8 Metrics. *Circulation*, 146(11), 822-835.
#' \doi{10.1161/CIRCULATIONAHA.122.060911}
#'
#' Flynn JT, Kaelber DC, Baker-Smith CM, et al. (2017). Clinical Practice
#' Guideline for Screening and Management of High Blood Pressure in Children
#' and Adolescents. *Pediatrics*, 140(3), e20171904.
#' \doi{10.1542/peds.2017-1904}
#'
#' Fung TT, Chiuve SE, McCullough ML, et al. (2008). Adherence to a DASH-Style
#' Diet and Risk of Coronary Heart Disease and Stroke in Women.
#' *Archives of Internal Medicine*, 168(7), 713-720.
#' \doi{10.1001/archinte.168.7.713}
#'
#' Krebs-Smith SM, Pannucci TE, Subar AF, et al. (2018). Update of the Healthy
#' Eating Index: HEI-2015. *Journal of the Academy of Nutrition and Dietetics*,
#' 118(9), 1591-1602. \doi{10.1016/j.jand.2018.05.021}
#' See also the National Cancer Institute's
#' \href{https://epi.grants.cancer.gov/hei/developing.html}{scoring standards}
#' and \href{https://epi.grants.cancer.gov/hei/hei-scoring-method.html}{algorithm}.
#'
#' @seealso [summary.essential8_scores()], [tidy.essential8_scores()], and
#'   [plot.essential8_scores()] to summarize, reshape, and plot the scores;
#'   [add_pediatric_references()] to derive pediatric growth-chart and
#'   blood-pressure inputs; [diet_reference()] for custom diet references.
#'
#' @examplesIf requireNamespace("dplyr", quietly = TRUE)
#' library(dplyr)
#'
#' patient <- tibble(
#'   id = "patient_1",
#'   age = 55,
#'   sex = "female",
#'   # Daily servings
#'   olive_oil = 2,
#'   green_leafy_vegetables = 1,
#'   other_vegetables = 2,
#'   whole_grains = 2,
#'   # Weekly servings
#'   berries = 3,
#'   other_fruit = 5,
#'   meat = 2,
#'   fish = 3,
#'   chicken = 2,
#'   cheese = 1,
#'   butter_cream = 1,
#'   beans = 3,
#'   sweets_and_pastries = 1,
#'   nuts = 4,
#'   alcohol = 4,
#'   # Fast-food meals per week
#'   fast_food = 0,
#'   moderate_activity_minutes = 90,
#'   vigorous_activity_minutes = 0,
#'   smoking_status = "former",
#'   years_since_quit = 6,
#'   current_inhaled_nds = FALSE,
#'   secondhand_smoke_home = FALSE,
#'   sleep_hours = 7.5,
#'   bmi = 27.5,
#'   bmi_profile = "general",
#'   non_hdl_cholesterol = 145,
#'   lipid_lowering_treatment = FALSE,
#'   diabetes = FALSE,
#'   glucose_measure = "fasting_glucose",
#'   glucose_value = 95,
#'   systolic_bp = 128,
#'   diastolic_bp = 78,
#'   antihypertensive_treatment = FALSE
#' )
#'
#' scores <- score_le8(patient, diet_method = "mepa")
#' select(scores, id, mepa_total, diet_score, le8_composite_score,
#'        le8_category)
#'
#' # A 4-year-old with the preschool diet screener and no laboratory values.
#' child <- tibble(
#'   id = "child_1",
#'   age = 4,
#'   # Ten MEPA items apply at ages 2-5; sweets include sugary drinks.
#'   green_leafy_vegetables = 1, other_vegetables = 1, # servings per day
#'   berries = 7, other_fruit = 14,                     # servings per week
#'   whole_grains = 2, olive_oil = 1,                   # servings per day
#'   sweets_and_pastries = 2, meat = 2, fish = 1,       # servings per week
#'   nuts = 2, butter_cream = 1,
#'   fast_food = 0.25,                                  # times per week
#'   active_play_minutes = 160,
#'   smoking_status = "never", current_inhaled_nds = FALSE,
#'   secondhand_smoke_home = FALSE,
#'   sleep_hours = 11,
#'   bmi_percentile = 60, bmi_percent_of_p95 = 85,
#'   systolic_bp = 98, diastolic_bp = 58,
#'   systolic_bp_p90 = 103, systolic_bp_p95 = 107,
#'   diastolic_bp_p90 = 63, diastolic_bp_p95 = 67,
#'   antihypertensive_treatment = FALSE
#' )
#'
#' child_scores <- score_le8(child, min_components = 5)
#' select(child_scores, id, mepa_total, ends_with("_score"), n_components)
#'
#' @examplesIf requireNamespace("mice", quietly = TRUE)
#'
#' # Multiply impute missing inputs, then pool the scores.
#' adults <- read.csv(system.file(
#'   "extdata", "le8-adult-example.csv", package = "essential8"
#' ))
#' adults <- adults[!startsWith(names(adults), "expected_")]
#' adults$non_hdl_cholesterol[c(2, 5)] <- NA
#'
#' imputed <- score_le8(adults, impute = le8_imputation_control(m = 5, seed = 1))
#' summary(imputed)
#' @export
score_le8 <- function(
  data,
  diet_method = "mepa",
  mepa_columns = NULL,
  min_components = 7L,
  dash_columns = NULL,
  dash_cutpoints = NULL,
  hei2015_columns = NULL,
  hei2015_cutpoints = NULL,
  reference = "nhanes_2015_2018",
  impute = FALSE
) {
  min_components <- .validate_min_components(min_components)
  diet_method <- .normalize_diet_method(diet_method)
  .check_diet_arguments(
    diet_method, mepa_columns, dash_columns, dash_cutpoints,
    hei2015_columns, hei2015_cutpoints
  )
  imputation <- .resolve_impute(impute)
  if (!is.null(imputation)) {
    return(.score_le8_with_imputation(
      data,
      control = imputation,
      score_args = list(
        diet_method = diet_method,
        mepa_columns = mepa_columns,
        min_components = min_components,
        reference = reference
      ),
      call = rlang::current_env()
    ))
  }

  original_data <- data
  input_columns <- names(data)
  data <- .prepare_le8_data(data, diet_method)
  age <- .le8_age(data)
  .check_le8_domains(data, age, diet_method)

  diet <- .score_le8_diet(
    data, age, diet_method, input_columns,
    mepa_columns = mepa_columns,
    dash_columns = dash_columns,
    dash_cutpoints = dash_cutpoints,
    hei2015_columns = hei2015_columns,
    hei2015_cutpoints = hei2015_cutpoints,
    reference = reference
  )

  scores <- data.frame(
    mepa_total = diet$mepa_total,
    dash_total = diet$dash_total,
    hei2015_total = diet$hei2015_total,
    physical_activity_moderate_equivalent_minutes = .le8_activity_minutes(data, age),
    diet_score = diet$score,
    physical_activity_score = .score_le8_physical_activity(data, age),
    nicotine_score = .score_le8_nicotine(data, age),
    sleep_score = .score_le8_sleep(data, age),
    bmi_score = .score_le8_bmi(data, age),
    blood_lipids_score = .score_le8_blood_lipids(data, age),
    blood_glucose_score = .score_le8_blood_glucose(data),
    blood_pressure_score = .score_le8_blood_pressure(data, age),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  if (!is.null(diet$components)) {
    scores <- cbind(scores, diet$components)
  }

  applicable <- .le8_applicable_components(age, diet_method)
  .inform_not_applicable(data, applicable)
  component_columns <- .le8_component_score_columns()
  for (column in component_columns) {
    scores[[column]][!applicable[, column]] <- NA_real_
  }

  scores <- .add_le8_composite(scores, min_components, applicable)
  scores$le8_category <- .le8_category(scores$le8_composite_score)
  scores$le8_population <- .le8_population_label(age)

  # Assign into the caller's object so tibbles, grouped tibbles, and
  # row names are preserved; the validated copy is only used internally.
  original_data[names(scores)] <- scores
  .new_le8_scores(
    original_data,
    diet_method = diet_method,
    min_components = min_components
  )
}

# Component dispatch -------------------------------------------------------------
#
# Each component is scored with both definitions and the row's population picks
# one. The scorers are vectorized and side-effect free, so this keeps the
# routing in one visible place.

.le8_activity_minutes <- function(data, age) {
  moderate <- data$moderate_activity_minutes
  vigorous <- data$vigorous_activity_minutes
  pediatric <- moderate + vigorous
  pediatric[!.pediatric_ages(age, 72, Inf)] <- NA_real_
  .by_population(age, adult = moderate + 2 * vigorous, pediatric = pediatric)
}

.score_le8_physical_activity <- function(data, age) {
  .by_population(
    age,
    adult = .score_adult_physical_activity(
      data$moderate_activity_minutes + 2 * data$vigorous_activity_minutes
    ),
    pediatric = .score_pediatric_physical_activity(
      weekly_minutes = data$moderate_activity_minutes +
        data$vigorous_activity_minutes,
      active_play_minutes = data$active_play_minutes,
      months = age$months
    )
  )
}

.score_le8_nicotine <- function(data, age) {
  smoking_status <- as.character(data$smoking_status)
  .by_population(
    age,
    adult = .score_adult_nicotine(
      smoking_status = smoking_status,
      years_since_quit = data$years_since_quit,
      current_inhaled_nds = data$current_inhaled_nds,
      secondhand_smoke_home = data$secondhand_smoke_home
    ),
    pediatric = .score_pediatric_nicotine(
      smoking_status = smoking_status,
      current_inhaled_nds = data$current_inhaled_nds,
      secondhand_smoke_home = data$secondhand_smoke_home
    )
  )
}

.score_le8_sleep <- function(data, age) {
  apnea_penalty <- .optional_flag(data, "apply_sleep_apnea_penalty")
  .by_population(
    age,
    adult = .score_adult_sleep(data$sleep_hours, apnea_penalty),
    pediatric = .score_pediatric_sleep(
      data$sleep_hours, age$months, apnea_penalty
    )
  )
}

.score_le8_bmi <- function(data, age) {
  .by_population(
    age,
    adult = .score_adult_bmi(
      bmi = data$bmi,
      profile = as.character(data$bmi_profile),
      apply_lean_muscular_override = .optional_flag(
        data, "apply_lean_muscular_bmi_override"
      )
    ),
    pediatric = .score_pediatric_bmi(
      bmi_percentile = data$bmi_percentile,
      bmi_percent_of_p95 = data$bmi_percent_of_p95,
      infant_weight_percentile = data$infant_weight_percentile,
      infant_weight_z_change = data$infant_weight_z_change,
      months = age$months
    )
  )
}

.score_le8_blood_lipids <- function(data, age) {
  non_hdl <- data$non_hdl_cholesterol
  treated <- data$lipid_lowering_treatment
  .by_population(
    age,
    adult = .score_adult_blood_lipids(non_hdl, treated),
    pediatric = .score_pediatric_blood_lipids(non_hdl, treated)
  )
}

.score_le8_blood_glucose <- function(data) {
  .score_adult_blood_glucose(
    diabetes = data$diabetes,
    measure = as.character(data$glucose_measure),
    value = data$glucose_value,
    apply_prevention_penalty = .optional_flag(
      data, "apply_prediabetes_metformin_penalty"
    )
  )
}

.score_le8_blood_pressure <- function(data, age) {
  .by_population(
    age,
    adult = .score_adult_blood_pressure(
      data$systolic_bp, data$diastolic_bp, data$antihypertensive_treatment
    ),
    pediatric = .score_pediatric_blood_pressure(
      systolic = data$systolic_bp,
      diastolic = data$diastolic_bp,
      systolic_p90 = data$systolic_bp_p90,
      systolic_p95 = data$systolic_bp_p95,
      diastolic_p90 = data$diastolic_bp_p90,
      diastolic_p95 = data$diastolic_bp_p95,
      treated = data$antihypertensive_treatment,
      months = age$months
    )
  )
}
