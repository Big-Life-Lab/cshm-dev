# Study Metadata Handoff

Updated September 23, 2026, for protocol v0.4.6.

The pipeline uses `cshm-variables.csv` as its study variable list, `cchsflow-variable-details.csv` as the base recoding table, and `cshm-variable-details.csv` for delivery-specific and study-specific rules. `config.yml` names these files; `_targets.R` combines the two details tables by column name. Do not concatenate duplicate recoding blocks from another upstream snapshot.

## Upstream provenance and local corrections

The September 22 update reviewed seven blocks from cchsflow commit `047401e4546c9e8c25c99faef6a7c5fc4181a479`: `SDCFIMM`, `SDCDRES`, `SDCGRES`, `SDCDCGT_cat7`, `SDCDCGT_2015plus`, `SDCDVVM` and `immigration_der`. Six changed; `SDCGRES` already matched. This was a selective update. The package remains pinned at `2d3c1cad`; the metadata changes require no new package derivation function.

The September 23 review identified errors in the imported racial mappings and existing geography and education rules. Local corrections now take precedence over those upstream blocks:

- `SDCDCGT_cat7` uses separate source-code mappings for 2003, 2005--2014 and 2015--2018, including the combined 2009--2010 file. Filipino, other-origin and multiple-origin responses remain substantive categories. Only the observed 2003 source category can map to the intermediate Indigenous category; later valid skips remain structural missingness. The 2001 derived code list remains unverified, so its coverage has been removed.
- `SDCDCGT_2015plus` retains the actual 2015--2018 source codes without permutation. It remains separate from the 2019-onward visible-minority classification, `SDCDVVM`. The latter's residual category is not White. All three are intermediate variables; `survey.ethnicity.master.var` is null. No pooled Master racial predictor or separate Indigenous-identity predictor is enabled.
- `GEOGPRV` imports only upstream Master mappings, covering every configured Master cycle. The existing PUMF rules and the local 2019--2020 and 2022 extensions retain `GEOGPRV` for those deliveries. Province joins the configured inputs that require rules in every active cycle.
- `EDUDR03` assigns pre-2015 some-postsecondary responses to category two. Category three requires a postsecondary credential. The 2022 PUMF has household education (`EDDVH3`) only, so individual education coverage is removed; household education is not substituted.
- The `SDCDRES` note retains the earlier local correction: the reviewed Master questions change from first-arrival year to landed-immigrant year in 2015. Its numerical mappings are unchanged. It is not uniformly time since first arrival.

The regression expectations come from the Statistics Canada cycle dictionaries in the `cchsflow-docs` complete collection. Key audit locations are the 2003 Master `SDCCDRAC` entry (page 937), 2013 Master `SDCDCGT` and `EDUDR04` entries (pages 919 and 951), 2015 Master `SDCDVCGT`, `SDC_IM3` and `SDCDVIMM` entries (pages 726, 694 and 724), and 2022 Master `SDCDVIMM` (page 199). Province aliases are `GEOA_PRV`, `GEOC_PRV`, `GEOE_PRV` in the first three cycles and `GEO_PRV` thereafter. Confirm these against the delivered secure-file headers before running.

## Immigration information retained

`SDCFIMM` is a source-specific proxy, distinct from birthplace. Earlier citizenship-at-birth-derived flags already fail to distinguish non-permanent residents; the limitation does not begin with the explicitly combined PUMF category in 2015--2016. The 2022 PUMF source codes are reversed during harmonization.

Master status combines immigrants and non-permanent residents in 2015--2021. `landed_immigrant_status` preserves the `SDC_IM3` question in those cycles, including its restricted universe and valid skips. A negative response alone is not classified as non-permanent-resident status. In 2022--2023, `immigration_status_detailed` preserves all three `SDCDVIMM` categories, including non-permanent residents; the legacy `SDCFIMM` binary output continues to merge them with immigrants.

`SDCGRES` retains PUMF residence-duration groups. `arrival_year` preserves direct first-arrival year in the reviewed pre-2015 and 2022--2023 Master fields. `landed_immigrant_year` preserves the separate 2015--2023 landed-year fields. Neither substitutes for the other. The direct-year rules use a permissive validation floor of 1800 and the final survey year as the upper bound; these are storage bounds, not observed source ranges or analysis boundaries. Source structural and item missingness are retained.

These intermediate inputs support the later Canadian risk-entry implementation. They do not settle the analytical treatment of observations without an arrival date or the source-specific non-permanent-resident rule.

## Secure-environment setup

Copy `config/statscan.yml.example` to the ignored `config/statscan.yml` and fill in actual paths and a non-overlapping list of delivered Master files. Keep its top-level `default:` block: these are local overrides read by `load_study_config(profile = "statscan")`. `_targets.R` uses that resolver. Calling `config::get()` alone does not merge the local file.

Stable dataset codes support subsets and reordered cycle lists. Descriptive tables sort by the survey year in the display label, so the stable code added for 2021 displays before 2022. Assigned survey years remain distinct from observed interview years. No 2024 field coverage is declared. Confirm that a separate 2021 delivery does not overlap another file.

## Validation and remaining work

`tests/testthat/test-review-corrections.R` exercises documented racial codes across coding eras, province recodes for every configured Master cycle, incomplete versus completed education, retained immigration categories, runtime rejection of a missing province rule, and chronological table ordering. `test-metadata-handoff.R` also covers configuration resolution, source-filtered imputation, stable cycle lookup, study-list selection, status recodes and distinct immigration dates. Run recoding tests with the project-pinned cchsflow v3. No secure respondent records are required.

The previous PR checks passed despite the mapping defects. Checking whether a variable is listed cannot establish that its source codes have the correct meaning. The new source-code tests reproduced those defects before the corrections were applied.

This handoff updates loading metadata and its consumers. It does not implement arrival-based APC entry, interval imputation, recent-PUMF exclusion from history fitting, all-imputation pooling or the new APC specifications. The existing continuous complete-cessation output still uses representative values and may substitute daily-stop timing when its confirmation gate is missing; it is not the protocol's interval method. The full pipeline must not be described as implementing protocol v0.4.6 yet. Confirm source headers and feeder availability in Maikol's environment; the coverage validator can still report existing source-specific smoking gaps.

Validation on September 23, 2026: 83 test cases and 307 assertions passed with cchsflow v3 at `2d3c1cad`; 19 existing fixture/model warnings remain. All R files pass styler 1.11.0. Full protocol and summary Word builds succeeded, with valid XML, updated version stamps and no unresolved citation markers. Page layout was not visually checked. No secure Master-data or new end-to-end pipeline run is claimed. The dependency lock is unchanged.
