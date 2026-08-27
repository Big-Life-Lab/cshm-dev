# validate-coverage.R — Pre-flight validation of variable coverage
#
# Checks that every variable declared in cshm-variables.csv has matching
# rows in the combined variable_details for each cycle it claims.
# This is the CCHS-specific validation layer (the "spur"): it verifies
# that config.yml variable mappings resolve correctly against cchsflow's
# variable_details before the pipeline runs.
#
# Two checks:
#   1. Declared coverage: does variable_details deliver what cshm-variables.csv
#      claims in its databaseStart column?
#   2. Critical coverage: do variables with pipeline-critical roles
#      (design, model-stratifier, apc-numerator, apc-denominator) have
#      complete coverage across all pipeline cycles?

#' Validate variable coverage against variable_details
#'
#' @param variables_sheet Data frame from cshm-variables.csv
#' @param variable_details_sheet Data frame: rbind of cchsflow base +
#'   CSHM extension variable_details
#' @param cfg Config list (needs cfg$cchs_cycles, cfg$data_source)
#' @param strict If TRUE, stop on any critical coverage gap.
#'   If FALSE (default), warn and return results.
#' @return Invisibly, a list with two data frames:
#'   \describe{
#'     \item{declared}{Gaps where cshm-variables.csv claims a cycle but
#'       variable_details cannot deliver it.}
#'     \item{critical}{Pipeline cycles missing for critical-role variables.}
#'   }
validate_cycle_coverage <- function(variables_sheet,
                                    variable_details_sheet,
                                    cfg,
                                    strict = FALSE) {
  data_source <- cfg$data_source %||% "pumf"

  # Filter variables sheet to active data source
  source_col <- variables_sheet$source
  active_vars <- variables_sheet[
    !is.na(source_col) & (source_col == data_source | source_col == "both"),
  ]

  # Pipeline cycles (e.g. cchs2001_p ... cchs2022_p)
  pipeline_cycles <- cfg$cchs_cycles
  if (is.null(pipeline_cycles)) {
    warning("validate_cycle_coverage: cfg$cchs_cycles is NULL; skipping")
    return(invisible(list(declared = data.frame(), critical = data.frame())))
  }

  # Build lookup: for each variable in variable_details, which cycles are covered?
  vd_coverage <- split(
    variable_details_sheet$databaseStart,
    variable_details_sheet$variable
  )
  vd_coverage <- lapply(vd_coverage, function(db_strings) {
    unique(trimws(unlist(strsplit(db_strings, ","))))
  })

  # Roles that must have complete pipeline coverage
  critical_roles <- c("design", "model-stratifier", "apc-numerator", "apc-denominator")

  declared_gaps <- data.frame(
    variable = character(0), cycle = character(0), role = character(0),
    stringsAsFactors = FALSE
  )
  critical_gaps <- data.frame(
    variable = character(0), cycle = character(0), role = character(0),
    stringsAsFactors = FALSE
  )

  for (i in seq_len(nrow(active_vars))) {
    var_name <- active_vars$variable[i]
    var_start <- active_vars$variableStart[i]
    var_role <- active_vars$role[i]

    # Skip DerivedVar-only variables (e.g. SurveyCycle)
    if (!is.na(var_start) && grepl("^DerivedVar::", var_start)) next
    # Skip variables with empty variableStart (resolved internally by cchsflow)
    if (is.na(var_start) || var_start == "") next

    covered_cycles <- vd_coverage[[var_name]]
    if (is.null(covered_cycles)) covered_cycles <- character(0)

    # --- Check 1: Declared coverage ---
    # Which pipeline cycles does cshm-variables.csv claim?
    declared_db <- trimws(unlist(strsplit(active_vars$databaseStart[i], ",")))
    declared_pipeline <- intersect(declared_db, pipeline_cycles)

    for (cycle in declared_pipeline) {
      if (!(cycle %in% covered_cycles)) {
        declared_gaps <- rbind(declared_gaps, data.frame(
          variable = var_name, cycle = cycle, role = var_role,
          stringsAsFactors = FALSE
        ))
      }
    }

    # --- Check 2: Critical coverage ---
    roles <- trimws(unlist(strsplit(var_role, ",")))
    is_critical <- any(roles %in% critical_roles)

    if (is_critical) {
      for (cycle in pipeline_cycles) {
        if (!(cycle %in% covered_cycles)) {
          critical_gaps <- rbind(critical_gaps, data.frame(
            variable = var_name, cycle = cycle, role = var_role,
            stringsAsFactors = FALSE
          ))
        }
      }
    }
  }

  # --- Report declared gaps ---
  if (nrow(declared_gaps) > 0) {
    gap_summary <- tapply(declared_gaps$cycle, declared_gaps$variable, function(cycles) {
      paste(cycles, collapse = ", ")
    })
    msg_lines <- vapply(names(gap_summary), function(v) {
      sprintf("  %s: missing %s", v, gap_summary[[v]])
    }, character(1))
    warning(
      "Declared coverage gaps (cshm-variables.csv claims cycle but variable_details lacks it):\n",
      paste(msg_lines, collapse = "\n"),
      call. = FALSE
    )
  }

  # --- Report critical gaps ---
  if (nrow(critical_gaps) > 0) {
    gap_summary <- tapply(critical_gaps$cycle, critical_gaps$variable, function(cycles) {
      paste(cycles, collapse = ", ")
    })
    msg_lines <- vapply(names(gap_summary), function(v) {
      sprintf(
        "  %s [%s]: missing %s", v,
        critical_gaps$role[critical_gaps$variable == v][1],
        gap_summary[[v]]
      )
    }, character(1))
    msg <- paste0(
      "Critical coverage gaps (pipeline-essential variables missing for some cycles):\n",
      paste(msg_lines, collapse = "\n")
    )
    if (strict) {
      stop(msg, call. = FALSE)
    } else {
      warning(msg, call. = FALSE)
    }
  }

  if (nrow(declared_gaps) == 0 && nrow(critical_gaps) == 0) {
    message("All variables pass coverage validation.")
  }

  invisible(list(declared = declared_gaps, critical = critical_gaps))
}


