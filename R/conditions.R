# Structured conditions ------------------------------------------------------
#
# Every input error carries `essential8_input_error` and `essential8_error`.
# `essential8_adult_input_error` is retained on general and adult errors so
# code written against essential8 <= 0.3.0 keeps catching them. Errors that
# only concern pediatric definitions carry `essential8_pediatric_input_error`
# instead.

.abort_input <- function(
  message,
  ...,
  population = c("any", "adult", "pediatric"),
  call = .user_facing_call(parent.frame()),
  .envir = parent.frame()
) {
  population <- match.arg(population)
  class <- switch(
    population,
    pediatric = "essential8_pediatric_input_error",
    "essential8_adult_input_error"
  )
  cli::cli_abort(
    message = message,
    ...,
    class = c(class, "essential8_input_error", "essential8_error"),
    call = call,
    .envir = .envir
  )
}

.abort_pediatric <- function(
  message,
  ...,
  call = .user_facing_call(parent.frame()),
  .envir = parent.frame()
) {
  .abort_input(
    message,
    ...,
    population = "pediatric",
    call = call,
    .envir = .envir
  )
}

.warn_le8 <- function(message, class, .envir = parent.frame()) {
  cli::cli_warn(
    message,
    class = c(class, "essential8_warning"),
    .envir = .envir
  )
}

# Report errors against the exported function the user called (for example
# `score_le8()`) rather than the internal helper that detected the problem.
.user_facing_call <- function(default) {
  exported <- list(score_le8, diet_reference, add_pediatric_references)
  for (i in rev(seq_len(sys.nframe()))) {
    fn <- sys.function(i)
    if (any(vapply(exported, identical, logical(1), fn))) {
      return(sys.call(i))
    }
  }
  default
}
