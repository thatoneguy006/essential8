.abort_rule_schema <- function(
  message,
  ...,
  call = parent.frame(),
  .envir = parent.frame()
) {
  cli::cli_abort(
    message = message,
    ...,
    class = c(
      "essential8_rule_schema_error",
      "essential8_error"
    ),
    call = call,
    .envir = .envir
  )
}

.abort_adult_scoring <- function(
  message,
  ...,
  call = parent.frame(),
  .envir = parent.frame()
) {
  cli::cli_abort(
    message = message,
    ...,
    class = c(
      "essential8_adult_input_error",
      "essential8_error"
    ),
    call = call,
    .envir = .envir
  )
}
