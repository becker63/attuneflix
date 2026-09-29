# Atlas Families acquisition protocol

Version 1. Two issue-blind protocols acquire the fresh evidence the families
experiment clusters over: Jev family-formation decisions
(`attune-jev-families-v1`, space `jev-families-raw-v1`) and callable embeddings
(`attune-families-embeddings-v1`, space `families-embeddings-v1`). Both are
owned by `src/Families/Protocol.flix`. The constants block below is rendered
from that module by `:protocol_constants` and pinned byte for byte by
`:report_test`, so this document cannot drift from the code.
The $5 cap applies to new passes. The retained Preact pass keeps its recorded
$50 envelope for exact keyless replay.

<!-- families:protocol:begin -->
| constant | value |
|---|---|
| decision protocol | `attune-jev-families-v1` |
| decision space | `jev-families-raw-v1` |
| decision endpoint | `https://openrouter.ai/api/alpha/decisions` |
| decision model | `typesafe/jev-1.13` |
| state header | `ATTUNE_FAMILIES_STATE_V1` |
| state identity protocol | `attune-families-state-v1` |
| objective | `family-formation` |
| maximum depth | `7` |
| preview members | `8` |
| name candidates | `6` |
| navigation question | `next_action` |
| naming question | `family_name` |
| embedding protocol | `attune-families-embeddings-v1` |
| embedding space | `families-embeddings-v1` |
| embedding endpoint | `https://openrouter.ai/api/v1/embeddings` |
| embedding model | `qwen/qwen3-embedding-8b` |
| dimension | `4096` |
| document limit (code points) | `48000` |
| batch size | `64` |
| encoding format | `base64` |
| ledger protocol | `attune-families-ledger-v1` |
| pass envelope USD | `5.000000` |
| historical Preact envelope USD | `50.000000` |
| embedding USD per token | `0.00000001` |
| decision USD bound | `0.000200` |
| bounded seeds per pass | `3000` |

Navigation instructions (`next_action`):

> Choose the typed repository-structure action that grows the seed into the most coherent code family: entities that serve one shared purpose and belong together as one unit of the repository. Prefer an action whose result stays focused on the seed's purpose, and avoid an action that pulls in unrelated code. Choose stop when the current frontier is already a more coherent family than every available structural child.

Naming instructions (`family_name`):

> Choose the repository location that best names the family grown from the seed: the most specific location that still describes what the family's members have in common.
<!-- families:protocol:end -->

## Issue-blindness

Every provider payload is a pure function of the protocol constants and one
admitted repository world (`Repository.World`: files, callables, the six
directed relations, and exact source spans). Nothing else reaches the
boundary:

- no issue text, no benchmark instance, no evaluator gold (`gold.parquet`,
  `jev-selection-diagnosis-v1`), and no frozen localization population or
  input space is read by the families tool;
- decision states carry repository structure only (typed previews: domain,
  cardinality, and the first members in admitted order), never a source body;
- embedding documents have no query side: no issue, instruction, or query text
  is ever embedded.

`:issue_blindness_test` scans the tool's sources for Localization modules,
issue fields, and gold or population space names, and scans the request of
every retained exchange for issue and gold markers. `:families_test` pins the
same property structurally: every decision payload is exactly the model,
the fixed state, and the questions, and names only paths, callables, domains,
and cardinalities (never a source body). `replay_<world>` reconstructs every
retained request from the protocol and the world alone.

## Decisions: family-formation navigation

**Seeds.** Every file that defines at least one callable seeds one navigation,
in admitted file order. The seed frontier is `Files({file})`.

**Navigation over the six-atom typed tree.** At each frontier the offered
children are exactly Atlas's own evaluation (`Atlas.evaluate` over
`Atlas.programsFrom(domain, 1)`) of the three atoms the frontier's domain
admits: `defines`, `imports`, `imported_by` from files; `defined_in`, `calls`,
`callers` from symbols. A child is offered only when it is nonempty and differs
from the current frontier. The route never extends past Atlas's frozen depth
seven. The protocol adds no atom and no rule; every family is the output of one
Atlas program.

