#!/bin/bash
# Bootstrap baseline measurement for the Effectful Typed-Stage mission
# (PREREGISTRATION.md §4-§8; fulfills VAL-CTRL-002).
#
#   nix develop --command bazel run \
#       //experiments/effectful-stage-architecture:measure_baseline
#
# Writes `experiments/effectful-stage-architecture/baseline-metrics.json`: the
# frozen control measurements (k-way cut, mutable cross-stage edges, shared
# writable hotspots, kernel size tax, cross-stage Bazel test invalidation and
# the task critical-path fraction T_inf/T_1) at the control specimen
# 09e27244af9340aa616116a93ea02472e7521ba5.
#
# STATUS: bootstrap instrument. This is temporary `bazel run` plumbing, in the
# spirit of the repository's existing locality script. Every reported number is
# a pure function of the tracked source tree and the declared BUILD graph; the
# logic is scheduled to move into a deterministic Flix analysis target backed by
# Starlark wiring (PREREGISTRATION.md §13, mission milestone 4). Bash is used
# only because `bazel query` (the BUILD channel) is inherently a build-graph
# query, exactly as in `experiments/atlas-work-topology/scripts/`.
#
# Three independent channels, never conflated:
#   BASIS  static qualified-reference graph over tracked production `.flix`.
#   BUILD  read-only `bazel query` of the declared BUILD graph.
#   WORK   the frozen four-task benchmark bundle's conflict structure.
#
# Determinism: no network, no clock, no ambient input. `ATTUNE_SKIP_BUILD=1`
# skips the BUILD channel for environments without a Bazel server.
set -euo pipefail

root="${BUILD_WORKSPACE_DIRECTORY:-$(git -C "$(dirname "$0")" rev-parse --show-toplevel)}"
cd "$root"

# `bazel run` may spawn with a PATH that omits the Nix dev-shell tools; locate a
# `jq` explicitly so the target is self-contained.
if ! command -v jq >/dev/null 2>&1; then
    for jqbin in /usr/bin/jq /nix/store/*-jq-*/bin/jq; do
        if [ -x "$jqbin" ]; then PATH="$(dirname "$jqbin"):$PATH"; break; fi
    done
fi

out="${1:-experiments/effectful-stage-architecture/baseline-metrics.json}"
revision="$(git rev-parse HEAD)"

# ---------------------------------------------------------------------------
# §2 Admission: the frozen path table (attuneflix-admission-v1).
# ---------------------------------------------------------------------------
admission() {
    case "$1" in
        .attune/*) return 1 ;;
        *.flix|*.java|*.js|*.mjs|*.cjs|*.jsx|*.ts|*.mts|*.cts|*.tsx|*.bzl|*.bazel|*.star) return 0 ;;
        BUILD|BUILD.bazel|WORKSPACE|WORKSPACE.bazel|*/BUILD|*/BUILD.bazel|*/WORKSPACE|*/WORKSPACE.bazel) return 0 ;;
        *) return 1 ;;
    esac
}
mapfile -t admitted < <(git ls-files | while IFS= read -r f; do admission "$f" && echo "$f"; done | LC_ALL=C sort)
admitted_count="${#admitted[@]}"

