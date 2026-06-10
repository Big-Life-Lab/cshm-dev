# Tests for where-matrix MICE imputation (protocol v0.3.0, Appendix D)
# The contract under test: only NA(b) cells are imputed; tagged NA(a)/NA(c)
# survive the round trip untouched; factor levels are preserved.

make_imputation_test_data <- function(n = 80, seed = 42) {
  set.seed(seed)
  age    <- round(runif(n, 20, 80))
  weight <- round(runif(n, 50, 500))

  # Continuous: years since quit — NA(a) for never-smokers, some NA(b)
  years_quit <- round(runif(n, 0, 30))
  years_quit[1:20] <- haven::tagged_na("a")   # never-smokers: not applicable
  years_quit[21:25] <- haven::tagged_na("b")  # don't know / refused
  years_quit[26:27] <- haven::tagged_na("c")  # not asked this cycle

  # Categorical: smoking status with structural and random missing levels
  status <- sample(c("1", "4", "6"), n, replace = TRUE)
  status[28:31] <- "NA(b)"
  status[32:33] <- "NA(a)"
  status <- factor(status, levels = c("1", "4", "6", "NA(a)", "NA(b)"))

  data.frame(
    age = age, weight = weight,
    years_quit = years_quit, status = status,
    stringsAsFactors = FALSE
  )
}

make_imputation_variables_sheet <- function() {
  data.frame(
    variable     = c("age", "weight", "years_quit", "status"),
    variableType = c("Continuous", "Continuous", "Continuous", "Categorical"),
    role         = c("imputation-predictor", "imputation-predictor",
                     "predictor, imputation-predictor",
                     "predictor, imputation-predictor"),
    source       = "both",
    stringsAsFactors = FALSE
  )
}

test_that("prepare_for_mice builds the where matrix on exactly the NA(b) cells", {
  d <- make_imputation_test_data()
  prep <- prepare_for_mice(d, c("age", "weight", "years_quit", "status"))

  expect_equal(sum(prep$where[, "years_quit"]), 5)   # rows 21:25
  expect_true(all(which(prep$where[, "years_quit"]) == 21:25))
  expect_equal(sum(prep$where[, "status"]), 4)        # rows 28:31
  expect_equal(sum(prep$where[, "age"]), 0)
  expect_equal(sum(prep$where[, "weight"]), 0)

  # Modelling frame: no NA(x) levels remain; tagged NAs are plain NA
  expect_false(any(c("NA(a)", "NA(b)", "NA(c)") %in% levels(prep$data$status)))
  expect_false(any(haven::is_tagged_na(prep$data$years_quit)))
  # Structural cells are NA in the frame (excluded from imputation by where = FALSE)
  expect_true(all(is.na(prep$data$years_quit[1:20])))
})

test_that("impute_data fills NA(b) and preserves tagged NA(a)/NA(c) untouched", {
  d <- make_imputation_test_data()
  vs <- make_imputation_variables_sheet()
  cfg <- list(imputation_m = 2, imputation_maxit = 1)

  result <- suppressWarnings(impute_data(d, vs, cfg))

  expect_equal(result$m, 2)
  expect_length(result$datasets, 2)

  for (out in result$datasets) {
    # NA(b) cells resolved to real values
    expect_false(any(is.na(out$years_quit[21:25])))
    expect_false(any(as.character(out$status[28:31]) == "NA(b)", na.rm = TRUE))
    expect_false(any(is.na(out$status[28:31])))

    # Structural missingness untouched — tags survive the round trip
    expect_true(all(haven::is_tagged_na(out$years_quit[1:20], "a")))
    expect_true(all(haven::is_tagged_na(out$years_quit[26:27], "c")))
    expect_true(all(as.character(out$status[32:33]) == "NA(a)"))

    # Factor levels preserved (including the structural-missing levels)
    expect_equal(levels(out$status), levels(d$status))

    # Imputed categorical values are never structural-missing labels
    expect_true(all(as.character(out$status[28:31]) %in% c("1", "4", "6")))

    # Complete columns are byte-identical
    expect_identical(out$age, d$age)
    expect_identical(out$weight, d$weight)

    # Observed values are unchanged
    expect_identical(out$years_quit[40:80], d$years_quit[40:80])
  }

  # Audit output names the imputed cells
  expect_equal(
    result$imputed_cells$n_imputed[result$imputed_cells$variable == "years_quit"], 5
  )
})

