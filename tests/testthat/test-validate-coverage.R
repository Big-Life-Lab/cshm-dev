test_that("check_feeder_closure passes on the project worksheets", {
  # testthat runs from tests/testthat; setup.R defines project_root
  ws <- function(f) file.path(project_root, "worksheets", f)
  vars <- read.csv(ws("cshm-variables.csv"))
  det <- as.data.frame(dplyr::bind_rows(
    read.csv(ws("cchsflow-variable-details.csv")),
    read.csv(ws("cshm-variable-details.csv"))
  ))
  # Restricted to the study cycles. The 2019-20 PUMF has no SMKG040 (grouped age started
  # daily), yet the cchsflow rules for SMKG203_cont/SMKG207_cont/age_start_smoking name
  # cchs2019_2020_p; the check reports that gap rather than passing over it.
  study_dbs <- unlist(config::get()$cchs_cycles)
  expect_warning(
    check_feeder_closure(vars, det, databases = study_dbs),
    "SMKG040_cont in cchs2019_2020_p"
  )
  # Every feeder is at least declared in cshm-variables.csv (no stop).
  expect_no_error(suppressWarnings(check_feeder_closure(vars, det, databases = study_dbs)))
})

test_that("check_feeder_closure stops when a derived variable's feeder is missing", {
  vars <- data.frame(variable = c("derived_x", "feeder_a"), stringsAsFactors = FALSE)
  det <- data.frame(
    variable = c("derived_x", "derived_x", "feeder_a"),
    variableStart = c("DerivedVar::[feeder_a, feeder_b]", "DerivedVar::[feeder_a, feeder_b]", "cchs2001_p::A"),
    databaseStart = c("cchs2001_p", "cchs2003_p", "cchs2001_p, cchs2003_p"),
    stringsAsFactors = FALSE
  )
  expect_error(check_feeder_closure(vars, det), "derived_x needs feeder_b")
})

test_that("check_feeder_closure is cycle-specific: a feeder present only in another cycle does not close the chain", {
  vars <- data.frame(variable = c("derived_x", "feeder_a"), stringsAsFactors = FALSE)
  det <- data.frame(
    variable = c("derived_x", "feeder_a"),
    variableStart = c("DerivedVar::[feeder_a]", "cchs2001_p::A"),
    databaseStart = c("cchs2001_p, cchs2003_p", "cchs2001_p"), # feeder_a has no 2003 rule
    stringsAsFactors = FALSE
  )
  expect_warning(check_feeder_closure(vars, det), "derived_x needs feeder_a in cchs2003_p")
  # Restricting the check to the databases in use removes the gap
  expect_silent(check_feeder_closure(vars, det, databases = "cchs2001_p"))
  det$databaseStart[2] <- "cchs2001_p, cchs2003_p"
  expect_silent(check_feeder_closure(vars, det))
})
