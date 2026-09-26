# PREREGISTRATION — AttuneFlix effectful typed-stage architecture experiment

Status: **preregistered**. This file is committed as its own `jj` change whose
only parents are the frozen control specimen
`main@09e27244af9340aa616116a93ea02472e7521ba5` and the milestone-1 control
record that documents it (`CONTROL.md`, `control-baseline.json`). No
architecture change, and no candidate measurement, exists in the experiment
history before this change (provable with `nix develop --command jj log`).

Nothing here is amended after a measurement runs except by an explicit, dated,
pre-measurement amendment appended at the end of the file (house precedent:
`experiments/atlas-work-topology/PREREGISTRATION.md`). The control figures
quoted in §9 are the mission's *measured control*, frozen in
`baseline-metrics.json` by the instrument of §10. The experiment was designed
before any candidate number was observed.

Central hypothesis (falsifiable, one repository, one intervention):

> A software system can keep its repository meaning and its Atlas signature
> exactly, while being reorganized from shared mutable implementation coupling
> into an effectful typed-stage pipeline whose stages are genuinely parallel to
> change — because the only shared thing left is a leaf-level, pure, frozen
> contract kernel that nobody has to edit.

The **semantic and signature oracles are the constraint**; the **writable work
topology is the objective**. A topology improvement that moves the meaning or
the signature is not a result of this experiment, it is a rejection (§7, O1-O6).
A signature-preserving improvement that does not move the topology is a
reported negative finding, not a failure.

## 0. The bound dimensions (index)

| # | dimension | bound in |
|---|---|---|
| 1 | control revision and baseline | §1 |
| 2 | admission and the three partitions (region, stage, kernel) | §2 |
| 3 | BASIS channel metric formulas | §3 |
| 4 | BUILD channel metric formulas | §4 |
| 5 | WORK channel metric formulas | §5 |
| 6 | kernel size tax | §6 |
| 7 | candidate acceptance / rejection oracle (O1-O9) | §7 |
| 8 | hill-climb procedure and candidate budget | §8 |
| 9 | measured control baseline and success thresholds | §9 |
| 10 | instrument of record, provenance and determinism | §10 |
| 11 | stopping rules | §11 |
| 12 | outcome classification | §12 |
| 13 | artifacts and the Flix/Starlark migration of the instrument | §13 |
| 14 | what this experiment never does | §14 |
| 15 | ordering guarantee | §15 |

## 1. Control revision and baseline

