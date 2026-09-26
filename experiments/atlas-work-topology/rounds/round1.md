# Round 1 — cell-owned law and build surfaces (Hill-Climb round 1 delta report)

| | |
|---|---|
| role | `round1` |
| candidate revision | `52da64241a61d9d1ebee82c8bf0f8773d63092b0` (*round 1: cell-owned law and build surfaces*) |
| control revision | `eca979f524661cbe400d22b90c7e3c305b32052e` |
| artifacts | `round1/round1.identity_map.json`, `round1/round1.topology.json`, `round1/round1.oracle.json`, `round1/round1.files.txt`, `round1/round1.sources.txt`, `round1/round1.targets.txt`, `round1/round1.tests.txt`, `round1/round1.fanout.txt`, `round1/round1.fanout_delta.tsv` |
| measurement | `nix develop --command bazel run //experiments/atlas-work-topology:measure_topology --config=buildbuddy-rbe -- round1` |
| BUILD channel | `nix develop --command bash experiments/atlas-work-topology/scripts/measure_bazel_locality.sh round1`, then `scripts/fanout_delta.sh control round1` |

**Verdict: accepted.** Every §10 oracle rule passes (O1–O6), the topology moves
in the intended direction, and the Bazel channel shows the cross-cell test
invalidation falling. One caveat is recorded in §2.1: the `D50` landmark drifts
by exactly one depth, which consumes the whole `|ΔD50| ≤ 1` margin and puts the
§12 S10 stopping rule one repeat away from firing.

## 0. Commands of record

```bash
# control evidence (already frozen; re-derivable, never re-acquired for a round)
nix develop --command bazel run //experiments/atlas-work-topology:acquire --config=buildbuddy-rbe
nix develop --command bazel run //experiments/atlas-work-topology:compute_control_signatures --config=buildbuddy-rbe
nix develop --command bazel run //experiments/atlas-work-topology:measure_control_topology --config=buildbuddy-rbe

# round 1 evidence
nix develop --command bazel run //experiments/atlas-work-topology:measure_topology --config=buildbuddy-rbe -- round1
nix develop --command bash experiments/atlas-work-topology/scripts/measure_bazel_locality.sh round1
bash experiments/atlas-work-topology/scripts/fanout_delta.sh control round1

# independent verification
nix develop --command bazel test //experiments/atlas-work-topology:round_test \
  //experiments/atlas-work-topology:round1_artifacts_test --config=buildbuddy-rbe
./verify
```

`round1_artifacts_test` re-derives the identity map, the topology document and
the oracle from the committed control evidence and compares them with the
committed files byte-for-byte, so the numbers below are reproducible from the
frozen evidence plus the two declared inputs of the round.

## 1. What round 1 changed, on the identity layer (§9)

The round's admitted surface grew from the 81 control basis files to 102 files
by the one §2 admission rule (`round1/round1.files.txt`); the frozen control
facts are 6,254 rows and were **not** re-acquired (§11).

| movement | count | meaning |
|---|---|---|
| stable | 64 | same logical identity, same path, same bytes |
| modified | 4 | same identity/path, changed bytes (`BUILD.bazel`, `build/BUILD.bazel`, `experiments/atlas-parallelism/BUILD.bazel`, `test/BUILD.bazel`) |
| moved | 13 | same logical identity and bytes, new path (`build/src/*.flix` → `test/<Cell>/*.flix`) |
| dropped | 0 | every control identity survives |
| new | 21 | candidate-only paths (the cell law packages and the round instrument) |
| collisions | 0 | control logical ids are unique, so classification is total |

49 of the 137 basis edges are incident to a modified file. **No admitted `src/`
production source changed content** (`O4` production-drift verdict: true), which
is the O5-adjacent guarantee that this round is a move/wiring round and not a
semantic edit.

The intervention itself: the horizontally owned `law` surface lost its
files — the 13 law sources moved from `build/src/` into `test/World|Engine|
Applications|Kernel/`, each cell package owns its law sources and law test
targets, and the root `//:tests` suite aggregates them. Per the §5 amendment
(`attuneflix-cells-v1-round1`), every admitted file now has exactly one cell and
every law target is owned by the cell it exercises.

## 2. Signature preservation oracle (§10)

Independent verification: `//experiments/atlas-work-topology:round_test`
(9 law tests, including the two round-specific drift laws) and
`//experiments/atlas-work-topology:round1_artifacts_test` both pass.

### O1 grammar invariance — pass

