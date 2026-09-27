#!/bin/bash
# Per-file provenance extractor for the BUILD channel of the Effectful Typed-Stage
# instrument (PREREGISTRATION.md §4, VAL-PROV-003 / VAL-PROV-004).
#
#   extract <out.json>                        measure the tree this script lives in
#   analyze <control.json> <cand.json> <out>  join two extracts, rank causes
#
# `extract` reproduces the instrument-of-record's BUILD channel *exactly* —
# the same admission rule, the same §2.3 / §16 stage path functions, the same
# `test_stage` package map, and the same two `bazel query` forms per admitted
# file (`attr(srcs, "<basename>", //...)` then
# `kind(".*_test", rdeps(//..., set(<declaring>)))`) — and additionally records,
# for every admitted file, the concrete invalidated test targets and the
# declaring BUILD targets that carry the invalidation edge. Its aggregate
# counts must equal the instrument's recorded
# `channels.build.cross_stage_test_invalidation{,_all_tests,_dagref}`; any
# mismatch is a hard error.
#
# Every number is a pure function of the tracked tree and its declared BUILD
# graph. No network, no clock-derived metric, no ambient input.
#
# The instrument of record (`measure_baseline_metrics.sh`) is never modified and
# never re-run against a committed record by this script; it only reads.
#
#   ATTUNE_TREE_ROOT=<dir>   measure another checkout (e.g. a control worktree)
#                            from this script's location
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
root="${ATTUNE_TREE_ROOT:-$(git -C "$script_dir" rev-parse --show-toplevel)}"
cd "$root"

if ! command -v jq >/dev/null 2>&1; then
    for jqbin in /usr/bin/jq /nix/store/*-jq-*/bin/jq; do
        if [ -x "$jqbin" ]; then PATH="$(dirname "$jqbin"):$PATH"; break; fi
    done
fi

# ---------------------------------------------------------------------------
# PREREGISTRATION.md §2.1 admission (attuneflix-admission-v1), verbatim.
# ---------------------------------------------------------------------------
admission() {
    case "$1" in
        .attune/*) return 1 ;;
        *.flix|*.java|*.js|*.mjs|*.cjs|*.jsx|*.ts|*.mts|*.cts|*.tsx|*.bzl|*.bazel|*.star) return 0 ;;
        BUILD|BUILD.bazel|WORKSPACE|WORKSPACE.bazel|*/BUILD|*/BUILD.bazel|*/WORKSPACE|*/WORKSPACE.bazel) return 0 ;;
        *) return 1 ;;
    esac
}

