# CSHM remediation plan

**Status:** draft for review · 2026-08-05
**Basis:** three-pass review of `Big-Life-Lab/cshm-dev` @ `74ba453` (pipeline/analysis, engineering practice, metadata/schema/config). Full findings in `cshm-dev-review.md`.
**Purpose:** sequence the fixes so results become trustworthy, then make the metadata/config layer a genuine reusable spine ready to receive DemPoRT's modelling machinery.

---

## Framing

Three principles shape the ordering.

**1. Nothing can be verified today.** `renv::restore()` fails on 193 packages, so the pipeline cannot run; no CI executes the tests. Every correctness fix would land blind. Verification infrastructure is therefore Phase 0, not a "practice" afterthought — and it pays for itself immediately, because each Phase 1 fix has a one-line invariant test that is worthless until something runs it.

**2. Several items are protocol amendments, not bug fixes.** CSHM's prespecification discipline is its best feature; changing methodology silently in code would undercut it. Every Phase 1 item below carries an explicit **protocol call**: fix the code to match the protocol, or amend the protocol with recorded rationale. Note that divergences run in both directions — the protocol specifies knots the code doesn't use, and `docs/reference/model.qmd` describes a constraint scheme that exists nowhere.

**3. The flow between repos is bidirectional.** CSHM is the stronger spine, but DemPoRT already solves several things CSHM gets wrong. Marked **[←DemPoRT]** where we port *from* DemPoRT, **[→DemPoRT]** where CSHM's pattern should propagate the other way.

---

## Phase 0 — Make verification possible

*Blocks everything. Target: a fresh clone runs green CI and completes a draft-profile pipeline run.*

| # | Task | Notes |
|---|---|---|
| **0.1** | Pin `cchsflow` to a git SHA (v3, `bd0df3ac`) and `docstyle` likewise; regenerate `renv.lock` with `Hash` fields; switch repo to HTTPS (`packagemanager.posit.co` / `cloud.r-project.org`) | Lockfile currently records `Source: Local`, `RemoteUrl: ~/github/cchsflow`, version 2.1.0 — the *wrong* version, by path, on one laptop. 0/193 packages carry hashes. **[→DemPoRT]** same defect there |
| **0.2** | Verify `renv::restore()` on a clean machine or container | Acceptance gate for 0.1 — not "it works here" |
| **0.3** | CI: run `testthat::test_dir()` | 33 tests exist and nothing runs them |
| **0.4** | CI: lint/styler check | Mandated by `CONTRIBUTING.md:141`, verified by nothing |
| **0.5** | CI: `quarto render` check | Would have caught 0.7 on the introducing commit |
| **0.6** | CI: draft-profile pipeline smoke test | Committed 100–200-row samples make a real end-to-end run cheap. Declare them as fixtures (`tests/fixtures/`, un-ignored, documented) rather than leaving them ignored-but-tracked |
| **0.7** | Fix `_quarto.yml` render list (`render: - "!manuscript/"` matches zero files) and add a Pages deploy workflow | Docs site currently builds nothing and 404s |
| **0.8** | Make `tests/testthat/setup.R` sourcing match `tar_source()` (recursive), or move `R/legacy/` out of `R/` | Test and pipeline environments currently differ; six legacy names collide with cchsflow exports |

**Phase 0 acceptance:** fresh clone → `renv::restore()` succeeds → CI green → `R_CONFIG_ACTIVE=draft targets::tar_make()` completes → docs site publishes.

---

## Phase 1 — Scientific correctness

*Each task lands **with** its regression test. Each carries a protocol call.*

### 1.1 Tagged-NA preservation **[←DemPoRT]** — no protocol change
`as.factor()` at `R/study-data.R:108-109` collapses NA(a)/NA(b)/NA(c) to plain `NA`, so the entire categorical half of the imputation model silently does nothing, Table 1 reports n=0 missing on every categorical row, and NA(b) ever-smokers are misclassified as never-smokers.
- Port `DemPoRT-V2-dev/R/create-study-data.R:83-97` (encode tags as strings before `as.factor()`) plus a `fix_na_c()` equivalent.
- **Test:** round-trip starting from `rec_with_table()` output (or a tagged-NA double), *not* a pre-built factor — the current tests miss this precisely because they hand-build the representation the pipeline never produces.
- **Protocol call:** none — this is unambiguously a bug against stated intent.

