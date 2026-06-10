# setup.R — loaded automatically by testthat before all test files
# Sources all R functions from the project root, making them available in tests.

project_root <- normalizePath(file.path(dirname(dirname(getwd()))))

r_files <- list.files(
  file.path(project_root, "R"),
  pattern  = "\\.R$",
  full.names = TRUE,
  recursive  = FALSE
)
invisible(lapply(r_files, source))