**Navigation question** (`next_action`, a Jev `choice`): the alternatives are
`stop` (keep the current frontier; always offered first) followed by one
`take <atom>` per offered child in Atlas's stable atom order. Each criterion
carries the typed preview of the frontier that alternative leads to. A walk
ends when Jev chooses `stop`, when no child is offered, or at depth seven.

**Naming question** (`family_name`, a Jev `choice`): the candidates are the
repository locations holding the terminal frontier's members (each member's
file and every non-root directory above it), ranked by members held, then
specificity (longer path first), then path, and capped at six. Each criterion
states the location's kind and how many of the family's members it holds. When
a single location holds the whole family the protocol names it without a
decision (`named = false`).

**State.** The model-visible state is fixed text:

```text
ATTUNE_FAMILIES_STATE_V1
objective: family-formation
repository: <owner/name>
seed: <preview of the seed frontier>
depth: <route length>/7
path: <route atoms, or (seed)>
current: <preview of the current frontier>
```

A preview is `domain=<file|symbol> cardinality=<n> top=[<first eight members>]`,
where a file member is its path and a symbol member is `path :: name`.

**Decision schema.** A request body is
`{"model", "state", "questions": {<question>: {"type": "choice",
"instructions", "criteria": {<key>: <criterion>}}}}`. An admitted observation
is the typed choice answer: the chosen key (which must be offered), its index,
the confidence, the probability of every offered alternative in alternative
order, the served model (the pinned model or one of its dated snapshots), the
provider, the response id, and the provider's own input tokens, output tokens,
and cost.

## Embeddings: callable documents

One document per admitted callable, in `Repository.World.symbols` order. The
text is the frozen document recipe `path:name\n<exact source bytes of the
admitted span>`, read from the world's retained source root and cut at the
frozen code-point limit (the cut is recorded as `truncated`). A span the root
cannot supply exactly, or that does not name its callable, is rejected before
any call. Documents are batched in order at the frozen 64-text boundary; each
batch is one request with `encoding_format = base64`. Vectors are admitted
through the SDK's own decoder (little-endian float32), checked for order and
dimension, and recorded in the typed table as one SHA-256 per vector; the
vectors themselves stay in the retained raw bodies.

## Caching and evidence

- **Request identity.** Every request has a versioned, content-derived identity
  (`ScientificIdentity.versioned`) over length-prefixed parts: protocol,
  provider, endpoint, model, and the exact payload, plus the world snapshot,
  the exact frontier identity, and every alternative's key and exact target
  for decisions (previews are bounded, so two frontiers can share a payload),
  and the encoding, dimension, and ordered inputs for embeddings. The
  credential is never a part.
