# Table-driven scoring helpers ------------------------------------------------
#
# AHA scoring tables are written as bands with inclusive lower bounds, for
# example "60 points for 130-159 mg/dL". `.score_bands()` encodes such a table
# as two parallel vectors so each component reads like its source table:
#
#   .score_bands(non_hdl, lower = c(-Inf, 130, 160, 190, 220),
#                         points = c( 100,  60,  40,  20,   0))
#
# `findInterval()` returns i such that lower[i] <= x < lower[i + 1], which is
# exactly the lower-inclusive, upper-exclusive convention of the AHA tables.
# Missing inputs stay missing.

.score_bands <- function(x, lower, points) {
  if (length(lower) != length(points) || is.unsorted(lower)) {
    cli::cli_abort(
      "Internal error: band bounds must be sorted and match the points.",
      .internal = TRUE
    )
  }
  band <- findInterval(x, lower)
  score <- rep(NA_real_, length(x))
  scored <- !is.na(band) & band > 0L
  score[scored] <- points[band[scored]]
  score
}

# Bands whose bounds differ by row (pediatric blood-pressure percentiles).
# `thresholds` is a list of increasing numeric vectors, one per band after the
# first; `points` has one more element than `thresholds`.
.score_row_bands <- function(x, thresholds, points) {
  score <- rep(points[[1]], length(x))
  for (i in seq_along(thresholds)) {
    score[which(x >= thresholds[[i]])] <- points[[i + 1L]]
  }
  score[is.na(x) | Reduce(`|`, lapply(thresholds, is.na))] <- NA_real_
  score
}

# Subtract a treatment or clinical-judgment decrement, flooring at zero.
# An NA `apply` (unknown treatment status) gives an NA score.
.apply_decrement <- function(score, apply, points = 20) {
  pmax(0, score - ifelse(apply, points, 0))
}

# Choose adult or pediatric values row by row.
.by_population <- function(age, adult, pediatric) {
  out <- pediatric
  out[age$adult] <- adult[age$adult]
  out
}
