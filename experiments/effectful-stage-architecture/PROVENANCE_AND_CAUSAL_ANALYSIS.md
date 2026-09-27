# Invalidation Provenance & Fan-Out Analysis — Candidate D vs control (M5, Phase 1)

Protocol: `attuneflix-effectful-stage-invalidation-provenance-v1`.
Machine-readable companion: `candidates/provenance-analysis.json` (carries
every number below, the per-file invalidated test targets, the declaring
BUILD targets, and the `method.commands` that produced each number).
Instrument of record: `scripts/measure_baseline_metrics.sh` §4 BUILD channel,
read-only and unmodified.

## 1. The question and the answer

**Question.** The frozen failure record is `cross_stage_test_invalidation`
59 (control) → 253 (Candidate D), and 59 → 173 under the supplementary `_dagref`
keying. Which source files produce the *increase*, what concrete typed
reference is responsible, and is the increase broad shallow propagation or a
few pathological hubs?

**Answer (recorded verdict).** **Broad shallow propagation, not hubs.** Under
both keyings the single largest contributor explains **under 11%** of the
increase, the top three under **28%**, and **19–20** distinct ranked
contributors are needed to reach 80%. The maximum per-node fan-out (18 frozen /
13 dagref) is itself a small share of the increase. The increase is the sum of
many new small kernel-reader invalidation sets (M1/M2 below), not a hub.

This feature (VAL-PROV-003, VAL-PROV-004) constructs the ranked provenance and
the fan-out/verdict. The hotspot enumeration (VAL-PROV-005), the edge taxonomy
(VAL-PROV-006) and the metric-soundness review (VAL-PROV-007) are the sibling
feature `p1-hotspot-provenance-edge-classification-metric-review`.

## 2. Scope: the quantity and its two keyings

The measured quantity is `cross_stage_test_invalidation` (PREREGISTRATION.md §4):

> `Σ_f |{ test t : t declares f in its srcs, stage(t) ≠ stage(f), and t is not under //experiments/ }|`

A per-file count is therefore a set of `(source file, test target)` pairs; the
instrument metric is the sum over the admitted file set. Two keyings exist and
are reported side by side, never substituted:

- **frozen §2.3 `stage_of`** — the metric of record, the one the §9.4
  thresholds and the §12 outcome use;
- **§16 `stage_of_dagref`** — the supplementary re-key that names the paths the
  mission's stage DAG actually owns (`src/Kernel.flix`, `src/Scientific/*`,
  `src/World/*`, `src/Stage/*`), which the frozen §2.3 table classifies as the
  residual bucket `other`.

| keying | control | candidate D | increase |
|---|---|---|---|
| frozen §2.3 (metric of record) | 59 | 253 | **+194** |
| supplementary §16 `_dagref` | 59 | 173 | **+114** |

## 3. Three sources of truth, cross-checked

| source | what it is | command |
|---|---|---|
| BUILD graph | the declared `srcs` graph that carries the invalidation | `bazel query attr(srcs, <basename>, //...)` then `kind(".*_test", rdeps(//..., set(<declaring>)))` |
| BUILD graph (reverse) | the same quantity re-derived with no file names: `kind("source file", deps(<test>))` per test | `... crosscheck ...` mode of the extractor |
| BASIS static graph | the tracked `.flix` module-reference graph (§3), naming the typed reference behind each node | `... basis <out.json>` mode of the extractor |
| source inspection | the semantic role of each contributor | `src/Kernel/*`, `src/Stage/*`, `src/World/*`, `src/Repository/*`, `src/Scientific/*`, `test/BUILD.bazel`, `test/World/BUILD.bazel`, `test/Kernel/BUILD.bazel` |

### Fidelity gate (the extractor reproduces the instrument exactly)

The per-file extractor re-implements the instrument-of-record's BUILD channel
(same admission, same §2.3/§16 stage functions, same `test_stage` package map,
same two `bazel query` forms) and asserts its aggregate equals the committed
record before any number is quoted:

| tree | frozen | all-tests | dagref | matches committed record |
|---|---|---|---|---|
| control `09e27244` | 59 | 260 | 59 | `baseline-metrics.json` |
| Candidate D `37ceaa5a` (= HEAD `eaff6b1` working tree) | 253 | 664 | 173 | `candidates/candidate-d.json` |

`consistency` in the JSON proves the decomposition is complete: the sum of
per-path deltas over the union of paths equals the recorded increase exactly
(194 frozen, 114 dagref — 0 residual).

## 4. Ranked causes — frozen §2.3 keying (metric of record)

Columns: rank, source file, frozen stage, semantic role, Δ (candidate −
control), candidate count, control count, number of cross-stage test targets
invalidated. Full rows (49 non-zero deltas) are below; the specific test-target
set per row is in the JSON and in Appendix A.

