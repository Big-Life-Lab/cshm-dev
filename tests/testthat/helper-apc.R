# Synthetic analysis_data for testing Stage 7 APC functions.
# Sourced automatically by testthat before test files.
# Column names are resolved from config so tests stay in sync with config.yml.

make_apc_test_data <- function(cfg, n = 100, seed = 42) {
  set.seed(seed)

  cycles <- factor(sample(as.character(1:11), n, replace = TRUE), levels = as.character(1:11))
  ages <- round(runif(n, 25, 65))
  smkdsty <- sample(c(1, 2, 3, 4, 5, 6), n,
    replace = TRUE,
    prob = c(0.25, 0.1, 0.1, 0.1, 0.05, 0.4)
  )

  age_first <- ifelse(
    smkdsty == 6, NA_real_,
    pmin(round(runif(n, 13, 25)), ages - 1)
  )
  # Former daily (cat 4) have years since stopped daily; others NA
  yrs_quit <- ifelse(smkdsty == 4, round(runif(n, 1, 20)), NA_real_)
  # Established-smoker gate: 100+ cigarettes (CCHS coding 1 = yes, 2 = no).
  # Most ever-smokers pass; some are experimental (2); never smokers are NA(a).
  smoked_100 <- ifelse(smkdsty == 6, NA_real_, ifelse(runif(n) < 0.85, 1, 2))
  # Years since stopped smoking completely: former smokers (4, 5) only.
  # PUMF 2003+ groups quit duration to a largest midpoint of 5 (worksheet rules)
  yrs_quit_complete <- ifelse(smkdsty %in% c(4, 5), sample(c(0.5, 1.5, 2.5, 5), n, replace = TRUE), NA_real_)
  # keep quit age at or after the entry age so the base data are internally consistent
  # 2022 PUMF (cycle 11): age_first_cigarette has no variable-details rule, so the real data
  # carry NA there; a non-missing value with no worksheet range is an error by design.
  age_first[cycles == "11"] <- NA_real_
  yrs_quit_complete <- pmin(yrs_quit_complete, ages - age_first)
  # 2001 and 2022 PUMF (cycles 1 and 11): time_quit_smoking_complete is not available, NA(c).
  yrs_quit_complete[cycles %in% c("1", "11")] <- NA_real_

  # Simulate survey years (2002–2022 range) and cohorts
  survey_years <- sample(2002:2022, n, replace = TRUE)
  cohorts <- survey_years - ages

  # Build data frame with placeholder names, then rename to config-resolved names
  df <- data.frame(
    cycle = cycles,
    sex = sample(1:2, n, replace = TRUE),
    age = ages,
    province = sample(10:60, n, replace = TRUE),
    weight = round(runif(n, 50, 500)),
    smoking_status = smkdsty,
    age_first_cigarette = age_first,
    years_since_quit = yrs_quit,
    established_smoker = smoked_100,
    years_since_quit_complete = yrs_quit_complete,
    survey_year = survey_years,
    cohort = cohorts,
    stringsAsFactors = FALSE
  )
  colnames(df) <- c(
    survey_var(cfg, "cycle"),
    survey_var(cfg, "sex"),
    survey_var(cfg, "age"),
    survey_var(cfg, "province"),
    survey_var(cfg, "weight"),
    survey_var(cfg, "smoking_status"),
    survey_var(cfg, "age_first_cigarette"),
    survey_var(cfg, "years_since_quit"),
    survey_var(cfg, "established_smoker"),
    survey_var(cfg, "years_since_quit_complete"),
    "survey_year",
    "cohort"
  )
  df
}
