#!/bin/bash
# attuneflix-grit-acquisition-v2 seam (PREREGISTRATION.md "AMENDMENT — v2
# acquisition").
#
# Usage: v2_extract.sh TOOL ROLE WORKTREE OUT_DIR
#
#   TOOL      path to the built acquisition binary
#             (bazel-bin/experiments/atlas-parallelism/acquire)
#   ROLE      baseline | cleaned
#   WORKTREE  isolated git worktree holding the frozen revision
#   OUT_DIR   experiments/atlas-parallelism/v2
#
# Writes OUT_DIR/sources/ROLE.files.txt (the admitted file list: the exact
# inclusion record, one sorted repository-relative path per line), then runs the
# repository's own Grit acquisition path over WORKTREE to write
# OUT_DIR/sources/ROLE.sources.parquet (path, sha256, byte length, language)
# and OUT_DIR/grit/ROLE.facts.parquet (every emitted Repository.Grit.Fact).
#
# The file list is the closure's own admitted-kind rule: a tracked path is
# admitted when Repository.Grit.language(path) admits it. Deterministic over the
# worktree's checked-out revision; nothing else is read.
set -eu

tool="$1"; role="$2"; worktree="$3"; out="$4"
test -x "$tool"
test -d "$worktree"

manifest="$out/sources/$role.files.txt"
mkdir -p "$out/sources" "$out/grit"

revision="$(git -C "$worktree" rev-parse HEAD)"
printf '%s\n' "$revision" > "$out/sources/$role.revision.txt"

git -C "$worktree" ls-tree -r --name-only HEAD \
    | grep -v '^\.attune/' \
    | grep -E '(\.(flix|java|js|jsx|ts|tsx|mjs|cjs|mts|cts|bzl|bazel|star)$|(^|/)(BUILD|WORKSPACE)$)' \
    | LC_ALL=C sort > "$manifest"

echo "ATLAS_PARALLELISM_MANIFEST role=$role revision=$revision files=$(wc -l < "$manifest")"

"$tool" \
    "--jvm_flag=-Dattune.command=acquire" \
    "--jvm_flag=-Dattune.root=$worktree" \
    "--jvm_flag=-Dattune.manifest=$manifest" \
    "--jvm_flag=-Dattune.sources=$out/sources/$role.sources.parquet" \
    "--jvm_flag=-Dattune.facts=$out/grit/$role.facts.parquet"