| # | file | stage | role | Δ | D | ctrl | tests invalidated |
|---|---|---|---|---|---|---|---|
| 1 | `src/Kernel.flix` | other | kernel-namespace-anchor | 18 | 18 | 0 | 18 |
| 2 | `src/Kernel/Contract.flix` | kernel | contract-kernel | 12 | 12 | 0 | 12 |
| 3 | `src/Scientific.flix` | other | scientific-namespace-anchor | 9 | 9 | 0 | 9 |
| 4 | `src/Scientific/Row.flix` | other | pure-scientific-schema | 9 | 9 | 0 | 9 |
| 5 | `src/Scientific/Schema.flix` | other | pure-scientific-schema | 9 | 9 | 0 | 9 |
| 6 | `src/Scientific/Value.flix` | other | pure-scientific-schema | 9 | 9 | 0 | 9 |
| 7 | `src/Kernel/Effect.flix` | kernel | capability-effect-declarations | 7 | 7 | 0 | 7 |
| 8 | `src/Stage/World.flix` | other | typed-stage-node | 7 | 7 | 0 | 7 |
| 9 | `src/World.flix` | other | world-admission-module | 7 | 7 | 0 | 7 |
| 10 | `src/World/Admission.flix` | other | world-admission-module | 7 | 7 | 0 | 7 |
| 11 | `src/World/CallIndex.flix` | other | world-admission-module | 7 | 7 | 0 | 7 |
| 12 | `src/World/Language.flix` | other | world-admission-module | 7 | 7 | 0 | 7 |
| 13 | `src/World/Language/Flix.flix` | other | world-admission-module | 7 | 7 | 0 | 7 |
| 14 | `src/World/Language/Java.flix` | other | world-admission-module | 7 | 7 | 0 | 7 |
| 15 | `src/World/Language/JavaScript.flix` | other | world-admission-module | 7 | 7 | 0 | 7 |
| 16 | `src/World/Language/Starlark.flix` | other | world-admission-module | 7 | 7 | 0 | 7 |
| 17 | `src/Scientific/Parquet.flix` | other | parquet-transport-seam | 6 | 6 | 0 | 6 |
| 18 | `src/Stage.flix` | other | stage-namespace-anchor | 6 | 6 | 0 | 6 |
| 19 | `src/Stage/Atlas.flix` | other | typed-stage-node | 5 | 5 | 0 | 5 |
| 20 | `test/Repository.flix` | law | horizontal-law-fixture | 5 | 13 | 8 | 13 |
| 21 | `src/Kernel/DigestHandler.flix` | kernel | effect-handler | 4 | 4 | 0 | 4 |
| 22 | `src/Kernel/Handler.flix` | kernel | effect-handler | 4 | 4 | 0 | 4 |
| 23 | `src/Stage/Prior.flix` | other | typed-stage-node | 4 | 4 | 0 | 4 |
| 24 | `src/Stage/Acquire.flix` | other | typed-stage-node | 3 | 3 | 0 | 3 |
| 25 | `src/Stage/CandidateSet.flix` | other | typed-stage-node | 3 | 3 | 0 | 3 |
| 26 | `src/Stage/Judge.flix` | other | typed-stage-node | 3 | 3 | 0 | 3 |
| 27 | `src/Stage/Projection.flix` | other | typed-stage-node | 3 | 3 | 0 | 3 |
| 28 | `src/Repository.flix` | world | pre-existing-production-module | 2 | 6 | 4 | 6 |
| 29 | `src/Stage/Pipeline.flix` | other | typed-stage-node | 2 | 2 | 0 | 2 |
| 30 | `test/TestWorlds.flix` | law | horizontal-law-fixture | 2 | 4 | 2 | 4 |
| 31 | `experiments/atlas-swe-explore/Summary.flix` | research | research-instrument | 1 | 1 | 0 | 1 |
| 32 | `src/Atlas.flix` | engine | pre-existing-production-module | 1 | 2 | 1 | 2 |
| 33 | `src/Atlas/Signature.flix` | engine | pre-existing-production-module | 1 | 2 | 1 | 2 |
| 34 | `src/Atlas/Signature/Table.flix` | engine | pre-existing-production-module | 1 | 5 | 4 | 5 |
| 35 | `src/Experiment.flix` | research | pre-existing-production-module | 1 | 1 | 0 | 1 |
| 36 | `src/Population/Table.flix` | applications | pre-existing-production-module | 1 | 4 | 3 | 4 |
| 37 | `src/Radii.flix` | engine | pre-existing-production-module | 1 | 2 | 1 | 2 |
| 38 | `src/Radii/Evaluate.flix` | engine | pre-existing-production-module | 1 | 2 | 1 | 2 |
| 39 | `src/Radii/Synthesize.flix` | engine | pre-existing-production-module | 1 | 2 | 1 | 2 |
| 40 | `src/Repository/Grit.flix` | world | pre-existing-production-module | 1 | 4 | 3 | 4 |
| 41 | `src/Repository/Physical.flix` | engine | pre-existing-production-module | 1 | 2 | 1 | 2 |
| 42 | `src/Repository/Table.flix` | world | pre-existing-production-module | 1 | 5 | 4 | 5 |
| 43 | `src/native/grit/AttuneGrit.java` | world | native-seam | 1 | 1 | 0 | 1 |
| 44 | `src/native/grit/AttuneGritNative.java` | world | native-seam | 1 | 1 | 0 | 1 |
| 45 | `src/native/identity/AttuneIdentity.java` | kernel | native-seam | 1 | 5 | 4 | 5 |
| 46 | `src/native/parquet/AttuneParquet.java` | kernel | native-seam | 1 | 5 | 4 | 5 |
| 47 | `src/Repository/Structure.flix` | world | pre-existing-production-module | -2 | 2 | 4 | 2 |
| 48 | `src/ScientificTable.flix` | kernel | pre-existing-production-module | -4 | 0 | 4 | 0 |
| 49 | `src/ScientificTable/Columns.flix` | kernel | pre-existing-production-module | -4 | 0 | 4 | 0 |

