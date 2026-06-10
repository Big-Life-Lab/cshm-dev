# imputation.R
# Multiple imputation via MICE for missing smoking history variables.
# Pipeline target: analysis_data
#
# Specification: docs/protocol/appendix-imputation.qmd (protocol v0.3.0).
# Three design points distinguish this from the DemPoRT-V2 implementation:
#   1. An explicit `where` matrix restricts imputation to item non-response
#      (NA(b)); structural missingness (NA(a) not-applicable, NA(c) not asked)
#      is never imputed. haven::tagged_na() values are plain NA to mice(),
#      so without the where matrix MICE would impute structural cells.
#   2. Survey design variables (cycle, weight) enter the imputation model as
#      predictors, making the imputation design-consistent.
#   3. All m completed datasets are retained; Table 1b averages across them
#      and the APC stage starts from imputation 1 (upgrade path: Rubin pooling).

#' Impute missing values via MICE
#'
#' Imputes NA(b) (don't know/refused) cells for variables carrying the
#' `imputation-predictor` role. Structural missingness — NA(a) (not
#' applicable) and NA(c) (not asked this cycle) — is preserved untouched:
#' only cells flagged in the `where` matrix are ever written back, so tagged
#' NAs survive by construction.
#'
#' @param cleaned_data Output of clean_study_data()
#' @param variables_sheet Variables worksheet data frame
#' @param cfg Config object from config::get() (uses imputation_m, imputation_maxit)
#' @return List:
#'   \describe{
#'     \item{datasets}{List of m completed data frames (full columns; only
#'       NA(b) cells differ from cleaned_data)}
#'     \item{m}{Number of imputations}
#'     \item{imputed_cells}{Data frame: variable, n_imputed — audit of which
#'       cells were filled}
#'     \item{logged_events}{mice loggedEvents data frame (NULL if none)}
#'   }
impute_data <- function(cleaned_data, variables_sheet, cfg) {
  impute_vars <- select_vars_by_role("imputation-predictor", variables_sheet)
  missing_from_data <- setdiff(impute_vars, colnames(cleaned_data))
  if (length(missing_from_data) > 0) {
    stop(
      "Imputation-predictor variables absent from data: ",
      paste(missing_from_data, collapse = ", "),
      " — check harmonization output before imputing."
    )
  }

  # Build the MICE modelling frame and the where matrix (TRUE = NA(b) cell)
  prep <- prepare_for_mice(cleaned_data, impute_vars)

  n_imputable <- colSums(prep$where)
  imputed_cells <- data.frame(
    variable  = names(n_imputable),
    n_imputed = unname(n_imputable),
    stringsAsFactors = FALSE
  )
  message(
    "Imputation targets (NA(b) cells):\n",
    paste(sprintf(
      "  %s: %d", imputed_cells$variable[imputed_cells$n_imputed > 0],
      imputed_cells$n_imputed[imputed_cells$n_imputed > 0]
    ), collapse = "\n")
  )

  if (sum(prep$where) == 0) {
    message("No NA(b) cells found — returning cleaned data unchanged (m = 1).")
    return(list(
      datasets = list(cleaned_data), m = 1L,
      imputed_cells = imputed_cells, logged_events = NULL
    ))
  }

  m <- cfg$imputation_m %||% 5
  maxit <- cfg$imputation_maxit %||% 5
  message("Running MICE: m=", m, ", maxit=", maxit)

  # Predictor matrix: variables with structural missingness (plain NA in the
  # modelling frame at where = FALSE cells, i.e. NA(a)/NA(c) in the source)
  # may BE imputed but must not SERVE as predictors. mice excludes rows with
  # missing predictors from each conditional model, so a structural-NA
  # predictor (e.g. time-since-quit, NA(a) for current and never-smokers)
  # would make most NA(b) cells in other variables unpredictable. The
  # complete design and auxiliary variables form the predictor core.
  has_structural <- vapply(impute_vars, function(v) {
    any(is.na(prep$data[[v]]) & !prep$where[, v])
  }, logical(1))
  pred_matrix <- mice::make.predictorMatrix(prep$data)
  if (any(has_structural)) {
    pred_matrix[, impute_vars[has_structural]] <- 0L
    message(
      "Excluded as predictors (structural missingness): ",
      paste(impute_vars[has_structural], collapse = ", ")
    )
  }

  mice_result <- mice::mice(
    prep$data,
    m               = m,
    maxit           = maxit,
    where           = prep$where,
    predictorMatrix = pred_matrix,
    printFlag       = FALSE
  )

  # Surface silently dropped/altered variables (constant, collinear, etc.).
  # Dropping a prespecified design predictor (weight, cycle, sex) silently
  # voids a protocol property — that is an error, not a warning.
  logged <- mice_result$loggedEvents
  if (!is.null(logged) && nrow(logged) > 0) {
    design_vars <- intersect(
      c("WTS_M", "SurveyCycle", "DHH_SEX", "DHHGAGE_cont"), impute_vars
    )
    dropped <- unique(unlist(strsplit(as.character(logged$out), ",\\s*")))
    # mice logs factor predictors as variable+level (e.g. "SurveyCycle10")
    design_dropped <- design_vars[vapply(design_vars, function(v) {
      any(dropped == v)
    }, logical(1))]
    if (length(design_dropped) > 0) {
      stop(
        "MICE dropped prespecified design predictor(s) from the imputation ",
        "model: ", paste(design_dropped, collapse = ", "),
        " — the design-consistency property of the protocol no longer holds. ",
        "Inspect loggedEvents and the predictor matrix.", call. = FALSE
      )
    }
    warning(
      "MICE logged events (variables dropped or altered in the imputation model):\n",
      paste(capture.output(print(logged)), collapse = "\n"),
      call. = FALSE
    )
  }

  # Convergence check, scoped to the variables that were actually imputed.
  # (Variables with zero where-TRUE cells always have NaN chain means, so an
  # unscoped check would warn on every healthy run.)
  imputed_vars <- imputed_cells$variable[imputed_cells$n_imputed > 0]
  cm <- mice_result$chainMean[
    intersect(imputed_vars, dimnames(mice_result$chainMean)[[1]]), , ,
    drop = FALSE
  ]
  if (length(cm) > 0 && any(!is.finite(cm))) {
    bad <- dimnames(cm)[[1]][apply(!is.finite(cm), 1, any)]
    stop(
      "Non-finite MICE chain means for imputed variable(s): ",
      paste(bad, collapse = ", "),
      " — degenerate fit; inspect mice::plot() before proceeding.",
      call. = FALSE
    )
  }

  # Write back: for each imputation, copy ONLY where-matrix cells into the
  # original data. Everything else — including tagged NA(a)/NA(c) and the
  # original factor levels — is untouched by construction.
  datasets <- lapply(seq_len(m), function(i) {
    completed <- mice::complete(mice_result, action = i)
    out <- cleaned_data
    for (var in colnames(prep$where)) {
      cells <- prep$where[, var]
      if (!any(cells)) next
      imputed_vals <- completed[[var]][cells]
      # mice declines to impute variables it flags constant/collinear
      # (method set to ""), returning plain NA for their where-TRUE cells.
      # Writing those back would replace the NA(b) tag with untagged NA —
      # silent corruption of the missing-data accounting. Fail loudly instead.
      if (anyNA(imputed_vals)) {
        stop(
          "MICE left ", sum(is.na(imputed_vals)), " where-TRUE cell(s) of '",
          var, "' unimputed (see logged events above: likely constant or ",
          "collinear). These NA(b) cells would lose their tag — adjust the ",
          "imputation model before proceeding.", call. = FALSE
        )
      }
      if (is.factor(out[[var]])) {
        # Imputed values are levels of the reduced factor; assign as character
        # into the original factor (levels unchanged; "NA(b)" cells resolved)
        out[[var]][cells] <- as.character(imputed_vals)
      } else {
        out[[var]][cells] <- imputed_vals
      }
    }
    recompute_derived(out)
  })

  message("Imputation complete: ", m, " datasets.")
  list(
    datasets = datasets, m = m,
    imputed_cells = imputed_cells, logged_events = logged
  )
}