- **Store first.** Every request is resolved from the content-addressed store
  (`raw/<digest>.json` under the world's space directory) before any transport
  is considered. A retained exchange whose request differs from the
  reconstructed payload is an error, never a silent reuse. An unchanged
  request is acquired exactly once; a re-run makes zero provider calls.
- **Retain before admission.** A live body is written atomically, with the
  provider response id intact, before it is admitted. Existing evidence is
  never replaced. Provider and transport errors are not observations and are
  not retained.
- **Typed projections.** Each world's spaces carry six typed Parquet tables
  with explicit schemas and exact round-trips: `documents.parquet`,
  `batches.parquet`, and `ledger.parquet` (embeddings); `decisions.parquet`,
  `outcomes.parquet`, and `ledger.parquet` (decisions). A table is written only
  after the complete world's raw evidence is admitted, and an existing table must equal the
  regenerated one.

## Budget accounting

- **Envelope.** One acquisition pass is bounded by the pass envelope.
- **Projection before any call.** The whole-world projection bounds embeddings
  by document bytes times the catalog price per token (a token covers at least
  one byte) and decisions by `seeds x (7 + 1)` times the per-decision bound.
  A world below the envelope uses one pass. A larger world uses one embedding
  pass and original-ordinal ranges of at most 3,000 seeds. Each bounded
  decision pass has a conservative bound of at most $4.80. The six whole-world
  typed tables are materialized only after every raw exchange is recorded,
  with `Refuse` transport and no provider calls.
- **Measured stop.** The live handler stops before a call once the pass's
  measured spend (the provider's own `usage.cost`) reaches the envelope.
- **Ledger.** Each space records one typed ledger row per world: requests, requests
  with a reported cost, input and output tokens, measured cost, unit cost,
  projection, and envelope, all from the provider's own usage fields. Bounded
  passes also retain a per-pass JSON record under `passes/` with the original
  seed range and the full sum of provider-reported usage costs over its logical
  observations, including store hits after a resumed attempt. The acquired
  count separately records new calls in the successful attempt. Those records are
  declared Bazel inputs and included in the BuildBuddy evidence archive.

## Transport and replay

The Flix provider effect is the only boundary. Its handler serves a store miss
in one of three ways: `Live` (the in-tree LangChain4j seam in
`src/native/inference`, the only reader of the key, used only by
`acquire_<world>`), `Refuse` (keyless replay: a miss is an error and no
transport exists), or `Simulated` (an in-process stand-in for law tests).
`replay_<world>` runs the whole pipeline under `Refuse` with no key in the
environment, over the recorded spaces as Bazel inputs, and fails unless every
regenerated table equals its recorded table exactly and zero provider calls
were made.

## Running an acquisition

The launcher is the only entry point that can reach the provider. From the
repository root:

```bash
nix develop --command bazel run --script_path=/tmp/acquire_preact \
  //experiments/atlas-families:acquire_preact --config=buildbuddy-rbe-arm64
ATTUNE_WORKSPACE=$PWD /tmp/acquire_preact <retained source root> project   # projection only, keyless
ATTUNE_WORKSPACE=$PWD OPENROUTER_API_KEY=... /tmp/acquire_preact <retained source root> acquire
```

The key is taken from the environment of that one command (the git-ignored
`.env`) and is never printed, logged, or committed.

After a whole world has six typed tables, `seal_evidence.py` declares its raw
envelopes and typed tables as Bazel inputs. A hermetic Starlark action packages
each world's two evidence spaces into a deterministic ZIP in BuildBuddy's CAS;
the small address index in `evidence-cas-index.json` makes those remote bytes
locatable from a fresh checkout:

```bash
python3 experiments/atlas-families/seal_evidence.py
nix develop --command bazel build //experiments/atlas-families:evidence_cas_index \
  --config=atlas-families-evidence-archive
cp bazel-bin/experiments/atlas-families/evidence-cas-index.json \
  experiments/atlas-families/evidence-cas-index.json
python3 experiments/atlas-families/evidence_cas.py verify \
  --index experiments/atlas-families/evidence-cas-index.json
# On a checkout missing one world's evidence, with at least 5 GiB free:
python3 experiments/atlas-families/evidence_cas.py hydrate \
  --index experiments/atlas-families/evidence-cas-index.json --digest <snapshot-digest>
python3 experiments/atlas-families/seal_evidence.py
```

`verify` retrieves every indexed blob and checks its SHA-256, ZIP integrity,
and typed-table presence without contacting a provider. `hydrate` restores
missing inputs atomically and checks existing bytes without replacing them.
BuildBuddy is a cache that may evict entries, so the local recorded evidence
is retained until a separate durable archive exists.

## Clustering method (`atlas-families-v1`)

The clustering is a pure function of one admitted world and its recorded
evidence: no provider, key, issue, or gold is reachable from it. It is owned by
`src/Families/Method.flix` (the versioned constants below, rendered by
`:method_constants` and pinned by `:report_test`), `src/Families/Cluster.flix`
(the method), `src/Families/Affinity.flix` (the affinity substrate),
`src/Families/Rollup.flix` (the location rollup), and
`src/Families/Cluster/Table.flix` (the three typed tables). Changing any
constant is a new method version.

<!-- families:method:begin -->
| constant | value |
|---|---|
| method protocol | `atlas-families-v1` |
| output space | `atlas-families-v1` |
| families table | `attune-atlas-families-v1` |
| members table | `attune-atlas-families-members-v1` |
| rollups table | `attune-atlas-families-rollups-v1` |
| family edges table | `attune-atlas-family-edges-v1` |
| edge contributions table | `attune-atlas-family-edge-contributions-v1` |
| weight: same file | `0.30` |
| weight: calls | `0.20` |
| weight: imports | `0.15` |
| weight: directory | `0.10` |
| weight: semantic | `0.25` |
<!-- families:method:end -->

1. **Candidates (Jev-decided agglomeration).** Every seed's recorded route is
   replayed through Atlas's own evaluator from the seed file to its exact
   terminal frontier, which must carry the recorded `state_id`; the recorded
   preview is never read. A file frontier is read at symbol grain (the
   callables its files define). Seeds whose frontiers hold the same nonempty
   members are one candidate; its representative is the least seed.
2. **Names.** A candidate carries its representative's recorded name, and the
   name is admitted only as the protocol produces it: a named family's name is
   the target its recorded `family_name` decision chose on that frontier (the
   decision identity is kept as `name_decision`), and an unnamed family's name
   is the frontier's only candidate location.
3. **Affinity.** A symbol's affinity to a candidate is the weighted sum of five
   indicators, each averaged over the candidate's other members: sharing a
   defining file (`Defines`/`DefinedIn`), a call edge in either direction
   (`Calls`/`Callers`), an import edge between the two files in either
   direction (`Imports`/`ImportedBy`), sharing a directory (the admitted
   `parent` prefixes), and the cosine similarity of the two recorded embedding
   vectors. The vectors are decoded from the retained raw batch bodies and each
   must carry the SHA-256 digest the typed batch table admitted for it. The
   first four indicators are the structural source, the fifth the semantic
   source.
4. **Assignment.** Each symbol joins, among the candidates whose frontier holds
   it, the one with the greatest affinity (the least candidate on a tie). A
   symbol no frontier holds joins the candidate of its own defining file's
   seed.
5. **Families.** The candidates that keep at least one member, in candidate
   order, numbered from 0. A family's identity is
   `ScientificIdentity.versioned("atlas-families-v1", snapshot + "\n" +
   "symbol:<id>" per member, ascending)`: it is derived from the exact admitted
   members, never from a path or a name.
6. **Rollup.** A file holds the members it defines and a directory holds the
   members of every file below it (root `""` included). Each (location, family)
   row counts the family's members there out of the location's members; the
   dominant family has the most members, the least family on a tie.
7. **Family edges.** Every exact `imports` (file grain) and `calls` (symbol
   grain) edge of the world is one contribution, attributed to the families of
   its endpoints: a symbol's family is its member row, a file's family is its
   dominant file rollup, and a file that defines no callable has no family, so
   an import that touches one stays an unattributed contribution. The
   attributed contributions of each relation and ordered family pair aggregate
   to one family edge with their count as multiplicity; no other family edge
   exists. Owned by `src/Families/Edge.flix` (the aggregation) and
   `src/Families/Edge/Table.flix` (the two typed tables).
8. **Export.** The Atlas Live export of a world is its three clustering tables
   and two family-edge tables under the data-tree names (`families.parquet`,
   `family_<table>.parquet` for the rest), written by `Families.Export`; the
   exporter refuses edge tables that are not the aggregation of the clustering
   beside them. The web projection stages the export beside the locations
   tables and ships it as `data/<digest>/` with a manifest entry; it never
   derives any of it.

The method runs as hermetic Bazel actions (`families_clusterings` in
`families.bzl`): `cluster_<world>` reads only the frozen world tables and the
two recorded evidence filegroups and writes `families.parquet`,
`members.parquet`, and `rollups.parquet`; `cluster_<world>_rerun` is the same
derivation as an independent action. The tables are content-addressed
BuildBuddy remote-cache outputs, never git-tracked evidence. Build them with
`nix develop --command bazel build //experiments/atlas-families:cluster_preact --config=buildbuddy-rbe-arm64`.

The edge and export stages are hermetic Bazel actions in the same pattern
(`families_exports` in `families.bzl`): `edges_<world>` aggregates the family
edges from the frozen world tables and `cluster_<world>`, and `export_<world>`
writes the `<snapshot digest>/` tree Atlas Live ships, staged by
`//web/atlas-live/projection:families` beside `:locations` and copied into the
web data tree by `project_cli` with a manifest entry. The
`families_export_parity_test` law holds the staging to the Flix-built tables,
byte for byte and row for row.
