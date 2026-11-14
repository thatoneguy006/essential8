#' Prepare LE8 inputs for multiple imputation with mice
#'
#' @description
#' `le8_imputation_setup()` returns the settings [mice::mice()] needs to
#' multiply impute missing [score_le8()] inputs in a way the AHA scoring rules
#' can use. `score_le8(impute = TRUE)` uses them to impute and score in one
#' call; call `le8_imputation_setup()` yourself to inspect the settings, or to
#' adjust them and run mice directly, then score the result with
#' [score_le8_imputed()].
#'
#' Imputing the inputs, rather than the 0-100 scores, keeps the relationships
#' between measurements that the AHA bands then summarize. The setup encodes
#' what is specific to LE8:
#'
#' * **Only inputs a person's age uses are imputed.** For example, adult BMI is
#'   never imputed for a child, nor blood-pressure percentile thresholds for an
#'   adult, nor a MEPA item that a preschooler's screener does not include.
#'   Observed values in such structurally unused cells are set to `NA` in the
#'   prepared data so they cannot distort the imputation models.
#'   `years_since_quit` is imputed only for adults who are, or may be imputed
#'   as, former smokers.
#' * **Predictors are limited to inputs available (observed or imputed) for
#'   everyone the target applies to**, plus `age` and any `auxiliary` columns,
#'   so no model relies on structurally missing values.
#' * **Methods:** predictive mean matching (`"pmm"`) for numeric inputs, which
#'   imputes only observed values and so respects their range and skew;
#'   logistic regression (`"logreg"`) for two-level inputs; and multinomial
#'   regression (`"polyreg"`) otherwise. Logical and character inputs are
#'   converted to factors for mice; [score_le8_imputed()] converts them back.
#' * **Combinations AHA does not score are never imputed.** Diagnosed
#'   diabetes implies an HbA1c measure. Current combustible smoking is never
#'   paired with current inhaled-NDS use. An observed fasting glucose implies
#'   no diagnosed diabetes, and an observed HbA1c of 6.5% or more implies
#'   diagnosed diabetes. Each imputed glucose value comes from donors with
#'   the same measure and diabetes status, and a measure is imputed only if
#'   such donors exist. These rules run in mice's `post`
#'   step of every iteration, so the other imputation models condition on
#'   consistent values.
#'
#' Two values that follow from observed data are filled in before imputation
#' (deductive imputation): `glucose_measure` is `"hba1c"` when `diabetes` is
#' `TRUE`, and `current_inhaled_nds` is `FALSE` for current smokers.
#'
#' @details
#' Observed values are validated with [score_le8()] first, so data that cannot
#' be scored stop here rather than after imputation. Every observed
#' `glucose_value` needs its `glucose_measure`.
#'
#' Only the MEPA diet screener is supported. Inputs must use the default
#' column names, and `age` must be complete.
#'
#' With adults and children in one data set, inputs that apply to only one
#' population cannot predict inputs that apply to both. To use richer models,
#' impute each population separately and combine the results with
#' `rbind()`, which mice provides for `mids` objects.
#'
#' Imputation models should include the variables used in later analyses,
#' such as exposures and outcomes. Pass them in `auxiliary`.
#'
#' `score_le8(impute = TRUE)` calls `mice::mice()` with
#' `remove.collinear = FALSE` and `remove.constant = FALSE`. mice's defaults
#' would stop imputing an input that is constant or collinear in the observed
#' data, leaving values that scoring needs missing. Each imputation model still
#' drops such predictors on its own. When calling `mice::mice()` directly with
#' a setup, pass the same two arguments.
#'
#' Glucose values mix units (mg/dL for fasting glucose, % for HbA1c), so
#' `glucose_measure` and `glucose_value` predict only each other; `diabetes`
#' represents glucose status in the other models.
#'
#' @param data A data frame of [score_le8()] inputs.
#' @param auxiliary Optional character vector of other columns in `data` to
#'   use as predictors, such as analysis outcomes, exposures, or survey design
#'   variables. They must be complete; they are not imputed.
#' @param diet_method The diet scoring method; only `"mepa"` is supported.
#' @return An `essential8_imputation_setup` object, a list with the prepared
#'   `data` and the mice arguments `method`, `predictorMatrix`, `where`,
#'   `visitSequence`, and `post`, plus `inputs`, a data frame describing each
#'   input: the rows it applies to, the values to impute, and the method.
#' @seealso [score_le8()] and its `impute` argument to impute and score in one
#'   call; [le8_imputation_control()]; [score_le8_imputed()] to score your own
#'   mice run.
#' @examplesIf requireNamespace("mice", quietly = TRUE)
#' adults <- read.csv(system.file(
#'   "extdata", "le8-adult-example.csv", package = "essential8"
#' ))
#' adults <- adults[!startsWith(names(adults), "expected_")]
#' adults$non_hdl_cholesterol[c(2, 5)] <- NA
#' adults$sleep_hours[3] <- NA
#'
#' setup <- le8_imputation_setup(adults)
#' setup
#'
#' # Adjust the settings, then run mice yourself: here, sleep hours are no
#' # longer predicted from age. Keep predictive mean matching for numeric
#' # inputs; methods such as "norm" can impute values outside their valid
#' # range, which score_le8() then rejects.
#' setup$predictorMatrix["sleep_hours", "age"] <- 0
#' imputed <- mice::mice(
#'   setup$data,
#'   m = 5,
#'   method = setup$method,
#'   predictorMatrix = setup$predictorMatrix,
#'   where = setup$where,
#'   visitSequence = setup$visitSequence,
#'   post = setup$post,
#'   remove.collinear = FALSE,
#'   remove.constant = FALSE,
#'   seed = 1,
#'   printFlag = FALSE
#' )
#' summary(score_le8_imputed(imputed))
#' @export
le8_imputation_setup <- function(data, auxiliary = NULL, diet_method = "mepa") {
  call <- rlang::current_env()
  .check_imputation_data(data, auxiliary, diet_method, call = call)

  prepared <- as.data.frame(data, stringsAsFactors = FALSE)
  age <- .le8_age(prepared)
  usage <- .le8_input_usage(age)
  inputs <- intersect(names(usage), names(prepared))

  # Structurally unused values play no part in scoring; blank them so they
  # cannot enter an imputation model.
  for (column in inputs) {
    prepared[[column]][!usage[[column]]] <- NA
  }
  deduced <- .deduce_le8_inputs(prepared)
  prepared <- deduced$data
  prepared <- .le8_inputs_as_factors(prepared, inputs)
  for (column in auxiliary) {
    if (is.character(prepared[[column]]) || is.logical(prepared[[column]])) {
      prepared[[column]] <- factor(prepared[[column]])
    }
  }

  columns <- names(prepared)
  where <- matrix(
    FALSE,
    nrow = nrow(prepared),
    ncol = length(columns),
    dimnames = list(NULL, columns)
  )
  # Rows each input is needed for: its age band and, for years_since_quit,
  # adults who are, or may be imputed as, former smokers.
  needed <- usage[inputs]
  if ("years_since_quit" %in% inputs) {
    status <- as.character(prepared$smoking_status)
    needed$years_since_quit <- needed$years_since_quit &
      (is.na(status) | status == "former")
  }
  for (column in inputs) {
    where[, column] <- is.na(prepared[[column]]) & needed[[column]]
  }

  observed_used <- vapply(
    inputs,
    function(column) any(!is.na(prepared[[column]]) & usage[[column]]),
    logical(1)
  )
  # Without observed values there is nothing to draw from.
  where[, inputs[!observed_used]] <- FALSE
  targets <- inputs[colSums(where[, inputs, drop = FALSE]) > 0L]

  method <- stats::setNames(rep("", length(columns)), columns)
  method[targets] <- vapply(
    targets,
    function(column) .le8_imputation_method(prepared[[column]]),
    character(1)
  )

  predictor_matrix <- matrix(
    0L,
    nrow = length(columns),
    ncol = length(columns),
    dimnames = list(columns, columns)
  )
  # A predictor must be observed or imputed in every row the target is needed
  # for; mice would otherwise skip those rows.
  candidates <- c(inputs[observed_used], "age", auxiliary)
  available <- !is.na(prepared[candidates]) | where[, candidates, drop = FALSE]
  # Glucose values mix units (mg/dL and %), so the glucose measure and value
  # predict only each other; diabetes carries glucose status for the rest.
  glucose_pair <- c("glucose_measure", "glucose_value")
  for (target in targets) {
    rows <- needed[[target]]
    complete_in_rows <- colSums(!available[rows, , drop = FALSE]) == 0L
    predictors <- setdiff(candidates[complete_in_rows], target)
    predictors <- switch(
      target,
      glucose_value = predictors,
      glucose_measure = setdiff(predictors, "glucose_value"),
      setdiff(predictors, glucose_pair)
    )
    predictor_matrix[target, predictors] <- 1L
  }

  post <- stats::setNames(rep("", length(columns)), columns)
  constrained <- intersect(.le8_post_columns(), targets)
  post[constrained] <- sprintf(
    "imp[[j]][, i] <- essential8:::.le8_post_impute(%s, imp[[j]][, i], data, r, where)",
    encodeString(constrained, quote = "\"")
  )

  summary <- data.frame(
    input = inputs,
    applies_to = vapply(inputs, function(x) sum(needed[[x]]), integer(1)),
    missing = vapply(
      inputs,
      function(x) sum(is.na(prepared[[x]]) & needed[[x]]),
      integer(1)
    ),
    impute = unname(colSums(where[, inputs, drop = FALSE])),
    method = unname(method[inputs]),
    row.names = NULL
  )
  summary <- summary[summary$applies_to > 0L, , drop = FALSE]

  structure(
    list(
      data = prepared,
      method = method,
      predictorMatrix = predictor_matrix,
      where = where,
      visitSequence = .le8_visit_sequence(targets),
      post = post,
      inputs = summary,
      deduced = deduced$counts,
      auxiliary = auxiliary
    ),
    class = "essential8_imputation_setup"
  )
}

