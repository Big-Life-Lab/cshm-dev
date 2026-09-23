review_recode <- function(raw, name, cycle) {
  skip_if(packageVersion("cchsflow") < "3.0.0")
  vars <- read.csv(file.path(project_root, "worksheets/cshm-variables.csv"))
  stopifnot(sum(vars$variable == name) == 1L)
  raw$fixture_id <- seq_len(nrow(raw))
  cchsflow::rec_with_table(raw, variables = vars[vars$variable == name, ], database_name = cycle, variable_details = TEST_DETAILS, notes = FALSE)[[name]]
}
test_that("racial mappings preserve every documented substantive code", {
  early <- review_recode(data.frame(SDCCDRAC = c(1:14, 96, 99)), "SDCDCGT_cat7", "cchs2003_m")
  expect_equal(as.character(early), c(as.character(c(1, 2, 5, 5, 5, 3, 4, 7, 5, 7, 7, 6, 6, 6)), "NA(a)", "NA(b)"))
  for (cycle in c("cchs2005_m", "cchs2009_2010_m", "cchs2013_2014_m")) {
    raw <- setNames(data.frame(c(1:13, 96, 99)), if (cycle == "cchs2005_m") "SDCEDCGT" else "SDCDCGT")
    out <- review_recode(raw, "SDCDCGT_cat7", cycle)
    expect_equal(as.character(out), c(as.character(c(1, 2, 5, 5, 5, 3, 7, 5, 7, 7, 6, 6, 6)), "NA(a)", "NA(b)"))
  }
  out <- review_recode(data.frame(SDCDVCGT = c(1:13, 96, 99)), "SDCDCGT_cat7", "cchs2015_2016_m")
  expect_equal(as.character(out), c(as.character(c(1, 7, 3, 2, 5, 6, 7, 5, 7, 5, 5, 6, 6)), "NA(a)", "NA(b)"))
  out <- review_recode(data.frame(SDCDVCGT = c(1:13, 96, 99)), "SDCDCGT_2015plus", "cchs2017_2018_m")
  expect_equal(as.character(out), c(as.character(1:13), "NA(a)", "NA(b)"))
})
test_that("all configured Master cycles have province rules and usable codes", {
  cfg <- config::get(file = file.path(project_root, "config.yml"), use_parent = FALSE)
  cycles <- names(cfg$cycle_codes)[grepl("_m$", names(cfg$cycle_codes))]
  for (cycle in cycles) {
    source <- switch(cycle,
      cchs2001_m = "GEOA_PRV",
      cchs2003_m = "GEOC_PRV",
      cchs2005_m = "GEOE_PRV",
      "GEO_PRV"
    )
    out <- review_recode(setNames(data.frame(c(24, 35, 99)), source), "GEOGPRV", cycle)
    expect_equal(as.character(out), c("24", "35", "NA(b)"), info = cycle)
  }
})
test_that("education does not turn incomplete postsecondary into graduation", {
  out <- review_recode(data.frame(EDUDR04 = c(1:4, 6, 9)), "EDUDR03", "cchs2013_2014_m")
  expect_equal(as.character(out), c("1", "2", "2", "3", "NA(a)", "NA(b)"))
  rows <- TEST_DETAILS[TEST_DETAILS$variable == "EDUDR03", ]
  expect_false(any(grepl("cchs2022_p", rows$databaseStart, fixed = TRUE)))
  vars <- read.csv(file.path(project_root, "worksheets/cshm-variables.csv"))
  expect_false(grepl("cchs2022_p", vars$databaseStart[vars$variable == "EDUDR03"], fixed = TRUE))
})
test_that("detailed immigration status and landed question survive harmonization", {
  out <- review_recode(data.frame(SDCDVIMM = c(1, 2, 3, 9)), "immigration_status_detailed", "cchs2023_m")
  expect_equal(as.character(out), c("1", "2", "3", "NA(b)"))
  out <- review_recode(data.frame(SDC_IM3 = c(1, 2, 6, 7, 8, 9)), "landed_immigrant_status", "cchs2015_2016_m")
  expect_equal(as.character(out), c("1", "2", "NA(a)", "NA(b)", "NA(b)", "NA(b)"))
})
test_that("province rule gaps fail the runtime coverage guard", {
  cfg <- config::get(file = file.path(project_root, "config.yml"), use_parent = FALSE)
  cfg$data_source <- "master"
  cfg$cchs_cycles <- "cchs2023_m"
  cfg$required_survey_keys <- "province"
  vars <- read.csv(file.path(project_root, "worksheets/cshm-variables.csv"))
  vars <- vars[vars$variable == "GEOGPRV", ]
  details <- TEST_DETAILS[TEST_DETAILS$variable != "GEOGPRV", ]
  expect_error(suppressWarnings(validate_cycle_coverage(vars, details, cfg, strict = TRUE)), "GEOGPRV")
})
test_that("display order follows survey years rather than stable IDs", {
  expect_identical(order_cycle_codes(c(11L, 12L, 13L, 10L), c("10" = "2019–20", "11" = "2022", "12" = "2021", "13" = "2023")), c(10L, 12L, 11L, 13L))
})

