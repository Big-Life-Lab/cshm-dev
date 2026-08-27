# Pipeline development progress

This document tracks implementation status and decisions for the CSHM `{targets}` pipeline.
Updated as stages are completed.

## Status summary

| Stage | Target | Status | Notes |
|-------|--------|--------|-------|
| 1 | `variables_sheet`, `variable_details_sheet` | Done | Extension rows for 2019–22 demographics in `worksheets/cshm-variable-details.csv` |
| 2 | `study_data` | Done | All 11 PUMF cycles; tibble → data.frame fix for cchsflow v3 |
| 3 | `cleaned_data` | Done | Age restriction + skewness truncation; all params in `config.yml` |
| 4 | `table_1a_data` | Done | 500 rows × 13 cols; 16 variables × 2 sex strata |
| 5 | `analysis_data` | Done | MICE; 13 variables with NA(b) imputed; m=1/maxit=1 in draft |
| 6 | `table_1b_data` | Done | Post-imputation; 0 NA remaining for imputed variables |
| 7 | `apc_data` | Done | 4 datasets (init/cess × men/women); cell aggregation before model fit |
| 8 | `apc_model_initiation_*`, `apc_model_cessation_*` | Done | 4 independent targets; cessation converges; initiation non-convergence expected on 5% sample (sparse cells) — resolves on full PUMF |
| 9 | `rate_tables` | Stub | |
| 10 | `validation_results` | Stub | |

---

## Stage 1–3: Data loading and cleaning

**Completed 2026-03-09.**

### Key decisions

- **PUMF/Master architecture:** Single `cshm-variables.csv` with a `source` column (`pumf`/`master`/`both`).
  `load_study_data()` filters by `cfg$data_source`. No separate sheets required.

- **Variable details extension:** `worksheets/cshm-variable-details.csv` provides `DHH_SEX`, `DHHGAGE_cont`,
  `GEOGPRV`, and `WTS_M` rows for `cchs2019_2020_p` and `cchs2022_p` — not yet in cchsflow v3.
  This follows the DemPoRT-V2-dev pattern of `rbind(cchsflow_vds, project_vds)` in `_targets.R`.

- **Age variable:** `DHHGAGE_cont` (not `DHH_AGE`). `DHH_AGE` has no PUMF copy rule in cchsflow v3.
  2019–20 and 2022 use 5-category midpoints (14.5, 26, 42, 57, 75) in the extension CSV.

- **cchsflow tibble fix:** `rec_with_table()` crashes when input is a tibble and `recEnd = "copy"`
  with range `recStart`. Fix: `as.data.frame(raw_data)` before calling `rec_with_table()`.

- **Data cleaning parameters in config:** `exclude_age_category`, `skewness_threshold`,
  `truncate_percentile` all live in `config.yml`. No hardcoded cleaning decisions in R code.

### Pipeline results (draft config, 5% sample)

- 65,154 rows loaded across 11 cycles
- 703 excluded (age group 1 = 12–17 year olds), 64,451 remaining after cleaning
- 7 skewed continuous variables truncated at 99th percentile:
  `age_first_cigarette`, `age_start_smoking`, `SMK_09A_cont`, `SMK_06A_cont`,
  `SMKDGSTP_cont`, `SMK_204`, `SMK_208`
- `DHH_SEX`, `DHHGAGE_cont`, `GEOGPRV`, `WTS_M`, `SMKDSTY`: 0% NA across all cycles
- `SDCFIMM`/`SDCGCGT`/`EDUDR03`: ~13.5% NA (genuinely absent from 2019–20 and 2022 PUMF)

---

## Stage 4/6: Descriptive tables

**Completed 2026-03-09.**

Infrastructure ported from DemPoRT-V2-dev:
- `R/get-descriptive-data.R` — `get_descriptive_data()` with stratifier support
- `R/descriptive-data.R` — `get_cshm_desc_data()` wrapper (stratifies by `DHH_SEX`)
- `R/create-descriptive-tables.R` — `create_descriptive_table()` and
  `create_cycle_specific_descriptive_table()` using `{gt}`

Table 1a (pre-imputation): from `cleaned_data`.
Table 1b (post-imputation): from `analysis_data`.

---

## Stage 5: Multiple imputation

**Completed 2026-03-09.**

### Key decisions