#' Options for imputing missing LE8 inputs
#'
#' @description
#' Sets how [score_le8()] imputes missing inputs when `impute` is used. Pass
#' the result as `score_le8(impute = le8_imputation_control(...))`;
#' `impute = TRUE` uses the defaults.
#'
#' @param m Number of imputed data sets, at least 2. A common rule of thumb
#'   for final analyses is at least as many imputations as the percentage of
#'   participants with any missing input.
#' @param maxit Number of mice iterations.
#' @param seed A whole number to make the imputations reproducible, or `NA`
#'   (the default) to use the session's random number stream.
#' @param auxiliary Optional character vector of other complete columns to use
#'   as predictors, such as analysis outcomes, exposures, or survey design
#'   variables; see [le8_imputation_setup()].
#' @param ... Further arguments to [mice::mice()], such as `printFlag = TRUE`
#'   to show mice's iteration log. Arguments with the same names as the
#'   imputation settings (for example, `method` or `predictorMatrix`) replace
#'   them.
#' @return An `essential8_imputation_control` object.
#' @seealso [score_le8()], [le8_imputation_setup()]
#' @examples
#' le8_imputation_control(m = 50, seed = 2026)
#' @export
le8_imputation_control <- function(
  m = 20,
  maxit = 5,
  seed = NA,
  auxiliary = NULL,
  ...
) {
  call <- rlang::current_env()
  abort_control <- function(message) {
    cli::cli_abort(
      message,
      class = c("essential8_imputation_error", "essential8_error"),
      call = call
    )
  }
  if (!rlang::is_scalar_integerish(m, finite = TRUE) || m < 2) {
    abort_control("{.arg m} must be a whole number of at least 2.")
  }
  if (!rlang::is_scalar_integerish(maxit, finite = TRUE) || maxit < 1) {
    abort_control("{.arg maxit} must be a positive whole number.")
  }
  if (!identical(seed, NA) && !rlang::is_scalar_integerish(seed, finite = TRUE)) {
    abort_control("{.arg seed} must be a single whole number or {.code NA}.")
  }
  if (!is.null(auxiliary) && (!is.character(auxiliary) || anyNA(auxiliary))) {
    abort_control("{.arg auxiliary} must be a character vector of column names.")
  }
  mice_args <- rlang::list2(...)
  if (length(mice_args) > 0L) {
    arg_names <- names(mice_args) %||% rep("", length(mice_args))
    if (any(arg_names == "")) {
      abort_control("Arguments in {.arg ...} must be named; they are passed to {.fn mice::mice}.")
    }
    fixed <- intersect(arg_names, c("data", "m", "maxit", "seed"))
    if (length(fixed) > 0L) {
      abort_control("Set {.arg {fixed}} with the arguments of {.fn le8_imputation_control}, not {.arg ...}.")
    }
  }
  structure(
    list(
      m = as.integer(m),
      maxit = as.integer(maxit),
      seed = seed,
      auxiliary = auxiliary,
      mice_args = mice_args
    ),
    class = "essential8_imputation_control"
  )
}

