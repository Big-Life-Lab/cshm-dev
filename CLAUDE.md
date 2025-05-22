# CSHGM - Canadian Smoking History Generator Model

This file contains useful notes and commands for working with this project. For a comprehensive project overview, see `docs/project-specifications.qmd`.

## Common commands

- Run all tests: `testthat::test_dir("tests/testthat/")`
- Run single test: `testthat::test_file("tests/testthat/test-process-smoking-initiation.R")`
- Load R package: `devtools::load_all()`
- Check R package: `devtools::check()`

## Quick reference

### Key files
- `config/` - Configuration files and variable definitions
- `R/process_smoking_initiation.R` - R implementation of smoking initiation data processing
- `docs/reference/` - Reference materials including legacy SAS code

### Variable codes
- `SMK_01A`: Lifetime smoking of 100+ cigarettes (1=Yes, 2=No)
- `agefirst`: Age when respondent first smoked a whole cigarette
- `SMKG01C_cont`: Continuous variable for age when first smoked (harmonized)

### APC model variables
- `age`: Age at smoking initiation 
- `period`: Calendar year when smoking was initiated (cohort + age)
- `cohort`: Birth year

## Editorial style

Canadian grammar and spelling should be used (e.g., "modelling" instead of "modeling").

The following editorial guidelines apply to all project documentation:
- Use sentence case for headings (capitalize only the first word)
- Use simple, clear, and concise language
- Avoid jargon and overly complex sentences
- Be direct and to the point
- Provide DOI or PMID for references where available
