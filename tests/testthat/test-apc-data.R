test_that("derive_survey_year returns correct integer year for all 11 cycles", {
  cfg <- config::get()
  cycle_col <- survey_var(cfg, "cycle")
  age_col <- survey_var(cfg, "age")

  data <- setNames(
    data.frame(
      factor(as.character(1:11), levels = as.character(1:11)),
      rep(40, 11),
      stringsAsFactors = FALSE
    ),
    c(cycle_col, age_col)
  )

  result <- derive_survey_year(data, cfg)

  # Cycle 1 (CCHS 1.1) collected Sept 2000 - Nov 2001: survey year 2001
  expected_years <- c(2001, 2003, 2005, 2008, 2010, 2012, 2014, 2016, 2018, 2020, 2022)
  expect_equal(result$survey_year, expected_years)
})

test_that("derive_survey_year computes cohort as survey_year - round(age)", {
  cfg <- config::get()
  cycle_col <- survey_var(cfg, "cycle")
  age_col <- survey_var(cfg, "age")

  data <- setNames(
    data.frame(
      factor("7", levels = as.character(1:11)),
      44,
      stringsAsFactors = FALSE
    ),
    c(cycle_col, age_col)
  )

  result <- derive_survey_year(data, cfg)
  # cycle 7 = 2014, age 44 → cohort = 2014 - 44 = 1970
  expect_equal(result$cohort, 1970L)
})

test_that("derive_survey_year stops on unknown cycle code", {
  cfg <- config::get()
  cycle_col <- survey_var(cfg, "cycle")
  age_col <- survey_var(cfg, "age")

  data <- setNames(
    data.frame(factor("99", levels = "99"), 40),
    c(cycle_col, age_col)
  )

  expect_error(derive_survey_year(data, cfg), "Unknown SurveyCycle codes")
})

test_that("build_initiation_data: no numerator rows with age < initiation floor", {
  cfg <- config::get()
  data <- make_apc_test_data(cfg)

  sex_col <- survey_var(cfg, "sex")
  result <- build_initiation_data(data[data[[sex_col]] == 1, ], cfg)

  init_rows <- result[result$event == 1, ]
  expect_true(all(init_rows$age >= survey_bound(cfg, "age_first_cigarette", "min")))
})

test_that("build_initiation_data: no rows with cohort < cohort_min", {
  cfg <- config::get()
  data <- make_apc_test_data(cfg)

  result <- build_initiation_data(data, cfg)
  expect_true(all(result$cohort >= cfg$apc$cohort_min))
})

test_that("build_initiation_data: denominator period within [period_min, period_max]", {
  cfg <- config::get()
  data <- make_apc_test_data(cfg)

  sex_col <- survey_var(cfg, "sex")
  result <- build_initiation_data(data[data[[sex_col]] == 1, ], cfg)
  denom <- result[result$event == 0, ]

  expect_true(all(denom$period >= cfg$apc$period_min))
  expect_true(all(denom$period <= cfg$apc$period_max))
})

cess_cfg <- function() {
  cfg <- config::get()
  cfg$apc$mortality_method <- "none"
  cfg
}

# One-row respondent data frame with config-resolved column names
one_person <- function(cfg, status, smoked_100 = 1, age_first = 16, yrs_quit_complete = NA,
                       age = 50, survey_year = 2010, weight = 100, cycle = "5") {
  df <- data.frame(
    cycle = factor(cycle, levels = as.character(1:11)), sex = 1L, age = age,
    province = 35L, weight = weight, smoking_status = status,
    age_first_cigarette = age_first, years_since_quit = NA_real_,
    established_smoker = smoked_100, years_since_quit_complete = yrs_quit_complete,
    survey_year = survey_year, cohort = survey_year - age
  )
  colnames(df) <- c(
    survey_var(cfg, "cycle"), survey_var(cfg, "sex"), survey_var(cfg, "age"),
    survey_var(cfg, "province"), survey_var(cfg, "weight"),
    survey_var(cfg, "smoking_status"), survey_var(cfg, "age_first_cigarette"),
    survey_var(cfg, "years_since_quit"), survey_var(cfg, "established_smoker"),
    survey_var(cfg, "years_since_quit_complete"), "survey_year", "cohort"
  )
  df
}