# ---------------------------------------------------------------------------
# §4 Region partition (attuneflix-regions-v1): the frozen 10-region semantic
# partition, identical per-path rules to the established work-topology
# instrument. First matching rule wins; `other` is the reported residual.
# ---------------------------------------------------------------------------
region_of() {
    case "$1" in
        src/Repository.flix|src/Repository/*) echo repository ;;
        src/Radii.flix|src/Radii/*) echo radii ;;
        src/Atlas.flix|src/Atlas/*) echo atlas ;;
        src/Localization.flix|src/Localization/*) echo localization ;;
        src/ScientificTable.flix|src/ScientificTable/*) echo tables ;;
        src/Population.flix|src/Population/*) echo population ;;
        src/*) echo src-root ;;
        test/*) echo tests ;;
        build/src/*) echo build-src ;;
        experiments/*) echo experiments ;;
        *) echo other ;;
    esac
}

# ---------------------------------------------------------------------------
# §5 Stage partition (attuneflix-stages-v1): the six typed-stage ownership
# units plus the stable kernel. A stage is a writable unit of the pipeline; a
# region is a semantic subsystem. Reported separately, never conflated.
# ---------------------------------------------------------------------------
stage_of() {
    case "$1" in
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

# ---------------------------------------------------------------------------
# §4 BASIS graph. An edge f -> g exists when the module declared by g (its
# longest declared module path) appears as a qualified reference `<M>.` in f's
# text, restricted to tracked production `.flix` sources.
# ---------------------------------------------------------------------------
module_of() {
    grep -m1 -oE '^[[:space:]]*(pub[[:space:]]+)?mod[[:space:]]+[A-Za-z0-9_.]+' "$1" \
        | sed -E 's/^[[:space:]]*(pub[[:space:]]+)?mod[[:space:]]+//' || true
}
# Module table: production modules first (preferred for reference resolution),
# then law/instrument modules only for names not already declared. Every tracked
# `.flix` source participates in the BASIS graph; a law or instrument file that
# declares a production module name (e.g. `test/Repository.flix`) never shadows
# the production module.
declare -A modfile
for f in "${admitted[@]}"; do
    case "$f" in src/*.flix|src/*/*.flix|src/*/*/*.flix) ;; *) continue ;; esac
    m="$(module_of "$f")"
    [ -n "$m" ] && modfile["$m"]="$f"
done
for f in "${admitted[@]}"; do
    case "$f" in *.flix) ;; *) continue ;; esac
    case "$f" in src/*) continue ;; esac
    m="$(module_of "$f")"
    [ -n "$m" ] && [ -z "${modfile[$m]:-}" ] && modfile["$m"]="$f"
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
all_flix=(); prod_files=()
for f in "${admitted[@]}"; do
    case "$f" in *.flix) all_flix+=("$f") ;; *) continue ;; esac
    case "$f" in src/*.flix|src/*/*.flix|src/*/*/*.flix) prod_files+=("$f") ;; esac
done
declare -A edge_keys
for f in "${all_flix[@]}"; do
    self="$(module_of "$f")"
    while IFS= read -r chain; do
        [ -n "$chain" ] || continue
        tgt="$(resolve "$chain")"
        [ -n "$tgt" ] || continue
        [ "$tgt" = "$self" ] && continue
        tfile="${modfile[$tgt]}"
        [ "$tfile" = "$f" ] && continue
        edge_keys["$f|$tfile"]=1
    done < <(grep -oE '[A-Z][A-Za-z0-9]*(\.[A-Za-z0-9]+)+' "$f" | LC_ALL=C sort -u)
done
total_edges="${#edge_keys[@]}"
prod_count="${#prod_files[@]}"

