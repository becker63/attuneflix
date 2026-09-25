# Self-Signature Parallelism Experiment — Report

Preregistered in `PREREGISTRATION.md` (committed first: jj `xkoxvypo` /
git `396d7a64`), then instrumented and measured. This report follows the
spec's nine-point outline, gives the compact before/after table, documents
the post-measurement hill-climb passes the steering directed, and records
the enshrinement decision.

## Revisions

| role | revision |
|---|---|
| preregistration | jj `xkoxvypo` / git `396d7a64` (amended once, pre-measurement, clearly labeled: round-3 budget ruling ~450 lines, gate < 4,800) |
| baseline | git `bcfc126db7b7c7f535353ccc8afca44465903571` (recovered from VCS history, evaluated in isolated worktree `/tmp/attuneflix-baseline`) |
| cleaned (after) | git `ae2f5e68711121f8ecbf9ce94a7926ca7c7833d1` (the sealed instrument change; artifacts add no `.flix` files) |

## Before/after table (preregistered metrics M1–M10)

All values from the committed typed-Parquet facts admitted in-graph by
`experiments/atlas-parallelism/Parallelism.flix`; reproduced by
`bazel build //experiments/atlas-parallelism:compare --config=buildbuddy-rbe`
(output: `compare.txt`). Metric definitions are identical across revisions.

| metric | baseline `bcfc126` | cleaned `ae2f5e68` |
|---|---|---|
| tracked_files | 41 | 42 |
| use_edges | 123 | 141 |
| cross_region_edge_ratio | 0.813 | 0.816 |
| median_file_blast | 24 | 28 |
| p90_file_blast | 36 | 37 |
| max_region_blast | 23 | 23 |
| max_pair_jaccard | 0.974 | 1.000 |
| high_overlap_pairs (of 45) | 37 | 42 |
| shared_hotspots | 14 | 15 |
| max_hotspot_pressure | 6 | 6 |
| independently_testable | 3 | 3 |
| min_region_coherence | 0.000 | 0.000 |
| cross_group_edges_4 | 18 | 22 |
| cross_group_edges_8 | 70 | 84 |

Per-region coherence (internal / outgoing use edges):

| region | baseline | cleaned |
|---|---|---|
| repository | 0.714 (10/4) | 0.667 (10/5) |
| tables | 1.000 (0/0) | 1.000 (1/0) |
| population | 0.500 (1/1) | 0.333 (1/2) |
| radii | 0.400 (2/3) | 0.400 (2/3) |
| localization | 0.385 (5/8) | 0.267 (4/11) |
| atlas | 0.294 (5/12) | 0.278 (5/13) |
| build-src (test entries) | 0.000 (0/36) | 0.061 (2/31) |
| tests | 0.000 (0/6) | 0.000 (0/7) |
| experiments | 0.000 (0/30) | 0.023 (1/43) |

The max_pair_jaccard attainment in the cleaned revision is the
`atlas + repository` pair: both regions' depth-2 signature neighborhoods
span essentially the entire file set (the pipeline root and the pipeline
middle both reach everything within two hops). Printed as the
`argmax_pair` diagnostic line in `compare.txt` (not a preregistered
metric).

## Hill-climb passes (post-measurement, steering-directed)

The steering directed aggressive hill-climbing after the first measurement,
with reorganization in scope and feature parity required. The ruler was
never touched: metric definitions stayed frozen; the repo was the only
thing allowed to move.

**Pass 1 — delete the `build/src/Repository.flix` shim (refuted, reverted).**
The 1-line `mod Repository {}` shim looked dead (no fan-in, no outgoing
edges besides a self-region anchor). Deleting it failed the build:
`//test:core_parity_check` declares it among its `srcs` (label form
`//build:src/Repository.flix`) because Flix 0.76 requires the parent module
declared when a reduced srcs set compiles `Repository/Structure.flix`
without the full `src/Repository.flix`. The shim is a load-bearing 1-line
build-graph anchor, not waste. Reverted; recorded as a finding.

**Pass 2 — cross-region coupling audit of `src/` (no incidental edges found).**
Every remaining cross-region use edge in `src/` is essential pipeline
coupling required by the science: `Radii/Evaluate` reads repository physical
relations; `Atlas` evaluates radii programs over repository worlds;
`Atlas/Signature/*` and the localization/population tables write through
`ScientificTable` codecs; `Localization/Sandwich` consumes atlas programs.
Removing any of these edges would mean duplicating shared types or codecs —
re-creating the duplication the cleanup removed — a maintainability
regression that also grows LOC against the gate.

