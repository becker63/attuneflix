#!/bin/bash
# The World locations table law (VAL-LOC-005).
#   nix develop --command bazel test //test/World:location_table_test --config=buildbuddy-rbe
#
# Asserts the declared schema and that writing the typed table and reading it
# back is exactly lossless, in Flix with the Arrow JVM flags.
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

"$(rlocation _main/test/World/location_law)" "--jvm_flag=-Dattune.command=roundtrip"
