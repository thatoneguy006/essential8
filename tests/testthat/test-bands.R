test_that(".score_bands uses lower-inclusive, upper-exclusive bands", {
  score <- essential8:::.score_bands(
    c(-1, 0, 9.99, 10, 20, NA),
    lower = c(-Inf, 10, 20),
    points = c(1, 2, 3)
  )
  expect_identical(score, c(1, 1, 1, 2, 3, NA))
  expect_error(essential8:::.score_bands(1, c(2, 1), c(1, 2)), "Internal")
})

test_that(".score_row_bands applies row-specific thresholds", {
  score <- essential8:::.score_row_bands(
    c(5, 5, 15, 5),
    thresholds = list(c(10, 4, 10, NA)),
    points = c(100, 50)
  )
  expect_identical(score, c(100, 50, 50, NA))
})
