# Rounds 2 & 3 — narrow cell crossings and shared build/law-surface stabilization (Hill-Climb delta report)

| | round 2 | round 3 |
|---|---|---|
| role | `round2` | `round3` |
| candidate revision | `10f3a212d0c4d10a6c06a8f1570b0e2dd284c920` (*round 2: shared law surface for narrow cell crossings*) | `73b870983147a3cff26052097adea5e979b84271` (*round 3: stabilize the shared build/law surface*) |
| control revision | `eca979f524661cbe400d22b90c7e3c305b32052e` | `eca979f524661cbe400d22b90c7e3c305b32052e` |
| artifacts | `round2/round2.{identity_map,topology,oracle}.json`, `round2/round2.{files,sources,targets,tests,fanout}.txt`, `round2/round2.fanout_delta.tsv` | `round3/round3.{identity_map,topology,oracle}.json`, `round3/round3.{files,sources,targets,tests,fanout}.txt`, `round3/round3.fanout_delta.tsv` |
| topology/oracle command | `nix develop --command bazel run //experiments/atlas-work-topology:measure_topology --config=buildbuddy-rbe -- round2` | `… measure_topology --config=buildbuddy-rbe -- round3` |
| BUILD channel | `… measure_bazel_locality.sh round2`, then `scripts/fanout_delta.sh control round2` | `… measure_bazel_locality.sh round3`, then `scripts/fanout_delta.sh control round3` |
| in-graph guard | `//experiments/atlas-work-topology:round2_reproducibility_test` | `//experiments/atlas-work-topology:round3_artifacts_test` |

**Verdict — Outcome C (§13): rejected on the primary quantity, accepted on the oracle.**
Every semantically binding §10 rule that the instrument implements passes for
both rounds (Atlas grammar invariant, `D50/D80/D90/D95` drift ≤ 1,
depth-7 reach within 5 pp, O6 identity continuity, `ParityTest` and `./verify`
green). But the primary objective `k_way_cut(8)` did not move: 70.07%
(96/137) → 70.07% (round 2) → 69.34% (round 3), against the Minimum Serious
threshold of `< 50%` and the Strong Success threshold of `≤ 35%`. Neither
threshold is reached, so by §13 the outcome is **C (inconclusive / trade-off)**,
and by §12 both **S7** (two consecutive rounds — 1 and 2 — adopt no improvement
in `k_way_cut(8)`) and **S10** (three consecutive candidates show a `D50` drift
of exactly 1) are at their stopping conditions. Round 2 additionally carries one
non-semantic oracle deviation: its revision modified `src/BUILD.bazel` with a
declared cell-surface comment, which the implemented (over-broad) production-drift
proxy reports as `O4 = false`; round 3 reverted it byte-identically. This report
records both findings rather than re-tuning the oracle (§10/S2).

## 0. Commands of record

```bash
# evidence for both rounds
nix develop --command bazel run //experiments/atlas-work-topology:measure_topology --config=buildbuddy-rbe -- round2
nix develop --command bazel run //experiments/atlas-work-topology:measure_topology --config=buildbuddy-rbe -- round3
nix develop --command bash experiments/atlas-work-topology/scripts/measure_bazel_locality.sh round2
nix develop --command bash experiments/atlas-work-topology/scripts/measure_bazel_locality.sh round3
bash experiments/atlas-work-topology/scripts/fanout_delta.sh control round2
bash experiments/atlas-work-topology/scripts/fanout_delta.sh control round3

# independent verification
nix develop --command bazel test \
  //experiments/atlas-work-topology:round1_artifacts_test \
  //experiments/atlas-work-topology:round2_reproducibility_test \
  //experiments/atlas-work-topology:round3_artifacts_test --config=buildbuddy-rbe
./verify
```

`round3_artifacts_test` re-runs the full `attune.command=verify` verdict set on
the round-3 documents (byte-equality plus every oracle verdict) and passes.
`round2_reproducibility_test` re-derives the round-2 documents
(`attune.command=measure`) and compares them byte-for-byte; it does not assert
the §10 verdict set, because round 2's revision legitimately trips the
production-drift proxy (see §2). The byte-equality diff still pins round 2's
recorded `O4 = false`, so the deviation cannot change silently, and re-tuning
the oracle to admit it is forbidden (§10, S2).

### 0.1 Documented limitation: the BUILD channel was measured on a shared warm worktree

