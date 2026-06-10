# create-descriptive-tables.R
# Format descriptive statistics into publication-ready gt tables.
# Ported from DemPoRT-V2-dev (origin/dev).

NA_c_label <- "Missing from survey"

categorical_predictor_footnote <- paste0(
  "For categorical variables the values are displayed as unweighted N ",
  "(survey-weighted percent where weights were supplied; otherwise unweighted percent). ",
  "Percents may not sum to 100 due to missingness."
)
continuous_predictor_footnote <- paste0(
  "For continuous predictors, the values are displayed as min - max, median (IQR); ",
  "median and IQR are survey-weighted where weights were supplied."
)

# ---- Formatting helpers -----------------------------------------------------
# When the descriptive data carry weighted columns (weight_var supplied to the
# engine), cells show unweighted n with weighted percent / weighted median (IQR)
# per protocol v0.3.0 §3.4.1. Without weights they fall back to unweighted stats.

format_cat_descriptive_data <- function(descriptive_data_row) {
  if (is.na(descriptive_data_row[1, "n"]) || descriptive_data_row[1, "n"] == 0) {
    return("No data")
  }
  pct <- if ("wtd_percent" %in% colnames(descriptive_data_row) &&
             !is.na(descriptive_data_row[1, "wtd_percent"])) {
    descriptive_data_row[1, "wtd_percent"]
  } else {
    descriptive_data_row[1, "percent"]
  }
  formatted_n <- format(descriptive_data_row[1, "n"], big.mark = ",")
  paste0(formatted_n, "\n (", round(pct * 100, 1), ")")
}

format_cont_descriptive_data <- function(descriptive_data_row) {
  if (is.na(descriptive_data_row[1, "n"]) || descriptive_data_row[1, "n"] == 0) {
    return("No data")
  }
  weighted <- "wtd_median" %in% colnames(descriptive_data_row) &&
    !is.na(descriptive_data_row[1, "wtd_median"])
  med <- if (weighted) descriptive_data_row[1, "wtd_median"]
         else descriptive_data_row[1, "median"]
  p25 <- if (weighted) descriptive_data_row[1, "wtd_percentile25"]
         else descriptive_data_row[1, "percentile25"]
  p75 <- if (weighted) descriptive_data_row[1, "wtd_percentile75"]
         else descriptive_data_row[1, "percentile75"]
  paste0(
    descriptive_data_row[1, "min"], " - ", descriptive_data_row[1, "max"], ",\n",
    med, " (", p25, " - ", p75, ")"
  )
}

.format_cont_type <- function(variables_sheet_row) {
  stopifnot(is_continuous_variable(variables_sheet_row))
  units        <- variables_sheet_row$units
  units_suffix <- ifelse(units != "N/A", paste0("(in ", units, ")"), "")
  paste(variables_sheet_row$variableType, units_suffix)
}

# ---- Row builders -----------------------------------------------------------

create_descriptive_table_row <- function(
  variable, type, stratifier_details_rows, get_stratifier_value
) {
  stratifier_cols <- purrr::map(
    seq_len(nrow(stratifier_details_rows)),
    function(i) {
      row <- stratifier_details_rows[i, ]
      data.frame(setNames(
        list(get_stratifier_value(row)),
        row$catLabel
      ))
    }
  ) |> purrr::list_cbind()
  cbind(data.frame(variable = variable, type = type), stratifier_cols)
}

create_descriptive_table_missing_rows <- function(
  variable, variable_details_sheet, stratifier_rows, data_for_variable
) {
  missing_cats <- get_unique_rec_end_rows(
    variable_details_sheet, variable, TRUE
  ) |> dplyr::filter(recEnd %in% c("NA::a", "NA::b"))

  missing_rows <- purrr::map(
    seq_len(nrow(missing_cats)),
    function(i) {
      mc <- missing_cats[i, ]
      create_descriptive_table_row(
        mc$catLabel, "", stratifier_rows,
        function(sr) {
          d <- data_for_variable |>
            dplyr::filter(
              groupBy_1 == sr$variable &
              groupByValue_1 == sr$recEnd &
              cat == mc$recEnd
            )
          format_cat_descriptive_data(d[1, ])
        }
      )
    }
  ) |> purrr::list_rbind()

  na_c_row <- create_descriptive_table_row(
    NA_c_label, "", stratifier_rows,
    function(sr) {
      d <- data_for_variable |>
        dplyr::filter(
          groupBy_1 == sr$variable &
          groupByValue_1 == sr$recEnd &
          cat == "NA::c"
        )
      format_cat_descriptive_data(d[1, ])
    }
  )
  rbind(missing_rows, na_c_row)
}

# ---- Core table builder -----------------------------------------------------

