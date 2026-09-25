#!/bin/bash
# attuneflix-self-admission-v1 fact extractor (PREREGISTRATION.md).
#
# Usage: extract_self_facts.sh OUT_DIR FILE.flix...
#
# Writes files.txt (one sorted tracked path per line), modules.txt (one
# "module<TAB>path" row per declared module), and uses.txt (one
# "source<TAB>target" row per dotted-token use edge, deduplicated and sorted).
# Deterministic over its arguments; nothing else is read.
set -eu
out="$1"; shift
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Files: the sorted tracked .flix paths.
for f in "$@"; do printf '%s\n' "$f"; done | LC_ALL=C sort > "$out/files.txt"

# Modules: the first line (in file order) whose trimmed text starts with
# "mod " or "pub mod "; the declared module is the maximal [A-Za-z0-9.]+
# token after the keyword.
for f in $(cat "$out/files.txt"); do
    awk 'done == 0 && $0 ~ /^[ \t]*(pub )?mod[ \t]/ {
        line = $0; sub(/^[ \t]*(pub )?mod[ \t]+/, "", line);
        if (match(line, /[A-Za-z0-9.]+/)) {
            print substr(line, RSTART, RLENGTH) "\t" FILENAME; done = 1
        }
    }' "$f"
done | LC_ALL=C sort > "$out/modules.txt"

# Use edges: tokens are maximal [A-Za-z0-9._] runs over code text (lines
# whose first non-whitespace characters are not //). Edge F -> G iff F != G,
# G declares module M, and a token T of F satisfies T == M or T starts with
# "M.".
awk '
FILENAME == ARGV[1] { if (NF == 2) { mod[$1] = $2 } ; next }
/^[ \t]*\/\// { next }
{
    line = $0
    while (match(line, /[A-Za-z0-9._]+/)) {
        token = substr(line, RSTART, RLENGTH)
        for (m in mod) {
            if (token == m || (index(token, m) == 1 &&
                substr(token, length(m) + 1, 1) == ".")) {
                if (mod[m] != FILENAME) print FILENAME "\t" mod[m]
            }
        }
        line = substr(line, RSTART + RLENGTH)
    }
}
' "$out/modules.txt" $(cat "$out/files.txt") | LC_ALL=C sort -u > "$out/uses.txt"
