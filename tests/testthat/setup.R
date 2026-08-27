# cchsflow must be attached (its derivation functions resolve unqualified
# dplyr/rlang helpers via Depends) — mirrors tar_option_set in _targets.R
suppressPackageStartupMessages(library(cchsflow))

# setup.R — loaded automatically by testthat before all test files
# Sources all R functions from the project root, making them available in tests.

project_root <- normalizePath(file.path(dirname(dirname(getwd()))))

r_files <- list.files(
  file.path(project_root, "R"),
  pattern = "\\.R$",
  full.names = TRUE,
  recursive = FALSE
)
invisible(lapply(r_files, source))

# The variable-details worksheet is the reference for variable ranges; the APC
# builders take it as an argument. Load it once for all tests.
TEST_DETAILS <- as.data.frame(dplyr::bind_rows(
  read.csv(file.path(project_root, "worksheets", "cchsflow-variable-details.csv")),
  read.csv(file.path(project_root, "worksheets", "cshm-variable-details.csv"))
))
