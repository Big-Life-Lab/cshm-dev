# data-cleaning.R
# Age restriction, distribution checks, and out-of-range truncation.
# Pipeline target: cleaned_data

#' Clean study data
#'
#' Applies age restriction (excludes youngest age group per cfg), checks
#' skewness of continuous predictors, and truncates at the 99th percentile
#' for any with |skewness| >= 1. Tagged NAs (NA(a)/NA(b)/NA(c)) are preserved
#' throughout.
#'
#' @param study_data Output of load_study_data()
#' @param variables_sheet Variables worksheet data frame
#' @param cfg Config object from config::get()
#' @return Cleaned data frame
clean_study_data <- function(study_data, variables_sheet, cfg) {
  # Step 1: Age restriction — exclude respondents below the study floor
  # (cfg$age_exclusion_min, typically 18: drops the 12-17 age groups)
  age_col <- survey_var(cfg, "age")
  if (!is.null(cfg$age_exclusion_min) && age_col %in% colnames(study_data)) {
    n_before <- nrow(study_data)
    study_data <- study_data[
      is.na(study_data[[age_col]]) |
      study_data[[age_col]] >= cfg$age_exclusion_min,
    ]
    message(
      "Age restriction: excluded ", n_before - nrow(study_data),
      " respondents younger than ", cfg$age_exclusion_min,
      " (", nrow(study_data), " remaining)"
    )
  }

  # Step 2: Identify continuous predictor variables for skewness check
  # Roles are comma-separated; select_vars_by_role() handles multi-role rows
  continuous_predictors <- intersect(
    variables_sheet$variable[variables_sheet$variableType == "Continuous"],
    unique(c(
      select_vars_by_role("predictor", variables_sheet),
      select_vars_by_role("model-stratifier", variables_sheet)
    ))
  )
  continuous_predictors <- intersect(continuous_predictors, colnames(study_data))

  # Step 3: Check skewness and truncate where |skewness| >= cfg$skewness_threshold
  skewness_summary <- check_skewness(
    study_data, continuous_predictors, cfg$skewness_threshold
  )

  message("\nSkewness check for continuous predictors:")
  print(skewness_summary$summary)

  if (length(skewness_summary$vars_to_truncate) > 0) {
    message(
      "\nTruncating at ", cfg$truncate_percentile, "th percentile: ",
      paste(skewness_summary$vars_to_truncate, collapse = ", ")
    )
    study_data <- truncate_continuous(
      study_data, skewness_summary$vars_to_truncate, cfg$truncate_percentile
    )
  } else {
    message("\nNo truncation needed.")
  }

  study_data
}

#' Check skewness of continuous variables
#'
#' @param data Data frame
#' @param vars Character vector of continuous variable names to check
#' @param threshold Absolute skewness threshold (default 1)
#' @return List with `vars_to_truncate` (character) and `summary` (data frame)
check_skewness <- function(data, vars, threshold) {
  rows <- lapply(vars, function(var) {
    x <- data[[var]]
    # Exclude tagged NAs — use only non-NA values for skewness calculation
    x_valid <- x[!is.na(x)]
    if (length(x_valid) < 3) return(NULL)

    # Pearson's moment coefficient of skewness (type 2 = unbiased, matches SAS)
    n <- length(x_valid)
    m <- mean(x_valid)
    s <- sd(x_valid)
    if (s == 0) return(NULL)
    skew <- (sum((x_valid - m)^3) / n) / (s^3) * sqrt(n * (n - 1)) / (n - 2)

    data.frame(
      variable    = var,
      n_valid     = n,
      skewness    = round(skew, 3),
      abs_skewness = round(abs(skew), 3),
      action      = if (abs(skew) >= threshold) "truncate" else "keep",
      stringsAsFactors = FALSE
    )
  })

  rows <- do.call(rbind, rows[!sapply(rows, is.null)])

  vars_to_truncate <- if (!is.null(rows)) {
    rows$variable[rows$action == "truncate"]
  } else {
    character(0)
  }

  list(vars_to_truncate = vars_to_truncate, summary = rows)
}

#' Truncate continuous variables at a given percentile
#'
#' Values above the truncation percentile are capped at that value.
#' Tagged NAs (haven::tagged_na) are preserved — not capped or coerced.
#'
#' @param data Data frame
#' @param vars Character vector of variable names to truncate
#' @param percentile Percentile to truncate at (0-100)
#' @return Data frame with truncated values
truncate_continuous <- function(data, vars, percentile) {
  stopifnot(percentile >= 0, percentile <= 100)
  for (var in vars) {
    x <- data[[var]]
    cap <- quantile(x, percentile / 100, na.rm = TRUE)
    # Preserve tagged NAs: only cap non-NA values that exceed the cap
    data[[var]] <- dplyr::if_else(
      !is.na(x) & x > cap,
      cap,
      x,
      missing = x  # tagged NAs pass through unchanged
    )
  }
  data
}