test_that("build_cessation_data: includes established smokers of every ever-smoker status", {
  cfg <- cess_cfg()
  data <- make_apc_test_data(cfg)
  result <- suppressMessages(build_cessation_data(data, cfg))
  diag <- attr(result, "cessation_diagnostics")
  expect_true(is.data.frame(diag))
  established <- sum(diag$n[diag$group == "established"])
  smoked_100 <- data[[survey_var(cfg, "established_smoker")]]
  smk <- data[[survey_var(cfg, "smoking_status")]]
  yes <- survey_code(cfg, "established_smoker", "yes_code")
  ever <- survey_code(cfg, "smoking_status", "ever_codes")
  expect_equal(established, sum(!is.na(smoked_100) & smoked_100 == yes & smk %in% ever & data$cohort >= cfg$apc$cohort_min))
  expect_true(all(result$event %in% c(0L, 1L)))
})

test_that("build_cessation_data: experimental smokers (under 100 cigarettes) are not included", {
  cfg <- cess_cfg()
  exp_smoker <- one_person(cfg, status = 4, smoked_100 = 2, age_first = 15, yrs_quit_complete = 10)
  result <- suppressMessages(build_cessation_data(exp_smoker, cfg))
  expect_equal(nrow(result), 0)
})

test_that("build_cessation_data: no person-year precedes the person's own entry age", {
  cfg <- cess_cfg()
  cur <- one_person(cfg, status = 1, age_first = 22, age = 40, survey_year = 2005)
  result <- suppressMessages(build_cessation_data(cur, cfg))
  expect_true(all(result$age >= 22))
  # at risk from entry through the survey year, inclusive
  expect_equal(sort(result$age), 22:40)
  expect_true(all(result$event == 0L))
})

test_that("build_cessation_data: durable quitter has one event at the quit age and risk rows before it", {
  cfg <- cess_cfg()
  q <- one_person(cfg, status = 4, age_first = 18, yrs_quit_complete = 10, age = 50, survey_year = 2010)
  result <- suppressMessages(build_cessation_data(q, cfg))
  expect_equal(sum(result$event), 1L)
  expect_equal(result$age[result$event == 1L], 40L)
  expect_equal(sort(result$age[result$event == 0L]), 18:39)
})

test_that("build_cessation_data: recent quitter is censored at the quit age with no event", {
  cfg <- cess_cfg()
  r <- one_person(cfg, status = 4, age_first = 18, yrs_quit_complete = 1, age = 50, survey_year = 2010)
  result <- suppressMessages(build_cessation_data(r, cfg))
  expect_equal(sum(result$event), 0L)
  expect_equal(max(result$age), 48L) # quit at 49; the quit year is not observed
  diag <- attr(result, "cessation_diagnostics")
  expect_equal(sum(diag$n[diag$group == "recent_quitters_censored"]), 1L)
})

test_that("build_cessation_data: starting and stopping at the same age is one trial with the event", {
  cfg <- cess_cfg()
  s <- one_person(cfg, status = 5, age_first = 40, yrs_quit_complete = 10, age = 50, survey_year = 2010)
  result <- suppressMessages(build_cessation_data(s, cfg))
  expect_equal(nrow(result), 1L)
  expect_equal(result$event, 1L)
  expect_equal(result$age, 40L)
  diag <- attr(result, "cessation_diagnostics")
  expect_equal(sum(diag$n[diag$group == "same_age_quits"]), 1L)
})

