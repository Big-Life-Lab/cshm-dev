# Synthetic analysis_data for testing Stage 7 APC functions.
# Sourced automatically by testthat before test files.
# Column names are resolved from config so tests stay in sync with config.yml.

make_apc_test_data <- function(cfg, n = 100, seed = 42) {
  set.seed(seed)

  cycles  <- factor(sample(as.character(1:11), n, replace = TRUE), levels = as.character(1:11))
  ages    <- round(runif(n, 25, 65))
  smkdsty <- sample(c(1, 2, 3, 4, 5, 6), n, replace = TRUE,
                    prob = c(0.25, 0.1, 0.1, 0.1, 0.05, 0.4))

  age_first <- ifelse(
    smkdsty == 6, NA_real_,
    pmin(round(runif(n, 13, 25)), ages - 1)
  )
  # Former daily (cat 4) have years since quit; others NA
  yrs_quit <- ifelse(smkdsty == 4, round(runif(n, 1, 20)), NA_real_)

  # Simulate survey years (2002–2022 range) and cohorts
  survey_years <- sample(2002:2022, n, replace = TRUE)
  cohorts      <- survey_years - ages

  # Build data frame with placeholder names, then rename to config-resolved names
  df <- data.frame(
    cycle               = cycles,
    sex                 = sample(1:2, n, replace = TRUE),
    age                 = ages,
    province            = sample(10:60, n, replace = TRUE),
    weight              = round(runif(n, 50, 500)),
    smoking_status      = smkdsty,
    age_first_cigarette = age_first,
    years_since_quit    = yrs_quit,
    survey_year         = survey_years,
    cohort              = cohorts,
    stringsAsFactors    = FALSE
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
    "survey_year",
    "cohort"
  )
  df
}