#' Recompute derived variables from imputed feeders
#'
#' Derived variables are not imputed directly (protocol Appendix D): their
#' feeders are imputed and the derived values are recomputed with the same
#' cchsflow function used at harmonization, guaranteeing internal consistency
#' by construction. Currently covers pack_years_der, the one derived variable
#' in the Table 1 set whose feeders are imputation targets.
#'
#' TODO(worksheet-driven): generalize by walking the DerivedVar chain in the
#' variable-details worksheet instead of naming feeders here.
#'
#' @param data A completed (imputed) data frame
#' @return Data frame with derived variables recomputed
recompute_derived <- function(data) {
  if (!"pack_years_der" %in% colnames(data)) return(data)

  as_num <- function(x) {
    if (is.factor(x)) suppressWarnings(as.numeric(as.character(x))) else x
  }
  feeders <- c("SMKDSTY_original", "DHHGAGE_cont", "age_start_smoking",
               "cigs_per_day", "time_quit_smoking", "SMK_05B", "SMK_05C",
               "age_first_cigarette", "smoked_100_lifetime")
  if (!all(feeders %in% colnames(data))) {
    warning("pack_years_der not recomputed — missing feeders: ",
            paste(setdiff(feeders, colnames(data)), collapse = ", "),
            call. = FALSE)
    return(data)
  }
  data$pack_years_der <- cchsflow::calculate_pack_years(
    smoking_status      = as_num(data$SMKDSTY_original),
    age                 = as_num(data$DHHGAGE_cont),
    age_start_smoking   = as_num(data$age_start_smoking),
    cigs_per_day        = as_num(data$cigs_per_day),
    time_quit_smoking   = as_num(data$time_quit_smoking),
    cigs_occasional     = as_num(data$SMK_05B),
    days_per_month      = as_num(data$SMK_05C),
    age_first_cigarette = as_num(data$age_first_cigarette),
    smoked_100_lifetime = as_num(data$smoked_100_lifetime)
  )
  data
}

