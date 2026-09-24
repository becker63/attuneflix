# Frozen SWE-Explore JavaScript/TypeScript scale experiment

This directory owns the frozen 78-case generalization study. `MANIFEST.json` is
the small control-plane identity: 15 historical-development cases and 63 new
cases, with the new population fixed as 42 optimization-development and 21
post-optimization-validation cases. Original manifest order determines shard
assignment before historical cases are skipped.

The scientific protocol is unchanged by the Parquet migration: pinned source
revisions, Marzano/Grit identity, relation definitions, Atlas grammar,
`CENTER_COUNT`, `MAX_DEPTH`, embedding provider/model/instruction/clipping,
request identity, cosine ranking with source-order ties, frozen iteration 013,
Jev requests, evaluator semantics, and gold isolation all retain their prior
meaning.

Local canonical evidence lives below `.attune/`:

- `repository-world-v1/*/{metadata,entities,relations}.parquet` — typed worlds
  for all 78 snapshots, migrated exactly from the retained observations;
- `semantic-prior-js-ts-scale-v1/rankings/*.parquet` — per-case documents and
  cosine rankings; raw provider envelopes remain JSON under `observations/`;
- `experiments/swe-explore-js-ts-scale/013-predictions/*.parquet` — frozen
  predictions retained before gold is introduced.

`results-censored.parquet` is the canonical sealed evaluator output. The
current graph exposes one keyless replay action and one bounded-lifetime
evaluation action per completed case, followed by deterministic aggregates:

```text
bazel build //.attune:localization_replay
bazel build //.attune:localization_evaluation
```

The aggregate validates exact 61-case order, the 42/19 completed split, exact
predictions, discrete evaluator equality, and the frozen `1e-10` floating
tolerance. Bazel actions receive only declared inputs; the developer-shell
wrapper does not pass `OPENROUTER_API_KEY`. The former environment-variable
range runner is preserved in the pre-refactor scientific checkpoint, not at
HEAD. Retained-evidence and timing provenance is in `USAGE.md`.

## Retained run status

The 2026-09-23 completion pass validated repository facts for all 63 new
cases. Semantic-prior rankings are complete for 61 cases. The two remaining
cases are `mrdoob__three.js-26589` and `mrdoob__three.js-27395`, both in the
post-optimization-validation population. Their frozen 48,000-codepoint input
produces a 40,961-token request for a model with a 40,960-token context limit;
OpenRouter rejects that exact request with HTTP 400. Reducing the frozen clip,
changing the model, or dropping a document would create a new scientific
condition, so this run records the failure rather than doing so.

The authorized run is now terminal: all 61 admissible predictions replayed
exactly without a provider credential, evaluator gold was opened only after
that freeze, and all 61 cases were scored. The two failures remain explicit
censors; they are not silently removed from the validation denominator.

## Frozen identities

- manifest SHA-256: `30451e14687618b9e9727e56cfe38825dc951539ed6a1702496326749ce38740`;
- admitted Grit-program aggregate: `028fa25c577a0ebad789cc4ab64092598aeb6787632beb568ec0d7417613d937`;
- frozen Atlas source: `8899efa83b4def48ed9871399ecec7d98016d21310179dd5a8df4197bc5673bb`;
- retained decision aggregate: `969a0cbe7779e4569e474fa8b4ddcc40c2a41ea4a1a3583f6918eb9176898a85`;
- canonical result Parquet: `061f5f9cc45a54bc176b48efca99f1405645220d6a8fe0627f43a0aba9c0aea0`;
- generated report: `e3ca12e7f96ff24fa7e376277e98fa8f6fa7464c5c9acb619a75ac6dfe3cae28`.

The result file uses the current inline `attune-json-tree-v1` representation.
Its decoded scientific rows are identical to the pre-column migration; only
the explicit representation identity and Parquet bytes changed.