#' @export
print.essential8_imputation_control <- function(x, ...) {
  cat(
    "LE8 imputation: m = ", x$m, ", maxit = ", x$maxit,
    ", seed = ", format(x$seed),
    if (length(x$auxiliary) > 0L) paste0(", auxiliary = ", paste(x$auxiliary, collapse = ", ")),
    if (length(x$mice_args) > 0L) paste0("; mice arguments: ", paste(names(x$mice_args), collapse = ", ")),
    "\n",
    sep = ""
  )
  invisible(x)
}

# Resolves score_le8()'s `impute` argument to imputation options, or NULL.
.resolve_impute <- function(impute, call = rlang::caller_env()) {
  if (isFALSE(impute)) {
    return(NULL)
  }
  if (isTRUE(impute)) {
    return(le8_imputation_control())
  }
  if (inherits(impute, "essential8_imputation_control")) {
    return(impute)
  }
  cli::cli_abort(
    c(
      "{.arg impute} must be {.code TRUE}, {.code FALSE}, or {.fn le8_imputation_control}.",
      "x" = "You supplied {.obj_type_friendly {impute}}."
    ),
    class = c("essential8_imputation_error", "essential8_error"),
    call = call
  )
}

# score_le8(impute = ): impute the inputs, then score the stacked imputations.
.score_le8_with_imputation <- function(data, control, score_args, call) {
  rlang::check_installed("mice", reason = "to impute LE8 inputs.")
  if (!is.null(score_args$mepa_columns)) {
    cli::cli_abort(
      c(
        "{.arg impute} needs the default MEPA column names.",
        "i" = "Rename the columns instead of using {.arg mepa_columns}."
      ),
      class = c("essential8_imputation_error", "essential8_error"),
      call = call
    )
  }
  setup <- le8_imputation_setup(
    data,
    auxiliary = control$auxiliary,
    diet_method = score_args$diet_method
  )

  if (all(setup$method == "")) {
    cli::cli_inform(
      c(
        "i" = "No missing inputs needed imputing; each of the {control$m} data sets is the observed data."
      ),
      class = "essential8_imputation_message"
    )
    observed <- as.data.frame(data)
    n <- nrow(observed)
    # Same layout as mice::complete(action = "long"): .imp and .id last.
    stacked <- observed[rep(seq_len(n), control$m), , drop = FALSE]
    stacked$.imp <- rep(seq_len(control$m), each = n)
    stacked$.id <- rep(seq_len(n), control$m)
    rownames(stacked) <- NULL
    imputed <- NULL
  } else {
    args <- c(
      list(
        data = setup$data,
        m = control$m,
        maxit = control$maxit,
        seed = control$seed,
        printFlag = FALSE
      ),
      .le8_mice_arguments(setup)
    )
    args[names(control$mice_args)] <- control$mice_args
    # Evaluate by name so the stored call does not embed a copy of the data.
    arg_env <- rlang::new_environment(args, parent = baseenv())
    mice_call <- rlang::call2(
      quote(mice::mice),
      !!!rlang::set_names(rlang::syms(names(args)), names(args))
    )
    imputed <- eval(mice_call, arg_env)
    .warn_unimputed(imputed, setup)
    stacked <- mice::complete(imputed, action = "long", include = FALSE)
  }

  if (inherits(data, "tbl_df")) {
    stacked <- tibble::as_tibble(stacked)
  }
  scores <- do.call(
    score_le8_imputed,
    c(list(stacked), score_args[setdiff(names(score_args), "mepa_columns")])
  )
  attr(scores, "mids") <- imputed
  scores
}