### 1.2 Initiation period window — **protocol decision required**
Numerator periods start 1933; the denominator spans 1965–2022, so 26% of weighted events sit in cells with no denominator and fitted probability exactly 1.0.
- **Option A (SAS-consistent):** set `period_min = cohort_min + min_age` so the windows coincide. Preserves pre-1965 cohorts.
- **Option B:** filter the numerator to `period >= period_min`, accepting loss of early cohorts.
- **Recommendation: A** — it matches the reference implementation and preserves the cohorts the study exists to reconstruct. `period_min: 1965` currently relates to nothing else and reads like a leftover.
- **Test:** every numerator cell has a matching denominator cell.
- **Protocol call:** amend — record the period-window definition and rationale.

### 1.3 Cessation at-risk definition — **protocol decision required**
`survey_bound(cfg, "years_since_quit", "min")` returns `0` — a *duration* — and is used as an *age*, so person-years accrue from birth. 23% of weighted person-years are structurally impossible, cohort-dependently.
- Add explicit `apc: min_age_initiation` / `min_age_cessation` config keys (the `apc-plan.md` design called for these; `survey_bound()` silently replaced them with a dimensionally different quantity).
- Give `expand_denominator()` a per-person `age_denom_min` fed by `age_start_smoking` (already loaded, roled, imputed — and never used).
- **Test:** `min(cessation_denominator$age) >= min_age_cessation`; no person-year precedes that person's daily-initiation age.
- **Protocol call:** amend — state that the cessation clock starts at daily initiation, and fix the age-8 floor the protocol claims but the code doesn't enforce.

### 1.4 APC identification — **protocol decision + validation gate**
`period == age + cohort` exactly, so the design matrix is rank-deficient by one (verified: rank 13 of 14); `glm(singular.ok = TRUE)` silently aliases a coefficient. Identification is currently achieved implicitly by a handful of clamped observations — unverified. `docs/reference/model.qmd:24` describes a different scheme that exists nowhere.
- **1.4a (immediate):** `stop()` in `fit_apc_model()` if `any(is.na(coef(fit)))` or `fit$rank < ncol(basis) + 1`; record `fit$rank` in attributes. Do this now regardless of 1.4b.
- **1.4b:** implement the Holford orthogonalization to the linear trend (`Modeling2013.sas:293-358`), separating identifiable curvature from non-identifiable linear drift.
- **Acceptance gate:** validate against Manuel 2020 Figure 1, as `apc-plan.md:453-464` already specifies. **Nothing publishes before this passes.**
- **Protocol call:** amend — state the identification strategy explicitly, and correct `docs/reference/model.qmd`.

### 1.5 Knot semantics — **protocol decision required**
Holford's five knots are *all* the knots (4 df); `splines2::nsp()` treats them as interior and adds boundaries (6 df), with different extrapolation. `interior_knots()` then silently drops out-of-range knots, so **df varies by stratum and initiation/cessation models are not comparable to each other** — and the prespecified knot list in the protocol is not what gets fitted.
- Decide whether config knots are boundary-inclusive (Holford) or interior; set `Boundary.knots` explicitly; turn the silent drop into a `stop()` or an explicit per-model knot list.
- **Protocol call:** reconcile — either the code or the protocol is wrong; record which.

### 1.6 Uncertainty — **protocol decision required**
Summed survey weights (~10⁴/respondent) are passed as binomial counts, so every SE/CI is too small by roughly the mean weight (~100×). The protocol promises bootstrap-propagated error and the rate-table schema specifies CIs from the coefficient covariance matrix — currently meaningless. Compounded by Stage 8 fitting `datasets[[1]]` only, and by `person_id` being discarded so no person-level bootstrap is possible.
- Choose: design-based (`svyglm`/replicate weights) or person-level bootstrap. **Retain `person_id` in Stage 7 output either way** — that is a prerequisite, not an option.
- Add Rubin pooling across the *m* imputations.
- **Protocol call:** amend — specify the variance approach concretely.

### 1.7 Mortality adjustment — **protocol decision required**
`"peto"` returns weights unchanged and is the configured default, while README states survival bias *is* corrected. Survivor bias is the reason a retrospective design needs the adjustment.
- Implement the SAS survival-probability correction, **or** rename to `"none"` and state the limitation in the protocol and README.
- **Recommendation:** rename now (honesty is free), implement as scheduled work.

