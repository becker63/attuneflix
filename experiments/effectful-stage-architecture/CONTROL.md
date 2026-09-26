# CONTROL — Frozen Control Baseline

Effectful Typed-Stage Architecture mission. This file pins the frozen scientific
control specimen the mission measures every candidate against, records the
canonical verification result at that specimen, and summarizes the deterministic
control metrics. Machine-readable form: `control-baseline.json`.

Fulfills: **VAL-CTRL-001** (control commit verification and baseline record).

---

## 1. Control revision identity

| Field | Value |
| --- | --- |
| Git commit | `09e27244af9340aa616116a93ea02472e7521ba5` |
| Git tree | `a603014e034f1cc5dcc9b0e0d93f9fa8bc0dcbd8` |
| Git parent | `ad82099e08f541fd05fef3a4019c29c6d00b4333` |
| Git subject | `README: link the atlas-work-topology work-topology experiment` |
| Git author | `becker63 <johnsontaylor6320@gmail.com>` |
| Git date | `Sat Sep 26 11:29:31 2026 +0000` |
| Jujutsu change id | `olnnyuutzxsr` |
| Jujutsu commit id | `09e27244af9340aa616116a93ea02472e7521ba5` |
| Jujutsu bookmarks | `main`, `main@origin` |

`09e27244af9340aa616116a93ea02472e7521ba5` is the scientific checkpoint the
mission is built on. It sits on top of the completed K4 work-topology experiment
(`ad82099e`, final report) and carries the promoted round-4 architecture whose
frozen Atlas signature is the mission's control curve.

The revision is **never rewritten and never re-measured**. Every candidate
(Candidates A–D) is compared against this specimen.

---

## 2. Working head and control equivalence

The working tree used to run the baseline is one documentation commit ahead of
the control specimen:

| Field | Value |
| --- | --- |
| Working head (Git) | `e12a4c15d601a8220525990e3c489df2fdc36aa8` |
| Working head tree | `952bcea1f925f7e5d142463f01fc1b7ecf32b30a` |
| Working head change id | `symxpmzqwolx` |
| Delta vs control | `AGENTS.md` only (2 insertions, 2 deletions) |

The sole delta is a documentation edit to `AGENTS.md` (permitting a local
`bazel clean` for disk recovery). It is **not a Bazel input**: searching every
`BUILD.bazel` and `*.bzl` file for `AGENTS.md` returns no match. The Bazel
derivation and validation graph at the working head is therefore identical to
the graph at the control specimen, so the `./verify` result below is the control
build's result. The exact control tree hash is recorded above for the record.

---

## 3. Canonical verification result (verbatim)

Command:

```
./verify
# == nix develop --command bazel test //... --config=buildbuddy-rbe
```

Exit code: **0**. Summary: **`Executed 0 out of 30 tests: 30 tests pass.`**
Every target resolved from the remote cache (warm cached rerun is preservation
evidence, per `AGENTS.md`). BuildBuddy invocation `40d2fdf0-a06b-4fde-a8d3-b82c3a80d37a`.

Verbatim output (test block):