# The mice arguments a setup implies. mice's global removal of constant or
# collinear variables would also stop imputing them, leaving required LE8
# inputs missing; each model still drops such predictors on its own.
.le8_mice_arguments <- function(setup) {
  list(
    method = setup$method,
    predictorMatrix = setup$predictorMatrix,
    where = setup$where,
    visitSequence = setup$visitSequence,
    post = setup$post,
    remove.collinear = FALSE,
    remove.constant = FALSE
  )
}

.warn_unimputed <- function(imputed, setup) {
  targets <- names(setup$method)[setup$method != ""]
  missing <- vapply(
    targets,
    function(column) sum(is.na(imputed$imp[[column]])),
    numeric(1)
  )
  missing <- missing[missing > 0]
  if (length(missing) > 0L) {
    cli::cli_warn(
      c(
        "Some LE8 inputs were not fully imputed.",
        "x" = "Still missing: {paste0(names(missing), ' (', missing, ')', collapse = ', ')}.",
        "i" = "Check {.code imputed$loggedEvents} and the imputation settings."
      ),
      class = c("essential8_imputation_warning", "essential8_warning")
    )
  }
  invisible(missing)
}

#' @export
print.essential8_imputation_setup <- function(x, ...) {
  inputs <- x$inputs
  n_impute <- sum(inputs$impute)
  cat(
    "LE8 imputation setup: ", nrow(x$data), " rows; ",
    n_impute, " missing input value", if (n_impute != 1L) "s",
    " to impute in ", sum(inputs$impute > 0L), " input",
    if (sum(inputs$impute > 0L) != 1L) "s", "\n",
    sep = ""
  )
  if (length(x$auxiliary) > 0L) {
    cat("Auxiliary predictors: ", paste(x$auxiliary, collapse = ", "), "\n", sep = "")
  }
  deduced <- x$deduced[x$deduced > 0L]
  if (length(deduced) > 0L) {
    cat(
      "Filled in from observed values: ",
      paste0(names(deduced), " (", deduced, ")", collapse = ", "),
      "\n",
      sep = ""
    )
  }
  shown <- inputs[inputs$missing > 0L, , drop = FALSE]
  if (nrow(shown) > 0L) {
    cat("\n")
    shown$method[shown$impute == 0L] <- "(no observed values)"
    print(shown, row.names = FALSE)
  }
  invisible(x)
}