### 1.8 Smaller correctness items
- **Ever-smokers with missing/out-of-range initiation age** are reclassified as never-initiating rather than dropped — biases the initiation hazard cohort-dependently. SAS drops them. Also resolves the PUMF age-8 category question flagged as open at `config.yml:159-161`. *Protocol call: decide and record.*
- **Data cleaning truncates event-timing variables** (`age_first_cigarette`, `time_quit_smoking_daily`) because they share the `predictor` role — a covariate rule applied to outcomes. Fix by role separation.
- **Imputation congeniality:** every smoking-history variable is excluded from the predictor matrix as "structural", so initiation age is imputed from age/sex/cycle/weight alone. Appendix D's congeniality claim is not currently true. Fix with universe-nested predictors (the `where` matrix already makes this feasible).
- **Unseeded `sample()`** (`R/study-data.R:72-75`) makes dev/draft runs irreproducible; **missing cycle files warn and continue**, silently changing the analysis population.

---

## Phase 2 — Make the spine real

*The metadata layer is excellent as documentation and enforces nothing. Good news: the schemas are tooling-clean LinkML — the gap to enforcement is one adapter plus one CI step.*

| # | Task | Notes |
|---|---|---|
| **2.1** | Commit the comma-split serialization adapter and run `linkml-validate` in CI | Currently the schema fails on **all 72 rows** because `role` is `multivalued` but stored comma-separated. Adapter is ~10 lines and validates cleanly once applied. Make the adapter *part of the specified contract* |
| **2.2** | Port role validation at sheet import **[←DemPoRT]** | `import_variables_sheet()` validates every token and stops; CSHM uses plain `read.csv`, so a typo'd role passes silently |
| **2.3** | Make `source` required in the schema (or make loaders fail loudly when it's missing) | Schema says optional; pipeline silently drops those rows |
| **2.4** | Correct the false claims | "exactly three additions" (nine); `apc-numerator` drives Stage 7 (it doesn't); "single source of truth"; "generated from the machine-readable schemas" (520 hand-written lines); the **reversed sex-specific period constraints** in `docs/reference/variables.qmd`; variable-details loading description; data-path mismatch |
| **2.5** | Document that refreshing the cchsflow snapshot requires column reconciliation | 16 upstream vs 23 in-repo — a naive refresh per `config.yml:47-50` **breaks `rbind()` at pipeline start** |
| **2.6** | Replace hardcoded names in `R/imputation.R:109-111` with `survey_var()` calls | Violates config.yml's own stated rule; silently voids the design-predictor guard under a new survey |
| **2.7** | Extend the protocol-version workflow to `schemas/**`, `config.yml`, and the worksheets; add semver-monotonicity and "history entry added" checks; **add branch protection making it a required check**; delete the `--depth=1` line | The check currently guards the wrong boundary, verifies change rather than correctness, has a reproduced latent hard-fail, and is not enforced at all |
| **2.8** | Schema for `cshm-variable-details.csv` | Highest-drift artifact in the system, zero schema — recode micro-syntax is where recode errors become data errors |
| **2.9** | Single cycle table in config (code, dataset, label, year) | Currently four copies, one of them in R code |
| **2.10** | Fix dead config keys; make `age_exclusion_min` absence a hard error; make the `default` profile safe-by-default | ~¼ of keys are inert, teaching users that config edits do nothing. The profile you get by forgetting `R_CONFIG_ACTIVE` is the *least-checked full run* |
| **2.11** | Schema hygiene | `range: integer` on `projection_horizon`; enums for `mortality_correction`/`data_source`; `identifier: false` on `person_id` in `SmokingHistoryRecord`; histories container class; shared `cshm-core.yaml` for SexEnum/ProvinceEnum; patterns on `variableStart`/`version`/`lastUpdated` |

---

## Phase 3 — Prepare for the splice

*Structural work that must precede merging DemPoRT's machinery.*

**3.1 Value-code semantics layer.** The single highest-leverage abstraction for "reusable beyond CCHS". `survey_var()` maps *names*; code *meanings* are hardcoded (ever-smoker `1:5`, ever-daily `c(1,2,4)`, `sex == 1/2`), and the tagged-NA encoding is re-implemented in three files. A new source passing the rename test will silently misclassify every smoker. Add a `codes:` map alongside the name map, plus one centralized missingness utility **[←DemPoRT `R/is-na.R`]**. DemPoRT's Fine–Gray event coding hits the identical wall.

**3.2 `tar_map()` restructure.** `tarchetypes` is loaded and never used; four Stage 8 targets are copy-paste over `transition × sex`, and the declared `provincial` subgroups would need 52 — while `cfg$apc$subgroups` is read by no R file. Also split `apc_data` per stratum so a cessation change doesn't invalidate initiation fits. **Prerequisite for receiving DemPoRT's config-first machinery** — and the same gap exists on DemPoRT's side.

**3.3 Stage 7 output contract.** Schema the APC dataset (`age, cohort, period, event, weight`, plus `person_id` from 1.6) — currently documented only in a docstring. **This is the exact interface DemPoRT's modelling machinery splices against.**

**3.4 Merged role vocabulary.** Proposal from the audit: core/reserved roles (`id`, `design`, `intermediate`, `predictor[:base|:extension]`, `model-stratifier`, `imputation-predictor`, `row-stratifier:<var>`, `descriptive`, `sensitivity-analysis`, `sub-group`) framework-owned and schema-validated; study roles namespaced (`apc:numerator`) in a per-study sheet extending a framework core sheet; roles.csv as generative authority with the LinkML enum and docs tables *generated* from it; per-role metadata (`roleGroup`, `critical` — replacing the hardcoded criticality list — and `consumedBy`, which makes decorative roles visible). Keep DemPoRT's parameterised-role pattern, but validate the parameter against the sheet's `variable` column. Note a plain LinkML enum cannot express parameterised values, so enforcement lives in the roles.csv check.

---

## Decisions required before the splice

These are design calls, not tasks. Each blocks Phase 3.

1. **The resolution boundary.** Roles select variable *sets*; `survey:` keys resolve *identities*; nothing else. Then either wire `apc-numerator`/`apc-denominator` or demote them to study roles with `consumedBy: none`. Splicing without this produces a hybrid nobody can reason about — DemPoRT's transformations are worksheet-driven, CSHM's model stage is config-driven.
2. **The framework contract:** "CSV + prose conventions" or "LinkML-validated data"? If the latter, the serialization adapter is part of the contract.
3. **Sheet format:** stay cchsflow-shaped for ecosystem interchange, or become the framework's own format with a documented mapping? The nine-column extension currently leaves this ambiguous.
4. **Truncation philosophy:** DemPoRT declares it per-variable via role; CSHM decides behaviourally via skewness threshold. A spliced pipeline cannot honour both silently.
5. **Multi-environment execution model** (RDC / ICES) — see below.

---

## Cross-cutting: the remote-environment problem

**This deserves its own workstream.** The `statscan` profile cannot work — four independent breaks, verified empirically: config load errors outright; RDC paths land in `cfg$local_config$*` which nothing reads; `data_source` never switches to `master`, so all seven master-only variables are silently dropped; and cycle naming matches neither the documented convention nor the code.

It matters disproportionately because (a) it is the environment producing the definitive estimates, (b) RDC iterations are expensive and vetted, and (c) **DemPoRT has the identical need at ICES**. Fix it here, CI-test both profiles (a 5-line script catches the load error), and design the result as the shared pattern — including the `config/<env>.yml.example` + gitignored-real-file convention, which is clean and verified to leak nothing **[→DemPoRT]**.

---

## What goes to external review

An external model won't have the repo, so give it the review report, this plan, and the specific code excerpts plus the SAS reference — and scope it to **methodology only**:

1. **APC identification (1.4)** — is the Holford orthogonalization the right approach, and is the Manuel 2020 figure a sufficient acceptance gate?
2. **At-risk definitions (1.2, 1.3)** — the initiation period window and the cessation clock start.
3. **Uncertainty (1.6)** — design-based vs person-level bootstrap for a weighted retrospective APC model.
4. **Mortality/survivor-bias adjustment (1.7)** — what is defensible if the SAS correction isn't reimplemented.
5. **Imputation congeniality (1.8)** — universe-nested predictors for structurally-missing smoking histories.

It will have nothing useful to say about CI configuration or lockfiles; don't spend its attention there.

---

## Sequencing summary

```
Phase 0 (verification)  ──► Phase 1 (correctness) ──► publishable results
        │                            │
        └────────────────────────────┴──► Phase 2 (spine) ──► Phase 3 (splice-ready)
                                                    │
                              Decisions 1–5 ────────┘
```

Phase 0 is a prerequisite for trusting anything in Phase 1. Phase 2 can proceed in parallel with Phase 1 once Phase 0 lands — different files, different risk. Phase 3 waits on the five decisions.
