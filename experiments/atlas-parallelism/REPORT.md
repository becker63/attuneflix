# Self-Signature Parallelism Experiment — Report

Preregistered in `PREREGISTRATION.md` (committed first: jj `xkoxvypo` /
git `396d7a64`), then instrumented and measured. This report follows the
spec's nine-point outline, gives the compact before/after table, documents
the post-measurement hill-climb passes the steering directed, and records
the enshrinement decision.

**Scope (amended 2026-09-25, close-out).** The report now carries **two
measurement systems over the same two frozen revisions, with identical metric
definitions and the identical region partition**:

- **v1 — lexical/proxy.** The original `attuneflix-self-admission-v1` result: a
  deliberately reduced lexical world produced by the custom Flix
  module/dotted-token extractor (`extract_self_facts.sh`). It is **preserved
  exactly** here — the same numbers, the same artifacts, the same decision —
  and is labeled `v1` everywhere. Nothing about it was rewritten or
  retroactively altered.
- **v2 — authoritative.** Real Grit acquisition (the repository's one source
  frontend; five languages; one `Repository.Grit.Fact` protocol) over both
  frozen revisions, with the parallelism neighborhoods derived from **actual
  Atlas evaluation output states**.

The acquisition change was preregistered as a labeled amendment committed
**before** the first v2 measurement (`PREREGISTRATION.md`, "AMENDMENT — v2
acquisition"; jj `myxlmvsq` / git `e0154f2b`). The v1/v2 comparison is itself a
result, and it is reported below.

## Revisions

| role | revision |
|---|---|
| preregistration | jj `xkoxvypo` / git `396d7a64` (amended once, pre-measurement, clearly labeled: round-3 budget ruling ~450 lines, gate < 4,800) |
| preregistration amendment (v2, pre-measurement) | jj `myxlmvsq` / git `e0154f2b` ("amend the self-signature preregistration for v2 acquisition") |
| baseline | git `bcfc126db7b7c7f535353ccc8afca44465903571` (recovered from VCS history, evaluated in isolated worktree `/tmp/attuneflix-baseline`) |
| cleaned (after) | git `ae2f5e68711121f8ecbf9ce94a7926ca7c7833d1` (the sealed instrument change; artifacts add no `.flix` files) |

Both v1 and v2 measure the **same two revisions**: baseline
`bcfc126…` (mission start, `main` checkpoint) and cleaned `ae2f5e68…` (the
sealed v1 instrument change). The v2 experiment was not restarted from scratch;
only the acquisition system changed. The v2 acquisition ran over both revisions
materialized as isolated `git worktree`s (`/tmp/attuneflix-baseline`,
`/tmp/attuneflix-cleaned`); the live worktree was never reset or mutated.

## Four-row result: v1 lexical proxy vs v2 real Grit acquisition

### What v2 measures

For each revision, the **committed typed acquisition artifacts** under
`experiments/atlas-parallelism/v2/` carry the real Grit output
(`v2/README.md` documents the exact inclusions/exclusions, the exact
reproduction commands, and the fact-kind evidence): 72 / 75 admitted files
(`.flix`, Java, Starlark `.bzl` + `BUILD`/`BUILD.bazel`/`MODULE.bazel`),
5,293 / 5,124 emitted facts, 762 / 650 symbol definitions, 90 / 125 admitted
import edges, and **769 / 693 admitted symbol-level call edges** — where the v1
lexical proxy structurally had none. Emitted fact kinds: `definition`,
`import`, `dependency` (the one Starlark relation word), `call`. JS/TS: no
tracked `.js`/`.ts` exists at either revision (recorded, not hidden).

The measurement graph then re-admits those facts through ordinary
`Repository.admit` **inside the Bazel action graph** (`grit_facts` command;
`attune_parallelism_grit_revision`), and the neighborhoods come from
**`Atlas.evaluate` / the depth-2 File family** over the admitted world. There is
no handwritten traversal of Imports/Calls anywhere in the v2 metric path.

**Output-state normalization (explicit, as preregistered).** `Atlas.State` has
exactly two constructors, `Files` and `Symbols` (`src/Atlas.flix`), so there is
no location state and no location mapping in this revision — recorded rather
than silently omitted. File states normalize directly to their path. Symbol
states normalize to their canonical definition owner (`Symbol#path`, i.e. the
admitted `DefinedIn`/`Defines` relation: `DefinedIn(symbol, file) :- Defines(file,
symbol)` in `src/Repository/Structure.flix`) — the same projection
`Repository.Physical.definedIn` uses for the `DefinedIn` transition in
`Atlas.evaluate`. `members` in `Parallelism.flix` performs exactly these two
cases and nothing else.

Determinism: a fresh acquisition run over the same frozen worktree reproduces
both committed Parquet artifacts byte-identically (`cmp` on
`baseline.sources.parquet`, `baseline.facts.parquet`, `baseline.files.txt`).

### The four rows

Identical metric definitions and identical region partition for all four rows;
only the acquisition system and the revision differ. `class` labels the
quantity's origin: **count** = plain count, **basis** = direct admitted-relation
statistic, **atlas** = derived from actual Atlas output states. Reproduced by
`bazel build //experiments/atlas-parallelism:four_rows --config=buildbuddy-rbe`
(`four_rows.txt`, `four_rows.parquet`, `four_pairs.parquet`).

| metric | class | baseline v1 | cleaned v1 | baseline v2 | cleaned v2 |
|---|---|---|---|---|---|
| tracked_files | count | 41 | 42 | 72 | 75 |
| use_edges (M3) | basis | 123 | 141 | 90 | 125 |
| cross_region_edge_ratio (M4) | basis | 0.813 | 0.816 | 0.867 | 0.888 |
| median_file_blast (M5) | atlas | 24 | 28 | 18 | 28 |
| p90_file_blast (M5) | atlas | 36 | 37 | 38 | 42 |
| max_region_blast (M6) | atlas | 23 | 23 | 260.0 | 167.5 |
| max_pair_jaccard (M7) | atlas | 0.974 | 1.000 | 0.949 | 0.976 |
| high_overlap_pairs (M7, of 45) | atlas | 37 | 42 | 45 | 45 |
| shared_hotspots (M8) | basis | 14 | 15 | 14 | 16 |
| max_hotspot_pressure (M8) | basis | 6 | 6 | 7 | 7 |
| independently_testable (M9) | basis | 3 | 3 | 3 | 4 |
| min_region_coherence (E1) | basis | 0.000 | 0.000 | 0.000 | 0.000 |
| cross_group_edges_4 (M10) | basis | 18 | 22 | 26 | 31 |
| cross_group_edges_8 (M10) | basis | 70 | 84 | 58 | 88 |

M2 `tracked_flix_loc` is counted outside the instrument (verbatim LOC command):
5,297 at the baseline revision, 4,740 at the cleaned revision. The v1 columns
are exactly the v1 report's numbers, reproduced in-graph by the same instrument
from the frozen `extracted/*` fact lists — v1 was not re-measured or altered.

The M6 value mixes file- and symbol-domain cardinalities (the unchanged v1
definition: the maximum output cardinality over the family). With real symbols
the symbol-domain outputs dominate, which is why v2's M6 is an order of
magnitude above v1's; it is flagged here, not redefined.

Per-region v2 rows (`coherence / seed files / neighborhood / independent /
region blast`):

| region | baseline v2 | cleaned v2 |
|---|---|---|
| repository | 0.625 / 6 / 42 / no / 45.7 | 0.556 / 6 / 44 / no / 46.0 |
| radii | 0.500 / 3 / 44 / no / 57.0 | 0.667 / 3 / 46 / no / 43.3 |
| atlas | 0.000 / 4 / 43 / no / 26.3 | 0.222 / 4 / 45 / no / 37.3 |
| localization | 0.333 / 5 / 37 / yes / 14.2 | 0.111 / 5 / 41 / yes / 17.8 |
| tables | 0.000 / 1 / 38 / no / 260.0 | 1.000 / 2 / 43 / no / 111.0 |
| population | 0.500 / 2 / 36 / no / 28.5 | 0.333 / 2 / 41 / no / 29.5 |
| src-root | 0.000 / 19 / 58 / no / 4.5 | 0.000 / 19 / 62 / no / 4.5 |
| tests | 0.000 / 2 / 39 / yes / 203.5 | 0.000 / 2 / 42 / yes / 167.5 |
| build-src | 0.000 / 13 / 43 / no / 13.5 | 0.000 / 11 / 43 / yes / 11.1 |
| experiments | 0.000 / 8 / 38 / yes / 33.1 | 0.000 / 12 / 44 / yes / 22.6 |

### v1 vs v2: agreement, disagreement, and which v1 signals were lexical artifacts

**Agreement — the semantic spine survives real acquisition.** 14 of the 15
cleaned-v1 shared hotspots are still shared hotspots in cleaned-v2:
`src/Radii.flix`, `src/Repository/Structure.flix`, `src/ScientificTable.flix`,
`src/ScientificTable/Columns.flix`, `src/ScientificIdentity.flix`,
`src/Atlas.flix`, `src/Atlas/Signature.flix`, `src/Atlas/Signature/Table.flix`,
`src/Localization.flix`, `src/Population.flix`, `src/Population/Table.flix`,
`src/Radii/Evaluate.flix`, `src/Repository/Physical.flix`,
`src/Repository/Table.flix`. The cleanup's direction is also the same under both
acquisition systems: `use_edges` up (123 → 141 v1; 90 → 125 v2), high-overlap
pairs up (37 → 42 v1; 45 → 45 v2, saturated), `cross_group_edges_4` up (18 → 22
v1; 26 → 31 v2), median file blast up (24 → 28 v1; 18 → 28 v2). The v1
conclusion — the cleanup traded duplication for shared-hub fan-in — is **not** a
lexical artifact.

**Disagreement — what the lexical proxy got wrong.** Three concrete,
explainable artifacts:

1. **`src/Repository.flix` was a v1 hotspot by construction.** It carries
   pressure 6 in both v1 rows (the joint-top hotspot) but is no longer a shared
   hotspot under real acquisition. Cause: the v1 rule is documented to treat a
   token that equals a module name, *or starts with it followed by `.`*, as a
   use edge, and explicitly notes that "reaching a child name through its dotted
   path also uses the parent module name". Every `Repository.Structure` /
   `Repository.Grit` / `Repository.Physical` mention therefore created an edge
   to `Repository.flix`. Real Flix references resolve to the child module only.
   This is exactly the predicted v1 distortion of namespace structure.
2. **v1's maximum-overlap pair was an artifact.** v1's `atlas+repository` pair
   attains `max_pair_jaccard` (0.974 / 1.000) — the parent-module edges feed it.
   Under real acquisition the maximum pair is `localization+tests`
   (0.949 / 0.976), and `src/Atlas.flix` is not even a shared hotspot in
   baseline-v2. The overlapping pair changed; the *conclusion* (pervasive
   depth-2 overlap) did not.
3. **New, non-Flix hotspots appear.** `build/flix.bzl` (Starlark, the Flix
   BUILD wiring) and `src/Repository/Grit.flix` (the acquisition seam itself)
   are shared hotspots only under real acquisition, and
   `src/ScientificTable/Columns.flix` rises to pressure 6 in cleaned-v2 (5 in
   cleaned-v1). The v1 proxy could not see Starlark or Java at all.

**Saturation under real acquisition.** With real symbols and calls, the depth-2
File family reaches nearly the whole world: `high_overlap_pairs` is 45/45 (all
pairs) in both v2 rows, and every v2 neighborhood covers 36-62 of 72-75 files.
The measured "coupling" is therefore mostly the pipeline's intrinsic
reachability, not a boundary defect — which is consistent with the v1
frontier analysis and with the pipeline reading of the region partition.

### The nine points, re-read under v2

Points 1-3, 6-9 stand unchanged. Point 4 (how Atlas signatures expose the
structure) is now literally true for the measurement: neighborhoods are Atlas
output states, and the acquisition is the repository's own Grit frontend. Point
5 (before/after results) is superseded in content by the four rows above: the
v1 magnitude of "coupling" was an artifact of the lexical world; the direction
of the cleanup's effect is confirmed by real acquisition.


## v1 before/after table (preserved exactly: the lexical/proxy measurement)

The v1 numbers exactly as first reported; kept here so the original result is
readable without the v2 columns. All values come from the committed
typed-Parquet facts admitted in-graph by
`experiments/atlas-parallelism/Parallelism.flix`; reproduced by
`bazel build //experiments/atlas-parallelism:compare --config=buildbuddy-rbe`
(output: `compare.txt`). Metric definitions are identical across revisions
and identical to the v2 definitions above.

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

## Bazel locality (separate execution/build evidence channel)

Bazel locality is collected as its **own channel** — it is never a substitute
for Grit acquisition or for the Atlas signature metrics. Commands (read-only
`bazel query`, no builds): `experiments/atlas-parallelism/v2_bazel_locality.sh`
with `BAZEL_LOCALITY_UNIVERSE` overriding the query universe. Evidence:
`experiments/atlas-parallelism/v2/bazel-locality/{baseline,cleaned}.{targets,tests,fanout}.txt`.

| channel | baseline `bcfc126` | cleaned `ae2f5e68` |
|---|---|---|
| analyzed targets, comparable source/build universe | 41 | 41 |
| test targets, same universe | 11 | 10 |
| analyzed targets, full `//...` | (Rust extension fails to load in a fresh output base; see note) | 371 |
| test targets, full `//...` | — | 15 |
| targets declaring `ScientificTable.flix` in `srcs` | 9 | 10 |
| targets declaring `Radii.flix` in `srcs` | 8 | 9 |
| targets declaring `Repository/Structure.flix` in `srcs` | 10 | 11 |
| targets declaring `Repository.flix` in `srcs` | 11 | 11 |
| targets declaring `Atlas.flix` in `srcs` | 7 | 8 |
| targets declaring `ScientificTable/Columns.flix` in `srcs` | (exists) 8 | 10 |

Reading: each core file is compiled into **7–11 independent Bazel actions**
(five Flix fatjars plus up to six independent `flix_check` law targets). The
build graph therefore agrees with the Atlas-side hub finding — the core files
are simultaneously the signature hubs *and* the broadest edit-invalidation
points — and it agrees with the region story: the region shards are separately
runnable actions (10 per revision) while the shared core is not independently
invalidation-local. Test ownership is flat: `//test` owns every law target and
each law target re-declares the core `srcs`, so a core edit invalidates the
whole law suite (11 → 10 action invalidations measured by `srcs` declaration).

Note (honest limitation): the baseline revision cannot be queried with the full
`//...` universe in a fresh output base, because evaluating it pulls the
`rules_rust` `crate_universe` module extension, which fails with `Permission
denied (os error 13)` on the read-only Rust crate sources in that worktree. The
baseline was therefore queried over the explicitly declared source/build
universe (`//:all + //build:all + //src:all + //test:all +
//experiments/atlas-swe-explore:all + //experiments/swe-explore-js-ts-scale:all
+ //data/evaluation:all`), which is exactly the package set that owns the
tracked source at that revision; the cleaned revision was queried over the full
`//...`. The two counts in the table are reported over the same comparable
universe so they can be compared; the full-`//...` figure for the cleaned
revision additionally includes the 93 frozen census world data packages
(~330 targets), which are data fixtures, not source build actions.

## Provenance: the result cannot be produced without Atlas

`experiments/atlas-parallelism/Provenance.flix` (wired as
`//experiments/atlas-parallelism:parallelism_provenance_test` and added to the
authoritative root `tests` suite) is a focused fixture that fails if the
measurement stops depending on the real Atlas evaluator/signature
implementation. Three tests, all in the Bazel graph in this repository:

1. **Neighborhoods come from actual Atlas transitions.** For every seed file,
   the neighborhood is exactly the depth-2 output-state union recomputed
   independently from the same world; a purely lexical file-set computation
   does not satisfy it.
2. **Changing an admitted relation changes the neighborhood.** Re-admitting the
   same sources with one relation edge added changes that seed's neighborhood;
   the neighborhood is a function of the admitted world evaluated by Atlas, not
   of a fixed listing.
3. **Changing the Atlas program family changes the neighborhood.** Running a
   different family/depth over the same admitted world yields a different
   neighborhood for the same seed.

Corollary observed during construction: the pre-extraction v1 path did **not**
satisfy test 3, because its neighborhoods were computed by a traversal rather
than by Atlas. That is the exact defect the v2 amendment corrects: if changing
or removing Atlas evaluation does not change the neighborhoods, the
implementation is wrong.

## Completion criteria (spec §15)

| criterion | status |
|---|---|
| v1 result preserved exactly and labeled as the lexical/proxy measurement | met — v1 columns reproduced in-graph and unchanged; v1 artifacts untouched |
| labeled amendment committed before the first v2 measurement | met — jj `myxlmvsq` / git `e0154f2b`, before any v2 artifact existed |
| both frozen revisions Grit-acquired, deterministic typed artifacts, documented inclusions/exclusions | met — `v2/README.md`; byte-identical re-run |
| file + region neighborhoods from actual Atlas output states, no handwritten traversal | met — `expansion` via `Atlas.evaluate`, depth-2 File family |
| provenance fixture proves Atlas dependence | met — `parallelism_provenance_test`, in the authoritative suite |
| preregistered quantities recomputed from real neighborhoods; basis statistics labeled | met — four-row table, `class` column; `metricClass` in-bounds |
| Bazel locality reported as a separate channel | met — section above; own script, own evidence |
| four rows + v1-vs-v2 agreement/disagreement analysis | met — section above |
| `./verify` green; frozen paths clean; honest LOC; never push | see below |

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

**The v2 reading of E1–E5.** Re-measured with real Grit acquisition and actual
Atlas neighborhoods, the same decision holds, and the margins are not close:
E1 min region coherence 0.000 (cleaned v2); E2 45 of 45 pairs have jaccard
≥ 0.5, max 0.976; E3 16 shared hotspots with fan-in up; E4 4 of 10 regions
independently testable; E5 locality shows 7–11 invalidations per core edit and
a 10-action shard fan-out — a working shard mechanism, but no threshold that a
future state would plausibly clear. **No oracle is enshrined for v2 either.**
The only caveat in favor of the property is that the v2 saturation
(`high_overlap_pairs` 45/45) is mostly intrinsic pipeline reachability at depth
2, not a boundary defect; a genuinely shard-parallel repository would need a
different region partition (a preregistered amendment), not just fewer edges.

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

- Facts (per revision, v1 lexical proxy): `experiments/atlas-parallelism/extracted/{baseline,after}/{files,modules,uses}.txt`
  (attuneflix-self-admission-v1; extractor seam `extract_self_facts.sh`).
- v2 real Grit acquisition (per revision, committed, deterministic):
  `experiments/atlas-parallelism/v2/sources/{baseline,cleaned}.{sources.parquet,files.txt}`
  and `experiments/atlas-parallelism/v2/grit/{baseline,cleaned}.facts.parquet`
  (schemas `AcquisitionFacts.flix`; seam `v2_extract.sh`; driver
  `AcquisitionDriver.flix`; documented in `v2/README.md`).
- v2 Bazel-locality evidence (separate channel):
  `experiments/atlas-parallelism/v2/bazel-locality/{baseline,cleaned}.{targets,tests,fanout}.txt`
  (script `v2_bazel_locality.sh`).
- The four-row table of record (v1 + v2, both revisions):
  `four_rows.txt` / `four_rows.parquet` / `four_pairs.parquet`
  (`bazel build //experiments/atlas-parallelism:four_rows`).
- Targeted-Parquet signature worlds (per revision):
  `bazel-bin/experiments/atlas-parallelism/{baseline,after}_world/{metadata,entities,relations}.parquet`
  (schemas `src/Repository/Table.flix`).
- Per-region shard rows (both revisions):
  `bazel-bin/experiments/atlas-parallelism/{baseline,after}_region_*/`
  (observation + physical + members schemas).
- Region-pairs tables (both revisions):
  `bazel-bin/experiments/atlas-parallelism/{baseline,after}_pairs.parquet`
  (schema `attuneflix-parallelism-pairs-v1`).
- The v1 comparison table: `compare.txt` (regenerated by the `compare`
  action; deterministic).
- Instrument: `Parallelism.flix` + `Main.flix` plus the v2 additions
  `AcquisitionFacts.flix`, `AcquisitionDriver.flix`, `AcquireMain.flix`,
  `Provenance.flix` (all counted toward the gate; see LOC below).

## LOC accounting (honest, verbatim command)

Measured with the AGENTS.md command (`git ls-files '*.flix' | xargs wc -l |
tail -1`), reading the **working-tree** content of tracked files, plus the
untracked v2 files:

| state | tracked `.flix` lines | files |
|---|---|---|
| committed before this feature (HEAD `059155c`) | 5,362 | 44 |
| working tree with the v2 additions | 5,853 | 48 |

This feature's delta: `Parallelism.flix` 470 → 625 (+155) and four new files
(`AcquisitionFacts.flix` 157, `AcquisitionDriver.flix` 108, `Provenance.flix`
68, `AcquireMain.flix` 3) = **+491 lines**, 4 new files.

The recorded gate is `< 4,800`; the mission's recorded close-out posture (user
steering 2026-09-25, `library/parallelism-experiment-status.md`) is that the
number "is a preference, not a wall, for close-out work — honest reporting
always". The `< 4,800` figure was already exceeded at the previous feature's
HEAD (5,362, from the Grit language/integration work), so this feature reports
both states rather than a single number. `Parallelism.flix` (625 lines) is
over the 400-line standing flag; the file already had that flag relaxed for
this instrument by the v1 steering, and it remains confined to the experiment.
