# Protocol and programming issues for future resolution

Issues identified during APC design (2026-03-09) that require future decisions or implementation work.
See `apc-plan.md` for the full APC design spec.

---

## Programming issues

### 1. Never-smoker placeholder in `age_first_cigarette`

**Description:** Never-smokers (SMKDSTY = 6) are top-coded with `age_first_cigarette = 55` in the
PUMF. This value is a placeholder, not a real initiation age. Without an explicit filter,
never-smokers will silently enter the initiation numerator with age = 55.

**Fix required:** Filter `SMKDSTY %in% c(1, 2, 3, 4, 5)` before constructing the initiation
numerator in Stage 7. Add assertion: `stopifnot(!any(apc_numerator$init_status == 1 & SMKDSTY == 6))`.

**Status:** Not yet implemented. Must be resolved before Stage 7 target is complete.

---

### 2. Implausible initiation ages

**Description:** 253 respondents have `age_first_cigarette > DHHGAGE_cont` (i.e., their reported
age of first cigarette exceeds their current age). These are measurement errors. Retaining them
will distort cohort curves for recent birth cohorts.

**Fix required:** Add plausibility filter: `age_first_cigarette <= age`. Log count of excluded rows.
Consider sensitivity analysis with and without the filter.

**Status:** Not yet implemented.

---

### 3. Territorial and small-province sample sizes

**Description:** APC models require sufficient N to estimate age, period, and cohort effects
independently. Territories (Yukon, NWT, Nunavut) have very small PUMF samples. PEI may also
be borderline. APC models fitted on small samples produce unstable or unidentifiable estimates.

**Fix required:** Define minimum sample size threshold (suggested: N ≥ 500 ever-smokers per sex).
Territories below threshold: pool into a single "territories" stratum or report national model
only. Decision rule must be specified before Stage 8 for provincial stratification.

**Status:** Threshold and pooling rule not yet defined. See protocol issue #10 below.

---

### 4. Survey weights and MPoRT mortality double-adjustment

**Description:** The CCHS sampling weights (`WTS_M`) already account for survey design and
post-stratification. If the MPoRT mortality correction also reweights respondents, this could
create a double-adjustment. The Peto method (weight × 1.0) avoids this issue.

**Fix required:** Clarify MPoRT weight adjustment mechanism before enabling `mortality_method: "mport"`.
Document the interaction in the protocol (§3.4.3).

**Status:** MPoRT stub raises `stop()`. Peto is the default. Revisit when MPoRT is implemented.

---

### 5. `SurveyCycle` is a factor

**Description:** `SurveyCycle` in `analysis_data` is a factor variable, not an integer.
`as.integer(SurveyCycle)` returns factor level codes (1, 2, ...) — which happen to be correct —
but the mechanism is fragile and undocumented. `as.character()` + lookup via `cfg$cycle_survey_years`
is the correct approach.

**Fix required:** In `derive_survey_year()`, use `as.character(SurveyCycle)` as the lookup key.
Add a unit test confirming correct year derivation for cycle "10" (2019–20 → 2020).

**Status:** `derive_survey_year()` not yet written. Must use `as.character()`.

---

### 6. Cohort ceiling

**Description:** 1,728 respondents (draft, 5% sample ≈ ~35,000 full sample) were born in 2000
or later. These respondents have at most 22 observation years. Fitting APC curves through
very recent birth cohorts introduces instability at the cohort ceiling and can distort
estimates for adjacent cohorts.

**Fix required:** Add `cohort_max` config parameter (suggested: 1999 or 2000). Exclude respondents
born after `cohort_max` from APC numerator and denominator. Evaluate sensitivity to this cutoff.

**Status:** Not yet implemented. Add to `config.yml` under `apc:`.

---

### 7. Cessation plausibility filter

**Description:** 20 former daily smokers have cessation age below `min_age_cessation` (8), and
2 have negative cessation ages (derived from `SMK_09A_cont`). These are data artefacts.

**Fix required:** Apply `time_quit_smoking >= 0` and `(age - time_quit_smoking) >= min_age_cessation`
filters when constructing the cessation numerator. Log count of excluded rows. Use
`cfg$apc$min_age_cessation` (currently 8) as the threshold.

**Status:** Not yet implemented. Must be resolved before Stage 7 target is complete.

---

## Protocol issues

### 8. Survey weights methodology (§3.4.4)

**Description:** §3.4.4 of the study protocol contains a `<!-- TBA -->` placeholder. The
methodological question — whether to use `WTS_M` directly in the logistic regression or to
incorporate survey design (strata, clusters) via `{survey}` — is unresolved.

The Manuel et al. (2020) paper used `WTS_M` as a case weight in logistic regression (not complex
survey design). This is simpler but may underestimate standard errors.

**Decision required:** Confirm whether to use simple case weights (`WTS_M` in `glm()`) or full
complex survey design (`svyglm()` from `{survey}`). Document rationale in §3.4.4.

**Status:** Placeholder in protocol. Discuss with co-authors (Garner, Diasparra) before Stage 8.

---

### 9. Period constraint years justification

**Description:** The APC model applies period effect constraints: initiation women fixed from 1999,
initiation men fixed from 2003, cessation fixed from 2013. These years are taken from Manuel et al.
(2020) but the rationale is not documented in the protocol.