# PREREGISTRATION.md §2.3 stage partition, verbatim (metric of record).
stage_of() {
    case "$1" in
        src/Kernel/*|src/kernel/*) echo kernel ;;
        src/ScientificIdentity.flix|src/ScientificTable.flix|src/ScientificTable/*|src/native/identity/*|src/native/parquet/*) echo kernel ;;
        src/Repository/Physical.flix) echo engine ;;
        src/Repository.flix|src/Repository/*|src/grit/*|src/native/grit/*) echo world ;;
        src/Radii.flix|src/Radii/*|src/Atlas.flix|src/Atlas/*) echo engine ;;
        src/Localization.flix|src/Localization/*|src/Population.flix|src/Population/*|src/native/inference/*) echo applications ;;
        src/Experiment.flix|experiments/*) echo research ;;
        test/World/*) echo world ;;
        test/Engine/*) echo engine ;;
        test/Applications/*) echo applications ;;
        test/Kernel/*) echo kernel ;;
        test/*|build/*|data/*|BUILD.bazel|MODULE.bazel) echo law ;;
        *) echo other ;;
    esac
}

# PREREGISTRATION.md §16 supplementary `_dagref` re-key, verbatim.
stage_of_dagref() {
    case "$1" in
        src/Kernel.flix|src/Kernel/*|src/kernel/*) echo kernel ;;
        src/ScientificIdentity.flix|src/Scientific.flix|src/Scientific/*|src/ScientificTable.flix|src/ScientificTable/*|src/native/identity/*|src/native/parquet/*) echo kernel ;;
        src/Repository/Physical.flix) echo engine ;;
        src/Repository.flix|src/Repository/*|src/grit/*|src/native/grit/*) echo world ;;
        src/World.flix|src/World/*) echo world ;;
        src/Radii.flix|src/Radii/*|src/Atlas.flix|src/Atlas/*) echo engine ;;
        src/Localization.flix|src/Localization/*|src/Population.flix|src/Population/*|src/native/inference/*) echo applications ;;
        src/Stage/Acquire.flix|src/Stage/World.flix) echo world ;;
        src/Stage/Prior.flix|src/Stage/Atlas.flix) echo engine ;;
        src/Stage/CandidateSet.flix|src/Stage/Judge.flix|src/Stage/Projection.flix|src/Stage/Pipeline.flix) echo applications ;;
        src/Experiment.flix|experiments/*) echo research ;;
        test/World/*) echo world ;;
        test/Engine/*) echo engine ;;
        test/Applications/*) echo applications ;;
        test/Kernel/*) echo kernel ;;
        test/*|build/*|data/*|BUILD.bazel|MODULE.bazel) echo law ;;
        *) echo other ;;
    esac
}

# PREREGISTRATION.md §4 test-stage map, verbatim.
test_stage() {
    case "$1" in
        //test/World:*) echo world ;; //test/Engine:*) echo engine ;;
        //test/Applications:*) echo applications ;; //test/Kernel:*) echo kernel ;;
        //experiments/*) echo research ;;
        //src/native/identity:*|//src/native/parquet:*) echo kernel ;;
        //src/native/grit:*) echo world ;; //src/native/inference:*) echo applications ;;
        *) echo other ;;
    esac
}

protocol="attuneflix-effectful-stage-invalidation-provenance-v1"

# ---------------------------------------------------------------------------
# extract
# ---------------------------------------------------------------------------
do_extract() {
    local out="${1:?usage: extract_invalidation_provenance.sh extract <out.json>}"
    local revision; revision="$(git rev-parse HEAD)"

    mapfile -t admitted < <(git ls-files | while IFS= read -r f; do admission "$f" && echo "$f"; done | LC_ALL=C sort)

    local analyzed_targets test_targets
    analyzed_targets="$(bazel query //... --noshow_progress 2>/dev/null | wc -l)"
    test_targets="$(bazel query 'kind(".*_test", //...)' --noshow_progress 2>/dev/null | wc -l)"

    local tmpd; tmpd="$(mktemp -d)"
    trap 'rm -rf "${tmpd:-}"' EXIT

    : > "$tmpd/files.jsonl"
    local f name declaring labels tests fs fdag t ts n
    n=0
    for f in "${admitted[@]}"; do
        name="$(basename "$f")"
        declaring="$(bazel query "attr(srcs, \"$name\", //...)" --noshow_progress 2>/dev/null | LC_ALL=C sort || true)"
        [ -n "$declaring" ] || continue
        labels="set($(printf '%s ' $declaring))"
        tests="$(bazel query "kind(\".*_test\", rdeps(//..., $labels))" --noshow_progress 2>/dev/null | LC_ALL=C sort || true)"
        [ -n "$tests" ] || continue
        fs="$(stage_of "$f")"; fdag="$(stage_of_dagref "$f")"
        printf '%s\n' "$declaring" > "$tmpd/declaring.txt"
        : > "$tmpd/tests.txt"
        while IFS= read -r t; do
            [ -n "$t" ] || continue
            ts="$(test_stage "$t")"
            printf '%s\t%s\n' "$t" "$ts" >> "$tmpd/tests.txt"
        done <<< "$tests"
        jq -n -c \
            --arg path "$f" --arg stage "$fs" --arg stage_dagref "$fdag" \
            --rawfile declaring "$tmpd/declaring.txt" \
            --rawfile tests "$tmpd/tests.txt" '
            ($tests | split("\n") | map(select(length > 0) | split("\t"))
                | map({label: .[0], stage: .[1]})
                | map(. + {
                    cross_all:    (.stage != $stage),
                    cross_frozen: ((.stage != $stage) and ((.label | startswith("//experiments/")) | not)),
                    cross_dagref: ((.stage != $stage_dagref) and ((.label | startswith("//experiments/")) | not))
                  })
                | map(select(.cross_all or .cross_dagref))
            ) as $tr
            | {
                path: $path, stage: $stage, stage_dagref: $stage_dagref,
                declaring_targets: ($declaring | split("\n") | map(select(length > 0))),
                frozen_count:    ([$tr[] | select(.cross_frozen)] | length),
                dagref_count:    ([$tr[] | select(.cross_dagref)] | length),
                all_tests_count: ([$tr[] | select(.cross_all)] | length),
                tests: $tr
              }' >> "$tmpd/files.jsonl"
        n=$((n + 1))
        printf '\r  %d/%d admitted files scanned' "$n" "${#admitted[@]}" >&2
    done
    printf '\n' >&2

    jq -s \
        --arg protocol "$protocol" \
        --arg recorded_at_utc "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg working_commit "$revision" \
        --arg tree_root "$root" \
        --argjson analyzed_targets "$analyzed_targets" \
        --argjson test_targets "$test_targets" \
        --argjson admitted_files "${#admitted[@]}" '
        {
          protocol: $protocol,
          recorded_at_utc: $recorded_at_utc,
          working_commit: $working_commit,
          tree_root: $tree_root,
          partitions: {
            admission: "attuneflix-admission-v1",
            stage: "attuneflix-stages-v1",
            stage_dagref: "attuneflix-stages-v1/dagref"
          },
          build: {
            skipped: false,
            analyzed_targets: $analyzed_targets,
            test_targets: $test_targets,
            admitted_files: $admitted_files,
            cross_stage_test_invalidation:          ([.[] | .tests[] | select(.cross_frozen)] | length),
            cross_stage_test_invalidation_all_tests:([.[] | .tests[] | select(.cross_all)] | length),
            cross_stage_test_invalidation_dagref:    ([.[] | .tests[] | select(.cross_dagref)] | length),
            contributing_files: ([.[] | select(.frozen_count > 0 or .dagref_count > 0)] | length),
            per_file: (map({key: .path, value: .}) | from_entries)
          }
        }' "$tmpd/files.jsonl" > "$out"

    echo "wrote $out"
    jq -c '{working_commit, analyzed_targets: .build.analyzed_targets,
            test_targets: .build.test_targets,
            cross_stage_test_invalidation: .build.cross_stage_test_invalidation,
            cross_stage_test_invalidation_all_tests: .build.cross_stage_test_invalidation_all_tests,
            cross_stage_test_invalidation_dagref: .build.cross_stage_test_invalidation_dagref,
            contributing_files: .build.contributing_files}' "$out"

    # Optional fidelity gate: assert the aggregate reproduces the recorded
    # instrument-of-record values for this tree.
    if [ -n "${ATTUNE_EXPECT_FROZEN:-}" ]; then
        local got_f got_a got_d
        got_f="$(jq '.build.cross_stage_test_invalidation' "$out")"
        got_a="$(jq '.build.cross_stage_test_invalidation_all_tests' "$out")"
        got_d="$(jq '.build.cross_stage_test_invalidation_dagref' "$out")"
        if [ "$got_f" != "$ATTUNE_EXPECT_FROZEN" ] || [ "$got_a" != "$ATTUNE_EXPECT_ALL" ] || [ "$got_d" != "$ATTUNE_EXPECT_DAGREF" ]; then
            echo "FIDELITY GATE FAILED: got frozen=$got_f all=$got_a dagref=$got_d" >&2
            echo "  expected frozen=$ATTUNE_EXPECT_FROZEN all=$ATTUNE_EXPECT_ALL dagref=$ATTUNE_EXPECT_DAGREF" >&2
            exit 1
        fi
        echo "fidelity gate OK: frozen=$got_f all=$got_a dagref=$got_d"
    fi
    rm -rf "$tmpd"
}

# ---------------------------------------------------------------------------
# analyze: join the control and candidate extracts, rank the causes of the
# 59 -> 253 (frozen) and 59 -> 173 (_dagref) increases, and emit the fan-out
# distribution and the top-1/3/5/10 cumulative shares for both keyings.
# ---------------------------------------------------------------------------
do_analyze() {
    local control="${1:?usage: ... analyze <control.json> <candidate.json> <out.json>}"
    local candidate="${2:?missing candidate extract}"
    local out="${3:?missing output path}"

    jq -n \
        --slurpfile c "$control" \
        --slurpfile d "$candidate" '
      def crosscount($rec; $flag): ([$rec.tests[]? | select(.[$flag])] | length);
      def labels($rec; $flag): [$rec.tests[]? | select(.[$flag]) | .label] | sort;

      # top-k cumulative share of an increase, over the ranked positive deltas
      def topk2($sorted; $key; $inc; $ks):
          [ $ks[] as $k
            | ($sorted | map(. + {d: .[$key]}) | map(select(.d > 0)) | .[0:$k]) as $top
            | {
                k: $k,
                paths: [$top[].path],
                per_path_delta: [$top[] | {path: .path, delta: .d}],
                cumulative_delta: (reduce $top[] as $x (0; . + $x.d)),
                share_of_increase: (if $inc == 0 then 0 else ((reduce $top[] as $x (0; . + $x.d)) / $inc) end),
                share_of_positive_delta:
                  (if ([$sorted[] | select(.[$key] > 0) | .[$key]] | add // 0) == 0 then 0
                   else ((reduce $top[] as $x (0; . + $x.d)) / ([$sorted[] | select(.[$key] > 0) | .[$key]] | add)) end)
              } ];

      # per-node fan-out distribution for a keying
      def fanout_distribution($rows; $ckey; $skey):
          ($rows | map(.[$ckey]) | map(select(. > 0))) as $counts
          | {
              nodes_with_invalidations: ($counts | length),
              total_invalidations: ($counts | add // 0),
              max_fanout: ($counts | max // 0),
              mean_fanout: (if ($counts | length) == 0 then 0 else (($counts | add) / ($counts | length)) end),
              histogram: ($counts | group_by(.) | map({fanout: .[0], nodes: length}) | sort_by(.fanout)),
              nodes: [$rows[] | select(.[$ckey] > 0)
                       | {path: .path, stage: .[$skey], fanout: .[$ckey]}]
                     | sort_by(-.fanout)
            };

      # how many ranked contributors are needed to reach a fraction of the increase
      def contributors_for($pos; $key; $frac; $inc):
        (reduce ($pos | sort_by(-.[$key]) | to_entries[]) as $e ({acc: 0, n: 0, done: false};
           if .done then . else
             (.acc + $e.value[$key]) as $a
             | {acc: $a, n: (.n + 1), done: ($a >= ($frac * $inc))}
           end) | .n);

      def negsum($rows; $key): (reduce ($rows[] | select(.[$key] < 0)) as $x (0; . + $x[$key]));

      # rows over the union of paths present in either tree
      ((($c[0].build.per_file | keys) + ($d[0].build.per_file | keys)) | unique) as $paths
      | [ $paths[] as $p
          | ($d[0].build.per_file[$p]) as $dr
          | ($c[0].build.per_file[$p]) as $cr
          | {
              path: $p,
              stage_frozen:     ($dr.stage // $cr.stage),
              stage_dagref:     ($dr.stage_dagref // $cr.stage_dagref),
              in_control:       ($cr != null),
              in_candidate:     ($dr != null),
              candidate_frozen: crosscount($dr; "cross_frozen"),
              control_frozen:   crosscount($cr; "cross_frozen"),
              candidate_dagref: crosscount($dr; "cross_dagref"),
              control_dagref:   crosscount($cr; "cross_dagref"),
              candidate_all:    crosscount($dr; "cross_all"),
              control_all:      crosscount($cr; "cross_all"),
              candidate_tests_frozen: labels($dr; "cross_frozen"),
              control_tests_frozen:   labels($cr; "cross_frozen"),
              candidate_tests_dagref: labels($dr; "cross_dagref"),
              control_tests_dagref:   labels($cr; "cross_dagref"),
              declaring_targets_candidate: ($dr.declaring_targets // []),
              declaring_targets_control:   ($cr.declaring_targets // [])
            }
          | . + { delta_frozen: (.candidate_frozen - .control_frozen),
                  delta_dagref: (.candidate_dagref - .control_dagref) }
        ] as $rows

      | ($rows | sort_by(-.delta_frozen)) as $by_delta_frozen
      | ($rows | sort_by(-.delta_dagref)) as $by_delta_dagref
      | ($rows | sort_by(-.candidate_frozen)) as $by_cand_frozen
      | ($rows | sort_by(-.candidate_dagref)) as $by_cand_dagref

      | ($c[0].build.cross_stage_test_invalidation)      as $ctlf
      | ($d[0].build.cross_stage_test_invalidation)      as $ctdf
      | ($c[0].build.cross_stage_test_invalidation_dagref) as $ctld
      | ($d[0].build.cross_stage_test_invalidation_dagref) as $ctdd
      | ($ctdf - $ctlf) as $incf
      | ($ctdd - $ctld) as $incd

      # hard consistency gate: the per-path deltas must reconstruct the recorded increase
      | (([$rows[].delta_frozen] | add) // 0) as $sumf
      | (([$rows[].delta_dagref] | add) // 0) as $sumd
      | if $sumf != $incf then error("frozen per-path delta sum \($sumf) != recorded increase \($incf)") else . end
      | if $sumd != $incd then error("dagref per-path delta sum \($sumd) != recorded increase \($incd)") else . end

      | {
        protocol: "attuneflix-effectful-stage-invalidation-provenance-v1",
        recorded_at_utc: (now | todateiso8601 | sub("\\.[0-9]+Z$"; "Z")),
        candidate_tree_working_commit: $d[0].working_commit,
        control_tree_working_commit: $c[0].working_commit,
        control_tree_root: $c[0].tree_root,
        candidate_tree_root: $d[0].tree_root,
        partitions: $d[0].partitions,
        totals: {
          control:  { frozen: $ctlf, dagref: $ctld },
          candidate:{ frozen: $ctdf, dagref: $ctdd },
          increase: { frozen: $incf, dagref: $incd }
        },
        consistency: {
          frozen_delta_sum_over_paths: $sumf,
          dagref_delta_sum_over_paths: $sumd,
          frozen_delta_sum_equals_increase: ($sumf == $incf),
          dagref_delta_sum_equals_increase: ($sumd == $incd)
        },
        keyings: {
          frozen: {
            control_total: $ctlf, candidate_total: $ctdf, increase: $incf,
            ranked_causes: [$by_delta_frozen[] | select(.delta_frozen != 0)],
            fanout: fanout_distribution($by_cand_frozen; "candidate_frozen"; "stage_frozen"),
            top_k_by_delta: topk2($by_delta_frozen; "delta_frozen"; $incf; [1,3,5,10]),
            top_k_by_candidate_fanout: topk2($by_cand_frozen; "candidate_frozen"; $incf; [1,3,5,10]),
            non_contributors: [$by_cand_frozen[] | select(.candidate_frozen == 0) | {path: .path, control_frozen: .control_frozen}],
            offsetting_contributors: [$by_delta_frozen[] | select(.delta_frozen < 0) | {path: .path, candidate_frozen: .candidate_frozen, control_frozen: .control_frozen, delta_frozen: .delta_frozen}],
            sum_positive_delta: (reduce ($by_delta_frozen[] | select(.delta_frozen > 0)) as $x (0; . + $x.delta_frozen)),
            sum_negative_delta: negsum($by_delta_frozen; "delta_frozen"),
            contributors_for_50pct: contributors_for($by_delta_frozen; "delta_frozen"; 0.5; $incf),
            contributors_for_80pct: contributors_for($by_delta_frozen; "delta_frozen"; 0.8; $incf),
            contributors_for_90pct: contributors_for($by_delta_frozen; "delta_frozen"; 0.9; $incf)
          },
          dagref: {
            control_total: $ctld, candidate_total: $ctdd, increase: $incd,
            ranked_causes: [$by_delta_dagref[] | select(.delta_dagref != 0)],
            fanout: fanout_distribution($by_cand_dagref; "candidate_dagref"; "stage_dagref"),
            top_k_by_delta: topk2($by_delta_dagref; "delta_dagref"; $incd; [1,3,5,10]),
            top_k_by_candidate_fanout: topk2($by_cand_dagref; "candidate_dagref"; $incd; [1,3,5,10]),
            non_contributors: [$by_cand_dagref[] | select(.candidate_dagref == 0) | {path: .path, control_dagref: .control_dagref}],
            offsetting_contributors: [$by_delta_dagref[] | select(.delta_dagref < 0) | {path: .path, candidate_dagref: .candidate_dagref, control_dagref: .control_dagref, delta_dagref: .delta_dagref}],
            sum_positive_delta: (reduce ($by_delta_dagref[] | select(.delta_dagref > 0)) as $x (0; . + $x.delta_dagref)),
            sum_negative_delta: negsum($by_delta_dagref; "delta_dagref"),
            contributors_for_50pct: contributors_for($by_delta_dagref; "delta_dagref"; 0.5; $incd),
            contributors_for_80pct: contributors_for($by_delta_dagref; "delta_dagref"; 0.8; $incd),
            contributors_for_90pct: contributors_for($by_delta_dagref; "delta_dagref"; 0.9; $incd)
          }
        },
        test_side_fanout: {
          candidate: ($d[0].build.per_file as $pf
            | { distinct_tests: ([($pf|to_entries[]) | .value.tests[]? | select(.cross_frozen) | .label] | unique | length),
                rows: ([($pf|to_entries[]) | .value.tests[]? | select(.cross_frozen) | {label, stage}]
                       | group_by(.label) | map({test: .[0].label, stage: .[0].stage, files: length})
                       | sort_by(-.files)) }),
          control: ($c[0].build.per_file as $pf
            | { distinct_tests: ([($pf|to_entries[]) | .value.tests[]? | select(.cross_frozen) | .label] | unique | length),
                rows: ([($pf|to_entries[]) | .value.tests[]? | select(.cross_frozen) | {label, stage}]
                       | group_by(.label) | map({test: .[0].label, stage: .[0].stage, files: length})
                       | sort_by(-.files)) }),
          candidate_test_targets: ($d[0].build.test_targets),
          control_test_targets: ($c[0].build.test_targets),
          note: "test-side fan-out = number of distinct upstream files whose stage differs from the test package stage"
        },
        verdict_rule: {
          hub_threshold_top3_share_of_increase: 0.5,
          hub_threshold_largest_single_share: 0.25,
          broad_threshold_contributors_for_80pct_at_least: 20,
          text: "verdict = hubs if (top3 share of increase >= 0.5) or (largest single share >= 0.25) or (contributors_for_80pct <= 5); broad if (top10 share < 0.5) and (contributors_for_80pct >= 20); else mixed"
        },
        method: {
          extract_command: "nix develop --command bash experiments/effectful-stage-architecture/scripts/extract_invalidation_provenance.sh extract <out.json>",
          analyze_command: "nix develop --command bash experiments/effectful-stage-architecture/scripts/extract_invalidation_provenance.sh analyze <control.json> <candidate.json> <out.json>",
          instrument_of_record: "experiments/effectful-stage-architecture/scripts/measure_baseline_metrics.sh (§4 BUILD channel; unmodified)",
          notes: [
            "extract reproduces the instrument-of-record BUILD channel exactly: same admission, §2.3 stage_of, §16 stage_of_dagref, test_stage, and the same two bazel query forms per admitted file.",
            "aggregate counts are asserted equal to the recorded instrument values before this analysis is quoted.",
            "per-file counts are (source file, test target) pairs: a file f contributes one unit per test target t with stage(t) != stage(f); the sum over files is the instrument metric.",
            "delta per path = candidate count - control count; the sum of deltas over the union of paths equals the recorded increase by construction.",
            "renamed paths (e.g. src/Repository.flix -> src/World/*) appear as a removal (negative delta) plus an addition (positive delta), never merged."
          ]
        }
      }' > "$out"

    echo "wrote $out"
}

# ---------------------------------------------------------------------------
# crosscheck: an independent second implementation of the same quantity.
#
# The extract above reproduces the instrument-of-record exactly, which asks the
# BUILD graph the *file-centric* question `rdeps(//..., set(declarers(basename)))`.
# This crosscheck asks the *test-centric* question `kind("source file", deps(t))`
# instead — one query per test target, no file names involved — and re-derives
# the per-path counts from the reverse direction. Two independent query
# directions that agree are stronger evidence than either alone; a divergence
# pinpoints where `attr(srcs, "<basename>", //...)` conflates same-basename files.
# ---------------------------------------------------------------------------
do_crosscheck() {
    local extract="${1:?usage: ... crosscheck <extract.json> <out.json>}"
    local out="${2:?missing output path}"
    local tmpd; tmpd="$(mktemp -d)"
    trap 'rm -rf "${tmpd:-}"' EXIT

    mapfile -t admitted < <(git ls-files | while IFS= read -r f; do admission "$f" && echo "$f"; done | LC_ALL=C sort)
    local -A ADM; local f
    for f in "${admitted[@]}"; do ADM["$f"]=1; done

    mapfile -t tests < <(bazel query 'kind(".*_test", //...)' --noshow_progress 2>/dev/null | LC_ALL=C sort)
    local -A EF ED EA
    local t ts exp lbl p fs fd
    for t in "${tests[@]}"; do
        ts="$(test_stage "$t")"
        case "$t" in //experiments/*) exp=1 ;; *) exp=0 ;; esac
        while IFS= read -r lbl; do
            [ -n "$lbl" ] || continue
            case "$lbl" in @*) continue ;; esac
            p="$(printf '%s' "$lbl" | sed -e 's|^//||' -e 's|:|/|')"
            [ -n "${ADM[$p]:-}" ] || continue
            fs="$(stage_of "$p")"; fd="$(stage_of_dagref "$p")"
            if [ "$ts" != "$fs" ]; then
                EA["$p"]=$(( ${EA[$p]:-0} + 1 ))
                if [ "$exp" = 0 ]; then EF["$p"]=$(( ${EF[$p]:-0} + 1 )); fi
            fi
            if [ "$ts" != "$fd" ] && [ "$exp" = 0 ]; then
                ED["$p"]=$(( ${ED[$p]:-0} + 1 ))
            fi
        done < <(bazel query "kind(\"source file\", deps($t))" --noshow_progress 2>/dev/null | LC_ALL=C sort)
    done

    { for p in "${!EF[@]}" "${!ED[@]}" "${!EA[@]}"; do echo "$p"; done; } | LC_ALL=C sort -u > "$tmpd/exact_paths"
    while IFS= read -r p; do
        printf '%s\t%s\t%s\t%s\n' "$p" "${EF[$p]:-0}" "${EA[$p]:-0}" "${ED[$p]:-0}"
    done < "$tmpd/exact_paths" > "$tmpd/exact.tsv"
    jq -r '.build.per_file | to_entries[] | "\(.key)\t\(.value.frozen_count)\t\(.value.all_tests_count)\t\(.value.dagref_count)"' "$extract" > "$tmpd/instr.tsv"

    jq -Rn '[inputs | split("\t") | {(.[0]): {frozen: (.[1]|tonumber), all: (.[2]|tonumber), dagref: (.[3]|tonumber)}}] | add // {}' "$tmpd/instr.tsv" > "$tmpd/instr.json"
    jq -Rn '[inputs | split("\t") | {(.[0]): {frozen: (.[1]|tonumber), all: (.[2]|tonumber), dagref: (.[3]|tonumber)}}] | add // {}' "$tmpd/exact.tsv" > "$tmpd/exact.json"

    jq -n \
        --arg protocol "attuneflix-effectful-stage-invalidation-crosscheck-v1" \
        --arg recorded_at_utc "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg working_commit "$(git rev-parse HEAD)" \
        --arg tree_root "$root" \
        --arg extract_path "$extract" \
        --slurpfile I "$tmpd/instr.json" \
        --slurpfile E "$tmpd/exact.json" '
      ($I[0] // {}) as $i | ($E[0] // {}) as $e
      | ((($i|keys) + ($e|keys)) | unique) as $ks
      | [ $ks[] as $k
          | { path: $k,
              instrument_frozen: ($i[$k].frozen // 0), exact_frozen: ($e[$k].frozen // 0),
              instrument_all:    ($i[$k].all    // 0), exact_all:    ($e[$k].all    // 0),
              instrument_dagref: ($i[$k].dagref // 0), exact_dagref: ($e[$k].dagref // 0) }
          | . + { delta_frozen: (.instrument_frozen - .exact_frozen),
                  delta_all:    (.instrument_all - .exact_all),
                  delta_dagref: (.instrument_dagref - .exact_dagref),
                  agrees: ((.instrument_frozen == .exact_frozen) and (.instrument_all == .exact_all) and (.instrument_dagref == .exact_dagref)) }
        ] as $rows
      | {
          protocol: $protocol, recorded_at_utc: $recorded_at_utc,
          working_commit: $working_commit, tree_root: $tree_root,
          extract_path: $extract_path,
          method: {
            command: "nix develop --command bash experiments/effectful-stage-architecture/scripts/extract_invalidation_provenance.sh crosscheck <extract.json> <out.json>",
            file_centric: "attr(srcs, <basename>, //...) then kind(\".*_test\", rdeps(//..., set(declaring)))  [the instrument of record, reproduced by `extract`]",
            test_centric: "kind(\"source file\", deps(<test>)) for every test target, counted in the reverse direction [this crosscheck]",
            note: "two independent query directions; agreement is cross-source confirmation, divergence locates the instrument same-basename conflation"
          },
          aggregate: {
            instrument: { frozen: ($i | [.[].frozen] | add // 0), all: ($i | [.[].all] | add // 0), dagref: ($i | [.[].dagref] | add // 0) },
            exact:      { frozen: ($e | [.[].frozen] | add // 0), all: ($e | [.[].all] | add // 0), dagref: ($e | [.[].dagref] | add // 0) }
          },
          per_path_totals: {
            paths_in_instrument_only: [($i|keys)[] | select($e[.] == null)],
            paths_in_exact_only:      [($e|keys)[] | select($i[.] == null)],
            agreeing_paths:   ([$rows[] | select(.agrees)] | length),
            disagreeing_paths:([$rows[] | select(.agrees | not)] | length)
          },
          disagreements: [$rows[] | select(.agrees | not) | select(.delta_frozen != 0 or .delta_all != 0 or .delta_dagref != 0)],
          per_path: $rows
        }' > "$out"

    echo "wrote $out"
    jq -c '{instrument_aggregate: .aggregate.instrument, exact_aggregate: .aggregate.exact,
            agreeing_paths: .per_path_totals.agreeing_paths,
            disagreeing_paths: .per_path_totals.disagreeing_paths}' "$out"
    rm -rf "$tmpd"
}

# ---------------------------------------------------------------------------
# basis: the instrument-of-record's BASIS static reference graph (§3), emitted
# per node and per edge. This is the third source of truth for provenance: it
# names the concrete typed reference (module -> module) behind a BUILD-level
# invalidation edge. Verbatim module-resolution logic from
# `measure_baseline_metrics.sh`; no formulas changed.
# ---------------------------------------------------------------------------
do_basis() {
    local out="${1:?usage: ... basis <out.json>}"
    local tmpd; tmpd="$(mktemp -d)"
    trap 'rm -rf "${tmpd:-}"' EXIT

    local revision; revision="$(git rev-parse HEAD)"
    mapfile -t admitted < <(git ls-files | while IFS= read -r f; do admission "$f" && echo "$f"; done | LC_ALL=C sort)

    local all_flix=() prod_files=() f m
    declare -A modfile
    for f in "${admitted[@]}"; do
        case "$f" in src/*.flix|src/*/*.flix|src/*/*/*.flix) ;; *) continue ;; esac
        m="$(grep -m1 -oE '^[[:space:]]*(pub[[:space:]]+)?mod[[:space:]]+[A-Za-z0-9_.]+' "$f" | sed -E 's/^[[:space:]]*(pub[[:space:]]+)?mod[[:space:]]+//' || true)"
        [ -n "$m" ] && modfile["$m"]="$f"
    done
    for f in "${admitted[@]}"; do
        case "$f" in *.flix) ;; *) continue ;; esac
        case "$f" in src/*) continue ;; esac
        m="$(grep -m1 -oE '^[[:space:]]*(pub[[:space:]]+)?mod[[:space:]]+[A-Za-z0-9_.]+' "$f" | sed -E 's/^[[:space:]]*(pub[[:space:]]+)?mod[[:space:]]+//' || true)"
        [ -n "$m" ] && [ -z "${modfile[$m]:-}" ] && modfile["$m"]="$f"
    done
    for f in "${admitted[@]}"; do
        case "$f" in *.flix) all_flix+=("$f") ;; *) continue ;; esac
        case "$f" in src/*.flix|src/*/*.flix|src/*/*/*.flix) prod_files+=("$f") ;; esac
    done

    resolve() {
        local acc="" best="" part
        local IFS='.'
        for part in $1; do
            if [ -z "$acc" ]; then acc="$part"; else acc="$acc.$part"; fi
            [ -n "${modfile[$acc]:-}" ] && best="$acc"
        done
        echo "$best"
    }

    : > "$tmpd/edges.tsv"
    local self chain tgt tfile
    for f in "${all_flix[@]}"; do
        self="$(grep -m1 -oE '^[[:space:]]*(pub[[:space:]]+)?mod[[:space:]]+[A-Za-z0-9_.]+' "$f" | sed -E 's/^[[:space:]]*(pub[[:space:]]+)?mod[[:space:]]+//' || true)"
        while IFS= read -r chain; do
            [ -n "$chain" ] || continue
            tgt="$(resolve "$chain")"
            [ -n "$tgt" ] || continue
            [ "$tgt" = "$self" ] && continue
            tfile="${modfile[$tgt]}"
            [ "$tfile" = "$f" ] && continue
            printf '%s\t%s\n' "$f" "$tfile"
        done < <(grep -oE '[A-Z][A-Za-z0-9]*(\.[A-Za-z0-9]+)+' "$f" | LC_ALL=C sort -u)
    done | LC_ALL=C sort -u > "$tmpd/edges.tsv"

    local nodes_json edges_json
    nodes_json="$(mktemp -p "$tmpd")"; edges_json="$(mktemp -p "$tmpd")"
    : > "$nodes_json"; : > "$edges_json"
    for f in "${all_flix[@]}"; do
        m="$(grep -m1 -oE '^[[:space:]]*(pub[[:space:]]+)?mod[[:space:]]+[A-Za-z0-9_.]+' "$f" | sed -E 's/^[[:space:]]*(pub[[:space:]]+)?mod[[:space:]]+//' || true)"
        jq -n -c --arg path "$f" --arg module "$m" --arg stage "$(stage_of "$f")" --arg stage_dagref "$(stage_of_dagref "$f")" \
           '{path: $path, module: $module, stage: $stage, stage_dagref: $stage_dagref}' >> "$nodes_json"
    done
    while IFS=$'\t' read -r a b; do
        [ -n "$a" ] || continue
        jq -n -c --arg from "$a" --arg to "$b" \
            --arg from_stage "$(stage_of "$a")" --arg to_stage "$(stage_of "$b")" \
            --arg from_stage_dagref "$(stage_of_dagref "$a")" --arg to_stage_dagref "$(stage_of_dagref "$b")" \
           '{from: $from, to: $to, from_stage: $from_stage, to_stage: $to_stage, from_stage_dagref: $from_stage_dagref, to_stage_dagref: $to_stage_dagref}' >> "$edges_json"
    done < "$tmpd/edges.tsv"

    jq -s \
        --arg protocol "attuneflix-effectful-stage-basis-graph-v1" \
        --arg recorded_at_utc "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg working_commit "$revision" \
        --arg tree_root "$root" '
        . as $edges
        | {
            protocol: $protocol, recorded_at_utc: $recorded_at_utc,
            working_commit: $working_commit, tree_root: $tree_root,
            total_reference_edges: ($edges | length),
            production_reference_edges: ([$edges[] | select(.from | startswith("src/")) | select(.to | startswith("src/"))] | length),
            edges: $edges
          }' "$edges_json" > "$tmpd/basis_with_edges.json"

    jq -s --slurpfile base "$tmpd/basis_with_edges.json" \
        '. as $nodes | $base[0] + {nodes: ($nodes | map({key: .path, value: .}) | from_entries)}' \
        "$nodes_json" > "$out"

    echo "wrote $out"
    jq -c '{working_commit, total_reference_edges, production_reference_edges, nodes: (.nodes | length)}' "$out"
    rm -rf "$tmpd"
}

mode="${1:-}"
case "$mode" in
    extract) shift; do_extract "$@" ;;
    analyze) shift; do_analyze "$@" ;;
    crosscheck) shift; do_crosscheck "$@" ;;
    basis) shift; do_basis "$@" ;;
    *) echo "usage: $0 extract <out.json> | analyze <control.json> <candidate.json> <out.json> | crosscheck <extract.json> <out.json> | basis <out.json>" >&2; exit 2 ;;
esac
