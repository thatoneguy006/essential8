# Adult (20+ years) component scores -------------------------------------------
#
# Each function transcribes one row of the adult column of Table 1 in
# Lloyd-Jones et al. (2022). Inputs are already validated; missing inputs give
# missing scores.

.score_adult_mepa_total <- function(total) {
  .score_bands(total, lower = c(-Inf, 4, 8, 12, 15), points = c(0, 25, 50, 80, 100))
}

# Weekly moderate-equivalent minutes (vigorous minutes count twice).
.score_adult_physical_activity <- function(minutes) {
  .score_activity_minutes(
    minutes,
    lower = c(-Inf, 30, 60, 90, 120, 150),
    points = c(20, 40, 60, 80, 90, 100)
  )
}

# Activity tables give 0 points for no activity and their lowest nonzero band
# for any positive amount ("1-29 minutes").
.score_activity_minutes <- function(minutes, lower, points) {
  score <- .score_bands(minutes, lower, points)
  score[which(minutes <= 0)] <- 0
  score
}

.score_adult_nicotine <- function(
  smoking_status,
  years_since_quit,
  current_inhaled_nds,
  secondhand_smoke_home
) {
  former_score <- .score_bands(
    years_since_quit,
    lower = c(-Inf, 1, 5),
    points = c(25, 50, 75)
  )
  score <- rep(NA_real_, length(smoking_status))
  score[which(smoking_status == "never")] <- 100
  score[which(smoking_status == "current")] <- 0
  former <- which(smoking_status == "former")
  score[former] <- former_score[former]

  .apply_nicotine_exposure(score, current_inhaled_nds, secondhand_smoke_home)
}

# Shared adult and pediatric nicotine modifiers: current inhaled-NDS use caps
# the score at 25, and living with an active indoor smoker subtracts 20 points
# unless the score is already 0. Both inputs are required.
.apply_nicotine_exposure <- function(
  score,
  current_inhaled_nds,
  secondhand_smoke_home
) {
  inhaled_nds <- which(current_inhaled_nds & score > 25)
  score[inhaled_nds] <- 25
  secondhand_smoke <- which(secondhand_smoke_home & score > 0)
  score[secondhand_smoke] <- score[secondhand_smoke] - 20
  score[is.na(current_inhaled_nds) | is.na(secondhand_smoke_home)] <- NA_real_
  score
}

.score_adult_sleep <- function(hours, apply_apnea_penalty) {
  score <- .score_bands(
    hours,
    lower = c(-Inf, 4, 5, 6, 7, 9, 10),
    points = c(0, 20, 40, 70, 100, 90, 40)
  )
  .apply_decrement(score, apply_apnea_penalty)
}

.score_adult_bmi <- function(
  bmi,
  profile,
  apply_lean_muscular_override = rep(FALSE, length(bmi))
) {
  general <- .score_bands(
    bmi,
    lower = c(-Inf, 25, 30, 35, 40),
    points = c(100, 70, 30, 15, 0)
  )
  # WHO ranges for individuals of Asian or Pacific ancestry (Table 1 notes).
  asian_pacific <- .score_bands(
    bmi,
    lower = c(-Inf, 23, 25, 30, 35),
    points = c(100, 75, 50, 25, 0)
  )
  score <- rep(NA_real_, length(bmi))
  score[which(profile == "general")] <- general[which(profile == "general")]
  score[which(profile == "asian_pacific")] <-
    asian_pacific[which(profile == "asian_pacific")]

  # The override can only apply to a known general-profile BMI of 25 to <30.
  # Requiring a known-TRUE eligibility prevents awarding 100 points when BMI
  # or profile is missing, and an NA flag only blanks rows it could change.
  eligible_override <- profile == "general" & bmi >= 25 & bmi < 30
  score[which(apply_lean_muscular_override & eligible_override)] <- 100
  score[which(is.na(apply_lean_muscular_override) & eligible_override)] <-
    NA_real_

  score
}

.score_adult_blood_lipids <- function(non_hdl, treated) {
  score <- .score_bands(
    non_hdl,
    lower = c(-Inf, 130, 160, 190, 220),
    points = c(100, 60, 40, 20, 0)
  )
  .apply_decrement(score, treated)
}

# The glucose table is identical for adults and children.
.score_adult_blood_glucose <- function(
  diabetes,
  measure,
  value,
  apply_prevention_penalty
) {
  no_diabetes_fbg <- .score_bands(value, c(-Inf, 100), c(100, 60))
  no_diabetes_hba1c <- .score_bands(value, c(-Inf, 5.7), c(100, 60))
  with_diabetes <- .score_bands(
    value,
    lower = c(-Inf, 7, 8, 9, 10),
    points = c(40, 30, 20, 10, 0)
  )

  score <- rep(NA_real_, length(value))
  rows <- which(!diabetes & measure == "fasting_glucose")
  score[rows] <- no_diabetes_fbg[rows]
  rows <- which(!diabetes & measure == "hba1c")
  score[rows] <- no_diabetes_hba1c[rows]
  # Diabetes bands are HbA1c bands; an unknown or non-HbA1c measure stays NA
  # rather than being interpreted as a percentage.
  rows <- which(diabetes & measure == "hba1c")
  score[rows] <- with_diabetes[rows]

  # The prediabetes/metformin penalty only applies to normoglycemic people
  # without diabetes. Where that is known to be false, an NA flag cannot
  # change the score, so treat it as FALSE instead of blanking the score.
  penalty <- apply_prevention_penalty
  normoglycemic <- .is_normoglycemic(diabetes, measure, value)
  penalty[is.na(penalty) & normoglycemic %in% FALSE] <- FALSE

  .apply_decrement(score, penalty)
}

.score_adult_blood_pressure <- function(systolic, diastolic, treated) {
  systolic_score <- .score_bands(
    systolic,
    lower = c(-Inf, 120, 130, 140, 160),
    points = c(100, 75, 50, 25, 0)
  )
  diastolic_score <- .score_bands(
    diastolic,
    lower = c(-Inf, 80, 90, 100),
    points = c(100, 50, 25, 0)
  )
  .apply_decrement(pmin(systolic_score, diastolic_score), treated)
}