.build_descriptive_table_data <- function(
  descriptive_data,
  variables_sheet,
  variable_details_sheet,
  variables,
  column_stratifier = NULL,
  row_stratifiers   = list(),
  sections_order    = NULL,
  include_na        = TRUE
) {
  stratify_config <- row_stratifiers
  if (!is.null(column_stratifier)) {
    stratify_config[["all"]] <- c(column_stratifier)
  }

  unrounded <- descriptive_data
  formatted  <- descriptive_data |>
    dplyr::mutate(dplyr::across(where(is.numeric) & !c(n), ~ signif(.x, 4)))

  # Determine sections
  sections_in_table <- c()
  for (v in variables) {
    s <- variables_sheet[variables_sheet$variable == v, ]$section[1]
    if (!s %in% sections_in_table) sections_in_table <- c(sections_in_table, s)
  }
  if (!is.null(sections_order)) sections_in_table <- sections_order

  stratifier_rows  <- get_unique_rec_end_rows(variable_details_sheet, column_stratifier)
  table_variables  <- c()
  table_type       <- c()
  table_row_types  <- c()
  stratify_by_stats <- list()
  for (i in seq_len(nrow(stratifier_rows))) {
    stratify_by_stats[[stratifier_rows[i, "catLabel"]]] <- c()
  }

  merge_stats <- function(stats) {
    table_variables <<- c(table_variables, stats$variable)
    table_type      <<- c(table_type,      stats$type)
    for (i in seq_len(nrow(stratifier_rows))) {
      cat_label <- stratifier_rows[i, "catLabel"]
      stratify_by_stats[[cat_label]] <<- c(
        stratify_by_stats[[cat_label]], stats[[cat_label]]
      )
    }
  }

  for (section in sections_in_table) {
    table_variables <- c(table_variables, section)
    table_type      <- c(table_type, "")
    table_row_types <- c(table_row_types, "section")
    for (i in seq_len(nrow(stratifier_rows))) {
      cat_label <- stratifier_rows[i, "catLabel"]
      stratify_by_stats[[cat_label]] <- c(stratify_by_stats[[cat_label]], "")
    }

    for (variable in variables) {
      vrow <- get_row_for_variable(variable, variables_sheet)
      if (vrow[1, ]$section != section) next
      if (!is.null(row_stratifiers[[variable]])) next

      data_for_var <- formatted[formatted$variable == variable, ]

      if (vrow[1, ]$variableType == "Categorical") {
        table_variables <- c(table_variables, vrow[1, "label"])
        table_type      <- c(table_type, "Categorical")
        table_row_types <- c(table_row_types, "variable")
        for (i in seq_len(nrow(stratifier_rows))) {
          stratify_by_stats[[stratifier_rows[i, "catLabel"]]] <- c(
            stratify_by_stats[[stratifier_rows[i, "catLabel"]]], ""
          )
        }

        categories <- get_unique_rec_end_rows(
          variable_details_sheet, variable, include_na
        )
        # Append NA(c) row
        na_row <- categories[1, , drop = FALSE]
        for (col in colnames(na_row)) {
          if (is.character(na_row[[col]])) na_row[[col]][1] <- ""
          else na_row[[col]][1] <- NA
        }
        na_row$variable[1] <- variable
        na_row$recEnd[1]   <- "NA::c"
        na_row$catLabel[1] <- NA_c_label
        na_row$typeEnd[1]  <- "cat"
        na_row$units[1]    <- "N/A"
        categories <- rbind(categories, na_row)

        for (ci in seq_len(nrow(categories))) {
          table_variables <- c(table_variables, categories[ci, "catLabel"])
          table_type      <- c(table_type, "")
          table_row_types <- c(table_row_types, "category")
          for (i in seq_len(nrow(stratifier_rows))) {
            sr <- stratifier_rows[i, ]
            d  <- data_for_var[
              data_for_var$cat == categories[ci, ]$recEnd &
              data_for_var$groupBy_1 == column_stratifier &
              data_for_var$groupByValue_1 == sr$recEnd, ]
            stratify_by_stats[[sr$catLabel]] <- c(
              stratify_by_stats[[sr$catLabel]],
              format_cat_descriptive_data(d)
            )
          }
        }
      } else {
        # Continuous
        first_row <- create_descriptive_table_row(
          vrow[1, ]$label, .format_cont_type(vrow), stratifier_rows,
          function(sr) {
            ixs <- which(
              is.na(data_for_var$cat) &
              data_for_var$groupBy_1 == column_stratifier &
              data_for_var$groupByValue_1 == sr$recEnd
            )
            if (length(ixs) != 1) stop(paste(
              "Expected 1 continuous row for", variable,
              "stratifier", sr$recEnd, "- found", length(ixs)
            ))
            format_cont_descriptive_data(data_for_var[ixs, ])
          }
        )
        merge_stats(first_row)
        table_row_types <- c(table_row_types, "variable")

        missing_rows <- create_descriptive_table_missing_rows(
          variable, variable_details_sheet, stratifier_rows, data_for_var
        )
        for (i in seq_len(nrow(missing_rows))) {
          merge_stats(missing_rows[i, ])
          table_row_types <- c(table_row_types, "category")
        }
      }
    }
  }

  descriptive_table <- data.frame(
    variable = table_variables,
    type     = table_type,
    row_type = table_row_types
  )
  for (i in seq_len(nrow(stratifier_rows))) {
    cat_label <- stratifier_rows[i, "catLabel"]
    descriptive_table[[cat_label]] <- stratify_by_stats[[cat_label]]
  }

  attr(descriptive_table, "unrounded_data") <- unrounded
  attr(descriptive_table, "stratifier_rows") <- stratifier_rows
  attr(descriptive_table, "column_stratifier") <- column_stratifier

  descriptive_table
}

