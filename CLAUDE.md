# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

For project overview, methodology, and architecture see [README.md](README.md) and [docs/development/project-architecture.md](docs/development/project-architecture.md).

## Common commands

```r
# Run the full pipeline
targets::tar_make()

# Visualize pipeline DAG
targets::tar_visnetwork()

# Run a single target / inspect / check outdated
targets::tar_make(study_data)
targets::tar_read(study_data)
targets::tar_outdated()

# Run tests
testthat::test_dir("tests/testthat/")
testthat::test_file("tests/testthat/test-apc-data.R")

# Switch config profile (dev = 10% sample; draft = 5% from cchsflow-data release)
Sys.setenv(R_CONFIG_ACTIVE = "dev")
targets::tar_make()

# Add a new dependency
renv::install("package-name")
renv::snapshot()
```

```bash
# Preview / build documentation website
quarto preview
quarto render

# Render manuscript to Word (docstyle)
quarto render manuscript/manuscript.qmd
```

## Developer context

### Pipeline and configuration

The pipeline follows the DemPoRT-V2-dev pattern (`~/github/DemPoRT-V2-dev`); its CLAUDE.md is the reference implementation.

| File | Purpose |
|------|---------|
| [_targets.R](_targets.R) | Pipeline definition (stages 1–8 active; 9–10 stubbed) |
| [config.yml](config.yml) | Environment profiles (`default`, `draft`, `dev`, `prod`, `statscan`) |
| [worksheets/cshm-variables.csv](worksheets/cshm-variables.csv) | Study variable list — `role`, `source`, and `purpose` columns |
| [worksheets/cshm-variable-details.csv](worksheets/cshm-variable-details.csv) | CSHM extension rows: GEOGPRV and WTS_M for cchs2019_2020_p and cchs2022_p (DHH_SEX/DHHGAGE_cont rows removed — cchsflow v3 now covers them) |
| [R/study-data.R](R/study-data.R) | `load_study_data()` — load + harmonize CCHS cycles |
| [R/data-cleaning.R](R/data-cleaning.R) | `clean_study_data()` — distribution checks, truncation |
| [R/imputation.R](R/imputation.R) | `impute_data()` — MICE imputation |
| [R/descriptive-data.R](R/descriptive-data.R) | `get_cshm_desc_data()` — Table 1 statistics wrapper |
| [R/get-descriptive-data.R](R/get-descriptive-data.R) | `get_descriptive_data()` — core stats engine (ported from DemPoRT) |
| [R/create-descriptive-tables.R](R/create-descriptive-tables.R) | `create_descriptive_table()`, `create_cycle_specific_descriptive_table()` |
| [R/variables-sheet-utils.R](R/variables-sheet-utils.R) | Variables worksheet helpers (ported from DemPoRT) |
| [R/variable-details-sheet-utils.R](R/variable-details-sheet-utils.R) | Variable details helpers (ported from DemPoRT) |
| [R/apc-model.R](R/apc-model.R) | APC data prep + model fitting |
| [R/smoking-histories.R](R/smoking-histories.R) | Rate table generation (Stage 9, stub) |
| [R/validation.R](R/validation.R) | Prevalence validation |
| [docs/results/table-1.qmd](docs/results/table-1.qmd) | Table 1a, 1b, and cycle appendix |
| [R/legacy/smoking.R](R/legacy/smoking.R) | Interim smoking variables (pre-cchsflow v3) |
| [R/legacy/process_smoking_initiation.R](R/legacy/process_smoking_initiation.R) | APC data prep (pre-pipeline; superseded by R/apc-model.R) |
| [resources/legacy-code/Modeling2013.sas](resources/legacy-code/Modeling2013.sas) | Original SAS implementation (Manuel et al. 2020) |
| docs/references/Manuel_HR_2020.pdf | Key reference paper (local only; PDFs are gitignored) |
| [config/statscan.yml.example](config/statscan.yml.example) | RDC config template (copy to `config/statscan.yml`, gitignored) |

**Documentation structure** (three purposes):

| Location | Purpose |
|----------|---------|
| [docs/protocol/full-protocol.qmd](docs/protocol/full-protocol.qmd) | Prespecified study protocol |
| [docs/protocol/study-summary.qmd](docs/protocol/study-summary.qmd) | One-page protocol summary |
| [docs/workflow/](docs/workflow/) | Step QMDs — one per pipeline stage (Stages 1–8) |
| [manuscript/manuscript.qmd](manuscript/manuscript.qmd) | Study manuscript (all numbers inline R from pipeline) |
| [docs/how-to/](docs/how-to/) | Task-oriented guides |
| [docs/explanation/](docs/explanation/) | Conceptual explanations of APC methodology |
| [docs/reference/](docs/reference/) | Variable, function, and model reference |

**Development artefacts** (`docs/development/` — gitignored, local only): planning documents, meeting notes, protocol drafts, pipeline progress notes.

