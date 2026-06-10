# apc-model.R
# Stage 7: Prepare APC numerator/denominator datasets
# Stage 8: Fit constrained cubic spline age-period-cohort models
#
# Based on the Canadian Smoking Histories Model (Manuel et al., Health Reports 2020)
# and the Holford constrained spline APC framework (Holford et al., Cancer Epidemiol
# Biomarkers Prev 2014).
#
# CCHS data used here is accessed and adapted in accordance with the Statistics Canada
# Open Licence (https://www.statcan.gc.ca/eng/reference/licence).
#
# References:
#   Manuel DG et al. Health Reports 2020. doi:10.25318/82-003-x202001100002-eng
#   Holford TR et al. Cancer Epidemiol Biomarkers Prev. 2014;23(11):2356-65.


# ---------------------------------------------------------------------------
# Stage 7 entry point
# ---------------------------------------------------------------------------

#' Prepare APC datasets for model fitting
#'
#' Builds long-format person-year data frames for smoking initiation (by sex)
#' and cessation (by sex). Each row is either a transition event (event = 1)
#' or an at-risk person-year (event = 0). Applies mortality survival correction
#' via cfg$apc$mortality_method.
#'
#' @param analysis_data Output of impute_data()
#' @param cfg Config object from config::get()
#' @return Named list: initiation_men, initiation_women, cessation_men,
#'   cessation_women. Each element is a data frame with columns:
#'   age, cohort, period, event, weight.
prepare_apc_data <- function(analysis_data, cfg) {
  data <- derive_survey_year(analysis_data, cfg)

  init_men   <- build_initiation_data(data[data[[survey_var(cfg, "sex")]] == 1, ], cfg)
  init_women <- build_initiation_data(data[data[[survey_var(cfg, "sex")]] == 2, ], cfg)
  cess_men   <- build_cessation_data(data[data[[survey_var(cfg, "sex")]] == 1, ], cfg)
  cess_women <- build_cessation_data(data[data[[survey_var(cfg, "sex")]] == 2, ], cfg)

  list(
    initiation_men   = apply_survival_correction(init_men,   cfg),
    initiation_women = apply_survival_correction(init_women, cfg),
    cessation_men    = apply_survival_correction(cess_men,   cfg),
    cessation_women  = apply_survival_correction(cess_women, cfg)
  )
}


# ---------------------------------------------------------------------------
# Stage 7 sub-functions
# ---------------------------------------------------------------------------

#' Add survey_year and cohort columns to analysis data
#'
#' Maps SurveyCycle factor codes ("1"–"11") to integer calendar years using
#' cfg$cycle_survey_years. Cohort is defined as survey_year − round(age).
#' NOTE: SurveyCycle is a factor — as.character() is required before lookup.
#'
#' @param data Data frame containing SurveyCycle and age columns
#' @param cfg Config object
#' @return data with survey_year (integer) and cohort (integer) columns added
derive_survey_year <- function(data, cfg) {
  cycle_col <- survey_var(cfg, "cycle")
  age_col   <- survey_var(cfg, "age")

  year_map <- cfg$cycle_survey_years
  cycle_keys <- as.character(data[[cycle_col]])

  # Map each key individually so missing keys return NA (not NULL)
  survey_years <- vapply(cycle_keys, function(k) {
    v <- year_map[[k]]
    if (is.null(v)) NA_integer_ else as.integer(v)
  }, integer(1))

  missing <- is.na(survey_years)
  if (any(missing)) {
    bad <- unique(cycle_keys[missing])
    stop("Unknown SurveyCycle codes with no year mapping: ", paste(bad, collapse = ", "))
  }

  data$survey_year <- as.integer(survey_years)
  data$cohort      <- data$survey_year - round(data[[age_col]])
  data
}


