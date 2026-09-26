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

## Determinism (VAL-CONTROL-003)

```bash
nix develop --command bazel test //experiments/atlas-work-topology:control_reproducibility_test --config=buildbuddy-rbe
```

Re-acquires the same worktree twice, re-admits the committed evidence through
`Repository.admit`, and asserts byte-for-byte equality of both runs against each
other and against the committed evidence, plus exact inclusion-record and
revision equality. All comparison logic runs in Flix (`ControlAcquisition.flix`).