- **What to impute:** Variables with random missingness only — `NA(b)` (don't know/refused).
  Structural missingness — `NA(a)` (not applicable) and `NA(c)` (not asked this cycle) — is
  **not** imputed. This is a key CSHM departure from DemPoRT: DemPoRT converts all tagged NAs
  to regular NA before MICE; CSHM converts only `NA(b)`.

- **Config-controlled:** `imputation_m` (number of imputations) and `imputation_maxit` in
  `config.yml`. Default: `m = 1, maxit = 5`. Dev/draft: `m = 1, maxit = 1`.

- **Variables imputed:** All `predictor`-role variables that have any `NA(b)` present.
  Design variables (`SurveyCycle`, `WTS_M`) and `derived-input` variables are excluded.

---

## Stages 7–8: APC data preparation and model fitting

**Completed 2026-03-10.**

### Key decisions

- **Survey year:** `SurveyCycle` code → integer year via `cfg$cycle_survey_years` lookup.
  2-year cycles use midpoint (e.g., 2008 for "2007–08"). Added to `config.yml`.
- **Period range:** 1965–2022 (PUMF default); 1965–2023 (statscan profile). Added to `config.yml`.
- **Cohort floor:** 1920. Added to `config.yml`.
- **Age floor:** initiation ≥ 8; cessation ≥ 8. Added to `config.yml`.
- **Ontario flag:** Dropped. National model; no `ont_id`.
- **Cessation:** Former daily smokers only (SMKDSTY 3 and 4). Former occasional smokers
  excluded — see GH#1.
- **Survival correction:** none (labelled as estimates among survivors); MPoRT and Peto stop as not implemented; no-op guard (task 1.7a, 2026-08-27).
- **Spline library:** `splines2::nsp()`. RCS as config-selectable sensitivity. Added to `config.yml`.
- **Period/cohort constraints:** Applied as clamp before spline basis construction (data-side,
  not model-side). Constraint years are sex- and model-type-specific per `config.yml`.

### Known limitation: `age_first_cigarette` floor at 13 in PUMF

Inspection of `analysis_data` (draft, 5% sample) shows `age_first_cigarette` ranges from
**13 to 55** — not 8 to 55. The variable uses coarser PUMF midpoints with a category floor
of 13. `SMKG01C_cont` (cycles 2007–18 only) has values from 8. This means genuine early
initiators (ages 8–12) are absent from `age_first_cigarette` in PUMF. This is a known PUMF
limitation; the RDC Master run will use exact ages. A warning will be logged at runtime if
`min(age_first_cigarette) > 10`.

### Additional key decisions (implementation)

- **Cell aggregation before model fit:** The SAS code uses `PROC MEANS` to aggregate person-years
  to `(age, period, cohort)` cells before fitting. Fitting on individual rows with raw survey weights
  (~10,000 per person) causes numerical failure in `glm.fit` (probabilities collapse to 0/1).
  The R implementation replicates this by summing weighted events (`d`) and weighted person-years
  (`pop`) per unique basis row, then fitting `glm(cbind(d, pop-d) ~ basis, family=binomial)`.

- **Knot boundary filter:** Config specifies period knots at 1940–1980 for the full denominator
  range. After period clamping, cessation data spans 1965–2013, making knots 1940/1950/1960
  fall outside the boundary. `interior_knots()` filters to knots strictly inside `(min(x), max(x))`
  before calling `nsp()`. Cessation models use 2 period interior knots (1970, 1980); initiation
  uses all 5 (1940–1980 within 1940–2003/1999 range).

- **Initiation non-convergence on draft sample:** With 5% sample (~3,200 respondents per sex),
  83% of initiation cells have zero events (complete separation). This is expected on draft data
  and resolves on full PUMF (~64,000 respondents). Cessation models converge on draft data
  because the at-risk population is smaller and denser.

### Pipeline results (draft config, 5% sample)

- `apc_data`: 4 datasets; initiation men ~1.6M rows, cessation men ~571K rows
- `apc_model_cessation_men`: converged (29 iter), fitted range 0–0.57, 2,833 cells
- `apc_model_cessation_women`: converged (29 iter), fitted range 0–0.43, 2,835 cells
- `apc_model_initiation_men`: non-convergent on 5% sample (sparse cells); 2,835 cells
- `apc_model_initiation_women`: non-convergent on 5% sample (sparse cells); 2,803 cells

### Validation checkpoint (pending — requires full PUMF)

Compare initiation prevalence curves against Manuel et al. (2020) Figure 1 after running on
full PUMF. Shape should match qualitatively (peak age 15–17; 1920s cohort highest; 2000s lowest).