The environment had ≈170 MB free on `/` at measurement time. A fresh Bazel
output base cannot extract this revision's LLVM toolchain and gritql source, so
the first locality attempt in `/tmp/attuneflix-round2` returned `declaring_actions`
but every `rdeps` query failed with `No space left on device` and silently wrote
`direct_dependents: 0` / `test_invalidation: 0`. Those partial artifacts were
discarded. Both rounds' fanout artifacts were then produced by querying the
revisions' own BUILD files in the already-warm `/tmp/attuneflix-round1` output
base (recorded verbatim in each artifact header as `worktree=/tmp/attuneflix-round1`
with the correct `revision=`). No cache was deleted and no `bazel clean` was run.

## 1. What rounds 2 and 3 changed, on the identity layer (§9)

| movement | control basis | round 2 | round 3 |
|---|---|---|---|
| admitted files | 81 | 110 | 111 |
| stable | — | 63 | 62 |
| modified | — | 5 | 5 |
| moved | — | 13 | 14 |
| dropped | — | 0 | 0 |
| new | — | 29 | 30 |
| collisions | — | 0 | 0 |

- **Round 2** is the named §11 step: the two shared World law fixtures
  (`build/src/Repository.flix`, `build/src/TestWorlds.flix`) were re-homed
  byte-identically onto the horizontal law surface (`test/Repository.flix`,
  `test/TestWorlds.flix`; cell `world → law`), and the Engine parity law moved
  to its cell (`test/ParityTest.flix → test/Engine/ParityTest.flix`). The five
  modified paths are `BUILD.bazel`, `build/BUILD.bazel`,
  `experiments/atlas-parallelism/BUILD.bazel`, `src/BUILD.bazel`,
  `test/BUILD.bazel`.
- **Round 3** is the shared-owner stabilization: the Flix build-rule definition
  `build/flix.bzl` moved byte-identically to `test/build/flix.bzl` (cell
  `law → law`, region `other → tests`) with its ten load sites repointed, and
  `src/BUILD.bazel` was restored byte-identically to control (reverting round 2's
  comment). The five modified paths are `BUILD.bazel`, `build/BUILD.bazel`,
  `experiments/atlas-parallelism/BUILD.bazel`, `experiments/atlas-swe-explore/BUILD.bazel`,
  `test/BUILD.bazel` — all law/build wiring.

No admitted `src/` *production source* changed content in round 3. In round 2
the only `src/`-path content change is the declared cell-public-surface comment
in `src/BUILD.bazel`, which round 3 reverted.

## 2. Signature preservation oracle (§10)

Both rounds pass every comparison the instrument produces. Round 3's full
`verify` verdict set is green; round 2's is green except the over-broad
production-drift proxy.

### O1 grammar invariance — pass (both rounds)

Six directed atoms, composition only, depth ≤ 7, unchanged: 3,279 cumulative
File-domain and 3,279 Symbol-domain routes, depth ladder 3, 12, 39, 120, 363,
1092, 3279. Neither round touches `Atlas`/`Radii`/`Repository`.

### O2 mixing landmarks — pass (both rounds; drift identical to round 1)

| landmark | control | round 1 | round 2 | round 3 | threshold |
|---|---|---|---|---|---|
| `D50` | 3 | 4 (+1) | 4 (+1) | 4 (+1) | 1 |
| `D80` | none (8) | none (8) | none (8) | none (8) | 1 |
| `D90` | none (8) | none (8) | none (8) | none (8) | 1 |
| `D95` | none (8) | none (8) | none (8) | none (8) | 1 |

`D50` shows the same single-depth drift round 1 introduced; rounds 2 and 3 add
no new landmark movement. `signature_ok = true` for both (all comparisons `ok`).

### O3 depth-7 reach — pass (both rounds)

`mean_coverage(7)`: control 0.67438 → **0.66358** for round 1, round 2 and
round 3 alike (Δ = **−0.01080**, well inside the 0.05 allowance). The full reach
curve is identical across the three candidates:

| depth | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| control | 0.0972 | 0.4136 | 0.5247 | 0.6327 | 0.6636 | 0.6728 | 0.6744 |
| r1/r2/r3 | 0.0756 | 0.2685 | 0.4722 | 0.5910 | 0.6327 | 0.6512 | 0.6636 |

The seed panel is the control panel carried by logical identity
(`RoundOracle.translatedSeeds`), never re-hashed from candidate paths.

