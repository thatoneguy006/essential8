#' Summarize LE8 scores
#'
#' @description
#' Summarizes the composite and component scores returned by [score_le8()]:
#' how many rows were scored, the distribution of each score, and the
#' cardiovascular health categories. Grouping is ignored; use
#' [summarise()][summarise.essential8_scores()] for summaries by group.
#'
#' @param object An `essential8_scores` object returned by [score_le8()].
#' @param x A `summary.essential8_scores` object.
#' @param digits Number of decimal places to print.
#' @param ... Not used.
#' @return `summary()` returns a `summary.essential8_scores` object, a list
#'   with:
#'   * `n`: the number of rows.
#'   * `population`: the number of adult and pediatric rows.
#'   * `n_composite`: rows with a composite score.
#'   * `n_complete`: rows with all eight component scores.
#'   * `statistics`: a data frame with one row per measure (the composite and
#'     each component) and the columns `measure`, `n` (available scores),
#'     `n_missing`, `mean`, `sd`, `min`, `q25`, `median`, `q75`, and `max`.
#'   * `categories`: a data frame with the count and percentage of rows in
#'     each category among rows with a composite score.
#'   * `settings`: the `diet_method` and `min_components` used for scoring,
#'     or `NULL` when unknown (for example, after [as_le8_scores()], or after
#'     dplyr verbs on a plain data frame, which drop custom attributes).
#'
#'   `print()` returns `x` invisibly.
#' @seealso [tidy.essential8_scores()], [summarise.essential8_scores()],
#'   [plot.essential8_scores()]
#' @examples
#' adults <- read.csv(system.file(
#'   "extdata", "le8-adult-example.csv", package = "essential8"
#' ))
#' adults <- adults[!startsWith(names(adults), "expected_")]
#' scores <- score_le8(adults)
#' summary(scores)
#'
#' # The statistics are also available as a data frame.
#' summary(scores)$statistics
#' @export
summary.essential8_scores <- function(object, ...) {
  .check_le8_scores(object, call = rlang::current_env())
  data <- as.data.frame(object)

  categories <- factor(data$le8_category, levels = .le8_category_levels())
  category_counts <- as.vector(table(categories))
  n_composite <- sum(!is.na(data$le8_composite_score))

  structure(
    list(
      n = nrow(data),
      population = c(
        adult = sum(data$le8_population == "adult", na.rm = TRUE),
        pediatric = sum(data$le8_population == "pediatric", na.rm = TRUE)
      ),
      n_composite = n_composite,
      n_complete = sum(data$n_components == 8L, na.rm = TRUE),
      statistics = .le8_measure_stats(data),
      categories = data.frame(
        category = factor(
          .le8_category_levels(),
          levels = .le8_category_levels()
        ),
        n = category_counts,
        percent = if (n_composite > 0L) {
          100 * category_counts / n_composite
        } else {
          NA_real_
        }
      ),
      settings = attr(object, "essential8_settings")
    ),
    class = "summary.essential8_scores"
  )
}

#' @rdname summary.essential8_scores
#' @export
print.summary.essential8_scores <- function(x, digits = 1, ...) {
  population <- x$population[x$population > 0L]
  cat(
    "LE8 scores: ", x$n, " row", if (x$n != 1L) "s",
    if (length(population) > 0L) {
      paste0(" (", paste(population, names(population), collapse = ", "), ")")
    },
    "\n",
    sep = ""
  )
  if (!is.null(x$settings)) {
    cat(
      "Diet method: ", x$settings$diet_method,
      "; min_components: ", x$settings$min_components, "\n",
      sep = ""
    )
  }
  cat(
    "Composite score available for ", x$n_composite, " of ", x$n,
    "; all 8 components for ", x$n_complete, ".\n\n",
    sep = ""
  )

  stats <- x$statistics
  number <- function(value) {
    out <- formatC(value, format = "f", digits = digits)
    out[is.na(value)] <- "-"
    out
  }
  span <- function(lower, upper) {
    out <- paste0(number(lower), "-", number(upper))
    out[is.na(lower)] <- "-"
    out
  }
  table <- data.frame(
    n = stats$n,
    mean = number(stats$mean),
    sd = number(stats$sd),
    median = number(stats$median),
    IQR = span(stats$q25, stats$q75),
    range = span(stats$min, stats$max),
    row.names = .le8_measure_labels()[as.character(stats$measure)],
    check.names = FALSE
  )
  print(table, right = TRUE)

  if (x$n_composite > 0L) {
    cat("\nCategory (rows with a composite score):\n")
    categories <- x$categories
    print(
      data.frame(
        n = categories$n,
        percent = paste0(number(categories$percent), "%"),
        row.names = paste0("  ", categories$category)
      ),
      right = TRUE
    )
  }
  invisible(x)
}

