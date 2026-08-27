# Smoking states and transitions: analysis specification

**Task 1.0 of the remediation plan.** Implements protocol v0.4.0, section 3.4.1, and adjudication item A1 (2026-08-07).
**Status:** ratified in full by the PI, 2026-08-27, after external review: the established-smoker criterion (100 cigarettes; experimental smokers are Never) and the other state definitions, the per-transition treatment of immigrants (censored before arrival in Canada), the same-age rule, and the 2001 decision. **Depends on** private PR #4 (task 1.7a), which introduces the `"none"` mortality-correction value used in section 6; merge #4 first.

## 1. Why this document exists

The pipeline built its initiation model on one definition of a smoker (anyone who has smoked a whole cigarette) and its cessation model on another (people who have smoked daily). The two rate tables therefore described different populations. This note fixes one set of definitions and states, for each, which CCHS variable carries it. Tasks 1.2, 1.3, 1.9, 1.8c, and 1.7b implement against this note; they do not define their own.

## 2. States

Each person is in exactly one state at each age.

**The established-smoker criterion (ratified 2026-08-27).** A person enters the model's smoking states only if they have smoked at least 100 cigarettes in their lifetime. This is the Manuel et al. (2020) rule, and it follows the CCHS convention: respondents who have smoked a whole cigarette but fewer than 100 in total (experimental smokers) are treated as non-smokers. The criterion is observed with the unified variable `smoked_100_lifetime` (cchsflow; PUMF 2001 to 2019--20) and its source question `SMK_01A` (all cycles, including 2022). Age at first whole cigarette supplies the timing of entry only for people who meet the criterion; it does not by itself make anyone a smoker.

| State | Definition | How it is observed at survey |
|---|---|---|
| Never | Has not smoked 100 cigarettes: never smoked a whole cigarette, or smoked fewer than 100 (experimental smoker) | `smoked_100_lifetime` = no; includes `SMKDSTY_original` never smoked and, from 2015, the SMKDVSTY experimental-smoker category |
| Current | Meets the criterion and has not stopped smoking completely (daily or occasional) | `smoked_100_lifetime` = yes and `SMKDSTY_original` = daily, occasional (formerly daily), or occasional (never daily) |
| Former | Meets the criterion and has stopped smoking completely | `smoked_100_lifetime` = yes and `SMKDSTY_original` = former daily or former occasional |

The table gives the observed status at survey. The modelled state can differ from it: the durability rule in section 4 moves people who quit less than two years before the survey from observed Former to modelled Current.

Two points follow from the definitions. Stopping daily smoking while still smoking occasionally is not a transition; the person stays current. How much a current smoker smokes, and whether they smoke daily, are characteristics of the current state (protocol section 3.4.4), not states of their own.

## 3. Transitions modelled

| Transition | From | To | Event age | CCHS variable (cchsflow v3) |
|---|---|---|---|---|
| Initiation | Never | Current | Age at first whole cigarette, for people who meet the criterion | `age_first_cigarette` |
| Cessation | Current | Former | Age at which the person stopped smoking completely | survey age minus `time_quit_smoking_complete` |

Not modelled as transitions: relapse (Former back to Current) and daily onset (Current to a daily sub-state). The CCHS records one quit per person, so relapse cannot be estimated from it; its influence is a sensitivity analysis (protocol section 3.5). Daily onset (`age_start_smoking`) is retained as a characteristic of current smokers and for the intensity model.

The CCHS does not ask the age at which the 100th cigarette was smoked, so the age at first whole cigarette is the entry age for everyone who meets the criterion. This follows Manuel et al. (2020) and is a known approximation: entry is dated to the start of smoking, not to the point at which it became established.

**Consequence for the code.** The cessation model currently includes only ever-daily smokers and uses `time_quit_smoking_daily` (config key `years_since_quit`). Under this specification the model includes all established smokers and the exit variable is `time_quit_smoking_complete`. Task 1.3 makes this change; the config key and the worksheet roles change with it.

**The 2001 cycle (decided 2026-08-27).** `time_quit_smoking_complete` is derived from questions first asked in 2003. For 2001 the timing of complete cessation is treated as not asked in that cycle (NA(c)) and handled by the imputation procedure for cycle-level absence (Appendix D); the 2001 `time_quit_smoking` variable, which lacks the "stopped completely" question, is not used as a substitute.

## 4. Event-time conventions

- **Time step and interval.** One year. The row for age *a* covers the year from the person's *a*-th birthday to the day before the next one. An event at age *a* happened during that year. The event row is part of the risk set: it carries one trial, with the event. Within a year, initiation is applied before cessation, so a person who starts and stops at the same age has a one-year spell (below). The year of the survey is the last observed row for everyone; it is treated as a full year of exposure, a simplification shared with the Manuel and Holford implementations.
- **One period of smoking per person.** A person enters Current once and leaves it at most once.
- **Initiation risk.** From the study floor age (`survey_bound(cfg, "age_first_cigarette", "min")`) to the age at first cigarette (event) or the survey age (censored), whichever comes first. Never smokers are at risk at every age up to the survey.
- **Cessation risk.** From the person's own age at first cigarette to the age they stopped completely (event) or the survey age (censored). No person-year before entry. A fixed minimum age, if used, is a reporting boundary only.
- **Durable cessation and recent quitters.** The primary definition of cessation is a quit that has lasted at least two years at the survey. Three things are distinguished for a person who quit less than two years before the survey. *Observed status:* Former (`SMKDSTY_original`). *Modelled state:* Current at every age up to the survey, because the quit is not yet known to be durable; this is the state used for prevalence and passed to the generator. *Cessation risk set:* person-years from entry to the reported quit age, then censored with no event; the years between the quit age and the survey are not in the risk set because whether the quit will hold cannot yet be observed. The person therefore has exactly one modelled state at each age (Current) while contributing to the risk set only up to the quit age. Risk-set membership describes what can be observed about the outcome; it is not the state.
- **Same-age initiation and cessation (ratified 2026-08-27).** When the age at first cigarette equals the age at stopping, the data cannot show which came first within the year. *Primary rule:* the person smoked for one year. They enter Current at that age, contribute one person-year at risk of cessation at that age, and have the cessation event in it. *Prespecified sensitivity:* remove the person from both transition models -- no initiation event and no cessation record -- treating them as never having established smoking, so that reconstructed prevalence does not acquire an initiation without its cessation. Few respondents, possibly none, are expected to have started and stopped at the same age; the pipeline reports the unweighted and weighted count per cycle so the expectation is checked rather than assumed.
- **Reported ages that cannot be right** (initiation after survey age, cessation before initiation) are treated as missing and enter the imputation procedure (task 1.8c). No person is silently reclassified.