Positive deltas sum to **+204**; three files contribute **−10** (the renamed
`src/ScientificTable*` paths now read 0, `src/Repository/Structure.flix` −2);
204 − 10 = 194, the recorded increase. Of the 46 positive contributors, **31
had zero cross-stage invalidation at control** (mostly the new
kernel/World/Stage/Scientific files) and 15 are pre-existing modules whose
invalidation grew (rebinding into the new stage catalogs).

## 5. Ranked causes — §16 `_dagref` keying (supplementary)

| # | file | stage | role | Δ | D | ctrl | tests invalidated |
|---|---|---|---|---|---|---|---|
| 1 | `src/Kernel.flix` | kernel | kernel-namespace-anchor | 12 | 12 | 0 | 12 |
| 2 | `src/Kernel/Contract.flix` | kernel | contract-kernel | 12 | 12 | 0 | 12 |
| 3 | `src/Kernel/Effect.flix` | kernel | capability-effect-declarations | 7 | 7 | 0 | 7 |
| 4 | `src/Stage.flix` | other | stage-namespace-anchor | 6 | 6 | 0 | 6 |
| 5 | `src/Scientific.flix` | kernel | scientific-namespace-anchor | 5 | 5 | 0 | 5 |
| 6 | `src/Scientific/Row.flix` | kernel | pure-scientific-schema | 5 | 5 | 0 | 5 |
| 7 | `src/Scientific/Schema.flix` | kernel | pure-scientific-schema | 5 | 5 | 0 | 5 |
| 8 | `src/Scientific/Value.flix` | kernel | pure-scientific-schema | 5 | 5 | 0 | 5 |
| 9 | `test/Repository.flix` | law | horizontal-law-fixture | 5 | 13 | 8 | 13 |
| 10 | `src/Kernel/DigestHandler.flix` | kernel | effect-handler | 4 | 4 | 0 | 4 |
| 11 | `src/Kernel/Handler.flix` | kernel | effect-handler | 4 | 4 | 0 | 4 |
| 12 | `src/Scientific/Parquet.flix` | kernel | parquet-transport-seam | 3 | 3 | 0 | 3 |
| 13 | `src/Stage/World.flix` | world | typed-stage-node | 3 | 3 | 0 | 3 |
| 14 | `src/World.flix` | world | world-admission-module | 3 | 3 | 0 | 3 |
| 15 | `src/World/Admission.flix` | world | world-admission-module | 3 | 3 | 0 | 3 |
| 16 | `src/World/CallIndex.flix` | world | world-admission-module | 3 | 3 | 0 | 3 |
| 17 | `src/World/Language.flix` | world | world-admission-module | 3 | 3 | 0 | 3 |
| 18 | `src/World/Language/Flix.flix` | world | world-admission-module | 3 | 3 | 0 | 3 |
| 19 | `src/World/Language/Java.flix` | world | world-admission-module | 3 | 3 | 0 | 3 |
| 20 | `src/World/Language/JavaScript.flix` | world | world-admission-module | 3 | 3 | 0 | 3 |
| 21 | `src/World/Language/Starlark.flix` | world | world-admission-module | 3 | 3 | 0 | 3 |
| 22 | `src/Repository.flix` | world | pre-existing-production-module | 2 | 6 | 4 | 6 |
| 23 | `src/Stage/Atlas.flix` | engine | typed-stage-node | 2 | 2 | 0 | 2 |
| 24 | `src/Stage/Prior.flix` | engine | typed-stage-node | 2 | 2 | 0 | 2 |
| 25 | `test/TestWorlds.flix` | law | horizontal-law-fixture | 2 | 4 | 2 | 4 |
| 26 | `experiments/atlas-swe-explore/Summary.flix` | research | research-instrument | 1 | 1 | 0 | 1 |
| 27 | `src/Atlas.flix` | engine | pre-existing-production-module | 1 | 2 | 1 | 2 |
| 28 | `src/Atlas/Signature.flix` | engine | pre-existing-production-module | 1 | 2 | 1 | 2 |
| 29 | `src/Atlas/Signature/Table.flix` | engine | pre-existing-production-module | 1 | 5 | 4 | 5 |
| 30 | `src/Experiment.flix` | research | pre-existing-production-module | 1 | 1 | 0 | 1 |
| 31 | `src/Population/Table.flix` | applications | pre-existing-production-module | 1 | 4 | 3 | 4 |
| 32 | `src/Radii.flix` | engine | pre-existing-production-module | 1 | 2 | 1 | 2 |
| 33 | `src/Radii/Evaluate.flix` | engine | pre-existing-production-module | 1 | 2 | 1 | 2 |
| 34 | `src/Radii/Synthesize.flix` | engine | pre-existing-production-module | 1 | 2 | 1 | 2 |
| 35 | `src/Repository/Grit.flix` | world | pre-existing-production-module | 1 | 4 | 3 | 4 |
| 36 | `src/Repository/Physical.flix` | engine | pre-existing-production-module | 1 | 2 | 1 | 2 |
| 37 | `src/Repository/Table.flix` | world | pre-existing-production-module | 1 | 5 | 4 | 5 |
| 38 | `src/native/grit/AttuneGrit.java` | world | native-seam | 1 | 1 | 0 | 1 |
| 39 | `src/native/grit/AttuneGritNative.java` | world | native-seam | 1 | 1 | 0 | 1 |
| 40 | `src/native/identity/AttuneIdentity.java` | kernel | native-seam | 1 | 5 | 4 | 5 |
| 41 | `src/native/parquet/AttuneParquet.java` | kernel | native-seam | 1 | 5 | 4 | 5 |
| 42 | `src/Repository/Structure.flix` | world | pre-existing-production-module | -2 | 2 | 4 | 2 |
| 43 | `src/ScientificTable.flix` | kernel | pre-existing-production-module | -4 | 0 | 4 | 0 |
| 44 | `src/ScientificTable/Columns.flix` | kernel | pre-existing-production-module | -4 | 0 | 4 | 0 |

