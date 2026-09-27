#!/bin/bash
# The Flix LOC law (VAL-LOC-007).
#   nix develop --command bazel test //:flix_loc_law_test --config=buildbuddy-rbe
#
# Counts "code lines" of every tracked `src/` and `test/` Flix source: a line is
# a code line when, after stripping `/* */` block comments, it is not blank and
# not a pure `//` line. Fails if the combined total is not strictly below 4,800,
# or any single file exceeds 400 code lines, or `src/Repository.flix` grew past
# its refactor baseline of 339.
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

code_lines() {
    awk '
    BEGIN { incomment = 0; count = 0 }
    {
        line = $0
        if (incomment) {
            if (index(line, "*/") > 0) { line = substr(line, index(line, "*/") + 2); incomment = 0 }
            else next
        }
        while (index(line, "/*") > 0) {
            before = substr(line, 1, index(line, "/*") - 1)
            after = substr(line, index(line, "/*") + 2)
            if (index(after, "*/") > 0) { line = before substr(after, index(after, "*/") + 2) }
            else { line = before; incomment = 1; break }
        }
        gsub(/^[ \t]+/, "", line)
        gsub(/[ \t\r]+$/, "", line)
        if (line == "") next
        if (line ~ /^\/\//) next
        count++
    }
    END { print count + 0 }
    ' "$1"
}

manifest="$(rlocation _main/flix_loc_files.txt)"
total=0
violations=0
repository=0
while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    code="$(code_lines "$(rlocation "_main/$rel")")"
    printf '%6d  %s\n' "$code" "$rel"
    total=$((total + code))
    if [ "$code" -gt 400 ]; then
        echo "LOC: ${rel} has ${code} code lines (> 400)" >&2
        violations=$((violations + 1))
    fi
    case "$rel" in
        src/Repository.flix) repository="$code" ;;
    esac
done < <(sort "$manifest")

echo "flix_loc_law: total=${total} (limit 4800), src/Repository.flix=${repository} (baseline 339)"

if [ "$total" -ge 4800 ]; then
    echo "LOC: combined ${total} code lines is not below 4800" >&2
    violations=$((violations + 1))
fi
if [ "$repository" -gt 339 ]; then
    echo "LOC: src/Repository.flix grew to ${repository} code lines (baseline 339)" >&2
    violations=$((violations + 1))
fi
if [ "$violations" -gt 0 ]; then
    echo "LOC: ${violations} violation(s)" >&2
    exit 1
fi
echo "LOC: ok"
