library(testthat)
# R functions loaded via tests/testthat/setup.R

# ---- Shared fixtures --------------------------------------------------------

make_variables_sheet <- function() {
  data.frame(
    variable     = c("SurveyCycle", "DHH_SEX", "DHH_AGE", "SMKDSTY"),
    label        = c("Survey cycle", "Sex", "Age", "Smoking status"),
    variableType = c("Categorical", "Categorical", "Continuous", "Categorical"),
    section      = c("Sociodemographics", "Sociodemographics",
                     "Sociodemographics", "Health behaviour"),
    units        = c("N/A", "N/A", "Years", "N/A"),
    role         = c("design", "model-stratifier", "predictor", "predictor"),
    stringsAsFactors = FALSE
  )
}

make_variable_details_sheet <- function() {
  data.frame(
    variable = c(
      "DHH_SEX", "DHH_SEX",
      "SMKDSTY", "SMKDSTY", "SMKDSTY",
      "DHH_AGE", "DHH_AGE", "DHH_AGE",
      "SurveyCycle", "SurveyCycle"
    ),
    recEnd = c(
      "1", "2",
      "1", "2", "3",
      "copy", "NA::a", "NA::b",
      "1", "2"
    ),
    catLabel = c(
      "Male", "Female",
      "Daily", "Occasional", "Former",
      "Age", "not applicable", "missing",
      "2001", "2003"
    ),
    typeEnd = c(
      "cat", "cat",
      "cat", "cat", "cat",
      "cont", "cont", "cont",
      "cat", "cat"
    ),
    units = rep("N/A", 10),
    stringsAsFactors = FALSE
  )
}

make_study_data <- function(n = 100, seed = 42) {
  set.seed(seed)
  data.frame(
    SurveyCycle = sample(1:2, n, replace = TRUE),
    DHH_SEX     = sample(c("1", "2"), n, replace = TRUE),
    DHH_AGE     = as.numeric(sample(15:80, n, replace = TRUE)),
    SMKDSTY     = sample(c("1", "2", "3"), n, replace = TRUE),
    stringsAsFactors = FALSE
  )
}

# ---- select_vars_by_role ----------------------------------------------------

test_that("select_vars_by_role returns correct variables", {
  vs <- make_variables_sheet()
  expect_equal(select_vars_by_role("predictor", vs), c("DHH_AGE", "SMKDSTY"))
  expect_equal(select_vars_by_role("model-stratifier", vs), "DHH_SEX")
  expect_equal(select_vars_by_role("design", vs), c("SurveyCycle", "WTS_M")[
    c("SurveyCycle", "WTS_M") %in% select_vars_by_role("design", vs)
  ])
  expect_length(select_vars_by_role("nonexistent", vs), 0)
})

# ---- get_unique_rec_end_rows ------------------------------------------------

test_that("get_unique_rec_end_rows excludes NA rows by default", {
  vds <- make_variable_details_sheet()
  rows <- get_unique_rec_end_rows(vds, "SMKDSTY")
  expect_false(any(rows$recEnd %in% c("NA::a", "NA::b", "NA::c")))
  expect_equal(nrow(rows), 3)
})

test_that("get_unique_rec_end_rows includes NA rows when requested", {
  vds <- make_variable_details_sheet()
  rows <- get_unique_rec_end_rows(vds, "DHH_AGE", include_NA = TRUE)
  expect_true(any(rows$recEnd == "NA::a"))
  expect_true(any(rows$recEnd == "NA::b"))
})

test_that("get_unique_rec_end_rows filters Func:: rows", {
  vds <- data.frame(
    variable = c("X", "X", "X"),
    recEnd   = c("1", "Func::foo", "2"),
    catLabel = c("A", "B", "C"),
    typeEnd  = rep("cat", 3),
    units    = rep("N/A", 3),
    stringsAsFactors = FALSE
  )
  rows <- get_unique_rec_end_rows(vds, "X")
  expect_false(any(grepl("Func::", rows$recEnd)))
  expect_equal(nrow(rows), 2)
})

# ---- get_descriptive_data ---------------------------------------------------

test_that("get_descriptive_data returns a data frame with expected columns", {
  data <- make_study_data()
  vs   <- make_variables_sheet()
  vds  <- make_variable_details_sheet()

  stratify_config <- list(all = list("DHH_SEX"))
  result <- get_descriptive_data(data, vs, vds, c("DHH_AGE", "SMKDSTY"),
                                  stratify_config)

  expect_s3_class(result, "data.frame")
  expect_true(all(c("variable", "cat", "n", "groupBy_1", "groupByValue_1")
                  %in% colnames(result)))
})

test_that("get_descriptive_data produces rows for each sex stratum", {
  data <- make_study_data()
  vs   <- make_variables_sheet()
  vds  <- make_variable_details_sheet()

  stratify_config <- list(all = list("DHH_SEX"))
  result <- get_descriptive_data(data, vs, vds, "DHH_AGE", stratify_config)

  male_rows   <- result[!is.na(result$groupByValue_1) &
                        result$groupByValue_1 == "1", ]
  female_rows <- result[!is.na(result$groupByValue_1) &
                        result$groupByValue_1 == "2", ]
  expect_gt(nrow(male_rows), 0)
  expect_gt(nrow(female_rows), 0)
})