# ---------------------------------------------------------------------------
# Generic greedy agglomerative k-way cut over a frozen partition `LABEL`
# (file -> group). Ties broken by the lexicographically smallest group pair;
# the merged group keeps the smaller name; stop at k groups.
# ---------------------------------------------------------------------------
kway_cut() {
    declare -A grpof
    local labels=() l
    for l in $(for f in "${CUT_FILES[@]}"; do echo "${LABEL[$f]}"; done | LC_ALL=C sort -u); do
        labels+=("$l"); grpof["$l"]="$l"
    done
    local groups="${#labels[@]}"
    # group-pair cross weights
    declare -A gw
    for k in "${!edge_keys[@]}"; do
        local a="${k%%|*}" b="${k##*|}"
        local la="${LABEL[$a]}" lb="${LABEL[$b]}"
        [ "$la" = "$lb" ] && continue
        local pair
        if [[ "$la" < "$lb" ]]; then pair="$la|$lb"; else pair="$lb|$la"; fi
        gw["$pair"]=$(( ${gw[$pair]:-0} + 1 ))
    done
    emit_cut() {
        local n=0
        for k in "${!edge_keys[@]}"; do
            [ "${grpof[${LABEL[${k%%|*}]}]}" != "${grpof[${LABEL[${k##*|}]}]}" ] && n=$((n+1))
        done
        echo "$n"
    }
    declare -A cut
    cut["$groups"]="$(emit_cut)"
    while [ "$groups" -gt 2 ]; do
        local best_key="" best_w=-1
        local live=() i j A B
        for l in "${labels[@]}"; do [ -n "${grpof[$l]:-}" ] && live+=("${grpof[$l]}"); done
        # unique live group names, sorted
        mapfile -t live < <(printf '%s\n' "${live[@]}" | LC_ALL=C sort -u)
        for (( i=0; i<${#live[@]}; i++ )); do
            for (( j=i+1; j<${#live[@]}; j++ )); do
                A="${live[$i]}"; B="${live[$j]}"; local w=0
                for p in "${!gw[@]}"; do
                    local ga="${grpof[${p%%|*}]}" gb="${grpof[${p##*|}]}"
                    if { [ "$ga" = "$A" ] && [ "$gb" = "$B" ]; } || { [ "$ga" = "$B" ] && [ "$gb" = "$A" ]; }; then
                        w=$(( w + gw[$p] ))
                    fi
                done
                local key="$A|$B"
                if [ "$w" -gt "$best_w" ] || { [ "$w" -eq "$best_w" ] && [ -z "$best_key" -o "$key" \< "$best_key" ]; }; then
                    best_w="$w"; best_key="$key"
                fi
            done
        done
        A="${best_key%%|*}"; B="${best_key##*|}"
        for l in "${labels[@]}"; do [ "${grpof[$l]:-}" = "$B" ] && grpof["$l"]="$A"; done
        groups=$((groups - 1))
        cut["$groups"]="$(emit_cut)"
    done
    for k in "${!cut[@]}"; do echo "$k ${cut[$k]}"; done | LC_ALL=C sort -n
}

# region k-way cut over the tracked `.flix` BASIS graph
declare -A LABEL
for f in "${all_flix[@]}"; do LABEL["$f"]="$(region_of "$f")"; done
CUT_FILES=("${all_flix[@]}")
declare -A region_cut
while read -r k c; do region_cut["$k"]="$c"; done < <(kway_cut)
region_groups="$(for f in "${all_flix[@]}"; do echo "${LABEL[$f]}"; done | LC_ALL=C sort -u | wc -l)"

# stage partition: cross-stage edges, hotspots, kernel tax (production surface)
declare -A STAGE
for f in "${prod_files[@]}"; do STAGE["$f"]="$(stage_of "$f")"; done
cross_edges=0
declare -A hotspot_importers
for k in "${!edge_keys[@]}"; do
    a="${k%%|*}"; b="${k##*|}"
    case "$a" in src/*) ;; *) continue ;; esac
    case "$b" in src/*) ;; *) continue ;; esac
    sa="${STAGE[$a]}"; sb="${STAGE[$b]}"
    [ "$sa" = "$sb" ] && continue
    cross_edges=$((cross_edges + 1))
    hotspot_importers["$b"]="${hotspot_importers[$b]:-} $sa"
done
hotspots=0; max_pressure=0
for g in "${!hotspot_importers[@]}"; do
    n="$(printf '%s\n' ${hotspot_importers[$g]} | sed '/^$/d' | LC_ALL=C sort -u | wc -l)"
    [ "$n" -ge 2 ] && hotspots=$((hotspots + 1))
    [ "$n" -gt "$max_pressure" ] && max_pressure="$n"
done
# region-level hotspots, reported for continuity with the prior instrument
declare -A rhot
for k in "${!edge_keys[@]}"; do
    a="${k%%|*}"; b="${k##*|}"; ra="$(region_of "$a")" rb="$(region_of "$b")"
    [ "$ra" = "$rb" ] && continue
    rhot["$b"]="${rhot[$b]:-} $ra"
done
region_hotspots=0; region_max_pressure=0
for g in "${!rhot[@]}"; do
    n="$(printf '%s\n' ${rhot[$g]} | sed '/^$/d' | LC_ALL=C sort -u | wc -l)"
    [ "$n" -ge 2 ] && region_hotspots=$((region_hotspots + 1))
    [ "$n" -gt "$region_max_pressure" ] && region_max_pressure="$n"
done
prod_loc=0; kernel_loc=0; kernel_files=0; kernel_fanin=0; prod_edges=0
for f in "${prod_files[@]}"; do
    l="$(wc -l < "$f")"; prod_loc=$((prod_loc + l))
    [ "${STAGE[$f]}" = kernel ] && { kernel_loc=$((kernel_loc + l)); kernel_files=$((kernel_files + 1)); }
done
for k in "${!edge_keys[@]}"; do
    case "${k%%|*}" in src/*) case "${k##*|}" in src/*) prod_edges=$((prod_edges + 1));; esac;; esac
    [ "${STAGE[${k##*|}]:-}" = kernel ] && kernel_fanin=$((kernel_fanin + 1))
done

# ---------------------------------------------------------------------------
# §8 WORK channel. Frozen four-task benchmark bundle pre-image; a file belongs
# to a task if it is in the task's reference closure from its declared seeds.
# The immutable set is the revision's declared Stable Kernel boundary
# (`src/Kernel/`), empty at control; the conflict graph and its chromatic
# number give T_inf, and T_1 is the unit task count.
# ---------------------------------------------------------------------------
declare -A adj
for k in "${!edge_keys[@]}"; do adj["${k%%|*}"]="${adj[${k%%|*}]:-} ${k##*|}"; done
closure() {
    local -A seen; local stack=("$@") node nxt
    while [ "${#stack[@]}" -gt 0 ]; do
        node="${stack[0]}"; stack=("${stack[@]:1}")
        [ -n "${seen[$node]:-}" ] && continue
        seen["$node"]=1
        for nxt in ${adj[$node]:-}; do stack+=("$nxt"); done
    done
    printf '%s\n' "${!seen[@]}" | LC_ALL=C sort
}
is_immutable() { case "$1" in src/Kernel/*|src/kernel/*) return 0 ;; *) return 1 ;; esac; }
declare -a task_names=(acquisition atlas_bitset judge_pareto projection_jsonld)
declare -A task_seed task_files
task_seed[acquisition]="src/Repository/Grit.flix src/Repository/Acquire.flix"
task_seed[atlas_bitset]="src/Repository/Physical.flix src/Radii/Evaluate.flix"
task_seed[judge_pareto]="src/Localization/Sandwich.flix src/Localization/PriorTable.flix"
task_seed[projection_jsonld]="src/Localization/PredictionTable.flix src/Population/Table.flix"
for t in "${task_names[@]}"; do
    keep=""
    while IFS= read -r x; do
        [ -n "$x" ] || continue
        is_immutable "$x" && continue
        keep="$keep $x"
    done <<< "$(closure ${task_seed[$t]})"
    task_files["$t"]="$keep"
done
declare -A conflict
for i in "${!task_names[@]}"; do
    for j in "${!task_names[@]}"; do
        [ "$j" -le "$i" ] && continue
        A="${task_names[$i]}"; B="${task_names[$j]}"; clash=0
        for x in ${task_files[$A]}; do
            case " ${task_files[$B]} " in *" $x "*) clash=1; break ;; esac
        done
        conflict["$A|$B"]="$clash"
    done
done
t_inf=0; n=${#task_names[@]}
for (( c=1; c<=n; c++ )); do
    total=$(( c ** n )); found=0
    for (( code=0; code<total; code++ )); do
        x=$code; declare -a col=()
        for (( i=0;i<n;i++ )); do col[$i]=$(( x % c )); x=$(( x / c )); done
        good=1
        for i in "${!task_names[@]}"; do
            for j in "${!task_names[@]}"; do
                [ "$j" -le "$i" ] && continue
                [ "${conflict[${task_names[$i]}|${task_names[$j]}]:-0}" = 1 ] || continue
                [ "${col[$i]}" = "${col[$j]}" ] && { good=0; break 2; }
            done
        done
        [ "$good" = 1 ] && { found=1; break; }
    done
    [ "$found" = 1 ] && { t_inf=$c; break; }
done
t_one="$n"

# ---------------------------------------------------------------------------
# §7 BUILD channel: cross-stage test invalidation via `bazel query`.
# ---------------------------------------------------------------------------
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
cross_invalidation=0; cross_invalidation_all=0; analyzed_targets=0; test_targets=0
if [ "${ATTUNE_SKIP_BUILD:-0}" != 1 ]; then
    analyzed_targets="$(bazel query //... --noshow_progress 2>/dev/null | wc -l)"
    test_targets="$(bazel query "kind(\".*_test\", //...)" --noshow_progress 2>/dev/null | wc -l)"
    for f in "${admitted[@]}"; do
        fs="$(stage_of "$f")"; name="$(basename "$f")"
        declaring="$(bazel query "attr(srcs, \"$name\", //...)" --noshow_progress 2>/dev/null | LC_ALL=C sort || true)"
        [ -n "$declaring" ] || continue
        labels="set($(printf '%s ' $declaring))"
        tests="$(bazel query "kind(\".*_test\", rdeps(//..., $labels))" --noshow_progress 2>/dev/null | LC_ALL=C sort || true)"
        while IFS= read -r t; do
            [ -n "$t" ] || continue
            [ "$(test_stage "$t")" = "$fs" ] && continue
            cross_invalidation_all=$((cross_invalidation_all + 1))
            case "$t" in //experiments/*) ;; *) cross_invalidation=$((cross_invalidation + 1)) ;; esac
        done <<< "$tests"
    done
fi

# ---------------------------------------------------------------------------
# Emit the machine-readable record.
# ---------------------------------------------------------------------------
frac() { [ "$2" -eq 0 ] && { echo 0; return; }; awk -v a="$1" -v b="$2" 'BEGIN{printf "%.6f", a/b}'; }
cuts_json="{}"
for k in $(printf '%s\n' "${!region_cut[@]}" | LC_ALL=C sort -n); do
    cuts_json="$(jq -c --arg k "$k" --argjson c "${region_cut[$k]}" --arg f "$(frac "${region_cut[$k]}" "$total_edges")" '. + {($k): {count: $c, fraction: ($f|tonumber)}}' <<< "$cuts_json")"
done
conflict_json="{}"
for k in "${!conflict[@]}"; do conflict_json="$(jq -c --arg k "$k" --argjson v "${conflict[$k]}" '. + {($k): ($v==1)}' <<< "$conflict_json")"; done
tasks_json="{}"
for t in "${task_names[@]}"; do
    nf="$(printf '%s\n' ${task_files[$t]} | sed '/^$/d' | wc -l)"
    tasks_json="$(jq -c --arg t "$t" --argjson n "$nf" --arg s "${task_seed[$t]}" '. + {($t): {file_count: $n, seed_files: ($s|split(" ")|map(select(length>0)))}}' <<< "$tasks_json")"
done

jq -n \
  --arg protocol "attuneflix-effectful-stage-baseline-v1" \
  --arg recorded_at_utc "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg control_commit "09e27244af9340aa616116a93ea02472e7521ba5" \
  --arg working_commit "$revision" \
  --arg admission_protocol "attuneflix-admission-v1" \
  --arg region_protocol "attuneflix-regions-v1" \
  --arg stage_protocol "attuneflix-stages-v1" \
  --argjson admitted_files "$admitted_count" \
  --argjson production_flix_files "$prod_count" \
  --argjson production_flix_loc "$prod_loc" \
  --argjson total_edges "$total_edges" \
  --argjson prod_edges "$prod_edges" \
  --argjson region_groups "$region_groups" \
  --argjson cuts "$cuts_json" \
  --argjson cross_stage_edges "$cross_edges" \
  --arg cross_stage_fraction "$(frac "$cross_edges" "$prod_edges")" \
  --argjson shared_hotspots "$hotspots" \
  --argjson max_hotspot_pressure "$max_pressure" \
  --argjson region_hotspots "$region_hotspots" \
  --argjson region_max_hotspot_pressure "$region_max_pressure" \
  --argjson kernel_files "$kernel_files" \
  --argjson kernel_loc "$kernel_loc" \
  --arg kernel_loc_fraction "$(frac "$kernel_loc" "$prod_loc")" \
  --argjson kernel_fanin "$kernel_fanin" \
  --arg kernel_fanin_share "$(frac "$kernel_fanin" "$total_edges")" \
  --argjson t_inf "$t_inf" \
  --argjson t_one "$t_one" \
  --arg t_fraction "$(frac "$t_inf" "$t_one")" \
  --argjson tasks "$tasks_json" \
  --argjson conflict "$conflict_json" \
  --argjson analyzed_targets "$analyzed_targets" \
  --argjson test_targets "$test_targets" \
  --argjson cross_invalidation "$cross_invalidation" \
  --argjson cross_invalidation_all "$cross_invalidation_all" \
  --arg build_skipped "${ATTUNE_SKIP_BUILD:-0}" \
  '{
     protocol: $protocol,
     recorded_at_utc: $recorded_at_utc,
     control_commit: $control_commit,
     working_commit: $working_commit,
     partitions: {
       admission: $admission_protocol,
       region: $region_protocol,
       stage: $stage_protocol
     },
     channels: {
       basis: {
         admitted_files: $admitted_files,
         production_flix_files: $production_flix_files,
         production_flix_loc: $production_flix_loc,
         total_reference_edges: $total_edges,
         production_reference_edges: $prod_edges,
         region_groups: $region_groups,
         k_way_cut: $cuts,
         mutable_cross_stage_edges: $cross_stage_edges,
         mutable_cross_stage_fraction: ($cross_stage_fraction|tonumber),
         shared_writable_hotspots: $shared_hotspots,
         max_hotspot_pressure: $max_hotspot_pressure,
         shared_region_hotspots: $region_hotspots,
         region_max_hotspot_pressure: $region_max_hotspot_pressure
       },
       kernel: {
         kernel_files: $kernel_files,
         kernel_loc: $kernel_loc,
         kernel_loc_fraction: ($kernel_loc_fraction|tonumber),
         kernel_fanin: $kernel_fanin,
         kernel_fanin_share: ($kernel_fanin_share|tonumber)
       },
       build: {
         skipped: ($build_skipped == "1"),
         analyzed_targets: $analyzed_targets,
         test_targets: $test_targets,
         cross_stage_test_invalidation: $cross_invalidation,
         cross_stage_test_invalidation_all_tests: $cross_invalidation_all
       },
       work: {
         tasks: $tasks,
         conflict_graph: $conflict,
         T_one: $t_one,
         T_inf: $t_inf,
         critical_path_fraction: ($t_fraction|tonumber)
       }
     }
   }' > "$out"

echo "wrote $out"
jq -c '{control: .control_commit,
        region_k_way_cut: [.channels.basis.k_way_cut | to_entries[] | {k: (.key|tonumber), f: .value.fraction}],
        cross_stage_edges: .channels.basis.mutable_cross_stage_edges,
        cross_stage_fraction: .channels.basis.mutable_cross_stage_fraction,
        hotspots: .channels.basis.shared_writable_hotspots,
        region_hotspots: .channels.basis.shared_region_hotspots,
        kernel_loc_fraction: .channels.kernel.kernel_loc_fraction,
        kernel_fanin_share: .channels.kernel.kernel_fanin_share,
        cross_invalidation: .channels.build.cross_stage_test_invalidation,
        T_inf_over_T_one: .channels.work.critical_path_fraction}' "$out"
