#!/bin/bash
# Declared typed-artifact boundary law (K4 Hill-Climb Round 4;
# PREREGISTRATION.md §7, §14; VAL-HC4-001).
#   nix develop --command bazel test \
#     //experiments/atlas-work-topology:artifact_boundary_test --config=buildbuddy-rbe
#
# Consumes the declared stage artifacts — the outputs of the cacheable actions
# `:control_signature_tables` and `:control_topology_documents` — and checks
# each one against the frozen committed evidence under `control/`. Byte
# equality is the whole check: a downstream consumer may reuse the declared
# boundary from the action cache only because the stage re-derives the frozen
# artifact exactly. No stage is re-run here, no source text is parsed, and no
# ambient state is read; the derivation belongs to the cached action and the
# typed-schema round-trip belongs to `control_signature_artifacts_test` and
# `control_topology_artifacts_test`.
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

pkg="experiments/atlas-work-topology"
world="$(dirname "$(rlocation _main/$pkg/control/control.files.txt)")"

status=0

check() {
    local declared="$1" committed="$2" label="$3"
    if cmp -s "$declared" "$committed"; then
        echo "OK   ${label}"
    else
        echo "FAIL ${label}"
        status=1
    fi
}

# The signature stage's typed artifact boundary.
check "$(rlocation _main/$pkg/control_signature_tables/control.signatures.parquet)" \
      "$world/control.signatures.parquet" \
      "signature stage: control.signatures.parquet (attune-atlas-signature-observations-v1)"
check "$(rlocation _main/$pkg/control_signature_tables/control.summaries.parquet)" \
      "$world/control.summaries.parquet" \
      "signature stage: control.summaries.parquet (attune-atlas-signature-summary-v1)"
check "$(rlocation _main/$pkg/control_signature_tables/control.identity_map.json)" \
      "$world/control.identity_map.json" \
      "signature stage: control.identity_map.json (logical identity map)"

# The work-topology / co-change stage's document boundary.
check "$(rlocation _main/$pkg/control_topology_documents/control.topology.json)" \
      "$world/control.topology.json" \
      "topology stage: control.topology.json (cuts k=2..10, cells, hotspots)"
check "$(rlocation _main/$pkg/control_topology_documents/control.cochange.json)" \
      "$world/control.cochange.json" \
      "topology stage: control.cochange.json (raw/normalized/line-weighted)"

if [ "$status" -eq 0 ]; then
    echo "PASS: both declared typed-artifact boundaries re-derive the frozen control evidence"
else
    echo "FAIL: a declared typed-artifact boundary differs from the frozen control evidence"
fi
exit "$status"
