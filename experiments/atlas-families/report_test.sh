#!/bin/bash
# Report law for the Atlas Families experiment.
#   nix develop --command bazel test \
#     //experiments/atlas-families:report_test --config=buildbuddy-rbe-arm64
#
# Every generated block in REPORT.md and PROTOCOL.md sits between
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
status=0

# `block DOCUMENT NAME` — the lines of DOCUMENT strictly between the NAME markers.
block() {
    local inside=0 found=0 line
    while IFS= read -r line || [ -n "$line" ]; do
        if [ "$line" = "<!-- families:$2:end -->" ]; then inside=0; continue; fi
        if [ "$inside" -eq 1 ]; then printf '%s\n' "$line"; fi
        if [ "$line" = "<!-- families:$2:begin -->" ]; then inside=1; found=1; fi
    done < "$(rlocation "_main/$pkg/$1")"
    [ "$found" -eq 1 ]
}

# `pinned DOCUMENT NAME GENERATED` — the NAME block must equal the generated file.
pinned() {
    local recorded generated
    if ! recorded="$(block "$1" "$2")"; then
        echo "FAIL $1 has no $2 block"; status=1; return
    fi
    generated="$(<"$3")"
    if [ "$recorded" = "$generated" ]; then
        echo "OK   $1 $2 block equals the regenerated projection"
    else
        echo "FAIL $1 $2 block differs from the regenerated projection"
        echo "--- regenerated"; printf '%s\n' "$generated"
        echo "--- recorded"; printf '%s\n' "$recorded"
        status=1
    fi
}

pinned REPORT.md inventory "$(rlocation _main/$pkg/inventory_report.md)"
pinned REPORT.md acquisition "$(rlocation _main/$pkg/acquisition_report.md)"
pinned REPORT.md clustering "$(rlocation _main/$pkg/clustering_report.md)"
pinned PROTOCOL.md protocol "$(rlocation _main/$pkg/protocol_constants.md)"
pinned PROTOCOL.md method "$(rlocation _main/$pkg/method_constants.md)"

if [ "$status" -ne 0 ]; then
    echo "report_test: FAILED"
    exit 1
fi
echo "report_test: PASSED"
