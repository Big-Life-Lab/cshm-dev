#' @title Time since quit smoking
#' 
#' @description This function creates a derived variable (time_quit_smoking_der)
#'  that calculates the approximate time a former smoker has quit smoking based
#'  on various CCHS smoking variables. This variable is for CCHS respondents in
#'  CCHS surveys 2003-2014.
#'  
#' @param SMK_09A_B number of years since quitting smoking. Variable asked to
#'  former daily smokers who quit <3 years ago.
#' 
#' @param SMKG09C number of years since quitting smoking. Variable asked to
#'  former daily smokers who quit >=3 years ago.
#'  
#' @return value for time since quit smoking in time_quit_smoking_der.
#' 
#' @examples 
#' # Using time_quit_smoking_fun() to create pack-years values across CCHS 
#' # cycles.
#' # time_quit_smoking_fun() is specified in variable_details.csv along with the
#' # CCHS variables and cycles included.
#'
#' # To transform time_quit_smoking across cycles, use rec_with_table() for each
#' # CCHS cycle and specify time_quit_smoking, along with each smoking variable.
#' # Then by using merge_rec_data(), you can combine time_quit_smoking across
#' # cycles.
#' 
#' library(cchsflow)
#' 
#' time_quit2009_2010 <- rec_with_table(
#'   cchs2009_2010_p, c(
#'     "SMK_09A_B", "SMKG09C", "time_quit_smoking"
#'   )
#' )
#'
#' head(time_quit2009_2010)
#'
#' time_quit2011_2012 <- rec_with_table(
#'   cchs2011_2012_p, c(
#'     "SMK_09A_B", "SMKG09C", "time_quit_smoking"
#'   )
#' )
#'
#' tail(time_quit2011_2012)
#'
#' combined_time_quit <- suppressWarnings(merge_rec_data(time_quit2009_2010,
#'  time_quit2011_2012))
#'
#' head(combined_time_quit)
#' tail(combined_time_quit)
#' 
#' # Using time_quit_smoking_fun() to generate a pack-years value with user 
#' # inputted number of years since quitting smoking for both former daily 
#' # smokers who quit <3 and >=3 years ago. time_quit_smoking_fun() can also 
#' # generate a pack-years value if you input a value for both number of years
#' # since quitting smoking. Let's say you quit smoking <3 years ago and stopped
#' # smoking daily 2 to <3 years ago and it's been 3 to 5 years since you stopped 
#' # smoking daily, your time since quitting smoking can be calculated as follows:
#' 
#' library(cchsflow)
#' time_quit_smoking <- time_quit_smoking_fun(3,1)
#' print(time_quit_smoking)
#' 
#' # Additional examples of time since quitting smoking calculations produced 
#' # using time_quit_smoking_fun() can be found below. Multiple instances exist 
#' # where an NA output may be produced such as a negative entry and or 
#' # missing SMKG09C values. 
#' 
#' library(cchsflow)
#' SMK_09A_B <- c(3, 4, 1, 4)
#' SMKG09C <- c(1, 2, NA, -2)
#' time_quit_smoking_data <- data.frame(SMK_09A_B, SMKG09C)
#' print(time_quit_smoking_data)
#' time_quit_smoking_data$time_quit_smoking <- 
#' time_quit_smoking_fun(time_quit_smoking_data$SMK_09A_B, time_quit_smoking_data$SMKG09C) 
#' print(time_quit_smoking_data)
#' @export

time_quit_smoking_fun <- function(SMK_09A_B, SMKG09C) {
  SMKG09C_cont <-
    if_else2(
      SMKG09C == 1, 4,
      if_else2(
        SMKG09C == 2, 8,
        if_else2(SMKG09C == 3, 12,
                 if_else2(SMKG09C == "NA(a)", tagged_na("a"), tagged_na("b")
                 )
        )
      )
    )
  tsq_ds <-
    if_else2(
      SMK_09A_B == 1, 0.5,
      if_else2(
        SMK_09A_B == 2, 1.5,
        if_else2(
          SMK_09A_B == 3, 2.5,
          if_else2(SMK_09A_B == 4, SMKG09C_cont,
                   if_else2(SMK_09A_B == "NA(a)", tagged_na("a"), tagged_na("b")
                   )
          )
        )
      )
    )
  return(tsq_ds)
}

#' # Updating the original function time_quit_smoking_fun_A() generates a 
#' # pack-years value with user inputted number of years since quitting smoking
#' # for both former daily smokers who quit <3 and >=3 years ago. This function
#' # version utilizes a continuous version of SMKG09C that is available within
#' # the shared files. time_quit_smoking_fun_A() can also generate a pack-years 
#' # value if you input a value for both number of years since quitting smoking.
#' # Let's say you quit smoking <3 years ago and stopped smoking daily 2 to <3 
#' # years ago and it's been 2 years since you stopped smoking daily, your 
#' # time since quitting smoking can be calculated as follows:
#' 
#' library(cchsflow)
#' time_quit_smoking <- time_quit_smoking_fun_A(3,2)
#' print(time_quit_smoking)
#' 
#' # Additional examples of time since quitting smoking calculations produced 
#' # using time_quit_smoking_fun() can be found below. Multiple instances exist 
#' # where an NA output may be produced such as a negative entry and or 
#' # missing SMKG09C values. 
#' 
#' library(cchsflow)
#' SMK_09A_B <- c(3, 4, 4, 4, 4, 4)
#' SMKG09C_cont <- c(1, 62, NA, -2, 2, 85)
#' time_quit_smoking_data <- data.frame(SMK_09A_B, SMKG09C_cont)
#' print(time_quit_smoking_data)
#' time_quit_smoking_data$time_quit_smoking <- 
#' time_quit_smoking_fun_A(time_quit_smoking_data$SMK_09A_B, time_quit_smoking_data$SMKG09C) 
#' print(time_quit_smoking_data)
#' @export

time_quit_smoking_fun_A <- function(SMK_09A_B, SMKG09C_cont, 
                                    min_SMKG09C_cont=3, max_SMKG09C_cont=82) {
  tsq_ds <-
    if_else2(
      SMK_09A_B == 1, 0.5,
      if_else2(
        SMK_09A_B == 2, 1.5,
        if_else2(
          SMK_09A_B == 3, 2.5,
          #if stopped smoking 3 or more years than use SMKG09C_cont value (only
          #for positive values falling within given min and max values) 
          if_else2(SMK_09A_B == 4 & SMKG09C_cont > 0 & 
                     SMKG09C_cont > min_SMKG09C_cont & 
                     SMKG09C_cont < max_SMKG09C_cont, SMKG09C_cont,
                   if_else2(SMK_09A_B == "NA(a)", tagged_na("a"), tagged_na("b")
                   )
          )
        )
      )
    )
  return(tsq_ds)
}

