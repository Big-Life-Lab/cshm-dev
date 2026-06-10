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

  mice_result <- mice::mice(
    prep$data,
    m         = m,
    maxit     = maxit,
    where     = prep$where,
    printFlag = FALSE
  )

  # Surface silently dropped/altered variables (constant, collinear, etc.)
  logged <- mice_result$loggedEvents
  if (!is.null(logged) && nrow(logged) > 0) {
    warning(
      "MICE logged events (variables dropped or altered in the imputation model):\n",
      paste(capture.output(print(logged)), collapse = "\n"),
      call. = FALSE
    )
  }

  # Convergence check: mice() does not error on pathological chains, so a
  # quick guard on non-finite chain means catches degenerate fits.
  if (any(!is.finite(mice_result$chainMean), na.rm = FALSE) &&
      any(is.nan(mice_result$chainMean))) {
    warning("Non-finite MICE chain means detected — inspect convergence ",
            "(mice::plot) before using these imputations.", call. = FALSE)
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
    out
  })

  message("Imputation complete: ", m, " datasets.")
  list(
    datasets = datasets, m = m,
    imputed_cells = imputed_cells, logged_events = logged
  )
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
