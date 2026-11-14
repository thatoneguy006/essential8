pediatric_example_fixture <- local({
  fixture <- NULL

  function() {
    if (is.null(fixture)) {
      path <- system.file(
        "extdata",
        "le8-pediatric-example.csv",
        package = "essential8"
      )
      if (!nzchar(path)) {
        path <- testthat::test_path(
          "..", "..", "inst", "extdata", "le8-pediatric-example.csv"
        )
      }
      fixture <<- utils::read.csv(
        path,
        check.names = FALSE,
        stringsAsFactors = FALSE
      )
    }
    fixture
  }
})

pediatric_input_fixture <- function() {
  fixture <- pediatric_example_fixture()
  fixture[!startsWith(names(fixture), "expected_")]
}

pediatric_row <- function(id, ...) {
  fixture <- pediatric_input_fixture()
  row <- fixture[fixture$id == id, , drop = FALSE]
  rownames(row) <- NULL
  changes <- list(...)
  for (column in names(changes)) {
    row[[column]] <- changes[[column]]
  }
  row
}

# Repeat a one-row input once per value, setting the named columns.
with_values <- function(row, ...) {
  changes <- list(...)
  n <- max(1L, lengths(changes))
  out <- row[rep(1L, n), , drop = FALSE]
  rownames(out) <- NULL
  for (column in names(changes)) {
    out[[column]] <- rep_len(changes[[column]], n)
  }
  out
}

# Many single-row pediatric cases deliberately omit laboratory values; muffle
# only the resulting component-availability warnings, which have dedicated
# tests that call score_le8() directly.
score_pediatric <- function(...) {
  muffle <- function(warning) invokeRestart("muffleWarning")
  withCallingHandlers(
    score_le8(...),
    essential8_missing_component = muffle,
    essential8_insufficient_components = muffle
  )
}