- `control_revision = 09e27244af9340aa616116a93ea02472e7521ba5` (`main`, the
  mission's frozen scientific control specimen). Its identity — git tree
  `a603014e034f1cc5dcc9b0e0d93f9fa8bc0dcbd8`, jj change `olnnyuutzxsr`,
  bookmarks `main`/`main@origin` — is pinned in `CONTROL.md` and
  `control-baseline.json` and is **never rewritten and never re-measured**.
- At that specimen `./verify` (`nix develop --command bazel test //...
  --config=buildbuddy-rbe`) passes **30/30** targets, exit `0`.
- Every candidate (A, B, C, D) is compared against this specimen with the
  identical instrument of §10.
- The frozen Atlas signature of the control specimen is `D50 = 4`,
  depth-7 reach `= 0.6636` (provenance
  `experiments/atlas-work-topology/round4/round4.oracle.json`, candidate
  column). It is a bound precondition (§7, O3) and is never retuned.
- Continuity caveat, stated once: the previous experiment's committed control
  evidence under `experiments/atlas-work-topology/control/` is pinned at
  revision `eca979f5`, an ancestor of this control specimen, and is **not** the
  mission's control. Its numbers (region hotspots 17, `cell_cut_4` 0.6604) are
  carried only as scoping priors (§9), never as the mission's measurement.

## 2. Admission and the three frozen partitions

### 2.1 Admission (`attuneflix-admission-v1`)

A tracked path is admitted iff it ends in one of the frozen source extensions
(`.flix .java .js .mjs .cjs .jsx .ts .mts .cts .tsx .bzl .bazel .star`) or is a
Bazel build file (`BUILD`, `BUILD.bazel`, `WORKSPACE`, `WORKSPACE.bazel` at any
depth), **excluding** the frozen data tree `.attune/**`. A pure function of the
path, applied identically to control and to every candidate.

### 2.2 Region partition (`attuneflix-regions-v1`) — the semantic partition

The same ten names and the same per-path first-match rules as the established
work-topology instrument; the residual bucket is `other`, reported never
dropped.

| # | region | rule |
|---|---|---|
| 1 | `repository` | `src/Repository.flix` or prefix `src/Repository/` |
| 2 | `radii` | `src/Radii.flix` or prefix `src/Radii/` |
| 3 | `atlas` | `src/Atlas.flix` or prefix `src/Atlas/` |
| 4 | `localization` | `src/Localization.flix` or prefix `src/Localization/` |
| 5 | `tables` | `src/ScientificTable.flix` or prefix `src/ScientificTable/` |
| 6 | `population` | `src/Population.flix` or prefix `src/Population/` |
| 7 | `src-root` | prefix `src/` |
| 8 | `tests` | prefix `test/` |
| 9 | `build-src` | prefix `build/src/` |
| 10 | `experiments` | prefix `experiments/` |
| - | `other` | every admitted path matching no rule above |

### 2.3 Stage partition (`attuneflix-stages-v1`) — the writable ownership units

A second, independent path function: a *stage* is a writable unit of the
pipeline, a *region* is a semantic subsystem. Reported separately, never
conflated. First matching rule wins:

| stage | rule |
|---|---|
| `kernel` | `src/ScientificIdentity.flix`, `src/ScientificTable.flix`, `src/ScientificTable/**`, `src/Kernel/**`, `src/native/identity/**`, `src/native/parquet/**` |
| `world` | `src/Repository.flix`, prefix `src/Repository/` except `src/Repository/Physical.flix`; `src/grit/**`; `src/native/grit/**`; `test/World/**` |
| `engine` | `src/Repository/Physical.flix`; `src/Radii.flix`, prefix `src/Radii/`; `src/Atlas.flix`, prefix `src/Atlas/`; `test/Engine/**` |
| `applications` | `src/Localization.flix`, prefix `src/Localization/`; `src/Population.flix`, prefix `src/Population/`; `src/native/inference/**`; `test/Applications/**` |
| `research` | `src/Experiment.flix`; prefix `experiments/` |
| `law` | prefix `test/` (not already matched), prefix `build/`, `data/`, repository-root `BUILD.bazel`/`MODULE.bazel` |
| `other` | every admitted path matching nothing above (reported residual) |

The stage partition is the pre-image of the mission's six typed stages
(`Acquire → World → Prior ‖ Atlas → CandidateSet → Judge → Projection`) plus the
stable kernel; at the control specimen the stage DAG does not yet exist, so
files are grouped by their prospective stage.

### 2.4 The kernel boundary

The **Stable Kernel** is `src/Kernel/**`. It is the leaf-level, pure,
zero-dependency contract the mission extracts (nominal IDs, Datalog relation
types, the six-atom Atlas grammar, scientific schema values, stage ADTs,
algebraic effect declarations). At the control specimen `src/Kernel/**` is
**empty** (the kernel does not exist yet); a candidate that declares it removes
those files from every task's dependency closure (§5) and from the mutable
cross-stage edge set (§3).

## 3. BASIS channel — the writable implementation graph

The BASIS graph is the **tracked `.flix` module-reference graph**, computed as a
pure function of source text (never inferred from BUILD files):

- A source `g` declares a module `M(g)` = its first `mod`/`pub mod` declaration.
  `g` is the *implementation of* a module only by that declaration.
- An edge `f → g` exists when `M(g)` (or a longer declared module path that
  resolves to `g`) appears as a qualified reference `<M>.` in `f`'s text, and
  `g ≠ f`. Resolution takes the **longest declared module prefix**; a law or
  instrument file that declares a production module name (`test/Repository.flix`
  declares `mod Repository`) never shadows the production module.
- All tracked `.flix` files participate. Production edges are those with both
  endpoints under `src/`.

Frozen formulas:

1. **`admitted_files`, `flix_files`, `production_flix_files`,
   `production_flix_loc`** — sizes of the admitted set and the production
   surface.
2. **`total_reference_edges`**, **`production_reference_edges`** — the BASIS
   graph sizes.
3. **`k_way_cut(k)`, `k = 2..K`** — the cross-group edge **count** and
   **fraction** (`count / total_reference_edges`) under the frozen greedy
   agglomerative merge over the **region partition** (§2.2): start from the
   non-empty regions as singleton groups sorted by name; repeatedly merge the
   pair `(A, B)` maximizing the bidirectional edge count between the groups,
   ties broken by the lexicographically smallest group pair, the merged group
   keeping the smaller name; stop at `k` groups; count edges whose endpoints
   fall in different groups. `K` = number of non-empty region groups. The
   **primary cut quantity** is `k_way_cut(K)` — the cut at the finest frozen
   region partition. The full trajectory `k = 2..K` is reported, never a single
   point.
4. **`mutable_cross_stage_edges`, `mutable_cross_stage_fraction`** — the count
   and fraction of **production** reference edges `(f, g)`, `stage(f) ≠
   stage(g)`, over `production_reference_edges`. This is the mutable
   implementation coupling the mission's stages must remove. It is the primary
   decoupling quantity.
5. **`shared_writable_hotspots`, `max_hotspot_pressure`** — over the **region**
   partition: the count of admitted files `g` with `importing_regions(g) ≥ 2`
   and the maximum, where `importing_regions(g) = |{region(f) : (f, g) ∈ edges,
   region(f) ≠ region(g)}|`. This is the mission's `shared hotspots` quantity
   (the control value corresponds to the previous instrument's 15-17, §9).
   `shared_writable_hotspots` on the **stage** partition is reported alongside,
   labelled, and never substituted for the region count.
6. **`region_coherence`** `c(R) = internal(R) / (internal(R) + outgoing(R))` per
   non-empty region, minimum reported.

## 4. BUILD channel — cross-stage test invalidation

A read-only `bazel query` of the revision's declared BUILD graph (never inferred
from source text):

- `analyzed_targets` = `bazel query //...` count.
- `test_targets` = `bazel query 'kind(".*_test", //...)` count.
- For each admitted file `f`: `declaring` = targets declaring `basename(f)` in
  `srcs`; `tests(f)` = `kind(".*_test", rdeps(//..., set(declaring)))`.
- **`cross_stage_test_invalidation`** = `Σ_f |{ t ∈ tests(f) : stage(t) ≠
  stage(f), t not under //experiments/ }|`. This is the re-run cost a concurrent
  worker in another stage pays when `f` changes. `stage(t)` maps a test label to
  its stage by package. The all-tests variant (including the experiment's own
  instrument targets) is reported alongside as
  `cross_stage_test_invalidation_all_tests`; the instrument-excluded variant is
  the primary quantity, so the instrument never inflates its own result.

## 5. WORK channel — critical-path fraction `T∞ / T1`

The frozen four-task representative engineering bundle (the pre-image of
`BENCHMARK_TASKS.md`, milestone 5):

| task | declared seed files |
|---|---|
| `acquisition` | `src/Repository/Grit.flix`, `src/Repository/Acquire.flix` |
| `atlas_bitset` | `src/Repository/Physical.flix`, `src/Radii/Evaluate.flix` |
| `judge_pareto` | `src/Localization/Sandwich.flix`, `src/Localization/PriorTable.flix` |
| `projection_jsonld` | `src/Localization/PredictionTable.flix`, `src/Population/Table.flix` |

Frozen formulas:

1. **Change surface `S(t)`** = the forward reference closure of `t`'s seed files
   in the BASIS graph, minus the immutable kernel boundary (§2.4). Rationale: a
   task stands on the implementation it transitively reaches; where that
   implementation is shared mutable code, the task is not independent. The
   kernel is excluded because read-only code cannot be a write conflict.
2. **Conflict graph** = an undirected edge `(t1, t2)` iff `S(t1) ∩ S(t2) ≠ ∅`.
3. **`T1`** = number of tasks (all-in-series makespan, in unit task times).
4. **`T∞`** = the chromatic number of the conflict graph: the minimum number of
   conflict-free parallel rounds with unit task times, computed exactly by
   brute force over colourings (`4^4` worst case).
5. **`critical_path_fraction`** = `T∞ / T1`. Parallel-to-change means small
   `T∞ / T1`. At a fully decoupled (pairwise-disjoint surface) architecture the
   fraction reaches `1/4`; at the control coupling it is `3/4` (§9).

## 6. Kernel size tax

1. **`kernel_loc_fraction`** = tracked kernel raw LOC / tracked production raw
   LOC. The kernel is deliberately frozen and read-only; its size is a tax paid
   once, so the metric is recorded and bounded, not blindly minimized.
2. **`kernel_fanin_share`** = reference edges into kernel files / total edges.
   A pure leaf kernel with high fan-in is the intended shape; the number proves
   the kernel is the shared thing, and that it is leaf-level.
3. `kernel_files`, `kernel_loc`, `kernel_fanin` — the raw counts.

## 7. Candidate acceptance / rejection oracle

Every candidate architecture change is measured with the identical instrument
and evaluated against **all** of:

- **O1 Grammar invariance.** Exactly the six directed Atlas atoms
  (`Defines, DefinedIn, Imports, ImportedBy, Calls, Callers`), composition only,
  depth ≤ 7, the 3,279 cumulative routes, route/state identities unchanged. Any
  change is a rejection.
- **O2 Mixing landmarks.** `|D_p(candidate) − D_p(control)| ≤ 1` for
  `p ∈ {0.50, 0.80, 0.90}`, `none` encoded as `8`; a control `none` met by a
  candidate value (or the reverse) fails.
- **O3 Depth-7 reach.** `mean_coverage(7)` may not fall by more than `0.05`
  (the control value is `0.6636`).
- **O4 Extinction and recurrence.** No route non-empty in control (normalized by
  logical identity) may be empty in the candidate; no depth may lose more than
  `0.10` survival fraction; no new bulk-extinction regime.
- **O5 Parity and the full gate.** `//test/Engine:core_parity_test` passes
  (`Repository.Reference` vs `Repository.Physical` exact parity) and
  `./verify` exits `0` with 100% of targets passing.
- **O6 Logical identity continuity.** Every control logical identity maps to
  exactly one current path; no identity silently created, dropped or merged by
  a move.
- **O7 Law and LOC hygiene.** Tracked `.flix` LOC (`src/` + `test/`) stays
  **< 4,800** raw lines with **zero files over 400** raw lines. Measurement
  code lives under `experiments/effectful-stage-architecture/`.
- **O8 Legibility and non-duplication.** No duplicated semantic implementation,
  no microservices, no network serialization of internal functions, no
  `FooService`/`FooProvider` ceremony; ordinary typed Flix modules and ordinary
  Bazel rules.
- **O9 Evidence determinism.** Typed Parquet round-trips are exact and the
  instrument of §10 is a deterministic function of the tree; every comparison is
  between the same measured artifacts.

**Rejection rule.** A candidate failing O1-O6 or O9 is **rejected and reverted**,
never retained with a weakened oracle, and the oracle is never re-tuned to admit
it. O7 and O8 are blocking but repairable within the same round.

**Non-rule.** A candidate that passes O1-O9 but does not improve (or worsens)
the §9 primary quantities is **not** rejected: it is recorded with its measured
deltas as a negative result and not adopted.

## 8. Hill-climb procedure and candidate budget

Four candidate generations against the frozen oracle, one coherent `jj` change
per unit of work, ending each with `jj new`:

- **Candidate A — Contract Kernel Extraction.** Extract the zero-dependency
  Stable Kernel (`src/Kernel/Contract.flix`): nominal IDs, pure relation types,
  Atlas grammar, scientific schema/value, stage ADTs. *Hypothesis:* the kernel
  files move out of every task's mutable surface, so `mutable_cross_stage_edges`
  and `shared_writable_hotspots` fall and `kernel_loc_fraction` becomes the
  explicit, bounded tax.
- **Candidate B — Capability Effects & Handlers.** Declare `eff Digest`,
  `eff SourceRead`, `eff Grit`, `eff ArtifactStore`, `eff Embedding`,
  `eff JudgeModel`; implement `Kernel.Handler.runProduction` (FFI) and
  `runReplay` (in-memory). *Hypothesis:* ambient `\ IO` leaves the domain
  modules, narrowing the World↔IO crossing to one handler seam and shrinking the
  World stage's cross-stage edges.
- **Candidate C — Schema/Transport split, World decomposition, six-stage DAG.**
  Split pure `Scientific.Schema`/`Value` from Parquet transport; decompose
  `src/Repository.flix` (410 raw lines, the standing >400 flag) into
  `World.Admission` and `World.Language.*` (each < 200 lines); implement the six
  typed stages. *Hypothesis:* the two highest-pressure shared files
  (`src/ScientificTable*.flix`, `src/Repository*.flix`) stop being shared mutable
  hotspots; region hotspots fall from the control value toward the target.
- **Candidate D — Bazel staged targets.** Mirror the stage DAG in Bazel packages
  (`//src/kernel:*`, `//src/stage/*`, `//src/transport/*`) with fine-grained
  test locality. *Hypothesis:* `cross_stage_test_invalidation` falls by ≥ 50%
  relative to control, because a stage-local change invalidates only downstream
  dependents.

Per candidate step: (1) propose a described `jj` change; (2) measure with the
identical instrument; (3) evaluate O1-O9 and the primary quantities; (4) adopt
only if O1-O9 pass, else revert and record the rejection; (5) record a delta row
(adopted *and* rejected); (6) run the affected Bazel targets batched into **one**
invocation, then `./verify`; (7) stop the generation when its budget is
exhausted: at most **8** candidate steps evaluated and at most **4** adopted per
generation.

No metric, partition, protocol or oracle is redefined between generations. The
hill-climb never re-acquires facts, never re-runs the frozen census, never
touches `.attune/**`, and never calls a model or provider.

## 9. Measured control baseline and success thresholds

Measured at the control specimen by the instrument of §10 and frozen in
`baseline-metrics.json` (protocol `attuneflix-effectful-stage-baseline-v1`).
These are the mission's own control numbers, not the prior experiment's.

### 9.1 BASIS

| quantity | control |
|---|---|
| admitted files | 113 |
| tracked `.flix` files | 68 |
| production `.flix` files / LOC | 25 / 3479 |
| total reference edges | 276 |
| production reference edges | 49 |
| region groups (`K`) | 9 |
| `k_way_cut(9)` (primary, finest region cut) | 197 / **0.7138** |
| `k_way_cut(8)` | 155 / 0.5616 |
| `k_way_cut(6)` | 97 / 0.3514 |
| `k_way_cut(4)` | 45 / 0.1630 |
| `k_way_cut(2)` | 8 / 0.0290 |
| `mutable_cross_stage_edges` | 30 / **0.6122** |
| `shared_writable_hotspots` (region) | **16**, max pressure 6 |
| stage-partition hotspots | 6, max pressure 3 |

The full cut trajectory (`k = 2..9`): `0.0290, 0.0942, 0.1630, 0.2572, 0.3514,
0.4420, 0.5616, 0.7138`.

### 9.2 BUILD

| quantity | control |
|---|---|
| analyzed targets | 492 |
| independently runnable test targets | 30 |
| `cross_stage_test_invalidation` (primary) | **59** |
| `cross_stage_test_invalidation_all_tests` | 260 |

`analyzed_targets` counts the whole `//...` universe at the measured working
tree, including this experiment's own `measure_baseline` target; the primary
`cross_stage_test_invalidation` = 59 depends only on `src/` and `test/`
dependencies and is invariant to the experiment's own BUILD additions.

### 9.3 Kernel size tax, WORK, LOC law

| quantity | control |
|---|---|
| `kernel_files` / `kernel_loc` | 3 / 260 |
| `kernel_loc_fraction` | 0.0747 |
| `kernel_fanin` / `kernel_fanin_share` | 42 / 0.1522 |
| `T1` / `T∞` / `critical_path_fraction` | 4 / 3 / **0.7500** |
| task conflict graph | acquisition–atlas, acquisition–judge, atlas–judge, judge–projection |
| `src/` + `test/` `.flix` LOC | 4369 (law: < 4800) |
| largest file | `src/Repository.flix` = 410 (over-400 flag) |

### 9.4 Success thresholds (preregistered)

| level | criterion |
|---|---|
| **Minimum serious success** | O1-O9 hold **and** `mutable_cross_stage_edges` reduced by ≥ 50% (30 → ≤ 15) **and** `cross_stage_test_invalidation` ≤ 18 |
| **Strong success** | all of the above **and** `shared_writable_hotspots` ≤ 6 (16 → ≤ 6) **and** `k_way_cut(9)` ≤ 0.35 |
| **Stretch goal** | all of the above **and** `critical_path_fraction` ≤ 0.50 (T∞ ≤ 2) **and** `kernel_loc_fraction` ≤ 0.15 |

Concurrency targets (measured in milestone 5, VAL-BENCH-003): ≥ **1.5×** speedup
at 2 workers and ≥ **2.0×** at 4 workers on the frozen bundle.

Positive but sub-threshold results are reported with their measured deltas; a
threshold is never reported as met without the frozen artifact that shows it.

## 10. Instrument of record, provenance and determinism

- **Command of record** (bootstrap):
  `nix develop --command bazel run //experiments/effectful-stage-architecture:measure_baseline`,
  which writes `baseline-metrics.json` into the package. With
  `ATTUNE_SKIP_BUILD=1` it runs the BASIS and WORK channels only.
- The instrument is a **pure function of the tracked tree and the declared BUILD
  graph**: no network, no clock-derived value inside a metric, no ambient input.
  The only non-derivable field is the record's `recorded_at_utc` timestamp,
  which is metadata and not a measured quantity. The generator commit and the
  fixed `control_commit` are both recorded.
- **Provenance.** The metric definitions bind the real `src/` production graph
  and the real Bazel graph. A provenance check must fail if the production
  module set or a declared BUILD target changes and the measured metrics do not
  (they are recomputed from the tree on every run; there is no cached constant).
- **Three channels are never conflated**: a BASIS number is never presented as
  an Atlas signature, and a BUILD number is never presented as a semantic
  measurement.

## 11. Stopping rules

**Hard stops (the step is reverted and the mission reports):**

- **S1** Any step requires re-acquiring facts, embeddings or Jev decisions, or
  any provider/model call.
- **S2** Any step modifies, regenerates or hand-edits frozen evidence
  (`.attune/**`, census parquet, historical experiment outputs), or weakens
  `Repository.Reference`/`Repository.Physical` parity.
- **S3** Any step alters the six atoms, the composition-only grammar, the
  depth-7 bound, or the meaning of any frozen scientific identity.
- **S4** `./verify` cannot be made green inside the generation (revert; if the
  failure predates the generation, stop and report it rather than masking it).
- **S5** The tracked-Flix LOC gate would be exceeded by the step and cannot be
  repaired inside the generation.

**Soft stops (finish the current measurement, then report):**

- **S6** The generation budget (4 generations, §8) is exhausted.
- **S7** Two consecutive generations adopt no step improving a primary quantity
  (all candidates rejected or neutral): the hill-climb has stalled.
- **S8** Every §9.4 threshold is met: stop early and report the achieved result.
- **S9** No admissible candidate remains (every remaining proposal would violate
  the oracle): record the reason and stop.
- **S10** Two consecutive candidates show `D50/D80/D90` drift of exactly 1 or a
  depth-7 reach drop between `0.03` and `0.05`: stop before the oracle margin is
  consumed.

Stopping never cancels the deliverable: `REPORT.md` is written with the measured
curves, the §12 outcome classification, and an explicit statement of which
stopping rule fired.

## 12. Outcome classification

Decided **only** from the frozen measurements:

- **Outcome A — strong success.** O1-O9 hold at the final adopted state and the
  §9.4 strong criteria are met.
- **Outcome B — serious success.** O1-O9 hold and the minimum criteria are met.
- **Outcome C — inconclusive or trade-off.** Minimum criteria not met, or any
  oracle/law concession was required at any point, or the run stopped through
  S4/S5/S7 without reaching the minimum.

The semantic and signature preservation (O1-O6) is a **precondition** of A and
B, never a bargain chip: if the only way found to reduce the cut requires moving
the meaning or the signature, the outcome is C and the finding is that in this
repository semantic connectivity and parallel changeability are in tension.
Every outcome, including C, is reported with the measured evidence.

## 13. Artifacts, targets and the Flix/Starlark migration of the instrument

```text
experiments/effectful-stage-architecture/
  PREREGISTRATION.md        this file
  CONTROL.md                frozen control specimen record (VAL-CTRL-001)
  control-baseline.json     machine-readable control specimen identity + verify
  baseline-metrics.json     machine-readable control metrics (VAL-CTRL-002)
  BUILD.bazel               Starlark: filegroup + the `measure_baseline` target
  scripts/
    measure_baseline_metrics.sh   bootstrap instrument of record (§10)
```

**Migration commitment.** This repository does not prefer bash. The bootstrap
script is temporary `bazel run` plumbing, in the same spirit as
`experiments/atlas-work-topology/scripts/measure_bazel_locality.sh`, and only
because the BUILD channel (cross-stage test invalidation, §4) is inherently a
`bazel query`. The BASIS, kernel-tax and WORK graph math (§3, §5, §6) is
scheduled to move into a deterministic **Flix** analysis target backed by
**Starlark** BUILD wiring — the repository norm, where Starlark passes declared
artifact paths and Flix produces every reported number — in mission milestone 4
(`//experiments/effectful-stage-architecture:measure_candidates`). No new bash
instrument is added beyond this bootstrap.

## 14. What this experiment never does

- Never modifies, regenerates or hand-edits `.attune/**`, the frozen census
  parquet, another experiment's `REPORT.md`, or retained provider evidence.
- Never invokes OpenRouter or any provider, never re-acquires embeddings or Jev
  decisions. Replay stays keyless and local.
- Never runs `bazel clean`, never deletes local or remote caches, never touches
  the `bazel-*` symlinks, never runs two Bazel processes at once.
- Never rewrites history at or below `main@09e27244af9340aa616116a93ea02472e7521ba5`,
  never pushes without explicit authorization.
- Never exposes evaluator gold to Localization and never lets Atlas depend on
  issues, inference or gold.
- Never presents a BASIS or BUILD number as an Atlas signature.
- Never reports a threshold as met without the frozen artifact that shows it.

## 15. Ordering guarantee

The experiment history is ordered: (1) the milestone-1 control record
(`CONTROL.md`, `control-baseline.json`), (2) this preregistration, (3) the
control metric capture (`baseline-metrics.json`), (4) Candidates A-D with
per-candidate oracle evaluation, (5) `BENCHMARK_TASKS.md` and the concurrency
benchmark, (6) `REPORT.md` and the final gate. No architecture edit may exist
before this file's change, and every candidate measurement follows it.
`nix develop --command jj log` proves the ordering: this file's parents are the
control record and the frozen control specimen, and no change under
`experiments/effectful-stage-architecture/` that measures a candidate predates
it.

## 16. Amendment — supplementary stage-partition path re-key (2026-09-26, pre-measurement, Candidate D)

Appended before the Candidate D measurement, per the §0 amendment rule, and not
a metric-formula, admission-rule, oracle, or region-partition change. It adds a
supplementary, clearly-labelled reading of the frozen stage partition defined in
§2.3 and does not replace the metric of record.

**What the frozen §2.3 table fixes.** §2.3 defines the stage partition as *"a
second, independent path function: a stage is a writable unit of the pipeline"*
and states the partition *"is the pre-image of the mission's six typed stages
plus the stable kernel"*. The path rules printed in §2.3 are the instantiation
of that definition for the **control specimen's** path set.

**Why the instantiation had to follow the DAG.** M2 and M3 built the mission's
own stage units at new paths — `src/Kernel.flix` (the kernel root anchor),
`src/Scientific*` (the pure schema the kernel owns, renamed from
`src/ScientificTable*`), `src/World/*` (the §8 "decompose Repository.flix into
World.Admission, World.Language.*" unit), and `src/Stage/*` (the six typed stage
modules). None of those paths matched a §2.3 rule, so the implementation
classified every one of them as the residual bucket `other`. That is not a
measurement of the DAG: it attributes exactly the mission's writable stage units
to the bucket that means "matches no stage". The same stale-instantiation defect
was already recorded for the *region* partition at Candidate C (`tables` region
emptied by the `ScientificTable*` -> `Scientific*` rename, K 9 -> 8).

**The amendment (supplementary reading, not a substitution).** The frozen
§2.3 rules remain the *metric of record*: `mutable_cross_stage_edges` and
`cross_stage_test_invalidation` are computed exactly as §3.4 and §4 state, so
every candidate stays directly comparable to `baseline-metrics.json`. The
instrument additionally reports a *supplementary* pair of readings
(`mutable_cross_stage_edges_dagref`,
`cross_stage_test_invalidation_dagref`) under a second path function
(`stage_of_dagref`, protocol name `attuneflix-stages-v1/dagref`) that names the
paths the mission's stages live at, preserving each stage's identity:

| stage | added rule |
|---|---|
| `kernel` | `src/Kernel.flix` (the kernel root anchor, alongside `src/Kernel/**`); `src/Scientific.flix`, `src/Scientific/**` (the pure schema, renamed from `ScientificTable*`) |
| `world` | `src/World.flix`, `src/World/**` (the decomposed Repository); `src/Stage/Acquire.flix`, `src/Stage/World.flix` (DAG nodes 1-2) |
| `engine` | `src/Stage/Prior.flix`, `src/Stage/Atlas.flix` (DAG nodes 3A/3B) |
| `applications` | `src/Stage/CandidateSet.flix`, `src/Stage/Judge.flix`, `src/Stage/Projection.flix`, `src/Stage/Pipeline.flix` (DAG nodes 4-6 and the composed pipeline) |
| `other` | `src/Stage.flix` (the DAG's zero-content namespace anchor, which is no stage unit; reported residual) |

No formula, admission rule, region partition, oracle, or test-stage rule
changes; the supplementary reading differs only in which files a stage owns.

**Control-neutrality (the check that it is a re-key, not a retune).** No control
path matches a rule added here: at `09e27244` there is no `src/Kernel.flix`, no
`src/Scientific.flix`, no `src/World/**`, and no `src/Stage/**`
(`src/ScientificTable*` is already `kernel` under the original rules). The
frozen control reading is therefore **identical under both keyings: 59
tests / 30 edges** (`baseline-metrics.json` is never re-measured). The re-key
therefore changes the classification of M2/M3-created paths only, and the
control-relative comparison the §9.4 thresholds use is unchanged whichever
keying is read.

**Why it is reported.** It separates two explanations of a candidate's BUILD
reading, which the frozen metric alone cannot: "the architecture coupled more"
from "the frozen path function does not recognize the architecture's own stage
units". Candidate D is the first revision whose stage units live at DAG paths,
so this is where the ambiguity first arises. The frozen reading stays primary
and is the one the §9.4 comparison and §12 outcome use.
