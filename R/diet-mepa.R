# MEPA screeners -----------------------------------------------------------------
#
# One set of MEPA inputs serves every age. Adults and children aged 6+ use the
# 16-item Table C screener and its adult bands. Younger children use the
# subsets suggested in Supplemental Appendix 2 of Lloyd-Jones et al. (2022),
# derived from the same columns plus `milk_source` (6-23 months):
#
#   screener   ages           items  points
#   adult      6+ years          16  adult bands (Table 1)
#   preschool  2-5 years         10  10 per item met
#   toddler    12-23 months       6  0-6 items -> 0, 25, 40, 55, 70, 85, 100
#   infant     6-11 months        6  as toddler
#
# For children under 6, `sweets_and_pastries` should include sugar-sweetened
# beverages, as the pediatric "sweets/SSB" item does.

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

.mepa_fields <- function() c(.adult_mepa_item_columns(), "sex", "milk_source")

.mepa_milk_sources <- function() c("human", "cow", "formula", "other")

.mepa_screeners <- function() {
  young_child_fields <- c(
    "green_leafy_vegetables", "other_vegetables", "berries", "other_fruit",
    "whole_grains", "sweets_and_pastries", "fast_food"
  )
  list(
    adult = list(
      months = c(72, Inf),
      fields = c(.adult_mepa_item_columns(), "sex")
    ),
    preschool = list(
      months = c(24, 72),
      fields = c(
        young_child_fields, "meat", "fish", "nuts", "olive_oil",
        "butter_cream"
      )
    ),
    toddler = list(months = c(12, 24), fields = c(young_child_fields, "milk_source")),
    infant = list(months = c(6, 12), fields = c(young_child_fields, "milk_source"))
  )
}

# Rows each screener applies to; adults always use the adult screener.
.mepa_screener_rows <- function(age) {
  lapply(.mepa_screeners(), function(screener) {
    rows <- .pediatric_ages(age, screener$months[[1]], screener$months[[2]])
    if (identical(screener$months[[2]], Inf)) rows <- rows | age$adult
    rows
  })
}

.score_mepa_diet <- function(data, age, mepa_columns, result) {
  screeners <- .mepa_screeners()
  rows <- .mepa_screener_rows(age)
  used <- names(screeners)[vapply(rows, any, logical(1))]
  needed <- unique(unlist(lapply(screeners[used], `[[`, "fields")))

  columns <- .resolve_mepa_columns(data, mepa_columns, needed)
  if (is.null(columns)) {
    return(result)
  }
  values <- .mepa_values(data, columns)

  for (screener in used) {
    screener_rows <- which(rows[[screener]])
    screener_values <- lapply(values, `[`, screener_rows)
    items <- .score_mepa_items(screener_values, screener)
    total <- as.integer(rowSums(items))
    result$mepa_total[screener_rows] <- total
    result$score[screener_rows] <- .score_mepa_total(total, screener)
  }
  result
}

.score_mepa_items <- function(value, screener) {
  if (screener == "adult") {
    return(.score_adult_mepa_items(value))
  }
  # Pediatric items, from the adult daily vegetable and weekly fruit items.
  vegetables_per_day <- value$green_leafy_vegetables + value$other_vegetables
  fruit_per_week <- value$berries + value$other_fruit
  milk <- value$milk_source
  switch(
    screener,
    preschool = cbind(
      vegetables = vegetables_per_day >= 2,
      fruit = fruit_per_week >= 14,            # 2 servings per day
      whole_grains = value$whole_grains >= 3,
      sweets_and_sugary_drinks = value$sweets_and_pastries <= 3,
      # 2 times per month, from weekly frequency (12 months / 52 weeks).
      fast_food = value$fast_food * 52 <= 2 * 12,
      red_and_processed_meat = value$meat <= 3,
      fish = value$fish >= 1,
      nuts_and_seeds = value$nuts >= 4,
      olive_oil = value$olive_oil >= 1,
      butter_cream = value$butter_cream <= 3
    ),
    toddler = cbind(
      vegetables = vegetables_per_day >= 2,
      fruit = fruit_per_week >= 14,
      whole_grains = value$whole_grains >= 2,
      sweets_and_sugary_drinks = value$sweets_and_pastries == 0,
      fast_food = value$fast_food == 0,
      milk_source = ifelse(is.na(milk), NA, milk %in% c("human", "cow"))
    ),
    infant = cbind(
      vegetables = vegetables_per_day >= 1,
      fruit = fruit_per_week >= 7,             # 1 serving per day
      whole_grains = value$whole_grains >= 1,
      sweets_and_sugary_drinks = value$sweets_and_pastries == 0,
      fast_food = value$fast_food == 0,
      milk_source = milk == "human"
    )
  )
}

