# Candidate A / B / C / D measurements (M2–M4: kernel, effects, schema/transport split, staged Bazel packages)

Machine-readable measurements of the M2 (Candidate A, B), M3 (Candidate C) and
M4 (Candidate D) generations, produced with the frozen instrument of record
(`../scripts/measure_baseline_metrics.sh`, PREREGISTRATION.md §10) and the
identical three channels (`basis`, `kernel`, `work`) plus the BUILD channel. No
metric formula, admission rule, oracle or region partition was redefined.
Candidate D adds a supplementary, clearly-labelled stage-partition reading
(PREREGISTRATION.md §16, `*_dagref` fields); the frozen §2.3 partition remains
the metric of record and is the one the tables below quote.

| file | revision | change |
|---|---|---|
| `candidate-a.json` | `3efee12b2fb83b62727c9a09fd98c79bf3c5643c` | extract the stable contract kernel (Candidate A) |
| `candidate-b.json` | `38deb855119efe1f8d8c65602d1b65d4883ee01a` | capability effects + handlers + ambient `\ IO` elimination (Candidate B) |
| `candidate-c.json` | `97568f6e269a10c9d92004441860a06371c1212e` | schema/transport split + World decomposition + six-stage typed DAG (Candidate C) |
| `candidate-d.json` | `37ceaa5a495084642dd4b6dfd874a179b0bea491` | mirror the stage DAG in Bazel packages + slice the law catalogs (Candidate D) |

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

| quantity (channel) | control | Candidate A | Candidate B | Candidate C | Candidate D |
|---|---|---|---|---|---|
| admitted files | 113 | 116 | 121 | 147 | 162 |
| production `.flix` files / LOC (basis) | 25 / 3479 | 27 / 3770 | 30 / 3799 | 50 / 4231 | **50 / 4231** (unchanged) |
| total / production reference edges | 276 / 49 | 278 / 50 | 309 / 65 | 396 / 125 | **396 / 125** (unchanged) |
| region groups (`K`) | 9 | 9 | 9 | **8** | 8 |
| `k_way_cut(K)` (primary, finest region cut) | 0.7138 (197) @ K=9 | 0.7122 (198) @ K=9 | 0.7314 (226) @ K=9 | **0.6540 (259) @ K=8** | 0.6540 (259) @ K=8 |
| `k_way_cut(8)` | 0.5616 (155) | 0.5612 (156) | 0.5987 (185) | 0.6540 (259) | 0.6540 (259) |
| `mutable_cross_stage_edges` (fraction) | 30 (0.6122) | 31 (0.6200) | 41 (0.6308) | **78 (0.6240)** | 78 (0.6240) |
| `shared_writable_hotspots` / max pressure | 16 / 6 | 16 / 6 | 18 / 8 | **22 / 7** | 22 / 7 |
| stage-partition hotspots / max pressure | 6 / 3 | 6 / 3 | 6 / 3 | 9 / 4 | 9 / 4 |
| `kernel_files` / `kernel_loc` | 3 / 260 | 4 / 547 | 7 / 584 | 5 / 445 | 5 / 445 |
| `kernel_loc_fraction` | 0.0747 | 0.1451 | 0.1537 | **0.1052** | 0.1052 |
| `kernel_fanin` / `kernel_fanin_share` | 42 / 0.1522 | 44 / 0.1583 | 96 / 0.3107 | 106 / 0.2677 | 106 / 0.2677 |
| analyzed / test targets | 492 / 30 | 495 / 31 | 510 / 35 | 526 / 38 | **575 / 44** |
| `cross_stage_test_invalidation` (primary) | 59 | 60 | 151 | **275** | **253** (−8.0%) |
| `cross_stage_test_invalidation_all_tests` | 260 | 261 | 409 | 686 | 664 (−3.2%) |
| `mutable_cross_stage_edges` (`_dagref`, §16) | 30 | 30 | 39 | 60 | **60** |
| `cross_stage_test_invalidation` (`_dagref`, §16) | 59 | 59 | 148 | 239 | **173** |
| task conflict graph edges | 4 | 4 | 3 | 2 | 2 |
| `T1` / `T∞` / `critical_path_fraction` | 4 / 3 / 0.7500 | 4 / 3 / 0.7500 | 4 / 2 / 0.5000 | 4 / 2 / 0.5000 | 4 / 2 / 0.5000 |

