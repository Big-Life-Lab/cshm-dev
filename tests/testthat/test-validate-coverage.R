test_that("check_feeder_closure passes on the project worksheets", {
  # testthat runs from tests/testthat; setup.R defines project_root
  ws <- function(f) file.path(project_root, "worksheets", f)
  vars <- read.csv(ws("cshm-variables.csv"))
  det <- as.data.frame(dplyr::bind_rows(
    read.csv(ws("cchsflow-variable-details.csv")),
    read.csv(ws("cshm-variable-details.csv"))
  ))
  expect_silent(check_feeder_closure(vars, det))
})

test_that("check_feeder_closure stops when a derived variable's feeder is missing", {
  vars <- data.frame(variable = c("derived_x", "feeder_a"), stringsAsFactors = FALSE)
  det <- data.frame(
    variable = c("derived_x", "derived_x", "feeder_a"),
    variableStart = c("DerivedVar::[feeder_a, feeder_b]", "DerivedVar::[feeder_a, feeder_b]", "cchs2001_p::A"),
    stringsAsFactors = FALSE
  )
  expect_error(check_feeder_closure(vars, det), "derived_x needs feeder_b")
})
