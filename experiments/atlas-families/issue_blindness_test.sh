#!/bin/bash
# Issue-blindness law for the Atlas Families acquisition.
#   nix develop --command bazel test \
#     //experiments/atlas-families:issue_blindness_test --config=buildbuddy-rbe-arm64
#
# 1. The families tool's own sources name no Localization module, no frozen
#    population, issue, or gold space, and no issue field.
# 2. Every retained Jev decision request is the fixed families state and names
#    no issue, gold, or benchmark field.
# 3. Every retained embedding request is a document batch under the pinned
#    recipe and names no benchmark issue field.
# Exact reconstruction of every retained request from the protocol and the
# world alone is the replay law (`replay_<world>`); this law scans the bytes.
#
# Only bash builtins, find, and grep are used so the test runs hermetically on RBE.
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
payload_markers=(
    "problem_statement" "hints_text" "instance_id" "fail_to_pass" "pass_to_pass"
    "gold" "issue"
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

# The retained request of one exchange file: everything before its response
# (the exchange keys are written in sorted order, so `request` precedes it).
request() {
    local content
    content="$(<"$1")"
    printf '%s' "${content%%\",\"response\":\"*}"
}

while IFS= read -r file; do
    decisions=$((decisions + 1))
    payload="$(request "$file")"
    if [[ "$payload" != *'ATTUNE_FAMILIES_STATE_V1\\nobjective: family-formation\\n'* ]]; then
        fail "${file##*/_main/} is not a families state"
    fi
    for marker in "${payload_markers[@]}"; do
        if [[ "${payload,,}" == *"$marker"* ]]; then fail "${file##*/_main/} names $marker"; fi
    done
done < <(find "$RUNFILES_DIR"/_main/.attune/jev-families-raw-v1 -path '*/raw/*.json' | sort)

while IFS= read -r file; do
    embeddings=$((embeddings + 1))
    payload="$(request "$file")"
    if [[ "$payload" != *'"protocol":"attune-families-embeddings-v1"'* ||
        "$payload" != *'\"encoding_format\":\"base64\"'* ]]; then
        fail "${file##*/_main/} is not a families document batch"
    fi
    for marker in "problem_statement" "hints_text" "FAIL_TO_PASS" "PASS_TO_PASS"; do
        if [[ "$payload" == *"$marker"* ]]; then fail "${file##*/_main/} names $marker"; fi
    done
done < <(find "$RUNFILES_DIR"/_main/.attune/families-embeddings-v1 -path '*/raw/*.json' | sort)

[ "$sources" -gt 0 ] || fail "no families sources scanned"
[ "$decisions" -gt 0 ] || fail "no retained decisions scanned"
[ "$embeddings" -gt 0 ] || fail "no retained embedding batches scanned"
ok "scanned $sources sources, $decisions decision exchanges, $embeddings embedding exchanges"

if [ "$status" -ne 0 ]; then
    echo "issue_blindness_test: FAILED"
    exit 1
fi
echo "issue_blindness_test: PASSED"
