#' Plot LE8 scores
#'
#' @description
#' Draws the scores returned by [score_le8()] with ggplot2:
#'
#' * `"components"` (the default): the mean composite and component scores.
#'   With a single row, these are that person's scores.
#' * `"distribution"`: box plots of the composite and component scores.
#' * `"composite"`: a histogram of the composite score, filled by
#'   cardiovascular health category.
#' * `"forest"`: a forest plot of the mean composite and component scores
#'   with confidence intervals, optionally compared across the groups in
#'   `by`, drawn by [ggforestplotR::ggforestplot()]. Requires the
#'   ggforestplotR package.
#'
#' Dashed lines mark the moderate (50) and high (80) thresholds. Missing scores
#' are left out. The result is a ggplot object, so it can be modified with
#' further ggplot2 layers, scales, and themes. For other designs, start from
#' [tidy()][tidy.essential8_scores()].
#'
#' @section Forest plots:
#' For `type = "forest"`, each row is a measure: the mean score and its
#' t-based confidence interval, from the rows with that score available.
#' Measures with fewer than two available scores in a group have no interval
#' and are left out. With `by`, rows with a missing group are left out, and
#' groups are ordered by factor level (or sorted, for other columns).
#'
#' @section Imputed scores:
#' For scores from [score_le8_imputed()], `"components"` shows pooled means
#' and `"forest"` pooled means with Rubin's-rules confidence intervals.
#' `"distribution"` shows the stacked imputed data sets, and `"composite"`
#' weights each row by \eqn{1/m} so the bars count participants.
#'
#' Arguments in `...` are passed to [ggforestplotR::ggforestplot()], so its
#' styling options work as usual, for example `striped_rows = TRUE`,
#' `point_size`, `dodge_width`, `ref_line`, or `sort_terms`. `conf.level`
#' (default `0.95`) sets the interval level as well as the label. The data
#' mapping arguments (`data`, `term`, `estimate`, `conf.low`, `conf.high`,
#' `label`, `group`, and `n`) are set by `plot()`. Composition helpers such as
#' [ggforestplotR::add_forest_table()] can be added to the result.
#'
#' @param x An `essential8_scores` object returned by [score_le8()].
#' @param type The plot to draw: `"components"`, `"distribution"`,
#'   `"composite"`, or `"forest"`.
#' @param by For `type = "forest"`, an optional column name in `x` whose
#'   groups are compared, such as `"sex"`. Defaults to the grouping column of
#'   a tibble grouped by one column, and to none otherwise.
#' @param ... For `type = "forest"`, named arguments passed to
#'   [ggforestplotR::ggforestplot()]. Must be empty for other types.
#' @return A ggplot object.
#' @seealso [tidy.essential8_scores()], [summary.essential8_scores()]
#' @examplesIf requireNamespace("ggplot2", quietly = TRUE)
#' adults <- read.csv(system.file(
#'   "extdata", "le8-adult-example.csv", package = "essential8"
#' ))
#' adults <- adults[!startsWith(names(adults), "expected_")]
#' scores <- score_le8(adults)
#'
#' plot(scores)
#' plot(scores, type = "distribution")
#' plot(scores, type = "composite")
#' @examplesIf requireNamespace("ggforestplotR", quietly = TRUE)
#'
#' # Compare groups in a forest plot, passing styling to ggforestplotR.
#' plot(scores, type = "forest", by = "bmi_profile", striped_rows = TRUE)
#' @importFrom rlang .data %||%
#' @export
plot.essential8_scores <- function(
  x,
  type = c("components", "distribution", "composite", "forest"),
  by = NULL,
  ...
) {
  .check_le8_scores(x, call = rlang::current_env())
  type <- rlang::arg_match(type)
  rlang::check_installed("ggplot2", reason = "to plot LE8 scores.")

  if (type != "forest") {
    if (!is.null(by)) {
      cli::cli_abort(
        "{.arg by} is only used with {.code type = \"forest\"}.",
        class = c("essential8_scores_error", "essential8_error")
      )
    }
    rlang::check_dots_empty()
  }

  switch(
    type,
    components = .plot_le8_components(x),
    distribution = .plot_le8_distribution(x),
    composite = .plot_le8_composite(x),
    forest = .plot_le8_forest(x, by = by, dots = rlang::list2(...))
  )
}

