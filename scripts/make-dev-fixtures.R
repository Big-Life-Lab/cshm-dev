# Regenerate the committed pipeline fixtures in data/dev/ (remediation task 0.6).
#
# Each fixture is a fixed-seed sample of 200 respondents per CCHS cycle, drawn
# from the cchsflow-data release files (CCHS PUMF, distributed under the
# Statistics Canada Open Licence). The fixtures let a fresh clone or CI runner
# complete an end-to-end pipeline run under the `ci` config profile.
#
# Usage: Rscript scripts/make-dev-fixtures.R
# Requires the cchsflow-data checkout locally; CI never runs this script.

set.seed(2026)
src_dir <- path.expand("~/github/cchsflow-data/data/sources/rdata")
out_dir <- "data/dev"
n_per_cycle <- 200

cycles <- c(
  cchs2001_p      = "CCHS_2001.RData",
  cchs2003_p      = "CCHS_2003.RData",
  cchs2005_p      = "CCHS_2005.RData",
  cchs2007_2008_p = "CCHS_2007_2008.RData",
  cchs2009_2010_p = "CCHS_2009_2010.RData",
  cchs2011_2012_p = "CCHS_2011_2012.RData",
  cchs2013_2014_p = "CCHS_2013_2014.RData",
  cchs2015_2016_p = "CCHS_2015_2016.RData",
  cchs2017_2018_p = "CCHS_2017_2018.RData",
  cchs2019_2020_p = "CCHS_2019_2020.RData",
  cchs2022_p      = "CCHS_2022.RData"
)

dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

for (cycle in names(cycles)) {
  e <- new.env()
  loaded <- load(file.path(src_dir, cycles[[cycle]]), envir = e)
  obj <- if ("table" %in% loaded) "table" else loaded[1]
  full <- e[[obj]]
  sampled <- full[sample(nrow(full), min(n_per_cycle, nrow(full))), , drop = FALSE]
  assign(cycle, sampled)
  save(list = cycle, file = file.path(out_dir, paste0(cycle, ".RData")), compress = "xz")
  message(
    cycle, ": ", nrow(sampled), " of ", nrow(full), " rows, ",
    ncol(sampled), " cols"
  )
}