The `_dagref` rows are the supplementary PREREGISTRATION.md §16 reading, given
for control and for every candidate by the same re-keyed path function; the
control is 30/59 under both keyings (§16 proves no control path matches an added
rule), so the rows are directly comparable and the frozen rows stay primary.

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

### Candidate D (M4)

Candidate D restructures the **Bazel graph only**. Every production `.flix`
file keeps its path and content, so every BASIS, kernel and WORK number is
byte-identical to Candidate C (same 50 production files / 4231 LOC, same
396/125 reference edges, same `k_way_cut(8)` 0.6540, same `T∞ = 2`). That
identity is the preservation evidence for the generation: the change is
ownership wiring, not meaning.

What moved is the BUILD channel. Each stage now owns a package
(`//src/kernel`, `//src/transport/parquet`, `//src/world`, `//src/engine`,
`//src/applications`, `//src/stage{,/acquire,/world,/prior,/atlas,/candidate_set,/judge,/projection,/pipeline}`,
`//src/research`) whose source catalogs the cell law packages compose, and the
single root LOC law is sliced per stage and per cell (7 law targets instead of
1, so `test_targets` 38 → 44).

- **The BUILD metric improves, but far short of the threshold.**
  `cross_stage_test_invalidation` falls **275 → 253 (−8.0%)**, and the
  all-tests variant 686 → 664. Against the frozen control (59) the M4 number is
  **4.3× higher**, so the §9.4 minimum criterion (≤ 18) and the validation
  contract's `≤ 25` are not met, and the `_dagref` reading (173) does not change
  that: the direction is negative under both keyings.
- **Mechanism (why the threshold is out of reach for this surface).** The
  quantity is `Σ_f |{ tests t : t declares f, stage(t) ≠ stage(f) }|` over the
  admitted file set. A Flix test target compiles its sources as one
  whole-program unit, so a cell law test necessarily declares the whole
  upstream closure it exercises (`//test/Applications:localization_sandwich_test`
  declares the World admission modules, the Engine, the kernel schema and the
  Parquet transport: 27 of its declared files are outside `applications`). The
  immutable kernel is read by every downstream cell by design (O1-O6), so with
  44 test targets the floor of the aggregate is on the order of
  `Σ_cells (files upstream of the cell)`, i.e. several hundred — orders above
  25. Reducing it further would require test targets that do not compile their
  upstream closure, which whole-program Flix compilation does not offer.
- **The behavioural half of VAL-BAZEL-002 does hold, and is demonstrable.** A
  stage-local edit now invalidates only the law targets whose stage closure
  contains it, and those are exactly its downstream dependents. With the root
  `//:flix_loc_law_test` no longer a single target over the whole surface, a
  change under `//src/stage/atlas` re-runs the Atlas/Pipeline laws, not the
  Kernel, World or Applications laws:

```bash
nix develop --command bazel query \
  'kind(".*_test", rdeps(//..., //src/stage/atlas:flix_sources))'
```

  which returns exactly three targets —

```text
//test/Applications:stage_pipeline_test
//test/Engine:atlas_grammar_test
//test/Engine:flix_loc_law_test
```

  — all Engine or Applications stage (i.e. downstream of node 3B), while every
  `//test/Kernel:*`, `//test/World:*` and `//test/Engine:atlas_signature_table_test`
  target is disjoint from it (that law reads the grammar tables directly, not
  the Stage 3B node). `//src/stage/judge` behaves the same way: its three
  dependents (`//test/Applications:localization_sandwich_test`,
  `//test/Applications:stage_pipeline_test`,
  `//test/Applications:flix_loc_law_test`) are all Applications stage, and no
  Kernel, World or Engine law target is invalidated.
- **Classification.** `mutable_cross_stage_edges` (78; `_dagref` 60) and
  `cross_stage_test_invalidation` (253; `_dagref` 173) both miss the §9.4
  minimum, `shared_writable_hotspots` (22) misses the strong criterion, while
  the stretch quantities `critical_path_fraction` (0.5000) and
  `kernel_loc_fraction` (0.1052) are met. Per PREREGISTRATION.md §12 this is
  **Outcome C** (inconclusive / trade-off) on the frozen measurements, and the
  generation is recorded with its measured deltas rather than smoothed into a
  success.

## Preserved artifacts — the frozen failure record (M5)

Everything above is a **preserved experimental artifact**, not a working file.
The failed generations are the finding (mission.md §1, user ruling 2026-09-27),
so these records are read-only evidence: they are never regenerated, retuned,
smoothed, or optimized away, and no later generation overwrites them. Each
metric record is bound to a revision that resolves to an ancestor of the
current tip.

