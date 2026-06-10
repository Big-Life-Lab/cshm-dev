# variables-sheet-utils.R
# Utility functions for working with the variables worksheet.
# Ported from DemPoRT-V2-dev (origin/dev).

get_row_for_variable <- function(variable, variables_sheet) {
  variables_sheet[variables_sheet$variable == variable, ]
}

is_continuous_variable <- function(variables_sheet_row) {
  variables_sheet_row[1, "variableType"] == "Continuous"
}

is_categorical_variable <- function(variables_sheet_row) {
  variables_sheet_row[1, "variableType"] == "Categorical"
}

is_value_na <- function(value) {
  value == "N/A"
}

#' Return variable names with a given role
#'
#' Roles are comma-separated in the worksheet, so a variable can carry
#' multiple roles (e.g. "predictor, table1, apc-numerator").
#' This function matches any variable whose role field contains `role`.
#'
#' @param role Character role value (e.g. "predictor", "table1", "apc-numerator")
#' @param variables_sheet Variables worksheet data frame
#' @return Character vector of matching variable names
select_vars_by_role <- function(role, variables_sheet) {
  has_role <- !is.na(variables_sheet$role) & vapply(
    strsplit(variables_sheet$role, ","),
    function(parts) role %in% trimws(parts),
    logical(1)
  )
  variables_sheet$variable[has_role]
}
