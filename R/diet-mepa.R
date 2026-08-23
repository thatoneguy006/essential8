.adult_mepa_item_columns <- function() {
  c(
    "olive_oil",
    "green_leafy_vegetables",
    "other_vegetables",
    "berries",
    "other_fruit",
    "meat",
    "fish",
    "chicken",
    "cheese",
    "butter_cream",
    "beans",
    "whole_grains",
    "sweets_and_pastries",
    "nuts",
    "fast_food",
    "alcohol"
  )
}

.adult_mepa_required_columns <- function() {
  c(.adult_mepa_item_columns(), "sex")
}

.normalize_adult_mepa_column_map <- function(mepa_columns) {
  canonical <- .adult_mepa_required_columns()
  resolved <- stats::setNames(canonical, canonical)

  if (is.null(mepa_columns) || length(mepa_columns) == 0L) {
    return(resolved)
  }

  if (!is.character(mepa_columns) || is.null(names(mepa_columns))) {
    .abort_adult_scoring(c(
      "{.arg mepa_columns} must be a named character vector.",
      "i" = "Names identify canonical MEPA fields and values identify columns in {.arg data}."
    ))
  }

  map_names <- names(mepa_columns)
  if (anyNA(map_names) || any(map_names == "") ||
      anyNA(mepa_columns) || any(mepa_columns == "")) {
    .abort_adult_scoring(
      "{.arg mepa_columns} must have complete, nonempty names and values."
    )
  }

  normalized_names <- tolower(map_names)
  duplicated_names <- unique(normalized_names[duplicated(normalized_names)])
  if (length(duplicated_names) > 0L) {
    .abort_adult_scoring(c(
      "{.arg mepa_columns} contains duplicated canonical fields.",
      "x" = "Duplicated after case normalization: {paste(duplicated_names, collapse = ', ')}."
    ))
  }

  unknown <- setdiff(normalized_names, canonical)
  if (length(unknown) > 0L) {
    .abort_adult_scoring(c(
      "{.arg mepa_columns} contains unsupported canonical fields.",
      "x" = "Unsupported: {paste(unknown, collapse = ', ')}.",
      "i" = "Use MEPA screener-item labels in snake_case, plus {.field sex}."
    ))
  }

  resolved[normalized_names] <- unname(mepa_columns)
  normalized_targets <- tolower(unname(resolved))
  duplicated_targets <- unique(
    unname(resolved)[duplicated(normalized_targets)]
  )
  if (length(duplicated_targets) > 0L) {
    .abort_adult_scoring(c(
      "{.arg mepa_columns} must map each MEPA field to a different column.",
      "x" = "Duplicated target after case normalization: {paste(duplicated_targets, collapse = ', ')}."
    ))
  }

  resolved
}

.resolve_adult_mepa_columns <- function(data, mepa_columns) {
  requested <- .normalize_adult_mepa_column_map(mepa_columns)
  data_names <- names(data)
  index <- match(tolower(unname(requested)), tolower(data_names))

  sex_position <- match("sex", names(requested))
  uses_default_sex <- tolower(unname(requested[sex_position])) == "sex"
  if (is.na(index[sex_position]) && uses_default_sex) {
    index[sex_position] <- match("female", tolower(data_names))
  }

  if (anyNA(index)) {
    missing <- names(requested)[is.na(index)]
    expected <- unname(requested[missing])
    details <- paste0(missing, " -> ", expected)
    .abort_adult_scoring(c(
      "MEPA scoring requires all 16 screener items and sex information.",
      "x" = "Missing mappings: {paste(details, collapse = ', ')}.",
      "i" = "Use {.field sex}, {.field female}, or provide {.arg mepa_columns}."
    ))
  }

  duplicated_columns <- unique(data_names[index[duplicated(index)]])
  if (length(duplicated_columns) > 0L) {
    .abort_adult_scoring(c(
      "MEPA column mappings must resolve each field to a different column.",
      "x" = "Duplicated resolved column: {paste(duplicated_columns, collapse = ', ')}."
    ))
  }

  stats::setNames(data_names[index], names(requested))
}

