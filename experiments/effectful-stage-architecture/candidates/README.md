# Candidate A / B / C measurements (M2–M3: kernel, effects, schema/transport split)

Machine-readable measurements of the M2 (Candidate A, B) and M3 (Candidate C)
generations, produced with the frozen instrument of record
(`../scripts/measure_baseline_metrics.sh`, PREREGISTRATION.md §10) and the
identical three channels (`basis`, `kernel`, `work`) plus the BUILD channel. No
metric, partition or protocol was redefined.

| file | revision | change |
|---|---|---|
| `candidate-a.json` | `3efee12b2fb83b62727c9a09fd98c79bf3c5643c` | extract the stable contract kernel (Candidate A) |
| `candidate-b.json` | `38deb855119efe1f8d8c65602d1b65d4883ee01a` | capability effects + handlers + ambient `\ IO` elimination (Candidate B) |
| `candidate-c.json` | `97568f6e269a10c9d92004441860a06371c1212e` | schema/transport split + World decomposition + six-stage typed DAG (Candidate C) |

All three records have `control_commit = 09e27244af9340aa616116a93ea02472e7521ba5`
and `build.skipped = false`, i.e. the BUILD channel was measured, not skipped.

## How they were produced

The instrument is a pure function of the tracked tree and the declared BUILD
graph, so it is evaluated **at the candidate revision itself**, not at the
working tip. `scripts/measure_candidates.sh` (target
`//experiments:measure_candidates`) does that end to end: for each named
candidate it creates a detached git worktree at the frozen revision, runs the
instrument inside it with the record path passed explicitly, and removes the
worktree.

```bash
nix develop --command bazel run \
    //experiments/effectful-stage-architecture:measure_candidates
```

with no `ATTUNE_CANDIDATES` the driver measures the frozen A/B revisions; a
generation is measured by naming its revision explicitly:

```bash
ATTUNE_CANDIDATES="candidate-c=97568f6e269a10c9d92004441860a06371c1212e" \
    nix develop --command bazel run \
    //experiments/effectful-stage-architecture:measure_candidates
```

Because the instrument is run **inside the worktree**, `root` and every
`git ls-files` / `bazel query` reading is that revision's tree, and
`working_commit` names exactly the measured revision. The records are written
into this package in the main checkout (the measurement artifacts are not part
of the measured revision, exactly as with `baseline-metrics.json`); the frozen
`baseline-metrics.json` is never touched.

The driver refuses to write a record whose BUILD channel degraded or was
skipped: a `bazel query` that fails quietly (a full disk, a dead server)
returns an empty dependency set, which would otherwise be recorded as a zero
cross-stage invalidation count.

## Measured deltas against the frozen control

| quantity (channel) | control | Candidate A | Candidate B | Candidate C |
|---|---|---|---|---|
| admitted files | 113 | 116 | 121 | 147 |
| production `.flix` files / LOC (basis) | 25 / 3479 | 27 / 3770 | 30 / 3799 | 50 / 4231 |
| total / production reference edges | 276 / 49 | 278 / 50 | 309 / 65 | 396 / 125 |
| region groups (`K`) | 9 | 9 | 9 | **8** |
| `k_way_cut(K)` (primary, finest region cut) | 0.7138 (197) @ K=9 | 0.7122 (198) @ K=9 | 0.7314 (226) @ K=9 | **0.6540 (259) @ K=8** |
| `k_way_cut(8)` | 0.5616 (155) | 0.5612 (156) | 0.5987 (185) | 0.6540 (259) |
| `mutable_cross_stage_edges` (fraction) | 30 (0.6122) | 31 (0.6200) | 41 (0.6308) | **78 (0.6240)** |
| `shared_writable_hotspots` / max pressure | 16 / 6 | 16 / 6 | 18 / 8 | **22 / 7** |
| stage-partition hotspots | 6 | 6 | 6 | 9 |
| `kernel_files` / `kernel_loc` | 3 / 260 | 4 / 547 | 7 / 584 | 5 / 445 |
| `kernel_loc_fraction` | 0.0747 | 0.1451 | 0.1537 | **0.1052** |
| `kernel_fanin` / `kernel_fanin_share` | 42 / 0.1522 | 44 / 0.1583 | 96 / 0.3107 | 106 / 0.2677 |
| analyzed / test targets | 492 / 30 | 495 / 31 | 510 / 35 | 526 / 38 |
| `cross_stage_test_invalidation` (primary) | 59 | 60 | 151 | **275** |
| `cross_stage_test_invalidation_all_tests` | 260 | 261 | 409 | 686 |
| task conflict graph edges | 4 | 4 | 3 | 2 |
| `T1` / `T∞` / `critical_path_fraction` | 4 / 3 / 0.7500 | 4 / 3 / 0.7500 | 4 / 2 / 0.5000 | 4 / 2 / 0.5000 |

Task change surfaces (`file_count`): acquisition 4→4→3→3, atlas_bitset
4→4→3→3, judge_pareto 11→11→9→7, projection_jsonld 5→5→5→7. The conflict pair
`acquisition|atlas_bitset` disappears at Candidate B (both surfaces fall to the
kernel boundary), which is what lowers `T∞` from 3 to 2. At Candidate C the
pair `acquisition|judge_pareto` also disappears (the acquisition closure
shrinks to 3 files and no longer reaches the judge surface), leaving the two
conflict edges `atlas_bitset–judge_pareto` and
`judge_pareto–projection_jsonld`.