# Inputs each row's age uses, from the same age bands as the scorers. A cell
# outside these is structurally missing: AHA does not use it for that person.
.le8_input_usage <- function(age) {
  n <- length(age$adult)
  everyone <- rep(TRUE, n)
  adult <- age$adult
  ped <- function(lower, upper) .pediatric_ages(age, lower, upper)
  school_age_or_adult <- adult | ped(72, Inf)
  bp_ages <- adult | ped(12, Inf)

  usage <- list(
    moderate_activity_minutes = school_age_or_adult,
    vigorous_activity_minutes = school_age_or_adult,
    active_play_minutes = ped(12, 72),
    smoking_status = everyone,
    years_since_quit = adult,
    current_inhaled_nds = everyone,
    secondhand_smoke_home = everyone,
    sleep_hours = everyone,
    bmi = adult,
    bmi_profile = adult,
    bmi_percentile = ped(24, 240),
    bmi_percent_of_p95 = ped(24, 240),
    infant_weight_percentile = ped(4, 24),
    infant_weight_z_change = ped(6, 24),
    non_hdl_cholesterol = everyone,
    lipid_lowering_treatment = everyone,
    diabetes = everyone,
    glucose_measure = everyone,
    glucose_value = everyone,
    systolic_bp = bp_ages,
    diastolic_bp = bp_ages,
    antihypertensive_treatment = bp_ages,
    systolic_bp_p90 = ped(12, 156),
    systolic_bp_p95 = ped(12, 156),
    diastolic_bp_p90 = ped(12, 156),
    diastolic_bp_p95 = ped(12, 156)
  )

  screeners <- .mepa_screeners()
  screener_rows <- .mepa_screener_rows(age)
  for (field in .mepa_fields()) {
    rows <- rep(FALSE, n)
    for (screener in names(screeners)) {
      if (field %in% screeners[[screener]]$fields) {
        rows <- rows | screener_rows[[screener]]
      }
    }
    usage[[field]] <- rows
  }
  usage
}

.check_imputation_data <- function(data, auxiliary, diet_method, call) {
  if (!is.data.frame(data)) {
    cli::cli_abort(
      "{.arg data} must be a data frame.",
      class = c("essential8_imputation_error", "essential8_error"),
      call = call
    )
  }
  if (!identical(diet_method, "mepa")) {
    cli::cli_abort(
      c(
        "Imputation setup supports only {.code diet_method = \"mepa\"}.",
        "i" = "Impute other diet inputs with your own {.pkg mice} settings."
      ),
      class = c("essential8_imputation_error", "essential8_error"),
      call = call
    )
  }
  if (!"age" %in% names(data) || anyNA(data$age)) {
    cli::cli_abort(
      c(
        "{.field age} must be present and complete.",
        "i" = "Age decides which AHA definitions, and so which inputs, apply."
      ),
      class = c("essential8_imputation_error", "essential8_error"),
      call = call
    )
  }
  if (!is.null(auxiliary)) {
    if (!is.character(auxiliary) || anyNA(auxiliary)) {
      cli::cli_abort(
        "{.arg auxiliary} must be a character vector of column names.",
        class = c("essential8_imputation_error", "essential8_error"),
        call = call
      )
    }
    unknown <- setdiff(auxiliary, names(data))
    reserved <- intersect(auxiliary, c("age", .le8_input_spec()$column, .mepa_fields()))
    incomplete <- auxiliary[vapply(
      intersect(auxiliary, names(data)),
      function(column) anyNA(data[[column]]),
      logical(1)
    )]
    problems <- c(
      "x" = if (length(unknown) > 0L) "Not found: {.field {unknown}}.",
      "x" = if (length(reserved) > 0L) "Already LE8 inputs: {.field {reserved}}.",
      "x" = if (length(incomplete) > 0L) "Contain missing values: {.field {incomplete}}."
    )
    if (length(problems) > 0L) {
      cli::cli_abort(
        c("{.arg auxiliary} must name other complete columns of {.arg data}.", problems),
        class = c("essential8_imputation_error", "essential8_error"),
        call = call
      )
    }
  }
  if (all(c("glucose_value", "glucose_measure") %in% names(data))) {
    unlabeled <- !is.na(data$glucose_value) & is.na(data$glucose_measure)
    if (any(unlabeled)) {
      cli::cli_abort(
        c(
          "Every observed {.field glucose_value} needs its {.field glucose_measure}.",
          "x" = "{sum(unlabeled)} row{?s} {?has/have} a value but no measure.",
          "i" = "Record whether each value is fasting glucose or HbA1c; it cannot be imputed."
        ),
        class = c("essential8_imputation_error", "essential8_error"),
        call = call
      )
    }
  }
  # Observed values must already be scoreable.
  suppressMessages(suppressWarnings(
    score_le8(
      .drop_le8_scores_class(as.data.frame(data)),
      diet_method = diet_method,
      min_components = 1
    )
  ))
  invisible()
}

# Values that follow from observed data under the scoring rules.
.deduce_le8_inputs <- function(data) {
  counts <- c(glucose_measure = 0L, current_inhaled_nds = 0L)
  if (all(c("diabetes", "glucose_measure") %in% names(data))) {
    rows <- which(data$diabetes %in% TRUE & is.na(data$glucose_measure))
    data$glucose_measure[rows] <- "hba1c"
    counts[["glucose_measure"]] <- length(rows)
  }
  if (all(c("smoking_status", "current_inhaled_nds") %in% names(data))) {
    rows <- which(
      as.character(data$smoking_status) %in% "current" &
        is.na(data$current_inhaled_nds)
    )
    data$current_inhaled_nds[rows] <- FALSE
    counts[["current_inhaled_nds"]] <- length(rows)
  }
  list(data = data, counts = counts)
}

