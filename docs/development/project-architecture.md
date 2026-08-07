# Project architecture

## Overview

The Canadian Smoking Histories Model (CSHM) estimates age-period-cohort (APC) smoking parameters from CCHS survey data, then feeds those parameters to the CISNET Smoking History Generator (shg-rcpp) for simulation. This document describes the repo structure, data pipeline, and configuration system.

## Two-stage analysis

| Stage | Tool | Output |
|-------|------|--------|
| 1. Estimate APC parameters | CSHM (this repo) | Canadian initiation/cessation rate tables |
| 2. Simulate smoking histories | [shg-rcpp](https://github.com/NCI-CISNET/shg-rcpp) | Individual-level smoking histories |

CSHM is methodologically distinct from shg-rcpp: CSHM *estimates* parameters from CCHS survey data using APC regression; shg-rcpp *simulates* individual histories from pre-fitted tables. The two connect via rate table files formatted to the shg-rcpp input specification.

## Two computing environments

| Environment | Data source | Who uses it |
|-------------|-------------|-------------|
| Development (PUMF) | `~/github/cchsflow-data/data/sources/rdata/` | All team members |
| Production (Master) | Statistics Canada RDC (secure path in `config/statscan.yml`) | RDC analysts only |

PUMF files use midpoint-estimated pseudo-continuous variables (e.g., `SMKG01C_cont`, `SMKG040_cont`). Master files provide exact continuous values (`SMK_01C`, `SMK_040`). PUMF-derived results are the shareable international artifact; Master data produces the definitive estimates.

**CCHS cycles (PUMF):** 2001, 2003, 2005, 2007–08, 2009–10, 2011–12, 2013–14, 2015–16, 2017–18, 2019–20, 2022

## Three-layer data pipeline

```
Layer 1 — Raw source (never in repo)
  Original PUMF .RData files, one per CCHS cycle
  Path: ~/github/cchsflow-data/data/sources/rdata/
  Config key: data.raw_dir

Layer 2 — Study data (in repo or GH Release)
  Combined harmonized cycles, filtered to study variables
  Produced by: study_data target
  Path: data/study_data.rds

Layer 3 — Analysis-ready data (in repo or GH Release)
  Post-cleaning + post-imputation
  Produced by: imputation target
  Path: data/analysis_data.rds
  This is the primary reproducibility artifact for external users.
```

## Pipeline stages (`_targets.R`)

| Stage | Target | Input | Output |
|-------|--------|-------|--------|
| 1 | `read_worksheets` | `worksheets/` CSVs | variable metadata |
| 2 | `study_data` | raw PUMF cycles + worksheets | `data/study_data.rds` |
| 3 | `data_cleaning` | study_data | cleaned data frame |
| 4 | `table_1a` | cleaned data | Table 1 pre-imputation |
| 5 | `imputation` | cleaned data | `data/analysis_data.rds` |
| 6 | `table_1b` | analysis_data | Table 1 post-imputation |
| 7 | `apc_data` | analysis_data | initiation/cessation numerator sets (by sex) |
| 8 | `apc_model` | apc_data | fitted APC models *(in development)* |
| 9 | `smoking_histories` | apc_model | simulated histories *(in development)* |
| 10 | `validation` | smoking_histories | comparison against historic surveys *(in development)* |

## Configuration (`config.yml`)

Four profiles using the `{config}` R package:

| Profile | Purpose |
|---------|---------|
| `default` | PUMF data from `~/github/cchsflow-data/`; used for development |
| `dev` | Same as default but with `sample_proportion: 0.1` for fast iteration |
| `prod` | Same PUMF source, full sample; final PUMF run before RDC |
| `statscan` | Master file paths; loaded via `config/statscan.yml` (gitignored) |

Set active profile: `Sys.setenv(R_CONFIG_ACTIVE = "dev")`

## Worksheets (`worksheets/`)

Following the cchsflow/DemPoRT pattern:

| File | Purpose |
|------|---------|
| `cshm-variables.csv` | Study variables: name, label, units, type |
| `cshm-variable-details.csv` | Response categories, recoding rules, units |
| `cshm-variables-working-copy.csv` | Working copy for in-progress edits |
| `cchsflow-variable-details.csv` | cchsflow upstream variable details (reference) |

## cchsflow dependency

Harmonization uses [cchsflow](https://github.com/Big-Life-Lab/cchsflow) v3 (`v3-smoking` branch, PR #163). Key smoking variables introduced in v3:

- `age_first_cigarette` — age first smoked whole cigarette
- `age_start_smoking` — age started smoking daily
- `time_quit_smoking` — years since quitting

These route automatically to exact values (Master) or midpoint estimates (PUMF) based on file type.

Until PR #163 merges, `R/legacy/smoking.R` provides interim equivalents.

## R functions (`R/`)

| File | Purpose |
|------|---------|
| `R/study-data.R` | Load and harmonize CCHS cycles via cchsflow |
| `R/data-cleaning.R` | Distribution checks and truncation |
| `R/imputation.R` | MICE imputation |
| `R/apc-model.R` | Fit constrained cubic spline APC models |
| `R/smoking-histories.R` | Simulate histories from fitted rates |
| `R/validation.R` | Compare modelled prevalence against historic surveys |
| `R/legacy/smoking.R` | Interim smoking variable functions (pre-cchsflow v3) |

## Reference implementation

Pipeline architecture follows [DemPoRT-V2-dev](https://github.com/Big-Life-Lab/DemPoRT-V2-dev):
- `{targets}` pipeline with `_targets.R`
- `{config}` YAML profiles via `config.yml`
- cchsflow worksheets for variable metadata

## Refactor phases

| Phase | Work | Status |
|-------|------|--------|
| 1 | Config consolidation, worksheet move, file cleanup | Complete |
| 2 | `_targets.R` with `read_worksheets` + `study_data` targets | In progress |
| 3 | Table 1a (pre-imputation) | Pending |
| 4 | Imputation + Table 1b | Pending |
| 5 | APC data preparation | Pending |
| 6 | APC model fitting (requires cchsflow v3) | Pending |
| 7 | Simulation + validation | Pending |