```
INFO: Analyzed 30 targets (0 packages loaded, 0 targets configured).
INFO: Found 30 test targets...
INFO: Elapsed time: 0.512s, Critical Path: 0.03s
INFO: 1 process: 302 action cache hit, 1 internal.
INFO: Build completed successfully, 1 total action
INFO:
//experiments/atlas-parallelism:parallelism_provenance_test     (cached) PASSED in 0.0s
//experiments/atlas-work-topology:artifact_boundary_test        (cached) PASSED in 0.2s
//experiments/atlas-work-topology:control_reproducibility_test  (cached) PASSED in 156.8s
//experiments/atlas-work-topology:control_signature_artifacts_test (cached) PASSED in 12.1s
//experiments/atlas-work-topology:control_signature_test        (cached) PASSED in 0.1s
//experiments/atlas-work-topology:control_topology_artifacts_test (cached) PASSED in 3.1s
//experiments/atlas-work-topology:control_topology_test         (cached) PASSED in 0.0s
//experiments/atlas-work-topology:report_test                   (cached) PASSED in 0.2s
//experiments/atlas-work-topology:round1_artifacts_test         (cached) PASSED in 9.8s
//experiments/atlas-work-topology:round2_reproducibility_test   (cached) PASSED in 10.1s
//experiments/atlas-work-topology:round3_artifacts_test         (cached) PASSED in 5.4s
//experiments/atlas-work-topology:round4_artifacts_test         (cached) PASSED in 5.5s
//experiments/atlas-work-topology:round_test                    (cached) PASSED in 0.1s
//src/native/grit:attune_grit_rust_test                         (cached) PASSED in 0.1s
//src/native/grit:attune_grit_test                              (cached) PASSED in 1.6s
//src/native/identity:attune_identity_test                      (cached) PASSED in 0.1s
//src/native/inference:attune_inference_test                    (cached) PASSED in 0.3s
//src/native/parquet:attune_parquet_test                        (cached) PASSED in 0.7s
//test/Applications:inference_boundary_test                     (cached) PASSED in 0.1s
//test/Applications:localization_sandwich_test                  (cached) PASSED in 0.0s
//test/Applications:population_table_test                       (cached) PASSED in 0.0s
//test/Engine:atlas_grammar_test                                (cached) PASSED in 0.1s
//test/Engine:atlas_signature_table_test                        (cached) PASSED in 0.0s
//test/Engine:core_parity_test                                  (cached) PASSED in 0.0s
//test/Kernel:identity_test                                     (cached) PASSED in 0.0s
//test/Kernel:scientific_table_test                             (cached) PASSED in 0.0s
//test/World:grit_acquire_test                                  (cached) PASSED in 0.1s
//test/World:grit_acquisition_test                              (cached) PASSED in 0.1s
//test/World:repository_admission_test                          (cached) PASSED in 0.1s
//test/World:repository_table_test                              (cached) PASSED in 0.0s

Executed 0 out of 30 tests: 30 tests pass.
There were tests whose specified size is too big. Use the --test_verbose_timeout_warnings command line option to see which ones these are.
INFO: Streaming build results to: https://app.buildbuddy.io/invocation/40d2fdf0-a06b-4fde-a8d3-b82c3a80d37a
```

The mission precondition `./verify` passes **30/30** is satisfied at the control
build graph.

---

## 4. Deterministic control metrics (summary)

Full machine-readable record in `control-baseline.json`.

| Metric | Control value |
| --- | --- |
| Verify test targets | 30 |
| Verify tests passed | 30 |
| Verify tests failed | 0 |
| Tracked `.flix` lines in `src/` + `test/` | 4369 (law: < 4800) |
| Tracked `.flix` files in `src/` + `test/` | 38 |
| Largest `src/`+`test/` file | `src/Repository.flix` = 410 lines |
| Files over 400 lines (excl. historical instrument) | 1 (`src/Repository.flix`) |
| All tracked `.flix` files / lines | 68 / 8952 |

The `src/Repository.flix` 410-line file is the standing pre-existing flag the
mission's Candidate C decomposition explicitly resolves; it is recorded here as
the control condition, not as a regression introduced by this record.

---

## 5. Inherited frozen scientific evidence

The committed control evidence under `experiments/atlas-work-topology/control/`
is the previous experiment's frozen control, pinned at revision
`eca979f524661cbe400d22b90c7e3c305b32052e` (an ancestor of the mission control
specimen). It is read-only evidence, inherited verbatim; the identities below
pin it so any later candidate can prove it did not perturb the science.