#' Build combined initiation numerator + denominator dataset
#'
#' @param data Data frame for one sex, with survey_year and cohort columns
#' @param cfg Config object
#' @return Long-format data frame: age, cohort, period, event, weight
build_initiation_data <- function(data, cfg) {
  status_col <- survey_var(cfg, "smoking_status")
  age_col    <- survey_var(cfg, "age_first_cigarette")
  weight_col <- survey_var(cfg, "weight")
  min_age    <- survey_bound(cfg, "age_first_cigarette", "min")
  cohort_min <- cfg$apc$cohort_min
  period_min <- cfg$apc$period_min
  period_max <- cfg$apc$period_max

  # Restrict to valid cohorts
  data <- data[data$cohort >= cohort_min, ]

  # Identify ever-smokers: SMKDSTY_original %in% 1:5, age_first_cigarette >= min_age
  # Never-smokers (SMKDSTY_original = 6) carry NA(a) for age_first_cigarette;
  # 55 is the legitimate midpoint of the "50+ years" category among ever-smokers.
  # SMKDSTY_original categories: 1=daily, 2=occ(fmr daily), 3=always occ, 4=fmr daily, 5=fmr occ, 6=never
  smkdsty <- data[[status_col]]
  ever_smoker <- !is.na(smkdsty) & smkdsty %in% 1:5

  age_init_raw <- data[[age_col]]

  # The analytic floor is survey_bound(cfg, "age_first_cigarette", "min"):
  # 13 for PUMF, 8 for Master per config.yml. Note SMKG01C_cont has a 5-11
  # category (midpoint 8) in all PUMF cycles, so a floor of 13 excludes that
  # group — whether to lower the PUMF floor to 8 is an open study decision.
  # Source of truth for category midpoints: cchsflow variable_details.csv (recEnd).
  ages_among_smokers <- age_init_raw[ever_smoker & !is.na(age_init_raw)]
  if (length(ages_among_smokers) > 0 && min(ages_among_smokers) > 10) {
    warning(
      "min(age_first_cigarette) = ", min(ages_among_smokers),
      " among ever-smokers — early-initiation categories appear absent or ",
      "excluded by the configured floor (", min_age, "). RDC Master run will ",
      "use exact ages."
    )
  }

  # Issue 2: flag implausible initiation ages (age_first > current age)
  age_survey <- data[[survey_var(cfg, "age")]]
  implausible <- ever_smoker & !is.na(age_init_raw) & age_init_raw > age_survey
  n_implausible <- sum(implausible, na.rm = TRUE)
  if (n_implausible > 0) {
    message("Excluding ", n_implausible, " rows with age_first_cigarette > current age.")
  }

  # Valid initiators: ever-smoker, plausible age, age >= min_age
  valid_init <- ever_smoker &
    !is.na(age_init_raw) &
    age_init_raw >= min_age &
    !implausible

  # Numerator: one row per initiator
  num <- data[valid_init, ]
  age_num <- as.integer(round(num[[age_col]]))
  numerator <- data.frame(
    age    = age_num,
    cohort = num$cohort,
    period = num$cohort + age_num,
    event  = rep(1L, nrow(num)),
    weight = num[[weight_col]]
  )

  # Denominator: person-years at risk before initiation
  # Person attributes needed for expand
  denom_source <- data.frame(
    person_id = seq_len(nrow(data)),
    cohort    = data$cohort,
    age_init  = ifelse(valid_init, as.integer(round(age_init_raw)), NA_integer_),
    # Never-smokers and invalid: treat as still at risk through end of period range
    age_survey = as.integer(round(data[[survey_var(cfg, "age")]])),
    weight    = data[[weight_col]]
  )
  # For never-smokers (no initiation), denominator runs to survey age (proxy for period_max)
  # For initiators, denominator runs up to (but not including) age_init
  denom_source$age_denom_max <- ifelse(
    is.na(denom_source$age_init),
    denom_source$age_survey,    # never initiated — at risk through observed age
    denom_source$age_init - 1L  # initiated — at risk until year before initiation
  )

  period_range <- seq(period_min, period_max)

  denominator <- expand_denominator(denom_source, period_range, min_age)

  rbind(numerator, denominator)
}


#' Expand person × period denominator with immediate at-risk filter
#'
#' @param denom_source Data frame with: person_id, cohort, age_denom_max, weight
#' @param period_range Integer vector of calendar years
#' @param min_age Minimum age for being at risk
#' @return Data frame: age, cohort, period, event=0, weight
expand_denominator <- function(denom_source, period_range, min_age) {
  # Vectorised approach: for each person, compute valid period range and expand
  # This avoids materialising the full cross-product before filtering
  rows <- vector("list", nrow(denom_source))

  for (i in seq_len(nrow(denom_source))) {
    p  <- denom_source$person_id[i]
    co <- denom_source$cohort[i]
    am <- denom_source$age_denom_max[i]
    w  <- denom_source$weight[i]

    if (is.na(co) || is.na(am)) next

    # Period range for this person: they are at risk from min_age to age_denom_max
    p_min <- max(period_range[1], co + min_age)
    p_max <- min(period_range[length(period_range)], co + am)

    if (p_max < p_min) next

    ps <- seq(p_min, p_max)
    rows[[i]] <- data.frame(
      age    = as.integer(ps - co),
      cohort = co,
      period = as.integer(ps),
      event  = 0L,
      weight = w
    )
  }

  non_null <- rows[!vapply(rows, is.null, logical(1))]
  if (length(non_null) == 0) {
    return(data.frame(age = integer(0), cohort = integer(0), period = integer(0),
                      event = integer(0), weight = numeric(0)))
  }
  do.call(rbind, non_null)
}


