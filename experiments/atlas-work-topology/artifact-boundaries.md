# Typed artifact and Bazel cache boundaries (K4 Hill-Climb Round 4)

Round 4 of the hill-climb (PREREGISTRATION.md §11) exploits typed Parquet and
Bazel cache boundaries for the experiment's expensive scientific stages. This
file records what was declared, where the boundary sits, and the evidence that
it is a boundary rather than a convention. It adds no Flix, no grammar, no
oracle rule and no `src/` change.

## What is declared

Two stages are pure deterministic functions of the frozen typed evidence:
nothing in them reads the ambient environment, the VCS state or any source
text. They are now declared Bazel actions whose declared inputs are exactly
that evidence and whose declared outputs are their typed artifacts:

| target | stage (mnemonic) | declared inputs | declared typed outputs |
|---|---|---|---|
| `//experiments/atlas-work-topology:control_signature_tables` | `AttuneControlSignatures` (`attune.command=compute`) | `control.revision.txt`, `control.files.txt`, `control.sources.parquet`, `control.facts.parquet` | `control.signatures.parquet` (`attune-atlas-signature-observations-v1`), `control.summaries.parquet` (`attune-atlas-signature-summary-v1`), `control.identity_map.json` |
| `//experiments/atlas-work-topology:control_topology_documents` | `AttuneControlTopology` (`attune.command=measure`) | the same world boundary + `control.cochange_history.txt` | `control.topology.json`, `control.cochange.json` |

The rules live in `artifacts.bzl`; the output groups (`signatures`, `summaries`,
`identity_map`, `topology`, `cochange`) let a consumer depend on one artifact.

The four `filegroup`s in `BUILD.bazel` are the matching input boundaries, one
per producing stage — `:control_world_artifacts`, `:control_signature_artifacts`,
`:control_topology_artifacts`, `:control_locality_artifacts`. Every consumer
declares the narrowest boundary it actually reads; `:control_files` remains as
the union for the report and round bookkeeping. Before Round 4 one 10-file list
was declared everywhere, so a change to any single control artifact invalidated
every control consumer, including the round tests that read only the world.

## Evidence

Reproduce the boundary (one Bazel process at a time):

```bash
nix develop --command bazel build \
  //experiments/atlas-work-topology:control_signature_tables \
  //experiments/atlas-work-topology:control_topology_documents --config=buildbuddy-rbe
```

First invocation executes the two stages (`91 processes: 85 internal, 6 remote`,
29.9 s); the second is reuse, verbatim:

```text
INFO: 1 process: 32 action cache hit, 1 internal.
INFO: Build completed successfully, 1 total action
```

The declared input closure is exactly the frozen evidence (the stages' own Flix
sources enter through the tool's runfiles, so a source change invalidates
exactly these actions):

```text
$ bazel aquery 'mnemonic("AttuneControlSignatures", //experiments/atlas-work-topology:control_signature_tables)' --config=buildbuddy-rbe
  Mnemonic: AttuneControlSignatures
  Inputs: [ ... control_signatures_bin, ... control_signatures_bin.jar,
            ... control_signatures_bin-runfiles,
            experiments/atlas-work-topology/control/control.facts.parquet,
            experiments/atlas-work-topology/control/control.files.txt,
            experiments/atlas-work-topology/control/control.revision.txt,
            experiments/atlas-work-topology/control/control.sources.parquet]
  Outputs: [ ... control_signature_tables/control.identity_map.json,
             ... control_signature_tables/control.signatures.parquet,
             ... control_signature_tables/control.summaries.parquet]

$ bazel aquery 'mnemonic("AttuneControlTopology", //experiments/atlas-work-topology:control_topology_documents)' --config=buildbuddy-rbe
  Inputs: [ ... control_topology_bin, ... control_topology_bin.jar,
            ... control_topology_bin-runfiles,
            ... control/control.cochange_history.txt,
            ... control/control.facts.parquet, .../control.files.txt,
            .../control.revision.txt, .../control.sources.parquet]
  Outputs: [ ... control_topology_documents/control.cochange.json,
             .../control.topology.json]
```

## Downstream consumer

`//experiments/atlas-work-topology:artifact_boundary_test` reads the declared
stage outputs and checks each against the frozen committed evidence under
`control/` with `cmp`. It never re-runs a stage and never parses source text, so
a consumer may reuse the cached artifact only because the declared action
re-derives the frozen bytes exactly. Observed:

```text
OK   signature stage: control.signatures.parquet (attune-atlas-signature-observations-v1)
OK   signature stage: control.summaries.parquet (attune-atlas-signature-summary-v1)
OK   signature stage: control.identity_map.json (logical identity map)
OK   topology stage: control.topology.json (cuts k=2..10, cells, hotspots)
OK   topology stage: control.cochange.json (raw/normalized/line-weighted)
PASS: both declared typed-artifact boundaries re-derive the frozen control evidence
INFO: 4 processes: 149 action cache hit, 2 internal, 2 remote.
```

All five declared artifacts are byte-identical to the frozen evidence, so the
typed-schema round-trips in `control_signature_artifacts_test` and
`control_topology_artifacts_test` (exact table re-derivation, O9) and this
boundary check agree.

## What did not change

- `//experiments/atlas-work-topology:acquire`,
  `:compute_control_signatures` and `:measure_control_topology` remain the
  `bazel run` commands of record that write the committed evidence
  (PREREGISTRATION.md §14); the actions re-derive the same bytes as declared
  build outputs and never touch the source tree.
- No grammar, atom, evaluator, typed schema, region, cell or oracle rule
  changed; no `src/` file changed; zero Flix lines added or removed, so the
  Round 4 candidate adds no new `D50`/reach drift and no new logical identity
  beyond the new `.bzl`/`BUILD.bazel`/`.sh` files this round introduces.
- The `control/`, `round1/`, `round2/` and `round3/` evidence is unchanged.

## Operational notes

- `bazel test //experiments/atlas-work-topology:research_tests
  --config=buildbuddy-rbe` covers every rewired consumer plus the new boundary
  test (12/12 green, including the round-4 measurement's
  `round4_artifacts_test`); `source /etc/profile.d/nix.sh && ./verify` is
  29/29 green, exit 0.
- The Round 4 candidate's own oracle verdicts (`ROUND_SIGNATURE_OK true`,
  `D50 3 -> 4`, depth-7 reach `-0.0108`, no new drift) are in the round-4
  measurement commit and `round4/round4.oracle.json`: the boundary work is
  signature-identical to round 3.
- Disk: the stage actions download ~2 MB of typed artifacts. At ~125 MB free on
  `/`, the full fresh `./verify --nocache_test_results` is not affordable; a
  cached `./verify` is (the library's round23 note still applies: reuse a warm
  output base, never `bazel clean`).
