context("Smoking Initiation Processing")

test_that("process_smoking_initiation works correctly", {
  # Create test data
  test_data <- data.frame(
    ont_id = c(1001, 1002, 1003, 1004, 1005, 1006),
    sex = c("M", "F", "M", "F", "M", "M"),
    SMK_01A = c(1, 2, 1, 1, 1, 1),  # 1=Yes, 2=No to 100+ cigarettes
    agefirst = c(16, NA, 12, 21, 7, 18),
    cchsbdate = as.Date(c("2001-06-15", "2001-07-20", "2001-08-10", 
                        "2001-09-05", "2001-10-25", "1918-05-10")),
    weighting = c(150, 200, 175, 225, 190, 210)
  )
  
  # Process the test data for males
  result_m <- process_smoking_initiation(test_data, sex = "M")
  
  # Process the test data for females
  result_f <- process_smoking_initiation(test_data, sex = "F")
  
  # Tests for male results
  expect_equal(nrow(result_m), 2)  # Only 2 valid male smokers (ID 1001, 1003)
  expect_equal(result_m$ont_id, c(1003, 1001))  # Sorted by age, then period
  
  # ID 1005 (male) should be excluded due to age < 8
  expect_false(1005 %in% result_m$ont_id)
  
  # ID 1006 (male) should be excluded due to cohort < 1920
  expect_false(1006 %in% result_m$ont_id)
  
  # Tests for female results
  expect_equal(nrow(result_f), 1)  # Only 1 valid female smoker (ID 1004)
  expect_equal(result_f$ont_id, 1004)
  
  # ID 1002 (female) should be excluded as non-smoker (SMK_01A=2)
  expect_false(1002 %in% result_f$ont_id)
  
  # Check all required columns are present
  expected_cols <- c("ont_id", "weighting", "age", "cohort", "period", "init")
  expect_true(all(expected_cols %in% colnames(result_m)))
  expect_true(all(expected_cols %in% colnames(result_f)))
  
  # Check that all included respondents have init=1
  expect_true(all(result_m$init == 1))
  expect_true(all(result_f$init == 1))
  
  # Check that period = cohort + age
  expect_equal(result_m$period, result_m$cohort + result_m$age)
  expect_equal(result_f$period, result_f$cohort + result_f$age)
})

test_that("process_smoking_initiation handles invalid inputs", {
  # Test with non-data frame
  expect_error(process_smoking_initiation("not a data frame", "M"))
  
  # Test with invalid sex
  test_data <- create_smoking_test_data(5)
  expect_error(process_smoking_initiation(test_data, "X"))
  
  # Test with missing required variables
  incomplete_data <- test_data[, -which(names(test_data) == "SMK_01A")]
  expect_error(process_smoking_initiation(incomplete_data, "M"))
})

test_that("create_smoking_test_data creates valid test data", {
  # Generate test data
  test_data <- create_smoking_test_data(100, seed = 456)
  
  # Check structure
  expect_s3_class(test_data, "data.frame")
  expect_equal(nrow(test_data), 100)
  
  # Check column names
  expected_cols <- c("ont_id", "sex", "SMK_01A", "agefirst", "cchsbdate", "weighting")
  expect_true(all(expected_cols %in% colnames(test_data)))
  
  # Check data types
  expect_type(test_data$ont_id, "double")
  expect_type(test_data$sex, "character")
  expect_type(test_data$SMK_01A, "double")
  expect_type(test_data$weighting, "double")
  expect_s3_class(test_data$cchsbdate, "Date")
  
  # Check ranges
  expect_true(all(test_data$sex %in% c("M", "F")))
  expect_true(all(test_data$SMK_01A %in% c(1, 2)))
  
  # Non-smokers should have NA for agefirst
  non_smokers <- test_data$SMK_01A == 2
  expect_true(all(is.na(test_data$agefirst[non_smokers])))
  
  # Smokers should have ages between 8 and 30
  smokers <- test_data$SMK_01A == 1
  expect_true(all(test_data$agefirst[smokers] >= 8 & test_data$agefirst[smokers] <= 30))
})

test_that("process_smoking_initiation produces correct period calculation", {
  # Create simple test data with known values
  test_data <- data.frame(
    ont_id = 1:3,
    sex = rep("M", 3),
    SMK_01A = c(1, 1, 1),
    agefirst = c(15, 20, 25),
    cchsbdate = as.Date(c("2000-01-01", "2000-01-01", "2000-01-01")),
    weighting = c(100, 100, 100)
  )
  
  result <- process_smoking_initiation(test_data, "M")
  
  # For all these respondents, cohort should be 2000
  expect_equal(unique(result$cohort), 2000)
  
  # Check that period is calculated correctly
  expected_periods <- c(2015, 2020, 2025)  # 2000 + ages 15, 20, 25
  expect_equal(result$period, expected_periods)
})