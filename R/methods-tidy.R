#' @importFrom generics tidy
#' @export
generics::tidy

#' Tidy LE8 scores into long format
#'
#' @description
#' Reshapes the composite and component scores returned by [score_le8()] into
#' long format, with one row per input row and measure. This is the shape
#' ggplot2 and grouped summaries expect.
#'
#' @param x An `essential8_scores` object returned by [score_le8()].
#' @param id_cols Optional character vector of columns in `x` to carry into
#'   the result, such as a participant identifier. Defaults to the grouping
#'   columns when `x` is a grouped tibble, and to none otherwise. Scores from
#'   [score_le8_imputed()] always carry `.imp` (and `.id`, when present).
#' @param composite Whether to include the composite score as a measure.
#' @param ... Not used.
#' @return A data frame of the same type as `x` (a tibble for tibble input),
#'   ungrouped, with the columns:
#'   * `row`: the row of `x` the score comes from.
#'   * the `id_cols`.
#'   * `le8_population`: `"adult"` or `"pediatric"`.
#'   * `measure`: a factor; `composite` (when included), then `diet`,
#'     `physical_activity`, `nicotine`, `sleep`, `bmi`, `blood_lipids`,
#'     `blood_glucose`, and `blood_pressure`.
#'   * `score`: the score, from 0 to 100, or `NA` when unavailable.
#' @seealso [summary.essential8_scores()], [plot.essential8_scores()]
#' @examples
#' adults <- read.csv(system.file(
#'   "extdata", "le8-adult-example.csv", package = "essential8"
#' ))
#' adults <- adults[!startsWith(names(adults), "expected_")]
#' scores <- score_le8(adults)
#' head(tidy(scores, id_cols = "id"), 9)
#' @export
tidy.essential8_scores <- function(x, id_cols = NULL, composite = TRUE, ...) {
  .check_le8_scores(x, call = rlang::current_env())
  if (!is.logical(composite) || length(composite) != 1L || is.na(composite)) {
    cli::cli_abort(
      "{.arg composite} must be {.code TRUE} or {.code FALSE}.",
      class = c("essential8_scores_error", "essential8_error")
    )
  }
  if (is.null(id_cols) && inherits(x, "grouped_df")) {
    id_cols <- setdiff(names(attr(x, "groups")), ".rows")
  }
  id_cols <- .check_tidy_id_cols(id_cols, x)
  if (.is_imputed(x)) {
    id_cols <- union(intersect(c(".imp", ".id"), names(x)), id_cols)
  }

  data <- as.data.frame(x)
  keys <- .le8_measure_keys()
  if (!composite) {
    keys <- keys[keys != "composite"]
  }
  n <- nrow(data)
  k <- length(keys)
  source_rows <- rep(seq_len(n), each = k)

  ids <- data[source_rows, id_cols, drop = FALSE]
  rownames(ids) <- NULL
  scores <- as.matrix(data[names(keys)])

  out <- data.frame(
    row = source_rows,
    ids,
    le8_population = data$le8_population[source_rows],
    measure = factor(rep(unname(keys), times = n), levels = unname(keys)),
    score = as.vector(t(scores)),
    check.names = FALSE
  )
  if (inherits(x, "tbl_df")) {
    out <- tibble::as_tibble(out)
  }
  out
}

.check_tidy_id_cols <- function(id_cols, x, call = rlang::caller_env()) {
  if (is.null(id_cols)) {
    return(character())
  }
  if (!is.character(id_cols) || anyNA(id_cols)) {
    cli::cli_abort(
      "{.arg id_cols} must be a character vector of column names.",
      class = c("essential8_scores_error", "essential8_error"),
      call = call
    )
  }
  reserved <- intersect(id_cols, c("row", "le8_population", "measure", "score"))
  unknown <- setdiff(setdiff(id_cols, reserved), names(x))
  if (length(unknown) > 0L || length(reserved) > 0L) {
    cli::cli_abort(
      c(
        "{.arg id_cols} must name other columns of {.arg x}.",
        "x" = if (length(unknown) > 0L) "Not found: {.field {unknown}}.",
        "x" = if (length(reserved) > 0L) "Already in the result: {.field {reserved}}."
      ),
      class = c("essential8_scores_error", "essential8_error"),
      call = call
    )
  }
  unique(id_cols)
}