# ---- gt display -------------------------------------------------------------

create_descriptive_table_display <- function(descriptive_table_data) {
  descriptive_table_data$section_group <- NA_character_
  current_section <- NA_character_
  for (i in seq_len(nrow(descriptive_table_data))) {
    if (descriptive_table_data$row_type[i] == "section") {
      current_section <- descriptive_table_data$variable[i]
    }
    descriptive_table_data$section_group[i] <- current_section
  }

  data_filtered <- descriptive_table_data[
    descriptive_table_data$row_type != "section", ]

  gt_table <- data_filtered |>
    dplyr::select(-row_type) |>
    gt::gt(rowname_col = "variable", groupname_col = "section_group") |>
    gt::tab_style(
      style = gt::cell_text(weight = "bold"),
      locations = gt::cells_row_groups()
    ) |>
    gt::tab_options(table.font.size = gt::px(10)) |>
    gt::opt_table_lines(extent = "default")

  if (any(data_filtered$row_type == "variable")) {
    variable_labels <- data_filtered$variable[data_filtered$row_type == "variable"]
    gt_table <- gt_table |>
      gt::tab_style(
        style = list(
          gt::cell_text(weight = "bold"),
          gt::cell_text(indent = gt::px(10))
        ),
        locations = gt::cells_stub(rows = variable_labels)
      )
  }
  if (any(data_filtered$row_type == "category")) {
    cat_labels <- data_filtered$variable[data_filtered$row_type == "category"]
    gt_table <- gt_table |>
      gt::tab_style(
        style = gt::cell_text(indent = gt::px(20)),
        locations = gt::cells_stub(rows = cat_labels)
      )
  }

  gt_table
}

# ---- Public functions -------------------------------------------------------

#' Create sex-stratified (+ Overall) descriptive table
#'
#' @param descriptive_data Output of get_descriptive_data()
#' @param variables_sheet Variables worksheet data frame
#' @param variable_details_sheet Variable details worksheet data frame
#' @param variables Character vector of variables to include
#' @param column_stratifier Variable name for column stratification (from config)
#' @param sections_order Optional character vector to order sections
#' @param include_na Whether to show missing categories
#' @return A gt table object
create_descriptive_table <- function(
  descriptive_data,
  variables_sheet,
  variable_details_sheet,
  variables,
  column_stratifier = NULL,
  sections_order    = NULL,
  include_na        = TRUE
) {
  descriptive_table <- .build_descriptive_table_data(
    descriptive_data, variables_sheet, variable_details_sheet,
    variables, column_stratifier, list(), sections_order, include_na
  )

  unrounded      <- attr(descriptive_table, "unrounded_data")
  stratifier_rows <- attr(descriptive_table, "stratifier_rows")

  header_labels <- list(variable = "Variable", type = "Type")
  for (i in seq_len(nrow(stratifier_rows))) {
    d <- unrounded[
      !is.na(unrounded$groupBy_1) &
      unrounded$groupBy_1 == column_stratifier &
      !is.na(unrounded$groupByValue_1) &
      unrounded$groupByValue_1 == stratifier_rows[i, "recEnd"], ]
    valid <- d[!is.na(d$percent) & d$percent > 0, ]
    total_n <- if (nrow(valid) > 0 && valid[1, "percent"] > 0) {
      round(valid[1, "n"] / valid[1, "percent"])
    } else {
      sum(d$n, na.rm = TRUE)
    }
    header_labels[[stratifier_rows[i, "catLabel"]]] <- gt::html(paste0(
      stratifier_rows[i, "catLabel"],
      " (N = ", format(total_n, big.mark = ","), ")<sup>a</sup>"
    ))
  }

  create_descriptive_table_display(descriptive_table) |>
    gt::cols_label(.list = header_labels) |>
    gt::tab_style(
      style = gt::cell_text(weight = "bold"),
      locations = gt::cells_column_labels()
    ) |>
    gt::tab_header(title = "Sex-stratified population characteristics") |>
    gt::cols_width(type ~ gt::px(144)) |>
    gt::tab_footnote(footnote = gt::html(paste0(
      "<sup>a</sup> ", categorical_predictor_footnote, " ",
      continuous_predictor_footnote
    ))) |>
    gt::tab_footnote(
      footnote = "Abbreviations: IQR, interquartile range; N, number"
    )
}