### O4 / O6 — round 3 pass; round 2 records `O4 = false`

| rule | round 2 | round 3 |
|---|---|---|
| O4 no admitted production source (`src/`) changed content | **false** (`src/BUILD.bazel`) | true |
| O6a every control identity maps to at most one current path | true | true |
| O6b no control identity was silently dropped | true | true |
| O6c control logical ids are unique | true | true |
| O5 parity (`//test/Engine:core_parity_test`) and `./verify` | pass | pass |

The implemented `RoundOracle.productionDrift` rule flags any `src/`-path basis
file whose bytes changed at the same path. Round 2's only such file is
`src/BUILD.bazel`, whose change is a comment declaring the round-2 cell
public-surface contract (25 added lines, no functional BUILD change — the
`exports_files` list was already control-identical). The preregistered §10 O4 is
the *extinction/recurrence regime*, which is unaffected: the admitted basis graph
is byte-for-byte the same shape (816 defines, 893 calls, `candidate_use_edges`
128) as round 1. The preregistration forbids re-tuning the oracle (§10, S2), so
round 2 stays rejected-by-proxy on that one verdict and is recorded here as the
round's measured finding; round 3 removed the cause. This is the only
oracle-adjacent concession in the two rounds.

### 2.1 Basis edge drift — identical to round 1 for both rounds

| quantity | control | round 2 | round 3 |
|---|---|---|---|
| basis use edges, identity-translated (§6.2 basis) | 137 | 137 | 137 |
| basis use edges, frozen facts re-admitted at candidate paths | 137 | 128 | 128 |
| lost / gained basis edges | — | 12 / 3 | 12 / 3 |
| unresolved imports | 507 | 506 | 506 |

The 15-edge drift is the same fixed set of starlark label/`glob` facts reported
in `rounds/round1.md` §2.1 (`test/BUILD.bazel → test/<Cell>/*.flix` glob edges
lost; `*BUILD.bazel → src/Repository.flix` label edges gained). It does not
compound: neither round 2 nor round 3 adds a single new lost or gained edge, and
the landmark drift is exactly round 1's. That is why `D50` stays at 4 instead of
walking further.

## 3. Static work-topology (§4–§6)

Both candidate columns translate every basis endpoint onto its `current_path` by
logical identity, so the tables differ from control only where a file changed
region or cell.

| quantity | control | round 1 | round 2 | round 3 |
|---|---|---|---|---|
| `use_edges` | 137 | 137 | 137 | 137 |
| `cross_region_edges` | 121 | 109 | 109 | **108** |
| `cross_region_edge_ratio` | 0.883 | 0.796 | 0.796 | **0.788** |
| `other_edges` | 9 | 9 | 9 | **6** |
| `cell_cut_4` | 0.660 | 0.554 | 0.554 | 0.554 |
| shared hotspots | 17 | 16 | 16 | **15** |
| max hotspot pressure | 7 | 6 | 6 | 6 |
| non-empty regions | 10 | 9 | 9 | 9 |
| independently testable regions | 4 | 3 | 3 | 2 |
| `max_region_blast` | 199 | 139.5 | 139.5 | 139.5 |
| `max_pair_jaccard` | 0.959 | 0.941 | 0.941 | **0.961** |
| high-overlap pairs (Jaccard ≥ 0.5) | 45 | 36 | 36 | 36 |

- **Round 2 changes no region-level row.** The two re-homed law fixtures stay in
  the `tests` region, so region membership, the cuts, hotspots, coherence and
  the Atlas channel are byte-identical to round 1's topology document (only the
  `revision` field and the `context` movement counts differ). This is the
  expected result: §9 region and
  cell membership are path-prefix based, and a same-region move is invisible to
  the cut.
- **Round 3 moves the low-`k` cuts and the hotspot count.** Moving
  `build/flix.bzl` out of the `other` region into `tests` removes three
  `other`-region edges and lets the greedy merge keep finer groups, so
  `cross_region_edges` falls 109 → 108, `other_edges` 9 → 6, and the shared
  hotspot list loses `build/flix.bzl` (16 → 15). `cell_cut_4` is unchanged
  (0.554): the K4 ownership-cell cut is computed over non-law, non-kernel edges
  and the move is law-internal. `max_hotspot_pressure` stays at 6 because the two
  pressure-6 files are `src/ScientificTable.flix` and
  `src/ScientificTable/Columns.flix`, imported only by immovable production
  modules plus the fixed `experiments`/`tests` prefixes.
