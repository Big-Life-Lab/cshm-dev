# LinkML data dictionary — scope and design

**Issue:** #16 in `protocol-todo.md`
**Status:** Draft schemas created — feedback requested on design questions
**Authors:** D. Manuel
**Date:** 2026-03-10

---

## What is this?

We need a machine-readable schema for the variables used in CSHM — both the CCHS survey
variables we harmonize from cchsflow and the derived APC variables we create. A schema:

- Documents what each variable is, where it comes from, and how it is coded
- Allows external collaborators to understand the data model without reading source code
- Enables automated validation (does the data match the schema?)
- Generates human-readable documentation for the project website

The proposed tool is [LinkML](https://linkml.io) — an open framework for data modelling
used by cchsflow v3 (PR #163). Aligning with cchsflow means we can reuse their class
definitions and inherit from their base schema.

---

## Background: current state

CSHM variables are currently defined in two CSV worksheets:

| File | Purpose |
|------|---------|
| `worksheets/cshm-variables.csv` | One row per study variable; `role` and `source` columns |
| `worksheets/cshm-variable-details.csv` | cchsflow-style recoding rules for cycles not yet in cchsflow v3 |

These worksheets are loaded by `_targets.R` (stage 1) and drive harmonization in stage 2
(`load_study_data()`). They work well for pipeline execution but lack:

- Formal type definitions and allowed values
- Descriptions readable by collaborators without R knowledge
- Machine-readable provenance (which CCHS cycles each variable appears in)
- Validation that the worksheets themselves are internally consistent

---

## Scope: three schemas

The CSHM schema is split into three files, each covering a distinct layer of the pipeline:

| File | Covers | Pipeline stage |
|------|--------|---------------|
| [`schemas/cshm-variables.yaml`](../../schemas/cshm-variables.yaml) | CCHS harmonization variables | Stages 1–7 |
| [`schemas/cshm-cohort.yaml`](../../schemas/cshm-cohort.yaml) | Synthetic cohort population | Stage 9 (simulation) |
| [`schemas/cshm-rate-tables.yaml`](../../schemas/cshm-rate-tables.yaml) | APC model output; shg-rcpp input | Stage 8–9 |

This separation means a cchsflow contributor can read `cshm-variables.yaml` in isolation
without needing to understand the simulation layer, and an shg-rcpp team member can
read `cshm-rate-tables.yaml` without knowing anything about CCHS harmonization.

### `cshm-variables.yaml` — what it covers

- All study variables in `worksheets/cshm-variables.csv`
- Two CSHM-specific fields not in cchsflow: `role` and `source`
- All other fields match cchsflow `variables.csv` exactly (same names, same meaning)
- cchsflow variables referenced by name via a `uses:` list, not redefined (option B)

### `cshm-cohort.yaml` — what it covers

- Synthetic person attributes: `birth_year`, `sex`, `province`, `weight`
- `SmokingHistoryRecord` — one row per person-age in the simulation output
- `SimulationRunMetadata` — provenance (config profile, rate table version, seed)

### `cshm-rate-tables.yaml` — what it covers

- Rate table rows: (model_type × sex × province × age × period) → conditional probability
- Confidence intervals (`rate_lower`, `rate_upper`)
- `RateTableMetadata` — provenance linking back to CCHS cycles and CSHM version
- `shgrcpp_compatible` flag indicating validation against shg-rcpp input spec

### What the schemas do NOT cover

- Raw CCHS variable names from all 231+ datasets (that is cchsflow's domain)
- Full cchsflow recoding rules (those remain in `variable_details.csv`)
- Statistical model internals (coefficient matrices, spline basis)

---

## Key design questions for collaborators

### Q1 — Relationship to cchsflow v3 schema *(open)*

cchsflow v3 (PR #163) is building a LinkML schema for the full cchsflow variable set.
CSHM should import from that schema rather than duplicate it.

**Options:**
- **A** — Wait for cchsflow PR #163 to merge, then import the stable schema
- **B** — Create a CSHM-only schema now (no import), migrate to import later
- **C** — Contribute CSHM requirements to cchsflow v3 PR #163 and develop in parallel

**Recommendation:** Option C. The CSHM-specific slots (`role`, `source`) are likely useful
to other cchsflow-based projects (DemPoRT, MPoRT, OnPoRT). Raising them in PR #163 could
benefit the broader ecosystem.

*Note: cchsflow v3 currently uses column-order YAML validators, not true LinkML, so the
PR #163 schema is not yet importable. Drafts proceed independently; import can be added
once PR #163 stabilises.*

### Q2 — Scope boundary: cchsflow variables *(resolved: option B)*

cchsflow variables used by CSHM (e.g., `SMKDSTY`, `DHHGAGE_cont`) are listed in a
`uses:` manifest in `cshm-variables.yaml` but not redefined. This makes the dependency
explicit without duplicating cchsflow's definitions.

### Q3 — Audience and documentation format *(resolved)*

Primary audience: health/epidemiology researchers. Documentation leads with plain-language
descriptions and code value labels (e.g., SMKDSTY = 1 "daily", 2 "occasional", ...).
Technical schema details are secondary. LinkML's `gen-doc` tool will generate this
documentation automatically from `description` fields in the schema.

### Q4 — Validation integration *(resolved: CI only)*

Schema validation (`linkml-validate`) runs in GitHub Actions (issue #14), not in the
`{targets}` pipeline. This avoids blocking `tar_make()` during development.

---

## Relationship to pipeline and config

### `_targets.R` stage 1 (current)

```r
tar_target(variables_sheet,
  read.csv(cfg$worksheets$variables)
),
tar_target(variable_details_sheet,
  rbind(
    read.csv(cfg$worksheets$cchsflow_variable_details),
    read.csv(cfg$worksheets$cshm_variable_details)
  )
),
```

With a LinkML schema, an optional validation step could be added here:
`linkml_validate(variables_sheet, schema = "schemas/cshm-variables.yaml")`.

### `config.yml` (relevant excerpt)

The `survey:` block maps conceptual roles to variable names:

```yaml
survey:
  sex: DHH_SEX
  age: DHHGAGE_cont
  smoking_status: SMKDSTY
  age_first_cigarette: age_first_cigarette
  years_since_quit: SMK_09A_cont
```

The schema would formally define each of these and link them to the `CshmVariable` class.

---

## Draft variable inventory (APC-relevant subset)

| Variable | Role | Source | APC use | Cycles |
|----------|------|--------|---------|--------|
| `DHH_SEX` | predictor | both | denominator | 1–11 |
| `DHHGAGE_cont` | predictor | both | denominator | 1–11 |
| `GEOGPRV` | predictor | both | denominator | 1–11 |
| `WTS_M` | weight | both | denominator | 1–11 |
| `SMKDSTY` | predictor | both | numerator + denominator | 1–11 |
| `age_first_cigarette` | derived-input | pumf | numerator | 1–11 |
| `SMK_09A_cont` | derived-input | pumf | numerator | 1–11 |
| `survey_year` | apc-internal | — | denominator | — |
| `cohort` | apc-internal | — | numerator + denominator | — |
| `period` | apc-internal | — | numerator + denominator | — |
| `age` | apc-internal | — | numerator + denominator | — |
| `init` | outcome | — | numerator | — |

---

## Next steps (proposed)

1. **Feedback from collaborators** — responses to Q1–Q4 above
2. **Survey cchsflow PR #163** — understand current LinkML class structure
3. **Draft `schemas/cshm-variables.yaml`** — start with APC-internal variables (no cchsflow
   dependency) then extend to harmonized inputs
4. **Generate docs** — integrate with `docs/reference/variables.qmd`
5. **CI validation** — add `linkml-validate` step to GitHub Actions (issue #14)
