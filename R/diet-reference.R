#' Construct a reference for population diet scoring
#'
#' Creates a small, method-specific reference for DASH or HEI-2015 indices,
#' including HEI-2015 totals calculated from raw inputs. Raw DASH with custom
#' definitions requires explicit `dash_cutpoints` in [score_le8()] to specify
#' intake quintiles as well. The four values are index-score cutpoints at the indicated
#' percentiles, not percentiles themselves. No observations are stored or ranked.
#'
#' @param p25,p50,p75,p95 Single finite numeric cutpoints, in nondecreasing order.
#' @param method Either `"dash"` or `"hei2015"`, matched case-insensitively.
#' @param label,source Optional single nonempty strings describing the reference
#'   population and its source. These do not change scoring.
#' @param score_range Optional numeric vector of two finite bounds identifying
#'   the index's theoretical range. HEI-2015 always uses 0 to 100. DASH has
#'   multiple definitions, so a custom DASH reference has no implicit range.
#' @return An `essential8_diet_reference` object containing the method,
#'   cutpoints, optional metadata, and index range. It identifies percentile
#'   bands, not an exact continuous percentile distribution.
#' @examples
#' ref <- diet_reference(40, 55, 65, 80, method = "hei2015",
#'                       label = "Synthetic example")
#' ref
#' @export
diet_reference <- function(p25, p50, p75, p95, method = "dash",
                           label = NULL, source = NULL, score_range = NULL) {
  method <- .normalize_reference_method(method)
  values <- list(p25 = p25, p50 = p50, p75 = p75, p95 = p95)
  valid <- vapply(values, function(x) {
    is.numeric(x) && is.null(dim(x)) && length(x) == 1L &&
      !is.na(x) && is.finite(x)
  }, logical(1))
  if (!all(valid) || any(diff(unlist(values)) < 0)) {
    .abort_adult_scoring(
      "Diet reference cutpoints must be finite numeric scalars in nondecreasing order."
    )
  }
  for (value in list(label, source)) {
    if (!is.null(value) && (!is.character(value) || length(value) != 1L ||
                           is.na(value) || !nzchar(trimws(value)))) {
      .abort_adult_scoring(
        "Diet reference labels and sources must be single nonempty strings."
      )
    }
  }
  if (method == "hei2015") {
    if (!is.null(score_range) && (!is.numeric(score_range) ||
        !is.null(dim(score_range)) ||
        !identical(as.numeric(score_range), c(0, 100)))) {
      .abort_adult_scoring("HEI-2015 references must use the range 0 to 100.")
    }
    score_range <- c(0, 100)
  }
  if (!is.null(score_range)) {
    if (!is.numeric(score_range) || !is.null(dim(score_range)) ||
        length(score_range) != 2L || anyNA(score_range) ||
        any(!is.finite(score_range)) || score_range[1] >= score_range[2] ||
        any(unlist(values) < score_range[1] |
            unlist(values) > score_range[2])) {
      .abort_adult_scoring(
        "{.arg score_range} must contain two increasing finite bounds enclosing every cutpoint."
      )
    }
  }
  structure(
    c(list(method = method), values,
      list(label = label, source = source, score_range = score_range)),
    class = "essential8_diet_reference"
  )
}

.normalize_reference_method <- function(method) {
  method <- .normalize_adult_diet_method(method)
  if (!method %in% c("dash", "hei2015")) {
    .abort_adult_scoring("Diet references support only {.val dash} or {.val hei2015}.")
  }
  method
}

.validate_diet_reference <- function(reference, method) {
  required <- c("method", "p25", "p50", "p75", "p95")
  if (!inherits(reference, "essential8_diet_reference") ||
      !is.list(reference) || anyDuplicated(names(reference)) ||
      !all(required %in% names(reference))) {
    .abort_adult_scoring("Use {.fn diet_reference} to construct a diet reference.")
  }
  validated <- diet_reference(
    reference$p25, reference$p50, reference$p75, reference$p95,
    method = reference$method, label = reference$label,
    source = reference$source, score_range = reference$score_range
  )
  if (validated$method != method) {
    .abort_adult_scoring(
      "The supplied diet reference is for {validated$method}, but {.arg diet_method} is {method}."
    )
  }
  reference[names(validated)] <- validated
  reference
}

.resolve_diet_reference <- function(method, reference) {
  method <- .normalize_reference_method(method)
  if (is.character(reference)) {
    if (length(reference) != 1L || anyNA(reference) ||
        reference != "nhanes_2015_2018") {
      .abort_adult_scoring(
        "Unknown diet reference. Use {.val nhanes_2015_2018} or {.fn diet_reference}."
      )
    }
    if (!exists(".nhanes_diet_references", inherits = TRUE)) {
      .abort_adult_scoring(
        "The NHANES 2015-2018 diet references are unavailable in this package build."
      )
    }
    reference <- .nhanes_diet_references[[method]]
  }
  .validate_diet_reference(reference, method)
}

.diet_index_to_score <- function(score, reference) {
  if (is.logical(score) && all(is.na(score))) score <- as.numeric(score)
  if (!is.numeric(score) || !is.null(dim(score)) ||
      any(!is.finite(score[!is.na(score)]))) {
    .abort_adult_scoring("Diet index scores must be numeric and finite when observed.")
  }
  bounds <- reference$score_range
  if (!is.null(bounds) && any(score < bounds[1] | score > bounds[2], na.rm = TRUE)) {
    .abort_adult_scoring(
      "Diet index scores must be from {bounds[1]} to {bounds[2]} for the selected reference."
    )
  }
  .score_population_diet_total(score, unlist(reference[c("p25", "p50", "p75", "p95")]))
}

#' @export
print.essential8_diet_reference <- function(x, ...) {
  cat("Diet reference:", x$method, "\n")
  if (!is.null(x$label)) cat("Population:", x$label, "\n")
  print(unlist(x[c("p25", "p50", "p75", "p95")]))
  if (!is.null(x$source)) cat("Source:", x$source, "\n")
  invisible(x)
}