#' Build combined cessation numerator + denominator dataset
#'
#' Restricted to ever-daily smokers using SMKDSTY_original categories:
#'   1 = daily, 2 = occasional (formerly daily), 4 = former daily.
#' Category 3 (always occasional) and 5 (former occasional) are excluded
#' because they never smoked daily. See GH#1.
#'
#' @param data Data frame for one sex, with survey_year and cohort columns
#' @param cfg Config object
#' @return Long-format data frame: age, cohort, period, event, weight
build_cessation_data <- function(data, cfg) {
  status_col  <- survey_var(cfg, "smoking_status")
  quit_col    <- survey_var(cfg, "years_since_quit")
  age_col     <- survey_var(cfg, "age")
  weight_col  <- survey_var(cfg, "weight")
  min_age     <- survey_bound(cfg, "years_since_quit", "min")
  cohort_min  <- cfg$apc$cohort_min
  period_min  <- cfg$apc$period_min
  period_max  <- cfg$apc$period_max

  # SMKDSTY_original: 1=daily, 2=occ(fmr daily), 3=always occ, 4=fmr daily, 5=fmr occ, 6=never
  # Cessation scope: ever-daily smokers only (1, 2, 4). Excludes always-occasional (3)
  # and former-occasional (5) — they never smoked daily so cessation timing is undefined.
  smkdsty_raw <- data[[status_col]]
  in_scope <- !is.na(smkdsty_raw) & smkdsty_raw %in% c(1, 2, 4) & data$cohort >= cohort_min
  data <- data[in_scope, ]

  smkdsty      <- data[[status_col]]
  years_quit   <- data[[quit_col]]
  age_survey   <- data[[age_col]]
  age_cessation <- age_survey - years_quit

  former_daily  <- smkdsty == 4
  current_daily <- smkdsty %in% c(1, 2)

  # Issue 7: plausibility filter for former daily smokers.
  # PUMF: time_quit_smoking_daily top-coded at 15 years; cessation ages below
  # approximately (survey_age - 15) are not directly observed. Master has exact values.
  # Source of truth for bounds: config.yml survey: years_since_quit: pumf/master: max.
  implausible_cess <- former_daily & (
    is.na(age_cessation) | age_cessation < min_age | age_cessation < 0
  )
  n_implausible <- sum(implausible_cess, na.rm = TRUE)
  if (n_implausible > 0) {
    message("Excluding ", n_implausible,
            " cessation rows with age_cessation < ", min_age, " or negative.")
  }

  valid_cess <- former_daily & !implausible_cess & !is.na(age_cessation)

  # Numerator: one row per quitter
  num <- data[valid_cess, ]
  age_cess_int <- as.integer(round(age_cessation[valid_cess]))
  numerator <- data.frame(
    age    = age_cess_int,
    cohort = num$cohort,
    period = num$cohort + age_cess_int,
    event  = rep(1L, nrow(num)),
    weight = num[[weight_col]]
  )

  # Denominator: current and valid former daily smokers at risk of cessation
  in_denom <- valid_cess | current_daily

  age_denom_max <- ifelse(
    valid_cess[in_denom],
    as.integer(round(age_cessation[in_denom])) - 1L,
    as.integer(round(age_survey[in_denom]))
  )

  denom_source <- data.frame(
    person_id     = seq_len(sum(in_denom)),
    cohort        = data$cohort[in_denom],
    age_denom_max = age_denom_max,
    weight        = data[[weight_col]][in_denom]
  )

  period_range <- seq(period_min, period_max)
  denominator  <- expand_denominator(denom_source, period_range, min_age)

  rbind(numerator, denominator)
}