### Revision bindings

| artifact | `working_commit` (measured tree) | ancestor of HEAD | status |
|---|---|---|---|
| `../CONTROL.md` | control specimen `09e27244af9340aa616116a93ea02472e7521ba5` | yes | frozen control specimen record (VAL-CTRL-001) |
| `../baseline-metrics.json` | `d766448b9c6108443f262e51d528630ebb6f3c48` | yes | frozen **control baseline** (`control_commit` = `09e27244af9340aa616116a93ea02472e7521ba5`) |
| `candidate-a.json` | `3efee12b2fb83b62727c9a09fd98c79bf3c5643c` | yes | **preserved negative result** — preregistered Outcome C |
| `candidate-b.json` | `38deb855119efe1f8d8c65602d1b65d4883ee01a` | yes | **preserved negative result** — preregistered Outcome C |
| `candidate-c.json` | `97568f6e269a10c9d92004441860a06371c1212e` | yes | **preserved negative result** — preregistered Outcome C |
| `candidate-d.json` | `37ceaa5a495084642dd4b6dfd874a179b0bea491` | yes | **preserved negative result** — preregistered Outcome C |
| `reproduction-head.json` | `d8d9b037180b6814bdf94b4cfee5de407b8888ce` | — (HEAD when measured) | reproducibility evidence for `candidate-d.json` |
| `reproduction-head-diff.json` | `d8d9b037180b6814bdf94b4cfee5de407b8888ce` | — (HEAD when measured) | machine-readable diff of the fresh run vs `candidate-d.json` |

All five metric records carry the identical `control_commit`
`09e27244af9340aa616116a93ea02472e7521ba5`, so they are five readings of one
frozen control specimen. The control record is the **baseline**, not a failure;
Candidates A, B, C and D are the four preserved negative results. Nothing here
is a candidate that "did not count": per PREREGISTRATION.md §7 a generation that
passes O1–O9 yet does not improve (or worsens) a primary quantity is recorded
with its measured deltas as a negative result, and it is retained.

The frozen control evidence of the *earlier* work-topology experiment
(`experiments/atlas-work-topology/control/`, whose `control.revision.txt` names
`eca979f5`) is a separate, also byte-untouched artifact set; it is not the
control of this experiment and is never re-measured by the instrument here.

### Why "preregistered Outcome C"

PREREGISTRATION.md §9.4 preregisters the minimum serious-success criteria —
`mutable_cross_stage_edges` reduced by at least 50% (30 → ≤ 15) and
`cross_stage_test_invalidation` ≤ 18 — and §12 defines the outcome branches
(A strong success / B serious success / C inconclusive or trade-off). Candidate
D measures **78** mutable cross-stage edges and **253** cross-stage
invalidations against the control's 30 and 59, so the minimum criteria are not
met and the generation is classified **Outcome C**. The supplementary §16
`_dagref` keying (60 edges / 173 invalidations) is negative in the same
direction, so the classification does not depend on the keying. The failed
candidates are never discarded and the preregistered targets are never
reinterpreted after seeing the numbers; they are carried forward unmet to the
hill-climb milestones (VAL-HILL-003).

### Revision-binding and byte-integrity check (run at HEAD `d8d9b03`)

```bash
# 1. every record's revision resolves and is an ancestor of the tip
git rev-parse --verify 09e27244af9340aa616116a93ea02472e7521ba5^{commit}
for r in d766448b9c6108443f262e51d528630ebb6f3c48 \
         3efee12b2fb83b62727c9a09fd98c79bf3c5643c \
         38deb855119efe1f8d8c65602d1b65d4883ee01a \
         97568f6e269a10c9d92004441860a06371c1212e \
         37ceaa5a495084642dd4b6dfd874a179b0bea491; do
    git merge-base --is-ancestor "$r" HEAD && echo "$r ancestor of HEAD"
done

# 2. frozen evidence is byte-untouched: the working-tree blob hash equals the
#    committed blob hash for every frozen file
for f in $(git ls-files .attune experiments/atlas-work-topology/control \
                     experiments/effectful-stage-architecture/baseline-metrics.json \
                     'experiments/effectful-stage-architecture/candidates/candidate-*.json'); do
    [ "$(git hash-object "$f")" = "$(git rev-parse "HEAD:$f")" ] \
        && echo "MATCH $f" || echo "DIFF $f"
done

# 3. no uncommitted or untracked change anywhere
git status --porcelain        # empty
```

