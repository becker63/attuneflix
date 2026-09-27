#!/bin/bash
# The World location law (VAL-LOC-003, VAL-LOC-004).
#   nix develop --command bazel test //test/World:location_parity_test --config=buildbuddy-rbe
#
# Re-derives every parent edge from the exported locations and compares it with
# the stored `parent` relation of each of the 78 frozen worlds, in Flix. A
# mismatch, a non-dense id, or a file path that differs from its entity is a
# non-zero exit.
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

bin="$(rlocation _main/test/World/location_law)"
digests="$(rlocation _main/web/atlas-live/projection/expected_worlds.txt)"

first="$(head -n1 "$digests")"
worlds_file="$(rlocation "_main/web/atlas-live/projection/worlds/${first}/metadata.parquet")"
locations_file="$(rlocation "_main/web/atlas-live/projection/locations/${first}/locations.parquet")"
worlds="$(dirname "$(dirname "$worlds_file")")"
locations="$(dirname "$(dirname "$locations_file")")"

args=(
    "--jvm_flag=-Dattune.worlds_root=$worlds"
    "--jvm_flag=-Dattune.locations_root=$locations"
)
index=0
while IFS= read -r digest; do
    [ -n "$digest" ] || continue
    args+=("--jvm_flag=-Dattune.world.${index}=${digest}")
    index=$((index + 1))
done < "$digests"
args+=("--jvm_flag=-Dattune.world_count=${index}")

"$bin" "${args[@]}"
