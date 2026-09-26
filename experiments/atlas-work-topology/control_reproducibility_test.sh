#!/bin/bash
# Exact-determinism re-acquisition (PREREGISTRATION.md §2; VAL-CONTROL-003).
#   nix develop --command bazel test //experiments/atlas-work-topology:control_reproducibility_test --config=buildbuddy-rbe
#
# Runs the frozen acquisition twice over the same isolated control worktree and
# delegates every comparison to Flix (`attune.command=control_verify`), which
# fails with a non-zero exit on any byte difference. Bash is only the worktree
# checkout and the two JVM invocations.
set -euo pipefail

# The Java launcher needs the merged runfiles root; a test gets TEST_SRCDIR, and
# `bazel run` (if reused) does not export RUNFILES_DIR, so derive it too.
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

revision="$1"
bin="$(rlocation _main/experiments/atlas-work-topology/acquire_bin)"
committed="$(dirname "$(rlocation _main/experiments/atlas-work-topology/control/control.files.txt)")"
worktree="${ATTUNE_CONTROL_WORKTREE:-/tmp/attuneflix-control}"
tmp="${TEST_TMPDIR:-$(mktemp -d)}"
listing="$tmp/listing.txt"
manifest="$tmp/control.files.txt"

if [ ! -e "$worktree" ] || [ "$(git -C "$worktree" rev-parse HEAD 2>/dev/null || true)" != "$revision" ]; then
    repo=""
    dir="$(readlink -f "$committed")"
    while [ "$dir" != "/" ] && [ -n "$dir" ]; do
        if [ -e "$dir/.git" ]; then repo="$dir"; break; fi
        dir="$(dirname "$dir")"
    done
    if [ -z "$repo" ]; then
        echo "FAIL: isolated control worktree $worktree is absent and the repository was not found" >&2
        exit 1
    fi
    if [ -e "$worktree" ]; then git -C "$repo" worktree remove --force "$worktree" >/dev/null; fi
    git -C "$repo" worktree add "$worktree" "$revision" >/dev/null
fi

git -C "$worktree" ls-tree -r --name-only HEAD > "$listing"

"$bin" "--jvm_flag=-Dattune.command=control_manifest" \
       "--jvm_flag=-Dattune.list=$listing" \
       "--jvm_flag=-Dattune.files=$manifest"

acquire_into() {
    local target="$1"
    "$bin" "--jvm_flag=-Dattune.command=acquire" \
           "--jvm_flag=-Dattune.root=$worktree" \
           "--jvm_flag=-Dattune.manifest=$manifest" \
           "--jvm_flag=-Dattune.sources=$target/control.sources.parquet" \
           "--jvm_flag=-Dattune.facts=$target/control.facts.parquet"
}
echo "RUN 1"; acquire_into "$tmp/a"
echo "RUN 2"; acquire_into "$tmp/b"

"$bin" "--jvm_flag=-Dattune.command=control_verify" \
       "--jvm_flag=-Dattune.a_sources=$tmp/a/control.sources.parquet" \
       "--jvm_flag=-Dattune.a_facts=$tmp/a/control.facts.parquet" \
       "--jvm_flag=-Dattune.b_sources=$tmp/b/control.sources.parquet" \
       "--jvm_flag=-Dattune.b_facts=$tmp/b/control.facts.parquet" \
       "--jvm_flag=-Dattune.committed_sources=$committed/control.sources.parquet" \
       "--jvm_flag=-Dattune.committed_facts=$committed/control.facts.parquet" \
       "--jvm_flag=-Dattune.files_rederived=$manifest" \
       "--jvm_flag=-Dattune.files_committed=$committed/control.files.txt" \
       "--jvm_flag=-Dattune.revision_file=$committed/control.revision.txt" \
       "--jvm_flag=-Dattune.revision_expected=$revision"