# Colors: one blue for single-series marks, and an ordinal light-to-dark blue
# ramp for the low/moderate/high categories.
.le8_plot_colors <- function() {
  list(
    mark = "#2a78d6",
    fill = "#cde2fb",
    categories = c(low = "#86b6ef", moderate = "#2a78d6", high = "#104281"),
    reference = "grey45"
  )
}

# Measure labels as a factor, with the composite first (at the top).
.le8_label_factor <- function(measure) {
  labels <- .le8_measure_labels()
  factor(labels[as.character(measure)], levels = rev(labels))
}

.le8_threshold_lines <- function() {
  ggplot2::geom_vline(
    xintercept = c(50, 80),
    linetype = "dashed",
    linewidth = 0.4,
    colour = .le8_plot_colors()$reference
  )
}

.le8_plot_theme <- function() {
  ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),
      plot.title.position = "plot"
    )
}

.le8_score_axis <- function(name = "Score") {
  ggplot2::scale_x_continuous(
    name = name,
    limits = c(0, 100),
    breaks = seq(0, 100, by = 20),
    expand = ggplot2::expansion(mult = c(0, 0.06))
  )
}

.le8_threshold_caption <- function() {
  "Dashed lines mark the moderate (50) and high (80) thresholds."
}

.abort_nothing_to_plot <- function(what, call = rlang::caller_env()) {
  cli::cli_abort(
    "{.arg x} has no non-missing {what} to plot.",
    class = c("essential8_scores_error", "essential8_error"),
    call = call
  )
}

.plot_le8_components <- function(x) {
  data <- as.data.frame(x)
  stats <- if (.is_imputed(x)) {
    .le8_pooled_measure_stats(data)
  } else {
    .le8_measure_stats(data)
  }
  stats <- stats[!is.na(stats$mean), , drop = FALSE]
  if (nrow(stats) == 0L) {
    .abort_nothing_to_plot("scores", call = rlang::caller_env())
  }
  stats$label <- .le8_label_factor(stats$measure)
  single <- nrow(x) == 1L

  ggplot2::ggplot(stats, ggplot2::aes(x = .data$mean, y = .data$label)) +
    .le8_threshold_lines() +
    ggplot2::geom_col(width = 0.65, fill = .le8_plot_colors()$mark) +
    ggplot2::geom_text(
      ggplot2::aes(label = formatC(.data$mean, format = "f", digits = 0)),
      hjust = -0.25,
      size = 3.2
    ) +
    .le8_score_axis(if (single) "Score" else "Mean score") +
    ggplot2::labs(
      title = if (single) "LE8 scores" else "Mean LE8 scores",
      subtitle = if (!single) .le8_plot_n(x),
      y = NULL,
      caption = .le8_threshold_caption()
    ) +
    .le8_plot_theme()
}

.plot_le8_distribution <- function(x) {
  long <- as.data.frame(tidy.essential8_scores(x))
  long <- long[!is.na(long$score), , drop = FALSE]
  if (nrow(long) == 0L) {
    .abort_nothing_to_plot("scores", call = rlang::caller_env())
  }
  long$label <- .le8_label_factor(long$measure)
  colors <- .le8_plot_colors()

  ggplot2::ggplot(long, ggplot2::aes(x = .data$score, y = .data$label)) +
    .le8_threshold_lines() +
    ggplot2::geom_boxplot(
      width = 0.6,
      colour = colors$mark,
      fill = colors$fill,
      outlier.size = 1.5
    ) +
    .le8_score_axis() +
    ggplot2::labs(
      title = "Distribution of LE8 scores",
      subtitle = .le8_plot_n(x, stacked = TRUE),
      y = NULL,
      caption = .le8_threshold_caption()
    ) +
    .le8_plot_theme()
}

