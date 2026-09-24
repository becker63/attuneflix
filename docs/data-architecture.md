# Scientific data architecture

AttuneFlix has one repository-wide data rule:

> External formats vary. Internal scientific datasets are Parquet. JSON is the
> control plane. Markdown is the human plane.

During the Bazel migration, pinned Nix expressions still fetch several exact
upstream datasets and project only the fields a capability may receive. In
particular, solver-visible issue projections remain gold-free; evaluator gold
is built separately. Those pins and projections are moving into Bazel rather
than remaining an application runtime. After ingestion, Flix owns the data
meaning and uses the small Bazel-built JVM seam in `src/native/parquet/`. No
DuckDB database or second storage layer exists.

## Canonical Parquet schemas

New canonical datasets declare real columns in Flix through
`ScientificTable.Schema`. The JVM boundary accepts only the declared column
names, primitive/list types, and nullability, then moves those values through
Arrow into Parquet. Dataset protocol identities are ordinary required columns,
not hidden Java metadata. The four preregistered Atlas census schemas live in
`Atlas.Signature.Table` and are checked as executable laws.

`attune-json-tree-v1` below is the retained migration representation for the
already-frozen localization evidence. It remains readable while those
artifacts are migrated and compared semantically, but it is not the schema for
new Atlas data and is not the intended final representation.

Most nested experiment artifacts use `attune-json-tree-v1`. Each Parquet row is
one JSON semantic node with these columns:

| Column | Meaning |
| --- | --- |
| `path: list<string>` | Typed object-key/array-index path from the single root |
| `node_type: string` | `object`, `array`, `null`, `boolean`, `integer`, `float`, or `string` |
| `string_value` | String payload when applicable |
| `integer_value` | Signed 64-bit integer payload when applicable |
| `float_value` | IEEE-754 double payload when applicable |
| `boolean_value` | Boolean payload when applicable |

This versioned representation preserves absent versus null fields, empty
containers, integer/float identity, and array order. Object keys are serialized
in deterministic order. It changes serialization bytes, not experiment
semantics; migration was admitted only after strict recursive type-and-value
comparison against every source artifact.

The replication census is the naturally tabular `attune-tabular-v1` schema:
11 rows and the 15 named columns described in
[`docs/replication/README.md`](replication/README.md). Its Parquet metadata
retains the SHA-256 of the historical TSV representation.

## Persisted artifacts

- `docs/replication/replication.parquet` is the frozen replication census.
- `docs/research/jev/*.parquet` contains the frozen 15-case result and
  post-hoc diagnosis; the adjacent reports retain historical JSON hashes where
  those hashes are part of the record.
- `experiments/jev-policy-hillclimb/iterations/*/metrics.parquet` contains each
  frozen iteration's complete metrics. Each adjacent `REPORT.md` explains its
  provenance and regeneration path.
- `.attune/repository-facts-*/**.parquet`, semantic-prior rankings, scale
  predictions, and evaluator outputs are local canonical scientific evidence.
  Raw provider response envelopes remain JSON because they are immutable
  observations whose exact response bytes are the control/replay boundary.

`MANIFEST.json`, the two small `route-templates.json` policy descriptors,
protocol metadata, lockfiles, and configuration remain JSON/TOML because they
are control objects rather than datasets.

## Executable laws

`nix/check-data-plane.py`, called by `./verify`, rejects tracked canonical data
with CSV/TSV/JSONL/NDJSON, Arrow IPC, pickle, SQLite, or DuckDB extensions. It
also rejects experiment implementation code that names direct CSV/TSV/JSONL
inputs outside `nix/`, validates Parquet magic and schema metadata, and requires
nearby Markdown for committed Parquet. Its self-test exercises accepted and
rejected paths before the repository scan.