#' @title Simple smoking status
#'
#' @description This function creates a derived smoking variable (smoke_simple)  
#'  with four categories: 
#'  
#' \itemize{
#'   \item non-smoker (never smoked)
#'   \item current smoker (daily and occasional?)
#'   \item former daily smoker quit =<5 years or former occasional smoker 
#'   \item former daily smoker quit >5 years
#'  }
#'
#' @param SMKDSTY_cat5 derived variable that classifies an individual's smoking
#'  status. This variable captures cycles 2001-2018.
#'
#' @param time_quit_smoking derived variable that calculates the approximate
#'  time a former smoker has quit smoking. 
#'  See \code{\link{time_quit_smoking_fun}} for documentation on how variable
#'  was derived.
#'
#' @examples
#' # Using the 'smoke_simple_fun' function to create the derived smoking   
#' # variable across CCHS cycles.
#' # smoke_simple_fun() is specified in the variable_details.csv
#'
#' # To create a harmonized smoke_simple variable across CCHS cycles, use 
#' # rec_with_table() for each CCHS cycle and specify smoke_simple_fun and 
#' # the required base variables. Since time_quit_smoking_der is also a derived 
#' # variable, you will have to specify the variables that are derived from it.
#' # Using merge_rec_data(), you can combine smoke_simple across cycles.
#'
#' library(cchsflow)
#'
#' smoke_simple2009_2010 <- rec_with_table(
#'   cchs2009_2010_p, c(
#'     "SMKDSTY", "SMK_09A_B", "SMKG09C", "time_quit_smoking",
#'     "smoke_simple"
#'   )
#' )
#'
#' head(smoke_simple2009_2010)
#'
#' smoke_simple2011_2012 <- rec_with_table(
#'   cchs2011_2012_p,c(
#'    "SMKDSTY", "SMK_09A_B", "SMKG09C", "time_quit_smoking",
#'    "smoke_simple"
#'   )
#' )
#'
#' tail(smoke_simple2011_2012)
#'
#' combined_smoke_simple <- 
#' suppressWarnings(merge_rec_data(smoke_simple2009_2010,smoke_simple2011_2012))
#'
#' head(combined_smoke_simple)
#' tail(combined_smoke_simple)
#' 
#' # Using smoke_simple_fun() to generate a derived smoking variable across CCHS
#' # cycles with user inputted smoking status and approximate time a former smoker 
#' # has quit smoking. smoke_simple_fun() can also generate derived smoking variable 
#' # value if you input a value for both number of smoking status and approximate
#' # time a former smoker has quit smoking. Let's say your smoking status is former 
#' # daily (3) and your approximate time of quit smoking is 6 to 10 years (2), 
#' # your derived smoking variable can be calculated as follows:
#' 
#' library(cchsflow)
#' time_quit_smoking <- time_quit_smoking_fun(3,2)
#' print(time_quit_smoking)
#' 
#' smoke_simple <- smoke_simple_fun(3,3) 
#' print(smoke_simple)
#' 
#' # Additional examples of derived smoking variable using smoke_simple_fun() can
#' # be found below. Multiple instances exist where an NA output may be produced 
#' # such as a negative entry or missing SMKG09C values. 
#' 
#' library(cchsflow)
#' library(cchsflow)
#' SMKDSTY_cat5 <- c(1, 3, 2, 3)
#' SMKG09C <- c(1, 2, 5, NA)
#' smoke_simple_data <- data.frame(SMKDSTY_cat5, SMKG09C)
#' print(smoke_simple_data)
#' smoke_simple_data$smoke_simple <- 
#' smoke_simple_fun(smoke_simple_data$SMKDSTY_cat5, smoke_simple_data$SMKG09C) 
#' print(smoke_simple_data)
#' @export
smoke_simple_fun <-
  function(SMKDSTY_cat5, time_quit_smoking) {
    
    # Nested function: current smoker status
    derive_current_smoker <- function(SMKDSTY_cat5) {
      smoker <-
        ifelse(SMKDSTY_cat5 %in% c(1, 2), 1,
               ifelse(SMKDSTY_cat5 %in% c(3, 4, 5), 0,
                      ifelse(SMKDSTY_cat5 == "NA(a)", "NA(a)", "NA(b)")))
      return(smoker)
    }
    smoker <- derive_current_smoker(SMKDSTY_cat5)
    
    # Nested function: ever smoker status
    derive_ever_smoker <- function(SMKDSTY_cat5) {
      eversmoker <-
        ifelse(SMKDSTY_cat5 %in% c(1, 2, 3, 4), 1,
               ifelse(SMKDSTY_cat5 == 5, 0,
                      ifelse(SMKDSTY_cat5 == "NA(a)", "NA(a)", "NA(b)")))
      return(eversmoker)
    }
    eversmoker <- derive_ever_smoker(SMKDSTY_cat5)
    
    # smoke_simple 0 = non-smoker
    smoke_simple <- 
      ifelse(smoker == 0 & eversmoker == 0, 0,
      # smoke_simple 1 = current smoker
        ifelse(smoker == 1 & eversmoker == 1, 1,
      # smoke_simple 2 = former daily smoker quit =<5 years or former occasional
      # smoker
          ifelse(smoker == 0 & eversmoker == 1 & time_quit_smoking <= 5 |
                   SMKDSTY_cat5 == 4, 2,
      # smoke_simple 3 = former daily smoker quit > 5 years
            ifelse(smoker == 0 & eversmoker == 1 & time_quit_smoking > 5,
                   3,
                   ifelse(smoker == "NA(a)" & eversmoker == "NA(a)" &
                            time_quit_smoking == "NA(a)", "NA(a)", "NA(b)")))))
    return(smoke_simple)
  }

