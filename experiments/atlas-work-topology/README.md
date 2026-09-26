# Atlas work-topology & K4 experiment

The preregistration (`PREREGISTRATION.md`) binds this experiment; read it first.
This directory holds the control specimen and every later round's measurement.

## Control acquisition (VAL-CONTROL-001 / -002 / -003)

Command of record:

```bash
nix develop --command bazel run //experiments/atlas-work-topology:acquire
```

It materializes the frozen control revision
`eca979f524661cbe400d22b90c7e3c305b32052e` in an isolated git worktree at
`/tmp/attuneflix-control` (never the live worktree) and runs the repository's own
polyglot acquisition path:

```text
source -> Grit -> Repository.Grit.Fact -> Repository.admit -> Repository.World
```

The one acquisition seam is reused unchanged from
`//experiments/atlas-parallelism` (`AcquisitionDriver`/`AcquisitionFacts`); this
experiment adds only `ControlAcquisition.flix`, which derives the inclusion
record with the closure's own language table (`Repository.Grit.language`) and
provides the determinism check. Bash is only `bazel run` plumbing (worktree
checkout + raw `git ls-tree`).

## Frozen artifacts (`control/`)

| artifact | schema | content |
|---|---|---|
| `control.files.txt` | text | the admitted path list, sorted |
| `control.revision.txt` | text | the 40-character control revision hash |
| `control.sources.parquet` | `attuneflix-grit-sources-v2` | path, sha256, byte_length, language |
| `control.facts.parquet` | `attuneflix-grit-facts-v2` | path, source_sha256, language, program, kind, start_byte, end_byte, value |
| `control.signatures.parquet` | `attune-atlas-signature-observations-v1` | one row per seed × logical route through depth 7 |
| `control.summaries.parquet` | `attune-atlas-signature-summary-v1` | reductions + physical work + mixing landmarks |
| `control.identity_map.json` | JSON | logical_id, control_path, current_path, control_region, ownership_cell |

81 admitted files (48 `.flix`, 15 `.bazel`, 11 `.java`, 7 `.bzl`); 6,254 facts;
an admitted world of 816 symbols, 137 import edges, 893 call edges.

## Control signatures (VAL-SIGNATURE-001 / -002 / -003)

Command of record:

```bash
nix develop --command bazel run //experiments/atlas-work-topology:compute_control_signatures
```

It re-admits the committed control evidence through ordinary `Repository.admit`,
evaluates the frozen composition-only Atlas family (`atlas-composition-depth7-v1`,
3,279 routes per declared seed domain) over the frozen `atlas-signature-seeds-v1`
panel at depth 7 (16 seeds → 52,464 observation rows), derives the mixing
landmarks (`D50`, `D80`, `D90`, `D95`), and writes the logical identity map of
§9. `ControlSignature.flix` owns the curve and landmarks, `ControlIdentity.flix`
the §9 identity, and `ControlMap.flix` the §4 region, §5 cell and surface
protocols. No grammar, atom or evaluator is added.

Measured at control: `D50 = 3`, `D80 = D90 = D95 = none` (encoded `8`),
depth-7 mean file reach `0.674` over the eight File seeds; 81 distinct logical
identities.

Independent verification:

```bash
nix develop --command bazel test \
  //experiments/atlas-work-topology:control_signature_test \
  //experiments/atlas-work-topology:control_signature_artifacts_test --config=buildbuddy-rbe
```

`control_signature_test` is the provenance and protocol law suite (synthetic
worlds: the depth response changes when an admitted relation or the program
family changes; landmarks are monotone; region/cell/identity rules). The
artifacts test independently re-derives the landmarks and the identity map from
the committed evidence and asserts they equal the committed artifacts exactly.

## Control work-topology (VAL-TOPOLOGY-001 / -002 / -004)

Command of record:

```bash
nix develop --command bazel run //experiments/atlas-work-topology:measure_control_topology
```

It re-admits the committed control evidence, computes the static work-topology
and the co-change work graph, and writes:

