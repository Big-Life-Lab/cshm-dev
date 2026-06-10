# variable-details-sheet-utils.R
# Utility functions for working with the variable_details worksheet.
# Ported from DemPoRT-V2-dev (origin/dev).

#' Return unique recEnd rows for a variable
#'
#' @param variable_details_sheet Variable details worksheet data frame
#' @param for_variable Variable name to look up
#' @param include_NA Whether to include NA:: rows (default FALSE)
#' @return Data frame of unique recEnd rows
get_unique_rec_end_rows <- function(
  variable_details_sheet,
  for_variable,
  include_NA = FALSE
) {
  all_unique <- variable_details_sheet |>
    dplyr::filter(variable == for_variable) |>
    dplyr::distinct(recEnd, .keep_all = TRUE) |>
    dplyr::filter(!grepl("Func::", recEnd))

  if (include_NA) {
    return(all_unique)
  }

  all_unique |>
    dplyr::filter(recEnd != "NA::a" & recEnd != "NA::b")
}

is_categorical <- function(variable, variable_details_sheet) {
  "cat" %in% variable_details_sheet[
    variable_details_sheet$variable == variable, "typeEnd"
  ]
}

get_variable_type <- function(variable, variable_details_sheet) {
  get_variable_rows(variable, variable_details_sheet)[1, "typeEnd"]
}

get_variable_rows <- function(variable, variable_details_sheet) {
  variable_details_sheet[variable_details_sheet$variable == variable, ]
}
