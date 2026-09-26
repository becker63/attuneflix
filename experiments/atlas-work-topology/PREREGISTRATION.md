# PREREGISTRATION — AttuneFlix work-topology & K4 parallel-architecture experiment

Status: **preregistered**. This file is committed as its own `jj` change whose
only parent is the control revision
`main@eca979f524661cbe400d22b90c7e3c305b32052e`. No architecture change, no
control measurement and no candidate measurement exists in the experiment
history before this change (provable with `nix develop --command jj log`).

Nothing here is amended after a measurement runs except by an explicit, dated,
pre-measurement amendment appended at the end of the file (house precedent:
`experiments/atlas-parallelism/PREREGISTRATION.md`). The control figures quoted
in §13 are the mission's *scoping priors*, not measurements; the frozen control
measurement replaces them and is recorded under `control/` and in `REPORT.md`.
The experiment was designed before any number in it was observed.

Central hypothesis (falsifiable, one repository, one intervention):

> A software system can remain a highly connected semantic machine while
> becoming substantially more parallel to change.

The **semantic signature is the constraint**; the **work topology is the
objective**. A topology improvement that moves the signature is not a result of
this experiment, it is a rejection (O1-O5). A signature-preserving result that
does not move the topology is a reported negative finding, not a failure.

## 0. The ten bound dimensions (index)

| # | dimension | bound in |
|---|---|---|
| 1 | control revision | §1 |
| 2 | acquisition protocol | §2 |
| 3 | Atlas signature protocol, depth 1..7 | §3 |
| 4 | fixed control-region mapping (10-region conceptual partition) | §4 |
| 5 | K4 ownership-cell mapping | §5 |
| 6 | primary measurements | §6 (§7 build channel, §8 co-change channel, §9 identities) |
| 7 | candidate acceptance / rejection rules | §10 |
| 8 | hill-climb procedure | §11 |
| 9 | stopping rules | §12 |
| 10 | success / stretch thresholds and outcome classification | §13 |

## 1. Control revision