| artifact | content |
|---|---|
| `control/control.topology.json` | BASIS cuts `k=2..10`, cross-region ratio, per-region coherence and independence, hotspot pressure, the `other` decomposition, the K4 `cell_cut_4`, and the ATLAS depth-<=2 region-pair Jaccard and blast radii |
| `control/control.cochange.json` | raw / normalized / line-weighted file-pair co-change, strongest pairs, per-region share, cross-region ratio, and the co-change 8-way cut |
| `control/control.cochange_history.txt` | the raw `git log --numstat --no-renames` extract the model is computed from |

Measured at control (the mission scoping prior `88/125 = 70.4%` for the 8-way cut
and `31/125 = 24.8%` for the 4-way cut is reproduced within the control
revision's larger admitted graph):

- `use_edges = 137` (the control revision admits 81 files versus the parallelism
  cleaned revision's 75, so both numerator and denominator grow).
- Cut curve (cross-region edges / 137): `k=2` 14, `k=3` 21, `k=4` **33 (24.1%)**,
  `k=5` 47, `k=6` 68, `k=7` 81, `k=8` **96 (70.1%)**, `k=9` 108, `k=10` 123.
- K4 ownership-cell cut `cell_cut_4 = 0.660` (35 of 53 four-cell internal edges);
  kernel- and law-involved edges (32 and 58 of the 137) are excluded from it and
  counted separately (the horizontal `law` surface is large and unowned at
  control).
- 17 shared hotspots, maximum hotspot pressure 7; median file blast 27, p90 45;
  `max_pair_jaccard` 0.959 with 45 pairs at Jaccard >= 0.5.
- Co-change: 66 of 103 commits touch admitted files, 692 pairs, raw mass 1127,
  cross-region raw ratio 0.734. The history is small and single-author, so this
  is a weak proxy, reported as such.

Independent verification:

```bash
nix develop --command bazel test //experiments/atlas-work-topology:control_topology_test \
  //experiments/atlas-work-topology:control_topology_artifacts_test --config=buildbuddy-rbe
```

`ControlTopology.flix` owns the measurement, `ControlTopologyJson.flix` its JSON
rendering, `ControlCoChange.flix` the work graph, and `ControlMeasure.flix` the
`measure`/`verify` commands.

## Bazel build locality (VAL-TOPOLOGY-003)

Command of record:

```bash
nix develop --command bash experiments/atlas-work-topology/scripts/measure_bazel_locality.sh control
```

It is a read-only `bazel query` of the control revision's isolated worktree and
writes `control/control.targets.txt` (437 analyzed targets),
`control/control.tests.txt` (18 test targets) and `control/control.fanout.txt`
(per admitted file: the `srcs` fanout, the direct-dependent count and the
test-target invalidation). The control revision loads the full `//...` universe
in its worktree (the older baseline's `crate_universe` limitation does not
reproduce here); the universe actually queried is recorded in the artifact
header, and `BAZEL_LOCALITY_UNIVERSE` overrides it for revisions that do need the
Rust-free substitute. The BUILD graph agrees with the basis hub finding: each
core file compiles into 7-12 independent actions while every law target
re-declares the core `srcs`, so a core edit invalidates much of the law suite.

## Determinism (VAL-CONTROL-003)

```bash
nix develop --command bazel test //experiments/atlas-work-topology:control_reproducibility_test --config=buildbuddy-rbe
```

Re-acquires the same worktree twice, re-admits the committed evidence through
`Repository.admit`, and asserts byte-for-byte equality of both runs against each
other and against the committed evidence, plus exact inclusion-record and
revision equality. All comparison logic runs in Flix (`ControlAcquisition.flix`).

## Round 1 — cell-owned law and build surfaces (VAL-HC1-002 / -003)

Round 1 is the candidate revision `52da6424…`; its delta report is
`rounds/round1.md` and its artifacts are under `round1/`.

Commands of record:

```bash
nix develop --command bazel run //experiments/atlas-work-topology:measure_topology --config=buildbuddy-rbe -- round1
nix develop --command bash experiments/atlas-work-topology/scripts/measure_bazel_locality.sh round1
bash experiments/atlas-work-topology/scripts/fanout_delta.sh control round1
```

`measure_topology <role>` derives the role's admitted manifest and source
manifest from the revision recorded in `<role>/<role>.revision.txt`, re-admits
the frozen control facts (no Grit, no re-acquisition) and writes:

| artifact | content |
|---|---|
| `round1/round1.files.txt`, `round1/round1.sources.txt` | the round revision's admitted paths and source hashes by the one §2 admission rule |
| `round1/round1.identity_map.json` | the §9 post-round identity map: movement classification (stable/modified/moved/dropped/new), regions, and the round's ownership cell per file |
| `round1/round1.topology.json` | candidate BASIS cuts `k=2..10`, cross-region ratio, per-region coherence/independence, hotspot pressure, the amended `cell_cut_4`, and the candidate ATLAS region overlap and blast radii |
| `round1/round1.oracle.json` | the §10 oracle: grammar invariance, mixing landmarks, the depth 1..7 reach curve, identity verdicts, the basis graph and the explicit basis-edge drift |

`RoundIdentity.flix` owns the movement/identity classification,
`RoundTopology.flix` the candidate static topology (region- and cell-partitioned
by the §5 amendment), `RoundOracle.flix` the §10 rules, `RoundJson.flix` the
rendering and `RoundMeasure.flix` the commands. `ControlMap.roundCellOf` is the
dated §5 amendment; `ControlMap.cellOf` stays frozen for control.

Measured delta (details and every number in `rounds/round1.md`):

- Oracle **passes** on every rule: `D50` 3 → 4 (exactly the allowance), `D80`/
  `D90`/`D95` unchanged, depth-7 reach 0.674 → 0.664 (−0.0108 of the 0.05
  allowance). The whole landmark drift is 15 starlark label/glob edges in three
  BUILD files; no `.flix`/`.java` declaration or import edge changes.
- Topology moves: `cell_cut_4` 0.660 → 0.554, cross-region ratio 0.883 → 0.796,
  hotspots 17 → 16, max pressure 7 → 6, `max_region_blast` 199 → 139.5, high
  overlap pairs 45 → 36. `k_way_cut(8)`, the primary objective, is unchanged at
  96/137 and the two shared World law helpers become the round's cross-cell
  hotspots.
- BUILD channel: 437 → 467 analyzed targets, 18 → 23 test targets; cross-cell
  test invalidation 92 → 55 (−40%) with the experiment's own test targets
  excluded from the universe comparison.

Independent verification:

```bash
nix develop --command bazel test //experiments/atlas-work-topology:round_test \
  //experiments/atlas-work-topology:round1_artifacts_test --config=buildbuddy-rbe
```

`round_test` is the round's protocol/provenance law suite (identity
classification, the amended cell cut, the translated comparison basis, the
identity-carried seed panel, the reported basis-edge drift, T8 under the frozen
test-side rule, grammar invariance). `round1_artifacts_test` re-derives the
identity map, topology and oracle from the committed control evidence and
asserts byte-for-byte equality with the committed `round1/` artifacts.

## Rounds 2 and 3 — narrow crossings and shared-owner stabilization

The round-2 revision `10f3a212…` re-homed the two shared law fixtures onto the
horizontal law surface; the round-3 revision `73b8709…` moved the shared
`build/flix.bzl` rule definition to `test/build/flix.bzl` and restored
`src/BUILD.bazel` byte-identically. Neither round moved `k_way_cut(8)`
(70.07% → 69.34%), so §13 classifies the run Outcome C. Deltas, verdicts and
gotchas: `rounds/round23.md`; the artifacts are under `round2/` and `round3/`.

## Round 4 — typed artifact and build-cache boundaries

The two expensive scientific stages (the depth 1..7 signature derivation and the
static work-topology / co-change measurement) are now declared cacheable Bazel
actions over their exact typed input boundary, with their typed artifacts as
declared outputs; the frozen control evidence is declared as four per-stage
artifact boundaries instead of one 10-file list, and
`artifact_boundary_test` consumes the declared artifacts and checks them
byte-for-byte against the frozen evidence. Details, the cache-hit logs and the
declared input closures: `artifact-boundaries.md`.

