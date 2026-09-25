# v2 acquisition inputs — real Grit over the two frozen revisions

These artifacts are the **frozen measurement inputs** of the v2 self-signature
(PREREGISTRATION.md, section "AMENDMENT — v2 acquisition"). They exist so that
the in-graph measurement — ordinary `Repository.admit` -> `Repository.World` ->
`Repository.Physical` -> `Atlas.evaluate` -> parallelism metrics — is hermetic
and reproducible without VCS access at build time, the same way the Atlas census
commits its frozen world evidence under `.attune/`.

They are **data**, not a second source tree and not handwritten code: nothing
here is compiled, imported, or counted as tracked Flix.

## The two frozen revisions

| role | revision (git) | worktree |
|---|---|---|
| baseline | `bcfc126db7b7c7f535353ccc8afca44465903571` | `/tmp/attuneflix-baseline` (isolated `git worktree`, never mutated) |
| cleaned | `ae2f5e68711121f8ecbf9ce94a7926ca7c7833d1` | `/tmp/attuneflix-cleaned` (isolated `git worktree`) |

Both are the revisions already bound by the v1 experiment: the mission's
recorded baseline and the sealed cleaned revision. The experiment was not
restarted from scratch; only the acquisition system changed from the v1 lexical
proxy to real Grit.

## How these artifacts were produced (exact reproduction)

```bash
# 1. isolated worktrees at the two frozen revisions (never the live worktree)
git worktree add /tmp/attuneflix-baseline bcfc126db7b7c7f535353ccc8afca44465903571
git worktree add /tmp/attuneflix-cleaned  ae2f5e68711121f8ecbf9ce94a7926ca7c7833d1

# 2. the repository's own acquisition path, built by Bazel
nix develop --command bazel build //experiments/atlas-parallelism:acquire --config=buildbuddy-rbe

# 3. Grit acquisition over each frozen worktree (typed artifacts land in v2/)
bash experiments/atlas-parallelism/v2_extract.sh \
    bazel-bin/experiments/atlas-parallelism/acquire baseline /tmp/attuneflix-baseline \
    experiments/atlas-parallelism/v2
bash experiments/atlas-parallelism/v2_extract.sh \
    bazel-bin/experiments/atlas-parallelism/acquire cleaned /tmp/attuneflix-cleaned \
    experiments/atlas-parallelism/v2

# 4. the acquisition evidence report (printed, not stored)
bazel-bin/experiments/atlas-parallelism/acquire \
    --jvm_flag=-Dattune.command=summary \
    --jvm_flag=-Dattune.sources=experiments/atlas-parallelism/v2/sources/baseline.sources.parquet \
    --jvm_flag=-Dattune.facts=experiments/atlas-parallelism/v2/grit/baseline.facts.parquet
```

The engine is the frozen hermetic Grit closure
(`getgrit/gritql @ c80b3026471b229f41b279c3eb0c162dcdacfdb1`, sha256
`87066b84963dc1b89b9344fbae046f941ed8fce5e983c48d74a26964f6e7cb48`), extended
with the one pinned Flix grammar (`omarjatoi/tree-sitter-flix @
78cff149b2e9897456f94844872353b5ee0ca93b`) and a maintained Starlark grammar
(`tree-sitter-grammars/tree-sitter-starlark @
a453dbf3ba433db0e5ec621a38a7e59d72e4dc69`). The acquisition code is
`Repository.Acquire` (the one program-dispatch/native boundary) plus
`AcquisitionDriver`: For every admitted file it runs the three packaged
frontends (`src/grit/{defines,imports,calls}/<language>.grit`) and projects the
engine's envelopes through `Repository.Grit.facts`.

## Admitted surface (exact inclusions)

A tracked path is admitted iff the closure's one detection table admits its
kind: `Repository.Grit.language(path) != None` — `.flix`, `.java`,
`.js`/`.mjs`/`.cjs`, `.jsx`, `.ts`/`.mts`/`.cts`, `.tsx`, `.bzl`/`.bazel`/
`.star`, and the Bazel build files `BUILD`, `BUILD.bazel`, `WORKSPACE`,
`WORKSPACE.bazel` — excluding the frozen data tree `.attune/**`.

Per file: `v2/sources/<role>.files.txt` (the sorted admitted list, the exact
inclusion record), `v2/sources/<role>.revision.txt` (the worktree `HEAD` the
list was derived from), and `v2/sources/<role>.sources.parquet` (path, sha256,
byte length, language).

| role | files | flix | java | starlark |
|---|---|---|---|---|
| baseline | 72 | 41 | 11 | 20 |
| cleaned | 75 | 42 | 11 | 22 |

Documented exclusions: the frozen `.attune/**` data tree and `*.parquet`
(evidence, not implementation source); Markdown documentation; `*.json`,
`*.toml`, `*.lock`, `*.nix`, `*.sh`, `verify`, `.bazelrc`, `.gitignore`,
`.scm` metadata (environment/build plumbing — not admitted by the closure's
table); `*.rs` (the narrow native Grit seam; Rust is not an admitted Grit
target language in this closure); `*.grit` (the frontends themselves, and
absent at both measured revisions). **JS/TS:** no tracked `.js`/`.jsx`/`.ts`/
`.tsx` exists at either revision (verified with `git ls-tree`), so the
JavaScript/TypeScript frontends contribute no facts here — recorded, not hidden.

## Artifacts and schemas

- `v2/sources/<role>.sources.parquet` — `attuneflix-grit-sources-v2`:
  path, sha256, byte_length, language.
- `v2/grit/<role>.facts.parquet` — `attuneflix-grit-facts-v2`:
  path, source_sha256, language, program, kind, start_byte, end_byte, value.
  One row per `Repository.Grit.Fact` the engine emitted, per file and relation
  program. `source_sha256` ties every fact to the exact source bytes it was
  acquired from.

Acquisition summary of record (from step 4):

| role | files | facts | symbols | defines | imports | calls | unresolved imports | unresolved calls |
|---|---|---|---|---|---|---|---|---|
| baseline | 72 | 5,293 | 762 | 762 | 90 | 769 | 433 | 2,263 |
| cleaned | 75 | 5,124 | 650 | 650 | 125 | 693 | 423 | 2,439 |

Fact kinds emitted (engine output, not a script's guess): `definition` (Flix,
Java, Starlark defines), `import` (all three), `dependency` (the one Starlark
relation-word extension for real label dependencies), and `call` (all three).
The admitted `calls` relation is non-empty in v2 — 769 / 693 symbol-level call
edges — where the v1 lexical proxy structurally could not have any.

## How the measurement consumes them

`//experiments/atlas-parallelism:v2_{baseline,cleaned}_world` re-admits these
facts through ordinary `Repository.admit` **inside the Bazel action graph**
(no source text is parsed in the graph), then runs the same per-region Atlas
signature shards as v1. The re-admission verifies, per fact, that the path is
admitted, that the source hash and language match the inclusion record, and
that the byte range lies inside the source — the evidence and the inclusion
record cannot drift apart silently.
