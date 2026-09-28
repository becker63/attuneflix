#!/bin/bash
# Charter law for the Atlas Families experiment.
#   nix develop --command bazel test \
#     //experiments/atlas-families:charter_test --config=buildbuddy-rbe-arm64
#
#   1. The repo AGENTS.md keeps the no-reacquisition paragraph verbatim and
#      carries the dated acquisition-zone carve-out scoped to
#      experiments/atlas-families/ (provider contact is legal only after it).
#   2. REPORT.md carries the charter sections: protocol intent, acquisition
#      ruling, and cost envelope.
#
# Only bash builtins and grep are used so the test runs hermetically on RBE.
# Both documents are compared with every whitespace run folded to one space, so
# re-wrapping a paragraph does not fail the law but changing a word does.
set -euo pipefail

if [ -n "${TEST_SRCDIR:-}" ]; then
    export RUNFILES_DIR="$TEST_SRCDIR"
elif [ -z "${RUNFILES_DIR:-}" ] && [ -d "$0.runfiles" ]; then
    export RUNFILES_DIR="$(cd "$0.runfiles" && pwd)"
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

agents="$(rlocation _main/AGENTS.md)"
report="$(rlocation _main/experiments/atlas-families/REPORT.md)"

status=0
say_ok() { echo "OK   $1"; }
fail() { echo "FAIL $1"; status=1; }

folded() {
    local -a words
    read -r -d '' -a words < "$1" || true
    local IFS=' '
    printf '%s' "${words[*]}"
}

agents_text="$(folded "$agents")"
report_text="$(folded "$report")"

# `contains TEXT LABEL NEEDLE` — the folded document must contain NEEDLE.
contains() {
    if [[ "$1" == *"$3"* ]]; then say_ok "$2"; else fail "$2 (missing: $3)"; fi
}

frozen_rule="The frozen science is never re-run or retuned because implementation \
changed. Never: reacquire embeddings or Jev decisions; invoke OpenRouter or \
any provider; retune iteration 013; alter the frozen localization population, \
the two Three.js censors, Atlas's six directed atoms, depth seven, Datalog \
meaning, or the official evaluator meaning; expose evaluator gold to \
Localization; alter retained provider evidence; or create new scientific \
identities from path/refactor changes. Replay stays keyless; Atlas stays \
issue-, inference-, and gold-independent; exact replay and parity laws are \
never weakened."

contains "$agents_text" "AGENTS.md keeps the no-reacquisition paragraph verbatim" "$frozen_rule"
contains "$agents_text" "AGENTS.md carve-out is dated" \
    "Acquisition-zone carve-out (user ruling, 2026-09-28)."
contains "$agents_text" "AGENTS.md carve-out is scoped to the experiment" \
    "for the Atlas Families experiment only, and only within \`experiments/atlas-families/\` (the acquisition zone)."
contains "$agents_text" "AGENTS.md carve-out keeps every rule binding outside the zone" \
    "Outside the zone every prohibition above binds unchanged."
contains "$agents_text" "AGENTS.md carve-out keeps every rule binding inside the zone except acquisition" \
    "Inside the zone every prohibition above still binds except the experiment's own fresh acquisition"
contains "$agents_text" "AGENTS.md carve-out keeps the acquisition issue-blind" \
    "The acquisition is issue-blind (no issue text and no evaluator gold in any payload, state, or prompt)"
contains "$agents_text" "AGENTS.md keeps the Typed Parquet rule verbatim" \
    "It is read-only evidence: never modify, regenerate, or hand-edit it (this includes the frozen census parquet and REPORT.md)."

contains "$report_text" "REPORT.md has the protocol intent" "## Protocol intent"
contains "$report_text" "REPORT.md has the acquisition ruling" "## Acquisition ruling"
contains "$report_text" "REPORT.md dates the ruling" "2026-09-28"
contains "$report_text" "REPORT.md has the cost envelope" "## Cost envelope"
contains "$report_text" "REPORT.md states the per-pass envelope" "\$50 per acquisition pass"
contains "$report_text" "REPORT.md states the stop-check" \
    "if the projection exceeds the envelope, acquisition stops and the numbers go to the user."

if [ "$status" -ne 0 ]; then
    echo "charter_test: FAILED"
    exit 1
fi
echo "charter_test: PASSED"