**Pass 3 — hub-shape review (deliberate trade, kept).** The measured hub
formation (`ScientificTable/Columns.flix` consolidation, shared
`TestWorlds` fixture, single-owner folds) raises fan-in but is the
deliberate outcome of the mission's single-owner deduplication: many readers
of one stable, frozen contract coordinate through the contract rather than
through each other. Re-splitting or re-duplicating the hubs would improve
the measured overlap numbers while making the codebase objectively worse to
work on. Kept.

**Frontier conclusion.** The cleanup moved the repository toward the
single-owner, shared-core corner of the (duplication ↔ fan-in) trade-off.
The preregistered ten-region partition slices the repository by component,
but the dependency topology is a pipeline (repository → radii → atlas →
tables → localization/population) with a test/experiment periphery reaching
into the core. A pipeline sliced vertically has inherently low within-region
coherence, and tests of core modules can never be region-independent. The
measured numbers are the honest price of single ownership on a compact
scientific kernel; no further hill-climb exists that does not regress
maintainability or redefine the ruler.

## Enshrinement decision (VAL-PARA-007)

**The property does not hold. No oracle is enshrined.** All five
preregistered enshrinement conditions (PREREGISTRATION.md E1–E5) fail on
the cleaned revision:

- E1 (pronounced region coherence): fails — min region coherence 0.000;
  only `repository` and `tables` are coherent.
- E2 (bounded cross-region neighborhood overlap): fails — 42 of 45 region
  pairs have jaccard ≥ 0.5; the max is 1.000.
- E3 (bounded shared hotspot pressure): fails to bind meaningfully — 15
  shared hotspots; fan-in grew with the consolidation wins.
- E4 (independently testable regions): fails — 3 of 10, unchanged from
  baseline; test-side regions are definitionally dependent on core.
- E5 (Bazel locality): the shard fan-out works (10 independent per-region
  actions per revision on RBE), but the locality metric itself does not
  support a pronounced threshold.

Per the binding rule — "if the measurements do not support the property,
do NOT enshrine a permanently-failing test — return to orchestrator with
the numbers" — the `oracle` command stays as an instrument capability
(`experiments/atlas-parallelism/Parallelism.flix`, thresholds via
`attune.threshold.*` properties), is wired as a runnable Bazel action, but
is **not** added to the authoritative suite, because it would be a
permanently red test.

**Proposed threshold analysis for a future state.** If a future cleanup
wants the oracle, the repo shape has to change first, and the numbers say
what shape that is: (a) make the test periphery own its fixtures
region-locally (E4, coherence of `build-src`/`tests`), (b) break the
`Columns`/`TestWorlds` fan-in either by interface narrowing that does not
duplicate codecs, or (c) re-derive regions along pipeline stages rather
than components — which requires a preregistered partition amendment, since
the current partition is frozen. Thresholds would then be set from that
after-state with explicit margins per the enshrinement rule; the instrument
and its shard-parallel wiring are already in place and budgeted.

## The nine points

1. **Why parallel agent development is an architectural concern.** Multiple
   agents editing one repository conflict when they touch the same files or
   depend on the same unstable definitions. The probability of such
   conflicts is a structural property of the file/module graph — it can be
   measured, and therefore designed against, before any agent runs.
2. **Why this is not an argument for microservices.** The alternative to a
   coordination surface is not many repositories. A single repository with
   narrow typed boundaries keeps atomic cross-boundary changes possible,
   keeps one build graph, and keeps semantic ownership explicit; splitting
   by service trades coordination for distributed-systems overhead this
   codebase does not need.
3. **The parallelizable monolith notion.** One repository; clear semantic
   ownership (each module has one reason to change); narrow typed/effect
   boundaries (here: Flix's pure/IO effect separation, typed Parquet
   schemas); local tests; low coordination surface (what this experiment
   measures).
