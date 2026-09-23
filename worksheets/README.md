# Study Metadata Handoff

Updated September 22, 2026, for protocol v0.4.5.

The pipeline uses `cshm-variables.csv` as its study variable list, `cchsflow-variable-details.csv` as the base recoding table, and `cshm-variable-details.csv` for delivery-specific and study-specific rules. `config.yml` names these files; `_targets.R` combines the two details tables by column name. Do not concatenate duplicate recoding blocks from a second upstream snapshot.

## Upstream provenance

This is a selective update from cchsflow commit `047401e4546c9e8c25c99faef6a7c5fc4181a479`, not a whole-snapshot refresh. The refreshed blocks are `SDCFIMM`, `SDCDRES`, `SDCGRES`, `SDCDCGT_cat7`, `SDCDCGT_2015plus`, `SDCDVVM` and `immigration_der`. All other base rows retain their prior values, including local smoking fixes. The package dependency remains pinned at `2d3c1cad`; these metadata changes do not require a new derivation function.

The `SDCDRES` note has a documented local correction: the reviewed 2015--2021 Master questions use landed-immigrant year, whereas upstream describes the break as 2022. The numerical mappings retain their upstream form. This variable must not be interpreted uniformly as time since first arrival.

The local 2019--2020 and 2022 PUMF deliveries contain `GEOGPRV`. The existing CSHM geography and weight extensions are retained; the new upstream `GEO_PRV` mappings were not imported. Maikol must verify headers against the actual secure delivery before using its mappings.

## Exposure representation

- `SDCFIMM` is immigration status, distinct from birthplace. Later PUMF categories include non-permanent residents. The 2022 source codes are reversed during harmonization.
- `SDCGRES` retains PUMF residence-duration groups. `SDCDRES` retains the Master duration with the source-concept qualification above.
- `arrival_year` preserves direct first-arrival year in the reviewed pre-2015 and 2022--2023 Master fields. `landed_immigrant_year` preserves the separate 2015--2023 landed-year fields. Neither variable substitutes for the other. These intermediate inputs preserve timing for the later risk-entry implementation.
- Direct-year validation uses a permissive lower bound of 1800 and the final survey year as its upper bound. These bounds validate input years; observed source ranges, interview dates and analysis boundaries remain separate. Structural and item missingness are preserved.
- `SDCDCGT_cat7` and `SDCDVVM` remain separate Master classifications. The residual visible-minority category is not White. No raw-response binary racial mapping or separate Indigenous-identity predictor is activated.
- The categorical quit-duration variables and finer Master timing inputs are retained for the future interval implementation. The existing continuous complete-cessation output still uses representative values and may substitute daily-stop timing when its confirmation gate is missing. It is not the protocol's interval method.
- Education uses the protocol's three-category `EDUDR03` in both sources. Core demographic source flags and Master age roles are corrected; imputation selects predictors for the active source.

## Secure-environment setup

Copy `config/statscan.yml.example` to the ignored `config/statscan.yml` and fill in actual paths and a non-overlapping list of delivered Master files. Keep its top-level `default:` block: these are local overrides read by `load_study_config(profile = "statscan")`. `_targets.R` uses that resolver. Calling `config::get()` alone does not merge the local file.

Stable dataset codes in `config.yml` support subsets and reordered cycle lists. Survey-year lookup values remain assigned years, not observed interview years. No 2024 field coverage is declared yet. The example includes 2021 separately; confirm the actual delivery contains that cycle without overlapping another file.

## Validation and remaining work

`tests/testthat/test-metadata-handoff.R` covers configuration resolution, source-filtered imputation, stable cycle lookup, configured-variable selection and synthetic status/date/classification recodes. Run with the project-pinned cchsflow v3 for the recoding tests. No secure respondent records are required.

This handoff updates loading metadata and its consumers. It does not implement arrival-based APC entry, interval imputation, recent-PUMF exclusion from history fitting, all-imputation pooling or the new APC specifications. The full pipeline must not be described as implementing protocol v0.4.5 yet. Confirm source headers and feeder availability in Maikol's environment before a Master run; the coverage validator can still report existing source-specific smoking gaps.

Validation on September 22, 2026: the full testthat suite passed with cchsflow v3 (`2d3c1cad`) and a temporary library providing the missing test dependencies. The suite emitted warnings from existing fixtures and automatic database selection. The new handoff tests passed, including synthetic recodes and tagged missingness. A focused loader smoke test passed on 400 fixture rows from 2022 and 2003 in reversed cycle order. A broader 2003 harmonization smoke run was stopped because of runtime; no full Master or end-to-end pipeline run is claimed. The dependency lock was unchanged.
