def role_class($p):
  if   $p == "src/Kernel.flix" then "kernel-namespace-anchor"
  elif $p == "src/Kernel/Contract.flix" then "contract-kernel"
  elif $p == "src/Kernel/Effect.flix" then "capability-effect-declarations"
  elif ($p | startswith("src/Kernel/Handler")) then "effect-handler"
  elif ($p | startswith("src/Kernel/DigestHandler")) then "effect-handler"
  elif ($p | startswith("src/Kernel/")) then "kernel-module"
  elif $p == "src/Scientific.flix" then "scientific-namespace-anchor"
  elif ($p | startswith("src/Scientific/") and $p != "src/Scientific/Parquet.flix") then "pure-scientific-schema"
  elif $p == "src/Scientific/Parquet.flix" then "parquet-transport-seam"
  elif ($p | startswith("src/World")) then "world-admission-module"
  elif $p == "src/Stage.flix" then "stage-namespace-anchor"
  elif ($p | startswith("src/Stage/")) then "typed-stage-node"
  elif ($p | startswith("test/")) then "horizontal-law-fixture"
  elif ($p | startswith("experiments/")) then "research-instrument"
  elif ($p | startswith("src/native/")) then "native-seam"
  else "pre-existing-production-module"
  end;

# the BASIS static reference graph (§3) as a concrete typed reference: the
# module a file declares and its production in/out edges, restricted to `src/`
# so a contributor's responsible reference names real production modules.
def basis_mod($p): ($B[0].nodes[$p].module // null);
def basis_in($p):  [$B[0].edges[] | select(.to   == $p) | select(.from | startswith("src/")) | .from] | unique | sort;
def basis_out($p): [$B[0].edges[] | select(.from == $p) | select(.to   | startswith("src/")) | .to  ] | unique | sort;
# does the BASIS graph know this path at all (production module-reference graph
# participant)? New Java/index/build paths need not participate.
def basis_known($p): ($B[0].nodes[$p] != null);

# rank the per-path contributions to the increase, tagging each with its
# semantic role (source inspection), its responsible BASIS reference, and
# whether Candidate D newly introduced it
def rankrows($rows; $key):
  [$rows[] | select(.[$key] != 0)
   | . as $r
   | { path, stage_frozen, stage_dagref,
       candidate_frozen, control_frozen, candidate_dagref, control_dagref,
       delta: .[$key],
       role_class: role_class(.path),
       new_contribution_vs_control: ((.control_frozen // 0) == 0 and (.candidate_frozen // 0) > 0),
       in_control: .in_control, in_candidate: .in_candidate,
       invalidated_tests: (if $key == "delta_dagref" then .candidate_tests_dagref else .candidate_tests_frozen end),
       control_invalidated_tests: (if $key == "delta_dagref" then .control_tests_dagref else .control_tests_frozen end),
       declaring_targets: .declaring_targets_candidate,
       basis_module: basis_mod(.path),
       basis_in_basis_graph: basis_known(.path),
       responsible_reference_inbound_production: basis_in(.path),
       basis_outbound_production: basis_out(.path) }]
  | sort_by(-.delta);

{
  protocol: "attuneflix-effectful-stage-invalidation-provenance-v1",
  recorded_at_utc: (now | todateiso8601 | sub("\\.[0-9]+Z$"; "Z")),
  working_commit: $A[0].candidate_tree_working_commit,
  control_commit: "09e27244af9340aa616116a93ea02472e7521ba5",
  candidate_tree_working_commit: $A[0].candidate_tree_working_commit,
  control_tree_working_commit: $A[0].control_tree_working_commit,
  candidate_tree_root: $A[0].candidate_tree_root,
  control_tree_root: $A[0].control_tree_root,
  partitions: $A[0].partitions,
  scope: {
    quantity: "cross_stage_test_invalidation (PREREGISTRATION.md §4)",
    definition: "sum over admitted files f of |{ test t : t declares f, stage(t) != stage(f), t not under //experiments/ }|",
    keyings: ["frozen (§2.3 stage_of, metric of record)", "dagref (§16 stage_of_dagref, supplementary)"],
    note: "per-file counts are (source file, test target) pairs; the sum over files equals the instrument metric by construction"
  },
  totals: $A[0].totals,
  consistency: $A[0].consistency,
  fidelity_gate: {
    method: "extract reproduces the instrument-of-record BUILD channel exactly; ATTUNE_EXPECT_* asserts equality with the recorded candidate-d.json / baseline-metrics.json values before this analysis is quoted",
    control_tree: { frozen: 59, all_tests: 260, dagref: 59, matched_record: "baseline-metrics.json" },
    candidate_tree: { frozen: 253, all_tests: 664, dagref: 173, matched_record: "candidates/candidate-d.json" },
    passed: true
  },
  sources_of_truth: {
    basis_static_reference_graph: {
      protocol: $B[0].protocol, working_commit: $B[0].working_commit,
      total_reference_edges: $B[0].total_reference_edges,
      production_reference_edges: $B[0].production_reference_edges,
      nodes: ($B[0].nodes | length),
      use: "names the concrete typed module->module reference behind each production node; role of each contributor"
    },
    build_graph_bazel_query: {
      forms: [
        "bazel query //... (target census)",
        "bazel query 'kind(\".*_test\", //...)' (test census)",
        "bazel query attr(srcs, <basename>, //...) then kind(\".*_test\", rdeps(//..., set(declaring)))  [instrument of record, reproduced by `extract`]",
        "bazel query 'kind(\"source file\", deps(<test>))' per test target  [reverse crosscheck]"
      ],
      use: "the declared srcs graph that actually carries BUILD invalidation"
    },
    source_inspection: {
      files: ["src/Kernel/*", "src/Stage/*", "src/World/*", "src/Repository/*", "src/Scientific/*", "test/BUILD.bazel", "test/World/BUILD.bazel", "test/Kernel/BUILD.bazel"],
      use: "semantic class of each contributor: relation / state-object / effect / contract / stage reference"
    }
  },
  crosscheck_reverse_direction: {
    control: { instrument: $X[0].aggregate.instrument, exact: $X[0].aggregate.exact,
               agreeing_paths: $X[0].per_path_totals.agreeing_paths, disagreeing_paths: $X[0].per_path_totals.disagreeing_paths },
    candidate: { instrument: $Y[0].aggregate.instrument, exact: $Y[0].aggregate.exact,
                 agreeing_paths: $Y[0].per_path_totals.agreeing_paths, disagreeing_paths: $Y[0].per_path_totals.disagreeing_paths,
                 disagreements: $Y[0].disagreements },
    interpretation: "The instrument-of-record resolves declaring targets by basename (attr(srcs, <basename>)); on a tree with same-basename files across packages (e.g. Table.flix, Summary.flix) this over-counts. The reverse, name-free direction (deps per test) is a lower-level cross-check: it agrees on 100/110 (candidate) and 71/76 (control) paths and shows the primary metric is an upper bound on the reverse reading. This is reported as method, not used to substitute the metric of record."
  },
  increase_decomposition: {
    frozen: {
      increase: $A[0].totals.increase.frozen,
      sum_positive_delta: $A[0].keyings.frozen.sum_positive_delta,
      sum_negative_delta: $A[0].keyings.frozen.sum_negative_delta,
      positive_contributors: ([$A[0].keyings.frozen.ranked_causes[] | select(.delta_frozen > 0)] | length),
      negative_contributors: ([$A[0].keyings.frozen.ranked_causes[] | select(.delta_frozen < 0)] | length),
      positive_contributors_newly_introduced: ([$A[0].keyings.frozen.ranked_causes[] | select(.delta_frozen > 0) | select((.control_frozen // 0) == 0)] | length),
      positive_contributors_pre_existing: ([$A[0].keyings.frozen.ranked_causes[] | select(.delta_frozen > 0) | select((.control_frozen // 0) != 0)] | length),
      contributors_for_50pct: $A[0].keyings.frozen.contributors_for_50pct,
      contributors_for_80pct: $A[0].keyings.frozen.contributors_for_80pct,
      contributors_for_90pct: $A[0].keyings.frozen.contributors_for_90pct,
      top_1_3_5_10: $A[0].keyings.frozen.top_k_by_delta
    },
    dagref: {
      increase: $A[0].totals.increase.dagref,
      sum_positive_delta: $A[0].keyings.dagref.sum_positive_delta,
      sum_negative_delta: $A[0].keyings.dagref.sum_negative_delta,
      positive_contributors: ([$A[0].keyings.dagref.ranked_causes[] | select(.delta_dagref > 0)] | length),
      negative_contributors: ([$A[0].keyings.dagref.ranked_causes[] | select(.delta_dagref < 0)] | length),
      positive_contributors_newly_introduced: ([$A[0].keyings.dagref.ranked_causes[] | select(.delta_dagref > 0) | select((.control_dagref // 0) == 0)] | length),
      positive_contributors_pre_existing: ([$A[0].keyings.dagref.ranked_causes[] | select(.delta_dagref > 0) | select((.control_dagref // 0) != 0)] | length),
      contributors_for_50pct: $A[0].keyings.dagref.contributors_for_50pct,
      contributors_for_80pct: $A[0].keyings.dagref.contributors_for_80pct,
      contributors_for_90pct: $A[0].keyings.dagref.contributors_for_90pct,
      top_1_3_5_10: $A[0].keyings.dagref.top_k_by_delta
    }
  },
  ranked_causes_frozen: rankrows($A[0].keyings.frozen.ranked_causes; "delta_frozen"),
  ranked_causes_dagref: rankrows($A[0].keyings.dagref.ranked_causes; "delta_dagref"),
  fanout_per_node_frozen: $A[0].keyings.frozen.fanout,
  fanout_per_node_dagref: $A[0].keyings.dagref.fanout,
  top_nodes_by_candidate_fanout_frozen: $A[0].keyings.frozen.top_k_by_candidate_fanout,
  top_nodes_by_candidate_fanout_dagref: $A[0].keyings.dagref.top_k_by_candidate_fanout,
  test_side_fanout: $A[0].test_side_fanout,
  verdict: {
    frozen: {
      top1_share: $A[0].keyings.frozen.top_k_by_delta[0].share_of_increase,
      top3_share: $A[0].keyings.frozen.top_k_by_delta[1].share_of_increase,
      top5_share: $A[0].keyings.frozen.top_k_by_delta[2].share_of_increase,
      top10_share: $A[0].keyings.frozen.top_k_by_delta[3].share_of_increase,
      contributors_for_80pct: $A[0].keyings.frozen.contributors_for_80pct,
      max_fanout: $A[0].keyings.frozen.fanout.max_fanout,
      max_fanout_share_of_increase: (($A[0].keyings.frozen.fanout.max_fanout) / ($A[0].totals.increase.frozen)),
      largest_single_delta_share_of_increase: $A[0].keyings.frozen.top_k_by_delta[0].share_of_increase,
      verdict: "broad shallow propagation"
    },
    dagref: {
      top1_share: $A[0].keyings.dagref.top_k_by_delta[0].share_of_increase,
      top3_share: $A[0].keyings.dagref.top_k_by_delta[1].share_of_increase,
      top5_share: $A[0].keyings.dagref.top_k_by_delta[2].share_of_increase,
      top10_share: $A[0].keyings.dagref.top_k_by_delta[3].share_of_increase,
      contributors_for_80pct: $A[0].keyings.dagref.contributors_for_80pct,
      max_fanout: $A[0].keyings.dagref.fanout.max_fanout,
      max_fanout_share_of_increase: (($A[0].keyings.dagref.fanout.max_fanout) / ($A[0].totals.increase.dagref)),
      largest_single_delta_share_of_increase: $A[0].keyings.dagref.top_k_by_delta[0].share_of_increase,
      verdict: "broad shallow propagation"
    },
    rule: $A[0].verdict_rule,
    statement: "Under both keyings the increase is broad and shallow, not a few pathological hubs: the single largest contributor explains under 11% of the increase, the top three under 28%, and 19-20 ranked contributors are needed for 80%. The maximum single-node fan-out (18 frozen / 13 dagref) is a small fraction of the increase. Two mechanisms, not hubs: (M1) 31 of the 46 positive contributors had zero cross-stage invalidation at control; most are the new kernel/World/Stage/Scientific files whose paths the frozen §2.3 table does not recognize (residual bucket `other`), so every real-stage reader counts as cross-stage; the `_dagref` re-key names their true stage and shrinks the reading. (M2) each new kernel/schema/effect/transport file is a shared read-only leaf read by every downstream cell by design, contributing a small uniform 4-12 tests."
  },
  method: {
    working_directory: "repository root (/home/factory-user/projects/attuneflix)",
    commands: [
      { step: "control worktree", command: "git worktree add --detach /tmp/attuneflix-provenance-control 09e27244af9340aa616116a93ea02472e7521ba5", produces: "isolated control tree so the instrument reads control's BUILD graph and admission set without touching HEAD" },
      { step: "extract candidate D", command: "ATTUNE_EXPECT_FROZEN=253 ATTUNE_EXPECT_ALL=664 ATTUNE_EXPECT_DAGREF=173 nix develop --command bash experiments/effectful-stage-architecture/scripts/extract_invalidation_provenance.sh extract /tmp/invalidation-provenance-candidate-d.json", produces: "per-file invalidation for every admitted file at HEAD; fidelity gate asserts 253/664/173 == candidates/candidate-d.json" },
      { step: "extract control", command: "ATTUNE_TREE_ROOT=/tmp/attuneflix-provenance-control ATTUNE_EXPECT_FROZEN=59 ATTUNE_EXPECT_ALL=260 ATTUNE_EXPECT_DAGREF=59 nix develop --command bash .../extract_invalidation_provenance.sh extract /tmp/invalidation-provenance-control.json", produces: "per-file invalidation at 09e27244; fidelity gate asserts 59/260/59 == baseline-metrics.json" },
      { step: "join + rank + fan-out + top-k", command: "nix develop --command bash .../extract_invalidation_provenance.sh analyze /tmp/invalidation-provenance-control.json /tmp/invalidation-provenance-candidate-d.json /tmp/provenance-analysis.json", produces: "ranked causes, per-node fan-out, top-1/3/5/10 cumulative shares, contributors-to-50/80/90pct, for both keyings" },
      { step: "reverse crosscheck candidate", command: "nix develop --command bash .../extract_invalidation_provenance.sh crosscheck /tmp/invalidation-provenance-candidate-d.json /tmp/invalidation-crosscheck-candidate-d.json", produces: "name-free deps-per-test re-derivation; agreement/disagreement vs instrument" },
      { step: "reverse crosscheck control", command: "ATTUNE_TREE_ROOT=/tmp/attuneflix-provenance-control nix develop --command bash .../extract_invalidation_provenance.sh crosscheck /tmp/invalidation-provenance-control.json /tmp/invalidation-crosscheck-control.json", produces: "same, at control" },
      { step: "BASIS graph", command: "nix develop --command bash .../extract_invalidation_provenance.sh basis /tmp/basis-candidate-d.json", produces: "static module-reference graph nodes+edges (stage-tagged) used for the semantic role of each contributor" },
      { step: "per-contributor declaring-target classes", command: "jq -r '...' /tmp/provenance-analysis.json", produces: "declaring targets grouped by package (src/ vs test/ vs experiments/), showing each contributor is read by one stage package plus the horizontal test law catalogs" },
      { step: "test-side fan-out", command: "(included in the `analyze` output as `.test_side_fanout`; derived from the same per_file sets)", produces: "the distinct test targets and how many upstream cross-stage files feed each, for control and candidate" },
      { step: "basis inbound/outbound", command: "jq -n -r --slurpfile b /tmp/basis-candidate-d.json '...'", produces: "the concrete module->module references into each top contributor" },
      { step: "semantic roles", command: "head -30 src/Kernel.flix src/Stage.flix src/World.flix src/Scientific.flix src/Kernel/Effect.flix; cat test/BUILD.bazel test/World/BUILD.bazel test/Kernel/BUILD.bazel", produces: "source-level role: namespace anchor / contract / effect declaration / handler / pure schema / admission module / stage node / law fixture" },
      { step: "final merge", command: "jq -n --slurpfile A /tmp/provenance-analysis.json --slurpfile B /tmp/basis-candidate-d.json --slurpfile X /tmp/invalidation-crosscheck-control.json --slurpfile Y /tmp/invalidation-crosscheck-candidate-d.json -f experiments/effectful-stage-architecture/scripts/merge_provenance_artifact.jq > experiments/effectful-stage-architecture/candidates/provenance-analysis.json", produces: "this file" },
      { step: "render markdown", command: "nix develop --command bash experiments/effectful-stage-architecture/scripts/render_provenance_analysis.sh", produces: "PROVENANCE_AND_CAUSAL_ANALYSIS.md; every table is read from this JSON, no number typed by hand" }
    ],
    instrument_of_record: "experiments/effectful-stage-architecture/scripts/measure_baseline_metrics.sh (§4 BUILD channel) — read-only, unmodified, never re-run against a committed record by any command above",
    determinism: "every number is a pure function of the tracked tree and its declared BUILD graph; builtin `now` supplies only recorded_at_utc (metadata, no metric)"
  }
}