test_that("impute_data with no NA(b) returns the data unchanged", {
  d <- make_imputation_test_data()
  d$years_quit[21:25] <- 10        # remove the NA(b) cells
  d$status[28:31] <- "1"
  vs <- make_imputation_variables_sheet()
  cfg <- list(imputation_m = 2, imputation_maxit = 1)

  result <- impute_data(d, vs, cfg)
  expect_equal(result$m, 1L)
  expect_identical(result$datasets[[1]], d)
})

test_that("impute_data stops when an imputation-predictor variable is absent", {
  d <- make_imputation_test_data()
  d$status <- NULL
  vs <- make_imputation_variables_sheet()
  cfg <- list(imputation_m = 1, imputation_maxit = 1)
  expect_error(impute_data(d, vs, cfg), "absent from data")
})

test_that("weighted_quantile interpolates and matches type-7 median under equal weights", {
  x <- c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
  w <- rep(1, 10)
  # Midpoint-ECDF interpolation: equal-weight median equals the type-7 median
  expect_equal(weighted_quantile(x, w, 0.5), unname(quantile(x, 0.5)))
  # Upweighting the top value pulls the median toward it
  w2 <- c(rep(1, 9), 100)
  expect_gt(weighted_quantile(x, w2, 0.5), 9.5)
  # Boundary probabilities clamp to the extremes
  expect_equal(weighted_quantile(x, w, c(0, 1)), c(1, 10))
  expect_equal(weighted_quantile(numeric(0), numeric(0), 0.5), NA_real_)
  expect_equal(weighted_quantile(7, 3, c(0.25, 0.75)), c(7, 7))
})

test_that("impute_data stops when MICE declines to impute a flagged cell", {
  d <- make_imputation_test_data()
  d$flat <- 1                                   # constant: mice sets method ""
  d$flat[5] <- haven::tagged_na("b")
  vs <- rbind(make_imputation_variables_sheet(),
              data.frame(variable = "flat", variableType = "Continuous",
                         role = "imputation-predictor", source = "both"))
  cfg <- list(imputation_m = 1, imputation_maxit = 1)
  # Either guard may fire first: the declined-cell write-back stop or the
  # scoped chain-mean degeneracy stop — both protect the same contract.
  expect_error(suppressWarnings(impute_data(d, vs, cfg)), "unimputed|degenerate fit")
})

test_that("structural-NA variables are excluded as predictors, not as targets", {
  d <- make_imputation_test_data()
  vs <- make_imputation_variables_sheet()
  cfg <- list(imputation_m = 1, imputation_maxit = 1)
  msgs <- capture_messages(suppressWarnings(impute_data(d, vs, cfg)))
  excl <- msgs[grepl("Excluded as predictors", msgs)]
  expect_length(excl, 1)
  # years_quit (NA(a)/(c)) and status (NA(a) level) carry structural missingness
  expect_match(excl, "years_quit")
  expect_match(excl, "status")
  expect_false(grepl("\\bage\\b", excl))        # complete variables stay predictors
})

test_that("pack_years_der is recomputed from imputed feeders", {
  skip_if_not(all(c("calculate_pack_years") %in% getNamespaceExports("cchsflow")))
  n <- 12
  d <- data.frame(
    SMKDSTY_original    = factor(rep("6", n), levels = c("1", "4", "6")),
    DHHGAGE_cont        = rep(50, n),
    age_start_smoking   = rep(NA_real_, n),
    cigs_per_day        = rep(NA_real_, n),
    time_quit_smoking   = rep(NA_real_, n),
    SMK_05B             = rep(NA_real_, n),
    SMK_05C             = rep(NA_real_, n),
    age_first_cigarette = rep(NA_real_, n),
    smoked_100_lifetime = rep(2, n),
    pack_years_der      = rep(99, n)            # stale value to be overwritten
  )
  out <- recompute_derived(d)
  # never-smokers: pack-years recomputed to 0, replacing the stale 99
  expect_true(all(out$pack_years_der == 0))
})