- `max_pair_jaccard` rises slightly in round 3 (0.941 → 0.961) while the count
  of high-overlap pairs is unchanged (36); the change is the `tests`-vs-`tables`
  pair tightening as the law surface absorbs the build rule.

### 3.1 Cuts `k = 2..10` (T4) — cross-group edge counts

| k | control | round 1 | round 2 | round 3 |
|---|---|---|---|---|
| 2 | 14 | 14 | 14 | 11 |
| 3 | 21 | 21 | 21 | 18 |
| 4 | 33 | 33 | 33 | 30 |
| 5 | 47 | 47 | 47 | 44 |
| 6 | 68 | 67 | 67 | 64 |
| 7 | 81 | 84 | 84 | 81 |
| **8** | **96** | **96** | **96** | **95** |
| 9 | 108 | 111 | 111 | 110 |
| 10 | 123 | 111 | 111 | 110 |

`k = 10` degenerates onto `k = 9` once a region empties (`build-src` since
round 1); the value is reported, not dropped.

## 4. Quantitative 8-way cut target (VAL-HC23-004, §13)

`k_way_cut(8)` is the frozen primary objective (T4). Control baseline from the
frozen measurement is `96 / 137 = 70.07%` (the §13 scoping prior was `88 / 125 =
70.4%`; the frozen measurement replaces it).

| level | criterion | round 2 | round 3 | met? |
|---|---|---|---|---|
| Minimum serious success | `k_way_cut(8) < 50%` | 96/137 = **70.07%** | 95/137 = **69.34%** | **no** |
| Strong success | `k_way_cut(8) ≤ 35%` | 70.07% | 69.34% | **no** |
| Stretch goal | `k_way_cut(8) ≤ 25%` | 70.07% | 69.34% | no |

- Round 2: **70.07%, a 0.00 pp reduction.**
- Round 3: **69.34%, a 0.73 pp reduction** (one edge, 96 → 95).
- Neither the `< 50%` Minimum Serious nor the `≤ 35%` Strong threshold is
  reached. The §12 S8 stretch stop does not apply.

Structural reason, established in `library/round3-hotspot-stabilization.md` and
confirmed by these measurements: the round document is computed from the frozen
control world plus `RoundIdentity.mapping`, so **only a file move can change
`k_way_cut(8)`** — rewiring a consumer is invisible. Production `src/` files
cannot move (a production file's project path must equal its Flix module path,
and a non-`src/` path flips its surface class and fails O6b), so the cut can
only move via law/build re-homing, and the region boundary between `tests` and
the production regions is where the cut has lived since control. Rounds 2 and 3
did exactly the two legal law-surface moves available and moved the primary
quantity by one edge.

## 5. BUILD channel (§7): Bazel locality and invalidation

Both rounds' fanout artifacts are a read-only `bazel query` of the revision's
own BUILD files in its worktree (see §0.1 for the worktree caveat);
`*.fanout_delta.tsv` is keyed on the §9 logical identity layer.

| quantity | control | round 1 | round 2 | round 3 |
|---|---|---|---|---|
| analyzed targets | 437 | 467 | 474 | 474 |
| independently runnable test targets | 18 | 23 | 25 | 25 |
| summed cross-cell test invalidation, all tests | 108 | 154 | 192 | 192 |
| summed cross-cell test invalidation, `//experiments/...` excluded | **92** | **55** | **59** | **59** |
| files reduced / increased / equal (architecture reading) | — | 27 / 2 / 52 | 27 / 2 / 52 | 27 / 2 / 52 |

The raw row rises only because the experiment's own instrument tests live in the
same `//...` universe and depend on the `src/` core (documented instrument
contamination); the architecture-only column is the reading that matters. It
falls 92 → 55 at round 1, then rises 55 → **59** at round 2 and is unchanged at
round 3.

The +4 in round 2 is a **labelling effect, not a new dependency**: the two
re-homed law fixtures changed their §5 ownership cell from `world` to `law`, so
the world-cell law tests that previously counted as same-cell now count as
cross-cell. The two shared fixtures read:

| fixture (control → current) | control arch | round 1 arch | round 2 arch | round 3 arch |
|---|---|---|---|---|
| `build/src/Repository.flix` → `test/Repository.flix` | 0 | 4 | 8 | 8 |
| `build/src/TestWorlds.flix` → `test/TestWorlds.flix` | 0 | 2 | 2 | 2 |

