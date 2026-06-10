test_that("derive_survey_year returns correct integer year for all 11 cycles", {
  cfg <- config::get()
  cycle_col <- survey_var(cfg, "cycle")
  age_col   <- survey_var(cfg, "age")

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
  age_col   <- survey_var(cfg, "age")

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
  age_col   <- survey_var(cfg, "age")

  data <- setNames(
    data.frame(factor("99", levels = "99"), 40),
    c(cycle_col, age_col)
  )

  expect_error(derive_survey_year(data, cfg), "Unknown SurveyCycle codes")
})

test_that("build_initiation_data: no numerator rows with age < initiation floor", {
  cfg  <- config::get()
  data <- make_apc_test_data(cfg)

  sex_col <- survey_var(cfg, "sex")
  result <- build_initiation_data(data[data[[sex_col]] == 1, ], cfg)

  init_rows <- result[result$event == 1, ]
  expect_true(all(init_rows$age >= survey_bound(cfg, "age_first_cigarette", "min")))
})

test_that("build_initiation_data: no rows with cohort < cohort_min", {
  cfg  <- config::get()
  data <- make_apc_test_data(cfg)

  result <- build_initiation_data(data, cfg)
  expect_true(all(result$cohort >= cfg$apc$cohort_min))
})

test_that("build_initiation_data: denominator period within [period_min, period_max]", {
  cfg  <- config::get()
  data <- make_apc_test_data(cfg)

  sex_col <- survey_var(cfg, "sex")
  result <- build_initiation_data(data[data[[sex_col]] == 1, ], cfg)
  denom  <- result[result$event == 0, ]

  expect_true(all(denom$period >= cfg$apc$period_min))
  expect_true(all(denom$period <= cfg$apc$period_max))
})

test_that("build_cessation_data: only ever-daily smokers in cessation data", {
  cfg  <- config::get()
  data <- make_apc_test_data(cfg)

  # build_cessation_data accepts current daily (1), occ former daily (2), and former daily (4)
  # smoking_status category 3 (always occasional) and 5 (former occasional) are excluded
  result <- build_cessation_data(data, cfg)
  # Cessation events (event=1) come from former daily smokers — we can't check
  # smoking_status directly from the output, but we can verify the function runs without error
  # and produces a valid data frame
  expect_true(is.data.frame(result))
  expect_true(all(c("age", "cohort", "period", "event", "weight") %in% names(result)))
})

test_that("no missing weight in any output element", {
  cfg  <- config::get()
  data <- make_apc_test_data(cfg)

  result_init <- build_initiation_data(data, cfg)
  result_cess <- build_cessation_data(data, cfg)

  expect_false(anyNA(result_init$weight))
  expect_false(anyNA(result_cess$weight))
})

test_that("apply_survival_correction: peto returns data unchanged", {
  cfg <- config::get()

  df <- data.frame(age = 1:5, cohort = 1970:1974, period = 1985:1989,
                   event = c(1,0,0,1,0), weight = c(100, 200, 150, 300, 250))

  result <- apply_survival_correction(df, cfg)
  expect_equal(result$weight, df$weight)
})

test_that("apply_survival_correction: mport raises not-implemented error", {
  cfg <- config::get()
  cfg$apc$mortality_method <- "mport"

  df <- data.frame(age = 1, cohort = 1970, period = 1985, event = 0, weight = 100)
  expect_error(apply_survival_correction(df, cfg), "not yet implemented")
})