- `control_revision = eca979f524661cbe400d22b90c7e3c305b32052e`
  (`main`, the mission's frozen control specimen).
- The commit at that revision is titled `v2 self-signature: real Grit
  acquisition + neighborhoods from actual Atlas`; the repository history stays
  intact and is never rewritten at or below `main@bcfc126`.
- The revision is materialized only in an isolated `git worktree` under `/tmp`
  (`git worktree add /tmp/attuneflix-control <control_revision>`). The live
  worktree is never reset, never mutated, and never used as an acquisition
  input.
- Recorded evidence: `experiments/atlas-work-topology/control/control.revision.txt`
  holds exactly the 40-character hash above;
  `experiments/atlas-work-topology/control/control.files.txt` holds the sorted
  admitted path list (§2).

## 2. Acquisition protocol (real Grit, one fact protocol)

The control world is acquired with the repository's own, already-frozen
polyglot acquisition path. There is no experiment-specific parser, no second
frontend, and no lexical proxy:

```text
source -> Grit -> Repository.Grit.Fact -> Repository.admit -> Repository.World
```

- **Admitted surface.** A tracked path is admitted iff
  `Repository.Grit.language(path) != None` (deterministic path table:
  `.flix`, `.java`, `.js`/`.mjs`/`.cjs`, `.jsx`, `.ts`/`.mts`/`.cts`, `.tsx`,
  `.bzl`/`.bazel`/`.star`, and the Bazel build files `BUILD`, `BUILD.bazel`,
  `WORKSPACE`, `WORKSPACE.bazel`), **excluding** the frozen data tree
  `.attune/**`. The admitted list is committed verbatim
  (`control.files.txt`); the exclusion is part of the protocol, not an
  accident.
- **Frontends.** `src/grit/{defines,imports,calls}/<language>.grit` executed by
  the frozen hermetic Grit closure
  `getgrit/gritql @ c80b3026471b229f41b279c3eb0c162dcdacfdb1`, with the one
  pinned Flix grammar
  `omarjatoi/tree-sitter-flix @ 78cff149b2e9897456f94844872353b5ee0ca93b` and the
  maintained Starlark grammar. The engine is dispatched through the single seam
  `Repository.Acquire.evaluate`; no language-specific syntax escapes it.
- **Fact shape.** Every language emits the one
  `Repository.Grit.Fact` = (kind, path, start_byte, end_byte, value). There are
  no per-language fact types and no per-language worlds.
- **Admission.** `Repository.admit` is the only admission step; `parents` is
  derived from the admitted paths, imports/calls are resolved per language
  behind the one admission abstraction, and unresolved imports/calls are
  counted (`unresolvedImports`, `unresolvedCalls`), never silently dropped.
- **Acquisition identity.** `grit-acquisition-v2:getgrit/gritql@c80b3026471b229f41b279c3eb0c162dcdacfdb1:frontends-defines-imports-calls`.
  The world also carries `fact_identity = repository-facts-v2` (hash over the
  admitted basis), `source_tree_identity = attuneflix-source-tree-v1:<control_revision>`
  and `snapshot_id` from the frozen `atlas-snapshot-v1` identity rule.
- **Artifacts** (typed Parquet under `experiments/atlas-work-topology/control/`):

| artifact | schema | content |
|---|---|---|
| `control.sources.parquet` | `attuneflix-grit-sources-v2` | path, sha256, byte_length, language |
| `control.facts.parquet` | `attuneflix-grit-facts-v2` | path, source_sha256, language, program, kind, start_byte, end_byte, value |
| `control.files.txt` | text | the admitted path list, `LC_ALL=C` sorted, one repository-relative path per line |
| `control.revision.txt` | text | the 40-character control revision hash |

- **Evidence cannot drift.** Re-admission (inside the Bazel graph, no source
  text parsed at build time) verifies per fact that the path is admitted, that
  the source hash and language match the inclusion record, and that the byte
  range lies inside the source. A mismatch is a hard failure, never a warning.
- **Determinism.** Two consecutive acquisitions of the same worktree, by the
  same frozen engine, must produce row-for-row identical tables, identical
  manifests, and identical content hashes. Byte-for-byte equality of the
  Parquet containers is asserted as well; if the Parquet writer is shown to
  embed only a non-semantic writer-version string, the row-for-row and
  manifest hash equality remain the acceptance criterion and the difference is
  documented, never hidden.
- **Command of record.** `nix develop --command bazel run //experiments/atlas-work-topology:acquire`
  (reproducible measurement target), with the isolated worktree path passed as
  a declared property, never read from the ambient environment.

## 3. Atlas signature protocol (depth 1..7)

The depth-response oracle is the existing, frozen Atlas machinery
(`//src:Atlas.flix`, `//src:Atlas/Signature.flix`,
`//src:Atlas/Signature/{Summary,Table}.flix`, `Repository.Physical`). The
mission adds no grammar, no atom and no evaluator.

- **Grammar.** Composition-only programs over the **six directed atoms**
  `Defines, DefinedIn, Imports, ImportedBy, Calls, Callers`, maximum depth
  **7**, `atlas_protocol = atlas-composition-depth7-v1`. The grammar is
  enumerated by `Atlas.programsFrom(<declared seed domain>, d)` for
  `d = 1..7`. Both declared seed domains (File, Symbol) admit exactly
  **3,279 cumulative logical routes** through depth 7, with per-depth level
  counts `3, 9, 27, 81, 243, 729, 2,187`. Route identity is
  `atlas-route-v1:<sha256>`; semantic state identity is
  `atlas-state-v1:<sha256>` (already frozen; reused unchanged).
- **Evaluation.** `Atlas.evaluate` over the re-admitted control world, one
  physical transition per `(Atom, exact typed frontier)` cache miss and one
  transition reuse per hit. No handwritten BFS/DFS, no second graph, no
  alternate expansion path.
- **Seed panel.** The frozen issue-blind panel `atlas-signature-seeds-v1`:
  hash each stable entity identity under the domain-prefix bytes, order by
  (digest, identity), keep the **first 8** per declared domain, giving at most
  8 File seeds and 8 Symbol seeds (**16 seeds**; fewer only if a domain in the
  control world has fewer than 8 entities). Selection never uses issue text,
  embeddings, evaluator gold, ordinal filesystem order, or file paths as
  priority.
- **Per-depth measured quantities** (one row per seed × route, frozen schema
  `attune-atlas-signature-observations-v1`): `depth`, `first_atom`,
  `last_atom`, `terminal_domain`, `input_cardinality`, `output_cardinality`,
  `domain_cardinality`, `expansion_ratio = output/input`,
  `reach_fraction = output/domainCardinality`, `extinct`,
  `first_extinction_depth`, `semantic_state_id`, `same_as_input`.
- **Per-depth reductions** (frozen schema `attune-atlas-signature-summary-v1`,
  scopes `seed_domain`, `seed_domain_depth`, `seed_domain_depth_direction`):
  `observation_count`, `extinct_fraction`, `survival_fraction`,
  `first_extinction_depth_{1..7}_fraction`, `output_cardinality_p50/p90/p99`,
  `expansion_ratio_p50/p90/p99`, `contracting/unchanged/expanding_fraction`,
  `reach_fraction_p50/p90/p99`, `reach_ge_0_25/0_50/0_90_fraction`,
  `unique_semantic_states`, `logical_per_unique_state`,
  `state_multiplicity_p50/p90/p99/max`, `same_as_input_fraction`.
- **Physical work** (frozen schema `attune-atlas-signature-physical-v1`):
  `logical_routes`, `unique_semantic_states`, `physical_transition_requests`,
  `physical_transition_evaluations`, `physical_transition_reuses`,
  `logical_per_unique_state`, `logical_per_physical_evaluation`, `memo_cells`.
- **Mixing landmarks `D50, D80, D90, D95`.** Exact definition, for the File
  seed panel `P` (|P| ≤ 8) and depth `d = 1..7`:
  - `reach_d(f)` = the set of admitted file paths in
    `⋃ { members(output) : r ∈ File-domain routes, |r| ≤ d, output = Atlas.evaluate(world, {f}, r) }`,
    where `members` maps a file state to its files and a symbol state to the
    declaring file through the canonical `DefinedIn` relation;
  - `cover_d(f) = |reach_d(f)| / fileCount`;
  - `mean_coverage(d) = (1/|P|) * Σ_{f ∈ P} cover_d(f)`, monotone in `d`
    because the union is cumulative (depth ≤ d);
  - `D_p = min { d ∈ 1..7 : mean_coverage(d) ≥ p }`, or `none` if the curve
    never reaches `p`; `D50`, `D80`, `D90`, `D95` take `p = 0.50, 0.80, 0.90,
    0.95`.
  - For drift comparison `none` is encoded as `8` (max depth + 1).
- **Depth-7 reach** = `mean_coverage(7)`; reported as a fraction with three
  decimals.
- **Signature identity for this experiment**:
  `signature_protocol = atlas-signature-work-topology-v1`, together with the
  frozen `atlas_protocol`, `repository = "attuneflix"`, `base_revision`,
  `source_tree_identity`, `fact_identity`, `snapshot_id` columns. The
  `atlas-signature-swe-explore-v1` census protocol and its `.attune` data are
  never modified or re-run.
- **Commands of record.**
  `nix develop --command bazel run //experiments/atlas-work-topology:compute_control_signatures`
  writes `control.signatures.parquet` (observations), `control.summaries.parquet`
  (summary + physical rows), and the per-seed shards they are combined from.

## 4. Control-region mapping: `attuneflix-regions-v1` (the 10-region conceptual partition)

A pure function of the admitted path, fixed in advance, applied identically to
the control and to every candidate. First matching rule wins.

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
| - | `other` | every admitted path matching no rule above (residual bucket) |

- The 10 named regions are the 10-region conceptual partition and are the
  partition used for every reported ratio. These are the same ten names and
  the same per-path rules as the instrument that produced the mission's
  control prior in §13, whose residual fallback for an unmatched path is the
  string `other`.
- The residual `other` bucket is **never silently dropped**: its file list, its
  edge count and its share of the basis graph are reported with every cut
  table. An edge whose source or target is `other`-homed counts as crossing at
  every `k` in the inherited instrument convention (the residual group is not a
  merge seed); that convention is part of the protocol, documented rather than
  discovered.
- Regions with no files at a revision are dropped from that revision's analyses
  (no empty-region rows, no zero-valued phantom regions).
- The partition may not be re-tuned after seeing control or candidate numbers.
  The only permitted change is a dated pre-measurement amendment, which must
  keep the 10 region names.

## 5. K4 ownership-cell mapping: `attuneflix-cells-v1`

A second, independent path function over the same admitted file set. It is
reported **separately** from §4 (a region is a semantic subsystem, a cell is an
ownership unit). First matching rule wins:

| cell | rule |
|---|---|
| `kernel` | `src/ScientificIdentity.flix`, `src/ScientificTable.flix`, `src/ScientificTable/**`, `src/native/identity/**`, `src/native/parquet/**` |
| `world` | `src/Repository.flix`, prefix `src/Repository/` except `src/Repository/Physical.flix`; `src/grit/**` (the GritQL frontends); `src/native/grit/**` |
| `engine` | `src/Repository/Physical.flix`; `src/Radii.flix`, prefix `src/Radii/`; `src/Atlas.flix`, prefix `src/Atlas/` |
| `applications` | `src/Localization.flix`, prefix `src/Localization/`; `src/Population.flix`, prefix `src/Population/`; `src/native/inference/**` |
| `research` | `src/Experiment.flix`; prefix `experiments/` |
| `law` | prefix `test/`; prefix `build/`; repository-root `BUILD.bazel` / `MODULE.bazel`; prefix `data/` |
| `other` | every admitted path matching nothing above (residual; reported, never dropped) |

Definitions bound here:

- **The four cells** are World (what repository world do we have?), Engine (what
  does the admitted structure do?), Applications (what useful work do we
  perform with Atlas outputs?) and Research (what experiments do we run on the
  system?). `kernel` is the stable high-fan-in substrate
  (`ScientificIdentity`, `ScientificTable`); `law` is the horizontally owned
  test/build surface that has **no owner at control**.
- **Cell invariants (target state, verified per round):** no cell imports an
  internal module of another cell except through that cell's intentional public
  surface; no production module in kernel/World/Engine/Applications imports
  from Research; `Repository.Physical` is owned by Engine while keeping
  permanent exact parity against `Repository.Reference` owned by World.
- **Ownership-cell cut, `k = 4`.** `cell_cut_4` = the number and fraction of
  basis edges `(f, g)` with `cell(f) != cell(g)`, computed over the four cells;
  kernel-, law- and other-homed edges are excluded from the numerator and
  denominator and their counts are reported in the same table. This is the
  *initial* (pre-Round-1) ownership-cell cut.
- After Round 1 every admitted file is cell-homed (`law` surfaces become
  cell-owned). The Round 1 owner assignment is a **pre-measurement amendment**
  (dated, appended to this file, committed before the Round 1 measurement) that
  records the exact path prefix per cell and applies identically to every later
  candidate. The two invariants that amendment must satisfy: every admitted
  file has exactly one cell, and every law target is owned by the cell it
  exercises.

## 6. Primary measurements

Three channels, never conflated. A BASIS value is never presented as an Atlas
signature, and a BUILD value is never presented as a semantic measurement.

### 6.1 BASIS (direct admitted-relation statistics, `world#imports`)

- **T1 `admitted_files`** = count of admitted files, with the per-language
  histogram (flix, java, starlark, javascript, jsx, typescript, tsx).
- **T2 `use_edges`** = `|world#imports|` (file→file import edges; the basis
  graph). Also reported: `symbols`, `defines`, `calls`, `parents`,
  `unresolvedImports`, `unresolvedCalls`.
- **T3 `cross_region_edge_ratio`** = `|{(f,g) ∈ imports : region(f) ≠ region(g)}| / |imports|`
  under §4, reported over the 10 named regions with the `other` decomposition.
- **T4 `k_way_cut(k)`, `k = 2..10`** = the cross-group edge **count** and
  **fraction** (`count / |imports|`) after the frozen greedy agglomerative
  merge: start from the non-empty named regions as singleton groups sorted by
  name; repeatedly merge the pair `(A, B)` maximizing
  `w(A,B) + w(B,A)` (edge count between the groups, both directions), ties
  broken by the lexicographically smallest pair of names, the merged group
  keeping the smaller name; stop at `k` groups; count edges whose endpoints fall
  in different groups. `k_way_cut(8)` is **the primary objective quantity**.
- **T5 `cell_cut_4`** = the ownership-cell cut of §5 (initial and, per round,
  post-amendment).
- **T6 `region_coherence`** `c(R) = internal(R) / (internal(R) + outgoing(R))`
  per non-empty region, with the minimum reported.
- **T7 `shared_hotspots`** = count of admitted files `g` with
  `importing_regions(g) ≥ 2`; `max_hotspot_pressure = max_g importing_regions(g)`
  where `importing_regions(g) = |{region(f) : (f,g) ∈ imports, region(f) ≠ region(g)}|`.
- **T8 `independently_testable_regions`** = count of non-empty regions `R` with
  no use edge `(f → g)`, `g ∈ R`, `f ∉ R`, `region(f)` not test-side
  (`tests`, `build-src`).
- **T9 region-pair Jaccard overlap** (ATLAS class, listed here for the table's
  completeness): `N(R) = R's files ∪ (union of all File-domain route outputs of
  depth ≤ 2 from `R`'s file seed)`;
  `jaccard(A,B) = |N(A) ∩ N(B)| / |N(A) ∪ N(B)|`; report `max_pair_jaccard` and
  `high_overlap_pairs` (pairs with `jaccard ≥ 0.5`).
- **T10 file blast radius** (ATLAS class): `b(f)` = size of the union of
  depth-≤2 File-domain outputs from `{f}`; report median and p90 with the
  nearest-rank rule (ascending sort, 0-based index
  `min(n-1, floor(p * n / 100))`), plus `max_region_blast`.

### 6.2 ATLAS (depth 1..7 signature, §3)

The full depth-response curve, the mixing landmarks `D50, D80, D90, D95`,
depth-7 reach, extinction depths, unique states, logical routes, physical
transitions and reuses, and the compression ratios. All comparisons between
control and a candidate are made on the **logical identity** layer (§9), so
file moves and renames do not perturb the comparison.

### 6.3 BUILD (execution/build evidence, §7) and CO-CHANGE (§8)

Separate channels; each has its own artifact and its own section of `REPORT.md`.

### 6.4 PROCESS / Factory channel

Per-feature wall time, worker session count, concurrency, conflict events,
reconciliation events, validator findings, and reverted-candidate counts come
from mission records only. They are reported in a dedicated Factory section and
are **never** mixed into a structural measurement or into an Oracle verdict.

## 7. Bazel build-locality and invalidation channel

Deterministic reading of the revision's declared `BUILD.bazel` files via
`bazel query` (never inferred from source text):

- `control.targets.txt` = every analyzed target with its label kind.
- `control.tests.txt` = every independently runnable test target
  (`kind(".*_test", universe)`).
- `control.fanout.txt` = per admitted source file, the targets declaring it in
  `srcs` (`attr(srcs, "<basename>", universe)`) and the direct-dependent count;
  plus the test-target invalidation fanout (`rdeps` intersected with test
  targets) and the attributable action count for a full build.
- Command of record:
  `nix develop --command bash experiments/atlas-work-topology/scripts/measure_bazel_locality.sh control`
  (and `round1`, `round2`, `round3`, `round4` thereafter), writing
  `control.fanout.txt`, `control.targets.txt`, `control.tests.txt`.
- **Documented limitation, inherited and never hidden:** the control revision
  cannot be loaded with the full `//...` universe in a fresh output base (its
  Rust crate universe module extension cannot be evaluated), so the locality
  evidence uses the Rust-free source/build universe; the restriction is
  recorded verbatim in the report. BuildBuddy cache reuse is discussed
  explicitly as an execution-cost effect, never as architectural independence.

## 8. Co-change work graph

Model `attuneflix-cochange-v1`, constructed from the VCS history reachable from
the control revision, excluding the experiment's own changes:

- **Raw model (unweighted):** for each commit touching `T`, the set of admitted
  files it touches, add `1` to `raw(f, g)` for every unordered pair
  `{f, g} ⊆ T`. This is a pair *frequency*.
- **Weighted model (normalized):** add `1 / C(|T|, 2)` per commit per pair, so
  each commit contributes unit total mass and large commits cannot dominate.
  Reported alongside: `changed_lines` weighting
  (`min(changed_lines(f), changed_lines(g))` per co-change) as a third,
  clearly labelled variant.
- **Reported:** the strongest pairs, per-region internal share, the
  cross-region co-change ratio, and the co-change counterpart of
  `k_way_cut(8)`. Artifact `control.cochange.json`.
- Raw, normalized and line-weighted numbers are always printed as three
  distinct columns; a weighted number is never presented as a raw frequency.
- **Documented limitation:** the available history is small and single-author
  with squashed `jj` changes, so this model is a weak, honest proxy for real
  coordination; it is reported as such and never used alone to justify a
  candidate's acceptance.

## 9. Logical identity mapping

`control.identity_map.json` maps every admitted control file to
`{logical_id, control_path, current_path, control_region, ownership_cell}`.

- `logical_id = "attuneflix-logical-v1:" + sha256(language + "\u0000" + declared_identity + "\u0000" + surface_class)`,
  using the frozen `ScientificIdentity.sha256`. Paths are **not** part of the
  payload (that is the whole point: identity survives moves).
- `declared_identity`: `.flix` = the declared module name (`mod`/`pub mod`
  first declaration); `.flix` with no declaration = basename without extension;
  `.java` = declared package + class name; `.grit` = `<relation>/<language>`;
  Bazel files = Bazel package path + basename (`root` for the repository root).
- `surface_class ∈ {production, law, instrument}` from a coarse, move-stable
  prefix rule (`src/` → production; `test/`, `build/` → law; `experiments/` →
  instrument), which keeps distinct identities distinct where two files declare
  the same module name (`src/Repository.flix` vs `build/src/Repository.flix`).
- `logical_ids` must be **unique** at control; a collision is a construction
  failure to be resolved by extending the payload, never by ignoring the
  collision.
- `current_path` equals `control_path` at control and is updated after every
  adopted round. Region and cell columns are filled from §4 and §5.

## 10. Candidate acceptance / rejection rules (the signature preservation oracle)

Every candidate architecture change is measured with the identical instrument
and evaluated against all of:

- **O1 Grammar invariance.** Exactly the six directed atoms, composition only,
  depth ≤ 7, 3,279 cumulative File-domain and Symbol-domain routes, route/state
  identities unchanged. Any change here is a rejection, never a migration.
- **O2 Mixing landmarks.** `|D_p(candidate) − D_p(control)| ≤ 1` for
  `p ∈ {0.50, 0.80, 0.90}` (`none` encoded as 8; control `none` + candidate
  value, or the reverse, fails).
- **O3 Depth-7 reach.** `mean_coverage(7)` may not fall by more than `0.05`
  (5 percentage points).
- **O4 Extinction and recurrence regime.** No route that is non-empty in
  control (logical-identity normalized) may be empty in the candidate; no depth
  `d` may lose more than `0.10` survival fraction relative to control; no new
  bulk extinction regime at any depth.
- **O5 Parity and the full gate.** `ParityTest` (`Repository.Reference` vs
  `Repository.Physical`) passes and
  `source /etc/profile.d/nix.sh && ./verify` exits `0` with 100% of test targets
  passing on BuildBuddy RBE.
- **O6 Logical identity continuity.** Every control `logical_id` maps to
  exactly one `current_path`; no identity is silently created, dropped or
  merged by a move. A deliberate split is recorded explicitly in the identity
  map (both successors listed with provenance) and reported as a finding.
- **O7 Law and LOC hygiene.** Tracked handwritten Flix LOC
  (`git ls-files '*.flix' | xargs wc -l | tail -1`) must end **< 4,800** raw
  lines; no tracked `.flix` file may exceed 400 raw lines, except the
  standing-flagged instrument `experiments/atlas-parallelism/Parallelism.flix`,
  which the hill-climb must bring within the limit or retire. Measurement code
  for this experiment lives in `experiments/atlas-work-topology/` and counts
  toward the gate; no permanent `src/` inflation for measurement.
- **O8 Legibility and non-duplication.** No duplicated semantic implementation,
  no microservices, no network serialization of internal functions, no
  enterprise wrappers (`FooService`, `FooProvider`); idioms are ordinary typed
  Flix modules and ordinary Bazel rules.
- **O9 Evidence determinism.** Typed Parquet round-trips are exact, and control
  re-acquisition reproduces the tables (§2), so every comparison is between the
  same measured artifacts.

**Rejection rule.** A candidate failing O1, O2, O3, O4, O5, O6 or O9 is
**rejected and reverted**; it is never retained with a weakened or amended
oracle, and the oracle is never re-tuned to admit it. O7 and O8 are blocking but
repairable within the same round (repair and re-measure; if unrepairable, the
candidate is rejected).

**Non-rule.** A candidate that passes O1..O9 but does not improve (or worsens)
`k_way_cut(8)`, `cell_cut_4`, coherence, hotspot pressure or fanout is **not**
rejected: it is recorded with its measured deltas as a negative result and not
adopted. Reporting the negative result is part of the deliverable.

## 11. Hill-climb procedure

Four rounds against the frozen oracle, in order; one coherent `jj` change per
unit of work, ending each with `jj new`:

1. **Round 1, cell-owned law and build surfaces.** Move tests, fixtures and
   build wiring into cell-owned law surfaces (World, Engine, Applications,
   Research), with the root `//:tests` suite *aggregating* cell suites rather
   than owning them. Pre-measurement amendment of §5 first.
2. **Round 2, narrow cell crossings.** Replace reach-through into another
   cell's internal modules with explicit intentional public surfaces.
3. **Round 3, stabilize high-pressure shared owners.** Identify shared hotspots
   from the control data and move volatile implementations behind stable
   contracts without duplicating them.
4. **Round 4, typed artifact and build-cache boundaries.** Exploit typed
   Parquet and Bazel cache boundaries for expensive or scientific stages so
   rebuilds and invalidations do not propagate repository-wide.

Per round, and for each candidate step:

1. Propose the candidate as a described `jj` change (title + body: what
   changed, the surviving owner, laws preserved, tests run, LOC delta).
2. Measure with the identical instrument: `measure_topology` for the topology
   and cut tables, `compute_control_signatures` machinery for the signature
   delta, the build-locality script for the fanout channel, all normalized by
   logical identity.
3. Evaluate O1..O9 and the primary quantity `k_way_cut(8)`.
4. Adopt only if O1..O9 pass; otherwise revert the candidate's `jj` change and
   record the rejection with its measurements.
5. Record one delta row per candidate (adopted *and* rejected) in
   `round<k>.topology.json` and the round's signature delta table.
6. Run the round's affected Bazel test targets batched into **one** invocation
   (`nix develop --command bazel test //target1 //target2 --config=buildbuddy-rbe`;
   never two concurrent Bazel processes), then `source /etc/profile.d/nix.sh && ./verify`.
7. Stop the round when its candidate budget is exhausted: at most **8**
   candidate steps evaluated and at most **4** adopted per round.

No metric, partition, protocol or oracle is redefined between rounds; the only
permitted change is the §5 pre-measurement cell amendment of Round 1. The
hill-climb never re-acquires facts, never re-runs the frozen census, never
touches `.attune/**`, and never calls a model or provider.

## 12. Stopping rules

**Hard stops (immediately, the step is reverted and the mission reports):**

- **S1** Any step would require re-acquiring facts, embeddings or Jev
  decisions, or any provider/model call.
- **S2** Any step would modify, regenerate or hand-edit frozen evidence
  (`.attune/**`, the census parquet, historical experiment outputs), or weaken
  `Repository.Reference`/`Repository.Physical` parity.
- **S3** Any step would alter the six atoms, the composition-only grammar, the
  depth-7 bound, or the meaning of any frozen scientific identity.
- **S4** `./verify` cannot be made green inside the round (revert the round;
  if the failure predates the round, stop and report the pre-existing failure
  rather than masking it).
- **S5** The tracked-Flix LOC gate would be exceeded by the step and cannot be
  repaired inside the round.

**Soft stops (finish the current measurement, then report):**

- **S6** The round budget is exhausted (4 rounds).
- **S7** Two consecutive rounds adopt no step that improves `k_way_cut(8)`
  (all candidates rejected or neutral): the hill-climb has stalled.
- **S8** `k_way_cut(8)` reaches the stretch goal (≤ 25%): stop early and
  report the achieved result rather than spending the remaining margin.
- **S9** No admissible candidate remains in a round (every remaining proposal
  would violate the oracle): record the exhausted reason and stop.
- **S10** Two consecutive candidates show either a `D50/D80/D90` drift of
  exactly 1 or a depth-7 reach drop between 0.03 and 0.05: stop before the
  oracle margin is consumed.

Stopping never cancels the deliverable: `REPORT.md` is written with the
measured curves, the outcome classification of §13, and an explicit statement
of which stopping rule fired.

## 13. Success, stretch and outcome classification

Control baseline (mission scoping prior, to be replaced by the frozen control
measurement): `k_way_cut(8) = 70.4%` cross-region edges (`88 / 125`).

| level | criterion on the primary quantity |
|---|---|
| Minimum serious success | `k_way_cut(8) < 50%` |
| Strong success | `k_way_cut(8) ≤ 35%` |
| Stretch goal | `k_way_cut(8) ≤ 25%` (≈ the 4-way baseline) |

Outcome classification for `REPORT.md`, decided **only** from the frozen
measurements:

- **Outcome A — strong success.** O1..O9 hold at the final adopted state and
  `k_way_cut(8) ≤ 35%`.
- **Outcome B — serious success.** O1..O9 hold and
  `50% > k_way_cut(8) > 35%`.
- **Outcome C — inconclusive or trade-off.** `k_way_cut(8) ≥ 50%`, or any
  oracle/law concession was required at any point, or the run stopped through
  S4/S5/S7 without reaching 50%.

The signature preservation (O1..O5) is a **precondition** of A and B, never a
bargain chip: if the only way found to reduce the cut requires moving the
signature, the outcome is C and the finding is that in this repository semantic
connectivity and parallel changeability are in tension. Every outcome,
including C, is reported with the measured evidence.

## 14. Artifacts, targets and provenance

Artifact layout under `experiments/atlas-work-topology/`:

```text
PREREGISTRATION.md                 this file (first experiment change)
REPORT.md                          final synthesis, 5 headline curves
control/
  control.revision.txt             the control revision hash
  control.files.txt                admitted path list (inclusion record)
  control.sources.parquet          attuneflix-grit-sources-v2
  control.facts.parquet            attuneflix-grit-facts-v2
  control.signatures.parquet       attune-atlas-signature-observations-v1
  control.summaries.parquet        attune-atlas-signature-summary-v1 (+ physical rows)
  control.topology.json            cuts k=2..10, cell_cut_4, coherence, hotspots
  control.cochange.json            raw / normalized / line-weighted co-change
  control.identity_map.json        logical_id, control_path, current_path, region, cell
  control.fanout.txt               Bazel direct dependents per file
  control.targets.txt              analyzed targets
  control.tests.txt                independently runnable test targets
scripts/measure_bazel_locality.sh  the build-locality command of record
round1/ round2/ round3/ round4/    the same artifact set per adopted round
```

Reproducible Bazel targets (VAL-REPORT-002), all wired through the one
derivation graph and re-runnable from scratch:

- `//experiments/atlas-work-topology:acquire` (`bazel run`) — control
  acquisition (§2).
- `//experiments/atlas-work-topology:compute_control_signatures` (`bazel run`)
  — depth 1..7 signature tables (§3).
- `//experiments/atlas-work-topology:measure_control_topology` (`bazel run`)
  — control topology, cuts, co-change (§6, §8).
- `//experiments/atlas-work-topology:measure_topology` (`bazel run`) — a
  candidate's topology and signature deltas.
- `//experiments/atlas-work-topology:control_reproducibility_test` (`bazel test`)
  — deterministic re-acquisition.
- `//experiments/atlas-work-topology:...` — the experiment's own test suite,
  clean under `--config=buildbuddy-rbe`.

**Provenance (in-graph, mandatory).** The measurement graph depends on the real
`//src:Atlas.flix`, `//src:Atlas/Signature.flix`, `//src:Repository/Physical.flix`
and the real admission code, exactly as the parallelism provenance fixture does:
a focused provenance test must fail if the Atlas program family or an admitted
relation changes and the measured signature does not. If a result could be
produced without Atlas, the design is wrong and is corrected, not excused.

## 15. What this experiment never does

- Never modifies, regenerates or hand-edits `.attune/**`, the frozen census
  parquet, `REPORT.md` of any historical experiment, or any retained provider
  evidence.
- Never invokes OpenRouter or any provider, never re-acquires embeddings or Jev
  decisions, never retunes iteration 013. Replay stays keyless and local.
- Never runs `bazel clean`, never deletes local or remote caches, never touches
  the `bazel-*` / `bazel-out` symlinks, never runs two Bazel processes at once.
- Never rewrites history at or below `main@bcfc126`, never pushes without
  explicit authorization.
- Never exposes evaluator gold to Localization and never lets Atlas depend on
  issues, inference or gold.
- Never presents a BASIS or BUILD number as an Atlas signature, and never
  presents a weighted co-change number as a raw frequency.
- Never reports a threshold as met without the frozen artifact that shows it.

## 16. Ordering guarantee

The experiment history is ordered: (1) this preregistration, (2) control
acquisition, (3) control signatures, (4) control topology and co-change,
(5) Rounds 1-4 with per-candidate oracle evaluation, (6) `REPORT.md` and the
final gate. Steps 2-6 may not be committed, and no architecture edit may exist,
before this file's change. `nix develop --command jj log` proves it: this file's
parent is `main@eca979f524661cbe400d22b90c7e3c305b32052e` and no change under
`experiments/atlas-work-topology/` predates it.
