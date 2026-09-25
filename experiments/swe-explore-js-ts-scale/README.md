# Frozen SWE-Explore JavaScript/TypeScript scale experiment

This directory is the durable public record of the sealed 78-case study. Its
scientific population and final results are explicit typed Parquet datasets;
Markdown is the human projection.

## Canonical evidence

| Artifact | Typed protocol | Meaning |
| --- | --- | --- |
| `population-metadata.parquet` | `attune-population-metadata-v1` | Benchmark revisions, source routing, Atlas protocol, depth, centers, and route counts |
| `population-cases.parquet` | `attune-population-cases-v1` | Ordered 78-case population, split membership, source identity, and completed/censored outcome |
| `replay-proof.parquet` | `attune-localization-replay-proof-v1` | Exact 61-case typed prior/prediction replay proof |
| `evaluation-metrics.parquet` | `attune-localization-evaluation-metrics-v1` | Per-case, per-condition official metrics |
| `evaluation-regions.parquet` | `attune-localization-evaluation-regions-v1` | Exact projected regions used by evaluation |
| `evaluation-telemetry.parquet` | `attune-localization-evaluation-telemetry-v1` | Logical routes, semantic states, projections, and actual score evaluations |
| `evaluation-proof.parquet` | `attune-localization-evaluation-proof-v1` | Exact/discrete and floating-tolerance parity verdicts |

The copied public artifacts are byte-identical to the aggregate typed outputs
that passed the remote 61-case migration proof. Their SHA-256 identities are:

```text
population-metadata  5ce53f52cae6a4fd8cb04b87e8f0e94a5ce575b2e3de1e87630d146793ead72e
population-cases     5ed376e8be9f77e4acd6b030fe2263d2868de36a5011343f973bfe91b2dc695a
replay-proof         3871e0648b196b728a0a18c145b5326e905f33430fe7b0a341133d5561215fe0
evaluation-metrics   894a9bd77d023c221f27bc2a13e637718f1cf438e9d9bd34209991d2021c95cf
evaluation-regions   aa97aa3cc8c1824d690839dccb0c1d0ec6ade5f7409d9bc489c33a2911dda684
evaluation-telemetry 5b00c582d765995f118d4b4bbc2a4d346649eeb4c4ed961caa85266e1ddd327b
evaluation-proof     7836992d7bbc5090a52a0047506b6fa3c5af9fc2b3f3f2de66523ee07828fcb5
```

`REPORT.md` and `USAGE.md` explain the result, timing, provider-token, and
cost evidence. Exact external provider response envelopes remain immutable in
their native JSON because the original bytes are the evidence. They are not
the internal data model.

## Population and censors

The order is frozen: 15 historical-development cases and 63 new cases, with
the new population split into 42 optimization-development and 21 untouched
post-optimization-validation cases. Sixty-one new cases completed. The two
remaining validation cases are `mrdoob__three.js-26589` and
`mrdoob__three.js-27395`; their frozen 48,000-codepoint input produces 40,961
tokens for a model with a 40,960-token limit. They remain explicit censors.

No clip, model, case, evaluator rule, gold boundary, or iteration-013 policy
was changed to make them complete.

## Reproduction boundary

The historical iteration-013 acquisition/replay/evaluator implementation was
removed from permanent HEAD after exact migration. Its final executable
checkpoints remain in Jujutsu history:

```text
07efad98  typed prior/prediction migration and exact 61-case replay
4010bc68  typed evaluator parity
e274a1f5  generic JSON-tree migration representation removed
711f4b54  permanent localization reduced to prior -> Atlas -> judge
```

The current program is not a museum of the old selector. The frozen Parquet
evidence, reports, checksums, BuildBuddy invocations, and history preserve the
result. Current localization code implements the smaller reusable sandwich.