.le8_categorical_levels <- function() {
  c(
    .le8_choices(),
    list(sex = c("female", "male"), milk_source = .mepa_milk_sources())
  )
}

.le8_inputs_as_factors <- function(data, inputs) {
  levels <- .le8_categorical_levels()
  for (column in intersect(inputs, .le8_inputs_of_type("logical"))) {
    data[[column]] <- factor(data[[column]], levels = c(FALSE, TRUE))
  }
  for (column in intersect(inputs, names(levels))) {
    value <- switch(
      column,
      sex = .normalize_sex(data[[column]], column),
      milk_source = .normalize_milk_source(data[[column]], column),
      as.character(data[[column]])
    )
    data[[column]] <- factor(value, levels = levels[[column]])
  }
  data
}

# Converts factors from mice back to the types score_le8() validates.
.le8_inputs_from_factors <- function(data) {
  for (column in intersect(.le8_inputs_of_type("logical"), names(data))) {
    if (is.factor(data[[column]]) || is.character(data[[column]])) {
      data[[column]] <- as.logical(as.character(data[[column]]))
    }
  }
  for (column in intersect(names(.le8_categorical_levels()), names(data))) {
    if (is.factor(data[[column]])) {
      data[[column]] <- as.character(data[[column]])
    }
  }
  data
}

.le8_imputation_method <- function(value) {
  if (is.factor(value)) {
    if (nlevels(value) == 2L) "logreg" else "polyreg"
  } else {
    "pmm"
  }
}

# Constrained inputs are visited in dependency order, ahead of the rest.
.le8_post_columns <- function() {
  c("smoking_status", "current_inhaled_nds", "diabetes", "glucose_measure", "glucose_value")
}

.le8_visit_sequence <- function(targets) {
  # mice reads a single string as a keyword ("roman", ...), and one target
  # needs no ordering, so leave mice's default.
  if (length(targets) < 2L) {
    return(NULL)
  }
  first <- intersect(.le8_post_columns(), targets)
  c(first, setdiff(targets, first))
}

# mice post-processing ---------------------------------------------------------
#
# Called from the `post` strings set up above, inside mice's sampler, after
# each variable is imputed. `values` are the current imputations for the rows
# where `where[, column]` is TRUE; `data` holds the current completed values and
# `r` the observed-data indicator.

.le8_post_impute <- function(column, values, data, r, where) {
  rows <- which(where[, column])
  if (length(rows) == 0L) {
    return(values)
  }
  observed <- function(name) {
    if (!name %in% colnames(r)) {
      return(rep(FALSE, nrow(data)))
    }
    r[, name]
  }
  current <- function(name) {
    if (!name %in% names(data)) {
      return(rep(NA_character_, nrow(data)))
    }
    as.character(data[[name]])
  }
  draw <- function(pool, size) pool[sample.int(length(pool), size, replace = TRUE)]
  out <- as.character(values)

  if (column == "current_inhaled_nds") {
    out[current("smoking_status")[rows] %in% "current"] <- "FALSE"
  } else if (column == "smoking_status") {
    nds_observed <- observed("current_inhaled_nds") &
      current("current_inhaled_nds") %in% "TRUE"
    conflict <- nds_observed[rows] & out %in% "current"
    if (any(conflict)) {
      status <- current("smoking_status")
      pool <- status[observed("smoking_status") & nds_observed]
      if (length(pool) == 0L) {
        pool <- status[observed("smoking_status") & !status %in% "current"]
      }
      if (length(pool) == 0L) {
        pool <- c("never", "former")
      }
      out[conflict] <- draw(pool, sum(conflict))
    }
  } else if (column == "diabetes") {
    measure <- current("glucose_measure")
    value <- suppressWarnings(as.numeric(current("glucose_value")))
    measure_observed <- observed("glucose_measure")
    out[(measure_observed & measure %in% "fasting_glucose")[rows]] <- "FALSE"
    diagnostic <- measure_observed & observed("glucose_value") &
      measure %in% "hba1c" & value >= 6.5
    out[diagnostic[rows]] <- "TRUE"
  } else if (column == "glucose_measure") {
    diabetes <- current("diabetes") %in% "TRUE"
    out[diabetes[rows]] <- "hba1c"
    # A measure is only usable with observed values to draw from for the
    # same diabetes status; otherwise take the other measure.
    donor_rows <- observed("glucose_value")
    has_donors <- function(measure, diabetic) {
      any(donor_rows & current("glucose_measure") == measure & diabetes == diabetic)
    }
    for (i in seq_along(rows)[!diabetes[rows]]) {
      other <- setdiff(c("fasting_glucose", "hba1c"), out[i])
      if (!has_donors(out[i], FALSE) && has_donors(other, FALSE)) {
        out[i] <- other
      }
    }
  } else if (column == "glucose_value") {
    out <- .le8_post_glucose_value(as.numeric(values), rows, data, observed("glucose_value"))
    return(out)
  }

  if (is.factor(values)) {
    factor(out, levels = levels(values))
  } else if (is.logical(values)) {
    as.logical(out)
  } else {
    out
  }
}