test_that("build_cessation_data: missing quit timing (e.g. 2001, NA(c)) is excluded and counted, not reclassified", {
  cfg <- cess_cfg()
  m <- one_person(cfg, status = 4, age_first = 18, yrs_quit_complete = NA, age = 50, survey_year = 2001, cycle = "1")
  result <- suppressMessages(build_cessation_data(m, cfg))
  expect_equal(nrow(result), 0L)
  diag <- attr(result, "cessation_diagnostics")
  expect_equal(sum(diag$n[diag$group == "excluded_timing_missing"]), 1L)
})

test_that("build_cessation_data: a quit before entry is excluded and counted", {
  cfg <- cess_cfg()
  bad <- one_person(cfg, status = 4, age_first = 45, yrs_quit_complete = 10, age = 50, survey_year = 2010) # quit at 40, before entry at 45
  result <- suppressMessages(build_cessation_data(bad, cfg))
  expect_equal(nrow(result), 0L)
  diag <- attr(result, "cessation_diagnostics")
  expect_equal(sum(diag$n[diag$group == "excluded_quit_before_entry"]), 1L)
})

test_that("build_initiation_data: experimental smokers contribute no initiation event", {
  cfg <- cess_cfg()
  exp_smoker <- one_person(cfg, status = 3, smoked_100 = 2, age_first = 15, age = 40, survey_year = 2005)
  result <- suppressMessages(build_initiation_data(exp_smoker, cfg))
  expect_equal(sum(result$event), 0L)
  expect_true(nrow(result) > 0) # at risk, like a never smoker
})

test_that("no missing weight in any output element", {
  cfg <- config::get()
  data <- make_apc_test_data(cfg)

  result_init <- build_initiation_data(data, cfg)
  result_cess <- build_cessation_data(data, cfg)

  expect_false(anyNA(result_init$weight))
  expect_false(anyNA(result_cess$weight))
})

test_that("apply_survival_correction: none leaves weights unchanged and labels the data", {
  cfg <- config::get()
  cfg$apc$mortality_method <- "none"

  df <- data.frame(
    age = 1:5, cohort = 1970:1974, period = 1985:1989,
    event = c(1, 0, 0, 1, 0), weight = c(100, 200, 150, 300, 250)
  )

  result <- apply_survival_correction(df, cfg)
  expect_equal(result$weight, df$weight)
  expect_identical(attr(result, "mortality_correction"), "none")
  expect_match(attr(result, "estimand_note"), "survived to be surveyed")
})

test_that("apply_survival_correction: peto raises not-implemented error", {
  cfg <- config::get()
  cfg$apc$mortality_method <- "peto"

  df <- data.frame(age = 1, cohort = 1970, period = 1985, event = 0, weight = 100)
  expect_error(apply_survival_correction(df, cfg), "not yet implemented")
})

test_that("apply_survival_correction: unknown method is an error", {
  cfg <- config::get()
  cfg$apc$mortality_method <- "no-such-method"

  df <- data.frame(age = 1, cohort = 1970, period = 1985, event = 0, weight = 100)
  expect_error(apply_survival_correction(df, cfg), "Unknown mortality_method")
})

test_that("assert_correction_applied: a correction that changes no weights fails", {
  before <- data.frame(
    age = 20:22, period = 2000:2002, cohort = 1980L, event = c(0L, 1L, 0L),
    weight = c(100, 200, 150)
  )
  expect_error(
    assert_correction_applied(before, before, "mport"),
    "left every weight unchanged"
  )
  after <- before
  after$weight <- after$weight * c(1.1, 1.3, 1.2)
  expect_true(assert_correction_applied(before, after, "mport"))
})

