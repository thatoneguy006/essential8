# Age routing ------------------------------------------------------------------
#
# Rows aged 20 years or older use the adult AHA definitions; younger rows use
# the pediatric definitions, whose age bands are expressed in months. The
# optional `age_months` column, when observed, gives the pediatric bands more
# precision than `age * 12`.

.le8_minimum_age_months <- function() 4
.le8_adult_age_years <- function() 20

.le8_age <- function(data) {
  months <- data$age * 12
  if ("age_months" %in% names(data)) {
    observed <- !is.na(data$age_months)
    months[observed] <- data$age_months[observed]
  }
  adult <- data$age >= .le8_adult_age_years()
  list(
    years = data$age,
    months = months,
    adult = adult,
    pediatric = !adult
  )
}

# Pediatric rows whose age in months is in [lower, upper).
.pediatric_ages <- function(age, lower = 0, upper = Inf) {
  age$pediatric & age$months >= lower & age$months < upper
}

.le8_population_label <- function(age) {
  ifelse(age$adult, "adult", "pediatric")
}

# Which components AHA defines at each row's age. Adults have all eight.
# Pediatric limits come from the 2022 advisory's supplemental Appendix 2:
# diet from 6 months (individual screener) or 2 years (population percentiles),
# physical activity from 1 year, and blood pressure from 1 year.
.le8_applicable_components <- function(age, diet_method) {
  diet_minimum <- if (diet_method == "mepa") 6 else 24
  n <- length(age$adult)
  applicable <- matrix(
    TRUE,
    nrow = n,
    ncol = length(.le8_component_score_columns()),
    dimnames = list(NULL, .le8_component_score_columns())
  )
  applicable[, "diet_score"] <- !.pediatric_ages(age, 0, diet_minimum)
  applicable[, "physical_activity_score"] <- !.pediatric_ages(age, 0, 12)
  applicable[, "blood_pressure_score"] <- !.pediatric_ages(age, 0, 12)
  applicable
}