# Each imputed glucose value must come from a donor with the same measure and
# diabetes status: the measures have different units, and a diagnostic-range
# value without diagnosed diabetes cannot be scored. Predictive mean matching
# almost always draws such a donor; any other draw is replaced by a random
# donor from the matching stratum.
.le8_post_glucose_value <- function(values, rows, data, observed) {
  stratum <- paste(
    as.character(data$glucose_measure),
    as.character(data$diabetes) %in% "TRUE"
  )
  donors <- split(data$glucose_value[observed], stratum[observed])
  for (key in unique(stratum[rows])) {
    in_stratum <- which(stratum[rows] == key)
    pool <- donors[[key]]
    if (is.null(pool) || length(pool) == 0L) {
      values[in_stratum] <- NA_real_
      next
    }
    invalid <- in_stratum[!values[in_stratum] %in% pool]
    values[invalid] <- pool[sample.int(length(pool), length(invalid), replace = TRUE)]
  }
  values
}

#' Score multiply imputed LE8 inputs
#'
#' @description
#' Scores every completed data set from a multiple imputation and returns
#' them stacked, with the imputation number in `.imp`. Methods for the result
#' pool across imputations with Rubin's rules: [summary()] and, with dplyr,
#' [summarise()] report pooled means with confidence intervals, and
#' `plot(type = "forest")` draws pooled intervals.
#'
#' @param data A `mids` object from [mice::mice()] (for example, run with the
#'   settings from [le8_imputation_setup()]), or a data frame of stacked
#'   completed data sets with an integer `.imp` column numbering them from 1
#'   (for example, from `mice::complete(imputed, "long")` or another
#'   imputation package). To impute and score in one call, use
#'   `score_le8(impute = TRUE)` instead.
#' @param ... Arguments passed to [score_le8()], such as `min_components`.
#' @return An `essential8_imputed_scores` object: the stacked scored data sets,
#'   a subclass of `essential8_scores`. Its `summary()`, `summarise()`,
#'   `tidy()`, and `plot()` methods account for the imputations.
#' @section Pooling:
#' Each statistic is estimated in every imputed data set and combined with
#' Rubin's rules. Means are pooled with total variance
#' \eqn{T = \bar{U} + (1 + 1/m) B} and Barnard-Rubin degrees of freedom; the
#' fraction of missing information (`fmi`) describes how much the
#' imputations add to the uncertainty. Category percentages are pooled the
#' same way. Standard deviations and quantiles are averaged across
#' imputations, which describes the distribution but carries no interval.
#' @seealso [le8_imputation_setup()]
#' @examplesIf requireNamespace("mice", quietly = TRUE)
#' adults <- read.csv(system.file(
#'   "extdata", "le8-adult-example.csv", package = "essential8"
#' ))
#' adults <- adults[!startsWith(names(adults), "expected_")]
#' adults$non_hdl_cholesterol[c(2, 5)] <- NA
#'
#' # Stacked completed data sets, as any imputation software might return.
#' completed <- function(imp, value) {
#'   out <- adults
#'   out$non_hdl_cholesterol[is.na(out$non_hdl_cholesterol)] <- value
#'   cbind(.imp = imp, out)
#' }
#' stacked <- rbind(completed(1L, 150), completed(2L, 170))
#' summary(score_le8_imputed(stacked))
#' @export
score_le8_imputed <- function(data, ...) {
  call <- rlang::current_env()
  if (inherits(data, "mids")) {
    rlang::check_installed("mice", reason = "to complete the imputed data sets.")
    data <- mice::complete(data, action = "long", include = FALSE)
  }
  if (!is.data.frame(data) || !".imp" %in% names(data)) {
    cli::cli_abort(
      c(
        "{.arg data} must be a {.cls mids} object or a data frame with an {.field .imp} column.",
        "i" = "Stack completed data sets with {.code mice::complete(imputed, \"long\")}."
      ),
      class = c("essential8_imputation_error", "essential8_error"),
      call = call
    )
  }
  .check_le8_imputations(data, call = call)
  data <- .le8_inputs_from_factors(data)
  scores <- score_le8(data, ...)
  .new_le8_imputed_scores(scores)
}

.new_le8_imputed_scores <- function(x) {
  if (!inherits(x, "essential8_imputed_scores")) {
    class(x) <- c("essential8_imputed_scores", class(x))
  }
  x
}