4. **How Atlas repository signatures expose the structural properties.**
   The instrument admits the tracked file/module/use graph as a repository
   world (typed Parquet, frozen-facts pattern), seeds each region as a
   File-set state, and evaluates the canonical depth-2 Atlas signature
   family over it. The signature outputs — member unions, physical
   transitions — are the measured neighborhoods; the metric layer reads
   them through the same Atlas machinery the product uses.
5. **Before/after results from this cleanup.** The table above. The cleanup
   was a LOC/maintainability success (single owners, no duplication, ~4.3k
   lines); its coordination-surface effect is measurable and mixed: use
   edges +18 (of which ~10 are the instrument's own self-measurement
   edges), hub fan-in up (`ScientificTable` +`Columns` shared by all table
   writers; `TestWorlds` shared by the a/b world tests), median file blast
   24 → 28, coherence of core regions roughly unchanged, and the
   consolidation moved overlap up (37 → 42 high-overlap pairs).
6. **What the measurements do and do not establish.** They establish that
   the preregistered coordination-surface property, measured with frozen
   definitions on the preregistered partition, does not hold pronouncedly
   for either revision, and that the cleanup's deduplication direction
   trades fan-in for duplication at a quantified rate. They do not
   establish that the repository is bad for parallel work — the BuildBuddy
   shard fan-outs in this very experiment ran 18+ remote actions in
   parallel over the same graph — and they do not measure human or agent
   coordination outcomes, only the structural surface.
7. **Bazel/BuildBuddy complementarity.** Bazel externalizes the dependency
   DAG (this experiment's fact admission, ten per-region shards, and
   compare action are declared, cacheable, sandboxed nodes); BuildBuddy
   makes repeated deterministic work reusable across workers (shard and
   fatjar actions hit RBE caches across the mission's sessions). Neither
   substitutes for semantic modularity: they parallelize execution of the
   graph, not comprehension of it — which is exactly what the measured
   surface quantifies.
8. **How Factory makes the property operational.** The Factory orchestrator
   decomposes the mission into features sized to bounded regions; workers
   own their files exclusively; validators re-derive results
   independently. The observed session history (17/21 features completing
   in parallel worker sessions with named file-ownership collisions —
   see the Factory observations section) is the operating record the
   structural metrics are meant to predict.
9. **Future work connecting structural predictions to observed swarm
   behavior.** The open question: "Can repository signatures predict
   actual multi-agent coordination overhead?" Possible future evidence:
   Atlas structural signatures + Bazel dependency graphs + VCS co-change
   history + Factory worker conflict/reconciliation traces. No large
   historical study was performed in this mission.

## Factory observations (session record, kept separate from structural results)

These are orchestrator-provided observations about the Factory mission
session itself, not structural measurements, and are reported separately
for that reason: 17/21 features completed across ~20 worker sessions; two
features were re-scoped to verification-only; `reduction-completion`
returned once for a gate ruling and completed in two passes; seven user
steerings were absorbed mid-mission; one refutation (`build/src/Repository.flix`
anchor deletion) was re-derived independently in this feature's pass 1 and
confirmed; four milestone validators passed with zero blocking findings;
standing census evidence is byte-identical across four parquets. The per-file
ownership map and reconciliation events are recorded in the mission
orchestrator block.

## Artifacts

- Facts (per revision): `experiments/atlas-parallelism/extracted/{baseline,after}/{files,modules,uses}.txt`
  (attuneflix-self-admission-v1; extractor seam `extract_self_facts.sh`).
- Typed Parquet signature worlds (per revision):
  `bazel-bin/experiments/atlas-parallelism/{baseline,after}_world/{metadata,entities,relations}.parquet`
  (schemas `src/Repository/Table.flix`).
- Per-region shard rows (both revisions):
  `bazel-bin/experiments/atlas-parallelism/{baseline,after}_region_*/`
  (observation + physical + members schemas).
- Region-pairs tables (both revisions):
  `bazel-bin/experiments/atlas-parallelism/{baseline,after}_pairs.parquet`
  (schema `attuneflix-parallelism-pairs-v1`).
- The comparison table of record: `compare.txt` (regenerated by the
  `compare` action; deterministic).
- Instrument: `Parallelism.flix` + `Main.flix` (472 experiment Flix lines
  total, including the oracle command; honestly counted toward the gate —
  the round-3 ~450 budget was relaxed mid-session by explicit user
  steering, "relax with the loc constraints"; total tracked Flix 4,740 <
  4,800 gate).