## Reading

- **The parallel-to-change objective moved.** `critical_path_fraction` reaches
  the §9.4 **stretch** value 0.50 (`T∞ = 2`) at Candidate B and holds there at
  Candidate C: with the immutable `src/Kernel/**` boundary excluded from every
  task surface, two of the four benchmark tasks are now conflict-free.
- **The kernel tax is now explicit and visible.** `kernel_loc_fraction`
  0.0747 → 0.1537 and `kernel_fanin_share` 0.1522 → 0.3107: the kernel is the
  shared, read-only thing the rest of the tree reads, which is the intended
  shape (a leaf-level pure contract with high fan-in).
- **The decoupling quantities did not improve, and this is recorded as a
  negative delta, not hidden.** `mutable_cross_stage_edges` 30 → 41,
  `shared_writable_hotspots` 16 → 18, `k_way_cut(9)` 0.7138 → 0.7314 and
  `cross_stage_test_invalidation` 59 → 151 all rise. Two mechanisms:
  the new kernel and handler files are *new nodes with new edges* (including
  the effectful shell's references into the World sources it bridges), and the
  shared law/BUILD source catalogs still declare those leaf files in every cell
  that reads them, so a kernel edit still invalidates other cells' tests.
  Candidate B's hypothesis (ambient `\ IO` leaves the domain modules, the
  World↔IO crossing narrows) is realized in the *source* graph — the
  per-file breakdown attributes only a small part of the BUILD-channel rise to
  the new kernel files (`src/Kernel.flix` 14 and `src/Kernel/Contract.flix` 11
  of 151 come from the pre-existing shared catalogs, not from the new files) —
  but the frozen BUILD channel measures declared `srcs` sharing, which
  Candidate C's schema/transport split and Candidate D's fine-grained stage
  packages exist to fix.

### Candidate C (M3)

- **The primary cut quantity moves to `k_way_cut(8)`, and the `K` change is
  recorded.** The frozen region partition (`attuneflix-regions-v1`) has a
  `tables` region keyed to `src/ScientificTable.flix` / `src/ScientificTable/*`.
  Candidate C's schema/transport split renames that surface to
  `src/Scientific.flix` / `src/Scientific/*`, which the frozen rules classify
  under `src/*` → `src-root`; the `tables` region is therefore empty and
  `region_groups` falls 9 → 8. Per PREREGISTRATION.md §3.3 the primary
  quantity is `k_way_cut(K)`, the cut at the finest frozen partition, so
  Candidate C's primary is `k_way_cut(8)`. At the *same* `k = 8` the cut rises
  0.5616 (155) → 0.6540 (259), so this is not a definitional win: it is a
  measured regression at the shared finest resolution. The full M3 region
  trajectory is `k = 2..8`: `0.0278, 0.0707, 0.1212, 0.2348, 0.3510, 0.4672,
  0.6540`.
- **The M3 decoupling quantities worsen further, again recorded as negative
  deltas.** `mutable_cross_stage_edges` 41 → 78, `shared_writable_hotspots`
  18 → 22, stage-partition hotspots 6 → 9, and
  `cross_stage_test_invalidation` 151 → 275. The mechanism is the same as at
  Candidate B, at larger scale: the split multiplies production files
  (30 → 50) and production reference edges (65 → 125), and every new leaf file
  is still declared by the shared `test/**`/BUILD source catalogs, so a
  stage-local edit still invalidates the other cells' tests. This namespace
  locality debt is exactly what Candidate D's fine-grained `//src/kernel:*` /
  `//src/stage/*` packages exist to pay down; Candidate C alone was not
  expected to move it.
- **The kernel shrinks relative to the split surface while staying the shared
  leaf.** `kernel_files` 7 → 5 and `kernel_loc` 584 → 445
  (`kernel_loc_fraction` 0.1537 → 0.1052), with `kernel_fanin_share` still high
  at 0.2677: the six-stage decomposition moved the schema/value types into the
  kernel but left the effectful shell as the high-fan-in read-only boundary.
- **The stretch parallel objective holds.** `critical_path_fraction` stays
  0.5000 (`T∞ = 2`, `T1 = 4`). The conflict pair
  `acquisition|judge_pareto` (present at control, A and B) disappears at
  Candidate C; both acquisition-side tasks are now conflict-free.
- **No oracle concession was required.** O5 (`//test/Engine:core_parity_test`
  exact parity) and the byte-identical depth-7 signature oracle
  (`//experiments/atlas-work-topology:control_signature_artifacts_test`,
  `D50 = 4`, depth-7 reach 0.6636) both pass at the measured revision; O7 holds
  (`//:flix_loc_law_test`: 4766 code lines / 72 files, largest
  `src/Radii/Evaluate.flix` (293) < 400).

Neither candidate is rejected: per PREREGISTRATION.md §7, a candidate that
passes O1-O9 but does not improve (or worsens) a primary quantity is recorded
with its measured deltas as a negative result.
