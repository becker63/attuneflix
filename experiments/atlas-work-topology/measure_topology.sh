#!/bin/bash
# Command of record (PREREGISTRATION.md §6, §7, §8, §14):
#   nix develop --command bazel run //experiments/atlas-work-topology:measure_control_topology
#
# Freezes the co-change raw extract from the VCS history reachable from the
# control revision (never the experiment's own changes: they are descendants of
# the control commit), then re-admits the committed control evidence and writes
# `control.topology.json` and `control.cochange.json` into the source tree.
# Bash is only `bazel run` plumbing (the raw `git log --numstat` extract); every
# reported number is produced by Flix over the frozen world.
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

bin="$(rlocation _main/experiments/atlas-work-topology/control_topology_bin)"
root="${BUILD_WORKSPACE_DIRECTORY:?run this target with 'bazel run', not 'bazel build'}"
dir="$root/experiments/atlas-work-topology/control"
revision="$(tr -d '[:space:]' < "$dir/control.revision.txt")"

# Prefer the isolated control worktree; fall back to the live repository, which
# is equivalent because the revision is named explicitly.
worktree="${ATTUNE_CONTROL_WORKTREE:-/tmp/attuneflix-control}"
repo="$root"
if [ "$(git -C "$worktree" rev-parse HEAD 2>/dev/null || true)" = "$revision" ]; then
    repo="$worktree"
fi

history="$dir/control.cochange_history.txt"
git -C "$repo" log "$revision" --numstat --no-renames --format='C%x09%H' > "$history"

"$bin" "--jvm_flag=-Dattune.command=measure" \
       "--jvm_flag=-Dattune.sources=$dir/control.sources.parquet" \
       "--jvm_flag=-Dattune.facts=$dir/control.facts.parquet" \
       "--jvm_flag=-Dattune.files=$dir/control.files.txt" \
       "--jvm_flag=-Dattune.revision=$dir/control.revision.txt" \
       "--jvm_flag=-Dattune.cochange_history=$history" \
       "--jvm_flag=-Dattune.output_topology=$dir/control.topology.json" \
       "--jvm_flag=-Dattune.output_cochange=$dir/control.cochange.json"