#' Apply mortality survival correction to APC dataset
#'
#' Dispatches on cfg$apc$mortality_method.
#'   "peto" — weight unchanged (Peto approximation, weight × 1.0)
#'   "mport" — not yet implemented
#'
#' @param apc_data Data frame with weight column
#' @param cfg Config object
#' @return apc_data with weight column adjusted
apply_survival_correction <- function(apc_data, cfg) {
  method <- cfg$apc$mortality_method

  if (method == "peto") {
    # Peto stub: weights unchanged
    return(apc_data)
  }

  if (method == "mport") {
    stop(
      "MPoRT mortality correction not yet implemented. ",
      "Set cfg$apc$mortality_method = 'peto' for current pipeline runs. ",
      "See protocol-todo.md issue #4 for interaction with WTS_M."
    )
  }

  stop("Unknown mortality_method: '", method, "'. Expected 'peto' or 'mport'.")
}


# ---------------------------------------------------------------------------
# Stage 8 entry point
# ---------------------------------------------------------------------------

#' Fit APC model for one sex × transition combination
#'
#' Fits a weighted binomial logistic regression on a constrained natural
#' cubic spline basis (Holford et al. 2014). Period and cohort effects are
#' clamped before basis construction to hold them constant beyond the
#' observed range (data-side constraint).
#'
#' @param apc_dataset One element of the list returned by prepare_apc_data()
#' @param model_type Character: "initiation" or "cessation"
#' @param sex Integer: 1 (men) or 2 (women)
#' @param cfg Config object from config::get()
#' @return Fitted glm object with attributes: knots, constraints, model_type,
#'   spline_type, sex
fit_apc_model <- function(apc_dataset, model_type, sex, cfg) {
  basis <- build_spline_basis(apc_dataset, model_type, sex, cfg)
  fit   <- fit_binomial_apc(basis, apc_dataset$event, apc_dataset$weight)

  attr(fit, "knots") <- list(
    age    = cfg$apc$age_knots,
    period = cfg$apc$period_knots,
    cohort = cfg$apc$cohort_knots
  )
  attr(fit, "constraints") <- list(
    period_max = get_period_constraint(model_type, sex, cfg),
    cohort_min = cfg$apc$cohort_constraints$initiation_prior_to,
    cohort_max = cfg$apc$cohort_constraints$cessation_from
  )
  attr(fit, "model_type")  <- model_type
  attr(fit, "spline_type") <- cfg$apc$spline_type
  attr(fit, "sex")         <- sex

  fit
}


# ---------------------------------------------------------------------------
# Stage 8 sub-functions
# ---------------------------------------------------------------------------

#' Filter knots to those strictly inside the observed data range
#'
#' nsp() sets boundary knots automatically at min/max(x). Interior knots
#' outside that range raise an error. This can occur for cessation models
#' where the clamped period range (e.g. 1965–2013) excludes early knots
#' (e.g. 1940, 1950, 1960) specified for the full denominator range.
#'
#' @param x Numeric vector of observed values
#' @param knots Numeric vector of candidate interior knot positions
#' @return Numeric vector of knots strictly inside (min(x), max(x))
interior_knots <- function(x, knots) {
  lo <- min(x, na.rm = TRUE)
  hi <- max(x, na.rm = TRUE)
  knots[knots > lo & knots < hi]
}