.plot_le8_composite <- function(x) {
  data <- as.data.frame(x)
  data <- data[!is.na(data$le8_composite_score), , drop = FALSE]
  if (nrow(data) == 0L) {
    .abort_nothing_to_plot("composite scores", call = rlang::caller_env())
  }
  # Imputed data sets are stacked; weight each row so bars count participants.
  m <- if (.is_imputed(x)) .n_imputations(x) else 1L
  data$weight <- 1 / m
  data$category <- factor(data$le8_category, levels = .le8_category_levels())
  levels(data$category) <- c("Low", "Moderate", "High")

  # Left-closed 5-point bins align with the category cutpoints (50 and 80),
  # so each bar falls in exactly one category.
  ggplot2::ggplot(
    data,
    ggplot2::aes(
      x = .data$le8_composite_score,
      fill = .data$category,
      weight = .data$weight
    )
  ) +
    ggplot2::geom_histogram(
      breaks = seq(0, 100, by = 5),
      closed = "left",
      colour = "white",
      linewidth = 0.3
    ) +
    .le8_threshold_lines() +
    ggplot2::scale_fill_manual(
      name = "Category",
      values = unname(.le8_plot_colors()$categories),
      drop = FALSE
    ) +
    .le8_score_axis("LE8 composite score") +
    ggplot2::scale_y_continuous(
      name = if (m > 1L) "Participants (average over imputations)" else "Rows",
      breaks = .integer_breaks,
      expand = ggplot2::expansion(mult = c(0, 0.05))
    ) +
    ggplot2::labs(
      title = "LE8 composite scores",
      subtitle = if (m > 1L) {
        paste0(
          "n = ", format(round(nrow(data) / m, 1)),
          " participants with a composite score, averaged over ", m, " imputations"
        )
      } else {
        paste0("n = ", nrow(data), " rows with a composite score")
      }
    ) +
    .le8_plot_theme() +
    ggplot2::theme(
      panel.grid.major.y = ggplot2::element_line(),
      panel.grid.major.x = ggplot2::element_blank()
    )
}

# Counts are whole numbers, so never label fractional rows.
.integer_breaks <- function(limits) {
  breaks <- pretty(limits)
  breaks[breaks == round(breaks)]
}

# Forest plot ------------------------------------------------------------------

# Arguments `plot()` maps itself; everything else in `...` reaches ggforestplot().
.le8_forest_mapped_args <- function() {
  c("data", "term", "estimate", "conf.low", "conf.high", "label", "group", "n")
}

.plot_le8_forest <- function(x, by, dots, call = rlang::caller_env()) {
  rlang::check_installed(
    "ggforestplotR",
    version = "0.6.0",
    reason = "to draw LE8 forest plots."
  )
  .check_forest_dots(dots, call = call)
  conf_level <- dots[["conf.level"]] %||% 0.95
  if (!is.numeric(conf_level) || length(conf_level) != 1L ||
      is.na(conf_level) || conf_level <= 0 || conf_level >= 1) {
    cli::cli_abort(
      "{.arg conf.level} must be a single number between 0 and 1.",
      class = c("essential8_scores_error", "essential8_error"),
      call = call
    )
  }
  if (is.null(by) && inherits(x, "grouped_df")) {
    group_vars <- setdiff(names(attr(x, "groups")), ".rows")
    if (length(group_vars) == 1L) {
      by <- group_vars
    }
  }

  forest <- .le8_forest_data(
    x,
    by = by,
    conf_level = conf_level,
    imputed = .is_imputed(x),
    call = call
  )
  args <- list(
    data = forest,
    term = "measure",
    estimate = "estimate",
    conf.low = "conf.low",
    conf.high = "conf.high",
    label = "label",
    n = "n",
    conf.level = conf_level,
    ref_line = NULL
  )
  if (!is.null(by)) {
    args$group <- by
  }
  args[names(dots)] <- dots

  plot <- do.call(ggforestplotR::ggforestplot, args)
  plot +
    .le8_threshold_lines() +
    ggplot2::labs(
      x = paste0("Mean score (", format(100 * conf_level), "% CI)"),
      title = if (is.null(by)) "Mean LE8 scores" else paste("Mean LE8 scores by", by),
      caption = .le8_threshold_caption()
    )
}

