# Round 4 — typed artifact and build-cache boundaries (Hill-Climb delta report)

| | |
|---|---|
| role | `round4` |
| candidate revision | `c236a3aabfa13e5f36162e895d1ca4742f9730c0` (*round 4: typed artifact and build-cache boundaries*) |
| measurement commit | `33ea5712b461a1178af32819d41aedddaac61d2c` (carries `round4/` and the `round4_artifacts_test` wiring) |
| parent | `8286eefe` (the rounds 2/3 measurement checkpoint, `main` at measurement time) |
| control revision | `eca979f524661cbe400d22b90c7e3c305b32052e` |
| artifacts | `round4/round4.{identity_map,topology,oracle}.json`, `round4/round4.{files,sources,targets,tests,fanout}.txt`, `round4/round4.fanout_delta.tsv` |
| topology/oracle command | `nix develop --command bazel run //experiments/atlas-work-topology:measure_topology --config=buildbuddy-rbe -- round4` |
| BUILD channel | `… measure_bazel_locality.sh round4`, then `scripts/fanout_delta.sh control round4` |
| in-graph guard | `//experiments/atlas-work-topology:round4_artifacts_test` |

**Verdict — Outcome C (§13), accepted on the oracle, neutral on the cut.** Round
4 is the last planned hill-climb step (§11 step 4). It adds no Flix line and
changes no `src/` production content, so it moves neither the signature nor the
primary quantity: `k_way_cut(8)` stays `95 / 137 = 69.34%` (round 3's value),
below neither threshold. Its deliverable is a *build-graph* artifact boundary,
not a cut movement, and the round-4 BUILD channel is consequently a cache/action
story (three new test targets, unchanged architecture-only invalidation) rather
than a locality improvement.

## 0. Commands of record

```bash
# round-4 evidence
nix develop --command bazel run //experiments/atlas-work-topology:measure_topology --config=buildbuddy-rbe -- round4
nix develop --command bash experiments/atlas-work-topology/scripts/measure_bazel_locality.sh round4
bash experiments/atlas-work-topology/scripts/fanout_delta.sh control round4

# declared typed-artifact boundary (the round's deliverable)
nix develop --command bazel build \
  //experiments/atlas-work-topology:control_signature_tables \
  //experiments/atlas-work-topology:control_topology_documents --config=buildbuddy-rbe
nix develop --command bazel test //experiments/atlas-work-topology:artifact_boundary_test --config=buildbuddy-rbe

# independent verification
nix develop --command bazel test //experiments/atlas-work-topology:round4_artifacts_test --config=buildbuddy-rbe
source /etc/profile.d/nix.sh && ./verify
```

`round4_artifacts_test` re-derives the round-4 identity map, topology and oracle
from the committed control evidence and asserts the full `attune.command=verify`
verdict set. It passes, because no `src/` content changed and no Flix line was
added (unlike round 2, whose `src/BUILD.bazel` comment trips the over-broad
production-drift proxy).

## 1. What round 4 changed, on the identity layer (§9)

| movement | control basis | round 4 |
|---|---|---|
| admitted files | 81 | 112 |
| stable | — | 62 |
| modified | — | 5 |
| moved | — | 14 |
| dropped | — | 0 |
| new | — | 31 |
| collisions | — | 0 |

The five modified paths are `BUILD.bazel`, `build/BUILD.bazel`,
`experiments/atlas-parallelism/BUILD.bazel`,
`experiments/atlas-swe-explore/BUILD.bazel` and `test/BUILD.bazel` — all
law/build wiring. `new = 31` is round 3's 30 plus exactly one admitted file,
`experiments/atlas-work-topology/artifacts.bzl` (`.sh` and `.md` files are not in
the admitted language set, so they do not appear at all). The 14 moves are round
3's law/build re-homings, unchanged.

The intervention itself is the declared typed-artifact boundary
(`library/round4-artifact-boundaries.md`): two expensive scientific stages
(depth 1..7 signature derivation; static work-topology and co-change) became
cacheable Bazel actions over exactly their typed input boundary, with their
typed artifacts as declared outputs, and the single 10-file control list was
replaced at every consumer site by four per-stage typed input boundaries
(`:control_world_artifacts`, `:control_signature_artifacts`,
`:control_topology_artifacts`, `:control_locality_artifacts`).

## 2. Signature preservation oracle (§10)

| landmark | control | round 4 | delta | threshold | ok |
|---|---|---|---|---|---|
| `D50` | 3 | 4 | **+1** | 1 | yes |
| `D80` | none (8) | none (8) | 0 | 1 | yes |
| `D90` | none (8) | none (8) | 0 | 1 | yes |
| `D95` | none (8) | none (8) | 0 | 1 | yes |
| `mean_coverage(7)` | 0.67438 | 0.66358 | **−0.01080** | 0.05 | yes |

`signature_ok = true`; the reach curve is byte-identical to rounds 1–3. The
basis-edge drift is the same fixed 12 lost / 3 gained starlark label/`glob`
edges first reported in `rounds/round1.md` §2.1 (`candidate_use_edges = 128`,
`modified_basis_edges = 66`, `candidate_unresolved_imports = 506`).

| rule | verdict |
|---|---|
| O4 no admitted production source (`src/`) changed content | true |
| O6a every control identity maps to at most one current path | true |
| O6b no control identity was silently dropped | true |
| O6c control logical ids are unique | true |
| O5 parity (`//test/Engine:core_parity_test`) and `./verify` | pass |

## 3. Static work-topology (§4–§6)

Round 4 moves no file, so every region-level row equals round 3's:

| quantity | control | round 4 |
|---|---|---|
| `use_edges` | 137 | 137 |
| `cross_region_edges` | 121 (0.883) | 108 (0.788) |
| `other_edges` | 9 | 6 |
| `cell_cut_4` | 0.660 (35/53) | 0.554 (36/65) |
| shared hotspots | 17 | 15 |
| max hotspot pressure | 7 | 6 |
| non-empty regions | 10 | 9 |
| independently testable regions | 4 | 2 |
| `max_region_blast` | 199 | 139.5 |
| `max_pair_jaccard` | 0.959 | 0.961 |
| high-overlap pairs (Jaccard ≥ 0.5) | 45 | 36 |

| k | control | round 4 |
|---|---|---|
| 2 | 14 | 11 |
| 3 | 21 | 18 |
| 4 | 33 | 30 |
| 5 | 47 | 44 |
| 6 | 68 | 64 |
| 7 | 81 | 81 |
| **8** | **96 (70.07%)** | **95 (69.34%)** |
| 9 | 108 | 110 |
| 10 | 123 | 110 |

## 4. BUILD channel (§7) and the declared artifact boundary

The fanout artifacts are a read-only `bazel query` of the round-4 revision in
the shared warm `/tmp/attuneflix-round1` output base (the same documented
worktree caveat as rounds 2/3; the artifact header records
`worktree=/tmp/attuneflix-round1 revision=c236a3aa… universe=//...`), so the
`rdeps` fanouts are real, not the disk-exhaustion zeros.

| quantity | control | round 4 |
|---|---|---|
| analyzed targets | 437 | **485** |
| independently runnable test targets | 18 | **28** |
| summed cross-cell test invalidation, all tests | 108 | 243 |
| summed cross-cell test invalidation, `//experiments/...` excluded | **92** | **59** |
| files reduced / increased / equal (architecture reading) | — | 27 / 2 / 52 |

The architecture-only column is unchanged from rounds 2/3 (59): round 4 adds no
architectural dependency. The raw all-tests column rises 192 → 243 only because
round 4 added three test targets to the `//...` universe (25 → 28), each
depending on the core `src/` — the documented instrument contamination. The
declared stage boundary itself is the round's real deliverable:

- both stage actions execute remotely and succeed; all five declared artifacts
  are **byte-identical** to the frozen committed evidence
  (`artifact_boundary_test`: 5 × `OK` + `PASS`);
- a second `bazel build` of the two stages reports `32 action cache hit`, and the
  boundary test run reports `149 action cache hit`;
- the declared input closure is exactly the tool plus the frozen evidence
  (`aquery` in `library/round4-artifact-boundaries.md`) — a change to any other
  repository file cannot invalidate either stage.

## 5. Outcome classification (§13) and closure

- **Oracle:** accepted on every rule.
- **Primary quantity:** `k_way_cut(8)` unchanged at 69.34%; neither `< 50%` nor
  `≤ 35%` is reached. **Outcome C.**
- **Stopping rules:** S6 (four-round budget exhausted) applies at this round;
  S7 (rounds 1 and 2 adopted no improvement) and S10 (three consecutive
  candidates with `D50` drift exactly 1) remain live from rounds 2/3.
- **Final synthesis:** `experiments/atlas-work-topology/REPORT.md`.

## 6. Limits

- No Grit re-acquisition, no provider call, no evaluator change (§11).
- The BUILD-channel universe is `//...`, so the instrument's own tests are
  counted; both the raw and the architecture-only columns are committed.
- The round adds no Flix line; the tracked-Flix LOC gate (O7) remains a
  pre-existing violation owned by `feature-final-gate-hygiene`.