#' Create cycle-stratified appendix table (sex within each cycle)
#'
#' @param study_data Study data frame
#' @param variables_sheet Variables worksheet data frame
#' @param variable_details_sheet Variable details worksheet data frame
#' @param variables Character vector of variables to include
#' @param cycle_col Name of the survey cycle column (from config)
#' @param cycle_labels Named vector mapping integer cycle codes to display labels
#' @param column_stratifier Variable for column stratification (from config)
#' @param sections_order Optional character vector to order sections
#' @param include_na Whether to show missing categories
#' @return A gt table object
create_cycle_specific_descriptive_table <- function(
  study_data,
  variables_sheet,
  variable_details_sheet,
  variables,
  cycle_col,
  cycle_labels,
  column_stratifier = NULL,
  sections_order    = NULL,
  include_na        = TRUE
) {
  cycles <- sort(unique(as.integer(as.character(study_data[[cycle_col]]))))
  cycles <- cycles[!is.na(cycles)]
  if (length(cycles) == 0) stop("No valid cycle values found in study_data[[\"", cycle_col, "\"]]")

  stratify_config <- list()
  if (!is.null(column_stratifier)) {
    stratify_config[["all"]] <- list(column_stratifier)
  }

  cycle_tables    <- list()
  cycle_data_list <- list()

  for (cycle in cycles) {
    cycle_data <- study_data[
      as.integer(as.character(study_data[[cycle_col]])) == cycle, ]
    key <- paste0("Cycle_", cycle)
    cycle_data_list[[key]] <- cycle_data

    cycle_desc <- get_descriptive_data(
      cycle_data, variables_sheet, variable_details_sheet,
      variables, stratify_config
    )
    cycle_tables[[key]] <- .build_descriptive_table_data(
      cycle_desc, variables_sheet, variable_details_sheet,
      variables, column_stratifier, list(), sections_order, include_na
    )
  }

  # Combine tables side by side
  combined <- data.frame(
    variable = cycle_tables[[1]]$variable,
    type     = cycle_tables[[1]]$type,
    row_type = cycle_tables[[1]]$row_type
  )
  for (cycle in cycles) {
    key    <- paste0("Cycle_", cycle)
    ct     <- cycle_tables[[key]]
    # Use the catLabel column names from the first cycle's stratifier_rows
    strat_rows <- attr(ct, "stratifier_rows")
    for (i in seq_len(nrow(strat_rows))) {
      cat_label <- strat_rows[i, "catLabel"]
      combined[[paste0("Cycle", cycle, "_", cat_label)]] <- ct[[cat_label]]
    }
  }

  strat_rows_ref <- attr(cycle_tables[[1]], "stratifier_rows")
  cat_labels_ref <- strat_rows_ref$catLabel

  gt_table <- create_descriptive_table_display(combined)

  col_labels <- list(type = "Type")
  for (cycle in cycles) {
    key        <- paste0("Cycle_", cycle)
    cycle_data <- cycle_data_list[[key]]
    cycle_lbl  <- cycle_labels[as.character(cycle)]

    span_cols <- c()
    for (cat_label in cat_labels_ref) {
      col_name  <- paste0("Cycle", cycle, "_", cat_label)
      strat_val <- strat_rows_ref$recEnd[strat_rows_ref$catLabel == cat_label]
      n_val     <- nrow(cycle_data[
        !is.na(cycle_data[[column_stratifier]]) &
        cycle_data[[column_stratifier]] == strat_val, ])
      col_labels[[col_name]] <- gt::html(paste0(
        cat_label, " (N = ", format(n_val, big.mark = ","), ")<sup>a</sup>"
      ))
      span_cols <- c(span_cols, col_name)
    }

    gt_table <- gt_table |>
      gt::tab_spanner(label = cycle_lbl, columns = dplyr::all_of(span_cols))
  }

  gt_table |>
    gt::cols_label(.list = col_labels) |>
    gt::tab_style(
      style = gt::cell_text(weight = "bold"),
      locations = gt::cells_column_labels()
    ) |>
    gt::tab_header(
      title = "Sex and cycle-stratified population characteristics"
    ) |>
    gt::cols_width(type ~ gt::px(108)) |>
    gt::tab_footnote(footnote = gt::html(paste0(
      "<sup>a</sup> ", categorical_predictor_footnote, " ",
      continuous_predictor_footnote
    ))) |>
    gt::tab_footnote(
      footnote = "Abbreviations: IQR, interquartile range; N, number"
    )
}