test_that("assert_correction_applied: a correction may change only the weights", {
  before <- data.frame(
    age = 20:22, period = 2000:2002, cohort = 1980L, event = c(0L, 1L, 0L),
    weight = c(100, 200, 150)
  )
  dropped <- before[-2, ]
  dropped$weight <- dropped$weight * 1.2
  expect_error(assert_correction_applied(before, dropped, "mport"), "number of rows")

  reordered <- before[c(3, 1, 2), ]
  reordered$weight <- reordered$weight * 1.2
  expect_error(assert_correction_applied(before, reordered, "mport"), "reordered")

  bad <- before
  bad$weight <- c(110, NA, 160)
  expect_error(assert_correction_applied(before, bad, "mport"), "non-finite")
})

test_that("fit_apc_model carries the mortality-correction label and estimand note", {
  cfg <- config::get()
  cfg$apc$mortality_method <- "none"
  apc_data <- prepare_apc_data(make_apc_test_data(cfg), cfg)
  ds <- apc_data$initiation_men
  expect_identical(attr(ds, "mortality_correction"), "none")
  fit <- fit_apc_model(ds, "initiation", 1, cfg) # sex is coded 1 = men
  expect_identical(attr(fit, "mortality_correction"), "none")
  expect_match(attr(fit, "estimand_note"), "survived to be surveyed")
})

test_that("apply_survival_correction: mport raises not-implemented error", {
  cfg <- config::get()
  cfg$apc$mortality_method <- "mport"

  df <- data.frame(age = 1, cohort = 1970, period = 1985, event = 0, weight = 100)
  expect_error(apply_survival_correction(df, cfg), "not yet implemented")
})

test_that("value codes are read from config, not hard-coded", {
  cfg <- cess_cfg()
  expect_equal(survey_code(cfg, "sex", "men_code"), 1)
  expect_equal(survey_code(cfg, "smoking_status", "former_codes"), c(4, 5))
  # Relabel the former-smoker codes in config and the classification follows
  cfg2 <- cfg
  cfg2$survey$smoking_status$pumf$former_codes <- c(4)
  cfg2$survey$smoking_status$pumf$current_codes <- c(1, 2, 3, 5)
  q <- one_person(cfg2, status = 5, age_first = 20, yrs_quit_complete = 10, age = 50, survey_year = 2010)
  result <- suppressMessages(build_cessation_data(q, cfg2))
  # status 5 is now "current": at risk to survey, no event
  expect_equal(sum(result$event), 0L)
  expect_equal(max(result$age), 50L)
})

test_that("fit_binomial_apc: refuses to fit a model with no events", {
  basis <- matrix(c(1, 2, 3, 4, 5, 6), ncol = 1, dimnames = list(NULL, "x"))
  expect_error(
    fit_binomial_apc(basis, event = rep(0L, 6), weight = rep(100, 6)),
    "numerator is empty"
  )
  expect_error(
    fit_binomial_apc(basis[0, , drop = FALSE], event = integer(0), weight = numeric(0)),
    "no person-year rows"
  )
})

test_that("fit_binomial_apc: fits and reports convergence when events exist", {
  set.seed(1)
  x <- rep(seq(-1, 1, length.out = 20), each = 5)
  basis <- matrix(x, ncol = 1, dimnames = list(NULL, "x"))
  event <- as.integer(runif(length(x)) < plogis(-1 + x))
  fit <- fit_binomial_apc(basis, event = event, weight = rep(10, length(x)))
  expect_true(isTRUE(fit$converged))
  expect_s3_class(fit, "glm")
})

# ---- respondent-level invariants (external review of PR #7) ----

test_that("cessation: risk begins at the person's own entry age, even below the reporting floor", {
  cfg <- cess_cfg()
  early <- one_person(cfg, status = 1, age_first = 8, age = 40, survey_year = 2005)
  result <- suppressMessages(build_cessation_data(early, cfg))
  expect_equal(min(result$age), 8L)
  expect_true(survey_bound(cfg, "age_first_cigarette", "min") > 8)
})

