# Age and duration ranges: what the protocol says, what the references used, what the worksheet gives

Working note, 2026-08-28. Written so the protocol can be made explicit about minimum and maximum ages for initiation and cessation, and so the cchsflow variable-details rules can be checked against those conventions. Nothing here is a decision; the decisions are marked as open.

## 1. Where the numbers come from today

Three different things set an age or duration limit in the pipeline, and they are not the same:

| Kind | Where it lives | Examples |
|---|---|---|
| **Analysis decision** | `config.yml` under `apc:` | `initiation_floor_age` (PUMF 13, Master 8); `cessation_durability_years` (2); `cohort_min` (1920); estimation window start derived as `cohort_min + initiation_floor_age` (task 1.2) |
| **Variable range** (what a reported value can be) | derived from the variable-details worksheet by `details_range()` / `survey_range()`; never in config | age at first cigarette 8–51 (PUMF midpoints); years since quitting 0.5–5 (PUMF 2003+) |
| **Reference-study convention** | the protocol (should be), citing Holford and Manuel | initiation zero before 8; cessation zero before 15; age 85 ceiling |

The second row was settled on 2026-08-27 (Sol round 1 on PR #7, PI decision): the worksheet is the reference for min and max; config points at it (`range: variable_details`); a non-missing value with no worksheet range stops the pipeline.

## 2. What the reference studies used

| Convention | Holford et al. 2014 (AJPM; NCI SHG) | Manuel et al. 2020 (Health Reports; Ontario CCHS) | SAS reference (Modeling2013.sas) |
|---|---|---|---|
| Initiation probability zero before | age 8 | age 8 | `if age lt 8 ... delete` (initiation risk set) |
| Cessation probability zero before | age 15 | age 15 | `if age lt 15 ... delete` (cessation risk set); `if age ge 15` |
| No person-year after | survey age | survey date | `age gt surveyage then delete` |
| Upper age | NHIS ages 18–84; cessation probability held at the age-85 level above 85; histories reported to age 99 | CCHS aged 12+ | — |
| Durable cessation | quit at least 2 years before interview; otherwise observation truncated at the quit age | same rule (Holford lineage) | — |
| Missing age sentinel | — | — | 101 |
| Cohorts | 1890–2035 estimated; before-1920 intensity constrained to 1920 | 1920s cohort earliest reported | — |

Meza et al. 2023 (AJPM, race/ethnicity SHG) follows the same Holford construction; its stated limits were not extracted in this pass (the full text is in Zotero, item 9LGL8F9F) — check before citing.

## 3. Where the current protocol and code differ from those conventions

1. **Cessation floor.** Holford and Manuel set cessation probability to zero before age 15; the SAS reference drops cessation person-years before 15. The current code (task 1.3) starts each person's cessation risk at their own age at first cigarette with **no fixed minimum**, and the protocol (v0.4.1 §3.4.1) says so. This is a deliberate departure argued in the adjudication (a floor never substitutes for person-specific entry), but the protocol does not say that it departs from the reference studies or why. **Open:** keep person-specific entry (and say so), or add a 15-year reporting floor for comparability with Manuel 2020, or both (estimate person-specific; report from 15).
2. **Initiation floor.** Holford/Manuel: 8. Current: 8 in Master, 13 in PUMF (issue #5 decision; the PUMF 5–11 category is too coarse). Protocol §3.3 records this. Consistent, but the protocol should state the reference value (8) and that 13 is a PUMF data limit, not a methodological choice.
3. **Upper age.** No protocol statement. The PUMF age variable is grouped and capped (`DHHGAGE_cont` 13–85 for 2001–2018; 14.5–75 for 2019–20 and 2022, where the top category is 65+ with midpoint 75). Holford held cessation at the age-85 level beyond 85 and reported to 99. **Open:** state the maximum modelled age (85 seems the natural choice given the CCHS top code) and how rates above it are carried.
4. **Maximum age at initiation / duration of smoking.** Reference studies have no explicit maximum; "few initiate after 30" is an observation, not a rule. The worksheet gives 8–51 for age at first cigarette in the PUMF (grouped midpoints; the top group is 50+ → 51) — a reporting range, not a limit. **Open:** whether the protocol should state a maximum initiation age or leave it to the data.
5. **Quit duration.** PUMF top group "3 or more years" (midpoint 5) for 2003–2014 makes long-term former smokers quit too late; refinable with SMKG09C (2007–14) and SMKDGSTP (2015–22) — see `phase1-1.9-1.10-investigation.md`. Holford's "at least 2 years" durability rule is implementable in every cycle since the 2–3 / 3+ boundary exists.
6. **The 2019–20 and 2022 PUMF age variable** (five broad groups) cannot place a person within a year of age; the APC model is limited to 2001–2018 for age-specific estimation (`project_age_variable_constraints` memory). The protocol should say this.

## 4. What the worksheet currently derives (PUMF, `details_range()`)

| Variable | 2001 | 2003–2014 | 2015–16 | 2017–18 | 2019–20 | 2022 |
|---|---|---|---|---|---|---|
| `age_first_cigarette` | 8–51 | 8–51 | 8–47 | 8–51 | 8–51 | none (no rule) |
| `age_start_smoking` | 8–51 | 8–51 | 8–51 | 8–51 | none | none |
| `time_quit_smoking_complete` | none (not asked) | 0.5–5 | 0.5–5 | 0.5–5 | 0.5–5 | none |
| `time_quit_smoking_daily` | 0.5–15 | 0.5–5 | 0.5–5 | 0.5–5 | 0.5–5 | none |
| `DHHGAGE_cont` | 13–85 | 13–85 | 13–85 | 13–85 | 14.5–75 | 14.5–75 |

Two rows point at worksheet gaps rather than data facts: `age_first_cigarette` has no `cchs2022_p` rule although its feeder `SMKG01C_cont` does, and 2015–16 tops out at 47 (a different midpoint set) — both worth a cchsflow issue.

## 5. Suggested protocol text (for discussion, not applied)

A short "Age and time ranges" paragraph in §3.4.1, in this order: (a) reference conventions (Holford 2014; Manuel 2020): initiation from 8, cessation from 15, histories to 85 (Holford to 99), durable cessation two years; (b) what this study does and where it differs (person-specific cessation entry; PUMF initiation floor 13 as a data limit; maximum modelled age 85 with rates carried forward); (c) that reported-value ranges come from the CCHS recoding rules in cchsflow (variable details), are checked per cycle, and are not analysis limits.

## 6. Status of the PI's protocol edits (2026-08-28)

At 09:31 the protocol QMD was saved in the working copy on branch `fix/phase1-1.2-initiation-window`, but `git status` shows no change: either the edits are not yet saved in Positron, or they were made to the rendered Word file (`docs/protocol/output/full-protocol.docx`, rendered 09:25). Check before editing the QMD.