Result at HEAD `d8d9b037180b6814bdf94b4cfee5de407b8888ce`: every measured
revision is an ancestor of HEAD; all **312** `.attune/**` files, all **13**
`experiments/atlas-work-topology/control/*` files, `baseline-metrics.json` and
`candidate-{a,b,c,d}.json` **hash MATCH** their committed blobs (zero
`DIFF`); and the working tree is clean.

### Reproducibility of `candidate-d.json` at HEAD

`reproduction-head.json` is a fresh run of the instrument of record **at HEAD**,
written to a **new** path — the committed records are never overwritten:

```bash
source /etc/profile.d/nix.sh
nix develop --command bash \
  experiments/effectful-stage-architecture/scripts/measure_baseline_metrics.sh \
  experiments/effectful-stage-architecture/candidates/reproduction-head.json
```

Every differing leaf path between the fresh record and the committed one:

```bash
jq -n --slurpfile a candidates/reproduction-head.json \
      --slurpfile b candidates/candidate-d.json '
  def flat: [paths(scalars) as $p | {k: ($p|map(tostring)|join(".")), v: getpath($p)}];
  ($a[0]|flat) as $x | ($b[0]|flat) as $y |
  [ $x[] as $e | ($y[] | select(.k == $e.k)) as $f | select($e.v != $f.v)
    | {path: $e.k, fresh_head: $e.v, candidate_d: $f.v} ]'
```

Reproduction gate: after deleting the three permitted metadata fields the two
records must be **byte-identical**:

```bash
jq -S 'del(.recorded_at_utc,.working_commit,.channels.build.analyzed_targets)' \
   candidates/reproduction-head.json > /tmp/a.norm.json
jq -S 'del(.recorded_at_utc,.working_commit,.channels.build.analyzed_targets)' \
   candidates/candidate-d.json      > /tmp/b.norm.json
diff -u /tmp/b.norm.json /tmp/a.norm.json      # empty == gate passed
```

Result (fresh run `2026-09-27T03:58:34Z` at `d8d9b03`): the whole-record diff
contains exactly **three** differing leaf paths, all permitted —

| path | fresh HEAD | `candidate-d.json` |
|---|---|---|
| `recorded_at_utc` | `2026-09-27T03:58:34Z` | `2026-09-26T23:36:40Z` |
| `working_commit` | `d8d9b037180b6814bdf94b4cfee5de407b8888ce` | `37ceaa5a495084642dd4b6dfd874a179b0bea491` |
| `channels.build.analyzed_targets` | `576` | `575` |

and the normalised records are byte-identical (`diff` empty). `analyzed_targets`
is the `bazel query //...` target census, not a metric; it rises by one because
the M4 fix `d8d9b037` added the `//src/world:acquire` filegroup, and no metric
channel reads it. Every metric channel reproduces exactly:

| channel | field | recorded | fresh HEAD |
|---|---|---|---|
| BASIS | `admitted_files` | 162 | 162 |
| BASIS | `production_flix_files` / `production_flix_loc` | 50 / 4231 | 50 / 4231 |
| BASIS | `total_reference_edges` / `production_reference_edges` | 396 / 125 | 396 / 125 |
| BASIS | `k_way_cut` (k = 2…8) | 259 @ k8 = 0.654040 | identical |
| BASIS | `mutable_cross_stage_edges` / `_dagref` | 78 / 60 | 78 / 60 |
| BASIS | `shared_writable_hotspots` / `max_hotspot_pressure` | 22 / 7 | 22 / 7 |
| KERNEL | `kernel_files` / `kernel_loc` / `kernel_fanin` | 5 / 445 / 106 | 5 / 445 / 106 |
| KERNEL | `kernel_loc_fraction` / `kernel_fanin_share` | 0.105176 / 0.267677 | identical |
| BUILD | `cross_stage_test_invalidation` / `_dagref` / all-tests | 253 / 173 / 664 | 253 / 173 / 664 |
| BUILD | `test_targets` | 44 | 44 |
| WORK | `T_one` / `T_inf` / `critical_path_fraction` | 4 / 2 / 0.500000 | 4 / 2 / 0.500000 |
| WORK | task `file_count`s and `conflict_graph` | 3/3/7/7, 2 edges | identical |

So the regression is **reproducible**: it is a property of the tree at Candidate
D, not an artifact of the measurement environment. The machine-readable form of
this comparison is `reproduction-head-diff.json`.
