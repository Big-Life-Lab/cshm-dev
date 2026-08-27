# Smoking states and transitions: analysis specification

**Task 1.0 of the remediation plan.** Implements protocol v0.4.0, section 3.4.1, and adjudication item A1 (2026-08-07).
**Status:** ratified 2026-08-27 (PI). The same-age rule, the one item that was open, is decided below; everything else restates the protocol in operational terms.

## 1. Why this document exists

The pipeline built its initiation model on one definition of a smoker (anyone who has smoked a whole cigarette) and its cessation model on another (people who have smoked daily). The two rate tables therefore described different populations. This note fixes one set of definitions and states, for each, which CCHS variable carries it. Tasks 1.2, 1.3, 1.9, 1.8c, and 1.7b implement against this note; they do not define their own.

## 2. States

Each person is in exactly one state at each age.

| State | Definition | How it is observed at survey |
|---|---|---|
| Never | Has never smoked a whole cigarette | `SMKDSTY_original` = never smoked |
| Current | Has smoked a whole cigarette and has not stopped smoking completely (daily or occasional) | `SMKDSTY_original` = daily, occasional (formerly daily), or occasional (never daily) |
| Former | Smoked a whole cigarette in the past and has stopped smoking completely | `SMKDSTY_original` = former daily or former occasional |

Two points follow from the definitions. Stopping daily smoking while still smoking occasionally is not a transition; the person stays current. How much a current smoker smokes, and whether they smoke daily, are characteristics of the current state (protocol section 3.4.4), not states of their own.

## 3. Transitions modelled

| Transition | From | To | Event age | CCHS variable (cchsflow v3) |
|---|---|---|---|---|
| Initiation | Never | Current | Age at first whole cigarette | `age_first_cigarette` |
| Cessation | Current | Former | Age at which the person stopped smoking completely | survey age minus `time_quit_smoking_complete` |

Not modelled as transitions: relapse (Former back to Current) and daily onset (Current to a daily sub-state). The CCHS records one quit per person, so relapse cannot be estimated from it; its influence is a sensitivity analysis (protocol section 3.5). Daily onset (`age_start_smoking`) is retained as a characteristic of current smokers and for the intensity model.

**Consequence for the code.** The cessation model currently uses the ever-daily universe and `time_quit_smoking_daily` (config key `years_since_quit`). Under this specification the universe is all ever-smokers and the exit variable is `time_quit_smoking_complete`. Task 1.3 makes this change; the config key and the worksheet roles change with it.

## 4. Event-time conventions

- **Time step.** One year. Ages are whole years; each person contributes one row per age at which they are at risk of the transition being modelled.
- **One spell per person.** A person enters Current once and leaves it at most once.
- **Initiation risk.** From the study floor age (`survey_bound(cfg, "age_first_cigarette", "min")`) to the age at first cigarette (event) or the survey age (censored), whichever comes first. Never smokers are at risk at every age up to the survey.
- **Cessation risk.** From the person's own age at first cigarette to the age they stopped completely (event) or the survey age (censored). No person-year before entry. A fixed minimum age, if used, is a reporting boundary only.
- **Durable cessation.** The primary definition of cessation is a quit that has lasted at least two years at the survey. A person who quit less than two years before the survey is a current smoker at the survey; in the cessation model they contribute person-years up to the reported quit age and are then censored, with no event.
- **Same-age initiation and cessation (ratified 2026-08-27).** When the age at first cigarette equals the age at stopping, the data cannot show which came first within the year. *Primary rule:* treat it as a one-year spell. The person enters Current at that age, contributes one person-year at risk of cessation at that age, and has the cessation event in it. *Prespecified sensitivity:* exclude same-age spells from the cessation model (treat the person as never having established smoking). Few respondents, possibly none, are expected to meet this condition; the pipeline reports the unweighted and weighted count per cycle so the expectation is checked rather than assumed.
- **Reported ages that cannot be right** (initiation after survey age, cessation before initiation) are treated as missing and enter the imputation procedure (task 1.8c). No person is silently reclassified.

## 5. Target population and risk-set entry

- The Canadian household population covered by the CCHS, aged 12 and over at survey (the study analyses respondents aged 18 and over; `age_exclusion_min`).
- **Immigration.** Person-years before immigration are excluded (protocol section 3.3). In the Master files the year of immigration is exact. In the PUMF only immigrant status and, in some cycles, a grouped time-since-immigration variable are available; task 1.9 specifies the PUMF approximation and documents its error.
- A person's risk set for either transition begins at the later of the state-entry age (section 4) and the age at entry into the Canadian population.

## 6. Output contract with the smoking-history generator

The generator (shg-rcpp) consumes the rate tables and produces, for each simulated person, a state at each age. The contract:

- Rate tables carry, per `model_type` (initiation, cessation), `sex`, `province`, `age`, `period`, and `cohort`: `rate`, `rate_lower`, `rate_upper`, and `mortality_correction` (`schemas/cshm-rate-tables.yaml`). `rate` is the annual probability of the transition among people in the source state at that age.
- The generator applies initiation to Never and cessation to Current. Former is absorbing (no relapse). At every age each simulated person is in exactly one of the three states.
- Intensity (cigarettes per day) and daily status are attributes attached to Current, drawn from the intensity model; they never change a person's state.
- `mortality_correction = "none"` means the rates describe respondents who survived to be surveyed. The generator must carry that label through to its outputs until a correction is implemented (task 1.7b).

## 7. Decisions recorded here

| Item | Decision | Source |
|---|---|---|
| State model | Established-smoking model: Never, Current, Former | Adjudication A1, 2026-08-07 |
| Entry event | First whole cigarette (`age_first_cigarette`) | A1; Manuel et al. 2020 |
| Exit event | Stopped smoking completely (`time_quit_smoking_complete`) | A1; protocol 3.4.1 |
| Durability | Two years; more recent quitters are current at survey | Protocol 3.4.1 |
| Same-age rule | One-year spell (primary); exclusion (sensitivity) | PI decision, 2026-08-27 |
| Relapse | Not modelled; sensitivity analysis | Protocol 3.4.1 |
| Immigration entry | Excluded before immigration; PUMF approximation in task 1.9 | Protocol 3.3; adjudication B1 |

## 8. What changes in the pipeline because of this note

- [ ] 1.3: cessation universe = ever-smokers; exit variable = `time_quit_smoking_complete`; clock from `age_first_cigarette`; recent-quitter censoring; same-age rule.
- [ ] Config: replace the `years_since_quit` mapping (`time_quit_smoking_daily`) with the complete-cessation variable; keep `age_start_daily` for the intensity model only.
- [ ] Worksheets: roles for `time_quit_smoking_complete` (apc-numerator, apc-denominator); `age_start_smoking` loses its cessation role.
- [ ] 1.3 diagnostic: report the unweighted and weighted number of same-age spells per cycle.
- [ ] 1.2: initiation window aligned to the entry event above.
- [ ] 1.9: immigration entry floor.
- [ ] 1.8c: imputation universes follow section 2 (state gates first).
- [ ] Generator contract (section 6) added to the rate-table schema description.
