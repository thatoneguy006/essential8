#' Restore LE8 score methods to a data frame
#'
#' @description
#' [score_le8()] returns an `essential8_scores` object: the input data frame
#' (or tibble), with its original class, plus the score columns. The extra
#' class provides [summary()][summary.essential8_scores()],
#' [tidy()][tidy.essential8_scores()], [plot()][plot.essential8_scores()], and,
#' with dplyr loaded, [summarise()][summarise.essential8_scores()].
#'
#' Row-wise operations such as `filter()`, `mutate()`, `arrange()`, joins, and
#' `bind_rows()` keep the class. `group_by()`, `summarise()` with
#' expressions, `as_tibble()`, `pivot_longer()`, and saving to and reading from
#' a file drop it. `as_le8_scores()` adds the class back to any data frame that
#' still contains the score columns. It does not rescore or change any values.
#'
#' A data frame with an `.imp` column, such as saved results from
#' [score_le8_imputed()], becomes an `essential8_imputed_scores` object, so
#' its methods pool across imputations again.
#'
#' @param x A data frame containing the columns returned by [score_le8()]:
#'   the eight component scores (`diet_score`, `physical_activity_score`,
#'   `nicotine_score`, `sleep_score`, `bmi_score`, `blood_lipids_score`,
#'   `blood_glucose_score`, and `blood_pressure_score`), `n_components`,
#'   `le8_composite_score`, `le8_category`, and `le8_population`.
#' @return `x`, with the class `essential8_scores` added, and
#'   `essential8_imputed_scores` too when `x` has an `.imp` column.
#' @seealso [score_le8()]
#' @examples
#' scores <- score_le8(
#'   data.frame(age = 45, sleep_hours = 7.5, bmi = 24, bmi_profile = "general"),
#'   min_components = 2
#' )
#' plain <- as.data.frame(scores)
#' summary(as_le8_scores(plain))
#' @export
as_le8_scores <- function(x) {
  if (!is.data.frame(x)) {
    cli::cli_abort(
      c(
        "{.arg x} must be a data frame.",
        "x" = "You supplied {.cls {class(x)}}."
      ),
      class = c("essential8_scores_error", "essential8_error")
    )
  }
  .check_le8_scores(x, call = rlang::current_env())
  x <- .new_le8_scores(x)
  if (".imp" %in% names(x)) {
    .check_le8_imputations(x, call = rlang::current_env())
    x <- .new_le8_imputed_scores(x)
  }
  x
}

.new_le8_scores <- function(x, diet_method = NULL, min_components = NULL) {
  if (!inherits(x, "essential8_scores")) {
    class(x) <- c("essential8_scores", class(x))
  }
  if (!is.null(diet_method)) {
    attr(x, "essential8_settings") <- list(
      diet_method = diet_method,
      min_components = min_components
    )
  }
  x
}

# Removes the class and its metadata, leaving the caller's data frame type.
.drop_le8_scores_class <- function(x) {
  class(x) <- setdiff(class(x), c("essential8_imputed_scores", "essential8_scores"))
  attr(x, "essential8_settings") <- NULL
  x
}

.le8_scores_required_columns <- function() {
  c(
    .le8_component_score_columns(),
    "n_components",
    "le8_composite_score",
    "le8_category",
    "le8_population"
  )
}

# The methods check for their columns at call time because `select()` and
# similar verbs keep the class even after score columns are removed.
.check_le8_scores <- function(x, call = rlang::caller_env()) {
  missing <- setdiff(.le8_scores_required_columns(), names(x))
  if (length(missing) == 0L) {
    return(invisible(x))
  }
  legacy <- intersect(.le8_legacy_output_columns(), names(x))
  cli::cli_abort(
    c(
      "{.arg x} does not contain the score columns returned by {.fn score_le8}.",
      "x" = "Missing: {.field {missing}}.",
      if (length(legacy) > 0L) {
        c("i" = "Columns such as {.field {legacy[1]}} come from essential8 0.3.0 or earlier; rescore with {.fn score_le8}.")
      } else {
        c("i" = "Keep these columns when selecting, or rescore with {.fn score_le8}.")
      }
    ),
    class = c("essential8_scores_error", "essential8_error"),
    call = call
  )
}

# Measures summarised by the methods: the composite, then the eight components
# in AHA order. Named by output column; values are short keys.
.le8_measure_keys <- function() {
  c(le8_composite_score = "composite", .le8_component_keys())
}

.le8_measure_labels <- function() {
  stats::setNames(
    c("LE8 composite", unname(.le8_component_labels())),
    unname(.le8_measure_keys())
  )
}

# One row per measure: available and missing counts, mean, SD, and quantiles.
# Shared by summary() and summarise() so both report identical statistics.
.le8_measure_stats <- function(scores) {
  keys <- .le8_measure_keys()
  rows <- lapply(names(keys), function(column) {
    values <- scores[[column]]
    observed <- values[!is.na(values)]
    n <- length(observed)
    quantiles <- if (n > 0L) {
      stats::quantile(observed, c(0, 0.25, 0.5, 0.75, 1), names = FALSE)
    } else {
      rep(NA_real_, 5L)
    }
    data.frame(
      n = n,
      n_missing = length(values) - n,
      mean = if (n > 0L) mean(observed) else NA_real_,
      sd = if (n > 1L) stats::sd(observed) else NA_real_,
      min = quantiles[[1]],
      q25 = quantiles[[2]],
      median = quantiles[[3]],
      q75 = quantiles[[4]],
      max = quantiles[[5]]
    )
  })
  data.frame(
    measure = factor(unname(keys), levels = unname(keys)),
    do.call(rbind, rows)
  )
}

.le8_category_levels <- function() c("low", "moderate", "high")

.is_imputed <- function(x) inherits(x, "essential8_imputed_scores")

# Number of imputations in stacked imputed scores.
.n_imputations <- function(x) length(unique(x$.imp))

# Mean of each measure with a confidence interval: t-based for one data set,
# pooled with Rubin's rules across imputations.
.le8_interval_stats <- function(scores, imputed, conf_level = 0.95) {
  if (imputed) {
    stats <- .le8_pooled_measure_stats(scores, conf_level = conf_level)
    return(stats[c("measure", "n", "mean", "conf.low", "conf.high")])
  }
  stats <- .le8_measure_stats(scores)
  half_width <- ifelse(
    stats$n >= 2L,
    stats::qt(1 - (1 - conf_level) / 2, df = pmax(stats$n - 1L, 1L)) *
      stats$sd / sqrt(stats$n),
    NA_real_
  )
  data.frame(
    measure = stats$measure,
    n = stats$n,
    mean = stats$mean,
    conf.low = stats$mean - half_width,
    conf.high = stats$mean + half_width
  )
}
