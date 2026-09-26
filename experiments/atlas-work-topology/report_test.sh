#!/bin/bash
# Report law: the final synthesis and its numbers (VAL-REPORT-001, VAL-REPORT-002).
#   nix develop --command bazel test \
#     //experiments/atlas-work-topology:report_test --config=buildbuddy-rbe
#
# Guards experiments/atlas-work-topology/REPORT.md two ways:
#
#   1. The report must contain the five required headline curves, an explicit
#      outcome classification, and the commands of record (the contract of
#      PREREGISTRATION.md §14 / VAL-REPORT-001).
#   2. The report's headline numbers must agree with the frozen artifacts: the
#      primary quantity at control and at round 4, the round-4 D50 comparison,
#      and the architecture-only cross-cell test invalidation. If an artifact is
#      re-derived to different bytes (the artifacts tests would already fail) or
#      the report is edited to a value the artifact does not contain, this fails.
#
# Only bash, grep, cut and dirname are used: the test runs hermetically on
# BuildBuddy RBE and must not depend on jq/awk being installed on the worker.
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

pkg="experiments/atlas-work-topology"
report="$(rlocation _main/$pkg/REPORT.md)"
topology_control="$(rlocation _main/$pkg/control/control.topology.json)"
topology_round4="$(rlocation _main/$pkg/round4/round4.topology.json)"
oracle_round4="$(rlocation _main/$pkg/round4/round4.oracle.json)"
fanout_round4="$(rlocation _main/$pkg/round4/round4.fanout_delta.tsv)"

status=0
say_ok() { echo "OK   $1"; }
fail() { echo "FAIL $1"; status=1; }

# `contains FILE LABEL NEEDLE` — the report (or an artifact) must contain NEEDLE.
contains() {
    if grep -qF -- "$3" "$1"; then say_ok "$2"; else fail "$2 (missing: $3)"; fi
}

[ -s "$report" ] || { echo "FAIL report: $report is missing or empty"; exit 1; }

# --- 1. The five required headline curves (VAL-REPORT-001) -------------------
contains "$report" "curve 1 (Atlas mixing)"          "Curve 1 — Atlas mixing curve"
contains "$report" "curve 2 (work-cut)"              "Curve 2 — Work-cut curve"
contains "$report" "curve 3 (build invalidation)"    "Curve 3 — Build invalidation curve"
contains "$report" "curve 4 (Factory concurrency)"   "Curve 4 — Factory concurrency curve"
contains "$report" "curve 5 (economic)"              "Curve 5 — Economic curve"

# --- 2. Explicit outcome classification --------------------------------------
contains "$report" "explicit classification" "Outcome classification: Outcome C"
contains "$report" "Outcome A criterion present" "Outcome A"
contains "$report" "Outcome B criterion present" "Outcome B"
contains "$report" "primary quantity criterion"  "k_way_cut(8)"

# --- 3. Commands of record present -------------------------------------------
contains "$report" "candidate measurement command" "//experiments/atlas-work-topology:measure_topology"
contains "$report" "locality command of record"    "measure_bazel_locality.sh"
contains "$report" "full gate command"             "./verify"

# --- 4. Headline numbers agree with the frozen artifacts ---------------------
contains "$topology_control" "artifact: control k=8 cross edges = 96" '"cross_edges":96,'
contains "$topology_round4"  "artifact: round4 k=8 cross edges = 95"  '"cross_edges":95,'
contains "$report" "report: control 8-way cut 96/137" "96/137"
contains "$report" "report: round4 8-way cut 95/137"  "95/137"
contains "$report" "report: control 70.07%"           "70.07%"
contains "$report" "report: round4 69.34%"            "69.34%"

contains "$oracle_round4" "artifact: round4 D50 comparison 4 vs 3" \
    '"candidate":4,"control":3,"delta":1,"metric":"D50"'
contains "$report" "report: D50 control 3 -> candidate 4" "| 3 | 4 |"

contains "$fanout_round4" "artifact: round4 architecture cross-cell = 59" \
    'role_cross_cell_arch=59'
contains "$report" "report: architecture cross-cell invalidation column" \
    '`//experiments/...` excluded'

# --- 5. The round evidence backing the curves exists -------------------------
for role in round1 round2 round3 round4; do
    for suffix in targets.txt tests.txt fanout.txt fanout_delta.tsv; do
        f="$(rlocation _main/$pkg/$role/$role.$suffix)"
        [ -s "$f" ] || fail "round evidence: $role/$role.$suffix missing or empty"
    done
done
for doc in rounds/round1.md rounds/round23.md rounds/round4.md; do
    f="$(rlocation _main/$pkg/$doc)"
    [ -s "$f" ] || fail "round document: $doc missing or empty"
done

if [ "$status" -eq 0 ]; then
    echo "PASS: REPORT.md carries the five headline curves, the Outcome C classification, and headline numbers matching the frozen artifacts"
else
    echo "FAIL: the report law is not satisfied"
fi
exit "$status"