Positive deltas sum to **+124**, negatives **−10**, giving the recorded **+114**.
The `_dagref` re-key moves `src/Kernel.flix`, `src/Scientific/*`, `src/World/*`
and `src/Stage/*` out of the residual `other` bucket into the stage they own,
which shrinks their contribution — the direct evidence of mechanism M1. The
§2.3 residual files are exactly the mission's own stage units (mission.md §1
K4-2: "the frozen path function does not recognize the architecture's own
stage units").

## 6. Per-node invalidation fan-out

Fan-out of a node is the number of distinct cross-stage test targets a change
to that file would re-run.

### frozen §2.3

| fan-out | nodes |
|---|---|
| 1 | 5 |
| 2 | 8 |
| 3 | 4 |
| 4 | 7 |
| 5 | 5 |
| 6 | 3 |
| 7 | 10 |
| 9 | 4 |
| 12 | 1 |
| 13 | 1 |
| 18 | 1 |

Highest fan-out nodes (frozen):

| node | stage | fan-out |
|---|---|---|
| `src/Kernel.flix` | other | 18 |
| `test/Repository.flix` | law | 13 |
| `src/Kernel/Contract.flix` | kernel | 12 |
| `src/Scientific.flix` | other | 9 |
| `src/Scientific/Row.flix` | other | 9 |
| `src/Scientific/Schema.flix` | other | 9 |
| `src/Scientific/Value.flix` | other | 9 |
| `src/Kernel/Effect.flix` | kernel | 7 |
| `src/Stage/World.flix` | other | 7 |
| `src/World.flix` | other | 7 |
| `src/World/Admission.flix` | other | 7 |
| `src/World/CallIndex.flix` | other | 7 |

### §16 `_dagref`

| fan-out | nodes |
|---|---|
| 1 | 5 |
| 2 | 9 |
| 3 | 10 |
| 4 | 6 |
| 5 | 8 |
| 6 | 2 |
| 7 | 1 |
| 12 | 2 |
| 13 | 1 |

Highest fan-out nodes (`_dagref`):

| node | stage | fan-out |
|---|---|---|
| `test/Repository.flix` | law | 13 |
| `src/Kernel.flix` | kernel | 12 |
| `src/Kernel/Contract.flix` | kernel | 12 |
| `src/Kernel/Effect.flix` | kernel | 7 |
| `src/Repository.flix` | world | 6 |
| `src/Stage.flix` | other | 6 |
| `src/Atlas/Signature/Table.flix` | engine | 5 |
| `src/Repository/Table.flix` | world | 5 |
| `src/Scientific.flix` | kernel | 5 |
| `src/Scientific/Row.flix` | kernel | 5 |
| `src/Scientific/Schema.flix` | kernel | 5 |
| `src/Scientific/Value.flix` | kernel | 5 |

The frozen keying has 49 nodes with fan-out ≥ 1 and the `_dagref` keying 44
(the candidate D contributor sets); control has 20. The modal fan-out is small
(frozen: 8 nodes at 2, 10 nodes at 7; dagref: 10 nodes at 3, 9 nodes at 2).
There is no heavy tail: the largest node is 18 (frozen) / 13 (dagref), and only
one node exceeds 12.

## 7. Test-side fan-out (how many upstream files each test watches)

| keying | distinct tests invalidated | note |
|---|---|---|
| control | 10 | 59 `(file, test)` pairs |
| Candidate D frozen | 23 | 253 pairs |

Control test targets and their upstream cross-stage file counts:

| test | stage | upstream files |
|---|---|---|
| `//test/Applications:localization_sandwich_test` | applications | 18 |
| `//test/Engine:atlas_signature_table_test` | engine | 11 |
| `//test/World:repository_table_test` | world | 8 |
| `//test/Engine:atlas_grammar_test` | engine | 7 |
| `//test/Applications:population_table_test` | applications | 5 |
| `//test/Engine:core_parity_test` | engine | 4 |
| `//test/Kernel:scientific_table_test` | kernel | 3 |
| `//test/World:grit_acquire_test` | world | 1 |
| `//test/World:grit_acquisition_test` | world | 1 |
| `//test/World:repository_admission_test` | world | 1 |

Candidate D test targets and their upstream cross-stage file counts:

| test | stage | upstream files |
|---|---|---|
| `//test/Applications:localization_sandwich_test` | applications | 36 |
| `//test/Engine:atlas_signature_table_test` | engine | 27 |
| `//test/World:repository_table_test` | world | 25 |
| `//test/Engine:atlas_grammar_test` | engine | 23 |
| `//test/Applications:stage_pipeline_test` | applications | 19 |
| `//test/World:flix_loc_law_test` | world | 13 |
| `//test/World:handler_production_test` | world | 13 |
| `//test/World:repository_admission_test` | world | 13 |
| `//test/Kernel:handler_test` | kernel | 12 |
| `//test/World:grit_acquisition_test` | world | 12 |
| `//test/Applications:population_table_test` | applications | 10 |
| `//test/Applications:flix_loc_law_test` | applications | 6 |
| `//test/Engine:core_parity_test` | engine | 6 |
| `//test/Kernel:flix_loc_law_test` | kernel | 6 |
| `//test/Kernel:parquet_transport_test` | kernel | 6 |
| `//test/World:grit_acquire_test` | world | 6 |
| `//test/Applications:inference_boundary_test` | applications | 5 |
| `//test/Engine:flix_loc_law_test` | engine | 5 |
| `//test/Kernel:scientific_table_test` | kernel | 5 |
| `//test/World:acquire_seam_test` | world | 2 |
| `//src/research:flix_loc_law_test` | other | 1 |
| `//test/Kernel:contract_test` | kernel | 1 |
| `//test/Kernel:effect_test` | kernel | 1 |

