# smoking-histories.R
# Simulate individual-level smoking histories from fitted APC rate tables.
# Pipeline target: smoking_histories

#' Generate Canadian rate tables for shg-rcpp
#'
#' Extracts initiation and cessation probability tables from fitted APC models,
#' formatted to match the CISNET shg-rcpp input specification. PUMF-derived
#' tables can be shared internationally under the Statistics Canada Open Licence.
#'
#' @param apc_models List of fitted APC models (initiation + cessation, by sex)
#' @param cfg Config object from config::get()
#' @return List of rate tables (initiation_men, initiation_women, cessation)
generate_rate_tables <- function(apc_models, cfg) {
  # TODO: implement
  # Output format: shg-rcpp input specification
  # See: https://github.com/NCI-CISNET/shg-rcpp
  stop("Not yet implemented")
}