#' # Updating the original function smoke_simple_fun_A() generates a 
#' # derived smoking variable across CCHS cycles with user inputted smoking
#' # status and approximate time a former smoker has quit smoking. This function
#' # version utilizes a continuous version of SMKG09C that is available within
#' # the shared files. smoke_simple_fun() can also generate derived smoking variable 
#' # value if you input a value for both number of smoking status and approximate
#' # time a former smoker has quit smoking. Let's say your smoking status is former 
#' # daily (3) and your approximate time of quit smoking is 6 to 10 years (2), 
#' # your derived smoking variable can be calculated as follows:
#' 
#' library(cchsflow)
#' time_quit_smoking <- time_quit_smoking_fun_A(4,20)
#' print(time_quit_smoking)
#' 
#' smoke_simple <- smoke_simple_fun_A(3,20) 
#' print(smoke_simple)
#' 
#' # Additional examples of time since quitting smoking calculations produced 
#' # using time_quit_smoking_fun() can be found below. Multiple instances exist 
#' # where an NA output may be produced such as a negative entry and or 
#' # missing SMKG09C values. 
#' 
#' library(cchsflow)
#' SMKDSTY_cat5 <- c(3, 2, 3, 3)
#' SMKG09C <- c(2, 1, NA, -2)
#' smoke_simple_data <- data.frame(SMKDSTY_cat5, SMKG09C)
#' print(smoke_simple_data)
#' smoke_simple_data$smoke_simple <- 
#' smoke_simple_fun(smoke_simple_data$SMKDSTY_cat5, smoke_simple_data$SMKG09C) 
#' print(smoke_simple_data)
#' @export
smoke_simple_fun_A <-
  function(SMKDSTY_cat5, time_quit_smoking, 
           min_time_quit_smoking=0.5, max_time_quit_smoking=82) {
    
    # Nested function: current smoker status
    derive_current_smoker <- function(SMKDSTY_cat5) {
      smoker <-
        ifelse(SMKDSTY_cat5 %in% c(1, 2), 1,
               ifelse(SMKDSTY_cat5 %in% c(3, 4, 5), 0,
                      ifelse(SMKDSTY_cat5 == "NA(a)", "NA(a)", "NA(b)")))
      return(smoker)
    }
    smoker <- derive_current_smoker(SMKDSTY_cat5)
    
    # Nested function: ever smoker status
    derive_ever_smoker <- function(SMKDSTY_cat5) {
      eversmoker <-
        ifelse(SMKDSTY_cat5 %in% c(1, 2, 3, 4), 1,
               ifelse(SMKDSTY_cat5 == 5, 0,
                      ifelse(SMKDSTY_cat5 == "NA(a)", "NA(a)", "NA(b)")))
      return(eversmoker)
    }
    eversmoker <- derive_ever_smoker(SMKDSTY_cat5)
    
    # smoke_simple 0 = non-smoker
    smoke_simple <- 
      ifelse(smoker == 0 & eversmoker == 0, 0,
             # smoke_simple 1 = current smoker
             ifelse(smoker == 1 & eversmoker == 1, 1,
                    # smoke_simple 2 = former daily smoker quit =<5 years or former occasional
                    # smoker
                    ifelse(smoker == 0 & eversmoker == 1 & time_quit_smoking <= 5 &
                             time_quit_smoking >= min_time_quit_smoking &
                             time_quit_smoking <= max_time_quit_smoking |
                             SMKDSTY_cat5 == 4, 2,                             
                    # smoke_simple 3 = former daily smoker quit > 5 years
                    ifelse(smoker == 0 & eversmoker == 1 & time_quit_smoking > 5 &
                             time_quit_smoking >= min_time_quit_smoking &
                             time_quit_smoking <= max_time_quit_smoking,
                           3,
                           ifelse(smoker == "NA(a)" & eversmoker == "NA(a)" &
                                    time_quit_smoking == "NA(a)", "NA(a)", "NA(b)")))))
return(smoke_simple)
  }

#' @title Smoking pack-years
#'
#' @description This function creates a derived variable (pack_years_der) that
#'  measures an individual's smoking pack-years based on various CCHS smoking
#'  variables. This is a popular variable used by researchers to quantify
#'  lifetime exposure to cigarette use.
#'
#' @details pack-years is calculated by multiplying the number of cigarette
#'  packs per day (20 cigarettes per pack) by the number of years. Example 1:
#'  a respondent who is a current smoker who smokes 1 package of cigarettes for
#'  the last 10 years has smoked 10 pack-years. Pack-years is also calculated
#'  for former smokers. Example 2: a respondent who started smoking at age
#'  20 years and smoked half a pack of cigarettes until age 40 years smoked for
#'  10 pack-years.
#'
#' @param SMKDSTY_A variable used in CCHS cycles 2001-2014 that classifies an 
#' individual's smoking status.
#'
#' @param DHHGAGE_cont continuous age variable.
#'
#' @param time_quit_smoking derived variable that calculates the approximate
#'  time a former smoker has quit smoking. 
#'  See \code{\link{time_quit_smoking_fun}} for documentation on how variable
#'  was derived
#'
#' @param SMKG203_cont age started smoking daily. Variable asked to daily
#'  smokers.
#'
#' @param SMKG207_cont age started smoking daily. Variable asked to former
#'  daily smokers.
#'
#' @param SMK_204 number of cigarettes smoked per day. Variable asked to
#'  daily smokers.
#'
#' @param SMK_05B number of cigarettes smoked per day. Variable asked to
#'  occasional smokers
#'
#' @param SMK_208 number of cigarettes smoked per day. Variable asked to former
#'  daily smokers
#'
#' @param SMK_05C number of days smoked at least one cigarette
#'
#' @param SMK_01A smoked 100 cigarettes in lifetime (y/n)
#'
#' @param SMKG01C_cont age smoked first cigarette
#'
#' @return value for smoking pack-years in the pack_years_der variable
#'
#' @examples
#' # Using pack_years_fun() to create pack-years values across CCHS cycles
#' # pack_years_fun() is specified in variable_details.csv along with the CCHS
#' # variables and cycles included.
#'
#' # To transform pack_years_der across cycles, use rec_with_table() for each
#' # CCHS cycle and specify pack_years_der, along with each smoking variable.
#' # Since time_quit_smoking_der is also a derived 
#' # variable, you will have to specify the variables that are derived from it.
#' # Then by using merge_rec_data(), you can combine pack_years_der across
#' # cycles
#'
#' library(cchsflow)
#'
#' pack_years2009_2010 <- rec_with_table(
#'   cchs2009_2010_p, c(
#'     "SMKDSTY_A", "DHHGAGE_cont", "SMK_09A_B", "SMKG09C", "time_quit_smoking",
#'     "SMKG203_cont", "SMKG207_cont", "SMK_204", "SMK_05B", "SMK_208",
#'     "SMK_05C", "SMK_01A", "SMKG01C_cont", "pack_years_der"
#'   )
#' )
#'
#' head(pack_years2009_2010)
#'
#' pack_years2011_2012 <- rec_with_table(
#'   cchs2011_2012_p,c(
#'     "SMKDSTY_A", "DHHGAGE_cont", "SMK_09A_B", "SMKG09C", "time_quit_smoking",
#'     "SMKG203_cont", "SMKG207_cont", "SMK_204", "SMK_05B", "SMK_208",
#'     "SMK_05C", "SMK_01A", "SMKG01C_cont", "pack_years_der"
#'   )
#' )
#'
#' tail(pack_years2011_2012)
#'
#' combined_pack_years <- suppressWarnings(merge_rec_data(pack_years2009_2010,
#'  pack_years2011_2012))
#'
#' head(combined_pack_years)
#' tail(combined_pack_years)
#' @export
pack_years_fun <-
  function(SMKDSTY_A, DHHGAGE_cont, time_quit_smoking, SMKG203_cont,
           SMKG207_cont, SMK_204, SMK_05B,
           SMK_208, SMK_05C, SMKG01C_cont, SMK_01A) {
    # Age verification
    if (is.na(DHHGAGE_cont)) {
      return(tagged_na("b"))
    } else if (DHHGAGE_cont < 0) {
      return(tagged_na("b"))
    }

    # PackYears for Daily Smoker
    pack_years <- 
      if_else2(
        SMKDSTY_A == 1, pmax(((DHHGAGE_cont - SMKG203_cont) *
                              (SMK_204 / 20)), 0.0137),
        # PackYears for Occasional Smoker (former daily)
        if_else2(
          SMKDSTY_A == 2, pmax(((DHHGAGE_cont - SMKG207_cont -
                                 time_quit_smoking) * (SMK_208 / 20)), 0.0137) +
            (pmax((SMK_05B * SMK_05C / 30), 1) *time_quit_smoking),
          # PackYears for Occasional Smoker (never daily)
          if_else2(
            SMKDSTY_A == 3, (pmax((SMK_05B * SMK_05C / 30), 1) / 20) *
              (DHHGAGE_cont - SMKG01C_cont),
            # PackYears for former daily smoker (non-smoker now)
            if_else2(
              SMKDSTY_A == 4, pmax(((DHHGAGE_cont - SMKG207_cont -
                                     time_quit_smoking) *
                                    (SMK_208 / 20)), 0.0137),
              # PackYears for former occasional smoker (non-smoker now) who
              # smoked at least 100 cigarettes lifetime
              if_else2(
                SMKDSTY_A == 5 & SMK_01A == 1, 0.0137,
                # PackYears for former occasional smoker (non-smoker now) who 
                # have not smoked at least 100 cigarettes lifetime
                if_else2(
                  SMKDSTY_A == 5 & SMK_01A == 2, 0.007,
                  # Non-smoker
                  if_else2(SMKDSTY_A == 6, 0,
                           # Account for NA(a)
                           if_else2(SMKDSTY_A == "NA(a)", tagged_na("a"),
                                    tagged_na("b"))
                  )
                )
              )
            )
          )
        )
      )
    return(pack_years)
  }

