build_verified_rules <- function() {
  devtools::load_all(".", quiet = TRUE)

  rule_files <- list.files(
    path = file.path("data-raw"),
    pattern = "-rules[.]csv$",
    recursive = TRUE,
    full.names = TRUE
  )

  rule_tables <- lapply(rule_files, function(rule_file) {
    rules <- utils::read.csv(
      rule_file,
      na.strings = c("", "NA"),
      check.names = FALSE,
      stringsAsFactors = FALSE
    )

    if (nrow(rules) == 0L) {
      return(NULL)
    }

    essential8:::.validate_rule_table(rules)
    rules
  })

  rule_tables <- Filter(Negate(is.null), rule_tables)
  if (length(rule_tables) == 0L) {
    stop(
      "No transcribed rule rows exist; package data was not built.",
      call. = FALSE
    )
  }

  le8_rules <- do.call(rbind, rule_tables)
  if (any(le8_rules$verification_status != "verified")) {
    stop(
      "All rule rows must be independently verified before package data is built.",
      call. = FALSE
    )
  }

  usethis::use_data(le8_rules, internal = TRUE, overwrite = TRUE)
}

if (sys.nframe() == 0L) {
  build_verified_rules()
}

