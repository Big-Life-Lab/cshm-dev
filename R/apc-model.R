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
#' or an at-risk person-year (event = 0). Applies the mortality survival
#' correction selected by cfg$apc$mortality_method ("none" until MPoRT is
#' implemented; see apply_survival_correction()).
#'
#' @param analysis_data Output of impute_data()
#' @param cfg Config object from config::get()
#' @return Named list: initiation_men, initiation_women, cessation_men,
#'   cessation_women. Each element is a data frame with columns:
#'   age, cohort, period, event, weight.
prepare_apc_data <- function(analysis_data, cfg) {
  data <- derive_survey_year(analysis_data, cfg)

  sex <- data[[survey_var(cfg, "sex")]]
  men <- !is.na(sex) & sex == survey_code(cfg, "sex", "men_code")
  women <- !is.na(sex) & sex == survey_code(cfg, "sex", "women_code")
  init_men <- build_initiation_data(data[men, ], cfg)
  init_women <- build_initiation_data(data[women, ], cfg)
  cess_men <- build_cessation_data(data[men, ], cfg)
  cess_women <- build_cessation_data(data[women, ], cfg)

  list(
    initiation_men   = apply_survival_correction(init_men, cfg),
    initiation_women = apply_survival_correction(init_women, cfg),
    cessation_men    = apply_survival_correction(cess_men, cfg),
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
  age_col <- survey_var(cfg, "age")

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
  data$cohort <- data$survey_year - round(data[[age_col]])
  data
}


#' Build the initiation numerator and denominator dataset
#'
#' Implements the estimand specification. Never smokers (status = never code) and
#' experimental smokers (smoked a whole cigarette but fewer than 100) are at risk
#' from the study floor age to the survey year, with no event. Established
#' smokers (100 or more cigarettes) have one event at their age at first whole
#' cigarette and are at risk from the floor age to the year before it. An
#' established smoker whose entry age is below the floor was already smoking
#' when observation begins and contributes nothing to this model (they remain in
#' the cessation model). Records with a missing status, a missing 100-cigarette
#' answer among ever-smokers, a missing entry age, or an entry age after the
#' survey age or outside the configured bounds are excluded and counted; task
#' 1.8c routes them through imputation. Nobody is reclassified as Never because
#' their information is missing.
#'
#' @param data Analysis data (one row per respondent) with a `cohort` column
#' @param cfg Config object
#' @return Data frame with age, cohort, period, event, weight, plus the attribute
#'   `initiation_diagnostics` (per-cycle counts, unweighted and weighted)
build_initiation_data <- function(data, cfg) {
  status_col <- survey_var(cfg, "smoking_status")
  init_col <- survey_var(cfg, "age_first_cigarette")
  age_col <- survey_var(cfg, "age")
  weight_col <- survey_var(cfg, "weight")
  cycle_col <- survey_var(cfg, "cycle")
  smoked_100_col <- survey_var(cfg, "established_smoker")
  smoked_100_yes <- survey_code(cfg, "established_smoker", "yes_code")
  ever_codes <- survey_code(cfg, "smoking_status", "ever_codes")
  never_code <- survey_code(cfg, "smoking_status", "never_code")
  floor_age <- survey_bound(cfg, "age_first_cigarette", "min")
  init_max <- survey_bound(cfg, "age_first_cigarette", "max")
  cohort_min <- cfg$apc$cohort_min
  period_min <- cfg$apc$period_min
  period_max <- cfg$apc$period_max

  data <- data[!is.na(data$cohort) & data$cohort >= cohort_min, ]

  smk <- data[[status_col]]
  smoked_100 <- data[[smoked_100_col]]
  age_init <- as.integer(round(data[[init_col]]))
  age_survey <- as.integer(round(data[[age_col]]))
  weight <- data[[weight_col]]
  cycle <- as.character(data[[cycle_col]])

  status_missing <- is.na(smk)
  never <- !status_missing & smk == never_code
  ever_status <- !status_missing & smk %in% ever_codes
  criterion_missing <- ever_status & is.na(smoked_100)
  experimental <- ever_status & !is.na(smoked_100) & smoked_100 != smoked_100_yes
  established <- ever_status & !is.na(smoked_100) & smoked_100 == smoked_100_yes
  missing_entry <- established & is.na(age_init)
  entry_invalid <- established & !is.na(age_init) &
    (age_init > age_survey | age_init > init_max | age_init < 0)
  entry_before_floor <- established & !is.na(age_init) & !entry_invalid & age_init < floor_age
  initiator <- established & !is.na(age_init) & !entry_invalid & age_init >= floor_age
  at_risk_to_survey <- never | experimental
  excluded <- status_missing | criterion_missing | missing_entry | entry_invalid

  groups <- list(
    respondents = rep(TRUE, nrow(data)),
    never_smokers = never,
    experimental_smokers = experimental,
    initiators = initiator,
    entered_before_floor = entry_before_floor,
    excluded_status_missing = status_missing,
    excluded_criterion_missing = criterion_missing,
    excluded_missing_entry = missing_entry,
    excluded_entry_invalid = entry_invalid
  )
  diag <- summarise_groups(groups, cycle, weight)
  totals <- vapply(groups, sum, numeric(1))
  message(
    "Initiation risk set: ", totals[["respondents"]], " respondents; ",
    totals[["initiators"]], " initiators (events); ", totals[["never_smokers"]],
    " never and ", totals[["experimental_smokers"]], " experimental smokers at risk; ",
    totals[["entered_before_floor"]], " entered before the floor age (no rows). ",
    "Excluded pending imputation: ", totals[["excluded_status_missing"]], " status missing, ",
    totals[["excluded_criterion_missing"]], " 100-cigarette answer missing, ",
    totals[["excluded_missing_entry"]], " entry age missing, ",
    totals[["excluded_entry_invalid"]], " entry age invalid."
  )

  numerator <- data.frame(
    age = age_init[initiator],
    cohort = data$cohort[initiator],
    period = data$cohort[initiator] + age_init[initiator],
    event = rep(1L, sum(initiator)),
    weight = weight[initiator]
  )

  in_denom <- at_risk_to_survey | initiator
  age_denom_max <- ifelse(initiator[in_denom], age_init[in_denom] - 1L, age_survey[in_denom])
  denom_source <- data.frame(
    person_id = seq_len(sum(in_denom)),
    cohort = data$cohort[in_denom],
    age_denom_min = rep(floor_age, sum(in_denom)),
    age_denom_max = age_denom_max,
    weight = weight[in_denom]
  )
  period_range <- seq(period_min, period_max)
  denominator <- expand_denominator(denom_source, period_range, floor_age)

  out <- rbind(numerator, denominator)
  attr(out, "initiation_diagnostics") <- diag
  out
}


#' Per-cycle counts (unweighted and weighted) for a list of logical groups
#'
#' @param groups Named list of logical vectors of equal length
#' @param cycle Character vector of cycle codes, same length
#' @param weight Numeric weights, same length
#' @return Data frame: group, cycle, n, weighted
summarise_groups <- function(groups, cycle, weight) {
  empty <- data.frame(
    group = character(0), cycle = character(0),
    n = integer(0), weighted = numeric(0), stringsAsFactors = FALSE
  )
  if (length(cycle) == 0) {
    return(empty)
  }
  do.call(rbind, lapply(names(groups), function(g) {
    sel <- groups[[g]]
    agg_n <- tapply(as.integer(sel), cycle, sum)
    agg_w <- tapply(weight * sel, cycle, sum)
    agg_n[is.na(agg_n)] <- 0L
    agg_w[is.na(agg_w)] <- 0
    data.frame(
      group = g, cycle = names(agg_n), n = as.integer(agg_n),
      weighted = as.numeric(agg_w), stringsAsFactors = FALSE
    )
  }))
}


#' Expand denominator person-years
#'
#' One row per person-year at risk, from each person's own start age to their
#' `age_denom_max`, restricted to the calendar window `period_range`.
#'
#' @param denom_source Data frame with: person_id, cohort, age_denom_max, weight,
#'   and optionally `age_denom_min` (per-person start age; time at risk of
#'   cessation begins at each person's own entry age). Rows without it use `min_age`.
#' @param period_range Integer vector of calendar years
#' @param min_age Default minimum age for being at risk (used when
#'   `age_denom_min` is absent or NA)
#' @return Data frame: age, cohort, period, event=0, weight
expand_denominator <- function(denom_source, period_range, min_age) {
  empty <- data.frame(
    age = integer(0), cohort = integer(0), period = integer(0),
    event = integer(0), weight = numeric(0)
  )
  n <- nrow(denom_source)
  if (n == 0) {
    return(empty)
  }
  age_min <- if ("age_denom_min" %in% names(denom_source)) {
    ifelse(is.na(denom_source$age_denom_min), min_age, denom_source$age_denom_min)
  } else {
    rep(min_age, n)
  }
  rows <- vector("list", n)
  age_min <- as.integer(round(age_min))
  for (i in seq_len(n)) {
    co <- as.integer(round(denom_source$cohort[i]))
    am <- as.integer(round(denom_source$age_denom_max[i]))
    w <- denom_source$weight[i]
    if (is.na(am) || is.na(co)) next
    # At risk from their own start age to age_denom_max, within the calendar window
    p_min <- max(period_range[1], co + age_min[i])
    p_max <- min(period_range[length(period_range)], co + am)
    if (p_min > p_max) next
    periods <- p_min:p_max
    rows[[i]] <- data.frame(
      age = periods - co, cohort = co, period = periods, event = 0L, weight = w
    )
  }
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0) {
    return(empty)
  }
  do.call(rbind, rows)
}


