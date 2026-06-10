# Canadian Smoking Histories Model (CSHM)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Overview

CSHM is an R implementation of an Age-Period-Cohort (APC) model that generates Canadian smoking histories from Canadian Community Health Survey (CCHS) data. It modernizes and extends the Ontario SHGM study (Manuel et al. 2020), updating the CCHS cycles, extending coverage from Ontario to all of Canada, and reimplementing the analysis in R from the original SAS code.

**Key reference:**

> Manuel DG, Wilton AS, Bennett C, Dass R, Laporte A, Holford TR. Smoking patterns based on birth-cohort-specific histories from 1965 to 2013, with projections to 2041. *Health Reports*. 2020;31(11):16–31. doi:[10.25318/82-003-x202001100002-eng](https://doi.org/10.25318/82-003-x202001100002-eng)

## How it works

The model has two stages:

**Stage 1 — Estimate rates from CCHS data.** Two separate APC logistic regression models are fit using harmonized CCHS survey cycles:
- **Initiation model** — probability of transitioning from never smoker to current smoker at age *a*, conditional on being a never smoker at *a*−1 (zero before age 8)
- **Cessation model** — conditional probability of a current smoker quitting at age *a* (zero before age 15)

Both models use constrained cubic splines with the same knot structure as Holford et al. (2014). The fundamental APC identity is `cohort = period − age`.

**Stage 2 — Simulate smoking histories.** Estimated initiation and cessation rates are used to simulate individual-level smoking histories for synthetic Canadian populations.

### APC model constraints

Period effects are held constant beyond the observed data range:

| Model | Constraint |
|-------|-----------|
| Initiation — men | Constant from 1999 forward |
| Initiation — women | Constant from 2003 forward |
| Cessation | Constant from 2013 forward |
| Cohort (initiation) | Constant prior to 1920 |
| Cohort (cessation) | Constant from 1985 forward |

### Mortality adjustment

Ever-smokers have lower survival to survey date than never-smokers. Survival bias is corrected using MPoRT weights adjusted for age, smoking status, years since quitting, immigration, and sex. A sensitivity analysis uses the Peto constant mortality risk ratio, consistent with the original Holford et al. (2014) US implementation.

### Smoking status definitions

| Status | Definition |
|--------|-----------|
| Never smoker | <100 lifetime cigarettes AND never smoked a whole cigarette |
| Current smoker | ≥100 lifetime cigarettes AND currently smokes daily or occasionally |
| Former smoker | ≥100 lifetime cigarettes AND not currently smoking |

## Data

### Two computing environments

| Environment | Data | Notes |
|-------------|------|-------|
| Development | CCHS PUMF `.RData` files | Open licence; used for model development and validation |
| Production | CCHS Master files | Statistics Canada RDC; exact continuous variables; final model run |

PUMF files use midpoint-estimated pseudo-continuous variables (e.g., `SMKG01C_cont`, `SMKG040_cont`). Master files provide exact continuous values (`SMK_01C`, `SMK_040`). PUMF-derived results are the shareable international artifact; Master data produces the definitive estimates.

**CCHS cycles used:** 2001, 2003, 2005, 2007–08, 2009–10, 2011–12, 2013–14, 2015–16, 2017–18, 2019–20, 2022 (PUMF); 2001–2023 (Master).

### CCHS harmonization

Variables are harmonized across CCHS cycles using the [cchsflow](https://github.com/Big-Life-Lab/cchsflow) R package. The active development version (v3, PR #163) introduces unified smoking variables that route automatically to the appropriate source depending on file type:

- `age_first_cigarette` — age first smoked whole cigarette (Master: exact; PUMF: midpoint estimate)
- `age_start_smoking` — age started smoking daily (Master: exact; PUMF: midpoint ±3 years)
- `time_quit_smoking` — years since quit smoking

## Pipeline

The analysis uses a [`{targets}`](https://docs.ropensci.org/targets/) pipeline with environment-specific configuration via `config.yml`. This pattern follows the [DemPoRT v2](https://github.com/Big-Life-Lab/DemPoRT-V2-dev) project.

| Stage | Target | Status |
|-------|--------|--------|
| 1 | `variables_sheet`, `variable_details_sheet` | ✅ Active |
| 2 | `study_data` | ✅ Active |
| 3 | `cleaned_data` | ✅ Active |
| 4 | `table_1a_data` | ✅ Active |
| 5 | `analysis_data` (MICE imputation) | ✅ Active |
| 6 | `table_1b_data` | ✅ Active |
| 7 | `apc_data` | ✅ Active |
| 8 | `apc_model_initiation_men/women`, `apc_model_cessation_men/women` | ✅ Active |
| 9 | `rate_tables` | 🔲 Stub |
| 10 | `validation_results` | 🔲 Stub |

## Project layout

A guide for new collaborators.

### Configuration (`config.yml`)

`config.yml` controls all environment-specific settings. Set the active profile before running:

```r
Sys.setenv(R_CONFIG_ACTIVE = "dev")   # 10% sample, debug logging
Sys.setenv(R_CONFIG_ACTIVE = "draft") # 5% sample from cchsflow-data release
Sys.setenv(R_CONFIG_ACTIVE = "prod")  # Full PUMF sample
# statscan: delegates to config/statscan.yml (gitignored) for RDC paths
```

Key sections in `config.yml`:
- **`cchs_cycles`** — 11 PUMF cycles (2001–2022); statscan profile adds 2023
- **`apc:`** — spline knots, period/cohort constraints, mortality method, projection horizon
- **`sensitivity:`** — documents all prespecified sensitivity analyses with protocol rationale
- **`survey:`** — maps conceptual variable roles to actual CCHS variable names; change these (and the variable worksheets) to adapt the pipeline to a different survey

### Schemas (`schemas/`)

LinkML YAML schemas define the data contracts for key pipeline inputs and outputs:

| Schema | Describes |
|--------|-----------|
| `cshm-variables.yaml` | Study variable dictionary (extends cchsflow `variables.csv`) |
| `cshm-rate-tables.yaml` | APC model output — initiation/cessation probability tables |
| `cshm-cohort.yaml` | Synthetic population used in Stage 9 simulation |

Schemas are documentation and validation specs, not runtime code. The `role`, `source`, and `purpose` fields in `cshm-variables.yaml` are the CSHM additions to the cchsflow variable convention.

### Variable worksheets (`worksheets/`)

Two CSVs define which CCHS variables are loaded at each pipeline stage:

| File | Purpose |
|------|---------|
| `worksheets/cshm-variables.csv` | Study variable list: `variable`, `role`, `source`, `purpose` |
| `worksheets/cshm-variable-details.csv` | CSHM extension rows for 2019–20 and 2022 cycles not yet in cchsflow v3 |

The `role` column is comma-separated and controls pipeline behaviour — e.g., `apc-numerator` variables define the event indicator in Stage 7; `imputation-predictor` variables go into MICE. See `schemas/cshm-variables.yaml` for the full role vocabulary.

`cchsflow`'s `variable_details.csv` (the recoding rules) is loaded separately from `~/github/cchsflow/inst/extdata/` and combined with the CSHM extension rows at pipeline start.

### R functions (`R/`)

| File | Stage | Entry point |
|------|-------|-------------|
| `study-data.R` | 2 | `load_study_data()` |
| `data-cleaning.R` | 3 | `clean_study_data()` |
| `descriptive-data.R` | 4, 6 | `get_cshm_desc_data()` |
| `imputation.R` | 5 | `impute_data()` |
| `apc-model.R` | 7–8 | `prepare_apc_data()`, `fit_apc_model()` |
| `variables-sheet-utils.R` | — | Variable role helpers |
| `variable-details-sheet-utils.R` | — | Variable details helpers |

### `{targets}` workflow

```r
targets::tar_make()          # Run full pipeline
targets::tar_make(apc_data)  # Run through a specific target
targets::tar_read(apc_data)  # Inspect a target's output
targets::tar_outdated()      # See what needs rerunning
targets::tar_visnetwork()    # Visualise pipeline DAG
```

Changing `config.yml` invalidates all downstream targets. Changing an R function invalidates only targets that call it.

## Relationship to CISNET shg-rcpp

The [CISNET Smoking History Generator](https://github.com/NCI-CISNET/shg-rcpp) (`SmokingHistoryGenerator` R package) implements the same APC methodology for the US population. CSHM is the Canadian adaptation.

CSHM generates individual-level smoking histories directly from the estimated rate tables (Stage 9), following the approach of Manuel et al. (2020) and Holford et al. (2014). Because CCHS PUMF data have an open Statistics Canada licence, PUMF-derived Canadian rate tables can be shared internationally.

## Setup

```r
# Restore R environment
renv::restore()

# Run the pipeline
targets::tar_make()
```

See `CONTRIBUTING.md` for the development workflow. Full documentation is in the `docs/` directory and rendered at [GitHub Pages](https://big-life-lab.github.io/cshm-dev/).

## Licence

The code in this repository is licensed under the [MIT License](LICENSE).

## Statistics Canada attribution

CCHS data used in this project is accessed and adapted in accordance with the
[Statistics Canada Open Licence](https://www.statcan.gc.ca/eng/reference/licence).

Source: Statistics Canada, Canadian Community Health Survey 2001 to 2022 PUMF, accessed 2025.
Reproduced and distributed on an "as is" basis with the permission of Statistics Canada.

Adapted from Statistics Canada, Canadian Community Health Surveys 2001 to 2022 PUMF, accessed 2025.
This does not constitute an endorsement by Statistics Canada of this product.

## Acknowledgements

- Dr. Ted Holford for the foundational APC methodology
- Statistics Canada for the CCHS data
- The CISNET Lung Working Group for the foundational US Smoking History Generator
- All contributors to the CSHM Consortium
