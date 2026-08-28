#!/usr/bin/env bash
# Run the CI checks locally (tests, style, ci-profile pipeline) instead of on hosted
# runners. Usage: scripts/ci-local.sh [tests|style|pipeline|render|all]   (default: all)
# Exit code is non-zero if any selected check fails. Run from the repository root or a
# worktree; a worktree without its own renv library needs
#   RENV_PATHS_LIBRARY=<main checkout>/renv/library
set -u
what="${1:-all}"
status=0
run () { echo; echo "=== $1 ==="; shift; "$@"; rc=$?; [ $rc -ne 0 ] && { echo "--- FAILED ($rc)"; status=1; }; return 0; }

if [[ "$what" == "tests" || "$what" == "all" ]]; then
  run tests Rscript -e 'testthat::test_dir("tests/testthat", stop_on_failure = TRUE, reporter = "summary")'
fi
if [[ "$what" == "style" || "$what" == "all" ]]; then
  run style Rscript -e 'if (!requireNamespace("styler", quietly = TRUE)) stop("styler is not installed (renv::repair() or install into a scratch library)"); r <- styler::style_dir("R", dry = "on"); bad <- r$file[r$changed]; if (length(bad)) { cat("Not styler-clean:", paste(bad, collapse = ", "), "\n"); quit(status = 1) }; cat("R/ is styler-clean\n")'
fi
if [[ "$what" == "pipeline" || "$what" == "all" ]]; then
  run pipeline env R_CONFIG_ACTIVE=ci Rscript -e 'suppressPackageStartupMessages(library(targets)); tar_make(reporter = "summary"); m <- tar_meta(fields = c("name", "error")); err <- m$name[!is.na(m$error) & m$error != ""]; if (length(err)) { cat("Errored targets:", paste(err, collapse = ", "), "\n"); quit(status = 1) }; cat("pipeline ok:", nrow(m), "targets\n")'
fi
if [[ "$what" == "render" || "$what" == "all" ]]; then
  run render quarto render docs/protocol/full-protocol.qmd
fi
echo; [ $status -eq 0 ] && echo "ALL SELECTED CHECKS PASSED" || echo "SOME CHECKS FAILED"
exit $status
