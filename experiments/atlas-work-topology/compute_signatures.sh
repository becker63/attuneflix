#!/bin/bash
# Command of record (PREREGISTRATION.md §3, §14):
#   nix develop --command bazel run //experiments/atlas-work-topology:compute_control_signatures
#
# Re-admits the committed control evidence, evaluates the frozen depth-7 Atlas
# family over the frozen seed panel, and writes the typed signature tables plus
# the logical identity map into the source tree. Bash is only `bazel run`
# plumbing; every number is produced by Flix over the frozen world.
set -euo pipefail

# `bazel run` does not export RUNFILES_DIR to the shell; the Java launcher we
# invoke needs it, so derive it from this script's own runfiles tree first.
if [ -z "${RUNFILES_DIR:-}${TEST_SRCDIR:-}" ] && [ -d "$0.runfiles" ]; then
    export RUNFILES_DIR="$(cd "$0.runfiles" && pwd)"
fi
if [ -n "${RUNFILES_DIR:-}" ]; then export JAVA_RUNFILES="$RUNFILES_DIR"; fi

# --- begin runfiles.bash initialization v3 ---
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---

bin="$(rlocation _main/experiments/atlas-work-topology/control_signatures_bin)"
root="${BUILD_WORKSPACE_DIRECTORY:?run this target with 'bazel run', not 'bazel build'}"
dir="$root/experiments/atlas-work-topology/control"

"$bin" "--jvm_flag=-Dattune.command=compute" \
       "--jvm_flag=-Dattune.sources=$dir/control.sources.parquet" \
       "--jvm_flag=-Dattune.facts=$dir/control.facts.parquet" \
       "--jvm_flag=-Dattune.revision=$dir/control.revision.txt" \
       "--jvm_flag=-Dattune.output_signatures=$dir/control.signatures.parquet" \
       "--jvm_flag=-Dattune.output_summaries=$dir/control.summaries.parquet" \
       "--jvm_flag=-Dattune.output_identity=$dir/control.identity_map.json"
