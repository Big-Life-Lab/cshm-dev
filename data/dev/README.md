# Pipeline fixtures

Fixed-seed samples of 200 respondents per CCHS cycle, one `.RData` file per
cycle with the canonical `cchs*_p` object name. Regenerate with:

```bash
Rscript scripts/make-dev-fixtures.R
```

**Provenance:** sampled from the [cchsflow-data](https://github.com/Big-Life-Lab/cchsflow-data)
release files -- CCHS Public Use Microdata Files, adapted and redistributed
under the [Statistics Canada Open Licence](https://www.statcan.gc.ca/en/reference/licence).

**Purpose:** the `ci` config profile reads this directory so a fresh clone or
CI runner can complete an end-to-end pipeline run (`R_CONFIG_ACTIVE=ci
targets::tar_make()`) without access to the full PUMF extracts. The samples
are for pipeline mechanics only -- estimates produced from them are
meaningless.