The number of invalidated test targets grew from 10 to 23 (+13). Five of the 13
new targets are Candidate D's per-stage LOC-law slices
(`//test/{World,Engine,Kernel,Applications}:flix_loc_law_test` plus
`//src/research:flix_loc_law_test`); the rest are new stage/kernel law targets
(`stage_pipeline_test`, `inference_boundary_test`, `handler_test`,
`parquet_transport_test`, `handler_production_test`, `acquire_seam_test`,
`contract_test`, `effect_test`). Each watches a handful of upstream files. The
largest test (`//test/Applications:localization_sandwich_test`, 36 upstream
files) already existed at control (18 upstream files); the distribution stays
flat, it is the file count per test that grew, not the appearance of a
dominating test.

## 8. Top-1/3/5/10 cumulative share of the increase

The task's central concentration measure: rank contributors by their positive
delta and report the share of the **increase** they explain.

### frozen §2.3 (increase = 194)

| top-k | cumulative Δ | share of increase (%) |
|---|---|---|
| 1 | 18 | 9.28 |
| 3 | 39 | 20.1 |
| 5 | 57 | 29.38 |
| 10 | 94 | 48.45 |

### §16 `_dagref` (increase = 114)

| top-k | cumulative Δ | share of increase (%) |
|---|---|---|
| 1 | 12 | 10.53 |
| 3 | 31 | 27.19 |
| 5 | 42 | 36.84 |
| 10 | 66 | 57.89 |

Contributors needed to reach a fraction of the increase:

| keying | 50% | 80% | 90% |
|---|---|---|---|
| frozen §2.3 | 11 files | 20 files | 25 files |
| §16 `_dagref` | 8 files | 19 files | 23 files |

## 9. Verdict: broad shallow propagation, not hubs

The preregistered verdict rule (`verdict_rule` in the JSON) was fixed before
this analysis ran: hubs if the top-3 share of the increase ≥ 50% **or** the
largest single share ≥ 25% **or** 80% is reached within ≤ 5 contributors;
broad if the top-10 share < 50% **and** 80% needs ≥ 20 contributors.

| test | frozen §2.3 | §16 `_dagref` | hub would be |
|---|---|---|---|
| largest single contributor share | 9.28% (`src/Kernel.flix`, Δ 18) | 10.53% (`src/Kernel.flix`, Δ 12) | ≥ 25% |
| top-3 share | 20.10% | 27.19% | ≥ 50% |
| top-5 share | 29.38% | 36.84% | — |
| top-10 share | 48.45% | 57.89% | — |
| contributors to reach 80% | 20 | 19 | ≤ 5 |
| max per-node fan-out | 18 | 13 | — |

**Recorded verdict: broad shallow propagation, under BOTH keyings.** No single
file, stage, or relation is a pathological hub. The largest contributor
(`src/Kernel.flix`, the 2-line kernel namespace anchor) explains less than a
tenth of the increase. Removing the top-5 causes would still leave ~70%
(frozen) of the increase unexplained by concentration.

## 10. Mechanism attribution

Every newly introduced invalidation is attributable to one of three concrete
mechanisms, all of which are *uniform small* effects rather than hubs.

**M1 — the frozen §2.3 path table does not recognize the DAG paths.** 31 of the
46 positive contributors had **zero** cross-stage invalidation at control; the
bulk of them are the new files `src/Kernel.flix`, `src/Scientific/*`,
`src/World/*`, `src/Stage/*`, `src/Stage.flix`, which match no §2.3 rule, so the
frozen keying classifies them as the residual bucket `other`. A test in a real
stage then reads them across a stage boundary. The `_dagref` re-key names their
true stage and their contribution drops (e.g. `src/Kernel.flix` 18 → 12,
`src/World/*` 7 → 3). This is an artifact of the frozen path instantiation, not
added semantic propagation — evidence for the metric-soundness review
(VAL-PROV-007).

**M2 — a new leaf file is read by every downstream cell by design.** The
contract kernel (`src/Kernel/Contract.flix`: nominal IDs, Datalog relation
types, Atlas 6-atom grammar, scientific schema, stage ADTs), the capability
effects (`src/Kernel/Effect.flix`), the pure scientific schema
(`src/Scientific/{Schema,Value,Row}.flix`) and the Parquet seam
(`src/Scientific/Parquet.flix`) are the read-only kernel every cell compiles
against. A change to any of them invalidates the World / Engine / Applications /
Kernel cell laws that read it through the shared law catalogs in
`test/BUILD.bazel` (`//test:kernel_contract_law_sources`,
`//test:kernel_table_law_sources`, …). Each such file contributes 4–12
cross-stage tests, uniformly.

