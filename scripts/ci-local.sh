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
if [ "$#" -gt 1 ]; then echo "Expected at most one argument, got $#: $*" >&2; exit 2; fi
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
  # Same assertions as the hosted pipeline job: no target errored, and every target is
  # completed or skipped (tar_progress()).
  run pipeline env R_CONFIG_ACTIVE=ci Rscript -e 'suppressPackageStartupMessages(library(targets)); tar_make(reporter = "balanced"); m <- tar_meta(fields = c("name", "error")); err <- m$name[!is.na(m$error) & m$error != ""]; if (length(err)) { cat("Errored targets:", paste(err, collapse = ", "), "\n"); quit(status = 1) }; p <- tar_progress(); cat(nrow(p), "targets;", sum(p$progress == "completed"), "completed\n"); stopifnot(nrow(p) > 0, all(p$progress %in% c("completed", "skipped"))); cat("pipeline ok\n")'
fi
if [[ "$what" == "render" || "$what" == "all" ]]; then
  # Same as the hosted render job: whole site, ci profile (no R execution), then the
  # non-empty-site assertions.
  run render bash -c 'quarto render --profile ci && test -f _site/index.html && PAGES=$(find _site -name "*.html" | wc -l | tr -d " ") && echo "site pages: $PAGES" && [ "$PAGES" -ge 30 ]'
fi
if [[ "$what" == "protocol-docx" ]]; then
  # Word render of the protocol (docstyle subproject). docstyle rewrites
  # docs/protocol/_docstyle/section-map.json (keys reordered). The pre-render file, in
  # whatever state it is in, is saved first and put back afterwards, so a user's edits to
  # it survive and the check leaves the worktree as it found it.
  run protocol-docx bash -c '
    map=docs/protocol/_docstyle/section-map.json
    bak=$(mktemp) && cp "$map" "$bak" || exit 1
    # Restoration is attached to process exit, so an interrupted render (Ctrl-C, TERM, HUP)
    # still puts the pre-render file back; a failed restoration fails the check and keeps
    # the backup for the user.
    restore () {
      if cp "$bak" "$map"; then rm -f "$bak"; return 0; fi
      echo "Could not restore $map; your pre-render copy is at $bak" >&2; return 1
    }
    trap "rc=\$?; restore || rc=1; exit \$rc" EXIT
    trap "exit 130" INT
    trap "exit 143" TERM HUP
    quarto render docs/protocol/full-protocol.qmd && test -f docs/protocol/output/full-protocol.docx'
fi
echo; [ $status -eq 0 ] && echo "ALL SELECTED CHECKS PASSED" || echo "SOME CHECKS FAILED"
exit $status
