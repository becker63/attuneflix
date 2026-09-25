# Scientific data architecture

AttuneFlix has one data rule:

> External evidence keeps its native bytes. Every admitted value with
> scientific meaning becomes an explicit typed Parquet artifact. Starlark
> wires artifacts; Flix owns their meaning.

This is deliberately stricter than treating JSON as a control plane. There is
no general scientific JSON tree in permanent HEAD.

## Two type systems, two jobs

At Bazel analysis time, custom Starlark providers say what role an artifact
plays. Their fields are `File` handles and immutable identity strings. Starlark
does not read Parquet rows.

```text
AttuneWorldInfo       metadata + entities + relations
AttunePopulationInfo  metadata + cases
AttuneIssueInfo       issue
AttunePriorInfo       metadata + documents + ranking
AttunePredictionInfo  summary + ranking
AttuneSignatureInfo   observations + physical + snapshot
```

At execution time, the corresponding Flix table module declares the exact
Parquet columns, nullability, protocol identifier, encoding, decoding, and
identity checks.

```text
Bazel File handles
        |
        v
declared action inputs
        |
        v
ScientificTable JVM boundary
        |
        v
typed Flix values
```

The Java Arrow/Parquet layer accepts only the schema and primitive/list values
declared by Flix. It does not interpret repository, Atlas, localization, or
evaluation meaning.

## Canonical typed tables

Permanent schema owners are:

- `Repository.Table`: world metadata, nominal entities, and admitted basis
  relations;
- `Population.Table`: experiment protocol and ordered case/outcome rows;
- `Localization.IssueTable`: admitted problem statement and case identity;
- `Localization.PriorTable`: learned-prior protocol, documents, and ranking;
- `Localization.PredictionTable`: selected condition and ordered prediction;
- `Atlas.Signature.Table`: route observations, physical counters, and snapshot
  identity;
- `Atlas.Signature.Summary`: regenerable signature reductions.

The sealed scale experiment additionally retains typed replay proof,
evaluation metric, region, telemetry, and parity-proof tables in
`experiments/swe-explore-js-ts-scale/`. Their historical producing code is
preserved by the named scientific checkpoints rather than kept as current
runtime architecture.

Tables stay narrow and independently keyed. Parquet unifies representation;
it does not collapse the action graph into one `everything.parquet` file.

## Starlark is artifact control, not a second data language

Rules consume and return providers. Actions receive provider files directly
through `ctx.actions.args()`. Bazel may spill a long argument list into a
generated parameter file. That file is transport, not a scientific format: it
contains paths and has no independent scientific identity.

The census loading graph needs its 78 target labels before execution. Its
checked `census.bzl` projection therefore contains only the ordered target
labels and analysis-time identity strings required to instantiate actions.
The aggregate action reads the canonical typed population and rejects any
repository/revision mismatch. The `.bzl` projection is compiled control data,
not a second authority.

## Capability boundaries

The build graph and Flix types enforce the important boundaries:

```text
Atlas signature       world -> signature
                      no issue, provider, learned decision, or gold edge

localization search   issue + world + typed prior -> unique Atlas outcomes
                      no provider or gold edge

learned judgment      issue + unique outcomes -> typed selection
                      one explicit Judge effect

evaluation            frozen prediction + evaluator-only gold -> metrics
                      gold arrives only after prediction is fixed
```

An acquisition handler may satisfy a learned effect through a provider. A
replay handler may satisfy it from retained evidence. The permanent Atlas
functions themselves are pure; local mutation in physical evaluators cannot
escape its Flix region.

## Allowed non-Parquet files

Not every file should be Parquet:

- Git source, Grit programs, Flix, Java, Rust, Starlark, lockfiles, and build
  configuration are executable or configuration source;
- exact provider response JSON and upstream benchmark bytes remain untouched
  external evidence;
- Markdown is a human projection;
- Bazel-generated parameter files are path transport;
- the small developer Nix flake selects workspace tools but contains no
  project scientific dependency graph.

Admission is the boundary. Once Flix reasons scientifically about external
content, its canonical representation is a named typed Parquet schema.

## Executable laws

`bazel test //...` checks table schemas, typed round trips through Arrow,
repository-world identity, nominal domains, admitted relations, Datalog versus
physical parity, Atlas grammar and signature rows, the typed population, and
the localization sandwich.

Heavy science is named explicitly. The Atlas census consists of 78 independent
signature actions, summary actions, a deterministic aggregate that verifies
the typed population, and a report projection. BuildBuddy executes and caches
that graph; no project Nix expression or source-store path participates.
