# descriptive-data.R
# CSHM-specific wrapper for calculating descriptive statistics.
# Pipeline targets: table_1a_data, table_1b_data

#' Calculate descriptive statistics for the CSHM study population
#'
#' Computes statistics for all predictor variables stratified by model-stratifier.
#' No row stratification is applied in the base table.
#'
#' @param data Cleaned or imputed study data frame
#' @param variables_sheet Variables worksheet data frame
#' @param variable_details_sheet Variable details worksheet data frame
#' @return Data frame of descriptive statistics (input to create_descriptive_table)
get_cshm_desc_data <- function(data, variables_sheet, variable_details_sheet) {
  predictor_vars <- select_vars_by_role("predictor", variables_sheet)
  sex_stratifier <- select_vars_by_role("model-stratifier", variables_sheet)[1]

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
    stratify_config         = stratify_config
  )
}
