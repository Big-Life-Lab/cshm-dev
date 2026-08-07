# APC implementation plan: Stages 7 and 8

**Status:** Ready for implementation (all design issues resolved)
**Covers:** Stage 7 (`apc_data`) and Stage 8 (`apc_models`)
**Source references:**
- `resources/legacy-code/Modeling2013.sas` (gitignored; SAS macros `%holford_init`, `%holford_cess`)
- `R/process_smoking_initiation.R` (pre-pipeline partial implementation — superseded)
- `docs/references/Manuel_HR_2020.md`
- `config.yml` APC section

---

## Overview and design principles

The APC stage transforms the imputed individual-level survey data (`analysis_data`) into transition
rate estimates by age, period (calendar year), and birth cohort. The output is a set of fitted
logistic regression models — one per sex per transition type — whose predictions feed directly
into Stage 9 (rate tables) and the `shg-rcpp` simulation engine.

Design principles:

1. **Config-driven:** All model parameters (knots, period range, cohort range, constraints,
   spline library) in `config.yml`. No hardcoded decisions in R code.
2. **Modular:** Each sub-function has one clear job and testable inputs/outputs.
3. **Tidyverse:** `dplyr`/`tidyr` throughout; no SAS-style year loops.
4. **Faithful to Holford:** The mathematical structure replicates Holford et al. (2014) and
   Manuel et al. (2020). Departures are explicit and documented.
5. **Stub-friendly:** Survival correction and cessation model can be stubbed independently
   without blocking the rest of the pipeline.

---

## Design issues and resolutions

### Issue 1: Age variable — DHHGAGE_cont midpoint imputation

**Problem:** `DHHGAGE_cont` uses midpoint-estimated ages (grouped categories), not exact ages.
This introduces measurement error in cohort assignment (`cohort = survey_year - age`).
The 2019–20 and 2022 cycles use only 5 age categories, producing especially coarse midpoints
(14.5, 26, 42, 57, 75). Artificial clumping at midpoints will affect the spline knot locations
and the smoothness of the fitted age effect — this is a known PUMF limitation.

**Resolution:** Accept `DHHGAGE_cont` as-is for the PUMF implementation. Document as a known
limitation. The Master file run (RDC) will use exact ages, and PUMF vs. Master results will
be compared in the sensitivity analysis. Note in `pipeline-progress.md` after Stage 7 is
complete.

### Issue 2: Survey year derivation

**Problem:** `SurveyCycle` is a factor code ("1"–"11"), not a calendar year. There is no
`survey_year` column in `analysis_data`. For 2-year CCHS cycles (e.g., "2007–08"), the exact
interview date is not available in PUMF.

**Resolution:** Add `cycle_survey_years` integer lookup to `config.yml` using the **midpoint
year** for 2-year cycles (e.g., 2008 for "2007–08"). This is consistent with SAS convention
and reduces systematic bias compared to first or last year. `derive_survey_year()` will be
the first step in `prepare_apc_data()`, joining `SurveyCycle` code to integer year.

See config additions section below for the full lookup table.

### Issue 3: Initiation age variable — confirmed available

