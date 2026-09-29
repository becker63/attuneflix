#!/bin/bash
# Issue-blindness law for the Atlas Families acquisition.
#   nix develop --command bazel test \
#     //experiments/atlas-families:issue_blindness_test --config=buildbuddy-rbe-arm64
#
# 1. The families tool's own sources name no Localization module, no frozen
#    population, issue, or gold space, and no issue field.
# 2. Every retained Jev decision request is the fixed families state and names
#    no benchmark issue field, gold, or benchmark payload. Repository paths
#    containing the ordinary word "issue" remain admitted source facts.
# 3. Every retained embedding request is a document batch under the pinned
#    recipe and names no benchmark issue field.
# Exact reconstruction of every retained request from the protocol and the
# world alone is the replay law (`replay_<world>`); this law scans the bytes.
#
# Bash, find, grep, and awk are available on the pinned RBE platform.
set -euo pipefail

if [ -n "${TEST_SRCDIR:-}" ]; then
    export RUNFILES_DIR="$TEST_SRCDIR"
elif [ -z "${RUNFILES_DIR:-}" ] && [ -d "$0.runfiles" ]; then
    export RUNFILES_DIR="$(cd "$0.runfiles" && pwd)"
fi

status=0
fail() { echo "FAIL $1"; status=1; }
ok() { echo "OK   $1"; }

# Markers of issue text, evaluator gold, and the frozen localization inputs.
source_markers=(
    "Localization." "gold.parquet" "jev-selection-diagnosis-v1" "localization-inputs"
    "localization-v1" "evaluation-inputs" "problem_statement" "instance_id"
)
sources=0
decisions=0
embeddings=0
for file in "$RUNFILES_DIR"/_main/experiments/atlas-families/Main.flix \
    $(find "$RUNFILES_DIR"/_main/experiments/atlas-families/src -name '*.flix' | sort); do
    sources=$((sources + 1))
    for marker in "${source_markers[@]}"; do
        if grep -qF -- "$marker" "$file"; then fail "${file##*/_main/} names $marker"; fi
    done
done

scanner="$RUNFILES_DIR/_main/experiments/atlas-families/issue_blindness_payload.awk"
decision_root="$RUNFILES_DIR/_main/.attune/jev-families-raw-v1"
embedding_root="$RUNFILES_DIR/_main/.attune/families-embeddings-v1"
decisions="$(find "$decision_root" -path '*/raw/*.json' | wc -l)"
embeddings="$(find "$embedding_root" -path '*/raw/*.json' | wc -l)"
if ! find "$decision_root" -path '*/raw/*.json' -exec awk -v kind=decision -f "$scanner" {} +; then
    status=1
fi
if ! find "$embedding_root" -path '*/raw/*.json' -exec awk -v kind=embedding -f "$scanner" {} +; then
    status=1
fi

[ "$sources" -gt 0 ] || fail "no families sources scanned"
[ "$decisions" -gt 0 ] || fail "no retained decisions scanned"
[ "$embeddings" -gt 0 ] || fail "no retained embedding batches scanned"
ok "scanned $sources sources, $decisions decision exchanges, $embeddings embedding exchanges"

if [ "$status" -ne 0 ]; then
    echo "issue_blindness_test: FAILED"
    exit 1
fi
echo "issue_blindness_test: PASSED"