The same public-surface rule that puts these fixtures on the horizontal law
surface (so no cell reads another cell's law internals) also makes the
cross-cell *count* for them label-complete. The underlying dependency set is
unchanged. The build-rule move in round 3 (`build/flix.bzl` →
`test/build/flix.bzl`) is invisible to this channel: `flix.bzl` is `load()`ed,
never declared in `srcs`, so its `declaring_actions` is 0 in every round.

Representative architecture-reading rows (`control → round 3`, tests / cross-cell
excluding the instrument):

| file | tests | cross-cell (arch) |
|---|---|---|
| `src/Repository.flix` (world) | 9 → 16 | **8 → 4** |
| `src/ScientificTable.flix` (kernel) | 6 → 13 | **5 → 4** |
| `src/Atlas.flix` (engine) | 4 → 10 | **3 → 1** |
| `src/Radii.flix` (engine) | 5 → 11 | **4 → 1** |
| `src/Population/Table.flix` (applications) | 6 → 13 | **5 → 3** |
| `src/Atlas/Signature.flix` (engine) | 4 → 10 | **3 → 1** |

## 6. Outcome classification (§13) and the delta for round 4

- **Oracle:** passed on every semantically binding rule for both rounds; round 2
  carries the one recorded production-drift deviation described in §2.
- **Topology:** moved marginally. Round 2 moved only the K4 law-ownership
  accounting (already moved in round 1) and left every region-level row at round
  1's value. Round 3 moved the low-`k` cuts, the hotspot count 16 → 15 and the
  cross-region ratio 0.796 → 0.788, but `cell_cut_4` and `max_hotspot_pressure`
  are structurally fixed and `k_way_cut(8)` moved by one edge.
- **Primary quantity:** `k_way_cut(8)` **70.07% → 70.07% → 69.34%**; neither the
  `< 50%` nor the `≤ 35%` threshold is reached. **Outcome C.**
- **Stopping rules now live (§12):**
  - **S7** — rounds 1 and 2 each adopted no step that improved `k_way_cut(8)`
    (96 → 96 → 96). Round 3 improved it by one edge (→ 95), so the literal
    "two consecutive rounds with no improvement" is met at rounds 1–2.
  - **S10** — three consecutive candidates (rounds 1, 2, 3) show a `D50` drift of
    exactly 1 versus control. The literal condition ("two consecutive candidates
    with a `D50/D80/D90` drift of exactly 1") is met; the drift does **not**
    compound (each candidate is measured against control and stays at `D50 = 4`,
    reach 0.6636), because the same fixed 15-edge starlark drift causes it.
  - §13's trade-off clause applies: reaching a lower `k_way_cut(8)` from here
    would require moving production `src/` files, which the identity/O6b rules
    forbid, or rewriting the region partition, which the frozen protocols forbid.
- **Constraints carried into round 4 (§11 step 4, typed artifact / build-cache
  boundaries):** round 4 is the last planned step and the primary objective is
  still ≈69%; anything it does to `k_way_cut(8)` must come from a *move* of a
  law/build file, and §12 S10 says the `D50` margin is spent.

## 7. Limits of this evidence

- No Grit re-acquisition, no provider call, no evaluator change (§11); each round
  re-expresses the frozen evidence at candidate paths and reports the
  path-resolution delta it cannot avoid (§2.1).
- The BUILD-channel universe is `//...` at every revision, so the instrument's
  own test targets are counted; the architecture-only column excludes
  `//experiments/...` explicitly and both numbers are committed.
- The two rounds' fanout artifacts were queried in the shared warm
  `/tmp/attuneflix-round1` output base because the environment was out of disk
  space (§0.1); the revision each artifact measured is recorded in its header.
- The co-change channel (§8) is not re-measured for a round: it is a property of
  the VCS history reachable from the control revision, not of a candidate tree,
  and the frozen `control.cochange.json` remains the only co-change artifact.
- `k = 10` degenerates onto `k = 9`; the value is reported, not dropped.
- The tracked-Flix LOC gate (O7) is a pre-existing violation
  (`8952` raw lines over 68 files, limit `< 4800`); rounds 2 and 3 add no Flix
  lines (pure moves plus BUILD comments). `feature-final-gate-hygiene` owns it.
