#!/bin/bash
# Committed-artifact verification (PREREGISTRATION.md §9, §10; VAL-HC1-002).
#
#   nix develop --command bazel test //experiments/atlas-work-topology:round1_artifacts_test --config=buildbuddy-rbe
#
# Re-derives the round identity map, static work-topology and signature oracle
# from the committed control evidence and the round's admitted path/source
# manifests, and compares them with the committed artifacts. Every comparison
# runs in Flix (`attune.command=verify`); a mismatch is a non-zero exit. The
# test never touches the candidate worktree or the network.
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

bin="$(rlocation _main/experiments/atlas-work-topology/round_topology_bin)"
rel="experiments/atlas-work-topology"
dir="$(dirname "$(rlocation _main/$rel/round1/round1.files.txt)")"
control="$(dirname "$(rlocation _main/$rel/control/control.files.txt)")"

"$bin" "--jvm_flag=-Dattune.command=verify" \
       "--jvm_flag=-Dattune.revision=$dir/round1.revision.txt" \
       "--jvm_flag=-Dattune.control_revision=$control/control.revision.txt" \
       "--jvm_flag=-Dattune.control_sources=$control/control.sources.parquet" \
       "--jvm_flag=-Dattune.control_facts=$control/control.facts.parquet" \
       "--jvm_flag=-Dattune.files=$dir/round1.files.txt" \
       "--jvm_flag=-Dattune.sources=$dir/round1.sources.txt" \
       "--jvm_flag=-Dattune.output_identity=$dir/round1.identity_map.json" \
       "--jvm_flag=-Dattune.output_topology=$dir/round1.topology.json" \
       "--jvm_flag=-Dattune.output_oracle=$dir/round1.oracle.json"