test_that("required configured inputs have rules throughout each source", {
  cfg <- config::get(file = file.path(project_root, "config.yml"), use_parent = FALSE)
  vars <- read.csv(file.path(project_root, "worksheets/cshm-variables.csv"))
  for (src in c("pumf", "master")) {
    cfg$data_source <- src
    suffix <- if (src == "master") "_m$" else "_p$"
    cfg$cchs_cycles <- names(cfg$cycle_codes)[grepl(suffix, names(cfg$cycle_codes))]
    required <- unlist(lapply(cfg$required_survey_keys, function(key) survey_var(cfg, key)))
    result <- validate_cycle_coverage(vars[vars$variable %in% required, ], TEST_DETAILS, cfg, strict = TRUE)
    expect_equal(nrow(result$declared), 0L, info = src)
    expect_equal(nrow(result$critical), 0L, info = src)
    expect_error(validate_cycle_coverage(vars[!vars$variable %in% survey_var(cfg, "province"), ], TEST_DETAILS, cfg, strict = TRUE), "GEOGPRV")
  }
})

test_that("optional Master racial inputs do not become pooled predictors", {
  cfg <- config::get(file = file.path(project_root, "config.yml"), use_parent = FALSE)
  cfg$data_source <- "master"
  vars <- read.csv(file.path(project_root, "worksheets/cshm-variables.csv"))
  race <- vars[vars$variable %in% c("SDCDCGT_cat7", "SDCDCGT_2015plus", "SDCDVVM"), ]
  expect_null(survey_var(cfg, "ethnicity"))
  expect_true(all(race$role == "intermediate"))
  expect_false(any(grepl("cchs2001_m", race$databaseStart, fixed = TRUE)))
})

test_that("immigration source coverage retains detailed responses in every declared cycle", {
  for (cycle in c("cchs2015_2016_m", "cchs2017_2018_m", "cchs2019_2020_m", "cchs2021_m")) {
    out <- review_recode(data.frame(SDC_IM3 = c(1, 2, 6, 7, 8, 9)), "landed_immigrant_status", cycle)
    expect_equal(as.character(out), c("1", "2", "NA(a)", "NA(b)", "NA(b)", "NA(b)"), info = cycle)
  }
  for (cycle in c("cchs2022_m", "cchs2023_m")) {
    out <- review_recode(data.frame(SDCDVIMM = c(1, 2, 3, 9)), "immigration_status_detailed", cycle)
    expect_equal(as.character(out), c("1", "2", "3", "NA(b)"), info = cycle)
  }
})

test_that("display ordering handles list labels and unmapped cycle IDs", {
  expect_identical(order_cycle_codes(c(11, 12, 99, NA), list("11" = "2022", "12" = "2021")), c(12L, 11L, 99L))
})

test_that("corrected category labels and dummy names agree with their output codes", {
  rows <- TEST_DETAILS[TEST_DETAILS$variable == "SDCDCGT_cat7", ]
  expect_true(all(rows$catLabelLong == rows$catLabel))
  expect_equal(rows$dummyVariable, paste0("SDCDCGT_cat7_", gsub("::", "", rows$recEnd, fixed = TRUE)))
  edu <- TEST_DETAILS[TEST_DETAILS$variable == "EDUDR03" & TEST_DETAILS$recEnd == "2", ]
  expect_true(all(edu$dummyVariable == "EDUDR03_cat3_2"))
  expect_true(all(grepl("without a postsecondary credential", edu$catLabelLong, fixed = TRUE)))
})