#' Check that every derived study variable has all of its feeders in the sheet
#'
#' cchsflow derives a variable only when every input listed in its
#' `DerivedVar::[...]` rule is present. A missing feeder makes rec_with_table()
#' skip the derived variable without an error, and the gap is noticed only when a
#' later stage looks for the column (in the first CI run of task 1.3, after 56
#' minutes). This check reads the derivation rules from the variable-details
#' sheet and stops at Stage 1 if a feeder is absent from the variables sheet.
#'
#' @param variables_sheet Study variables worksheet (data frame)
#' @param variable_details_sheet Combined variable-details worksheet (data frame)
#' @return Invisibly, a data frame of (variable, missing_feeder) pairs; stops if
#'   any row exists
check_feeder_closure <- function(variables_sheet, variable_details_sheet, databases = NULL) {
  # `databases`: restrict the check to these database names (normally the study cycles,
  # unlist(cfg$cchs_cycles)); NULL checks every database a derived rule names.
  study <- unique(variables_sheet$variable)
  det <- variable_details_sheet[, c("variable", "variableStart", "databaseStart")]
  split_dbs <- function(x) trimws(strsplit(as.character(x), ",")[[1]])
  det_dbs <- lapply(det$databaseStart, split_dbs)
  rules <- which(det$variable %in% study & grepl("DerivedVar::\\[", det$variableStart))
  gaps <- list()
  for (i in rules) {
    inner <- sub(".*DerivedVar::\\[([^]]*)\\].*", "\\1", det$variableStart[i])
    feeders <- trimws(strsplit(inner, ",")[[1]])
    dbs_i <- det_dbs[[i]]
    if (!is.null(databases)) dbs_i <- intersect(dbs_i, databases)
    for (db in dbs_i) {
      for (f in feeders) {
        in_study <- f %in% study
        # A feeder only closes the chain for this database if the details sheet has a rule
        # for it in the same database; a rule in another cycle does not count.
        has_rule <- any(det$variable == f & vapply(det_dbs, function(x) db %in% x, logical(1)))
        if (!in_study || !has_rule) {
          gaps[[length(gaps) + 1]] <- data.frame(
            variable = det$variable[i], missing_feeder = f, database = db,
            reason = if (!in_study) "not in cshm-variables.csv" else "no variable-details rule for this database",
            stringsAsFactors = FALSE
          )
        }
      }
    }
  }
  gaps <- if (length(gaps)) {
    unique(do.call(rbind, gaps))
  } else {
    data.frame(
      variable = character(0), missing_feeder = character(0),
      database = character(0), reason = character(0)
    )
  }
  not_in_study <- gaps[gaps$reason == "not in cshm-variables.csv", , drop = FALSE]
  no_rule <- gaps[gaps$reason != "not in cshm-variables.csv", , drop = FALSE]
  if (nrow(not_in_study) > 0) {
    # Fixable in this repo: add the feeder as an intermediate row.
    stop(
      "Derived study variables with feeders missing from worksheets/cshm-variables.csv: ",
      paste(unique(paste0(not_in_study$variable, " needs ", not_in_study$missing_feeder)), collapse = "; "),
      ". Add the feeders as intermediate rows; cchsflow skips the derivation silently otherwise."
    )
  }
  if (nrow(no_rule) > 0) {
    # The derived rule names a database in which its feeder has no rule (the feeder is not in
    # that cycle's file). cchsflow returns NA for the derived variable there. This is recorded
    # as a warning so the gap is visible in the pipeline log and in the coverage_check target.
    warning(
      "Derived study variables whose feeders have no variable-details rule in a database they are derived for ",
      "(the derived variable will be missing for that cycle): ",
      paste(unique(paste0(no_rule$variable, " needs ", no_rule$missing_feeder, " in ", no_rule$database)), collapse = "; "),
      call. = FALSE
    )
  }
  invisible(gaps)
}
