#!/bin/bash
# Report law for the Atlas Families experiment.
#   nix develop --command bazel test \
#     //experiments/atlas-families:report_test --config=buildbuddy-rbe-arm64
#
# Every generated block in REPORT.md sits between
#   <!-- families:<name>:begin --> and <!-- families:<name>:end -->
# and must equal the regenerated Bazel projection byte for byte, so the
# report's numbers are recorded artifacts, never hand-typed values.
#
# Only bash builtins and grep are used so the test runs hermetically on RBE.
set -euo pipefail

if [ -n "${TEST_SRCDIR:-}" ]; then
    export RUNFILES_DIR="$TEST_SRCDIR"
elif [ -z "${RUNFILES_DIR:-}" ] && [ -d "$0.runfiles" ]; then
    export RUNFILES_DIR="$(cd "$0.runfiles" && pwd)"
fi

# --- begin runfiles.bash initialization v3 ---
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---

pkg="experiments/atlas-families"
report="$(rlocation _main/$pkg/REPORT.md)"

status=0

# `block NAME` — the lines of REPORT.md strictly between the NAME markers.
block() {
    local inside=0 found=0 line
    while IFS= read -r line || [ -n "$line" ]; do
        if [ "$line" = "<!-- families:$1:end -->" ]; then inside=0; continue; fi
        if [ "$inside" -eq 1 ]; then printf '%s\n' "$line"; fi
        if [ "$line" = "<!-- families:$1:begin -->" ]; then inside=1; found=1; fi
    done < "$report"
    [ "$found" -eq 1 ]
}

# `pinned NAME GENERATED` — the NAME block must equal the generated file.
pinned() {
    local recorded generated
    if ! recorded="$(block "$1")"; then
        echo "FAIL REPORT.md has no $1 block"; status=1; return
    fi
    generated="$(<"$2")"
    if [ "$recorded" = "$generated" ]; then
        echo "OK   REPORT.md $1 block equals the regenerated projection"
    else
        echo "FAIL REPORT.md $1 block differs from the regenerated projection"
        echo "--- regenerated"; printf '%s\n' "$generated"
        echo "--- recorded"; printf '%s\n' "$recorded"
        status=1
    fi
}

pinned inventory "$(rlocation _main/$pkg/inventory_report.md)"

if [ "$status" -ne 0 ]; then
    echo "report_test: FAILED"
    exit 1
fi
echo "report_test: PASSED"