Six directed atoms, composition only, depth ≤ 7, unchanged: 3,279 cumulative
File-domain routes and 3,279 Symbol-domain routes, with the depth ladder
3, 12, 39, 120, 363, 1092, 3279. `RoundTest.theFrozenGrammarIsInvariant`
asserts the exact route counts; nothing in the round touches
`Atlas`/`Radii`/`Repository`.

### O2 mixing landmarks — pass (with the margin fully consumed)

| landmark | control | round1 | delta | threshold | ok |
|---|---|---|---|---|---|
| `D50` | 3 | 4 | **+1** | 1 | yes |
| `D80` | none (8) | none (8) | 0 | 1 | yes |
| `D90` | none (8) | none (8) | 0 | 1 | yes |
| `D95` | none (8) | none (8) | 0 | 1 | yes |

### O3 depth-7 reach — pass

| depth | control | round1 |
|---|---|---|
| 1 | 0.0972 | 0.0756 |
| 2 | 0.4136 | 0.2685 |
| 3 | 0.5247 | 0.4722 |
| 4 | 0.6327 | 0.5910 |
| 5 | 0.6636 | 0.6327 |
| 6 | 0.6728 | 0.6512 |
| 7 | 0.6744 | 0.6636 |

`mean_coverage(7)` falls by **0.0108** against the 0.05 allowance. The candidate
seed panel is the control panel carried by logical identity
(`RoundOracle.translatedSeeds`), never re-hashed from candidate paths, so the
comparison is on entities, not paths (§6.2, §9).

### O4 / O6 — pass

| rule | evidence | verdict |
|---|---|---|
| O4 no `src/` production source changed content | `productionDrift` empty | true |
| O6a every control identity maps to at most one current path | `collisions` empty | true |
| O6b no control identity was silently dropped | `dropped` empty | true |
| O6c control logical ids are unique | 81 distinct ids for 81 entries | true |
| O5 parity and the full gate | `ParityTest` passes; `./verify` exit 0, 25/25 tests | pass |

### 2.1 Basis edge drift: what the one-depth `D50` drift actually is

The oracle deliberately measures the candidate basis twice and reports the
difference, so the landmark drift is attributable rather than mysterious:

| quantity | control | round1 |
|---|---|---|
| admitted basis files | 81 | 81 |
| symbols / defines / calls | 816 / 816 / 893 | 816 / 816 / 893 |
| basis use edges, identity-translated (**§6.2 comparison basis**) | 137 | 137 |
| basis use edges, frozen facts re-admitted at candidate paths | 137 | **128** |
| unresolved imports | 507 | 506 |

The re-admitted basis loses 12 edges and gains 3, and **all 15 are starlark
label facts in three BUILD files** (`test/BUILD.bazel`, `experiments/
atlas-parallelism/BUILD.bazel`, `experiments/atlas-swe-explore/BUILD.bazel`).
Every `.flix` and `.java` declaration/import edge is reproduced exactly:
`round1.oracle.json → basis_edge_drift` lists the 12 lost
`test/BUILD.bazel → test/<Cell>/…flix` glob edges and the 3 gained
`*BUILD.bazel → src/Repository.flix` label edges, and nothing else.

The mechanism is that a Flix module import resolves against admitted **paths**
(`<module>.flix` suffix), while a starlark `glob`/label fact resolves against the
file list of the layout it was written for. The round moved the law files and
rewrote `test/BUILD.bazel`, but the round cannot re-acquire facts (§11), so the
frozen `test/BUILD.bazel` content is the *control* content and its glob patterns
still name `build/src/*.flix`. The oracle therefore measures a **conservative
bound**: the round-1 revision's own BUILD text would glob the new locations, so
the true round-1 basis is at least as connected as the 128-edge basis measured
here. Under that pessimistic basis the round still satisfies O2 and O3.

Two consequences are recorded honestly rather than smoothed away:

- The `D50` drift of exactly one depth and the 1.08 pp reach drop are the
  signature consequence of those 15 wiring edges, not of any change in the
  grammar, the atoms, the evaluator or the admitted semantic relations.
- Because `|ΔD50| = 1` is the full §12 S10 allowance, one more round with the
  same D50 drift triggers the stopping rule. Round 2 must not move `D50` again;
  that is now the binding constraint, and it is a constraint on *wiring edge
  cardinality*, which is exactly what a narrower crossing round controls.

## 3. Static work-topology (§4, §5, §6) — the objective moves

Both columns are computed by the same frozen merge rule and region rule; the
candidate column translates every basis endpoint onto its `current_path` by
logical identity, so a move changes region/cell membership and nothing else.

