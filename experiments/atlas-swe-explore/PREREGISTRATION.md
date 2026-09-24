# Atlas SWE-Explore repository-signature census

Status: preregistered before the full 78-case census.

This experiment measures how frozen repository snapshots respond to the fixed
Atlas language. It does not use issue text, embeddings, Jev, localization
predictions, evaluator gold, or provider access.

Signature protocol: `atlas-signature-swe-explore-v1`.

This identity covers the population unit, issue-blind seed protocol, four
typed output schemas, and primary measurements defined below. The Atlas
language itself has its independent identity
`atlas-composition-depth7-v1`.

## Population and unit

The population is every structurally valid snapshot represented by the frozen
78-case SWE-Explore JavaScript/TypeScript manifest, including the two Three.js
cases censored from localization.

The unit of computation is one unique snapshot:

```text
repository
+ base revision
+ source-tree identity
+ admitted-fact identity
+ Atlas protocol
+ signature protocol
```

Cases sharing all of those values use one signature action. A separate typed
case-to-snapshot table preserves all 78 manifest memberships. Snapshot rows are
never averaged away before repository-level analysis.

## Fixed Atlas language

Protocol name: `atlas-composition-depth7-v1`.

```text
atoms       defines, defined_in, imports, imported_by, calls, callers
operators   composition only
start       File or Symbol, according to the seed panel
depth       every well-typed program of length 1 through 7
order       stable atom order shown above, extended depth first
```

Reverse and union exist in Radii but are not constructors in this Atlas
protocol. There are no learned route choices and no beam. The complete typed
family is evaluated for every seed.

## Issue-blind seed panel

Protocol name: `atlas-signature-seeds-v1`.

Measure eight File seeds and eight Symbol seeds independently per snapshot.
This is a small fixed panel rather than full-domain route materialization:
full-domain output would multiply every repository entity by all 3,279 logical
programs and would mostly increase rows rather than add a cleaner observation.
Sixteen singleton seeds retain domain and within-repository variation while
keeping each snapshot action bounded.

Seed selection is deterministic and does not use vector order as a source of
randomness. Rank identities by unsigned SHA-256 bytes and take the first eight,
or every identity if the domain contains fewer than eight.

```text
File identity bytes:
    "file\0" + UTF-8 repository-relative path

Symbol identity bytes:
    "symbol\0"
    + UTF-8 repository-relative path + "\0"
    + UTF-8 symbol name              + "\0"
    + decimal start byte             + "\0"
    + decimal end byte
```

Hash ties, if any, break by the identity bytes themselves. The stored seed
ordinal is only a join back to the frozen admitted world; it is not part of
seed selection.

This extends the earlier eight-symbol issue-blind control to both Atlas input
domains and evaluates each seed separately. It must not depend on:

- issue text or case identity;
- embedding rank;
- localization or evaluator output;
- file-system enumeration order;
- wall clock or process randomness.

## Primary observation rows

`signatures.parquet` will be typed Parquet with one row per
snapshot × seed × logical Atlas program. Required columns are:

```text
signature_protocol       string
atlas_protocol           string
repository               string
base_revision            string
source_tree_identity     string
fact_identity            string
snapshot_id              string

seed_domain              enum string: file | symbol
seed_identity            string
seed_ordinal             int32

route_id                 string
route_atoms              list<string>
depth                    int32
first_atom               string
last_atom                string
terminal_domain          enum string: file | symbol

input_cardinality        int64
output_cardinality       int64
domain_cardinality       int64
expansion_ratio          nullable float64
reach_fraction           float64
extinct                  boolean
first_extinction_depth   nullable int32
semantic_state_id        string
same_as_input            boolean
```

`semantic_state_id` is a versioned digest of the domain tag plus the sorted
nominal IDs in the exact result set. It is an observation identity, not the
evaluator's private arena index.

`expansion_ratio` is `output_cardinality / input_cardinality`. It is null when
the input is empty. `reach_fraction` is output cardinality divided by the full
compatible terminal domain cardinality; it is zero when that domain is empty.
Because relations map an empty set to an empty set, first extinction is the
first empty prefix of the route.