#' Summarise LE8 scores with dplyr
#'
#' @description
#' With dplyr loaded, calling `summarise()` (or `summarize()`) on scores from
#' [score_le8()] *without* any summary expressions returns the statistics in
#' [summary()][summary.essential8_scores()] as a data frame, one row per
#' measure and group. Calls *with* expressions, such as
#' `summarise(scores, mean = mean(le8_composite_score))`, are passed to
#' dplyr unchanged.
#'
#' Groups come from `.by`, or from the grouping of a grouped tibble passed to
#' [score_le8()]. Because `group_by()` drops the `essential8_scores` class,
#' use `.by` for grouped summaries of scored data, or restore the class with
#' [as_le8_scores()].
#'
#' @param .data An `essential8_scores` object returned by [score_le8()].
#' @param ... Summary expressions. If any are supplied, the call is handled by
#'   [dplyr::summarise()].
#' @param .by <[`tidy-select`][dplyr::dplyr_tidy_select]> Optional columns to
#'   group by for this summary.
#' @param .groups Passed to [dplyr::summarise()] when `...` is supplied.
#'   Otherwise ignored; the LE8 summary is always ungrouped.
#' @return Without expressions, an ungrouped data frame of the same type as
#'   `.data` (a tibble for tibble input) with the grouping columns, `measure`
#'   (a factor: `composite`, then the eight components in AHA order), and the
#'   statistics `n` (available scores), `n_missing`, `mean`, `sd`, `min`,
#'   `q25`, `median`, `q75`, and `max`. With expressions, the result of
#'   [dplyr::summarise()].
#' @seealso [summary.essential8_scores()], [tidy.essential8_scores()]
#' @examplesIf requireNamespace("dplyr", quietly = TRUE)
#' library(dplyr)
#'
#' adults <- read.csv(system.file(
#'   "extdata", "le8-adult-example.csv", package = "essential8"
#' ))
#' scores <- adults |>
#'   select(!starts_with("expected_")) |>
#'   score_le8()
#'
#' summarise(scores)
#' summarise(scores, .by = bmi_profile)
#'
#' # Ordinary dplyr summaries work as usual.
#' summarise(scores, mean_le8 = mean(le8_composite_score), .by = bmi_profile)
#' @exportS3Method dplyr::summarise
summarise.essential8_scores <- function(.data, ..., .by = NULL, .groups = NULL) {
  if (...length() > 0L) {
    # Forward explicitly: NextMethod() would hand dplyr this method's `.by`
    # promise rather than the caller's expression, breaking tidy selection.
    return(dplyr::summarise(
      .drop_le8_scores_class(.data),
      ...,
      .by = {{ .by }},
      .groups = .groups
    ))
  }
  .check_le8_scores(.data, call = rlang::current_env())
  columns <- names(.le8_measure_keys())
  dplyr::reframe(
    .drop_le8_scores_class(.data),
    .le8_measure_stats(dplyr::pick(dplyr::all_of(columns))),
    .by = {{ .by }}
  )
}

#' Summarize multiply imputed LE8 scores
#'
#' @description
#' Pools the scores from `score_le8(impute = TRUE)` or [score_le8_imputed()]
#' across imputations with
#' Rubin's rules. Means and category percentages get pooled confidence
#' intervals and the fraction of missing information; standard deviations
#' and quantiles are averaged across imputations. Counts are per participant
#' (averaged across imputations), not per stacked row.
#'
#' @param object An `essential8_imputed_scores` object from
#'   [score_le8_imputed()].
#' @param x A `summary.essential8_imputed_scores` object.
#' @param conf_level Confidence level for the pooled intervals.
#' @param digits Number of decimal places to print.
#' @param ... Not used.
#' @return `summary()` returns a `summary.essential8_imputed_scores` object, a
#'   list with `n` (participants), `m` (imputations), `population`,
#'   `n_composite`, `n_complete`, `statistics` (one row per measure with `n`,
#'   `n_missing`, pooled `mean`, `std.error`, `conf.low`, `conf.high`, `df`,
#'   and `fmi`, and averaged `sd`, `min`, `q25`, `median`, `q75`, and `max`),
#'   `categories` (pooled percentages with confidence intervals),
#'   `conf_level`, and `settings`. `print()` returns `x` invisibly.
#' @seealso [score_le8_imputed()], [summary.essential8_scores()]
#' @examplesIf requireNamespace("mice", quietly = TRUE)
#' adults <- read.csv(system.file(
#'   "extdata", "le8-adult-example.csv", package = "essential8"
#' ))
#' adults <- adults[!startsWith(names(adults), "expected_")]
#' adults$non_hdl_cholesterol[c(2, 5)] <- NA
#'
#' scores <- score_le8(
#'   adults,
#'   impute = le8_imputation_control(m = 5, seed = 1)
#' )
#' summary(scores)
#' summary(scores)$statistics
#' @export
summary.essential8_imputed_scores <- function(object, conf_level = 0.95, ...) {
  .check_le8_scores(object, call = rlang::current_env())
  m <- .check_le8_imputations(object, call = rlang::current_env())
  data <- as.data.frame(object)
  per_imputation <- function(f) mean(vapply(split(data, data$.imp), f, numeric(1)))

  structure(
    list(
      n = nrow(data) / m,
      m = m,
      population = c(
        adult = sum(data$le8_population == "adult", na.rm = TRUE) / m,
        pediatric = sum(data$le8_population == "pediatric", na.rm = TRUE) / m
      ),
      n_composite = per_imputation(function(d) sum(!is.na(d$le8_composite_score))),
      n_complete = per_imputation(function(d) sum(d$n_components == 8L, na.rm = TRUE)),
      statistics = .le8_pooled_measure_stats(data, conf_level = conf_level),
      categories = .le8_pooled_categories(data, conf_level = conf_level),
      conf_level = conf_level,
      settings = attr(object, "essential8_settings")
    ),
    class = "summary.essential8_imputed_scores"
  )
}