.check_forest_dots <- function(dots, call = rlang::caller_env()) {
  if (length(dots) == 0L) {
    return(invisible())
  }
  dot_names <- names(dots) %||% rep("", length(dots))
  if (any(dot_names == "")) {
    cli::cli_abort(
      "Arguments in {.arg ...} must be named; they are passed to {.fn ggforestplotR::ggforestplot}.",
      class = c("essential8_scores_error", "essential8_error"),
      call = call
    )
  }
  mapped <- intersect(dot_names, .le8_forest_mapped_args())
  if (length(mapped) > 0L) {
    cli::cli_abort(
      c(
        "{.fn plot} sets {.arg {mapped}} for {.fn ggforestplotR::ggforestplot}.",
        "i" = "Use {.arg by} to compare groups, or call {.fn ggforestplotR::ggforestplot} on your own summary of {.fn tidy} output."
      ),
      class = c("essential8_scores_error", "essential8_error"),
      call = call
    )
  }
  invisible()
}

# One row per measure (and group): mean score with a t-based interval.
.le8_forest_data <- function(x, by, conf_level, imputed = FALSE,
                             call = rlang::caller_env()) {
  data <- as.data.frame(x)
  if (!is.null(by)) {
    if (!is.character(by) || length(by) != 1L || is.na(by) ||
        !by %in% names(data)) {
      cli::cli_abort(
        "{.arg by} must be the name of one column in {.arg x}.",
        class = c("essential8_scores_error", "essential8_error"),
        call = call
      )
    }
    groups <- data[[by]]
    if (!is.factor(groups)) {
      groups <- factor(groups, levels = sort(unique(groups[!is.na(groups)])))
    }
    keep <- !is.na(groups)
    data <- data[keep, , drop = FALSE]
    groups <- droplevels(groups[keep])
    pieces <- split(data, groups)
  } else {
    pieces <- list(data)
  }

  rows <- lapply(seq_along(pieces), function(i) {
    stats <- .le8_interval_stats(pieces[[i]], imputed = imputed, conf_level = conf_level)
    stats <- stats[!is.na(stats$conf.low), , drop = FALSE]
    if (nrow(stats) == 0L) {
      return(NULL)
    }
    out <- data.frame(
      measure = as.character(stats$measure),
      label = unname(.le8_measure_labels()[as.character(stats$measure)]),
      estimate = stats$mean,
      conf.low = stats$conf.low,
      conf.high = stats$conf.high,
      n = stats$n
    )
    if (!is.null(by)) {
      out[[by]] <- factor(names(pieces)[i], levels = names(pieces))
    }
    out
  })
  forest <- do.call(rbind, rows)
  if (is.null(forest)) {
    .abort_nothing_to_plot(
      "scores (at least two per measure are needed for an interval)",
      call = call
    )
  }
  rownames(forest) <- NULL
  forest
}

# Plot subtitle: rows, or participants and imputations for imputed scores.
.le8_plot_n <- function(x, stacked = FALSE) {
  if (!.is_imputed(x)) {
    return(paste0("n = ", nrow(x), " rows"))
  }
  m <- .n_imputations(x)
  paste0(
    "n = ", nrow(x) / m, " participants, ",
    if (stacked) "stacked over " else "pooled over ",
    m, " imputations"
  )
}