**M3 — horizontal law fixtures and shared catalogs.** `test/Repository.flix`
(the reduced `mod Repository {}` parent anchor every relational law compiles
against; Δ +5) and `test/TestWorlds.flix` (the a/b test world; Δ +2) are law
fixtures read by multiple cells; `src/Repository.flix` itself (Δ +2) still hosts
the `Repository.Structure` anchor. Candidate D's fine-grained law slices
(`//test/*:flix_loc_law_test`) also added per-stage test targets that watch the
single upstream file each slice owns, adding one small invalidation each.

None of M1–M3 is a hub: each contributes a bounded, uniform number of test
targets, and their sum — not any one — is the increase.

## 11. Cross-check: the reverse (name-free) direction

The instrument of record resolves a file's declaring targets by `basename`
(`attr(srcs, "<basename>", //...)`). On a tree with same-basename files across
packages (e.g. many `Table.flix`, `Summary.flix`) this can over-count. The
independent reverse direction — `kind("source file", deps(<test>))` for every
test, counted test→file with no names involved — gives:

| tree | instrument frozen / all / dagref | reverse frozen / all / dagref | agreeing paths | disagreeing paths |
|---|---|---|---|---|
| control | 59 / 260 / 59 | 40 / 215 / 40 | 71 | 5 |
| Candidate D | 253 / 664 / 173 | 216 / 569 / 140 | 100 | 10 |

The two directions agree on the large majority of paths and the reverse reading
is uniformly lower, so the primary metric is a consistent **upper bound**
(37 frozen / 39 dagref pairs at Candidate D are attributed to declarers reached
by basename). The 10 candidate disagreements are concentrated on files whose
basename recurs (`Table.flix`, `Summary.flix`, `Stage/*`). The metric of record
is preserved unchanged; this cross-check is recorded as method and as input to
the refined-metric discussion (VAL-PROV-007), never substituted.

## 12. Reproduction

All commands run from the repository root. `extract` is deterministic and its
fidelity gate fails loudly if a tree does not reproduce the recorded values.

```bash
source /etc/profile.d/nix.sh
E=experiments/effectful-stage-architecture/scripts/extract_invalidation_provenance.sh

# 1. control tree
git worktree add --detach /tmp/attuneflix-provenance-control 09e27244af9340aa616116a93ea02472e7521ba5

# 2. per-file extract, with hard fidelity gates against the committed records
ATTUNE_EXPECT_FROZEN=253 ATTUNE_EXPECT_ALL=664 ATTUNE_EXPECT_DAGREF=173 \
  nix develop --command bash $E extract /tmp/invalidation-provenance-candidate-d.json
ATTUNE_TREE_ROOT=/tmp/attuneflix-provenance-control \
ATTUNE_EXPECT_FROZEN=59 ATTUNE_EXPECT_ALL=260 ATTUNE_EXPECT_DAGREF=59 \
  nix develop --command bash $E extract /tmp/invalidation-provenance-control.json

# 3. join: ranked causes, fan-out, top-1/3/5/10, contributors-to-50/80/90%
nix develop --command bash $E analyze \
  /tmp/invalidation-provenance-control.json \
  /tmp/invalidation-provenance-candidate-d.json /tmp/provenance-analysis.json

# 4. reverse cross-check and the BASIS graph
nix develop --command bash $E crosscheck /tmp/invalidation-provenance-candidate-d.json /tmp/invalidation-crosscheck-candidate-d.json
ATTUNE_TREE_ROOT=/tmp/attuneflix-provenance-control nix develop --command bash $E crosscheck \
  /tmp/invalidation-provenance-control.json /tmp/invalidation-crosscheck-control.json
nix develop --command bash $E basis /tmp/basis-candidate-d.json

# 5. assemble the machine-readable artifact, then render this markdown from it
jq -n --slurpfile A /tmp/provenance-analysis.json \
      --slurpfile B /tmp/basis-candidate-d.json \
      --slurpfile X /tmp/invalidation-crosscheck-control.json \
      --slurpfile Y /tmp/invalidation-crosscheck-candidate-d.json \
   -f experiments/effectful-stage-architecture/scripts/merge_provenance_artifact.jq \
   > experiments/effectful-stage-architecture/candidates/provenance-analysis.json
nix develop --command bash experiments/effectful-stage-architecture/scripts/render_provenance_analysis.sh

# 6. clean up the scratch worktree
git worktree remove --force /tmp/attuneflix-provenance-control
```

The join, the merge and this renderer are all committed
(`scripts/extract_invalidation_provenance.sh`,
`scripts/merge_provenance_artifact.jq`,
`scripts/render_provenance_analysis.sh`), so every number in this document is
regenerable from the repository and the two trees alone.

## 13. Boundaries — what this analysis does not change

- It does not re-run, modify, or re-key the instrument of record; the frozen
  `baseline-metrics.json`, `candidate-*.json`, `PREREGISTRATION.md` and every
  `.attune/**` file are byte-untouched and read-only here.
- It does not reinterpret the §9.4 targets. 253 and 173 remain the recorded
  failures; this analysis explains them, it does not convert them.
- It does not call any provider, embedding, or model; all numbers are a pure
  function of the tracked tree and its declared BUILD graph.

## Appendix A — invalidated test targets per newly contributing file (frozen §2.3)