### T3/T4 — cross-region edges and the frozen k-way cut

| k | control cross edges | control fraction | round1 cross edges | round1 fraction |
|---|---|---|---|---|
| 2 | 14 | 0.102 | 14 | 0.102 |
| 3 | 21 | 0.153 | 21 | 0.153 |
| 4 | 33 | **0.241** | 33 | **0.241** |
| 5 | 47 | 0.343 | 47 | 0.343 |
| 6 | 68 | 0.496 | 67 | 0.489 |
| 7 | 81 | 0.591 | 84 | 0.613 |
| 8 | 96 | **0.701** | 96 | **0.701** |
| 9 | 108 | 0.788 | 111 | 0.810 |
| 10 | 123 | 0.897 | 111 | 0.810 |

`k_way_cut(8)`, the primary objective quantity, is **unchanged at 96 of 137
edges (70.1%)**. That is the honest headline for the cut channel: round 1 moved
ownership, not region adjacency. Two structural facts sit behind the flat
answer: the `build-src` region emptied (12 law files left it) and the `tests`
region absorbed them, so at `k = 10` the candidate has only 9 non-empty groups
and `k = 10` degenerates onto `k = 9`.

Cross-region edge ratio `T3` does move: 0.883 → **0.796** (121 → 109 cross-region
edges over the same 137-edge identity-translated basis).

### T5 — the amended K4 ownership-cell cut (`cell_cut_4`)

| quantity | control | round1 |
|---|---|---|
| shared (cross-cell) edges | 35 of 53 | 36 of 65 |
| `cell_cut_4` | 0.660 | **0.554** |
| excluded law-involved edges | 58 | 43 |
| excluded kernel-involved edges | 32 | 34 |
| excluded other-involved edges | 0 | 0 |

This is the round's clearest structural win: the four-cell numerator stays
essentially flat (35 → 36) while the considered denominator grows 53 → 65 and
law-involved edges fall 58 → 43, because the law sources that formed the
horizontally owned `law` surface are now homed in the four cells. The surface
that "had no owner at control" now belongs to cells, so the K4 cut finally
measures what it was defined to measure. Kernel-involved edges rise slightly
(32 → 34), which is the expected pressure on the stable substrate and is the
subject of the later stabilization rounds.

### T6/T7/T8 — coherence, hotspot pressure, independent testability

| quantity | control | round1 |
|---|---|---|
| non-empty regions | 10 | 9 (`build-src` empty, dropped per §4) |
| minimum coherence | 0 (`src-root`) | 0 (`src-root`) |
| region `tests` files / internal edges / coherence | 2 / 0 / 0.00 | 14 / 12 / 0.24 |
| shared hotspots | 17 | 16 |
| maximum hotspot pressure | 7 (`src/ScientificTable.flix`) | 6 (`src/ScientificTable.flix`, `src/ScientificTable/Columns.flix`) |
| independently testable regions (T8) | 4 | 3 |

Hotspot pressure eases at both the top and the tail: `src/ScientificTable.flix`
drops from 7 importing regions to 6, one file leaves the ≥2 hotspot list
(`src/Localization.flix`, whose second importing region was `build-src`), and six
more files lose one importing region (`src/Repository/Structure.flix` 4 → 3,
`src/Atlas/Signature.flix`, `src/Atlas/Signature/Table.flix`, `src/Population.flix`,
`src/Repository/Grit.flix` and `src/Repository/Table.flix` 3 → 2). The T8 count
falls only because the emptied `build-src` region leaves the partition; the
surviving test-side region `tests` keeps its status.

### T9/T10 — the Atlas channel over candidate regions

| quantity | control | round1 |
|---|---|---|
| median file blast | 27 | 27 |
| p90 file blast | 45 | 45 |
| `max_region_blast` | 199 | **139.5** |
| `max_pair_jaccard` | 0.959 | **0.941** |
| pairs at Jaccard ≥ 0.5 | 45 | **36** |

File blast radii are unchanged by construction (a move changes no set
cardinality; `RoundTest` keeps this as a law), while region-level blast and
region-pair overlap both fall: the strongest region-pair resemblance loosens and
nine high-overlap pairs disappear. Region separation, not file-level blast, is
what this round improved.

## 4. BUILD channel (§7): Bazel locality and invalidation

`round1/round1.targets.txt` (467 analyzed targets), `round1/round1.tests.txt`
(23 test targets) and `round1/round1.fanout.txt` are a read-only `bazel query`
of the round-1 revision in its own worktree; the comparative table
`round1/round1.fanout_delta.tsv` is keyed on the logical identity layer, so a
pure move is one row with two paths.

