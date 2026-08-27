# config-utils.R — helpers for accessing config.yml values
#
# survey_var(cfg, "age")        → variable name for current data_source
# survey_bound(cfg, "age", "min") → analytical bound for a survey variable

# Null-coalescing operator (base R >= 4.4 ships %||%; keep this for R >= 4.2 compat)
`%||%` <- function(x, y) if (is.null(x)) y else x

survey_var <- function(cfg, key) {
  entry <- cfg$survey[[key]]
  if (is.null(entry)) stop("survey_var: unknown key '", key, "'")
  # Scalar values (e.g. cycle) are stored directly, not as pumf/master lists
  if (!is.list(entry)) {
    return(entry)
  }
  src <- cfg$data_source %||% "pumf"
  src_entry <- entry[[src]]
  if (is.null(src_entry)) stop("survey_var: no '", src, "' entry for key '", key, "'")
  # Source entry is itself a list with var, min, max; or a plain scalar
  if (is.list(src_entry)) src_entry[["var"]] else src_entry
}

# Access a bound (min/max) for the active data source.
# e.g. survey_bound(cfg, "age_first_cigarette", "min") → 13 (pumf) or 8 (master)
# Access a value code for the active data source, e.g.
# survey_code(cfg, "established_smoker", "yes_code") -> 1
# (keys are named *_code because bare YAML keys such as `yes` parse as booleans)
survey_code <- function(cfg, key, code) {
  entry <- cfg$survey[[key]]
  if (is.null(entry)) stop("survey_code: unknown key '", key, "'")
  src <- cfg$data_source %||% "pumf"
  src_entry <- entry[[src]]
  if (is.null(src_entry)) stop("survey_code: no '", src, "' entry for key '", key, "'")
  val <- if (is.list(src_entry)) src_entry[[code]] else NULL
  if (is.null(val)) stop("survey_code: no code '", code, "' for key '", key, "' source '", src, "'")
  val
}

# Database name for a survey-cycle code (1-based position in cfg$cchs_cycles).
cycle_database <- function(cfg, cycle_code) {
  code <- suppressWarnings(as.integer(as.character(cycle_code)))
  out <- rep(NA_character_, length(code))
  ok <- !is.na(code) & code >= 1 & code <= length(cfg$cchs_cycles)
  out[ok] <- unlist(cfg$cchs_cycles)[code[ok]]
  out
}

# Valid range of a survey variable for one database. config.yml declares
# `range: variable_details` and the range is read from the worksheet rules
# (details_range()); a literal min/max in config is honoured only as a legacy
# fallback. Returns c(min, max), NA where the rules give no bound.
survey_range <- function(cfg, key, database, variable_details_sheet) {
  entry <- cfg$survey[[key]]
  if (is.null(entry)) stop("survey_range: unknown key '", key, "'")
  src <- cfg$data_source %||% "pumf"
  src_entry <- entry[[src]]
  if (is.null(src_entry) || !is.list(src_entry)) stop("survey_range: no '", src, "' entry for key '", key, "'")
  if (identical(src_entry$range, "variable_details")) {
    return(details_range(src_entry$var, database, variable_details_sheet))
  }
  if (!is.null(src_entry$min) || !is.null(src_entry$max)) {
    return(c(min = src_entry$min %||% NA_real_, max = src_entry$max %||% NA_real_))
  }
  c(min = NA_real_, max = NA_real_)
}

# The initiation floor is an analysis decision (public issue #5), not a variable
# range, so it lives under apc: in config, per data source.
initiation_floor <- function(cfg) {
  src <- cfg$data_source %||% "pumf"
  val <- cfg$apc$initiation_floor_age[[src]]
  if (is.null(val)) stop("cfg$apc$initiation_floor_age has no entry for source '", src, "'")
  val
}

# Literal bounds in config are legacy; variable ranges come from the worksheet
# through survey_range().
survey_bound <- function(cfg, key, bound) {
  entry <- cfg$survey[[key]]
  if (is.null(entry)) stop("survey_bound: unknown key '", key, "'")
  src <- cfg$data_source %||% "pumf"
  src_entry <- entry[[src]]
  if (is.null(src_entry)) stop("survey_bound: no '", src, "' entry for key '", key, "'")
  val <- if (is.list(src_entry)) src_entry[[bound]] else NULL
  if (is.null(val)) stop("survey_bound: no '", bound, "' for key '", key, "' source '", src, "'")
  val
}
