# imputation.R
# Multiple imputation via MICE for missing smoking history variables.
# Pipeline target: analysis_data

#' Impute missing values via MICE
#'
#' Applies multiple imputation to predictor variables with random missingness
#' (NA(b) = don't know/refused). Structural missingness — NA(a) (not
#' applicable) and NA(c) (not asked this cycle) — is preserved and not imputed.
#'
#' Number of imputations and iterations are controlled by cfg$imputation_m and
#' cfg$imputation_maxit. Use m=1, maxit=1 in draft/dev for fast iteration.
#'
#' @param cleaned_data Output of clean_study_data()
#' @param variables_sheet Variables worksheet data frame
#' @param cfg Config object from config::get()
#' @return Data frame with NA(b) values imputed (first completed dataset)
impute_data <- function(cleaned_data, variables_sheet, cfg) {
  # Identify variables for the MICE predictor matrix
  # "imputation-predictor" role covers all variables that should inform imputation
  impute_vars <- select_vars_by_role("imputation-predictor", variables_sheet)
  impute_vars <- intersect(impute_vars, colnames(cleaned_data))

  # Check which variables actually have NA(b) — only those need imputation
  has_na_b <- vapply(impute_vars, function(var) {
    x <- cleaned_data[[var]]
    if (is.factor(x)) {
      "NA(b)" %in% as.character(x)
    } else {
      any(haven::is_tagged_na(x, "b"))
    }
  }, logical(1))

  vars_to_impute <- impute_vars[has_na_b]

  message(
    "Imputation: ", length(vars_to_impute),
    " variables with NA(b) missingness:\n  ",
    paste(vars_to_impute, collapse = ", ")
  )

  if (length(vars_to_impute) == 0) {
    message("No NA(b) values found — returning cleaned data unchanged.")
    return(cleaned_data)
  }

  # Prepare data for MICE: pass all impute_vars so auxiliary predictors (those
  # without NA(b)) are included in the predictor matrix, improving imputation
  # quality. Only vars_to_impute will actually have NAs for MICE to fill.
  mice_input <- prepare_for_mice(cleaned_data, impute_vars)

  # Run MICE
  message(
    "Running MICE: m=", cfg$imputation_m,
    ", maxit=", cfg$imputation_maxit
  )
  mice_result <- mice::mice(
    mice_input,
    m         = cfg$imputation_m,
    maxit     = cfg$imputation_maxit,
    printFlag = FALSE
  )

  # Complete: use first imputation dataset
  completed <- mice::complete(mice_result, action = 1)

  # Write imputed values back; all other columns are unchanged
  result <- cleaned_data
  for (var in vars_to_impute) {
    result[[var]] <- completed[[var]]
  }

  message("Imputation complete.")
  result
}

#' Prepare variables for MICE by converting NA(b) to regular NA
#'
#' Only NA(b) (random missing) is converted to regular NA for MICE to impute.
#' NA(a) (not applicable) and NA(c) (not asked this cycle) are left as-is,
#' which prevents MICE from imputing structural missingness.
#'
#' @param data Data frame
#' @param vars Character vector of variable names to pass to MICE
#' @return Data frame subset with only `vars`, NA(b) converted to regular NA
prepare_for_mice <- function(data, vars) {
  out <- data[, vars, drop = FALSE]

  for (var in vars) {
    x <- out[[var]]

    if (is.factor(x)) {
      # Replace "NA(b)" level with regular NA; keep "NA(a)" and "NA(c)" as levels
      char_x <- as.character(x)
      char_x[char_x == "NA(b)"] <- NA_character_
      out[[var]] <- factor(char_x, levels = setdiff(levels(x), "NA(b)"))

    } else if (is.numeric(x)) {
      # Replace tagged NA(b) with regular NA; tagged NA(a) and NA(c) pass through
      x[haven::is_tagged_na(x, "b")] <- NA_real_
      out[[var]] <- x
    }
  }

  out
}
