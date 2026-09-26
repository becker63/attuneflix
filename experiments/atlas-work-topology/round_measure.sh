#!/bin/bash
# Command of record (PREREGISTRATION.md §9, §10, §11; VAL-HC1-002/VAL-HC1-003):
#
#   nix develop --command bazel run //experiments/atlas-work-topology:measure_topology -- round1
#
# Materializes the round's architecture revision in an isolated git worktree
# under /tmp, derives that revision's admitted path list with the one §2
# admission rule, reads that revision's source bytes (path, sha256, bytes,
# language only -- NO Grit, NO fact re-acquisition), and writes the round
# identity map, static work-topology and signature-preservation oracle into
# `experiments/atlas-work-topology/<role>/`. Bash is only the worktree checkout
# and the raw tracked-path listing; every reported number is produced in Flix.
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

role="${1:-round1}"
bin="$(rlocation _main/experiments/atlas-work-topology/round_topology_bin)"

root="${BUILD_WORKSPACE_DIRECTORY:?run this target with 'bazel run', not 'bazel build'}"
dir="$root/experiments/atlas-work-topology/$role"
control="$root/experiments/atlas-work-topology/control"
worktree="${ATTUNE_ROUND_WORKTREE:-/tmp/attuneflix-$role}"
mkdir -p "$dir"

revision="$(tr -d '[:space:]' < "$dir/$role.revision.txt")"

if [ ! -e "$worktree/.git" ] || [ "$(git -C "$worktree" rev-parse HEAD 2>/dev/null || true)" != "$revision" ]; then
    if [ -e "$worktree" ]; then git -C "$root" worktree remove --force "$worktree"; fi
    git -C "$root" worktree add "$worktree" "$revision"
fi

listing="$(mktemp)"; trap 'rm -f "$listing"' EXIT
git -C "$worktree" ls-tree -r --name-only HEAD > "$listing"

"$bin" "--jvm_flag=-Dattune.command=candidate_manifest" \
       "--jvm_flag=-Dattune.list=$listing" \
       "--jvm_flag=-Dattune.files=$dir/$role.files.txt"

"$bin" "--jvm_flag=-Dattune.command=candidate_sources" \
       "--jvm_flag=-Dattune.root=$worktree" \
       "--jvm_flag=-Dattune.manifest=$dir/$role.files.txt" \
       "--jvm_flag=-Dattune.sources=$dir/$role.sources.txt"

"$bin" "--jvm_flag=-Dattune.command=measure" \
       "--jvm_flag=-Dattune.role=$role" \
       "--jvm_flag=-Dattune.revision=$dir/$role.revision.txt" \
       "--jvm_flag=-Dattune.control_revision=$control/control.revision.txt" \
       "--jvm_flag=-Dattune.control_sources=$control/control.sources.parquet" \
       "--jvm_flag=-Dattune.control_facts=$control/control.facts.parquet" \
       "--jvm_flag=-Dattune.files=$dir/$role.files.txt" \
       "--jvm_flag=-Dattune.sources=$dir/$role.sources.txt" \
       "--jvm_flag=-Dattune.output_identity=$dir/$role.identity_map.json" \
       "--jvm_flag=-Dattune.output_topology=$dir/$role.topology.json" \
       "--jvm_flag=-Dattune.output_oracle=$dir/$role.oracle.json"

echo "ROUND role=$role revision=$revision worktree=$worktree out=$dir"
