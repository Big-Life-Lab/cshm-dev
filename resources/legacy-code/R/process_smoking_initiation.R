#' Process Smoking Initiation Data for Age-Period-Cohort Modeling
#' 
#' @title Process Smoking Initiation Data
#' 
#' @description 
#' This function processes data for smoking initiation based on the Canadian Community Health Survey (CCHS)
#' data that has been harmonized with the cchsflow package. It identifies individuals who have initiated 
#' smoking and creates a dataset with key variables needed for age-period-cohort (APC) modeling of smoking 
#' initiation rates.
#' 
#' This function implements part of the Canadian Smoking Histories Model in R, specifically 
#' replicating the data preparation step from line 120 in the original SAS code (Modeling2013.sas).
#' 
#' @param dataset A data frame containing harmonized CCHS smoking history data (from cchsflow).
#'   The dataset must contain the following variables:
#'   \itemize{
#'     \item \code{sex} - Sex of the respondent ("M" or "F")
#'     \item \code{SMK_01A} - Whether respondent has smoked 100+ cigarettes in lifetime (1=Yes, 2=No)
#'     \item \code{agefirst} - Age when respondent first smoked a whole cigarette
#'     \item \code{cchsbdate} - CCHS survey date as a Date object
#'   }
#' @param sex Character string indicating sex ("M" or "F") for filtering the data
#' 
#' @return A data frame with the variables needed for smoking initiation APC modeling:
#'   \describe{
#'     \item{ont_id}{Ontario resident identifier - unique ID for each respondent}
#'     \item{weighting}{Survey weighting factor - sampling weight assigned to each respondent}
#'     \item{age}{Age of smoking initiation - age when respondent first smoked}
#'     \item{cohort}{Birth cohort (calendar year) - year of birth}
#'     \item{period}{Period (calendar year) when smoking was initiated - calculated as cohort + age}
#'     \item{init}{Binary indicator of smoking initiation (1=initiated smoking)}
#'   }
#'   
#'   The returned data frame contains ONLY respondents who have initiated smoking (smoked at least 
#'   100 cigarettes in their lifetime) and were at least 8 years old when they started. Never-smokers 
#'   are excluded from the final dataset. Only birth cohorts from 1920 onwards are included.
#'   
#'   This dataset serves as the numerator for calculating age-period-cohort rates of smoking initiation.
#' 
#' @details 
#' This function replicates the SAS code used in the Canadian History Smoking Generator Model.
#' It filters data by sex, processes the harmonized smoking status variables, and creates a dataset 
#' that serves as the numerator for age-period-cohort rates in smoking initiation modeling.
#'
#' The function uses the following workflow:
#' 1. Filters dataset by sex
#' 2. Identifies never-smokers (who have not smoked 100+ cigarettes) 
#' 3. Sets initialization status (init=1 for smokers, init=0 for never-smokers)
#' 4. Calculates smoking initiation date
#' 5. Filters to include only those born in 1920 or later
#' 6. Creates a subset containing only those who initiated smoking
#' 7. Applies age filter (age >= 8)
#' 8. Calculates period (year of initiation) as cohort + age
#' 9. Returns final dataset sorted by age, period, and cohort
#'
#' The function uses harmonized variable names from the cchsflow package which standardizes variables
#' across different CCHS cycles.
#' 
#' For age-period-cohort modeling, this dataset should be paired with a denominator dataset that includes
#' the entire population at risk for smoking initiation at each age, period, and cohort combination.
#' 
#' @examples
#' \dontrun{
#' # Assuming 'cchs_data' is your harmonized CCHS dataset from cchsflow
#' inits_male <- process_smoking_initiation(cchs_data, sex = "M")
#' inits_female <- process_smoking_initiation(cchs_data, sex = "F")
#' 
#' # Check the structure of the output
#' str(inits_male)
#' 
#' # View the first few rows
#' head(inits_male)
#' 
#' # Get summary statistics
#' summary(inits_male)
#' }
#' 
#' @section Test Data:
#' Here's a small example dataset to test the function:
#' 
#' ```r
#' # Create test data
#' test_data <- data.frame(
#'   ont_id = c(1001, 1002, 1003, 1004, 1005),
#'   sex = c("M", "F", "M", "F", "M"),
#'   SMK_01A = c(1, 2, 1, 1, 1),  # 1=Yes, 2=No to 100+ cigarettes
#'   agefirst = c(16, NA, 12, 21, 7),
#'   cchsbdate = as.Date(c("2001-06-15", "2001-07-20", "2001-08-10", 
#'                         "2001-09-05", "2001-10-25")),
#'   weighting = c(150, 200, 175, 225, 190)
#' )
#' 
#' # Process the test data for males
#' result <- process_smoking_initiation(test_data, sex = "M")
#' print(result)
#' # Expected output: A dataset with 2 rows (ont_id 1001 and 1003)
#' # ont_id 1005 is excluded because age < 8
#' ```
#' 
#' @seealso 
#' \code{\link[cchsflow]{cchsflow}} for information on the CCHS data harmonization
#' 
#' @references 
#' Manuel, D.G. et al. (2013) "Canadian Smoking Histories Model"
#' 
#' @export
process_smoking_initiation <- function(dataset, sex = "M") {
  # Validate inputs
  if (!is.data.frame(dataset)) {
    stop("dataset must be a data frame")
  }
  
  if (!(sex %in% c("M", "F"))) {
    stop("sex must be either 'M' or 'F'")
  }
  
  required_vars <- c("sex", "SMK_01A", "agefirst", "cchsbdate", "ont_id", "weighting")
  missing_vars <- required_vars[!required_vars %in% names(dataset)]
  if (length(missing_vars) > 0) {
    stop("Missing required variables in dataset: ", paste(missing_vars, collapse = ", "))
  }
  
  # Filter dataset by sex
  filtered_data <- dataset[dataset$sex == sex, ]
  
  # Process smoking initiation data
  # Set initialization variables for non-smokers (never smoked 100+ cigarettes)
  # Using harmonized variable SMK_01A: "In lifetime, smoked 100 or more cigarettes"
  # Value 1 = "Yes", Value 2 = "No"
  filtered_data$agefirst <- ifelse(
    filtered_data$SMK_01A == 2,  # Value 2 = "No" to smoking 100+ cigarettes
    101, filtered_data$agefirst   # 101 is used as a flag for never-smokers
  )
  
  # Define initialization status
  # init = 1: Has initiated smoking (smoked 100+ cigarettes)
  # init = 0: Never initiated smoking (has not smoked 100+ cigarettes)
  filtered_data$init <- ifelse(filtered_data$agefirst == 101, 0, 1)
  
  # Create initialization date (using randomization within the year as in original SAS code)
  # This adds random days within the year of reported age to avoid artificial clumping
  filtered_data$init_date <- as.Date(
    ifelse(
      filtered_data$agefirst != 101,
      filtered_data$cchsbdate + 
        filtered_data$agefirst * 365 + 
        floor(runif(nrow(filtered_data)) * 365),
      NA
    ),
    origin = "1970-01-01"
  )
  
  # Determine cohort (year of birth) from survey date
  filtered_data$cohort <- as.numeric(format(filtered_data$cchsbdate, "%Y"))
  
  # Filter for cohorts from 1920 onwards (as in original SAS code)
  filtered_data <- subset(filtered_data, cohort >= 1920)
  
  # For those who initiated smoking, extract relevant variables
  # This step EXCLUDES never-smokers (init=0) from the final dataset
  inits <- subset(filtered_data, init == 1)
  
  # Set age to age of first cigarette
  # In the harmonized dataset, this corresponds to SMKG01C_cont
  inits$age <- inits$agefirst
  
  # Filter for ages 8 and above (as in original SAS code)
  # This removes unlikely very early smoking initiation ages
  inits <- subset(inits, age >= 8)
  
  # Calculate period (calendar year when smoking was initiated)
  # Period = birth cohort + age at initiation
  inits$period <- inits$cohort + inits$age
  
  # Select only the required variables for APC modeling
  result <- inits[, c("ont_id", "weighting", "age", "cohort", "period", "init")]
  
  # Sort the data by age, period, cohort (as in original SAS code)
  result <- result[order(result$age, result$period, result$cohort), ]
  
  return(result)
}

