#!/usr/bin/env bash
# Run the CI checks locally with the same commands and assertions as
# .github/workflows/ci.yml (hosted runners run automatically only on the public repository).
#
# Usage: scripts/ci-local.sh [tests|style|pipeline|render|all|protocol-docx]
#   all           = tests, style, pipeline, render (the four hosted jobs; default)
#   protocol-docx = render the protocol to Word (docstyle subproject); not a hosted job
#
# Exit code: 0 all selected checks passed; 1 a check failed; 2 bad argument.
# In a worktree without its own renv library set RENV_PATHS_LIBRARY=<main checkout>/renv/library.
set -u
what="${1:-all}"
case "$what" in
  tests|style|pipeline|render|all|protocol-docx) ;;
  *) echo "Unknown check '$what'. Use one of: tests, style, pipeline, render, all, protocol-docx." >&2; exit 2 ;;
esac
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
  # Same as the hosted render job: whole site, ci profile (no R execution), then the
  # non-empty-site assertions.
  run render bash -c 'quarto render --profile ci && test -f _site/index.html && PAGES=$(find _site -name "*.html" | wc -l | tr -d " ") && echo "site pages: $PAGES" && [ "$PAGES" -ge 30 ]'
fi
if [[ "$what" == "protocol-docx" ]]; then
  # Word render of the protocol (docstyle subproject). docstyle rewrites
  # docs/protocol/_docstyle/section-map.json with keys reordered; restore it so the
  # check leaves the worktree clean.
  run protocol-docx bash -c 'quarto render docs/protocol/full-protocol.qmd && test -f docs/protocol/output/full-protocol.docx; rc=$?; git checkout -q -- docs/protocol/_docstyle/section-map.json 2>/dev/null; exit $rc'
fi
echo; [ $status -eq 0 ] && echo "ALL SELECTED CHECKS PASSED" || echo "SOME CHECKS FAILED"
exit $status
