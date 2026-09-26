#!/bin/bash
# Bazel build-locality and invalidation evidence for one revision
# (PREREGISTRATION.md §7; VAL-TOPOLOGY-003).
#
#   nix develop --command bash experiments/atlas-work-topology/scripts/measure_bazel_locality.sh control
#
# Writes, into `experiments/atlas-work-topology/<role>/`:
#   <role>.targets.txt   every analyzed target in the query universe, with kind
#   <role>.tests.txt     every independently runnable test target
#   <role>.fanout.txt    per admitted source file: the targets declaring it in
#                        `srcs`, the direct-dependent count, and the test-target
#                        invalidation fanout
#
# This is a SEPARATE execution/build evidence channel. It is a read-only
# `bazel query` of the revision's declared BUILD files, never inferred from
# source text, and never a substitute for Grit acquisition or the Atlas
# measurement.
#
# The revision is queried in its isolated git worktree (default
# /tmp/attuneflix-control), so the measured BUILD graph is the revision's, not
# the live tree's. BAZEL_LOCALITY_UNIVERSE overrides the queried universe for
# revisions whose crate_universe module extension cannot be evaluated in a
# fresh output base; the control revision loads the full `//...` universe, and
# the universe actually queried is recorded in the artifact header.
set -euo pipefail

role="${1:?usage: measure_bazel_locality.sh ROLE [WORKTREE]}"
here="$(cd "$(dirname "$0")/.." && pwd)"
root="${BUILD_WORKSPACE_DIRECTORY:-$(git -C "$here" rev-parse --show-toplevel)}"
worktree="${2:-${ATTUNE_LOCALITY_WORKTREE:-/tmp/attuneflix-control}}"
universe="${BAZEL_LOCALITY_UNIVERSE:-//...}"
files="${ATTUNE_LOCALITY_FILES:-$here/$role/$role.files.txt}"
out="$here/$role"
revision_file="$here/$role/$role.revision.txt"

if [ ! -f "$files" ]; then
    echo "FAIL: missing admitted file list: $files" >&2
    exit 1
fi
if [ ! -f "$revision_file" ]; then
    echo "FAIL: missing revision record: $revision_file" >&2
    exit 1
fi
mkdir -p "$out"

# The role's revision is a declared protocol constant, read from the committed
# `<role>.revision.txt`. One shared worktree keeps the warm Bazel output base
# (§7 documents that a fresh output base cannot evaluate the revision's Rust
# crate universe), so the worktree is materialized once and then checked out to
# the role's revision; a re-run for either role is idempotent and deterministic.
revision="$(tr -d '[:space:]' < "$revision_file")"
if [ ! -e "$worktree/.git" ]; then
    git -C "$root" worktree add "$worktree" "$revision" >/dev/null
elif [ "$(git -C "$worktree" rev-parse HEAD 2>/dev/null || true)" != "$revision" ]; then
    git -C "$worktree" checkout --quiet "$revision"
fi

cd "$worktree"

revision="$(git rev-parse HEAD)"
bazel query "$universe" --output=label_kind --noshow_progress | LC_ALL=C sort > "$out/$role.targets.txt"
bazel query "kind(\".*_test\", $universe)" --noshow_progress | LC_ALL=C sort > "$out/$role.tests.txt"

{
    echo "# $role.fanout.txt — Bazel direct target fanout per admitted source file (PREREGISTRATION.md §7)"
    echo "# worktree=$worktree revision=$revision universe=$universe"
    echo "# declaring_actions: targets declaring the file basename in srcs (one analysis action each)"
    echo "# direct_dependents: rdeps(universe, declaring, 1) minus the declaring targets"
    echo "# test_invalidation: independently runnable test targets in rdeps(universe, declaring)"
    echo "# basename matching is the bound §7 protocol; a shared basename is reported, never hidden"
} > "$out/$role.fanout.txt"

while IFS= read -r file; do
    [ -n "$file" ] || continue
    name="$(basename "$file")"
    declaring="$(bazel query "attr(srcs, \"$name\", $universe)" --noshow_progress 2>/dev/null | LC_ALL=C sort || true)"

    if [ -z "$declaring" ]; then
        declaring_actions=0
        direct_dependents=0
        test_invalidation=0
        dependent_list=""
        test_list=""
    else
        labels="set($(printf '%s ' $declaring))"
        declaring_actions="$(printf '%s\n' "$declaring" | grep -c '[^[:space:]]' || true)"
        dependents="$(bazel query "rdeps($universe, $labels, 1)" --noshow_progress 2>/dev/null | LC_ALL=C sort || true)"
        dependent_list="$(comm -13 <(printf '%s\n' "$declaring" | LC_ALL=C sort) <(printf '%s\n' "$dependents" | LC_ALL=C sort) | grep -v '^[[:space:]]*$' || true)"
        direct_dependents="$(printf '%s\n' "$dependent_list" | grep -c '[^[:space:]]' || true)"
        test_list="$(bazel query "kind(\".*_test\", rdeps($universe, $labels))" --noshow_progress 2>/dev/null | LC_ALL=C sort || true)"
        test_invalidation="$(printf '%s\n' "$test_list" | grep -c '[^[:space:]]' || true)"
    fi

    {
        echo "== $file"
        echo "declaring_actions: $declaring_actions"
        echo "direct_dependents: $direct_dependents"
        echo "test_invalidation: $test_invalidation"
        echo "declaring_targets:"
        [ -z "$declaring" ] || printf '  %s\n' $declaring
        echo "direct_dependent_targets:"
        [ -z "$dependent_list" ] || printf '  %s\n' $dependent_list
        echo "test_invalidation_targets:"
        [ -z "$test_list" ] || printf '  %s\n' $test_list
    } >> "$out/$role.fanout.txt"
done < "$files"

echo "BAZEL_LOCALITY role=$role revision=$revision universe=$universe worktree=$worktree" \
     "targets=$(wc -l < "$out/$role.targets.txt") tests=$(wc -l < "$out/$role.tests.txt") files=$(wc -l < "$files")"