.score_mepa_total <- function(total, screener) {
  switch(
    screener,
    adult = .score_adult_mepa_total(total),
    preschool = as.numeric(total * 10),
    c(0, 25, 40, 55, 70, 85, 100)[total + 1L]
  )
}

.score_adult_mepa_items <- function(value) {
  alcohol <- value$alcohol
  sex <- value$sex
  cbind(
    olive_oil = value$olive_oil >= 2,
    # Daily intake of 1 is equivalent to the source threshold of 7 per week.
    green_leafy_vegetables = value$green_leafy_vegetables >= 1,
    other_vegetables = value$other_vegetables >= 2,
    berries = value$berries >= 2,
    # Weekly intake of 7 is equivalent to the source threshold of 1 per day.
    other_fruit = value$other_fruit >= 7,
    meat = value$meat <= 3,
    fish = value$fish >= 1,
    chicken = value$chicken <= 5,
    cheese = value$cheese <= 4,
    butter_cream = value$butter_cream <= 5,
    beans = value$beans >= 3,
    whole_grains = value$whole_grains >= 3,
    sweets_and_pastries = value$sweets_and_pastries <= 4,
    nuts = value$nuts >= 4,
    fast_food = value$fast_food <= 1,
    alcohol = alcohol > 0 & (
      (sex == "male" & alcohol <= 14) |
        (sex == "female" & alcohol <= 7)
    )
  )
}

# Column resolution -------------------------------------------------------------

.normalize_mepa_column_map <- function(mepa_columns) {
  canonical <- .mepa_fields()
  resolved <- stats::setNames(canonical, canonical)

  if (is.null(mepa_columns) || length(mepa_columns) == 0L) {
    return(resolved)
  }

  if (!is.character(mepa_columns) || is.null(names(mepa_columns))) {
    .abort_input(c(
      "{.arg mepa_columns} must be a named character vector.",
      "i" = "Names identify canonical MEPA fields and values identify columns in {.arg data}."
    ))
  }

  map_names <- names(mepa_columns)
  if (anyNA(map_names) || any(map_names == "") ||
      anyNA(mepa_columns) || any(mepa_columns == "")) {
    .abort_input(
      "{.arg mepa_columns} must have complete, nonempty names and values."
    )
  }

  normalized_names <- tolower(map_names)
  duplicated_names <- unique(normalized_names[duplicated(normalized_names)])
  if (length(duplicated_names) > 0L) {
    .abort_input(c(
      "{.arg mepa_columns} contains duplicated canonical fields.",
      "x" = "Duplicated after case normalization: {paste(duplicated_names, collapse = ', ')}."
    ))
  }

  unknown <- setdiff(normalized_names, canonical)
  if (length(unknown) > 0L) {
    .abort_input(c(
      "{.arg mepa_columns} contains unsupported canonical fields.",
      "x" = "Unsupported: {paste(unknown, collapse = ', ')}.",
      "i" = "Use MEPA screener-item labels in snake_case, plus {.field sex} and {.field milk_source}."
    ))
  }

  resolved[normalized_names] <- unname(mepa_columns)
  normalized_targets <- tolower(unname(resolved))
  duplicated_targets <- unique(
    unname(resolved)[duplicated(normalized_targets)]
  )
  if (length(duplicated_targets) > 0L) {
    .abort_input(c(
      "{.arg mepa_columns} must map each MEPA field to a different column.",
      "x" = "Duplicated target after case normalization: {paste(duplicated_targets, collapse = ', ')}."
    ))
  }

  resolved
}

