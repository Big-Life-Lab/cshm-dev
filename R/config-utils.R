# config-utils.R — helpers for accessing config.yml values
#
# survey_var(cfg, "age")        → variable name for current data_source
# survey_bound(cfg, "age", "min") → analytical bound for a survey variable

# Null-coalescing operator (base R >= 4.4 has |>; keep this for R >= 4.2 compat)
`%||%` <- function(x, y) if (is.null(x)) y else x

survey_var <- function(cfg, key) {
  entry <- cfg$survey[[key]]
  if (is.null(entry)) stop("survey_var: unknown key '", key, "'")
  # Scalar values (e.g. cycle) are stored directly, not as pumf/master lists
  if (!is.list(entry)) return(entry)
  src <- cfg$data_source %||% "pumf"
  src_entry <- entry[[src]]
  if (is.null(src_entry)) stop("survey_var: no '", src, "' entry for key '", key, "'")
  # Source entry is itself a list with var, min, max; or a plain scalar
  if (is.list(src_entry)) src_entry[["var"]] else src_entry
}

# Access a bound (min/max) for the active data source.
# e.g. survey_bound(cfg, "age_first_cigarette", "min") → 13 (pumf) or 8 (master)
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
