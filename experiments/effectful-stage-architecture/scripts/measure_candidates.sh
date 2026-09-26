#!/bin/bash
# Candidate measurement driver for the Effectful Typed-Stage mission
# (PREREGISTRATION.md §7, §8, §10; contributes the A/B records of
# VAL-METRIC-001).
#
#   nix develop --command bazel run \
#       //experiments/effectful-stage-architecture:measure_candidates
#
# The instrument of record is a pure function of a revision's tracked tree and
# its declared BUILD graph, so a candidate generation is measured *at its own
# revision*, never at the working tip. For each named candidate this driver
# creates a detached git worktree at the frozen revision, runs
# `scripts/measure_baseline_metrics.sh` inside it with the record path passed
# explicitly, and removes the worktree. The record's `working_commit` therefore
# names exactly the measured tree, and `control_commit` stays the frozen control
# `09e27244af9340aa616116a93ea02472e7521ba5`.
#
# Named candidates (frozen revisions of this branch):
#   candidate-a  3efee12  extract the stable contract kernel
#   candidate-b  38deb855 capability effects, handlers, ambient IO eliminated
#
# Override the set for later generations without editing the driver:
#   ATTUNE_CANDIDATES="candidate-c=<rev> candidate-d=<rev>" bazel run ...
#
# The records are written into `experiments/effectful-stage-architecture/
# candidates/` in the workspace checkout, replacing the committed ones in place;
# `candidates/README.md` states the provenance and the delta tables. Nothing
# else is written, and the frozen `baseline-metrics.json` is never touched.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="${BUILD_WORKSPACE_DIRECTORY:-$(cd "$here/../../.." && pwd)}"
pkg="experiments/effectful-stage-architecture"
outdir="$root/$pkg/candidates"
instrument="$pkg/scripts/measure_baseline_metrics.sh"

# `bazel run` may spawn with a PATH that omits the Nix dev-shell tools; locate a
# `jq` explicitly so the target is self-contained (as in the instrument).
if ! command -v jq >/dev/null 2>&1; then
    for jqbin in /usr/bin/jq /nix/store/*-jq-*/bin/jq; do
        if [ -x "$jqbin" ]; then PATH="$(dirname "$jqbin"):$PATH"; break; fi
    done
fi

if [ -n "${ATTUNE_CANDIDATES:-}" ]; then
    read -r -a specs <<< "$ATTUNE_CANDIDATES"
else
    specs=(
        candidate-a=3efee12b2fb83b62727c9a09fd98c79bf3c5643c
        candidate-b=38deb855119efe1f8d8c65602d1b65d4883ee01a
    )
fi

mkdir -p "$outdir"
for spec in "${specs[@]}"; do
    name="${spec%%=*}"
    rev="${spec##*=}"
    if [ "$name" = "$spec" ] || [ -z "$rev" ]; then
        echo "measure_candidates: expected <name>=<revision>, got '$spec'" >&2
        exit 2
    fi
    git -C "$root" rev-parse --verify --quiet "$rev^{commit}" >/dev/null || {
        echo "measure_candidates: unknown revision '$rev' for '$name'" >&2
        exit 2
    }
    # A stable worktree path per candidate (not `mktemp -d`): the Bazel output
    # base is keyed by the workspace path, so a stable path reuses one output
    # base across runs instead of leaking several gigabytes per invocation.
    wt="${TMPDIR:-/tmp}/attuneflix-cand-${name}"
    [ -e "$wt" ] && { git -C "$root" worktree remove --force "$wt" >/dev/null 2>&1 || rm -rf "$wt"; }
    cleanup() { git -C "$root" worktree remove --force "$wt" >/dev/null 2>&1 || rm -rf "$wt"; }
    trap cleanup EXIT
    git -C "$root" worktree add --detach "$wt" "$rev" >/dev/null
    echo "measure_candidates: $name at $(git -C "$wt" rev-parse HEAD)"
    # The instrument resolves its root from `BUILD_WORKSPACE_DIRECTORY` when that
    # is set, so it must be cleared here or it would measure this checkout
    # instead of the worktree (and record the wrong revision).
    ( cd "$wt" && env -u BUILD_WORKSPACE_DIRECTORY -u BUILD_WORKING_DIRECTORY \
        bash "$instrument" "$outdir/$name.json" )
    cleanup
    trap - EXIT
    # The BUILD channel is a `bazel query` that can fail quietly (a full disk or
    # a dead server returns nothing), which would record a zero invalidation
    # count as if it had been measured. Refuse such a record.
    jq -e --arg r "$(git -C "$root" rev-parse --verify "$rev^{commit}")" \
        '.working_commit == $r and .channels.build.skipped == false
         and .channels.build.analyzed_targets > 0 and .channels.build.test_targets > 0
         and (.channels.build.cross_stage_test_invalidation > 0
              or .channels.build.cross_stage_test_invalidation_all_tests > 0)' \
        "$outdir/$name.json" >/dev/null || {
        echo "measure_candidates: record for '$name' is not a faithful reading of $rev (wrong revision, or its BUILD channel degraded or was skipped)" >&2
        exit 1
    }
done

echo "measure_candidates: wrote ${#specs[@]} record(s) under $outdir"