test_that("cessation: a negative or out-of-bounds quit duration is excluded and counted, never post-survey time", {
  cfg <- cess_cfg()
  bad <- one_person(cfg, status = 4, age_first = 18, yrs_quit_complete = -5, age = 50, survey_year = 2010)
  result <- suppressMessages(build_cessation_data(bad, cfg))
  expect_equal(nrow(result), 0L)
  diag <- attr(result, "cessation_diagnostics")
  expect_equal(sum(diag$n[diag$group == "excluded_quit_timing_invalid"]), 1L)
  big <- one_person(cfg, status = 4, age_first = 18, yrs_quit_complete = 99, age = 50, survey_year = 2010)
  expect_equal(nrow(suppressMessages(build_cessation_data(big, cfg))), 0L)
})

test_that("cessation and initiation: no person-year after the survey age, none before entry", {
  cfg <- cess_cfg()
  data <- make_apc_test_data(cfg, n = 300, seed = 7)
  age_survey <- data[[survey_var(cfg, "age")]]
  cess <- suppressMessages(build_cessation_data(data, cfg))
  init <- suppressMessages(build_initiation_data(data, cfg))
  expect_true(all(cess$age <= max(age_survey)))
  expect_true(all(init$age <= max(age_survey)))
  expect_true(all(cess$age >= min(data[[survey_var(cfg, "age_first_cigarette")]], na.rm = TRUE)))
  expect_true(all(cess$event %in% c(0L, 1L)))
  expect_true(all(init$event %in% c(0L, 1L)))
})

test_that("initiation: missing status, missing 100-cigarette answer, or invalid entry are excluded, not Never", {
  cfg <- cess_cfg()
  no_crit <- one_person(cfg, status = 1, smoked_100 = NA, age_first = 16, age = 40, survey_year = 2005)
  r1 <- suppressMessages(build_initiation_data(no_crit, cfg))
  expect_equal(nrow(r1), 0L)
  d1 <- attr(r1, "initiation_diagnostics")
  expect_equal(sum(d1$n[d1$group == "excluded_criterion_missing"]), 1L)
  late <- one_person(cfg, status = 1, age_first = 45, age = 40, survey_year = 2005)
  expect_equal(nrow(suppressMessages(build_initiation_data(late, cfg))), 0L)
  no_age <- one_person(cfg, status = 1, age_first = NA, age = 40, survey_year = 2005)
  r3 <- suppressMessages(build_initiation_data(no_age, cfg))
  expect_equal(nrow(r3), 0L)
  d3 <- attr(r3, "initiation_diagnostics")
  expect_equal(sum(d3$n[d3$group == "excluded_missing_entry"]), 1L)
})

test_that("initiation: never smokers are at risk from the floor to the survey; initiators have one event", {
  cfg <- cess_cfg()
  floor_age <- survey_bound(cfg, "age_first_cigarette", "min")
  nev <- one_person(cfg, status = 6, smoked_100 = NA, age_first = NA, age = 30, survey_year = 2010)
  r <- suppressMessages(build_initiation_data(nev, cfg))
  expect_equal(sum(r$event), 0L)
  expect_equal(sort(r$age), floor_age:30)
  st <- one_person(cfg, status = 1, age_first = 20, age = 30, survey_year = 2010)
  r2 <- suppressMessages(build_initiation_data(st, cfg))
  expect_equal(sum(r2$event), 1L)
  expect_equal(r2$age[r2$event == 1L], 20L)
  expect_equal(sort(r2$age[r2$event == 0L]), floor_age:19)
})

test_that("initiation: an established smoker who started below the floor contributes no initiation rows", {
  cfg <- cess_cfg()
  early <- one_person(cfg, status = 1, age_first = 8, age = 40, survey_year = 2005)
  r <- suppressMessages(build_initiation_data(early, cfg))
  expect_equal(nrow(r), 0L)
  d <- attr(r, "initiation_diagnostics")
  expect_equal(sum(d$n[d$group == "entered_before_floor"]), 1L)
})
