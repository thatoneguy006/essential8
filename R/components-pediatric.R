# Pediatric (4 months to 19 years) component scores -----------------------------
#
# Sources: the children column of Table 1 in Lloyd-Jones et al. (2022) and the
# suggested rules for younger children in its Supplemental Appendix 2. Ages
# are in months. Each function returns NA outside the ages its source covers;
# `score_le8()` separately marks components AHA does not define at an age.

.score_pediatric_physical_activity <- function(
  weekly_minutes,
  active_play_minutes,
  months
) {
  score <- rep(NA_real_, length(months))

  # Ages 1-5: total active play of any intensity, minutes/day over 7 days.
  preschool <- which(months >= 12 & months < 72)
  score[preschool] <- .score_activity_minutes(
    active_play_minutes[preschool],
    lower = c(-Inf, 60, 90, 120, 150, 180),
    points = c(25, 50, 70, 80, 90, 100)
  )

  # Ages 6-19: weekly moderate or vigorous minutes, each counted once.
  school_age <- which(months >= 72 & months < 240)
  score[school_age] <- .score_activity_minutes(
    weekly_minutes[school_age],
    lower = c(-Inf, 120, 240, 300, 360, 420),
    points = c(20, 40, 60, 80, 90, 100)
  )

  score
}

# Pediatric categories describe any nicotine product: "never" = never tried,
# "former" = tried, but not within 30 days, "current" = combustible use within
# 30 days. Current inhaled-NDS use (within 30 days) scores 25 through the shared
# cap, and secondhand smoke at home subtracts 20 as for adults.
.score_pediatric_nicotine <- function(
  smoking_status,
  current_inhaled_nds,
  secondhand_smoke_home
) {
  score <- unname(c(never = 100, former = 50, current = 0)[smoking_status])
  .apply_nicotine_exposure(score, current_inhaled_nds, secondhand_smoke_home)
}

# Age-appropriate optimal sleep (hours per 24 hours, including naps, through
# age 5). AHA lists 13-18 years last; 19-year-olds, who are still scored with
# the pediatric column, use the same 8-10 hour range.
.pediatric_sleep_range <- function(months) {
  starts <- c(4, 12, 36, 72, 156)
  list(
    lower = .score_bands(months, starts, c(12, 11, 10, 9, 8)),
    upper = .score_bands(months, starts, c(16, 14, 13, 12, 10))
  )
}

.score_pediatric_sleep <- function(hours, months, apply_apnea_penalty) {
  range <- .pediatric_sleep_range(months)
  shortfall <- range$lower - hours
  excess <- hours - range$upper

  score <- rep(100, length(hours))
  short <- which(shortfall > 0)
  score[short] <- .score_bands(
    shortfall[short],
    lower = c(0, 1, 2, 3),
    points = c(70, 40, 20, 0)
  )
  long <- which(excess > 0)
  score[long] <- .score_bands(excess[long], lower = c(0, 1), points = c(90, 40))
  score[is.na(hours) | is.na(range$lower)] <- NA_real_

  .apply_decrement(score, apply_apnea_penalty)
}

.score_pediatric_bmi <- function(
  bmi_percentile,
  bmi_percent_of_p95,
  infant_weight_percentile,
  infant_weight_z_change,
  months
) {
  score <- rep(NA_real_, length(months))

  young_infant <- which(months >= 4 & months < 6)
  score[young_infant] <- .score_infant_weight_size(
    infant_weight_percentile[young_infant]
  )

  infant <- which(months >= 6 & months < 24)
  score[infant] <- .score_infant_weight(
    infant_weight_percentile[infant],
    infant_weight_z_change[infant]
  )

  growth_chart <- which(months >= 24 & months < 240)
  score[growth_chart] <- .score_growth_chart_bmi(
    bmi_percentile[growth_chart],
    bmi_percent_of_p95[growth_chart]
  )

  score
}

# Ages 1 to <6 months: current WHO weight-for-length or BMI percentile only.
.score_infant_weight_size <- function(percentile) {
  .score_bands(percentile, lower = c(-Inf, 97.7, 99.7), points = c(100, 75, 50))
}

# Ages 6-23 months: size decrements plus 25 points for rapid gain (an increase
# of at least 0.67 in the z-score since prior routine visits). The supplement
# defines the worst state, >= 99.7th percentile with rapid gain, as 0 points
# even though the listed decrements alone would leave 25.
.score_infant_weight <- function(percentile, z_change) {
  size_score <- .score_bands(
    percentile,
    lower = c(-Inf, 97.7, 99.7),
    points = c(100, 75, 50)
  )
  rapid_gain <- z_change >= 0.67
  score <- size_score - ifelse(rapid_gain, 25, 0)
  score[which(percentile >= 99.7 & rapid_gain)] <- 0
  score
}

# Ages 2-19: CDC BMI-for-age percentile, with percent of the 95th percentile
# distinguishing obesity severity at or above the 95th percentile.
.score_growth_chart_bmi <- function(percentile, percent_of_p95) {
  score <- .score_bands(
    percentile,
    lower = c(-Inf, 85, 95),
    points = c(100, 70, NA)
  )
  obesity <- which(percentile >= 95)
  score[obesity] <- .score_bands(
    percent_of_p95[obesity],
    lower = c(-Inf, 120, 140),
    points = c(30, 15, 0)
  )
  score
}

.score_pediatric_blood_lipids <- function(non_hdl, treated) {
  score <- .score_bands(
    non_hdl,
    lower = c(-Inf, 100, 120, 145, 190),
    points = c(100, 60, 40, 20, 0)
  )
  .apply_decrement(score, treated)
}

# Ages 1-12 use the AAP 2017 percentile categories, each threshold taking the
# lower of the percentile-based and absolute values ("whichever is lower");
# ages 13 and older use the adult table.
.score_pediatric_blood_pressure <- function(
  systolic,
  diastolic,
  systolic_p90,
  systolic_p95,
  diastolic_p90,
  diastolic_p95,
  treated,
  months
) {
  points <- c(100, 75, 50, 25, 0)
  systolic_score <- .score_row_bands(
    systolic,
    thresholds = list(
      pmin(systolic_p90, 120),      # elevated
      pmin(systolic_p95, 130),      # stage 1
      pmin(systolic_p95 + 12, 140), # stage 2
      pmin(systolic_p95 + 30, 160)  # 0 points
    ),
    points = points
  )
  diastolic_score <- .score_row_bands(
    diastolic,
    thresholds = list(
      pmin(diastolic_p90, 80),
      pmin(diastolic_p95, 80),
      pmin(diastolic_p95 + 12, 90),
      pmin(diastolic_p95 + 20, 100)
    ),
    points = points
  )
  percentile_score <- .apply_decrement(
    pmin(systolic_score, diastolic_score),
    treated
  )
  adolescent_score <- .score_adult_blood_pressure(systolic, diastolic, treated)

  score <- rep(NA_real_, length(months))
  children <- which(months >= 12 & months < 156)
  score[children] <- percentile_score[children]
  adolescents <- which(months >= 156 & months < 240)
  score[adolescents] <- adolescent_score[adolescents]
  score
}