| Artifact | sha256 |
| --- | --- |
| `control.cochange.json` | `5b47e976b32ec754b01ca8d66c14d51c8c907286e7c8d153ce10ea7e21cf0334` |
| `control.cochange_history.txt` | `f11fd46b5733ce718084f196bf7a982cc358b70c93b3c76b65c603fd05a1a83b` |
| `control.facts.parquet` | `c9a7974388b023970bbf721c13837f71b896d74d8f9476044135bbdde301b26a` |
| `control.fanout.txt` | `72115d4a5cd875cb1d56e3d318b7d401a5da16dfae8f636dece5d69d91b5c080` |
| `control.files.txt` | `f2c48c4a3c5ef678df84c4bd020e65e688ca77305b876c489853228723bca843` |
| `control.identity_map.json` | `ea6c24a537137705b79729f318171a317b3f11dbb74e05b75991368a5769fb0f` |
| `control.revision.txt` | `9ee88e506f0bf9c509708c913bb1bf40dcf71e60b69d88d2a6bb9094cf201fa1` |
| `control.signatures.parquet` | `173cc2a9f1c335e940da32761c9632ec9f2db75d1103cf64903cbd3c7241cf0f` |
| `control.sources.parquet` | `262589b59bfb8938d95a05740646a4563852b07983db4e23c77078e567091a88` |
| `control.summaries.parquet` | `a5b6669c0b75b7aa3288967fdb111eb28f0fa580a8b656c8480d1803e433323a` |
| `control.targets.txt` | `f365f5baa63d7825925f2cb2c7835cbe5c0eade65a1ce55c19f5d96dc238c1ed` |
| `control.tests.txt` | `09e321dd59ea3fe549a718f5fa3cbae1939d637b08de526ee0830bbfe44c2624` |
| `control.topology.json` | `5806fd3643059bdd1381cd7dd38bca44aee85ae7fa8f45f636ca0d58032d8d35` |

### Inherited control architecture metrics (measured at `eca979f5`)

Source: `control.topology.json` (protocol `attuneflix-topology-v1`).

| Metric | Value |
| --- | --- |
| Admitted files | 81 |
| Symbols / defines | 816 |
| Calls | 893 |
| Parent edges | 105 |
| Use edges | 137 |
| Cross-region edges | 121 (ratio 0.8832) |
| Shared hotspots (files) | 17 (max pressure 7: `src/ScientificTable.flix`) |
| 4-cell cut fraction | 0.6604 (35 shared of 53 considered edges) |
| Regions | 10 |

These are the previous experiment's control numbers and are recorded for
continuity only; the mission's own control metrics are measured at
`09e27244af9340aa616116a93ea02472e7521ba5` (see §6).

### Frozen Atlas signature invariants

The mission preregistration fixes the control Atlas mixing curve. Values are
recorded in `experiments/atlas-work-topology/round4/round4.oracle.json`
(signature protocol `atlas-signature-work-topology-v1`, `signature_ok: true`),
whose `candidate` column is the promoted architecture carried into the control
specimen:

| Landmark | Control value |
| --- | --- |
| D50 (depth at which mean coverage crosses 0.50) | 4 |
| Depth-7 reach (mean coverage) | 0.6636 |
| D80 / D90 / D95 | 8 / 8 / 8 |

Depth-response curve (depths 1..7): `0.0756, 0.2685, 0.4722, 0.5910, 0.6327, 0.6512, 0.6636`.

---

## 6. Scope of deferred control measurements

This record pins the control **identity**, the canonical **verification** state,
the **LOC law** baseline, and the inherited frozen scientific evidence. The
mission's own control architecture metrics are measured at the control specimen
by the preregistration work (`m1-author-preregistration-and-metrics`) and the
deterministic measurement targets it builds, including:

- $k$-way topological cut and mutable cross-stage edge count,
- shared writable hotspot count,
- cross-cell Bazel test invalidation count,
- Stable Kernel size tax,
- task critical-path fraction $T_\infty / T_1$.

Those are intentionally not fabricated here from a different revision.
