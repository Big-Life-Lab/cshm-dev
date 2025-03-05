testthat::context("Testing map_variable_data")

testthat::test_that("The function works with categorical variables", {
  data <- data.frame(
    a = c("1", "2"),
    b = c("1", "2")
  )
  variable <- "a"
  variable_details_sheet <- data.frame(
    variable = c("a", "a"),
    typeEnd = c("cat", "cat"),
    recEnd = c("1", "2")
  )
  
  expected_results <- list()
  expected_results[[1]] <- list(
    data = data[data$a == 1, ],
    category = "1"
  )
  expected_results[[2]] <- list(
    data = data[data$a == 2, ],
    category = "2"
  )
  
  actual_results <- list()
  map_variable_data(
    variable,
    data,
    variable_details_sheet, 
    function(data, category) {
      actual_results[[length(actual_results) + 1]] <<- list(
        data = data, 
        category = category
      )
    }
  )
  
  testthat::expect_equal(actual_results, expected_results)
})