#' # Updating the original function pack_years_fun_A() generates pack-years values 
#' # across CCHS cycles. Updated pack_years_fun_A() incorporates minimum and maximum
#' # values of all inputted variables. Note that while minimum and maximum values are
#' # preset, they can be altered to researcher-specific values if needed. 
#'
#' # Additional examples of pack years calculations produced 
#' # using pack_years_fun_A() can be found below. Multiple instances exist 
#' # where an NA output may be produced such as a negative/missing entry or an 
#' # entry existing outside of the allowed variable minimum and maximum values. 
#' 
#' # Examples demonstrating output when preset min/max values are exceeded within data
#' SMKDSTY_A <- c(1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5)
#' DHHGAGE_cont <- c(50, 50, 10, 105, 50, 50, 50, 50, 50, 50,
#'                  50, 50, 50, 50, 50, 50, 50, 50, 50)
#' time_quit_smoking <- c(0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 1.5, 0, 85, 
#'                       1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5)
#' SMKG203_cont <- c(15, 15, 15, 15, 15, 3, 90, 15, 15, 
#'                  15, 15, 15, 15, 15, 15, 15,15, 15, 15)
#' SMKG207_cont <- c(NA, NA, NA, NA, NA, NA, NA, 35, 35, 
#'                  35, 35, 3, 86, 35, 35, 35, 35, 35, 35)
#' SMK_204 <- c(25, 25, 25, 25, 25, 25, 25, 25, 25, 
#'             25, 25, 25, 25, 25, 25, 25, 25, 25, 25)
#' SMK_05B <- c(NA, NA, NA, NA, NA, NA, NA, 10, 10, 
#'             10, 10, 10, 10, 10, 10, 10, 10, 10, 10)
#' SMK_208 <- c(NA, NA, NA, NA, NA, NA, NA, 10, 10, 
#'             10, 10, 10, 10, 10, 0, 150, 10, 10, 10)
#' SMK_05C <- c(12, 12, 12, 12, 12, 12, 12, 12, 12,
#'             12, 12, 12, 12, 12, 12, 12, 12, 12, 12)
#' SMKG01C_cont <- c(18, 18, 18, 18, 18, 18, 18, 18, 18, 
#'                  18, 18, 18, 18, 18, 18, 18, 18, 18, 18)
#' SMK_01A <- c(NA, NA, NA, NA, NA, NA, NA, NA, NA,
#'             NA, NA, NA, NA, NA, NA, NA, 1, 2, 3)
#'
#' pack_years_data <- data.frame(SMKDSTY_A, DHHGAGE_cont, time_quit_smoking, 
#'                              SMKG203_cont, SMKG207_cont, SMK_204, SMK_05B,
#'                              SMK_208, SMK_05C, SMKG01C_cont, SMK_01A)
#' print(pack_years_data)
#' pack_years_data$pack_years <- 
#' pack_years_fun_A(pack_years_data$SMKDSTY_A, 
#'               pack_years_data$DHHGAGE_cont, 
#'               pack_years_data$time_quit_smoking, 
#'               pack_years_data$SMKG203_cont,
#'               pack_years_data$SMKG207_cont, 
#'               pack_years_data$SMK_204, 
#'               pack_years_data$SMK_05B,
#'               pack_years_data$SMK_208, 
#'               pack_years_data$SMK_05C, 
#'               pack_years_data$SMKG01C_cont, 
#'               pack_years_data$SMK_01A)
#' print(pack_years_data)
#' 
#' # Examples demonstrating output when min/max values set by user are exceeded
#' SMKDSTY_A <- c(1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5)
#' DHHGAGE_cont <- c(50, 50, 10, 105, 50, 50, 50, 50, 50, 50,
#'                  50, 50, 50, 50, 50, 50, 50, 50, 50)
#' time_quit_smoking <- c(0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 1.5, 0, 85, 
#'                       1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5)
#' SMKG203_cont <- c(15, 15, 15, 15, 15, 3, 90, 15, 15, 
#'                  15, 15, 15, 15, 15, 15, 15,15, 15, 15)
#' SMKG207_cont <- c(NA, NA, NA, NA, NA, NA, NA, 35, 35, 
#'                  35, 35, 3, 86, 35, 35, 35, 35, 35, 35)
#' SMK_204 <- c(25, 25, 25, 25, 25, 25, 25, 25, 25, 
#'             25, 25, 25, 25, 25, 25, 25, 25, 25, 25)
#' SMK_05B <- c(NA, NA, NA, NA, NA, NA, NA, 10, 10, 
#'             10, 10, 10, 10, 10, 10, 10, 10, 10, 10)
#' SMK_208 <- c(NA, NA, NA, NA, NA, NA, NA, 10, 10, 
#'             10, 10, 10, 10, 10, 0, 150, 10, 10, 10)
#' SMK_05C <- c(12, 12, 12, 12, 12, 12, 12, 12, 12,
#'             12, 12, 12, 12, 12, 12, 12, 12, 12, 12)
#' SMKG01C_cont <- c(18, 18, 18, 18, 18, 18, 18, 18, 18, 
#'                  18, 18, 18, 18, 18, 18, 18, 18, 18, 18)
#' SMK_01A <- c(NA, NA, NA, NA, NA, NA, NA, NA, NA,
#'             NA, NA, NA, NA, NA, NA, NA, 1, 2, 3)
#'
#' pack_years_data <- data.frame(SMKDSTY_A, DHHGAGE_cont, time_quit_smoking, 
#'                              SMKG203_cont, SMKG207_cont, SMK_204, SMK_05B,
#'                              SMK_208, SMK_05C, SMKG01C_cont, SMK_01A,
#'                              min_DHHGAGE_cont = 11 , max_DHHGAGE_cont = 103,
#'                              min_time_quit_smoking = 1.0, max_time_quit_smoking = 84,
#'                              min_SMKG203_cont = 4, max_SMKG203_cont = 88,
#'                              min_SMKG207_cont = 4, max_SMKG207_cont = 85, 
#'                              min_SMK_204 = 0, max_SMK_204 = 100, min_SMK_05B = 0, max_SMK_05B = 100, 
#'                              min_SMK_208 = 0, max_SMK_208 = 100, min_SMK_05C = 0, max_SMK_05C = 31, 
#'                              min_SMKG01C_cont = 5, max_SMKG01C_cont = 80)
#' print(pack_years_data)
#' pack_years_data$pack_years <- 
#' pack_years_fun_A(pack_years_data$SMKDSTY_A, 
#'               pack_years_data$DHHGAGE_cont, 
#'               pack_years_data$time_quit_smoking, 
#'               pack_years_data$SMKG203_cont,
#'               pack_years_data$SMKG207_cont, 
#'               pack_years_data$SMK_204, 
#'               pack_years_data$SMK_05B,
#'               pack_years_data$SMK_208, 
#'               pack_years_data$SMK_05C, 
#'               pack_years_data$SMKG01C_cont, 
#'               pack_years_data$SMK_01A)
#' print(pack_years_data)
#' @export
pack_years_fun_A <-
  function(SMKDSTY_A, DHHGAGE_cont, time_quit_smoking, SMKG203_cont,
           SMKG207_cont, SMK_204, SMK_05B,
           SMK_208, SMK_05C, SMKG01C_cont, SMK_01A, 
           min_DHHGAGE_cont = 12 , max_DHHGAGE_cont = 102, 
           min_time_quit_smoking = 0.5, max_time_quit_smoking = 82, 
           min_SMKG203_cont = 5, max_SMKG203_cont = 84, 
           min_SMKG207_cont = 5, max_SMKG207_cont = 80, 
           min_SMK_204 = 1, max_SMK_204 = 99, min_SMK_05B = 1, max_SMK_05B = 99, 
           min_SMK_208 = 1, max_SMK_208 = 99, min_SMK_05C = 0, max_SMK_05C = 31, 
           min_SMKG01C_cont = 5, max_SMKG01C_cont = 80) {
    # Age verification
    DHHGAGE_cont<-
      if_else2(is.na(DHHGAGE_cont), tagged_na("b"), 
               if_else2(DHHGAGE_cont < 0, tagged_na("b"),
                        if_else2(DHHGAGE_cont < min_DHHGAGE_cont, tagged_na("b"), 
                                 if_else2(DHHGAGE_cont > max_DHHGAGE_cont, tagged_na("b"),DHHGAGE_cont))))
    
    # PackYears for Daily Smoker
    pack_years <- 
      if_else2(
        SMKDSTY_A == 1 & SMKG203_cont > min_SMKG203_cont & SMKG203_cont < max_SMKG203_cont 
        & SMK_204 > min_SMK_204 & SMK_204 < max_SMK_204, pmax(((DHHGAGE_cont - SMKG203_cont) *
                                                                 (SMK_204 / 20)), 0.0137),
        # PackYears for Occasional Smoker (former daily)
        if_else2(
          SMKDSTY_A == 2 & SMKG207_cont > min_SMKG207_cont & SMKG207_cont < max_SMKG207_cont
          & time_quit_smoking > min_time_quit_smoking & time_quit_smoking < max_time_quit_smoking
          & SMK_05B > min_SMK_05B & SMK_05B < max_SMK_05B 
          & SMK_208 > min_SMK_208 & SMK_208 < max_SMK_208, pmax(((DHHGAGE_cont - SMKG207_cont -
                                                                    time_quit_smoking) * (SMK_208 / 20)), 0.0137) +
            (pmax((SMK_05B * SMK_05C / 30), 1) *time_quit_smoking),
          # PackYears for Occasional Smoker (never daily)
          if_else2(
            SMKDSTY_A == 3 & SMK_05C > min_SMK_05C & SMK_05C < max_SMK_05C 
            & SMKG207_cont > min_SMKG207_cont & SMKG207_cont < max_SMKG207_cont, 
            (pmax((SMK_05B * SMK_05C / 30), 1) / 20) * (DHHGAGE_cont - SMKG01C_cont),
            # PackYears for former daily smoker (non-smoker now)
            if_else2(
              SMKDSTY_A == 4 & SMKG207_cont > min_SMKG207_cont & SMKG207_cont < max_SMKG207_cont
              & time_quit_smoking > min_time_quit_smoking & time_quit_smoking < max_time_quit_smoking
              & SMK_208 > min_SMK_208 & SMK_208 < max_SMK_208, pmax(((DHHGAGE_cont - SMKG207_cont -
                                                                        time_quit_smoking) *
                                                                       (SMK_208 / 20)), 0.0137),
              # PackYears for former occasional smoker (non-smoker now) who
              # smoked at least 100 cigarettes lifetime
              if_else2(
                SMKDSTY_A == 5 & SMK_01A == 1, 0.0137,
                # PackYears for former occasional smoker (non-smoker now) who 
                # have not smoked at least 100 cigarettes lifetime
                if_else2(
                  SMKDSTY_A == 5 & SMK_01A == 2, 0.007,
                  # Non-smoker
                  if_else2(SMKDSTY_A == 6, 0,
                           # Account for NA(a)
                           if_else2(SMKDSTY_A == "NA(a)", tagged_na("a"),
                                    tagged_na("b"))
                  )
                )
              )
            )
          )
        )
      )
    return(pack_years)
  }