# Returns the data column for each canonical field found in `data`, or NULL
# when no screener item is supplied (the diet component is then structurally
# missing). Once any item is present, every field in `needed` (set by the ages
# in `data`) must resolve: a missing one is almost always a misspelling, so it
# is an error rather than a batch of silently missing scores.
.resolve_mepa_columns <- function(data, mepa_columns, needed) {
  requested <- .normalize_mepa_column_map(mepa_columns)
  data_names <- names(data)
  index <- .mepa_column_index(data_names, requested)

  explicitly_mapped <- tolower(names(mepa_columns))
  item_found <- !is.na(index[.adult_mepa_item_columns()])
  missing <- names(index)[is.na(index) &
    names(index) %in% c(needed, explicitly_mapped)]
  if (!any(item_found) && !any(missing %in% explicitly_mapped)) {
    return(NULL)
  }
  if (length(missing) > 0L) {
    details <- paste0(missing, " -> ", unname(requested[missing]))
    .abort_input(c(
      "MEPA scoring requires every screener field used at the ages in {.arg data}.",
      "x" = "Missing mappings: {paste(details, collapse = ', ')}.",
      "i" = "Use {.field sex}, {.field female}, or provide {.arg mepa_columns}."
    ))
  }

  found <- index[!is.na(index)]
  duplicated_columns <- unique(data_names[found[duplicated(found)]])
  if (length(duplicated_columns) > 0L) {
    .abort_input(c(
      "MEPA column mappings must resolve each field to a different column.",
      "x" = "Duplicated resolved column: {paste(duplicated_columns, collapse = ', ')}."
    ))
  }

  stats::setNames(data_names[found], names(found))
}

.mepa_column_index <- function(data_names, requested = .normalize_mepa_column_map(NULL)) {
  index <- stats::setNames(
    match(tolower(unname(requested)), tolower(data_names)),
    names(requested)
  )
  if (is.na(index[["sex"]]) && tolower(requested[["sex"]]) == "sex") {
    index[["sex"]] <- match("female", tolower(data_names))
  }
  index
}

# Validated values for every resolved field, keyed by canonical name.
.mepa_values <- function(data, columns) {
  values <- lapply(names(columns), function(field) {
    column <- columns[[field]]
    .check_column_shape(data, column)
    switch(
      field,
      sex = .normalize_adult_mepa_sex(data[[column]], column),
      milk_source = .normalize_milk_source(data[[column]], column),
      .check_mepa_item(data[[column]], field, column)
    )
  })
  stats::setNames(values, names(columns))
}

.check_mepa_item <- function(value, item, column) {
  value <- .coerce_all_na_logical(value, "numeric")
  if (!is.numeric(value)) {
    .abort_input(
      "MEPA field {.field {item}} ({.field {column}}) must be numeric."
    )
  }
  if (any(!is.finite(value[!is.na(value)]))) {
    .abort_input(
      "Observed values in MEPA field {.field {item}} must be finite."
    )
  }
  if (any(value < 0, na.rm = TRUE)) {
    .abort_input(
      "MEPA field {.field {item}} cannot contain negative values."
    )
  }
  as.numeric(value)
}

.normalize_milk_source <- function(value, column) {
  value <- .coerce_all_na_logical(value, "character")
  if (!is.character(value) && !is.factor(value)) {
    .abort_input("MEPA field {.field {column}} must be character or factor.")
  }
  value <- tolower(trimws(as.character(value)))
  .check_choices(value, column, .mepa_milk_sources())
  value
}

.normalize_adult_mepa_sex <- function(sex, column) {
  .normalize_sex(sex, column, label = "MEPA sex field")
}

# Accepts m/f, male/female, 0/1 (0 = male), or a logical column named
# `female`; returns "male", "female", or NA.
.normalize_sex <- function(sex, column, label = "Sex field") {
  # A logical column is unambiguous only when it is named `female`.
  if (is.logical(sex) && tolower(column) == "female") {
    return(ifelse(sex, "female", "male"))
  }
  if (is.logical(sex) && all(is.na(sex))) {
    return(rep(NA_character_, length(sex)))
  }
  supported_type <-
    is.character(sex) || is.factor(sex) || is.numeric(sex)
  if (!supported_type) {
    .abort_input(c(
      "{label} {.field {column}} has an unsupported type.",
      "i" = "Use character labels, a factor, numeric 0/1 values, or a logical {.field female} column."
    ))
  }

  labels <- tolower(trimws(as.character(sex)))
  if (any(labels == "", na.rm = TRUE)) {
    .abort_input(
      "{label} {.field {column}} must not contain blank values."
    )
  }

  normalized <- rep(NA_character_, length(labels))
  normalized[labels %in% c("m", "male", "0")] <- "male"
  normalized[labels %in% c("f", "female", "1")] <- "female"

  unknown <- unique(labels[!is.na(labels) & is.na(normalized)])
  if (length(unknown) > 0L) {
    .abort_input(c(
      "{label} {.field {column}} contains unsupported values.",
      "x" = "Unsupported: {paste(unknown, collapse = ', ')}.",
      "i" = "Use m/f, male/female, or 0/1; 0 is male and 1 is female."
    ))
  }

  normalized
}

