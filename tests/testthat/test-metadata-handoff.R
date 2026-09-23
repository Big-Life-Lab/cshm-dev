testthat::test_that("cycle lookup survives subsets and reordering", {
  cfg <- config::get(file = file.path(project_root, "config.yml"), use_parent = FALSE)
  cfg$cchs_cycles <- c("cchs2022_p", "cchs2003_p")
  testthat::expect_identical(cycle_database(cfg, c(2, 11, 1)), c("cchs2003_p", "cchs2022_p", NA_character_))
  cfg$data_source <- "master"
  cfg$cchs_cycles <- c("cchs2023_m", "cchs2021_m")
  testthat::expect_identical(survey_cycle_code("cchs2023_m", cfg), 13L)
  testthat::expect_identical(cycle_database(cfg, c(12, 13)), c("cchs2021_m", "cchs2023_m"))
})
testthat::test_that("Master imputation ignores PUMF-only predictors", {
  vars <- data.frame(variable = c("age_p", "age_m"), source = c("pumf", "master"), role = "imputation-predictor")
  data <- data.frame(age_m = c(30, 40, 50))
  result <- impute_data(data, vars, list(data_source = "master"))
  testthat::expect_identical(result$datasets[[1]], data)
})
testthat::test_that("secure overrides resolve at the top level", {
  local <- tempfile(fileext = ".yml")
  writeLines(c("default:", '  raw_data_dir: "fixture-master"', "  cchs_cycles: [cchs2023_m]"), local)
  on.exit(unlink(local))
  cfg <- load_study_config(file = file.path(project_root, "config.yml"), profile = "statscan", local_file = local)
  testthat::expect_identical(cfg$data_source, "master")
  testthat::expect_identical(cfg$raw_data_dir, "fixture-master")
  testthat::expect_equal(unlist(cfg$cchs_cycles), "cchs2023_m")
  testthat::expect_identical(survey_var(cfg, "education"), "EDUDR03")
  testthat::expect_error(load_study_config(file = file.path(project_root, "config.yml"), profile = "statscan", local_file = paste0(local, "absent")), "not found")
  writeLines(c("default:", "  data_source: pumf"), local)
  testthat::expect_error(load_study_config(file = file.path(project_root, "config.yml"), profile = "statscan", local_file = local), "master")
})
testthat::test_that("source recodes preserve status codes and distinct timing", {
  testthat::skip_if(packageVersion("cchsflow") < "3.0.0", "Requires the project-pinned cchsflow v3")
  vars <- read.csv(file.path(project_root, "worksheets/cshm-variables.csv"))
  rec <- function(data, names, cycle) {
    cchsflow::rec_with_table(
      data,
      variables = vars[vars$variable %in% names, ], database_name = cycle,
      variable_details = TEST_DETAILS, notes = FALSE
    )
  }
  status <- rec(data.frame(SDCDGIMM = c(1, 2, 6, 7, 8, 9), id = 1:6), "SDCFIMM", "cchs2022_p")
  testthat::expect_equal(as.character(status$SDCFIMM), c("2", "1", "NA(a)", "NA(b)", "NA(b)", "NA(b)"))
  dates <- rec(
    data.frame(IM_02 = c(1990, 9996, 9997), IM_04 = c(1995, 9996, 9999)),
    c("arrival_year", "landed_immigrant_year"), "cchs2023_m"
  )
  testthat::expect_equal(as.numeric(dates$arrival_year[1]), 1990)
  testthat::expect_equal(as.numeric(dates$landed_immigrant_year[1]), 1995)
  testthat::expect_true(haven::is_tagged_na(dates$arrival_year[2], "a"))
  testthat::expect_true(haven::is_tagged_na(dates$arrival_year[3], "b"))
  vm <- rec(data.frame(SDCDVVM = c(1, 13, 99), id = 1:3), "SDCDVVM", "cchs2023_m")
  testthat::expect_equal(as.character(vm$SDCDVVM), c("1", "13", "NA(b)"))
})
testthat::test_that("all configured source variables can be selected for loading", {
  vars <- read.csv(file.path(project_root, "worksheets/cshm-variables.csv"))
  cfg <- config::get(file = file.path(project_root, "config.yml"), use_parent = FALSE)
  for (src in c("pumf", "master")) {
    cfg$data_source <- src
    selected <- vars$variable[vars$source %in% c(src, "both")]
    for (key in names(cfg$survey)) {
      name <- survey_var(cfg, key)
      if (!is.null(name)) testthat::expect_true(name %in% selected, info = paste(src, key, name))
    }
  }
})