#' @title Age started smoking daily - daily/former daily smokers
#'
#' @description This function creates a continuous derived variable 
#' (SMKG040_fun) that calculates the approximate age that a daily or former 
#' daily smoker began smoking daily. 
#'
#' @details SMKG203 (daily smoker) and SMKG207 (former daily) are present in
#' CCHS 2001-2014, and are separate variables. For CCHS 2015 and onward, SMKG040 
#' (daily/former daily) combines the two previous variables. SMKG040_fun takes 
#' the continuous functions (SMKG203_cont and SMKG207_cont) to create SMKG040 
#' for 2001-2014.
#' 
#' @note In previous cycles, both SMKG203 and SMKG207 included respondents who 
#' did not state their smoking status. From CCHS 2015 and onward, SMKG040 only
#' included respondents who specified daily smoker or former daily smoker. As 
#' a result, SMKG040 has a large number of missing respondents for CCHS 2015 
#' survey cycles and onward.
#'
#' @param SMKG203_cont age started smoking daily. Variable asked to daily
#'  smokers.
#'
#' @param SMKG207_cont age started smoking daily. Variable asked to former
#'  daily smokers.
#'  
#' @return value for age started smoking daily for daily/former daily smokers in
#' the SMKG040_cont variable
#'  
#' @examples  
#' # Using SMKG040_fun() to create age values across CCHS cycles
#' # SMKG040_fun() is specified in variable_details.csv under SMKG040_cont.
#' 
#' # To create a continuous harmonized variable for SMKG040, use rec_with_table() 
#' # for each CCHS cycle and specify SMKG040_cont.
#' 
#' library(cchsflow)
#'
#' age_smoke_dfd_2009_2010 <- rec_with_table(
#'   cchs2009_2010_p, c(
#'     "SMKG203_cont", "SMKG207_cont","SMKG040_cont"
#'   )
#' )
#'
#' head(age_smoke_dfd_2009_2010)
#'
#' age_smoke_dfd_2011_2012 <- rec_with_table(
#'   cchs2011_2012_p,c(
#'     "SMKG203_cont", "SMKG207_cont","SMKG040_cont"
#'   )
#' )
#'
#' tail(age_smoke_dfd_2011_2012)
#'
#' combined_age_smoke_dfd <- suppressWarnings(merge_rec_data
#' (age_smoke_dfd_2009_2010,age_smoke_dfd_2011_2012))
#'
#' head(combined_age_smoke_dfd)
#' tail(combined_age_smoke_dfd)
#' 
#' SMKG203_cont <- c(30, NA, NA)
#' SMKG207_cont <- c(NA, 42, NA)
#' SMKG040_data <- data.frame(SMKG203_cont, SMKG207_cont)
#' SMKG040_data$SMKG040 <- SMKG040_fun(SMKG040_data$SMKG203_cont, SMKG040_data$SMKG207_cont) 
#' print(SMKG040_data)
#' @export