**Confirmed from `analysis_data`:** `age_first_cigarette` is present in all 64,451 rows with
no tagged NAs — cchsflow v3 (PR #163) is active in this pipeline. However, the observed
range is **13–55**, not 8–55. Investigation revealed:

- `age_first_cigarette` uses coarser PUMF categories with a minimum midpoint of **13**
- `SMKG01C_cont` (also in `analysis_data`) has values starting at **8** and covers cycles
  2007–2018 (32,495 non-NA rows)
- The minimum initiation age in the SAS code is 8 (per Manuel 2020)

**Consequence:** Using `age_first_cigarette` alone will miss genuine early initiators (ages
8–12) captured in `SMKG01C_cont`. The effective floor difference means some early initiation
events will be wrongly classified as never-smokers in the initiation numerator.

**Resolution:** Use `age_first_cigarette` as the primary variable. Add a runtime check: if
`min(age_first_cigarette, na.rm=TRUE) > 10`, log a warning that early initiation ages may
be underrepresented due to PUMF category floors, and note the SMKG01C_cont floor of 8. This
does not affect the PUMF implementation but is a key reason why the RDC Master run is needed.
The `min_age_initiation` config parameter (= 8) still applies as a filter floor, but in
practice will only exclude values below 13 in PUMF.

### Issue 4: Cessation model — former occasional smokers excluded

**Decision:** Exclude former occasional smokers (SMKDSTY 5) from the cessation model,
consistent with Manuel et al. (2020). Cessation is modelled only for former daily smokers
(SMKDSTY 3 and 4) where `time_quit_smoking` (= `SMK_09A_cont`) is available.

**Rationale:** `SMK_06A_cont` (cessation timing for occasional smokers) is only available in
cycles 2001–2014 and is absent from 2015+, making consistent inclusion impossible across all
11 PUMF cycles.

**Flagged:** GitHub issue [#1](https://github.com/Big-Life-Lab/cshm-dev/issues/1) tracks this
for future work. Add a `# TODO: GH#1` comment in `build_cessation_data()` and a note in the
protocol (§3.4.2).

### Issue 5: Ontario flag — drop entirely

**Decision:** Drop `ont_id`. The existing `R/process_smoking_initiation.R` used this as an
Ontario-specific respondent identifier from the original SAS code. It has no role in the
national model. Use R's row identity (via `dplyr::mutate(person_id = row_number())` before
expanding) as the join key for the denominator construction.

### Issue 6: Denominator size — vectorised expansion with early filter

With ~65,000 respondents and a period range of ~57 years (1965–2022), the raw
`expand_grid(person, period)` would produce ~3.7M rows, which is manageable. However, the
at-risk filter must be applied **immediately after** the expand to prevent storing the full
cross-product in memory:

```r
# Correct: filter in the same pipeline step
expand_grid(person_id = data$person_id, period = period_range) |>
  left_join(data |> select(person_id, cohort, age_init, weight), by = "person_id") |>
  filter(period >= cohort + cfg$apc$min_age_initiation,   # alive and old enough
         period <= cohort + age_init)                     # not yet initiated
```

For the draft config (5% sample, ~3,200 respondents), this is ~185,000 rows — fast and safe.
For full PUMF (~1M respondents), this step will require testing for memory headroom.

### Issue 7: Period constraints — clamp before spline basis

**Approach:** Apply a "clamp" transform on `period` and `cohort` before constructing the
spline basis. This is the correct Holford data-side constraint: observations beyond the
constraint year receive the same spline basis values as at the constraint year, effectively
holding the period (or cohort) effect constant.

```r
period_clamped <- pmin(period, constraint_year)
cohort_clamped <- pmin(pmax(cohort, cfg$apc$cohort_constraints$initiation_prior_to),
                        cfg$apc$cohort_constraints$cessation_from)
```

This is a data transformation, not a model coefficient constraint. It is applied to both the
fitting data and the prediction grid in Stage 9.

Note in implementation: the constraint year is sex- and model-type-specific (`config.yml`
`period_constraints` section). `build_spline_basis()` must accept a `model_type` and `sex`
argument to select the correct constraint year.

### Issue 8: Spline identifiability — highest technical risk

The APC identity (`cohort = period − age`) means the three linear terms are perfectly
collinear. Holford's solution is to construct age, period, and cohort spline bases
independently, then remove the overall linear trend from one dimension to resolve the
identifiability problem. In the SAS code this is handled implicitly by `PROC GENMOD` with
a specific coding of the spline contrasts.

**Implementation plan for `splines2::nsp()`:**

1. Construct age basis: `nsp(age, knots = cfg$apc$age_knots, intercept = FALSE)`
2. Construct period basis: `nsp(period_clamped, knots = cfg$apc$period_knots, intercept = FALSE)`
3. Construct cohort basis: `nsp(cohort_clamped, knots = cfg$apc$cohort_knots, intercept = FALSE)`
4. Column-bind all three as the model matrix; fit with `glm(..., family = binomial)`

The `nsp()` natural spline already imposes linear constraints at the boundary knots, which
partially addresses identifiability. Whether this exactly replicates the Holford SAS
identifiability constraint needs **explicit validation** against Manuel 2020 results before
Stage 9. This is the primary validation checkpoint.

**Action:** After Stage 8 runs on the draft sample, compare predicted initiation prevalence
curves (by cohort, men and women) against Figure 1 of Manuel et al. (2020). Shape should
match qualitatively; exact values will differ (Ontario vs. national; 2003–13 vs. 2001–22).

---

## Proposed function structure

### Stage 7: `prepare_apc_data()`

**File:** `R/apc-model.R`
**Pipeline target:** `apc_data`
**Input:** `analysis_data` (output of `impute_data()`), `cfg`
**Output:** Named list: `initiation_men`, `initiation_women`, `cessation_men`, `cessation_women`

Each list element is a long data frame with one row per person-year observation (numerator +
denominator combined), ready to pass to `fit_apc_model()`.

```
prepare_apc_data(analysis_data, cfg)
  ├── derive_survey_year(data, cfg)
  │     # SurveyCycle code → integer year via cfg$cycle_survey_years
  │     # cohort = survey_year - round(DHHGAGE_cont)
  │     # Adds: survey_year, cohort columns
  │
  ├── build_initiation_data(data, cfg)
  │     ├── derive_initiation_status(data, cfg)
  │     │     # ever_smoker: age_first_cigarette is non-NA and >= min_age_initiation
  │     │     # never_smoker: age_first_cigarette is NA or < min_age_initiation
  │     │     # Restrict to cohort >= cfg$apc$cohort_min (1920)
  │     │     # Warn if min(age_first_cigarette) > 10 (Issue 3)
  │     │
  │     ├── build_initiation_numerator(init_data, cfg)
  │     │     # One row per initiator
  │     │     # age = age_first_cigarette
  │     │     # period = cohort + age
  │     │     # event = 1, weight = WTS_M
  │     │
  │     └── build_initiation_denominator(init_data, cfg)
  │           # person_id = row_number() before expand
  │           # expand_grid(person_id, period = seq(period_min, period_max))
  │           # left_join person attributes (cohort, age_init, weight)
  │           # Filter immediately:
  │           #   period >= cohort + min_age_initiation  (alive and old enough)
  │           #   period <= cohort + age_first_cigarette  (not yet initiated)
  │           # age = period - cohort; event = 0
  │
  ├── build_cessation_data(data, cfg)
  │     # Restricted to former daily smokers: SMKDSTY %in% c(3, 4)
  │     # age_cessation = DHHGAGE_cont - SMK_09A_cont (time_quit_smoking)
  │     # Filter: age_cessation >= min_age_cessation, cohort >= cohort_min
  │     # TODO: GH#1 — former occasional smokers (SMKDSTY 5) excluded here
  │     # Parallel numerator/denominator structure to initiation
  │
  └── apply_survival_correction(data, cfg)
        # Dispatches on cfg$apc$mortality_method
        # "peto": weight unchanged (multiply by 1.0)
        # "mport": stop("MPoRT correction not yet implemented")
```

**Columns in each output data frame:**

| Column | Description |
|--------|-------------|
| `age` | Age at transition (integer years) |
| `cohort` | Birth year (`survey_year − round(DHHGAGE_cont)`) |
| `period` | Calendar year of transition (`cohort + age`) |
| `event` | 1 = transition occurred; 0 = at-risk person-year |
| `weight` | Survey weight (WTS_M), survival-corrected |

Sex is used only as a split key — it is not a column in the model data frames.

---

### Stage 8: `fit_apc_model()`

**File:** `R/apc-model.R`
**Pipeline target:** `apc_models`
**Input:** One element of `apc_data` list, `model_type` ("initiation"/"cessation"), `sex` (1/2), `cfg`
**Output:** Fitted `glm` object with metadata attributes

```
fit_apc_model(apc_dataset, model_type, sex, cfg)
  │
  ├── build_spline_basis(apc_dataset, model_type, sex, cfg)
  │     # Select constraint years from cfg$apc$period_constraints (sex- and type-specific)
  │     # period_clamped = pmin(period, constraint_period)
  │     # cohort_clamped = clamp(cohort, cohort_prior_to, cohort_from)
  │     # age_basis    = nsp(age,            knots = cfg$apc$age_knots,    intercept=FALSE)
  │     # period_basis = nsp(period_clamped, knots = cfg$apc$period_knots, intercept=FALSE)
  │     # cohort_basis = nsp(cohort_clamped, knots = cfg$apc$cohort_knots, intercept=FALSE)
  │     # Dispatch on cfg$apc$spline_type: "nsp" (default) or "rcs" (sensitivity)
  │     # Return cbind(age_basis, period_basis, cohort_basis) with named columns
  │
  └── fit_binomial_apc(basis_matrix, event, weight)
        # glm(event ~ ., data = as.data.frame(basis_matrix),
        #     family = binomial, weights = weight)
        # attr(fit, "knots")       = list(age, period, cohort knots)
        # attr(fit, "constraints") = list(period_max, cohort_min, cohort_max)
        # attr(fit, "model_type")  = model_type
        # attr(fit, "spline_type") = cfg$apc$spline_type
        # Return fit
```

**Pipeline targets (Stages 7–8 in `_targets.R`):**

The denominator construction (Issue 6 — large expand_grid) must be a **separate target** from
the numerator. This allows `{targets}` to cache the denominator independently, avoiding a full
rerun when only model parameters (knots, constraints) change. The numerator is fast; the
denominator is the expensive step.

```r
# Stage 7a: Numerator (fast — one row per initiator/quitter)
tar_target(apc_numerator,
  build_apc_numerator(analysis_data, cfg)
),

# Stage 7b: Denominator (slow — expand_grid; cached independently)
# Candidate for parallelisation or DuckDB back-end (see note below)
tar_target(apc_denominator,
  build_apc_denominator(analysis_data, cfg)
),

# Stage 7c: Combine and apply survival correction
tar_target(apc_data,
  combine_apc_data(apc_numerator, apc_denominator, cfg)
),

# Stage 8: Fit models (four separate targets — each independently cached)
tar_target(apc_model_initiation_men,
  fit_apc_model(apc_data$initiation_men, "initiation", sex = 1, cfg)
),
tar_target(apc_model_initiation_women,
  fit_apc_model(apc_data$initiation_women, "initiation", sex = 2, cfg)
),
tar_target(apc_model_cessation_men,
  fit_apc_model(apc_data$cessation_men, "cessation", sex = 1, cfg)
),
tar_target(apc_model_cessation_women,
  fit_apc_model(apc_data$cessation_women, "cessation", sex = 2, cfg)
)
```

**Why separate targets for each model (Stage 8):** Each `fit_apc_model` call is independent.
Splitting them lets `{targets}` run them in parallel (via `tar_make_future()` or
`tar_make_clustermq()`) and avoids rerunning all four when only one model's inputs change
(e.g., after updating cessation constraints).

**Denominator optimisation options (Stage 7b):**

The `expand_grid` denominator is the most compute-intensive step (~3.7M rows full PUMF;
~185K rows on 5% draft). Two optimisation paths to consider:

1. **Parallelisation via `{future}`:** Split by sex or by cohort decade; run denominator
   construction in parallel using `future.apply::future_lapply()`. Simple to implement,
   no new dependencies.

2. **DuckDB back-end:** The denominator is essentially a cross-join filtered by a range
   condition — exactly the kind of operation DuckDB handles efficiently out-of-core.
   Using `{duckdb}` + `{dplyr}` via `dbplyr` would let the denominator expand stay
   on disk rather than in R memory. Recommended if full PUMF (~1M respondents × 57 years
   ≈ 57M rows pre-filter) proves slow or memory-limited.

   ```r
   con <- duckdb::dbConnect(duckdb::duckdb())
   dplyr::copy_to(con, analysis_data, "persons")
   apc_denom <- dplyr::tbl(con, "persons") |>
     tidyr::expand(person_id, period = seq(period_min, period_max)) |>
     dplyr::filter(period >= cohort + min_age, period <= cohort + age_init) |>
     dplyr::collect()
   ```

**Recommendation:** Start with the simple in-memory `expand_grid` on draft/dev config.
If the full PUMF denominator is slow (>30 seconds), add parallelisation first; DuckDB if
memory is the constraint. Config flag `cfg$apc$denominator_backend: "memory"` (default) or
`"duckdb"` can select between implementations without changing the function interface.

---

## Config additions required

**Survey portability note:** All variable names that map conceptual roles to actual column
names in the harmonized data are grouped under `cfg$survey` in `config.yml`. To adapt the
pipeline to a new survey (e.g., NHIS for the US, ELSA for the UK), a researcher modifies
`config.yml`'s `survey:` block plus the `variables.csv` and `variable_details.csv`
worksheets — no R code changes required. The APC functions reference
`cfg$survey$sex`, `cfg$survey$age`, `cfg$survey$smoking_status`, etc.

Add to `config.yml` default profile (under `apc:` and at top level):

```yaml
  apc:
    # existing: age_knots, period_knots, cohort_knots, period_constraints,
    #           cohort_constraints

    # Period range for denominator construction
    period_min: 1965
    period_max: 2022          # statscan profile: 2023

    # Cohort range
    cohort_min: 1920          # already in cohort_constraints; add explicit key here

    # Age floors
    min_age_initiation: 8
    min_age_cessation: 8

    # Spline implementation
    spline_library: "splines2"
    spline_type: "nsp"        # sensitivity analysis: "rcs"

    # Mortality correction
    mortality_method: "peto"  # primary; sensitivity: "mport"

    # Subgroups
    subgroups:
      national:
        stratify_by: [DHH_SEX]
      provincial:
        stratify_by: [GEOGPRV, DHH_SEX]

# Survey year lookup — integer year per SurveyCycle code
# 2-year cycles use midpoint year (e.g. 2008 for "2007-08")
cycle_survey_years:
  "1":  2002    # 2001
  "2":  2003
  "3":  2005
  "4":  2008    # 2007-08
  "5":  2010    # 2009-10
  "6":  2012    # 2011-12
  "7":  2014    # 2013-14
  "8":  2016    # 2015-16
  "9":  2018    # 2017-18
  "10": 2020    # 2019-20
  "11": 2022
```

---

## Relationship to existing code

### `R/process_smoking_initiation.R`

Pre-pipeline partial implementation — **do not incorporate**. Key incompatibilities with
current pipeline:

| `process_smoking_initiation.R` | Current pipeline |
|---|---|
| `ont_id` (Ontario identifier) | Not applicable — national model |
| `cchsbdate` (Date object) | Not in `analysis_data` |
| `sex` coded "M"/"F" | `DHH_SEX` coded 1/2 |
| Uses `SMK_01A` directly | Uses harmonized `SMKDSTY` |
| `init_date` with random day-within-year | Not needed — age is integer |
| Cohort = format(cchsbdate, "%Y") | Cohort = survey_year − age |

**Disposition:** Move to `R/legacy/` after Stage 7 passes unit tests.

### `R/legacy/smoking.R`

Contains cchsflow helper functions (`time_quit_smoking_fun`, `smoke_simple_fun`,
`pack_years_fun`). These run during `load_study_data()` (Stage 2) inside `rec_with_table()`.
No changes needed for Stage 7.

---

## Testing strategy

### Unit tests — Stage 7 (`tests/testthat/test-apc-data.R`)

| Test | Checks |
|------|--------|
| `test_derive_survey_year` | Correct integer year for all 11 SurveyCycle codes |
| `test_cohort_assignment` | `cohort = survey_year − round(age)`; range 1920–2010 |
| `test_initiation_min_age` | No numerator rows with `age < 8` |
| `test_initiation_cohort_floor` | No rows with `cohort < 1920` |
| `test_denominator_at_risk_only` | Denominator rows stop at `age_first_cigarette` for each person |
| `test_denominator_period_bounds` | All `period` in `[period_min, period_max]` |
| `test_no_missing_weight` | `weight` never NA in any output element |
| `test_cessation_smkdsty_filter` | Only SMKDSTY 3 and 4 in cessation data |
| `test_age_first_cigarette_warning` | Warning logged when min < 10 (Issue 3) |

### Unit tests — Stage 8 (`tests/testthat/test-apc-model.R`)

| Test | Checks |
|------|--------|
| `test_spline_basis_ncol` | Correct column count for given knot vectors |
| `test_period_clamping` | No `period > constraint_year` in basis input |
| `test_cohort_clamping` | Cohort clamped at both bounds |
| `test_fit_class` | Output is `glm` with `binomial` family |
| `test_fitted_range` | All fitted values in (0, 1) |
| `test_model_attributes` | `attr(fit, "model_type")` etc. attached |

### Integration / validation checkpoint (after Stage 8)

Run on draft config (5% sample) and verify qualitatively against Manuel et al. (2020) Figure 1:

- Initiation prevalence curves peak at ages 15–17 (women) and 16 (men)
- 1920s cohort peaks highest; 2000s cohort peaks lowest and latest
- Cessation probabilities increase monotonically with age
- Fitted values are flat beyond the period constraint year (visible in predicted grid)

This is the primary go/no-go checkpoint before Stage 9. If the shape of the initiation
curves does not match Figure 1 qualitatively, the spline identifiability constraint (Issue 8)
needs further work before proceeding.

---

## Implementation sequence

1. Update `config.yml` with `cycle_survey_years` and APC range params
2. Implement and test `derive_survey_year()`
3. Implement `build_initiation_numerator()` + unit tests
4. Implement `build_initiation_denominator()` + unit tests (test on small synthetic data)
5. Implement `build_cessation_data()` (parallel structure; reuse sub-functions)
6. Implement `apply_survival_correction()` — Peto stub
7. Wire up `prepare_apc_data()`; run Stage 7 target; update `pipeline-progress.md`
8. Implement `build_spline_basis()` with `splines2::nsp()`
9. Implement `fit_binomial_apc()` + unit tests
10. Wire up Stage 8 targets; run on draft config
11. **Validation checkpoint:** Compare fitted initiation curves against Manuel 2020 Figure 1
12. Update `pipeline-progress.md`; move `process_smoking_initiation.R` to `R/legacy/`