.normalize_adult_mepa_sex <- function(sex, column) {
  supported_type <-
    is.character(sex) || is.factor(sex) || is.numeric(sex)
  if (!supported_type) {
    .abort_adult_scoring(c(
      "MEPA sex field {.field {column}} has an unsupported type.",
      "i" = "Use character labels, a factor, or numeric 0/1 values."
    ))
  }

  if (anyNA(sex)) {
    .abort_adult_scoring(
      "MEPA sex field {.field {column}} must be complete."
    )
  }

  labels <- tolower(trimws(as.character(sex)))
  if (any(labels == "")) {
    .abort_adult_scoring(
      "MEPA sex field {.field {column}} must not contain blank values."
    )
  }

  normalized <- rep(NA_character_, length(labels))
  normalized[labels %in% c("m", "male", "0")] <- "male"
  normalized[labels %in% c("f", "female", "1")] <- "female"

  unknown <- unique(labels[is.na(normalized)])
  if (length(unknown) > 0L) {
    .abort_adult_scoring(c(
      "MEPA sex field {.field {column}} contains unsupported values.",
      "x" = "Unsupported: {paste(unknown, collapse = ', ')}.",
      "i" = "Use m/f, male/female, or 0/1; 0 is male and 1 is female."
    ))
  }

  normalized
}

.validate_adult_mepa_inputs <- function(data, columns, rows) {
  for (item in .adult_mepa_item_columns()) {
    column <- columns[[item]]
    value <- data[[column]]
    .validate_adult_column_shape(data, column)

    if (!is.numeric(value)) {
      .abort_adult_scoring(
        "MEPA field {.field {item}} ({.field {column}}) must be numeric."
      )
    }

    applicable <- value[rows]
    if (anyNA(applicable) || any(!is.finite(applicable))) {
      .abort_adult_scoring(c(
        "MEPA field {.field {item}} must contain complete, finite values for MEPA rows.",
        "i" = "Missing-value MEPA scoring is not part of this implementation."
      ))
    }
    if (any(applicable < 0)) {
      .abort_adult_scoring(
        "MEPA field {.field {item}} cannot contain negative values."
      )
    }
  }

  sex_column <- columns[["sex"]]
  sex <- data[[sex_column]]
  .validate_adult_column_shape(data, sex_column)
  .normalize_adult_mepa_sex(sex[rows], sex_column)
}

.score_adult_mepa_items <- function(data, columns, rows, sex) {
  value <- function(item) {
    data[[columns[[item]]]][rows]
  }

  alcohol <- value("alcohol")

  cbind(
    olive_oil = value("olive_oil") >= 2,
    # Daily intake of 1 is equivalent to the source threshold of 7 per week.
    green_leafy_vegetables = value("green_leafy_vegetables") >= 1,
    other_vegetables = value("other_vegetables") >= 2,
    berries = value("berries") >= 2,
    # Weekly intake of 7 is equivalent to the source threshold of 1 per day.
    other_fruit = value("other_fruit") >= 7,
    meat = value("meat") <= 3,
    fish = value("fish") >= 1,
    chicken = value("chicken") <= 5,
    cheese = value("cheese") <= 4,
    butter_cream = value("butter_cream") <= 5,
    beans = value("beans") >= 3,
    whole_grains = value("whole_grains") >= 3,
    sweets_and_pastries = value("sweets_and_pastries") <= 4,
    nuts = value("nuts") >= 4,
    fast_food = value("fast_food") <= 1,
    alcohol = alcohol > 0 & (
      (sex == "male" & alcohol <= 14) |
        (sex == "female" & alcohol <= 7)
    )
  )
}

.compute_adult_mepa_total <- function(
  data,
  rows,
  mepa_columns = NULL,
  require_schema = any(rows)
) {
  total <- rep(NA_integer_, nrow(data))
  .normalize_adult_mepa_column_map(mepa_columns)

  if (!require_schema) {
    return(total)
  }

  columns <- .resolve_adult_mepa_columns(data, mepa_columns)
  sex <- .validate_adult_mepa_inputs(data, columns, rows)
  item_scores <- .score_adult_mepa_items(
    data,
    columns,
    rows,
    sex
  )
  total[rows] <- as.integer(rowSums(item_scores))

  total
}