#' @rdname summary.essential8_imputed_scores
#' @export
print.summary.essential8_imputed_scores <- function(x, digits = 1, ...) {
  number <- function(value, places = digits) {
    out <- formatC(value, format = "f", digits = places)
    out[is.na(value)] <- "-"
    out
  }
  count <- function(value) {
    ifelse(abs(value - round(value)) < 1e-9, format(round(value)), number(value))
  }
  span <- function(lower, upper) {
    out <- paste0(number(lower), "-", number(upper))
    out[is.na(lower)] <- "-"
    out
  }
  population <- x$population[x$population > 0]
  cat(
    "LE8 scores: ", count(x$n), " participants",
    if (length(population) > 0L) {
      paste0(" (", paste(count(population), names(population), collapse = ", "), ")")
    },
    ", pooled over ", x$m, " imputations\n",
    sep = ""
  )
  if (!is.null(x$settings)) {
    cat(
      "Diet method: ", x$settings$diet_method,
      "; min_components: ", x$settings$min_components, "\n",
      sep = ""
    )
  }
  cat(
    "Composite score available for ", count(x$n_composite), " of ", count(x$n),
    " (average over imputations).\n\n",
    sep = ""
  )

  stats <- x$statistics
  ci_label <- paste0(format(100 * x$conf_level), "% CI")
  table <- data.frame(
    n = count(stats$n),
    mean = number(stats$mean),
    ci = span(stats$conf.low, stats$conf.high),
    fmi = number(stats$fmi, 2),
    sd = number(stats$sd),
    median = number(stats$median),
    row.names = .le8_measure_labels()[as.character(stats$measure)],
    check.names = FALSE
  )
  names(table)[names(table) == "ci"] <- ci_label
  print(table, right = TRUE)
  cat("Means pooled with Rubin's rules; fmi = fraction of missing information.\n")

  if (x$n_composite > 0) {
    cat("\nCategory (rows with a composite score):\n")
    categories <- x$categories
    shown <- data.frame(
      n = count(categories$n),
      percent = paste0(number(categories$percent), "%"),
      ci = span(categories$conf.low, categories$conf.high),
      row.names = paste0("  ", categories$category),
      check.names = FALSE
    )
    names(shown)[names(shown) == "ci"] <- ci_label
    print(shown, right = TRUE)
  }
  invisible(x)
}

#' Summarise multiply imputed LE8 scores with dplyr
#'
#' @description
#' The [summarise()][summarise.essential8_scores()] method for scores from
#' [score_le8_imputed()]. Without expressions, it returns the pooled
#' statistics in [summary()][summary.essential8_imputed_scores()], one row per
#' measure and group. With expressions, it is ordinary dplyr on the stacked
#' data sets; add `.imp` to `.by` to summarise each imputation separately.
#'
#' @inheritParams summarise.essential8_scores
#' @param .data An `essential8_imputed_scores` object.
#' @return Without expressions, an ungrouped data frame with the grouping
#'   columns, `measure`, and the pooled statistics: `n`, `n_missing`, `mean`,
#'   `std.error`, `conf.low`, `conf.high` (95%), `df`, `fmi`, and the averaged
#'   `sd`, `min`, `q25`, `median`, `q75`, and `max`. With expressions, the
#'   result of [dplyr::summarise()].
#' @seealso [summary.essential8_imputed_scores()]
#' @exportS3Method dplyr::summarise
summarise.essential8_imputed_scores <- function(.data, ..., .by = NULL, .groups = NULL) {
  if (...length() > 0L) {
    return(dplyr::summarise(
      .drop_le8_scores_class(.data),
      ...,
      .by = {{ .by }},
      .groups = .groups
    ))
  }
  .check_le8_scores(.data, call = rlang::current_env())
  .check_le8_imputations(.data, call = rlang::current_env())
  columns <- c(".imp", names(.le8_measure_keys()))
  dplyr::reframe(
    .drop_le8_scores_class(.data),
    .le8_pooled_measure_stats(dplyr::pick(dplyr::all_of(columns))),
    .by = {{ .by }}
  )
}