## 5. Target population and risk-set entry

- The Canadian household population covered by the CCHS, aged 12 and over at survey (the study analyses respondents aged 18 and over; `age_exclusion_min`).
- **Immigration.** Person-years before immigration are excluded (protocol section 3.3). In the Master files the year of immigration is exact. In the PUMF only immigrant status and, in some cycles, a grouped time-since-immigration variable are available; task 1.9 specifies the PUMF approximation and documents its error.
- **Delayed entry is defined per transition**, because an immigrant can arrive in any state:
  - Arrives Never (no smoking before immigration): initiation risk begins at the later of the study floor age and the age at immigration; if they later initiate, cessation risk begins at that initiation age.
  - Arrives Current (initiated before immigration): the initiation event is excluded, because it occurred outside the target population; the person is Current from the age at immigration for prevalence, and cessation risk begins at the age at immigration, not at the initiation age.
  - Arrives Former (initiated and quit before immigration): contributes to neither risk set; Former from the age at immigration for prevalence.
  - Canadian-born: state-entry ages as in section 4.

## 6. Output contract with the smoking-history generator

The generator (shg-rcpp) consumes the rate tables and produces, for each simulated person, a state at each age. The contract:

- Rate tables carry, per `model_type` (initiation, cessation), `sex`, `province`, `age`, `period`, and `cohort`: `rate`, `rate_lower`, `rate_upper`, and `mortality_correction` (`schemas/cshm-rate-tables.yaml`). `rate` is the annual probability of the transition among people in the source state at that age.
- The generator applies initiation to Never and cessation to Current. Former is absorbing (no relapse). At every age each simulated person is in exactly one of the three states.
- Intensity (cigarettes per day) and daily status are attributes attached to Current, drawn from the intensity model; they never change a person's state.
- `mortality_correction = "none"` (introduced by task 1.7a, private PR #4) means the rates describe respondents who survived to be surveyed. The generator must carry that label through to its outputs until a correction is implemented (task 1.7b).

## 7. Decisions recorded here

| Item | Decision | Source |
|---|---|---|
| State model | Established-smoking model: Never, Current, Former | Adjudication A1, 2026-08-07 |
| Established-smoker criterion | At least 100 cigarettes in lifetime; experimental smokers are Never | Manuel et al. 2020; PI decision, 2026-08-27 |
| 2001 cycle | Complete-cessation timing is NA(c); imputed | PI decision, 2026-08-27 |
| Interval convention | Age row = year from the *a*-th birthday; event row in risk set; initiation before cessation within a year; survey year included as a full year | Specified here, 2026-08-27 |
| Entry event | First whole cigarette (`age_first_cigarette`) | A1; Manuel et al. 2020 |
| Exit event | Stopped smoking completely (`time_quit_smoking_complete`) | A1; protocol 3.4.1 |
| Durability | Two years; more recent quitters are current at survey | Protocol 3.4.1 |
| Same-age rule | One year of smoking with the event in it (primary); exclusion (sensitivity) | PI decision, 2026-08-27 |
| Relapse | Not modelled; sensitivity analysis | Protocol 3.4.1 |
| Immigration entry | Censored before arrival in Canada; per-transition delayed entry (section 5); PUMF approximation in task 1.9 | Protocol 3.3; adjudication B1; PI decision, 2026-08-27 |

## 8. What changes in the pipeline because of this note

- [ ] 1.3: cessation model includes all established smokers; exit variable = `time_quit_smoking_complete`; time at risk begins at `age_first_cigarette`; recent-quitter censoring; same-age rule.
- [ ] Config: replace the `years_since_quit` mapping (`time_quit_smoking_daily`) with the complete-cessation variable; keep `age_start_daily` for the intensity model only.
- [ ] Criterion: add `smoked_100_lifetime` (with `SMK_01A` for 2022) to the variables sheet as the inclusion variable for both transitions; experimental smokers map to Never.
- [ ] 2001: complete-cessation timing tagged NA(c) and routed to the cycle-level imputation path.
- [ ] Worksheets: roles for `time_quit_smoking_complete` (apc-numerator, apc-denominator); `age_start_smoking` loses its cessation role.
- [ ] 1.3 diagnostic: report the unweighted and weighted number of people who started and stopped at the same age, per cycle.
- [ ] 1.2: initiation window aligned to the entry event above.
- [ ] 1.9: per-transition delayed entry (section 5), including exclusion of pre-immigration initiation events.
- [ ] 1.8c: imputation follows the state definitions in section 2 (state membership imputed first).
- [ ] Generator contract (section 6) added to the rate-table schema description.
