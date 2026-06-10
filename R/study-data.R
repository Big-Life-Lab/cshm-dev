# study-data.R
# Load and harmonize CCHS cycles via cchsflow.
# Pipeline target: study_data

#' Survey cycle numeric code from dataset name
#'
#' @param data_name cchsflow dataset name (e.g. "cchs2001_p")
#' @return Integer cycle code (1 = 2001, ..., 11 = 2022)
survey_cycle_code <- function(data_name) {
  codes <- c(
    cchs2001_p      = 1L,
    cchs2003_p      = 2L,
    cchs2005_p      = 3L,
    cchs2007_2008_p = 4L,
    cchs2009_2010_p = 5L,
    cchs2011_2012_p = 6L,
    cchs2013_2014_p = 7L,
    cchs2015_2016_p = 8L,
    cchs2017_2018_p = 9L,
    cchs2019_2020_p = 10L,
    cchs2022_p      = 11L
  )
  code <- codes[[data_name]]
  if (is.null(code)) stop("Unknown CCHS dataset name: ", data_name)
  code
}

#' Load and harmonize CCHS PUMF cycles
#'
#' Reads all configured CCHS cycles from raw_data_dir, harmonizes variables
#' using cchsflow worksheets, adds SurveyCycle, and combines into a single
#' data frame.
#'
#' @param cfg Config object from config::get()
#' @param variables_sheet variables worksheet (data frame)
#' @param variable_details_sheet variable_details worksheet (data frame)
#' @return Combined harmonized data frame (all cycles, study variables only)
load_study_data <- function(cfg, variables_sheet, variable_details_sheet,
                            coverage_check = NULL) {
  # Filter to variables for this data source (pumf/master/both)
  # The cycle variable (survey_var(cfg, "cycle")) is derived manually — rec_with_table cannot derive it
  study_vars <- variables_sheet[
    variables_sheet$variable != survey_var(cfg, "cycle") &
    variables_sheet$source %in% c(cfg$data_source, "both"),
  ]

  harmonized <- NULL
  data_env   <- new.env()

  for (cycle in cfg$cchs_cycles) {
    # Support raw_data_file_map (cchsflow-data naming) or default cchs*_p.RData naming
    filename <- if (!is.null(cfg$raw_data_file_map[[cycle]])) {
      cfg$raw_data_file_map[[cycle]]
    } else {
      paste0(cycle, ".RData")
    }
    rdata_path <- file.path(cfg$raw_data_dir, filename)

    if (!file.exists(rdata_path)) {
      warning("Cycle file not found, skipping: ", rdata_path)
      next
    }

    message("Harmonizing ", cycle)
    loaded_name <- load(rdata_path, envir = data_env)

    # cchsflow-data release files use `table` as the internal object name
    obj_name <- if ("table" %in% loaded_name) "table" else loaded_name[1]
    raw_data <- get(obj_name, envir = data_env)

    if (cfg$sample_proportion < 1) {
      n_sample <- round(nrow(raw_data) * cfg$sample_proportion)
      raw_data <- raw_data[sample(nrow(raw_data), n_sample), ]
    }

    # rec_with_table (cchsflow v3) requires a plain data.frame, not a tibble.
    # When data is a tibble, data[logi_idx, "col"] returns a 1-column tibble
    # (a list), which breaks the copy recEnd assignment with a range recStart.
    raw_data <- as.data.frame(raw_data)

    cycle_data <- cchsflow::rec_with_table(
      data          = raw_data,
      variables     = study_vars,
      database_name = cycle,
      variable_details = variable_details_sheet,
      notes         = FALSE
    )

    cycle_data[[survey_var(cfg, "cycle")]] <- survey_cycle_code(cycle)

    if (is.null(harmonized)) {
      harmonized <- cycle_data
    } else {
      harmonized <- dplyr::bind_rows(harmonized, cycle_data)
    }

    rm(list = obj_name, envir = data_env)
    message("  Done: ", cycle, " (", nrow(cycle_data), " rows)")
  }

  if (is.null(harmonized)) stop("No CCHS cycles loaded — check cfg$raw_data_dir")

  # Convert types per variables worksheet
  for (var in colnames(harmonized)) {
    row <- variables_sheet[variables_sheet$variable == var, ]
    if (nrow(row) == 0) next
    if (row$variableType[1] == "Categorical") {
      harmonized[[var]] <- as.factor(harmonized[[var]])
    } else if (row$variableType[1] == "Continuous") {
      harmonized[[var]] <- as.numeric(harmonized[[var]])
    }
  }

  harmonized
}
