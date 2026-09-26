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

81 admitted files (48 `.flix`, 15 `.bazel`, 11 `.java`, 7 `.bzl`); 6,254 facts;
an admitted world of 816 symbols, 137 import edges, 893 call edges.

## Determinism (VAL-CONTROL-003)

```bash
nix develop --command bazel test //experiments/atlas-work-topology:control_reproducibility_test --config=buildbuddy-rbe
```

Re-acquires the same worktree twice, re-admits the committed evidence through
`Repository.admit`, and asserts byte-for-byte equality of both runs against each
other and against the committed evidence, plus exact inclusion-record and
revision equality. All comparison logic runs in Flix (`ControlAcquisition.flix`).
