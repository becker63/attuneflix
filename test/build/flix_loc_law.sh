#!/bin/sh
# Flix LOC law: the tracked handwritten Flix sources under `src/` and `test/`
# must stay within the declared code-line ceiling, and no single file may
# exceed the per-file ceiling.
#
# LOC here means CODE lines. A line counts when, after stripping block
# comments, it has content that is not itself a line comment (`//`, `///`).
# Blank lines and pure comment lines are documentation, not code, so they do
# not count. This keeps the ceiling a measure of the system's code, not of how
# much it explains itself.
#
# Invoked by the `flix_loc_law` Bazel test rule with the workspace-relative
# paths of every tracked `src/**/*.flix` and `test/**/*.flix` file.
set -eu

max_total="${ATTUNE_FLIX_LOC_MAX_TOTAL:-4800}"
max_file="${ATTUNE_FLIX_LOC_MAX_FILE:-400}"

code_lines() {
    awk '
        BEGIN { inblock = 0 }
        {
            line = $0
            out = ""
            i = 1
            n = length(line)
            while (i <= n) {
                two = substr(line, i, 2)
                if (inblock) {
                    if (two == "*/") { inblock = 0; i += 2 } else { i += 1 }
                } else if (two == "/*") {
                    inblock = 1; i += 2
                } else {
                    out = out substr(line, i, 1); i += 1
                }
            }
            sub(/^[ \t]+/, "", out)
            if (out == "") next
            if (substr(out, 1, 2) == "//") next
            code += 1
        }
        END { print code + 0 }
    ' "$1"
}

total=0
files=0
status=0
worst=""
worst_code=0
for file in "$@"; do
    [ -n "$file" ] || continue
    files=$((files + 1))
    code="$(code_lines "$file")"
    total=$((total + code))
    if [ "$code" -gt "$worst_code" ]; then worst="$file"; worst_code="$code"; fi
    if [ "$code" -gt "$max_file" ]; then
        echo "FLIX LOC LAW: ${file} has ${code} code lines (per-file ceiling ${max_file})" >&2
        status=1
    fi
done

if [ "$total" -ge "$max_total" ]; then
    echo "FLIX LOC LAW: ${total} total code lines (ceiling < ${max_total})" >&2
    status=1
fi

if [ "$status" -ne 0 ]; then
    echo "FLIX LOC LAW FAILED: ${total} code lines across ${files} files" >&2
    exit 1
fi

echo "FLIX LOC LAW OK: ${total} code lines across ${files} files (ceiling < ${max_total}, per-file <= ${max_file}); largest ${worst} (${worst_code})"