The years reflect the observed plateau/decline in smoking initiation rates from survey data —
i.e., no further period trend after those years. However, this should be explicitly stated and
supported with citations or data references.

**Fix required:** Add a paragraph to §3.4.2 or §3.4.3 explaining constraint year selection and
citing Manuel et al. (2020) Table 1 / Figure 2.

**Status:** Not yet documented in protocol.

---

### 10. Territorial pooling strategy

**Description:** §3.4.6 states that small sample sizes in provinces/territories "may require
pooled CCHS cycles or adjusted model constraints" but does not specify the decision rule.
This is ambiguous for implementation.

**Decision required:** Define:
1. Minimum N threshold for fitting a province-specific APC model (e.g., N ≥ 500 ever-smokers)
2. Pooling strategy for territories below threshold (e.g., pool into "territories" region vs.
   national model only vs. Bayesian shrinkage)
3. Whether pooled cycles (e.g., all 11 cycles) are used for low-N provinces or only the
   most recent 5 cycles

**Status:** Decision rule needed before Stage 8 provincial stratification. Discuss with co-authors.

---

## Public readiness

Issues to address before making the repository public or seeking external collaborators.

### 11. Clean git history of committed data and config files (P0)

**Description:** Sensitive or large files were committed to git history in earlier branches:
`data/dev/*.RData` (PUMF extracts), `config/secure.yml` (credentials), and
`config/variables/*.csv` (variable sheets since moved to `worksheets/`). These remain in git
history even after deletion.

**Fix required:** Run `git filter-repo` (or BFG Repo Cleaner) to remove these paths from all
history before making the repository public. Alternatively, confirm with co-authors that PUMF
data under the Statistics Canada Open Licence may be redistributed, then document the decision.
Update `.gitignore` to prevent re-addition.

**Status:** Must be resolved before any public GitHub release.

---

### 12. `CODE_OF_CONDUCT.md` (P1)

**Description:** `CONTRIBUTING.md` references a Code of Conduct but no `CODE_OF_CONDUCT.md`
file exists in the repository. GitHub displays a warning and contributor badges are suppressed.

**Fix required:** Add `CODE_OF_CONDUCT.md`. Recommended: Contributor Covenant v2.1
(standard for health research open-source projects; used by cchsflow, DemPoRT-V2).

**Status:** File missing.

---

### 13. `CITATION.cff` (P1)

**Description:** No machine-readable citation file exists. GitHub uses `CITATION.cff` to
populate the "Cite this repository" button. Without it, users cannot easily generate
citations in APA, BibTeX, or AMA format. Zenodo DOI integration also requires this file.

**Fix required:** Create `CITATION.cff` with authors (Manuel, Wilton, Bennett, ...), title,
version, DOI (once deposited), and preferred citation pointing to Manuel et al. 2020.

**Status:** File missing. Create after first tagged release.

---

### 14. GitHub Actions: automated testing and documentation deployment (P1)

**Description:** No CI/CD workflows exist. Without automated testing on push, contributors
may break the pipeline or tests without realising. Without an automated docs deploy,
the Quarto site at GitHub Pages requires manual `quarto render` and push.

**Fix required:**
1. `testthat` workflow — run `testthat::test_dir("tests/testthat/")` on push to `main` and
   on all pull requests (use `r-lib/actions/setup-r@v2` + renv pattern from `CLAUDE.md`)
2. Quarto docs deploy — render on push to `main` and deploy to `gh-pages` branch
   (use `quarto-actions/publish` action)

**Status:** `.github/workflows/` directory does not exist.

---

### 15. GitHub issue and PR templates (P2)

**Description:** No issue templates or PR template exist. Without templates, external
contributors submit incomplete bug reports or feature requests, increasing maintainer triage
burden.

**Fix required:**
- `.github/ISSUE_TEMPLATE/bug_report.md` — steps to reproduce, R version, config profile
- `.github/ISSUE_TEMPLATE/feature_request.md` — motivation, proposed solution
- `.github/pull_request_template.md` — checklist: tests added, `renv::snapshot()` run,
  protocol issue referenced (if applicable)

**Status:** Directory `.github/ISSUE_TEMPLATE/` does not exist.

---

### 16. LinkML data dictionary (P1)

**Description:** The project has no machine-readable schema for its variables. cchsflow v3
uses LinkML for its variable schema; CSHM extends cchsflow and should align to the same
framework. Without a schema, external collaborators cannot validate variable definitions,
understand coding conventions, or reuse the data model.

**Audience:** General public in health and epidemiology (not data engineers); documentation
should be readable without LinkML expertise.

**Fix required:**
1. Survey the cchsflow v3 LinkML schema (PR #163) to understand class/slot structure
2. Create `schemas/cshm-variables.yaml` — LinkML schema defining CSHM-specific variables
   and extensions to the cchsflow base schema
3. Document the schema in `docs/reference/variables.qmd`
4. Add validation step to CI (LinkML `gen-doc` or `linkml-validate`)

**Design principles:**
- Inherit from cchsflow base schema where possible (reuse `Variable`, `VariableDetails` classes)
- CSHM-specific slots: `role` (predictor/outcome/derived-input/weight/id),
  `data_source` (pumf/master/both), `apc_use` (numerator/denominator/neither)
- Human-readable documentation auto-generated from schema

**Status:** No schema file exists. Depends on cchsflow v3 LinkML schema stabilising (PR #163).