#' Build the cessation numerator and denominator dataset
#'
#' Implements the estimand specification (docs/development/estimand-specification.md).
#' The model includes established smokers (100 or more cigarettes; SMKDSTY 1 to 5).
#' The event is stopping smoking completely, dated by `years_since_quit_complete`.
#' Each person's time at risk begins at their own age at first whole cigarette.
#' A quit counts only if it has lasted `cfg$apc$cessation_durability_years` at the
#' survey; otherwise the person is current at survey and censored at the quit age.
#' A person who started and stopped at the same age contributes one trial, with the event.
#'
#' People whose entry age is missing or later than the survey age, whose quit
#' precedes their entry, or whose quit timing is missing (including the 2001
#' cycle, where complete-cessation timing was not asked) are excluded here and
#' counted. The counts, per cycle, are the `cessation_diagnostics` attribute.
#' Task 1.8c routes these people through imputation.
#'
#' @param data Analysis data (one row per respondent) with a `cohort` column
#' @param cfg Config object
#' @return Data frame with age, cohort, period, event, weight, plus the attribute
#'   `cessation_diagnostics` (per-cycle counts, unweighted and weighted)
build_cessation_data <- function(data, cfg) {
  status_col <- survey_var(cfg, "smoking_status")
  smoked_100_col <- survey_var(cfg, "established_smoker")
  smoked_100_yes <- survey_code(cfg, "established_smoker", "yes_code")
  quit_col <- survey_var(cfg, "years_since_quit_complete")
  init_col <- survey_var(cfg, "age_first_cigarette")
  age_col <- survey_var(cfg, "age")
  weight_col <- survey_var(cfg, "weight")
  cycle_col <- survey_var(cfg, "cycle")
  floor_age <- survey_bound(cfg, "age_first_cigarette", "min") # default for expand_denominator only
  durability <- cfg$apc$cessation_durability_years
  if (is.null(durability)) stop("cfg$apc$cessation_durability_years is not set.")
  quit_min <- survey_bound(cfg, "years_since_quit_complete", "min")
  quit_max <- survey_bound(cfg, "years_since_quit_complete", "max")
  cohort_min <- cfg$apc$cohort_min
  period_min <- cfg$apc$period_min
  period_max <- cfg$apc$period_max

  data <- data[!is.na(data$cohort) & data$cohort >= cohort_min, ]

  # Included population: established smokers. Status codes and their state groupings come
  # from config (survey.smoking_status.*_codes), not from literals here.
  ever_codes <- survey_code(cfg, "smoking_status", "ever_codes")
  current_codes <- survey_code(cfg, "smoking_status", "current_codes")
  former_codes <- survey_code(cfg, "smoking_status", "former_codes")
  smk <- data[[status_col]]
  smoked_100 <- data[[smoked_100_col]]
  established <- !is.na(smk) & smk %in% ever_codes & !is.na(smoked_100) & smoked_100 == smoked_100_yes
  d <- data[established, ]
  smk <- d[[status_col]]

  age_init <- as.integer(round(d[[init_col]]))
  age_survey <- as.integer(round(d[[age_col]]))
  yrs_quit <- as.numeric(d[[quit_col]])
  age_quit <- as.integer(round(age_survey - yrs_quit))
  weight <- d[[weight_col]]
  cycle <- as.character(d[[cycle_col]]) # observed cycles only; avoids NA sums for empty levels

  current <- smk %in% current_codes
  former <- smk %in% former_codes

  # Classification: each established smoker falls in exactly one group
  missing_entry <- is.na(age_init)
  entry_after_survey <- !missing_entry & age_init > age_survey
  timing_missing <- former & is.na(yrs_quit)
  # Quit timing must be finite, within the configured bounds for the source
  # (PUMF top-code, Master ceiling), and place the quit no later than the survey.
  timing_invalid <- former & !is.na(yrs_quit) &
    (!is.finite(yrs_quit) | yrs_quit < quit_min | yrs_quit > quit_max |
      is.na(age_quit) | age_quit > age_survey | age_quit < 0)
  quit_before_entry <- former & !is.na(age_quit) & !timing_invalid & !missing_entry & age_quit < age_init
  excluded <- missing_entry | entry_after_survey | timing_missing | timing_invalid | quit_before_entry
  recent <- !excluded & former & yrs_quit < durability
  durable <- !excluded & former & yrs_quit >= durability
  same_age <- durable & age_quit == age_init

  groups <- list(
    established = rep(TRUE, nrow(d)),
    current_at_survey = !excluded & current,
    durable_quitters = durable,
    recent_quitters_censored = recent,
    same_age_quits = same_age,
    excluded_missing_entry = missing_entry,
    excluded_entry_after_survey = entry_after_survey,
    excluded_timing_missing = timing_missing,
    excluded_quit_timing_invalid = timing_invalid,
    excluded_quit_before_entry = quit_before_entry
  )
  diag <- summarise_groups(groups, cycle, weight)
  totals <- vapply(groups, sum, numeric(1))
  message(
    "Cessation risk set: ", totals[["established"]], " established smokers; ",
    totals[["durable_quitters"]], " durable quitters (events); ",
    totals[["recent_quitters_censored"]], " recent quitters censored; ",
    totals[["same_age_quits"]], " started and stopped at the same age. Excluded pending imputation: ",
    totals[["excluded_missing_entry"]], " missing entry age, ",
    totals[["excluded_entry_after_survey"]], " entry after survey, ",
    totals[["excluded_timing_missing"]], " missing quit timing, ",
    totals[["excluded_quit_timing_invalid"]], " quit timing out of bounds, ",
    totals[["excluded_quit_before_entry"]], " quit before entry."
  )

  # Numerator: one event row per durable quitter, at the quit age
  numerator <- data.frame(
    age = age_quit[durable],
    cohort = d$cohort[durable],
    period = d$cohort[durable] + age_quit[durable],
    event = rep(1L, sum(durable)),
    weight = weight[durable]
  )

  # Denominator: person-years at risk without an event. Current smokers are at
  # risk from entry to the survey year (included as a full year). Durable and
  # recent quitters are at risk from entry to the year before the quit year: the
  # quit year is the event row for durable quitters and unobservable for recent
  # quitters. Someone who started and stopped at the same age has no denominator row;
  # their one trial is the event.
  in_denom <- !excluded & (current | durable | recent)
  age_denom_max <- ifelse(current[in_denom], age_survey[in_denom], age_quit[in_denom] - 1L)
  denom_source <- data.frame(
    person_id = seq_len(sum(in_denom)),
    cohort = d$cohort[in_denom],
    age_denom_min = age_init[in_denom], # each person's own entry age; the floor is reporting-only
    age_denom_max = age_denom_max,
    weight = weight[in_denom]
  )
  period_range <- seq(period_min, period_max)
  denominator <- expand_denominator(denom_source, period_range, floor_age)

  out <- rbind(numerator, denominator)
  attr(out, "cessation_diagnostics") <- diag
  out
}