#' Create Test Data for Smoking Initiation Processing
#'
#' @title Create Test CCHS Smoking Data
#'
#' @description
#' Creates a sample dataset mimicking harmonized CCHS data for testing the 
#' smoking initiation processing function.
#'
#' @param n Number of observations to generate
#' @param seed Random seed for reproducibility
#'
#' @return A data frame with simulated CCHS data
#'
#' @examples
#' test_data <- create_smoking_test_data(10)
#' head(test_data)
#'
#' @export
create_smoking_test_data <- function(n = 5, seed = 123) {
  set.seed(seed)
  
  # Generate random IDs
  ids <- 1000 + 1:n
  
  # Generate random sex
  sexes <- sample(c("M", "F"), n, replace = TRUE)
  
  # Generate smoking status (1=Yes, 2=No to 100+ cigarettes)
  # About 70% smokers, 30% non-smokers
  smk_status <- sample(c(1, 2), n, replace = TRUE, prob = c(0.7, 0.3))
  
  # Generate age of first cigarette (NA for non-smokers)
  age_first <- numeric(n)
  for (i in 1:n) {
    if (smk_status[i] == 1) {
      # Smokers get age between 8 and 30, with higher probability for teenage years
      age_first[i] <- sample(c(8:14, 15:19, 20:30), 1, 
                            prob = c(rep(0.05, 7), rep(0.1, 5), rep(0.03, 11)))
    } else {
      # Non-smokers get NA
      age_first[i] <- NA
    }
  }
  
  # Generate survey dates between 2000 and 2018
  survey_years <- sample(2000:2018, n, replace = TRUE)
  survey_months <- sample(1:12, n, replace = TRUE)
  survey_days <- sample(1:28, n, replace = TRUE)
  survey_dates <- as.Date(paste(survey_years, survey_months, survey_days, sep = "-"))
  
  # Generate survey weights between 50 and 300
  weights <- round(runif(n, 50, 300), 1)
  
  # Create the data frame
  test_data <- data.frame(
    ont_id = ids,
    sex = sexes,
    SMK_01A = smk_status,
    agefirst = age_first,
    cchsbdate = survey_dates,
    weighting = weights
  )
  
  return(test_data)
}