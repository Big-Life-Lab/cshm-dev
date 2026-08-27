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


#' Valid range of a variable for one database, from the variable-details rules
#'
#' The variable-details worksheet is the reference for minimum and maximum
#' values; config.yml points at it (`range: variable_details`) rather than
#' holding copies. The range is read from the recoding rules for `database`:
#' a `copy` rule with `recStart` of the form `[lo, hi]` contributes lo and hi;
#' a category-to-value rule contributes its numeric `recEnd` (the midpoint);
#' a derived variable (`DerivedVar::[...]` / `Func::`) takes the union of its
#' feeders' ranges. `NA::` and `else` rules are ignored. Ranges differ by
#' database because top-codes and category boundaries differ by cycle.
#'
#' @param variable Variable name in the details sheet
#' @param database Database name, e.g. "cchs2013_2014_p"
#' @param variable_details_sheet Combined variable-details data frame
#' @return Named numeric vector c(min, max); NA when the rules give no bound
details_range <- function(variable, database, variable_details_sheet, .seen = character()) {
  none <- c(min = NA_real_, max = NA_real_)
  rows <- variable_details_sheet[variable_details_sheet$variable == variable, , drop = FALSE]
  if (nrow(rows) == 0) {
    return(none)
  }
  in_db <- vapply(strsplit(as.character(rows$databaseStart), ","), function(x) database %in% trimws(x), logical(1))
  rows <- rows[in_db, , drop = FALSE]
  if (nrow(rows) == 0) {
    return(none)
  }
  vals <- numeric(0)
  for (i in seq_len(nrow(rows))) {
    rec_end <- trimws(as.character(rows$recEnd[i]))
    rec_start <- trimws(as.character(rows$recStart[i]))
    var_start <- as.character(rows$variableStart[i])
    if (grepl("^Func::", rec_end) || grepl("DerivedVar::", var_start)) {
      inner <- sub(".*DerivedVar::\\[([^]]*)\\].*", "\\1", var_start)
      feeders <- setdiff(trimws(strsplit(inner, ",")[[1]]), c(.seen, variable))
      for (f in feeders) {
        r <- details_range(f, database, variable_details_sheet, c(.seen, variable))
        vals <- c(vals, r)
      }
    } else if (rec_end == "copy") {
      m <- regmatches(rec_start, regexec("^\\[\\s*(-?[0-9.]+)\\s*,\\s*(-?[0-9.]+)\\s*\\]$", rec_start))[[1]]
      if (length(m) == 3) vals <- c(vals, as.numeric(m[2:3]))
    } else {
      num <- suppressWarnings(as.numeric(rec_end))
      if (!is.na(num)) vals <- c(vals, num)
    }
  }
  vals <- vals[is.finite(vals)]
  if (length(vals) == 0) {
    return(none)
  }
  c(min = min(vals), max = max(vals))
}
