# get-descriptive-data.R
# Calculate descriptive statistics for the study population.
# Ported from DemPoRT-V2-dev (origin/dev); extended with survey-weighted
# statistics (weight_var) per protocol v0.3.0 §3.4.1 / Appendix D.

#' Weighted quantile (midpoint-ECDF with linear interpolation)
#'
#' Interpolates linearly between order statistics positioned at the midpoints
#' of their cumulative weight intervals (the standard weighted analogue of a
#' continuous sample quantile). With equal weights the weighted median equals
#' the type-7 sample median; other quantiles are close but not identical to
#' type 7. Values beyond the first/last midpoint take the boundary value.
#'
#' @param x Numeric vector (NAs removed by caller)
#' @param w Numeric weights aligned with x
#' @param probs Probabilities in [0, 1]
#' @return Numeric vector of weighted quantiles
weighted_quantile <- function(x, w, probs) {
  if (length(x) == 0) return(rep(NA_real_, length(probs)))
  if (length(x) == 1) return(rep(x, length(probs)))
  ord <- order(x)
  x <- x[ord]; w <- w[ord]
  cw <- cumsum(w)
  midpoints <- (cw - w / 2) / sum(w)
  stats::approx(midpoints, x, xout = probs, rule = 2, ties = "ordered")$y
}

get_descriptive_data <- function(
  data,
  variables_sheet,
  variables_details_sheet,
  variables,
  stratify_config,
  weight_var = NULL
) {
  use_weights <- !is.null(weight_var)
  if (use_weights && !weight_var %in% colnames(data)) {
    stop("weight_var '", weight_var, "' not found in data.")
  }
  descriptive_data <- data.frame(
    variable   = c(),
    cat        = c(),
    median     = c(),
    percentile25 = c(),
    percentile75 = c(),
    min        = c(),
    max        = c(),
    n          = c(),
    percent    = c()
  )

  largest_num_stratifiers <- 0
  for (variable in names(stratify_config)) {
    for (stratify_config_for_variable_index in seq_len(length(stratify_config[[variable]]))) {
      current_num_stratifiers <- length(
        stratify_config[[variable]][[stratify_config_for_variable_index]]
      )
      if (!is.null(stratify_config[["all"]])) {
        current_num_stratifiers <- current_num_stratifiers +
          length(stratify_config[["all"]])
      }
      if (largest_num_stratifiers < current_num_stratifiers) {
        largest_num_stratifiers <- current_num_stratifiers
      }
    }
  }

  for (variable in variables) {
    variable_sheet_row <- variables_sheet[variables_sheet$variable == variable, ]

    if (is_continuous_variable(variable_sheet_row)) {
      map_stratifier_data(
        data, variables_sheet, variables_details_sheet, variable, stratify_config,
        function(current_stratifier_info) {
          new_row <- data.frame(
            variable = variable, cat = NA,
            median = NA, percentile25 = NA, percentile75 = NA,
            min = NA, max = NA, n = NA, percent = NA
          )
          for (si in seq_len(largest_num_stratifiers)) {
            new_row[[paste0("groupBy_",    si)]] <- NA
            new_row[[paste0("groupByValue_", si)]] <- NA
          }
          for (si in seq_len(length(current_stratifier_info$stratifiers))) {
            strat <- current_stratifier_info$stratifiers[[si]]
            new_row[[paste0("groupBy_",    si)]] <- strat
            new_row[[paste0("groupByValue_", si)]] <-
              current_stratifier_info$stratifier_combination[[strat]][1]
          }
          vals <- current_stratifier_info$data[[variable]]
          keep <- !is.na(vals)
          vals <- vals[keep]
          s    <- summary(vals)
          new_row$median       <- s[[3]]
          new_row$percentile25 <- s[[2]]
          new_row$percentile75 <- s[[5]]
          new_row$min          <- s[[1]]
          new_row$max          <- s[[6]]
          new_row$n            <- length(vals)
          if (use_weights) {
            w <- current_stratifier_info$data[[weight_var]][keep]
            wq <- weighted_quantile(vals, w, c(0.25, 0.5, 0.75))
            new_row$wtd_percentile25 <- wq[1]
            new_row$wtd_median       <- wq[2]
            new_row$wtd_percentile75 <- wq[3]
            new_row$wtd_percent      <- NA_real_
          }
          descriptive_data <<- rbind(descriptive_data, new_row)
        }
      )
    }

    for (na_type in c("NA::a", "NA::b", "NA::c")) {
      tagged_na_type <- switch(na_type, "NA::a" = "a", "NA::b" = "b", "NA::c" = "c")
      map_stratifier_data(
        data, variables_sheet, variables_details_sheet, variable, stratify_config,
        function(current_stratifier_info) {
          new_row <- data.frame(
            variable = variable, cat = na_type,
            median = NA, percentile25 = NA, percentile75 = NA, min = NA, max = NA
          )
          for (si in seq_len(largest_num_stratifiers)) {
            new_row[[paste0("groupBy_",    si)]] <- NA
            new_row[[paste0("groupByValue_", si)]] <- NA
          }
          for (si in seq_len(length(current_stratifier_info$stratifiers))) {
            strat <- current_stratifier_info$stratifiers[[si]]
            new_row[[paste0("groupBy_",    si)]] <- strat
            new_row[[paste0("groupByValue_", si)]] <-
              current_stratifier_info$stratifier_combination[[strat]][1]
          }
          filtered <- dplyr::filter(
            current_stratifier_info$data,
            haven::is_tagged_na(.data[[variable]], tagged_na_type) |
              .data[[variable]] == paste0("NA(", tagged_na_type, ")")
          )
          new_row$n       <- nrow(filtered)
          new_row$percent <- new_row$n / nrow(current_stratifier_info$data)
          if (use_weights) {
            new_row$wtd_percentile25 <- NA_real_
            new_row$wtd_median       <- NA_real_
            new_row$wtd_percentile75 <- NA_real_
            new_row$wtd_percent <- sum(filtered[[weight_var]], na.rm = TRUE) /
              sum(current_stratifier_info$data[[weight_var]], na.rm = TRUE)
          }
          descriptive_data <<- rbind(descriptive_data, new_row)
        }
      )
    }

    if (is_categorical_variable(variable_sheet_row)) {
      variable_detail_rows <- get_unique_rec_end_rows(
        variables_details_sheet, variable, FALSE
      )
      for (vdi in seq_len(nrow(variable_detail_rows))) {
        current_rec_end <- variable_detail_rows[vdi, "recEnd"]
        map_stratifier_data(
          data, variables_sheet, variables_details_sheet, variable, stratify_config,
          function(current_stratifier_info) {
            new_row <- data.frame(
              variable = variable,
              median = NA, percentile25 = NA, percentile75 = NA,
              min = NA, max = NA,
              cat = variable_detail_rows[vdi, "recEnd"]
            )
            for (si in seq_len(largest_num_stratifiers)) {
              new_row[[paste0("groupBy_",    si)]] <- NA
              new_row[[paste0("groupByValue_", si)]] <- NA
            }
            for (si in seq_len(length(current_stratifier_info$stratifiers))) {
              strat <- current_stratifier_info$stratifiers[[si]]
              new_row[[paste0("groupBy_",    si)]] <- strat
              new_row[[paste0("groupByValue_", si)]] <-
                current_stratifier_info$stratifier_combination[[strat]][1]
            }
            filtered <- dplyr::filter(
              current_stratifier_info$data,
              .data[[variable]] == current_rec_end
            )
            new_row$n       <- nrow(filtered)
            new_row$percent <- new_row$n / nrow(current_stratifier_info$data)
            if (use_weights) {
              new_row$wtd_percentile25 <- NA_real_
              new_row$wtd_median       <- NA_real_
              new_row$wtd_percentile75 <- NA_real_
              new_row$wtd_percent <- sum(filtered[[weight_var]], na.rm = TRUE) /
                sum(current_stratifier_info$data[[weight_var]], na.rm = TRUE)
            }
            descriptive_data <<- rbind(descriptive_data, new_row)
          }
        )
      }
    }
  }

  return(descriptive_data)
}