SMKG040_fun <- function(SMKG203_cont, SMKG207_cont){
  SMKG040_cont <-
    if_else2((SMKG203_cont == tagged_na("a") & SMKG207_cont == tagged_na("a")),
             tagged_na("a"),
             if_else2((SMKG203_cont == tagged_na("b") &
                         SMKG207_cont == tagged_na("b")), tagged_na("b"),
                      if_else2(!is.na(SMKG203_cont), SMKG203_cont,
                               if_else2(!is.na(SMKG207_cont), SMKG207_cont,
                                        tagged_na("b")))))
  return(SMKG040_cont)
}

#' # Additional examples of SMKG040_cont calculations produced 
#' # using SMKG040_fun_A() can be found below. Multiple instances exist 
#' # where an NA output may be produced such as a negative/missing entry or an 
#' # entry existing outside of the allowed variable minimum and maximum values. 
#' 
#' SMKG203_cont <- c(30, NA, -2, 95, NA, NA, NA)
#' SMKG207_cont <- c(NA, 42, NA, NA, -3, 86, NA)
#' SMKG040_data <- data.frame(SMKG203_cont, SMKG207_cont)
#' SMKG040_data$SMKG040 <- SMKG040_fun_A(SMKG040_data$SMKG203_cont, SMKG040_data$SMKG207_cont) 
#' print(SMKG040_data)
#' @export

SMKG040_fun_A <- function(SMKG203_cont, SMKG207_cont, 
                          min_SMKG203_cont = 5, max_SMKG203_cont = 84, 
                          min_SMKG207_cont = 5, max_SMKG207_cont = 80){
  SMKG040_cont <-
    if_else2((SMKG203_cont == tagged_na("a") & SMKG207_cont == tagged_na("a")),
             tagged_na("a"),
             if_else2((SMKG203_cont == tagged_na("b") &
                         SMKG207_cont == tagged_na("b")), tagged_na("b"),
                      if_else2(!is.na(SMKG203_cont) & SMKG203_cont > min_SMKG203_cont 
                               & SMKG203_cont < max_SMKG203_cont, SMKG203_cont,
                               if_else2(!is.na(SMKG207_cont) & SMKG207_cont > min_SMKG207_cont 
                                        & SMKG207_cont < max_SMKG207_cont, SMKG207_cont,
                                        tagged_na("b")))))
  return(SMKG040_cont)
}

