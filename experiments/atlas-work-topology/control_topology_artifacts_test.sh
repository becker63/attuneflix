#!/bin/bash
# Committed-artifact verification (PREREGISTRATION.md §6, §8; VAL-TOPOLOGY-*).
#   nix develop --command bazel test //experiments/atlas-work-topology:control_topology_artifacts_test --config=buildbuddy-rbe
#
# Re-derives the work-topology document and the co-change work graph from the
# committed control evidence and compares them with the committed artifacts.
# Every comparison runs in Flix (`attune.command=verify`); a mismatch is a
# non-zero exit.
set -euo pipefail

if [ -n "${TEST_SRCDIR:-}" ]; then
    export RUNFILES_DIR="$TEST_SRCDIR" JAVA_RUNFILES="$TEST_SRCDIR"
elif [ -z "${RUNFILES_DIR:-}" ] && [ -d "$0.runfiles" ]; then
    export RUNFILES_DIR="$(cd "$0.runfiles" && pwd)" JAVA_RUNFILES="$(cd "$0.runfiles" && pwd)"
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

bin="$(rlocation _main/experiments/atlas-work-topology/control_topology_bin)"
dir="$(dirname "$(rlocation _main/experiments/atlas-work-topology/control/control.files.txt)")"

"$bin" "--jvm_flag=-Dattune.command=verify" \
       "--jvm_flag=-Dattune.sources=$dir/control.sources.parquet" \
       "--jvm_flag=-Dattune.facts=$dir/control.facts.parquet" \
       "--jvm_flag=-Dattune.files=$dir/control.files.txt" \
       "--jvm_flag=-Dattune.revision=$dir/control.revision.txt" \
       "--jvm_flag=-Dattune.cochange_history=$dir/control.cochange_history.txt" \
       "--jvm_flag=-Dattune.topology=$dir/control.topology.json" \
       "--jvm_flag=-Dattune.cochange=$dir/control.cochange.json"
