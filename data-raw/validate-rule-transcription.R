devtools::load_all(".", quiet = TRUE)

rule_files <- list.files(
  path = file.path("data-raw"),
  pattern = "-rules[.]csv$",
  recursive = TRUE,
  full.names = TRUE
)

if (length(rule_files) == 0L) {
  stop("No rule-transcription files were found.", call. = FALSE)
}

for (rule_file in rule_files) {
  rules <- utils::read.csv(
    rule_file,
    na.strings = c("", "NA"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  essential8:::.validate_rule_table(rules, allow_empty = TRUE)
  message("Validated schema: ", rule_file, " (", nrow(rules), " rows)")
}