#' Apply the mortality survival correction to an APC dataset
#'
#' Dispatches on `cfg$apc$mortality_method` (protocol section 3.4.5):
#'   "none"  -- no correction. Weights stay as survey weights and the result is
#'              labelled so downstream outputs are reported as estimates among
#'              respondents who survived to be surveyed, not as birth-cohort
#'              smoking histories.
#'   "mport" -- MPoRT survival-bias adjustment (primary method; not yet
#'              implemented, remediation task 1.7b).
#'   "peto"  -- constant mortality risk ratio by smoking status (sensitivity
#'              analysis; not yet implemented).
#'
#' A method other than "none" must change the weights. If it leaves every weight
#' unchanged the function stops, so a no-op can never be mistaken for a
#' correction (this is what happened when "peto" was a stub).
#'
#' @param apc_data Data frame with a `weight` column
#' @param cfg Config object
#' @return `apc_data` with the `weight` column adjusted and the attribute
#'   `mortality_correction` set to the method applied
apply_survival_correction <- function(apc_data, cfg) {
  method <- cfg$apc$mortality_method
  valid <- c("none", "mport", "peto")
  if (!is.character(method) || length(method) != 1 || !method %in% valid) {
    stop(
      "Unknown mortality_method: '", paste(method, collapse = ","),
      "'. Expected one of: ", paste(valid, collapse = ", "), "."
    )
  }

  if (method == "none") {
    attr(apc_data, "mortality_correction") <- "none"
    attr(apc_data, "estimand_note") <- paste(
      "No mortality correction applied: estimates describe respondents who",
      "survived to be surveyed (protocol section 3.4.5)."
    )
    return(apc_data)
  }

  corrected <- switch(method,
    mport = stop(
      "MPoRT mortality correction is not yet implemented (remediation task 1.7b). ",
      "Set cfg$apc$mortality_method = 'none' and report results as estimates ",
      "among survivors."
    ),
    peto = stop(
      "Peto constant-risk-ratio correction is not yet implemented (sensitivity ",
      "analysis). Set cfg$apc$mortality_method = 'none' and report results as ",
      "estimates among survivors."
    )
  )

  assert_correction_applied(apc_data, corrected, method)
  attr(corrected, "mortality_correction") <- method
  corrected
}


