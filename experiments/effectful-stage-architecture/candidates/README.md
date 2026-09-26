# Candidate A / B measurements (M2 — kernel and effects)

Machine-readable measurements of the two M2 candidate generations, produced with
the frozen instrument of record (`../scripts/measure_baseline_metrics.sh`,
PREREGISTRATION.md §10) and the identical three channels (`basis`, `kernel`,
`work`) plus the BUILD channel. No metric, partition or protocol was redefined.

| file | revision | change |
|---|---|---|
| `candidate-a.json` | `3efee12b2fb83b62727c9a09fd98c79bf3c5643c` | extract the stable contract kernel (Candidate A) |
| `candidate-b.json` | `38deb855119efe1f8d8c65602d1b65d4883ee01a` | capability effects + handlers + ambient `\ IO` elimination (Candidate B) |

Both records have `control_commit = 09e27244af9340aa616116a93ea02472e7521ba5`
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

Both records in this directory are the output of that command. Later
generations are added without editing the driver:

```bash
ATTUNE_CANDIDATES="candidate-c=<rev> candidate-d=<rev>" \
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

| quantity (channel) | control | Candidate A | Candidate B |
|---|---|---|---|
| admitted files | 113 | 116 | 121 |
| production `.flix` files / LOC (basis) | 25 / 3479 | 27 / 3770 | 30 / 3799 |
| total / production reference edges | 276 / 49 | 278 / 50 | 309 / 65 |
| `k_way_cut(9)` (primary, count) | 0.7138 (197) | 0.7122 (198) | 0.7314 (226) |
| `mutable_cross_stage_edges` (fraction) | 30 (0.6122) | 31 (0.6200) | **41 (0.6308)** |
| `shared_writable_hotspots` / max pressure | 16 / 6 | 16 / 6 | **18 / 8** |
| stage-partition hotspots | 6 | 6 | 6 |
| `kernel_files` / `kernel_loc` | 3 / 260 | 4 / 547 | 7 / 584 |
| `kernel_loc_fraction` | 0.0747 | 0.1451 | **0.1537** |
| `kernel_fanin` / `kernel_fanin_share` | 42 / 0.1522 | 44 / 0.1583 | **96 / 0.3107** |
| analyzed / test targets | 492 / 30 | 495 / 31 | 510 / 35 |
| `cross_stage_test_invalidation` (primary) | 59 | 60 | **151** |
| `cross_stage_test_invalidation_all_tests` | 260 | 261 | 409 |
| task conflict graph edges | 4 | 4 | 3 |
| `T1` / `T∞` / `critical_path_fraction` | 4 / 3 / 0.7500 | 4 / 3 / 0.7500 | **4 / 2 / 0.5000** |

Task change surfaces (`file_count`): acquisition 4→4→3, atlas_bitset 4→4→3,
judge_pareto 11→11→9, projection_jsonld 5→5→5. The conflict pair
`acquisition|atlas_bitset` disappears at Candidate B (both surfaces fall to the
kernel boundary), which is what lowers `T∞` from 3 to 2.

## Reading

- **The parallel-to-change objective moved.** `critical_path_fraction` reaches
  the §9.4 **stretch** value 0.50 (`T∞ = 2`) at Candidate B: with the immutable
  `src/Kernel/**` boundary excluded from every task surface, two of the four
  benchmark tasks are now conflict-free.
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
- **No oracle concession was required.** O5 (`//test/Engine:core_parity_test`
  exact parity and `./verify` 35/35), O7 (LOC law: 4091 code lines / 46 files,
  largest 339 < 400) and the byte-identical depth-7 signature oracle
  (`//experiments/atlas-work-topology:control_signature_artifacts_test`,
  `D50 = 4`, depth-7 reach 0.6636) all hold at both revisions.

Neither candidate is rejected: per PREREGISTRATION.md §7, a candidate that
passes O1-O9 but does not improve (or worsens) a primary quantity is recorded
with its measured deltas as a negative result.