`config.yml` profiles (set via `R_CONFIG_ACTIVE`):
- **default** — PUMF data from `~/github/cchsflow-data/data/sources/rdata/` (renamed via scripts/rename-pumf-objects.R); full sample
- **draft** — 5% sample from `cchsflow-data` release files (`CCHS_2001.RData` naming, internal object `table`)
- **dev** — 10% sample from default PUMF source; single imputation; fast iteration
- **prod** — full PUMF sample; WARN logging
- **statscan** — delegates to `config/statscan.yml` (gitignored); Master file paths at RDC

APC spline knots: Age `[10, 15, 20, 50, 60]` · Period `[1940, 1950, 1960, 1970, 1980]` · Cohort `[1930, 1940, 1945, 1950, 1955, 1960, 1965, 1970, 1975, 1980]`

### Data paths

PUMF `.RData` files: `~/github/cchsflow/data/` (cycles 2001–2017/18 with correct `cchs*_p` naming). Cycles 2019–20 and 2022 require renaming from `cchsflow-data` GH release via `scripts/rename-pumf-objects.R`.

CCHS metadata CLI:
```bash
python3 ~/github/cchsflow-docs/mcp-server/cli.py search smoking
python3 ~/github/cchsflow-docs/mcp-server/cli.py detail SMKDSTY
python3 ~/github/cchsflow-docs/mcp-server/cli.py compare cchs2013_2014_p cchs2013_2014_m
```

### Variable naming

The `variableStart` worksheet column uses cchsflow notation: `cchs2001_p::SMKA_01A, cchs2007_2008_p::SMK_01A, [SMK_01A]` — `_p` = PUMF, `_m` = Master, `[VAR]` = fallback name.

**Unified variables (preferred):** `age_first_cigarette`, `age_start_smoking`, `time_quit_smoking`

**Master-only continuous:** `SMK_01C`, `SMK_040`, `SMK_09C` / `SMK_06C` / `SMK_10C`

**PUMF pseudo-continuous (midpoint imputed):** `SMKG01C_cont`, `SMKG040_cont`, `SMK_09A_cont` / `SMK_06A_cont` / `SMK_10A_cont`

**Deprecated aliases:** `SMK_005` → `SMK_202`; `SMK_030` → `SMK_05D`

**APC model variables (internal):** `age`, `cohort`, `period`, `init`, `weighting`, `ont_id`

### cchsflow dependency

Branch: `v3` (smoking work merged 2026-04-29, commit bd0df3ac; PR #163 closed in favour of direct merge). The pipeline reads recoding rules from the in-repo snapshot `worksheets/cchsflow-variable-details.csv` (taken from `~/github/cchsflow/inst/extdata/variable_details.csv` with local fixes for cchsflow #184/#185); refresh it when upstream merges the fixes. renv installs the cchsflow *package* from the local `~/github/cchsflow` checkout on `v3` (CRAN 2.1.0 lacks the v3 derivation functions). Key smoking files:
`R/smoke-start.R`, `R/smoke-stop.R`, `R/smoke-intensity.R`, `R/smoking-status.R`, `R/smoking-cessation.R`, `R/clean-variables.R`, `R/missing-data-functions.R`

cchsflow must be *attached* (not just `::`-qualified) when calling `rec_with_table()` — v3 derivation functions use unqualified dplyr/rlang helpers that resolve through its `Depends`. `_targets.R` handles this with `tar_option_set(packages = "cchsflow")`.

### Variable roles

Roles are comma-separated in `cshm-variables.csv`. A variable may carry multiple roles. `select_vars_by_role(role, variables_sheet)` handles this correctly.

| Role | Group | Purpose |
|------|-------|---------|
| `design` | Survey design | Survey infrastructure (SurveyCycle, WTS_M) |
| `intermediate` | Harmonization | Raw cchsflow input needed to derive a unified variable; not used directly by pipeline code |
| `predictor` | Model | Covariate in the APC model |
| `model-stratifier` | Model | Stratifies APC into separate fits (e.g. DHH_SEX) |
| `table1` | Descriptive | Row in Table 1 (drives row selection in `get_cshm_desc_data()`) |
| `table1-stratifier` | Descriptive | Reserved for cycle/extra stratification of descriptive tables (not yet consumed by code) |
| `apc-numerator` | APC data prep | Defines the event indicator in Stage 7 |
| `apc-denominator` | APC data prep | Constructs the at-risk person-year denominator in Stage 7 |
| `imputation-predictor` | Imputation | Included in MICE imputation model |
| `sensitivity-analysis` | Analysis | Used in sensitivity analyses only |

Role vocabulary (single source of truth): [schemas/cshm-variables.yaml](schemas/cshm-variables.yaml) `VariableRoleEnum`. Role helpers in `R/variables-sheet-utils.R` are project-local for now; long-term home is cchsflow (skill branch `skills/review-validation`).

### Missing data conventions

`haven::tagged_na()` throughout: **NA(a)** = not applicable · **NA(b)** = don't know/refused · **NA(c)** = not asked this cycle

## Code style

- Follow tidyverse design principles; snake_case for all function and variable names
- Format code with the `styler` package

## Editorial style

- Canadian English: "modelling", "behaviour", "analyse"
- Sentence case for all headings (except document title)
- Provide DOI or PMID for references