| quantity | control | round1 |
|---|---|---|
| analyzed targets | 437 | 467 |
| independently runnable test targets | 18 | 23 (5 of them the experiment's own) |
| summed cross-cell test invalidation, all test targets | 108 | 154 |
| summed cross-cell test invalidation, `//experiments/...` excluded | **92** | **55 (−40%)** |
| files with reduced / increased / equal cross-cell invalidation (architecture reading) | — | 27 / **2** / 52 |

The raw `all test targets` row rises only because the round instrument's own
five `//experiments/atlas-work-topology:*` test targets live in the same `//...`
universe and depend on `src/Experiment.flix`, `AcquisitionFacts.flix` and the
`src/` core; the same effect lifts every core file's raw invalidation count by
five. That is instrument contamination, not architecture, and the
architecture-only column is the reading that matters. Both are printed in the
artifact; neither is hidden.

Representative per-file rows (`control → round1`, tests / cross-cell / cross-cell
excluding the instrument):

| file | tests | cross-cell | cross-cell (architecture) |
|---|---|---|---|
| `src/Repository.flix` (world) | 9 → 14 | 9 → 10 | **8 → 4** |
| `src/ScientificTable.flix` (kernel) | 6 → 11 | 6 → 10 | **5 → 4** |
| `src/Atlas.flix` (engine) | 4 → 8 | 4 → 6 | **3 → 1** |
| `src/Radii.flix` (engine) | 5 → 9 | 5 → 6 | **4 → 1** |
| `src/Population/Table.flix` (applications) | 6 → 11 | 6 → 9 | **5 → 3** |
| `src/Localization.flix` (applications) | 1 → 1 | 1 → 0 | **1 → 0** |
| `src/native/identity/AttuneIdentity.java` (kernel) | 7 → 12 | 6 → 10 | **5 → 4** |

Two rows regress, and they are the round's real finding for rounds 2–3:

| file | tests | cross-cell (architecture) |
|---|---|---|
| `build/src/Repository.flix` → `test/World/Repository.flix` | 9 → 14 | **0 → 4** |
| `build/src/TestWorlds.flix` → `test/World/TestWorlds.flix` | 2 → 2 | **0 → 2** |

At control every law source sat in the `law` cell together with every law test,
so a shared law helper was never cross-cell. After cell homing those two shared
World law helpers are used by the law targets of *other* cells (Engine, Kernel,
Applications), so any edit to them re-runs tests owned elsewhere. They are the
shared law hotspots the "narrow cell crossings" and "stabilize shared hotspots"
rounds are aimed at, and this measurement is the baseline they start from.

## 5. Outcome classification (§13) and the delta for round 2

- Oracle: **accepted** (§10 satisfied on every rule; §2.1 records that `D50`
  consumed its full allowance).
- Topology: **moved, not yet at target.** `cell_cut_4` 0.660 → 0.554,
  cross-region ratio 0.883 → 0.796, hotspots 17 → 16 with max pressure 7 → 6,
  `max_region_blast` 199 → 139.5, high-overlap pairs 45 → 36; but
  `k_way_cut(8)` is unchanged at 96/137 and one measure (T8) falls
  structurally.
- BUILD: cross-cell test invalidation −40% (92 → 55) excluding the instrument,
  with two shared-World-helper regressions named above.
- Constraints carried into round 2:
  1. `D50` must not move again (S10 is one repeat away from firing), which
     argues for *rewiring* rather than adding edges.
  2. `k_way_cut(8)` is the primary objective and has not moved; the region
     boundary between `tests` and the production regions is where the cut lived
     at control and still lives now.
  3. `test/World/Repository.flix` and `test/World/TestWorlds.flix` are the two
     cross-cell law hotspots introduced by this round.

## 6. Limits of this round's evidence

- No Grit re-acquisition, no provider call and no evaluator change (§11); the
  round re-expresses frozen evidence at candidate paths and reports the
  path-resolution delta it cannot avoid (§2.1).
- The BUILD channel universe is `//...` at both revisions, so the round's own
  test targets are counted; the architecture-only column excludes
  `//experiments/...` explicitly and both numbers are committed.
- The co-change channel (§8) is not re-measured for a round: it is a property of
  the VCS history reachable from the control revision, not of the candidate
  revision's tree, and the frozen `control.cochange.json` remains the only
  co-change artifact.
- The `k = 10` cut degenerates onto `k = 9` at round 1 because only nine regions
  are non-empty after the `build-src` law files moved; the value is reported,
  not silently dropped.