#' Guard: a configured mortality correction must change the weights and nothing else
#'
#' Checks that `after` is the same person-year table as `before` -- same rows, in
#' the same order, with the same `age`, `period`, `cohort`, and `event` values --
#' that every weight is finite and positive, and that at least one weight changed.
#'
#' @param before,after Data frames with a `weight` column
#' @param method The method name, for the error message
#' @return `invisible(TRUE)`; stops on any violation
assert_correction_applied <- function(before, after, method) {
  if (!"weight" %in% names(before) || !"weight" %in% names(after)) {
    stop("mortality_method = '", method, "': both datasets must have a weight column.")
  }
  if (nrow(before) != nrow(after)) {
    stop(
      "mortality_method = '", method, "' changed the number of rows (",
      nrow(before), " -> ", nrow(after), "). A correction may only change weights."
    )
  }
  keys <- intersect(c("age", "period", "cohort", "event"), names(before))
  for (k in keys) {
    if (!identical(before[[k]], after[[k]])) {
      stop(
        "mortality_method = '", method, "' changed or reordered column '", k,
        "'. A correction may only change weights."
      )
    }
  }
  if (any(!is.finite(after$weight)) || any(after$weight <= 0)) {
    stop("mortality_method = '", method, "' produced non-finite or non-positive weights.")
  }
  if (isTRUE(all.equal(before$weight, after$weight))) {
    stop(
      "mortality_method = '", method, "' left every weight unchanged. ",
      "A configured correction must change the weights; use 'none' to run ",
      "without a correction."
    )
  }
  invisible(TRUE)
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
  fit <- fit_binomial_apc(basis, apc_dataset$event, apc_dataset$weight)

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
  attr(fit, "model_type") <- model_type
  attr(fit, "spline_type") <- cfg$apc$spline_type
  attr(fit, "sex") <- sex
  # Carry the mortality-correction label and estimand note from the APC dataset
  # so Stage 8 outputs cannot be mistaken for corrected models.
  attr(fit, "mortality_correction") <- attr(apc_dataset, "mortality_correction") %||% cfg$apc$mortality_method
  attr(fit, "estimand_note") <- attr(apc_dataset, "estimand_note")

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
  cohort_prior <- cfg$apc$cohort_constraints$initiation_prior_to
  cohort_from <- cfg$apc$cohort_constraints$cessation_from

  period_clamped <- pmin(apc_dataset$period, period_constraint)
  cohort_clamped <- pmin(pmax(apc_dataset$cohort, cohort_prior), cohort_from)

  # Filter interior knots to those strictly inside the observed data range.
  # nsp() boundary knots are set automatically at min/max(x); interior knots
  # outside that range cause an error. This can happen for cessation where the
  # effective period range (1965–2013 after clamping) excludes the early
  # period knots (1940, 1950, 1960) inherited from the full denominator spec.
  age_knots <- interior_knots(apc_dataset$age, cfg$apc$age_knots)
  period_knots <- interior_knots(period_clamped, cfg$apc$period_knots)
  cohort_knots <- interior_knots(cohort_clamped, cfg$apc$cohort_knots)

  spline_type <- cfg$apc$spline_type

  if (spline_type == "nsp") {
    if (!requireNamespace("splines2", quietly = TRUE)) {
      stop("Package 'splines2' required for spline_type = 'nsp'. Install with renv::install('splines2').")
    }
    age_basis <- splines2::nsp(apc_dataset$age, knots = age_knots, intercept = FALSE)
    period_basis <- splines2::nsp(period_clamped, knots = period_knots, intercept = FALSE)
    cohort_basis <- splines2::nsp(cohort_clamped, knots = cohort_knots, intercept = FALSE)
  } else if (spline_type == "rcs") {
    if (!requireNamespace("rms", quietly = TRUE)) {
      stop("Package 'rms' required for spline_type = 'rcs'. Install with renv::install('rms').")
    }
    age_basis <- rms::rcs(apc_dataset$age, knots = age_knots)
    period_basis <- rms::rcs(period_clamped, knots = period_knots)
    cohort_basis <- rms::rcs(cohort_clamped, knots = cohort_knots)
  } else {
    stop("Unknown spline_type: '", spline_type, "'. Expected 'nsp' or 'rcs'.")
  }

  colnames(age_basis) <- paste0("age_", seq_len(ncol(age_basis)))
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
    if (sex == survey_code(cfg, "sex", "women_code")) {
      return(pc$initiation_women_from)
    }
    if (sex == survey_code(cfg, "sex", "men_code")) {
      return(pc$initiation_men_from)
    }
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
  if (length(event) == 0) {
    stop("fit_binomial_apc: no person-year rows to fit.")
  }
  # Aggregate to unique basis rows (= unique age-period-cohort cells after clamping)
  df <- as.data.frame(basis_matrix)
  df$.event <- event
  df$.weight <- weight

  # Sum weighted events (d) and weighted person-years (pop) per unique cell
  agg_key <- do.call(paste, c(df[, !names(df) %in% c(".event", ".weight"), drop = FALSE], sep = "|"))
  cell_ids <- match(agg_key, unique(agg_key))
  n_cells <- max(cell_ids)

  d <- vapply(seq_len(n_cells), function(i) sum(df$.weight[cell_ids == i & df$.event == 1]), numeric(1))
  pop <- vapply(seq_len(n_cells), function(i) sum(df$.weight[cell_ids == i]), numeric(1))

  # Extract one basis row per unique cell
  cell_rows <- match(seq_len(n_cells), cell_ids)
  basis_agg <- basis_matrix[cell_rows, , drop = FALSE]

  cell_df <- as.data.frame(basis_agg)
  cell_df$.d <- d
  cell_df$.pop <- pop

  # Guards (public issue #3, items 4 and 7): a model fitted to no events, or that
  # did not converge, stops with an error rather than returning a fit that looks valid.
  if (sum(event == 1) == 0 || sum(d) <= 0) {
    stop(
      "fit_binomial_apc: the numerator is empty (", sum(event == 1), " event rows, ",
      "weighted events = ", sum(d), "). A model with no events would estimate ",
      "that this transition never happens."
    )
  }
  if (any(pop <= 0) || any(d > pop)) {
    stop("fit_binomial_apc: a cell has non-positive person-years or more events than person-years.")
  }

  fit <- glm(cbind(.d, .pop - .d) ~ . - .d - .pop,
    data = cell_df,
    family = binomial(),
    control = glm.control(maxit = 100, epsilon = 1e-8)
  )
  if (!isTRUE(fit$converged)) {
    stop("fit_binomial_apc: glm did not converge (", fit$iter, " iterations).")
  }
  if (isTRUE(fit$boundary)) {
    warning("fit_binomial_apc: glm stopped at the boundary of the parameter space; inspect the fit.")
  }
  fit
}
