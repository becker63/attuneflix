#!/bin/bash
# Committed-artifact reproducibility check (PREREGISTRATION.md §9, §10; VAL-HC23-003).
#
#   nix develop --command bazel test \
#     //experiments/atlas-work-topology:round2_reproducibility_test --config=buildbuddy-rbe
#
# Re-derives the round identity map, static work-topology and signature oracle
# from the committed control evidence and the round's admitted path/source
# manifests (`attune.command=measure`, the same pure derivation the round was
# measured with) and compares them with the committed artifacts byte-for-byte.
# A mismatch is a non-zero exit. The test never touches the candidate worktree
# or the network.
#
# This is the round-2 guard rather than `round_artifacts_test.sh`'s full
# `attune.command=verify`: the round-2 revision 10f3a21 modified
# `src/BUILD.bazel` with a declared cell-public-surface comment and round 3
# reverted it. The implemented `RoundMeasure.verify` production-drift proxy
# (any `src/` file whose bytes changed at the same path) therefore reports
# `O4 = false` on that revision, and §10/S2 forbid re-tuning the oracle to admit
# it. The byte-equality diff below still pins the exact oracle document,
# including its recorded `identity_verdicts`, so the round-2 evidence is
# reproducible and unchangeable; the failing verdict stays visible in
# `round2/round2.oracle.json` and is reported in `rounds/round23.md`.
set -euo pipefail

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

role="${1:?usage: round_reproducibility_test.sh ROLE}"
bin="$(rlocation _main/experiments/atlas-work-topology/round_topology_bin)"
rel="experiments/atlas-work-topology"
dir="$(dirname "$(rlocation _main/$rel/$role/$role.files.txt)")"
control="$(dirname "$(rlocation _main/$rel/control/control.files.txt)")"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

"$bin" "--jvm_flag=-Dattune.command=measure" \
       "--jvm_flag=-Dattune.role=$role" \
       "--jvm_flag=-Dattune.revision=$dir/$role.revision.txt" \
       "--jvm_flag=-Dattune.control_revision=$control/control.revision.txt" \
       "--jvm_flag=-Dattune.control_sources=$control/control.sources.parquet" \
       "--jvm_flag=-Dattune.control_facts=$control/control.facts.parquet" \
       "--jvm_flag=-Dattune.files=$dir/$role.files.txt" \
       "--jvm_flag=-Dattune.sources=$dir/$role.sources.txt" \
       "--jvm_flag=-Dattune.output_identity=$tmp/identity_map.json" \
       "--jvm_flag=-Dattune.output_topology=$tmp/topology.json" \
       "--jvm_flag=-Dattune.output_oracle=$tmp/oracle.json"

status=0
for document in identity_map topology oracle; do
    if cmp -s "$dir/$role.$document.json" "$tmp/$document.json"; then
        echo "OK   $role.$document.json re-derives byte-for-byte"
    else
        echo "FAIL $role.$document.json differs from the committed artifact"
        diff "$dir/$role.$document.json" "$tmp/$document.json" || true
        status=1
    fi
done

if [ "$status" -eq 0 ]; then
    echo "PASS: round $role documents re-derive exactly from the committed evidence"
else
    echo "FAIL: round $role measurement verification"
fi
exit "$status"