#' Build combined age-period-cohort spline basis matrix
#'
#' Applies period and cohort clamping, then constructs natural spline bases
#' for each dimension. Dispatches on cfg$apc$spline_type ("nsp" or "rcs").
#'
#' @param apc_dataset Data frame with age, period, cohort columns
#' @param model_type "initiation" or "cessation"
#' @param sex 1 or 2
#' @param cfg Config object
#' @return Named matrix: columns age_1...age_k, period_1...period_k,
#'   cohort_1...cohort_k (intercept = FALSE in all bases)
build_spline_basis <- function(apc_dataset, model_type, sex, cfg) {
  period_constraint <- get_period_constraint(model_type, sex, cfg)
  cohort_prior      <- cfg$apc$cohort_constraints$initiation_prior_to
  cohort_from       <- cfg$apc$cohort_constraints$cessation_from

  period_clamped <- pmin(apc_dataset$period, period_constraint)
  cohort_clamped <- pmin(pmax(apc_dataset$cohort, cohort_prior), cohort_from)

  # Filter interior knots to those strictly inside the observed data range.
  # nsp() boundary knots are set automatically at min/max(x); interior knots
  # outside that range cause an error. This can happen for cessation where the
  # effective period range (1965–2013 after clamping) excludes the early
  # period knots (1940, 1950, 1960) inherited from the full denominator spec.
  age_knots    <- interior_knots(apc_dataset$age, cfg$apc$age_knots)
  period_knots <- interior_knots(period_clamped,  cfg$apc$period_knots)
  cohort_knots <- interior_knots(cohort_clamped,  cfg$apc$cohort_knots)

  spline_type <- cfg$apc$spline_type

  if (spline_type == "nsp") {
    if (!requireNamespace("splines2", quietly = TRUE)) {
      stop("Package 'splines2' required for spline_type = 'nsp'. Install with renv::install('splines2').")
    }
    age_basis    <- splines2::nsp(apc_dataset$age, knots = age_knots,    intercept = FALSE)
    period_basis <- splines2::nsp(period_clamped,  knots = period_knots, intercept = FALSE)
    cohort_basis <- splines2::nsp(cohort_clamped,  knots = cohort_knots, intercept = FALSE)

  } else if (spline_type == "rcs") {
    if (!requireNamespace("rms", quietly = TRUE)) {
      stop("Package 'rms' required for spline_type = 'rcs'. Install with renv::install('rms').")
    }
    age_basis    <- rms::rcs(apc_dataset$age, knots = age_knots)
    period_basis <- rms::rcs(period_clamped,  knots = period_knots)
    cohort_basis <- rms::rcs(cohort_clamped,  knots = cohort_knots)

  } else {
    stop("Unknown spline_type: '", spline_type, "'. Expected 'nsp' or 'rcs'.")
  }

  colnames(age_basis)    <- paste0("age_",    seq_len(ncol(age_basis)))
  colnames(period_basis) <- paste0("period_", seq_len(ncol(period_basis)))
  colnames(cohort_basis) <- paste0("cohort_", seq_len(ncol(cohort_basis)))

  cbind(age_basis, period_basis, cohort_basis)
}


#' Look up the period constraint year for a given model type and sex
#'
#' @param model_type "initiation" or "cessation"
#' @param sex 1 (men) or 2 (women)
#' @param cfg Config object
#' @return Integer year beyond which the period effect is held constant
get_period_constraint <- function(model_type, sex, cfg) {
  pc <- cfg$apc$period_constraints

  if (model_type == "initiation") {
    if (sex == 2) return(pc$initiation_women_from)
    if (sex == 1) return(pc$initiation_men_from)
    stop("sex must be 1 or 2, got: ", sex)
  }

  if (model_type == "cessation") {
    return(pc$cessation_from)
  }

  stop("model_type must be 'initiation' or 'cessation', got: ", model_type)
}


#' Aggregate person-years to age-period-cohort cells and fit binomial APC model
#'
#' Follows the SAS PROC MEANS → PROC GENMOD pattern from Modeling2013.sas:
#' survey weights are summed within each (age, period, cohort) cell to produce
#' weighted numerator (d) and denominator (pop), then fitted as
#' glm(cbind(d, pop - d) ~ basis, family = binomial).
#'
#' Fitting on individual-level rows with raw weights causes numerical failure
#' because large survey weights (~10,000) create extreme leverage, driving
#' glm.fit to push some probabilities to exactly 0 or 1.
#'
#' @param basis_matrix Named matrix from build_spline_basis()
#' @param event Integer vector of 0/1 outcomes
#' @param weight Numeric vector of survey weights
#' @return Fitted glm object (family = binomial)
fit_binomial_apc <- function(basis_matrix, event, weight) {
  # Aggregate to unique basis rows (= unique age-period-cohort cells after clamping)
  df <- as.data.frame(basis_matrix)
  df$.event  <- event
  df$.weight <- weight

  # Sum weighted events (d) and weighted person-years (pop) per unique cell
  agg_key  <- do.call(paste, c(df[, !names(df) %in% c(".event", ".weight"), drop = FALSE], sep = "|"))
  cell_ids <- match(agg_key, unique(agg_key))
  n_cells  <- max(cell_ids)

  d   <- vapply(seq_len(n_cells), function(i) sum(df$.weight[cell_ids == i & df$.event == 1]), numeric(1))
  pop <- vapply(seq_len(n_cells), function(i) sum(df$.weight[cell_ids == i]), numeric(1))

  # Extract one basis row per unique cell
  cell_rows <- match(seq_len(n_cells), cell_ids)
  basis_agg <- basis_matrix[cell_rows, , drop = FALSE]

  cell_df <- as.data.frame(basis_agg)
  cell_df$.d   <- d
  cell_df$.pop <- pop

  glm(cbind(.d, .pop - .d) ~ . - .d - .pop, data = cell_df,
      family = binomial(),
      control = glm.control(maxit = 100, epsilon = 1e-8))
}