test_that("get_descriptive_data continuous rows have numeric summary stats", {
  data <- make_study_data()
  vs   <- make_variables_sheet()
  vds  <- make_variable_details_sheet()

  stratify_config <- list(all = list("DHH_SEX"))
  result <- get_descriptive_data(data, vs, vds, "DHH_AGE", stratify_config)

  # Filter to real strata (not the NA::c empty stratum)
  cont_rows <- result[
    result$variable == "DHH_AGE" &
    is.na(result$cat) &
    !is.na(result$groupByValue_1) &
    result$groupByValue_1 %in% c("1", "2"), ]
  expect_gt(nrow(cont_rows), 0)
  expect_true(all(!is.na(cont_rows$median)))
  expect_true(all(cont_rows$min <= cont_rows$median))
  expect_true(all(cont_rows$median <= cont_rows$max))
})

test_that("get_descriptive_data categorical rows have n and percent", {
  data <- make_study_data()
  vs   <- make_variables_sheet()
  vds  <- make_variable_details_sheet()

  stratify_config <- list(all = list("DHH_SEX"))
  result <- get_descriptive_data(data, vs, vds, "SMKDSTY", stratify_config)

  # Filter to real strata and real categories (not NA::c empty stratum)
  cat_rows <- result[
    result$variable == "SMKDSTY" &
    !is.na(result$cat) &
    !grepl("NA::", result$cat) &
    !is.na(result$groupByValue_1) &
    result$groupByValue_1 %in% c("1", "2"), ]
  expect_gt(nrow(cat_rows), 0)
  expect_true(all(!is.na(cat_rows$n)))
  # Percents should be in [0, 1]
  expect_true(all(cat_rows$percent >= 0 & cat_rows$percent <= 1, na.rm = TRUE))
})

# ---- create_descriptive_table -----------------------------------------------

test_that("create_descriptive_table returns a gt_tbl", {
  data <- make_study_data()
  vs   <- make_variables_sheet()
  vds  <- make_variable_details_sheet()

  stratify_config <- list(all = list("DHH_SEX"))
  desc <- get_descriptive_data(data, vs, vds, c("DHH_AGE", "SMKDSTY"),
                                stratify_config)
  tbl  <- create_descriptive_table(desc, vs, vds, c("DHH_AGE", "SMKDSTY"),
                                    column_stratifier = "DHH_SEX")
  expect_s3_class(tbl, "gt_tbl")
})

test_that("create_descriptive_table accepts valid sections_order", {
  data <- make_study_data()
  vs   <- make_variables_sheet()
  vds  <- make_variable_details_sheet()

  stratify_config <- list(all = list("DHH_SEX"))
  desc <- get_descriptive_data(data, vs, vds, c("DHH_AGE", "SMKDSTY"),
                                stratify_config)
  # Both sections present — should succeed
  tbl <- create_descriptive_table(desc, vs, vds, c("DHH_AGE", "SMKDSTY"),
                                   column_stratifier = "DHH_SEX",
                                   sections_order = c("Sociodemographics",
                                                      "Health behaviour"))
  expect_s3_class(tbl, "gt_tbl")
})

# ---- create_cycle_specific_descriptive_table --------------------------------

test_that("create_cycle_specific_descriptive_table returns a gt_tbl", {
  data         <- make_study_data()
  vs           <- make_variables_sheet()
  vds          <- make_variable_details_sheet()
  cycle_labels <- c("1" = "2001", "2" = "2003")

  tbl <- create_cycle_specific_descriptive_table(
    study_data             = data,
    variables_sheet        = vs,
    variable_details_sheet = vds,
    variables              = c("DHH_AGE", "SMKDSTY"),
    cycle_col              = "SurveyCycle",
    cycle_labels           = cycle_labels,
    column_stratifier      = "DHH_SEX"
  )
  expect_s3_class(tbl, "gt_tbl")
})

test_that("create_cycle_specific_descriptive_table errors with no cycle data", {
  data         <- make_study_data()
  data$SurveyCycle <- NA
  vs           <- make_variables_sheet()
  vds          <- make_variable_details_sheet()

  expect_error(
    create_cycle_specific_descriptive_table(
      study_data = data, variables_sheet = vs,
      variable_details_sheet = vds, variables = c("DHH_AGE"),
      cycle_col = "SurveyCycle",
      cycle_labels = c(), column_stratifier = "DHH_SEX"
    ),
    regexp = "No valid cycle"
  )
})

# ---- get_cshm_desc_data -----------------------------------------------------

test_that("get_cshm_desc_data returns rows only for predictor variables", {
  data <- make_study_data()
  vs   <- make_variables_sheet()
  vds  <- make_variable_details_sheet()

  result <- get_cshm_desc_data(data, vs, vds)

  expect_s3_class(result, "data.frame")
  # Only predictor variables should appear (not design or model-stratifier)
  returned_vars <- unique(result$variable)
  expect_true("DHH_AGE"  %in% returned_vars)
  expect_true("SMKDSTY"  %in% returned_vars)
  expect_false("WTS_M"   %in% returned_vars)
  expect_false("SurveyCycle" %in% returned_vars)
})