| file | Δ | invalidated cross-stage test targets |
|---|---|---|
| `src/Kernel.flix` | 18 | test/Applications:inference_boundary_test, test/Applications:localization_sandwich_test, test/Applications:population_table_test, test/Applications:stage_pipeline_test, test/Engine:atlas_grammar_test, test/Engine:atlas_signature_table_test, test/Engine:core_parity_test, test/Kernel:contract_test, test/Kernel:effect_test, test/Kernel:flix_loc_law_test, test/Kernel:handler_test, test/Kernel:parquet_transport_test, test/Kernel:scientific_table_test, test/World:grit_acquire_test, test/World:grit_acquisition_test, test/World:handler_production_test, test/World:repository_admission_test, test/World:repository_table_test |
| `src/Kernel/Contract.flix` | 12 | test/Applications:inference_boundary_test, test/Applications:localization_sandwich_test, test/Applications:population_table_test, test/Applications:stage_pipeline_test, test/Engine:atlas_grammar_test, test/Engine:atlas_signature_table_test, test/Engine:core_parity_test, test/World:grit_acquire_test, test/World:grit_acquisition_test, test/World:handler_production_test, test/World:repository_admission_test, test/World:repository_table_test |
| `src/Scientific.flix` | 9 | test/Applications:localization_sandwich_test, test/Applications:population_table_test, test/Engine:atlas_signature_table_test, test/Kernel:flix_loc_law_test, test/Kernel:handler_test, test/Kernel:parquet_transport_test, test/Kernel:scientific_table_test, test/World:handler_production_test, test/World:repository_table_test |
| `src/Scientific/Row.flix` | 9 | test/Applications:localization_sandwich_test, test/Applications:population_table_test, test/Engine:atlas_signature_table_test, test/Kernel:flix_loc_law_test, test/Kernel:handler_test, test/Kernel:parquet_transport_test, test/Kernel:scientific_table_test, test/World:handler_production_test, test/World:repository_table_test |
| `src/Scientific/Schema.flix` | 9 | test/Applications:localization_sandwich_test, test/Applications:population_table_test, test/Engine:atlas_signature_table_test, test/Kernel:flix_loc_law_test, test/Kernel:handler_test, test/Kernel:parquet_transport_test, test/Kernel:scientific_table_test, test/World:handler_production_test, test/World:repository_table_test |
| `src/Scientific/Value.flix` | 9 | test/Applications:localization_sandwich_test, test/Applications:population_table_test, test/Engine:atlas_signature_table_test, test/Kernel:flix_loc_law_test, test/Kernel:handler_test, test/Kernel:parquet_transport_test, test/Kernel:scientific_table_test, test/World:handler_production_test, test/World:repository_table_test |
| `src/Kernel/Effect.flix` | 7 | test/Applications:localization_sandwich_test, test/Applications:stage_pipeline_test, test/Engine:atlas_grammar_test, test/Engine:atlas_signature_table_test, test/World:grit_acquire_test, test/World:handler_production_test, test/World:repository_table_test |
| `src/Stage/World.flix` | 7 | test/Applications:localization_sandwich_test, test/Engine:atlas_grammar_test, test/Engine:atlas_signature_table_test, test/World:flix_loc_law_test, test/World:grit_acquisition_test, test/World:repository_admission_test, test/World:repository_table_test |
| `src/World.flix` | 7 | test/Applications:localization_sandwich_test, test/Engine:atlas_grammar_test, test/Engine:atlas_signature_table_test, test/World:flix_loc_law_test, test/World:grit_acquisition_test, test/World:repository_admission_test, test/World:repository_table_test |
| `src/World/Admission.flix` | 7 | test/Applications:localization_sandwich_test, test/Engine:atlas_grammar_test, test/Engine:atlas_signature_table_test, test/World:flix_loc_law_test, test/World:grit_acquisition_test, test/World:repository_admission_test, test/World:repository_table_test |
| `src/World/CallIndex.flix` | 7 | test/Applications:localization_sandwich_test, test/Engine:atlas_grammar_test, test/Engine:atlas_signature_table_test, test/World:flix_loc_law_test, test/World:grit_acquisition_test, test/World:repository_admission_test, test/World:repository_table_test |
| `src/World/Language.flix` | 7 | test/Applications:localization_sandwich_test, test/Engine:atlas_grammar_test, test/Engine:atlas_signature_table_test, test/World:flix_loc_law_test, test/World:grit_acquisition_test, test/World:repository_admission_test, test/World:repository_table_test |
| `src/World/Language/Flix.flix` | 7 | test/Applications:localization_sandwich_test, test/Engine:atlas_grammar_test, test/Engine:atlas_signature_table_test, test/World:flix_loc_law_test, test/World:grit_acquisition_test, test/World:repository_admission_test, test/World:repository_table_test |
| `src/World/Language/Java.flix` | 7 | test/Applications:localization_sandwich_test, test/Engine:atlas_grammar_test, test/Engine:atlas_signature_table_test, test/World:flix_loc_law_test, test/World:grit_acquisition_test, test/World:repository_admission_test, test/World:repository_table_test |
| `src/World/Language/JavaScript.flix` | 7 | test/Applications:localization_sandwich_test, test/Engine:atlas_grammar_test, test/Engine:atlas_signature_table_test, test/World:flix_loc_law_test, test/World:grit_acquisition_test, test/World:repository_admission_test, test/World:repository_table_test |
| `src/World/Language/Starlark.flix` | 7 | test/Applications:localization_sandwich_test, test/Engine:atlas_grammar_test, test/Engine:atlas_signature_table_test, test/World:flix_loc_law_test, test/World:grit_acquisition_test, test/World:repository_admission_test, test/World:repository_table_test |
| `src/Scientific/Parquet.flix` | 6 | test/Applications:population_table_test, test/Kernel:flix_loc_law_test, test/Kernel:handler_test, test/Kernel:parquet_transport_test, test/World:handler_production_test, test/World:repository_table_test |
| `src/Stage.flix` | 6 | test/Applications:inference_boundary_test, test/Applications:localization_sandwich_test, test/Applications:stage_pipeline_test, test/Engine:atlas_grammar_test, test/World:grit_acquire_test, test/World:repository_admission_test |
| `src/Stage/Atlas.flix` | 5 | test/Applications:localization_sandwich_test, test/Applications:stage_pipeline_test, test/Engine:atlas_grammar_test, test/Engine:atlas_signature_table_test, test/Engine:flix_loc_law_test |
| `test/Repository.flix` | 5 | test/Applications:localization_sandwich_test, test/Applications:stage_pipeline_test, test/Engine:atlas_grammar_test, test/Engine:atlas_signature_table_test, test/Engine:core_parity_test, test/Kernel:handler_test, test/World:acquire_seam_test, test/World:flix_loc_law_test, test/World:grit_acquire_test, test/World:grit_acquisition_test, test/World:handler_production_test, test/World:repository_admission_test, test/World:repository_table_test |
| `src/Kernel/DigestHandler.flix` | 4 | test/Engine:atlas_grammar_test, test/Engine:atlas_signature_table_test, test/World:handler_production_test, test/World:repository_table_test |
| `src/Kernel/Handler.flix` | 4 | test/Engine:atlas_grammar_test, test/Engine:atlas_signature_table_test, test/World:handler_production_test, test/World:repository_table_test |
| `src/Stage/Prior.flix` | 4 | test/Applications:localization_sandwich_test, test/Applications:stage_pipeline_test, test/Engine:atlas_grammar_test, test/Engine:flix_loc_law_test |
| `src/Stage/Acquire.flix` | 3 | test/World:acquire_seam_test, test/World:flix_loc_law_test, test/World:grit_acquire_test |
| `src/Stage/CandidateSet.flix` | 3 | test/Applications:flix_loc_law_test, test/Applications:localization_sandwich_test, test/Applications:stage_pipeline_test |
| `src/Stage/Judge.flix` | 3 | test/Applications:flix_loc_law_test, test/Applications:localization_sandwich_test, test/Applications:stage_pipeline_test |
| `src/Stage/Projection.flix` | 3 | test/Applications:flix_loc_law_test, test/Applications:inference_boundary_test, test/Applications:stage_pipeline_test |
| `src/Repository.flix` | 2 | test/Applications:localization_sandwich_test, test/Applications:stage_pipeline_test, test/Engine:atlas_grammar_test, test/Engine:atlas_signature_table_test, test/Engine:core_parity_test, test/Kernel:handler_test |
| `src/Stage/Pipeline.flix` | 2 | test/Applications:flix_loc_law_test, test/Applications:stage_pipeline_test |
| `test/TestWorlds.flix` | 2 | test/Applications:inference_boundary_test, test/Applications:localization_sandwich_test, test/Applications:stage_pipeline_test, test/Engine:atlas_grammar_test |
| `experiments/atlas-swe-explore/Summary.flix` | 1 | test/Engine:flix_loc_law_test |
| `src/Atlas.flix` | 1 | test/Applications:localization_sandwich_test, test/Applications:stage_pipeline_test |
| `src/Atlas/Signature.flix` | 1 | test/Applications:localization_sandwich_test, test/Applications:stage_pipeline_test |
| `src/Atlas/Signature/Table.flix` | 1 | test/Applications:flix_loc_law_test, test/Applications:localization_sandwich_test, test/Applications:population_table_test, test/World:flix_loc_law_test, test/World:repository_table_test |
| `src/Experiment.flix` | 1 | src/research:flix_loc_law_test |
| `src/Population/Table.flix` | 1 | test/Engine:atlas_signature_table_test, test/Engine:flix_loc_law_test, test/World:flix_loc_law_test, test/World:repository_table_test |
| `src/Radii.flix` | 1 | test/Applications:localization_sandwich_test, test/Applications:stage_pipeline_test |
| `src/Radii/Evaluate.flix` | 1 | test/Applications:localization_sandwich_test, test/Applications:stage_pipeline_test |
| `src/Radii/Synthesize.flix` | 1 | test/Applications:localization_sandwich_test, test/Applications:stage_pipeline_test |
| `src/Repository/Grit.flix` | 1 | test/Applications:localization_sandwich_test, test/Engine:atlas_grammar_test, test/Engine:atlas_signature_table_test, test/Kernel:handler_test |
| `src/Repository/Physical.flix` | 1 | test/Applications:localization_sandwich_test, test/Applications:stage_pipeline_test |
| `src/Repository/Table.flix` | 1 | test/Applications:flix_loc_law_test, test/Applications:localization_sandwich_test, test/Applications:population_table_test, test/Engine:atlas_signature_table_test, test/Engine:flix_loc_law_test |
| `src/native/grit/AttuneGrit.java` | 1 | test/Kernel:handler_test |
| `src/native/grit/AttuneGritNative.java` | 1 | test/Kernel:handler_test |
| `src/native/identity/AttuneIdentity.java` | 1 | test/Applications:localization_sandwich_test, test/Engine:atlas_grammar_test, test/Engine:atlas_signature_table_test, test/World:handler_production_test, test/World:repository_table_test |
| `src/native/parquet/AttuneParquet.java` | 1 | test/Applications:localization_sandwich_test, test/Applications:population_table_test, test/Engine:atlas_signature_table_test, test/World:handler_production_test, test/World:repository_table_test |
