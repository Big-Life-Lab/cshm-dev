# rename-pumf-objects.R
#
# Re-saves cchsflow-data release RData files with the correct internal object
# name (e.g., `table` → `cchs2019_2020_p`) so they match the cchsflow/data/
# convention expected by cchsflow::rec_with_table().
#
# Usage: Rscript scripts/rename-pumf-objects.R
#
# Run once after downloading the cchsflow-data v1.0.0 release assets.
# Output goes to ~/github/cchsflow/data/ so all cycles are in one place.

library(fs)

source_dir <- path.expand("~/github/cchsflow-data/data/sources/rdata")
target_dir <- path.expand("~/github/cchsflow/data")

# Map: source filename → target object name
cycle_map <- c(
  "CCHS_2001.RData"      = "cchs2001_p",
  "CCHS_2003.RData"      = "cchs2003_p",
  "CCHS_2005.RData"      = "cchs2005_p",
  "CCHS_2007_2008.RData" = "cchs2007_2008_p",
  "CCHS_2009_2010.RData" = "cchs2009_2010_p",
  "CCHS_2011_2012.RData" = "cchs2011_2012_p",
  "CCHS_2013_2014.RData" = "cchs2013_2014_p",
  "CCHS_2015_2016.RData" = "cchs2015_2016_p",
  "CCHS_2017_2018.RData" = "cchs2017_2018_p",
  "CCHS_2019_2020.RData" = "cchs2019_2020_p",
  "CCHS_2022.RData"      = "cchs2022_p"
)

for (src_file in names(cycle_map)) {
  obj_name  <- cycle_map[[src_file]]
  src_path  <- file.path(source_dir, src_file)
  dest_path <- file.path(target_dir, paste0(obj_name, ".RData"))

  # Skip if target already exists
  if (file.exists(dest_path)) {
    message("Skipping ", obj_name, " (already exists)")
    next
  }

  if (!file.exists(src_path)) {
    message("Source not found, skipping: ", src_path)
    next
  }

  message("Converting ", src_file, " → ", basename(dest_path))
  env <- new.env()
  load(src_path, envir = env)

  # Rename the object (expected to be called `table`)
  if (!"table" %in% ls(env)) {
    warning("Expected object 'table' not found in ", src_file, "; skipping")
    next
  }

  assign(obj_name, get("table", envir = env))
  save(list = obj_name, file = dest_path)
  message("  Saved: ", dest_path)
}

message("Done. Run ls ~/github/cchsflow/data/ to verify.")