#' @title Categorical smoking pack-years
#' 
#' @description This function creates a categorical derived variable
#' (pack_years_cat) that categorizes smoking pack-years (pack_years_der).
#' 
#' @details pack-years is calculated by multiplying the number of cigarette 
#' packs per day (20 cigarettes per pack) by the number of years.The categories 
#' were based on the Cardiovascular Disease Population Risk Tool 
#' (Douglas Manuel et al. 2018). 
#' 
#' pack_years_cat uses the derived variable pack_years_der. Pack_years_der uses
#' age and various smoking variables that have been transformed by cchsflow (see
#' documentation on pack_year_der). In order to categorize pack years across CCHS
#' cycles, age and smoking variables must be transformed and harmonized.
#' 
#' @param pack_years_der derived variable that calculates smoking pack-years
#'  See \code{\link{pack_years_fun}} for documentation on how variable
#'  was derived.
#'  
#' @return value for pack year categories in the pack_years_cat variable.
#' 
#' @examples  
#' # Using pack_years_fun_cat() to categorize pack year values across CCHS cycles
#' # pack_years_fun_cat() is specified in variable_details.csv along with the 
#' # CCHS variables and cycles included.
#'
#' # To transform pack_years_cat across cycles, use rec_with_table() for each
#' # CCHS cycle and specify pack_years_cat.
#' # Since pack_year_der is also also derived variable, you will have to specify 
#' # the variables that are derived from it.
#' # Since time_quit_smoking_der is also a derived variable in pack_year_der, 
#' # you will have to specify the variables that are derived from it.
#' # Then by using merge_rec_data(), you can combine pack_years_cat across
#' # cycles.
#' 
#' library(cchsflow)
#'
#' pack_years_cat_2009_2010 <- rec_with_table(
#'   cchs2009_2010_p, c(
#'     "SMKDSTY_A", "DHHGAGE_cont", "SMK_09A_B", "SMKG09C", "time_quit_smoking",
#'     "SMKG203_cont", "SMKG207_cont", "SMK_204", "SMK_05B", "SMK_208",
#'     "SMK_05C", "SMK_01A", "SMKG01C_cont", "pack_years_der", "pack_years_cat"
#'   )
#' )
#'
#' head(pack_years_cat_2009_2010)
#'
#' pack_years_cat_2011_2012 <- rec_with_table(
#'   cchs2011_2012_p,c(
#'     "SMKDSTY_A", "DHHGAGE_cont", "SMK_09A_B", "SMKG09C", "time_quit_smoking",
#'     "SMKG203_cont", "SMKG207_cont", "SMK_204", "SMK_05B", "SMK_208",
#'     "SMK_05C", "SMK_01A", "SMKG01C_cont", "pack_years_der", "pack_years_cat"
#'   )
#' )
#'
#' tail(pack_years_cat_2011_2012)
#'
#' combined_pack_years_cat <- suppressWarnings(merge_rec_data
#' (pack_years_cat_2009_2010,pack_years_cat_2011_2012))
#'
#' head(combined_pack_years_cat)
#' tail(combined_pack_years_cat)
#' @export
#' 
pack_years_fun_cat <- function(pack_years_der){
  pack_years_cat <-
    if_else2(pack_years_der == 0, 1,
    if_else2(pack_years_der > 0 & pack_years_der <= 0.01, 2,
    if_else2(pack_years_der > 0.01 & pack_years_der <= 3.0, 3,
    if_else2(pack_years_der > 3.0 & pack_years_der <= 9.0, 4,
    if_else2(pack_years_der > 9.0 & pack_years_der <= 16.2, 5,
    if_else2(pack_years_der > 16.2 & pack_years_der <= 25.7, 6,
    if_else2(pack_years_der > 25.7 & pack_years_der <= 40.0, 7,
    if_else2(pack_years_der > 40.0, 8,
    if_else2(haven::is_tagged_na(pack_years_der, "a"), "NA(a)", "NA(b)")))))))))
  
  return(pack_years_cat)
}

#' @title Type of smokers
#' 
#' @description This function creates a derived variable (SMKDSTY_A) for 
#' smoker type with 5 categories:
#' 
#' \itemize{
#'   \item daily smoker
#'   \item current occasional smoker (former daily) 
#'   \item current occasional smoker (never daily) 
#'   \item current nonsmoker (former daily)
#'   \item current nonsmoker (never daily)
#'   \item nonsmoker
#'  }
#' 
#' @details For CCHS 2001-2014, smoker type is derived from smoking more than 
#' 100 cigarettes in lifetime, type of smoker at present time, and ever smoked 
#' daily. For CCHS 2015-2018, smoker type was derived differently with different 
#' variables and categories. A function was created for a consistent smoker 
#' status across all cycles.
#' 
#' @param SMK_005 type of smoker presently
#' 
#' @param SMK_030 smoked daily - lifetime (occasional/former smoker)
#' 
#' @param SMK_01A smoked 100 or more cigarettes in lifetime
#' 
#' @return value for smoker type in the SMKDSTY_A variable
#' 
#' @examples  
#' # Using SMKDSTY_fun() to derive smoke type values across CCHS cycles
#' # SMKDSTY_fun() is specified in variable_details.csv along with the 
#' # CCHS variables and cycles included.
#'
#' # To transform SMKDSTY_A across cycles, use rec_with_table() for each
#' # CCHS cycle and specify SMKDSTY_A.
#' # For CCHS 2001-2014, only specify SMKDSTY_A for smoker type.
#' # For CCHS 2015-2018, specify the parameters and SMKDSTY_A for smoker type.
#' 
#' library(cchsflow)
#'
#' smoker_type_2009_2010 <- rec_with_table(
#'   cchs2009_2010_p, "SMKDSTY_A")
#'
#' head(smoker_type_2009_2010)
#'
#' smoker_type_2017_2018 <- rec_with_table(
#'   cchs2017_2018_p,c(
#'     "SMK_01A", "SMK_005","SMK_030","SMKDSTY_A"
#'   )
#' )
#'
#' tail(smoker_type_2017_2018)
#'
#' combined_smoker_type <- suppressWarnings(merge_rec_data
#' (smoker_type_2009_2010,smoker_type_2017_2018))
#'
#' head(combined_smoker_type)
#' tail(combined_smoker_type)
#' 
#' @export

SMKDSTY_fun<-function(SMK_005, SMK_030, SMK_01A){
  if_else2(SMK_005 == 1, 1, # Daily smoker
  if_else2(SMK_005 == 2 & SMK_030 == 1, 2, # Occasional smoker (former daily)
  if_else2(SMK_005 == 2 & (SMK_030 == 2|SMK_030 == "NA(a)"|SMK_030 == "NA(b)"), 
           3, # Occasional Smoker (never daily)
  if_else2(SMK_005 == 3 & SMK_030 == 1 , 4, # Former daily
  if_else2(SMK_005 == 3 & SMK_030 == 2 & SMK_01A == 1, 5, # Former occasional
  if_else2(SMK_005 == 3 & SMK_01A == 2, 6, # Never smoked
  if_else2(SMK_005 == "NA(a)", tagged_na("a"), tagged_na("b"))))))))
}

