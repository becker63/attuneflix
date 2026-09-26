#!/bin/bash
# Command of record (PREREGISTRATION.md §2, §14):
#   nix develop --command bazel run //experiments/atlas-work-topology:acquire
#
# Materializes the frozen control revision in an isolated git worktree under
# /tmp (never the live worktree) and freezes the typed evidence under
# experiments/atlas-work-topology/control/. Bash is only the `bazel run`
# plumbing (worktree checkout + raw tracked-path listing); the inclusion
# record and the acquisition both run in Flix.
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

revision="$1"
bin="$(rlocation _main/experiments/atlas-work-topology/acquire_bin)"
worktree="/tmp/attuneflix-control"

root="${BUILD_WORKSPACE_DIRECTORY:?run this target with 'bazel run', not 'bazel build'}"
out="$root/experiments/atlas-work-topology/control"
mkdir -p "$out"

if [ ! -e "$worktree" ] || [ "$(git -C "$worktree" rev-parse HEAD 2>/dev/null || true)" != "$revision" ]; then
    if [ -e "$worktree" ]; then git -C "$root" worktree remove --force "$worktree"; fi
    git -C "$root" worktree add "$worktree" "$revision"
fi

listing="$(mktemp)"; trap 'rm -f "$listing"' EXIT
git -C "$worktree" ls-tree -r --name-only HEAD > "$listing"

"$bin" "--jvm_flag=-Dattune.command=control_manifest" \
       "--jvm_flag=-Dattune.list=$listing" \
       "--jvm_flag=-Dattune.files=$out/control.files.txt"
printf '%s\n' "$revision" > "$out/control.revision.txt"
"$bin" "--jvm_flag=-Dattune.command=acquire" \
       "--jvm_flag=-Dattune.root=$worktree" \
       "--jvm_flag=-Dattune.manifest=$out/control.files.txt" \
       "--jvm_flag=-Dattune.sources=$out/control.sources.parquet" \
       "--jvm_flag=-Dattune.facts=$out/control.facts.parquet"

echo "CONTROL revision=$revision worktree=$worktree out=$out"