map_stratifier_data <- function(
  data, variables_sheet, variables_details_sheet,
  variable, stratify_config, iterator
) {
  stratifier_config_for_variable <- NA
  if (!is.null(stratify_config[[variable]])) {
    stratifier_config_for_variable <- stratify_config[[variable]]
  }
  if (!is.null(stratify_config[["all"]])) {
    if (length(stratifier_config_for_variable) == 1 &&
        is.na(stratifier_config_for_variable)) {
      stratifier_config_for_variable <- list(stratify_config[["all"]])
    } else {
      for (si in seq_len(length(stratifier_config_for_variable))) {
        stratifier_config_for_variable[[si]] <- append(
          stratifier_config_for_variable[[si]],
          stratify_config[["all"]], 0
        )
      }
    }
  }

  if (length(stratifier_config_for_variable) == 1 &&
      is.na(stratifier_config_for_variable)) {
    return(iterator(list(
      data = data,
      stratifiers = list(),
      stratifier_combination = data.frame()
    )))
  }

  for (stratifiers in stratifier_config_for_variable) {
    expand_grid_args <- list()
    for (strat in stratifiers) {
      strat_row <- get_row_for_variable(strat, variables_sheet)
      if (is_continuous_variable(strat_row)) {
        stop(paste("Stratifier", strat, "for variable", variable,
                   "is continuous — not supported"))
      }
      expand_grid_args[[strat]] <- c(
        get_unique_rec_end_rows(variables_details_sheet, strat, TRUE)$recEnd,
        "NA::c"
      )
    }
    all_combos <- do.call(tidyr::expand_grid, expand_grid_args)

    for (ci in seq_len(nrow(all_combos))) {
      data_for_combo <- data
      combo <- all_combos[ci, ]
      for (si in seq_len(length(stratifiers))) {
        strat <- stratifiers[[si]]
        strat_cat <- combo[1, ][[strat]]
        formatted_cat <- dplyr::case_when(
          strat_cat == "NA::a" ~ "NA(a)",
          strat_cat == "NA::b" ~ "NA(b)",
          strat_cat == "NA::c" ~ "NA(c)",
          TRUE ~ strat_cat
        )
        data_for_combo <- dplyr::filter(
          data_for_combo,
          !!as.symbol(strat) == formatted_cat
        )
      }
      iterator(list(
        data = data_for_combo,
        stratifiers = stratifiers,
        stratifier_combination = combo
      ))
    }
  }
}
