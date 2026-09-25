#!/bin/bash
# Bazel analyzed-graph locality evidence for one frozen revision
# (PREREGISTRATION.md "AMENDMENT — v2 acquisition", "Bazel locality").
#
# This is a SEPARATE execution/build evidence channel. It never substitutes for
# Grit acquisition: the source signature is the Atlas measurement.
#
# Usage: v2_bazel_locality.sh ROLE WORKTREE OUT_DIR FILE...
#
# Writes OUT_DIR/ROLE.targets.txt   (every analyzed target with its kind)
#        OUT_DIR/ROLE.tests.txt     (independently runnable test targets)
#        OUT_DIR/ROLE.fanout.txt    (direct dependents = srcs fan-out, per file)
#
# BAZEL_LOCALITY_UNIVERSE optionally restricts the queried target universe. The
# frozen baseline revision cannot be loaded with the full `//...` universe in a
# fresh output base (its Rust crate universe module extension cannot be
# evaluated), so its locality evidence uses the Rust-free source/build
# universe; the restriction is recorded in the report, never hidden.
set -eu
role="$1"; worktree="$2"; out="$3"; shift 3
universe="${BAZEL_LOCALITY_UNIVERSE:-//...}"
mkdir -p "$out"
cd "$worktree"
bazel query "$universe" --output=label_kind --noshow_progress | LC_ALL=C sort > "$out/$role.targets.txt"
bazel query "kind(\".*_test\", $universe)" --noshow_progress | LC_ALL=C sort > "$out/$role.tests.txt"
: > "$out/$role.fanout.txt"
for file in "$@"; do
    name="$(basename "$file")"
    echo "== targets declaring $name in srcs (universe: $universe)" >> "$out/$role.fanout.txt"
    bazel query "attr(srcs, \"$name\", $universe)" --noshow_progress | LC_ALL=C sort >> "$out/$role.fanout.txt"
    echo "  (dependents: $(bazel query "attr(srcs, \"$name\", $universe)" --noshow_progress | wc -l))" >> "$out/$role.fanout.txt"
done
echo "BAZEL_LOCALITY role=$role universe=$universe targets=$(wc -l < "$out/$role.targets.txt") tests=$(wc -l < "$out/$role.tests.txt")"