.check_le8_imputations <- function(x, call = rlang::caller_env()) {
  imp <- x$.imp
  if (!is.numeric(imp) || anyNA(imp) || any(imp < 1) || any(imp != round(imp))) {
    cli::cli_abort(
      c(
        "{.field .imp} must number the imputed data sets from 1.",
        "i" = "Leave out the original data ({.code .imp == 0})."
      ),
      class = c("essential8_imputation_error", "essential8_error"),
      call = call
    )
  }
  sizes <- table(imp)
  if (length(sizes) < 2L) {
    cli::cli_abort(
      "Pooling needs at least 2 imputed data sets in {.field .imp}.",
      class = c("essential8_imputation_error", "essential8_error"),
      call = call
    )
  }
  if (length(unique(sizes)) != 1L) {
    cli::cli_abort(
      "Every imputed data set in {.field .imp} must have the same number of rows.",
      class = c("essential8_imputation_error", "essential8_error"),
      call = call
    )
  }
  length(sizes)
}

# Rubin's rules -----------------------------------------------------------------

# Pools one scalar across imputations: Rubin (1987) total variance with the
# Barnard-Rubin (1999) small-sample degrees of freedom, as in mice::pool().
.rubin_pool <- function(estimates, variances, n, conf_level = 0.95) {
  m <- length(estimates)
  empty <- list(
    estimate = NA_real_, std.error = NA_real_, conf.low = NA_real_,
    conf.high = NA_real_, df = NA_real_, fmi = NA_real_
  )
  if (m < 2L || anyNA(estimates)) {
    return(empty)
  }
  qbar <- mean(estimates)
  if (anyNA(variances)) {
    empty$estimate <- qbar
    return(empty)
  }
  ubar <- mean(variances)
  between <- stats::var(estimates)
  total <- ubar + (1 + 1 / m) * between
  lambda <- if (total > 0) (1 + 1 / m) * between / total else 0
  df_complete <- max(n - 1, 1)
  df_observed <- (df_complete + 1) / (df_complete + 3) * df_complete * (1 - lambda)
  df <- if (lambda > 0) {
    df_old <- (m - 1) / lambda^2
    df_old * df_observed / (df_old + df_observed)
  } else {
    df_observed
  }
  riv <- if (ubar > 0) (1 + 1 / m) * between / ubar else 0
  half_width <- stats::qt(1 - (1 - conf_level) / 2, df) * sqrt(total)
  list(
    estimate = qbar,
    std.error = sqrt(total),
    conf.low = qbar - half_width,
    conf.high = qbar + half_width,
    df = df,
    fmi = (riv + 2 / (df + 3)) / (riv + 1)
  )
}

# Pooled version of .le8_measure_stats(): one row per measure.
.le8_pooled_measure_stats <- function(scores, conf_level = 0.95) {
  pieces <- split(scores, scores$.imp)
  per_imputation <- lapply(pieces, .le8_measure_stats)
  keys <- unname(.le8_measure_keys())
  rows <- lapply(seq_along(keys), function(k) {
    stats <- do.call(rbind, lapply(per_imputation, `[`, k, , drop = FALSE))
    pooled <- .rubin_pool(
      stats$mean,
      stats$sd^2 / stats$n,
      n = mean(stats$n),
      conf_level = conf_level
    )
    data.frame(
      n = mean(stats$n),
      n_missing = mean(stats$n_missing),
      mean = pooled$estimate,
      std.error = pooled$std.error,
      conf.low = pooled$conf.low,
      conf.high = pooled$conf.high,
      df = pooled$df,
      fmi = pooled$fmi,
      sd = mean(stats$sd),
      min = mean(stats$min),
      q25 = mean(stats$q25),
      median = mean(stats$median),
      q75 = mean(stats$q75),
      max = mean(stats$max)
    )
  })
  data.frame(
    measure = factor(keys, levels = keys),
    do.call(rbind, rows)
  )
}

.le8_pooled_categories <- function(scores, conf_level = 0.95) {
  levels <- .le8_category_levels()
  pieces <- split(scores, scores$.imp)
  rows <- lapply(levels, function(level) {
    per_imputation <- vapply(pieces, function(piece) {
      category <- piece$le8_category[!is.na(piece$le8_composite_score)]
      c(n = length(category), count = sum(category == level, na.rm = TRUE))
    }, numeric(2))
    n <- per_imputation["n", ]
    p <- ifelse(n > 0, per_imputation["count", ] / n, NA_real_)
    pooled <- .rubin_pool(p, p * (1 - p) / n, n = mean(n), conf_level = conf_level)
    data.frame(
      category = level,
      n = mean(per_imputation["count", ]),
      percent = 100 * pooled$estimate,
      conf.low = 100 * max(pooled$conf.low, 0),
      conf.high = 100 * min(pooled$conf.high, 1)
    )
  })
  out <- do.call(rbind, rows)
  out$category <- factor(out$category, levels = levels)
  out
}