#' @title Age started to smoke daily - daily smoker
#' 
#' @description This function creates a continuous derived variable
#' (SMKG203_cont) for age started to smoke daily for daily smokers.
#' 
#' @details For CCHS 2015-2018, age started to smoke daily was combined for daily 
#' and former daily smokers.Previous cycles had separate variables for age 
#' started to smoke daily. Type of smoker presently is used to define daily 
#' smoker.
#' 
#' @param SMK_005 type of smoker presently
#' 
#' @param SMKG040 age started to smoke daily - daily/former daily smoker
#' 
#' @return value for continuous age started to smoke daily for daily smokers 
#' in the SMKG203_cont variable
#' 
#' @examples  
#' # Using SMKG203_fun() to derive age started to smoke daily values across 
#' # CCHS cycles.
#' # SMKG203_fun() is specified in variable_details.csv along with the 
#' # CCHS variables and cycles included.
#'
#' # To transform SMKG203_A across cycles, use rec_with_table() for each
#' # CCHS cycle and specify SMKG203_A.
#' # For CCHS 2001-2014, only specify SMKG203_A.
#' # For CCHS 2015-2018, specify the parameters and SMKG203_A for daily smoker 
#' # age.
#' 
#' library(cchsflow)
#'
#' agecigd_2009_2010 <- rec_with_table(
#'   cchs2009_2010_p, "SMKG203_A")
#'
#' head(agecigd_2009_2010)
#'
#' agecigd_2017_2018 <- rec_with_table(
#'   cchs2017_2018_p,c(
#'     "SMK_005","SMKG040","SMKG203_A"
#'   )
#' )
#'
#' tail(agecigd_2017_2018)
#'
#' combined_agecigd <- suppressWarnings(merge_rec_data
#' (agecigd_2009_2010,agecigd_2017_2018))
#'
#' head(combined_agecigd)
#' tail(combined_agecigd)
#' 
#' @export

SMKG203_fun <- function(SMK_005, SMKG040){
  SMKG203 <- if_else2(
    SMK_005 == 1, SMKG040,
      if_else2(
        SMK_005 == "NA(a)"|SMKG040 == "NA(a)", tagged_na("a"), tagged_na("b")))
  SMKG203_cont <- if_else2(
    SMKG203 == 1, 8,
    if_else2(
      SMKG203 == 2, 13,
      if_else2(
        SMKG203 == 3, 16,
        if_else2(
          SMKG203 == 4, 18.5,
          if_else2(
            SMKG203 == 5, 22,
            if_else2(
              SMKG203 == 6, 27,
              if_else2(
                SMKG203 == 7, 32,
                if_else2(
                  SMKG203 == 8, 37,
                  if_else2(
                    SMKG203 == 9, 42,
                    if_else2(
                      SMKG203 == 10, 47,
                      if_else2(
                        SMKG203 == 11, 55,
                        if_else2(SMKG203 == "NA(a)", 
                                 tagged_na("a"), tagged_na("b")
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
  
  return(SMKG203_cont)
}

#' @title Age started to smoke daily - former daily smoker
#'
#' @description This function creates a continuous derived variable
#' (SMKG207_cont) for age started to smoke daily for former daily smokers.
#' 
#' @details For CCHS 2015-2018, age started to smoke daily was combined for daily 
#' and former daily smokers.Previous cycles had separate variables for age 
#' started to smoke daily. Smoked daily in lifetime is used to define former 
#' daily smoker.
#' 
#' @param SMK_030 smoked daily - lifetime (occasional/former smoker)
#' 
#' @param SMKG040 age started to smoke daily - daily/former daily smoker
#' 
#' @return value for continuous age started to smoke daily for former daily 
#' smokers in the SMKG207_cont variable
#' 
#' @examples  
#' # Using SMKG207_fun() to derive age started to smoke daily values across 
#' # CCHS cycles.
#' # SMKG207_fun() is specified in variable_details.csv along with the 
#' # CCHS variables and cycles included.
#'
#' # To transform SMKG207_A across cycles, use rec_with_table() for each
#' # CCHS cycle and specify SMKG207_A.
#' # For CCHS 2001-2014, only specify SMKG207_A.
#' # For CCHS 2015-2018, specify the parameters and SMKG207_A for former daily 
#' # smoker age.
#' 
#' library(cchsflow)
#'
#' agecigfd_2009_2010 <- rec_with_table(
#'   cchs2009_2010_p, "SMKG207_A")
#'
#' head(agecigfd_2009_2010)
#'
#' agecigfd_2017_2018 <- rec_with_table(
#'   cchs2017_2018_p,c(
#'     "SMK_030","SMKG040","SMKG207_A"
#'   )
#' )
#'
#' tail(agecigfd_2017_2018)
#'
#' combined_agecigfd <- suppressWarnings(merge_rec_data
#' (agecigfd_2009_2010,agecigfd_2017_2018))
#'
#' head(combined_agecigfd)
#' tail(combined_agecigfd)
#' 
#' @export
#' @export
SMKG207_fun <- function(SMK_030, SMKG040){
  SMKG207 <- if_else2(
      SMK_030 == 1, SMKG040,
       if_else2(
         SMK_030 == "NA(a)"|SMKG040 == "NA(a)", tagged_na("a"), tagged_na("b")))
  SMKG207_cont <- if_else2(
    SMKG207 == 1, 8,
      if_else2(
        SMKG207 == 2, 13,
          if_else2(
            SMKG207 == 3, 16,
              if_else2(
                SMKG207 == 4, 18.5,
                  if_else2(
                    SMKG207 == 5, 22,
                      if_else2(
                        SMKG207 == 6, 27,
                          if_else2(
                            SMKG207 == 7, 32,
                              if_else2(
                                SMKG207 == 8, 37,
                                if_else2(
                                  SMKG207 == 9, 42,
                                    if_else2(
                                      SMKG207 == 10, 47,
                                      if_else2(
                                          SMKG207 == 11, 55,
                                            if_else2(SMKG207 == "NA(a)", 
                                                tagged_na("a"), tagged_na("b")
                                                )
                                          )
                                      )
                                  )
                                )
                            )
                        )
                    )
                )
            )
        )
    )
                    
  return(SMKG207_cont)
  
}