#' Prepare the MICE modelling frame and where matrix
#'
#' Builds a copy of `vars` in which every tagged NA is plain NA (mice cannot
#' handle haven tags or "NA(x)" factor levels), plus a logical `where` matrix
#' marking exactly the NA(b) cells — the only cells MICE may impute.
#' Structural NA(a)/NA(c) cells are plain NA with where = FALSE: they are
#' excluded row-wise from the conditional models that use those variables,
#' which matches the question universes (e.g., never-smokers do not inform
#' the initiation-age model).
#'
#' For factors, the "NA(a)"/"NA(b)"/"NA(c)" levels are dropped from the
#' modelling frame so polytomous regression cannot assign a structural-missing
#' label as an imputed value.
#'
#' @param data Data frame
#' @param vars Character vector of variable names to include in the model
#' @return List: `data` (modelling frame), `where` (logical matrix, same dim)
prepare_for_mice <- function(data, vars) {
  out <- data[, vars, drop = FALSE]
  where <- matrix(
    FALSE, nrow = nrow(out), ncol = length(vars),
    dimnames = list(NULL, vars)
  )

  na_levels <- c("NA(a)", "NA(b)", "NA(c)")

  for (var in vars) {
    x <- out[[var]]

    if (is.factor(x)) {
      char_x <- as.character(x)
      where[, var] <- !is.na(char_x) & char_x == "NA(b)"
      char_x[char_x %in% na_levels] <- NA_character_
      out[[var]] <- factor(char_x, levels = setdiff(levels(x), na_levels))

    } else if (is.numeric(x)) {
      where[, var] <- haven::is_tagged_na(x, "b")
      # strip tags: all tagged NAs become plain NA in the modelling frame;
      # NA(a)/NA(c) cells have where = FALSE and are never imputed
      x[is.na(x)] <- NA_real_
      out[[var]] <- x
    }
  }

  list(data = out, where = where)
}