## Snapshot and physical summary rows

`snapshots.parquet` records one row per unique snapshot:

```text
snapshot identity columns
file_count
symbol_count
defines_count
imports_count
calls_count
parent_count
manifest_case_count
```

`physical.parquet` records one row per snapshot × seed:

```text
logical_routes
unique_semantic_states
physical_transition_requests
physical_transition_evaluations
physical_transition_reuses
logical_per_unique_state
logical_per_physical_evaluation
memo_cells
compiled_dag_nodes
```

`compiled_dag_nodes` is nullable. The current direct Atlas evaluator exposes
an exact transition table but does not compile a separate program DAG; null is
the truthful value for that implementation. `memo_cells` is exact because
every physical transition-table miss inserts exactly one cell.

The current evaluator may use a query-local arena index internally, but
persisted recurrence is computed from the exact versioned state identity.
Physical reuse counters remain direct evaluator counters. Do not reconstruct a
counter the implementation cannot report truthfully.

`case-snapshots.parquet` contains the manifest position, case ID, frozen split,
repository, revision, and snapshot ID. It is the only place where an issue case
enters this experiment.

## Primary signature summaries

Summaries remain separate by snapshot, seed domain, direction, and depth. The
primary repository signature is a table, not one score.

### Extinction

- empty-output fraction;
- survival fraction at each depth;
- distribution of first-extinction depth;
- the same quantities by final atom direction.

### Expansion

- output cardinality p50, p90, and p99;
- expansion-ratio p50, p90, and p99 over non-empty inputs;
- fraction contracting, unchanged, and expanding.

No post-hoc “explosion” cutoff is a primary metric.

### Reach

- reach-fraction p50, p90, and p99;
- fraction reaching at least 25%, 50%, and 90% of the compatible domain;
- directional differences for imports/imported_by and calls/callers.

The fixed thresholds are declared here before the census.

### Recurrence

- logical observations and unique exact semantic states;
- logical/state compression ratio;
- state multiplicity p50, p90, p99, and maximum;
- same-as-input continuation fraction;
- recurrence by depth and seed domain.

### Physical reuse

- transition requests, evaluations, and reuse hits;
- logical-route/physical-evaluation compression;
- unique-state/memo-cell counts;
- compiled DAG nodes.

Logical recurrence and evaluator reuse are reported separately.

## Analysis order

1. Freeze the typed snapshot-level rows.
2. Produce the preregistered summaries above.
3. Compare repositories without assigning a quality rank.
4. For repositories with multiple revisions, measure within-repository drift
   using per-feature absolute differences and Spearman correlation over the
   common normalized summary vector.
5. Check size confounding with file/symbol counts versus normalized reach,
   extinction, directionality, recurrence, and compression.
6. Optionally inspect simple standardized-feature clustering as exploratory.
7. Only after both datasets are frozen, join signature features to localization
   results. Mark every such relationship post hoc.

## Execution and cost

Each unique snapshot is one independent Bazel action. Aggregation and report
generation consume only those declared Parquet outputs. BuildBuddy may execute
and cache the actions remotely, but execution location is not a scientific
input. The run uses no paid provider calls.

Record cold and warm wall time, action count, remote/local action count, peak
worker memory where available, cache hits, critical path, and the sum of action
execution time. A clean local Bazel run must remain possible.

## Failure and missingness

A snapshot is included only when its retained facts pass repository, revision,
source-tree, Grit, Marzano, and fact-protocol identity checks. A missing or
invalid structural snapshot is Atlas-specific missingness; it is not inherited
from localization censoring. Completed snapshot actions remain valid if another
snapshot fails.

## Claims this experiment does not preregister

This census does not claim that signatures identify repository authors, define
a taxonomy, cause localization performance, or remain stable across arbitrary
future revisions. Architectural-drift lint, test selection, community studies,
and localization relationships are later applications or exploratory analyses.
