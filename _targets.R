library(targets)
library(tarchetypes)

# cchsflow must be attached (not just ::-qualified): v3 derivation functions
# call unqualified dplyr/rlang helpers that resolve via its Depends attachment
tar_option_set(packages = "cchsflow")

# Load all R functions
tar_source("R/")

# Configuration
cfg <- config::get()

list(
  # Stage 1: Load variable metadata worksheets
  # variable_details_sheet = cchsflow base + CSHM extensions (2019-20, 2022 cycles)
  tar_target(variables_sheet,
    read.csv(cfg$worksheets$variables)
  ),
  tar_target(variable_details_sheet,
    rbind(
      read.csv(cfg$worksheets$cchsflow_variable_details),
      read.csv(cfg$worksheets$cshm_variable_details)
    )
  ),

  # Stage 0: Pre-flight validation — verify variable coverage before loading data
  # Returns gap report (declared + critical); warns or errors per cfg$strict_validation
  tar_target(coverage_check,
    validate_cycle_coverage(variables_sheet, variable_details_sheet, cfg,
                            strict = cfg$strict_validation %||% FALSE)
  ),

  # Stage 2: Load and harmonize CCHS cycles
  # Produces data/study_data.rds — combined harmonized cycles, study variables only
  tar_target(study_data,
    load_study_data(cfg, variables_sheet, variable_details_sheet, coverage_check),
    format = "rds"
  ),

  # Stage 3: Data cleaning
  tar_target(cleaned_data,
    clean_study_data(study_data, variables_sheet, cfg)
  ),

  # Stage 4: Descriptive statistics — pre-imputation (Table 1a source data)
  tar_target(table_1a_data,
    get_cshm_desc_data(cleaned_data, variables_sheet, variable_details_sheet)
  ),

  # Stage 5: Multiple imputation
  # Produces data/analysis_data.rds — primary reproducibility artifact
  tar_target(analysis_data,
    impute_data(cleaned_data, variables_sheet, cfg),
    format = "rds"
  ),

  # Stage 6: Descriptive statistics — post-imputation (Table 1b source data)
  tar_target(table_1b_data,
    get_cshm_desc_data(analysis_data, variables_sheet, variable_details_sheet)
  ),

  # Stage 7: Prepare APC datasets (numerator + denominator combined, by sex)
  # Single target; denominator construction is the expensive step.
  # Keeping as one target lets {targets} cache the full APC data independently
  # from Stage 8 model parameters (knots, constraints).
  tar_target(apc_data,
    prepare_apc_data(analysis_data, cfg)
  ),

  # Stage 8: Fit APC models — four independent targets for parallel execution
  # and fine-grained caching (e.g. change cessation constraints → only cessation reruns)
  tar_target(apc_model_initiation_men,
    fit_apc_model(apc_data$initiation_men, "initiation", sex = 1, cfg)
  ),
  tar_target(apc_model_initiation_women,
    fit_apc_model(apc_data$initiation_women, "initiation", sex = 2, cfg)
  ),
  tar_target(apc_model_cessation_men,
    fit_apc_model(apc_data$cessation_men, "cessation", sex = 1, cfg)
  ),
  tar_target(apc_model_cessation_women,
    fit_apc_model(apc_data$cessation_women, "cessation", sex = 2, cfg)
  ),

  # Stage 9: Generate rate tables — STUB
  # Produces initiation/cessation probability tables by age, period, sex, province.
  # Used by Stage 10 to simulate individual-level smoking histories.
  # tar_target(rate_tables,
  #   generate_rate_tables(apc_models, cfg)
  # ),

  # Stage 10: Validation — STUB
  # tar_target(validation_results,
  #   validate_model(rate_tables, cfg)
  # )

  NULL
)
