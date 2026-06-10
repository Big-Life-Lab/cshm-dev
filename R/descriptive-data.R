# descriptive-data.R
# CSHM-specific wrapper for calculating descriptive statistics.
# Pipeline targets: table_1a_data, table_1b_data
#
# Presentation per protocol v0.3.0 §3.4.1: single table with unweighted n and
# survey-weighted statistics (weighted % for categories and NA-type rows;
# weighted median/IQR for continuous). Table 1b averages across the m
# completed imputation datasets.

#' Calculate descriptive statistics for the CSHM study population
#'
#' Computes statistics for all table1-role variables stratified by
#' model-stratifier. No row stratification is applied in the base table.
#'
#' @param data Cleaned or imputed study data frame
#' @param variables_sheet Variables worksheet data frame
#' @param variable_details_sheet Variable details worksheet data frame
#' @param weight_var Survey weight column name (e.g. "WTS_M"). NULL = unweighted.
#' @return Data frame of descriptive statistics (input to create_descriptive_table)
get_cshm_desc_data <- function(data, variables_sheet, variable_details_sheet,
                               weight_var = NULL) {
  # Table rows are selected by the table1 role (the documented wiring);
  # columns are stratified by model-stratifier (sex). The cycle-specific
  # appendix table is wired from config (survey_var cycle/sex), not roles.
  predictor_vars <- select_vars_by_role("table1", variables_sheet)
  sex_stratifier <- select_vars_by_role("model-stratifier", variables_sheet)[1]
  stopifnot(!is.na(sex_stratifier))

  # Only describe variables that were actually harmonized into data
  # (some variables in the sheet may be absent if no variable_details rows matched)
  available <- intersect(predictor_vars, colnames(data))
  absent    <- setdiff(predictor_vars, colnames(data))
  if (length(absent) > 0) {
    message("Descriptive table: skipping ", length(absent),
            " variables not in data: ", paste(absent, collapse = ", "))
  }

  stratify_config <- list()
  stratify_config[["all"]] <- list(sex_stratifier)

  get_descriptive_data(
    data                    = data,
    variables_sheet         = variables_sheet,
    variables_details_sheet = variable_details_sheet,
    variables               = available,
    stratify_config         = stratify_config,
    weight_var              = weight_var
  )
}

#' Descriptive statistics averaged across multiple imputations (Table 1b)
#'
#' Computes the descriptive statistics within each completed dataset and
#' averages the estimates across imputations (means for central statistics
#' and proportions; min of minima, max of maxima). With m = 1 this reduces
#' to a single get_cshm_desc_data() call.
#'
#' @param imputation_result Output of impute_data() (list with $datasets)
#' @param variables_sheet Variables worksheet data frame
#' @param variable_details_sheet Variable details worksheet data frame
#' @param weight_var Survey weight column name. NULL = unweighted.
#' @return Data frame of descriptive statistics, averaged across imputations
get_cshm_desc_data_mi <- function(imputation_result, variables_sheet,
                                  variable_details_sheet, weight_var = NULL) {
  datasets <- imputation_result$datasets
  stopifnot(length(datasets) >= 1)

  per_imp <- lapply(datasets, function(d) {
    get_cshm_desc_data(d, variables_sheet, variable_details_sheet, weight_var)
  })
  if (length(per_imp) == 1) return(per_imp[[1]])

  stacked <- dplyr::bind_rows(per_imp, .id = ".imp")
  # All imputations must produce identical row sets (worksheet-driven rows;
  # factor levels preserved by the write-back) — averaging mismatched groups
  # would be silent corruption.
  stopifnot(nrow(stacked) == nrow(per_imp[[1]]) * length(per_imp))

  mean_cols <- intersect(
    c("median", "percentile25", "percentile75", "n", "percent",
      "wtd_percentile25", "wtd_median", "wtd_percentile75", "wtd_percent"),
    colnames(stacked)
  )
  key_cols <- setdiff(colnames(stacked), c(".imp", mean_cols, "min", "max"))

  stacked |>
    dplyr::group_by(dplyr::across(dplyr::all_of(key_cols))) |>
    dplyr::summarise(
      dplyr::across(dplyr::all_of(mean_cols), ~ mean(.x, na.rm = FALSE)),
      min = if (all(is.na(min))) NA else min(min, na.rm = TRUE),
      max = if (all(is.na(max))) NA else max(max, na.rm = TRUE),
      .groups = "drop"
    ) |>
    as.data.frame()
}
