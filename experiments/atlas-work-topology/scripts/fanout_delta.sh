#!/usr/bin/env bash
# fanout_delta.sh CONTROL_ROLE ROLE
#
# Derives the comparative Bazel locality table between the control role and a
# candidate role (PREREGISTRATION.md §7), keyed on the §9 logical identity
# layer: a control file is compared against the candidate file that carries its
# logical identity, so a pure move is a row with the same numbers at two paths.
#
# The table also carries the *cross-cell test invalidation*: for each basis file,
# the independently runnable test targets that depend on it and whose §5
# ownership cell differs from the file's own cell. That is the quantity
# cell-homing is supposed to move. Because the instrument's own research tests
# also live in the `//...` universe, every cross-cell column is reported twice:
# with every test target, and with `//experiments/...` targets excluded (the
# architecture-only reading).
#
# Inputs (all committed, all produced by measure_bazel_locality.sh):
#   <control>/<control>.fanout.txt        direct target fanout per control file
#   <candidate>/<candidate>.fanout.txt    direct target fanout per candidate file
#   <candidate>/<candidate>.identity_map.json  control path -> current path
#
# Output: <candidate>/<candidate>.fanout_delta.tsv
set -euo pipefail

control="${1:-control}"
role="${2:-round1}"
here="$(cd "$(dirname "$0")/.." && pwd)"

control_fanout="$here/$control/$control.fanout.txt"
role_fanout="$here/$role/$role.fanout.txt"
identity_map="$here/$role/$role.identity_map.json"
out="$here/$role/$role.fanout_delta.tsv"

for f in "$control_fanout" "$role_fanout" "$identity_map"; do
    if [ ! -f "$f" ]; then
        echo "FAIL: missing input: $f" >&2
        exit 1
    fi
done

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The §5 ownership cell per admitted path, from the identity map (§9).
jq -r '.entries[] | [.control_path, .control_cell] | @tsv' "$identity_map" \
    | LC_ALL=C sort -k1,1 > "$work/cells_control.tsv"
jq -r '.entries[] | select(.current_path != "") | [.current_path, .ownership_cell] | @tsv' "$identity_map" \
    | LC_ALL=C sort -k1,1 > "$work/cells_role.tsv"

# Flatten a fanout file into one row per admitted file:
#   path  declaring_actions  direct_dependents  test_invalidation  cross_cell  cross_cell_arch
flatten() {
    awk -v cells="$2" -v OFS="\t" '
        function cellOfLabel(label,   path, parts, dir) {
            path = label
            sub(/^\/\//, "", path)
            split(path, parts, ":")
            dir = parts[1]
            if (dir == "test/World") return "world"
            if (dir == "test/Engine") return "engine"
            if (dir == "test/Applications") return "applications"
            if (dir == "test/Kernel") return "kernel"
            if (dir == "test") return "law"
            if (dir ~ /^experiments\//) return "research"
            if (dir == "src/native/identity" || dir == "src/native/parquet") return "kernel"
            if (dir == "src/native/grit") return "world"
            if (dir == "src/native/inference") return "applications"
            return "other"
        }
        function flush() {
            if (file != "") print file, actions, dependents, tests, cross, crossArch
        }
        BEGIN {
            while ((getline line < cells) > 0) {
                split(line, pair, "\t")
                cell[pair[1]] = pair[2]
            }
            close(cells)
            file = ""; actions = 0; dependents = 0; tests = 0; cross = 0; crossArch = 0; inList = 0
        }
        /^== / { flush(); file = substr($0, 4); actions = 0; dependents = 0; tests = 0; cross = 0; crossArch = 0; inList = 0; next }
        /^declaring_actions: / { actions = $2; next }
        /^direct_dependents: / { dependents = $2; next }
        /^test_invalidation: / { tests = $2; next }
        /^[a-z_]+_targets:/ { inList = ($0 ~ /^test_invalidation_targets:/); next }
        inList && /^  \/\// {
            label = substr($0, 3)
            if (cellOfLabel(label) != cell[file]) {
                cross++
                if (label !~ /^\/\/experiments\//) crossArch++
            }
            next
        }
        END { flush() }
    ' "$1" | LC_ALL=C sort -k1,1
}

flatten "$control_fanout" "$work/cells_control.tsv" > "$work/control.tsv"
flatten "$role_fanout" "$work/cells_role.tsv" > "$work/role.tsv"

{
    echo "# $role.fanout_delta.tsv — comparative Bazel direct fanout, control vs $role (PREREGISTRATION.md §7, §9)"
    echo "# keyed on the logical identity layer: control_path -> current_path; identical numbers on a pure move"
    echo "# cross_cell: dependent test targets whose §5 cell differs from the file's cell"
    echo "# cross_cell_arch: the same, excluding the instrument's own //experiments/... test targets"
    echo "# columns: control_path current_path movement control_cell ownership_cell control_declaring control_dependents control_tests control_cross_cell control_cross_cell_arch role_declaring role_dependents role_tests role_cross_cell role_cross_cell_arch delta_tests delta_cross_cell delta_cross_cell_arch"
} > "$out"

jq -r '.entries[] | [.control_path, .current_path, .movement, .control_cell, .ownership_cell] | @tsv' "$identity_map" \
    | LC_ALL=C sort -k1,1 > "$work/mapping.tsv"

awk -F'\t' -v OFS='\t' '
    FILENAME == ARGV[1] { ctrl[$1] = $2 "\t" $3 "\t" $4 "\t" $5 "\t" $6; next }
    FILENAME == ARGV[2] { role[$1] = $2 "\t" $3 "\t" $4 "\t" $5 "\t" $6; next }
    {
        controlPath = $1; currentPath = $2; movement = $3; controlCell = $4; ownershipCell = $5
        c = (controlPath in ctrl) ? ctrl[controlPath] : "0\t0\t0\t0\t0"
        r = (currentPath in role) ? role[currentPath] : "0\t0\t0\t0\t0"
        split(c, ca, "\t"); split(r, ra, "\t")
        rows++
        deltaTests = ra[3] - ca[3]
        deltaCross = ra[4] - ca[4]
        deltaCrossArch = ra[5] - ca[5]
        ctrlTests += ca[3]; roleTests += ra[3]
        ctrlCross += ca[4]; roleCross += ra[4]
        ctrlCrossArch += ca[5]; roleCrossArch += ra[5]
        if (movement == "new") next
        if (deltaCrossArch < 0) crossReduced++
        else if (deltaCrossArch > 0) crossIncreased++
        else crossEqual++
        print controlPath, currentPath, movement, controlCell, ownershipCell, ca[1], ca[2], ca[3], ca[4], ca[5], ra[1], ra[2], ra[3], ra[4], ra[5], deltaTests, deltaCross, deltaCrossArch
    }
    END {
        printf "# rows=%d control_tests=%d role_tests=%d control_cross_cell=%d role_cross_cell=%d control_cross_cell_arch=%d role_cross_cell_arch=%d cross_cell_arch_reduced=%d increased=%d equal=%d\n", \
            rows, ctrlTests, roleTests, ctrlCross, roleCross, ctrlCrossArch, roleCrossArch, crossReduced, crossIncreased, crossEqual
    }
' "$work/control.tsv" "$work/role.tsv" "$work/mapping.tsv" >> "$out"

echo "FANOUT_DELTA role=$role out=$out rows=$(grep -c '[^#]' "$out")"
