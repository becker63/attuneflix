# Atlas Families — charter and report

Atlas Families is a new application of Atlas. It clusters the admitted entities
of a frozen repository world into **families** and aggregates the world's exact
edges into family-level edges, so the existing relations become legible on the
Atlas Live map. It is a Research-cell experiment: it adds no atom, no depth, no
repository rule, and no Datalog or evaluator meaning. It consumes the frozen
six-atom program family (`Defines`, `DefinedIn`, `Imports`, `ImportedBy`,
`Calls`, `Callers`) exactly as the census and the repository signatures do.

This file is the experiment's charter. Later sections record the protocol,
per-world records, cost ledgers, replay proofs, and contrast numbers as they
land. Every number in a generated block is a Bazel projection of a typed table,
pinned byte for byte by `:report_test`.

## Protocol intent

- **Issue-blind.** Families are a property of the repository, not of any
  issue. No issue text, no evaluator gold (`gold.parquet`,
  `jev-selection-diagnosis-v1`), and no frozen localization population is ever
  read, and none appears in any provider payload, decision state, or prompt.
- **Acquire once, then deterministic.** Provider outputs are recorded as
  content-addressed evidence: raw envelopes with provider response ids intact,
  typed projections, and a per-pass cost ledger. Clustering, aggregation,
  export, and rendering are pure functions of the recorded evidence. Replay is
  keyless and exact.
- **Two fresh evidence sources.**
  - Embeddings: `qwen/qwen3-embedding-8b`, one document per admitted callable
    (the `Defines` symbol grain), document text = node identity plus the exact
    admitted source span (the frozen document recipe, with no query side).
    Space `families-embeddings-v1`.
  - Jev decisions: navigation over the six-atom typed tree with a
    family-formation objective (grow-from-seed and naming decisions), through
    the in-tree inference client. Protocol `attune-jev-families-v1`, space
    `jev-families-raw-v1`.
  - The exact schema, navigation, prompts, caching, and budget accounting are
    in [PROTOCOL.md](PROTOCOL.md).
- **Method.** Structural affinity (same-file co-membership, call and import
  adjacency, directory co-membership) plus embedding similarity forms the
  substrate; recorded Jev decisions drive agglomeration and naming. Families
  are defined at symbol grain and roll up deterministically to files and
  directories. Output space `atlas-families-v1`.
- **No invention.** Every family member resolves to an exact admitted entity
  row, and every family edge aggregates exact world edges with multiplicity and
  its contributing rows.
- **Quality bar.** The experiment is written at `src/`-promotion quality:
  `src/Families/**` mirrors the repository `src/` layout, every table has an
  explicit schema owner and an exact round-trip law, and every identity is a
  versioned, content-derived protocol.

## Acquisition ruling

On 2026-09-28 the user ruled, verbatim:

- "you can unfreeze data btw id prefer you essentially create a new experiment
  for this problem"
- "yes usage of openrouter keys is relaxed id prefer you aquire new data"

The repository `AGENTS.md` records the ruling as the acquisition-zone
carve-out in "Scientific no-reacquisition rules". OpenRouter acquisition and
new derived evidence are authorized for this experiment only, and only within
`experiments/atlas-families/`. The experiment may create and regenerate only
its own new spaces (`jev-families-raw-v1`, `families-embeddings-v1`,
`atlas-families-v1`, and the family edge and export tables). Every other
no-reacquisition prohibition still binds, inside and outside the zone: existing
`.attune/` spaces and retained provider evidence stay read-only, evaluator gold
is never read, and the frozen populations, iteration 013, the Three.js censors,
the six atoms, depth seven, Datalog meaning, and evaluator meaning are
untouched. `:charter_test` pins the carve-out and the unchanged paragraph.

The key lives only in the git-ignored `.env`. It is never printed, logged, or
committed, and replay runs with no key in the environment.

## Cost envelope

- **Envelope:** $50 per acquisition pass (proposed at mission acceptance,
  adjustable at the milestone-1 review).
- **Measure first:** unit costs (per embedding document and per Jev decision)
  are measured on the smallest planned world first, from the provider's own
  usage and cost fields, and recorded in the pass ledger.
- **Project before scaling:** the pass cost is projected from the measured unit
  costs and the inventory below before any further world is acquired.
- **Stop-check:** if the projection exceeds the envelope, acquisition stops and
  the numbers go to the user. No pass exceeds the envelope on the experiment's
  own authority.
- **Acquire once:** requests are cached by content-addressed request identity,
  so a re-run over an unchanged payload makes zero provider calls.

### Acquisition inventory (representative frozen worlds)

The embedding pass is sized by the callable count and the callable source bytes
of each world (each document is additionally capped by the frozen per-document
text limit). The representative snapshot per repository is the one with the
fewest points, the rule Atlas Live uses for its default world. The generated
synthetic stress fixture is not a frozen census world and is not inventoried
here. Regenerate with
`nix develop --command bazel build //experiments/atlas-families:inventory_report --config=buildbuddy-rbe-arm64`.

<!-- families:inventory:begin -->
| repository | snapshot | files | callables | directories | imports | calls | parents | callable source bytes |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| preactjs/preact | `6e2bef41bf19` | 210 | 1623 | 42 | 205 | 604 | 251 | 286019 |
| axios/axios | `1e44a1c45ec4` | 114 | 295 | 35 | 140 | 220 | 148 | 123395 |
| immutable-js/immutable-js | `f0d3c13774ad` | 192 | 618 | 19 | 351 | 793 | 210 | 227604 |
| NodeBB/NodeBB | `d13b9c7923b4` | 721 | 1367 | 109 | 2425 | 1137 | 829 | 762860 |
| vuejs/core | `96c87d888005` | 516 | 4149 | 79 | 1177 | 4594 | 594 | 1711739 |
| protonmail/webclients | `d88ee1076ffd` | 3427 | 8942 | 590 | 7999 | 14573 | 4016 | 7987839 |
| babel/babel | `002a462e6f58` | 15286 | 13362 | 11482 | 897 | 10066 | 26767 | 3322991 |
| **total** | | 20466 | 30356 | 12356 | 13194 | 31987 | 32815 | 14422447 |
<!-- families:inventory:end -->

The counts equal the Atlas Live manifest rows for the same snapshots (files,
symbols, directories, imports, calls, parent edges). A full representative
embedding pass is therefore 30,356 documents over at most 14,422,447 source
bytes. protonmail/webclients carries the most source bytes (55% of the total)
despite having fewer callables than babel/babel.

## Acquisition record

The first pass ran on the smallest planned world, preactjs/preact, through
`acquire_preact` with the real OpenRouter API (protocol in
[PROTOCOL.md](PROTOCOL.md)). The pre-acquisition projection for the world was
0.277180 USD against the 50 USD envelope, so the pass proceeded. A second live
run over the unchanged payloads resolved every request from the retained
evidence and made zero provider calls. The block below is projected from the
recorded ledgers and from `replay_preact`, the keyless replay proof that Bazel
rebuilds with no key in the environment and no transport. Regenerate with
`nix develop --command bazel build //experiments/atlas-families:acquisition_report --config=buildbuddy-rbe-arm64`.

<!-- families:acquisition:begin -->
**Recorded evidence**

| repository | snapshot | documents | batches | seeds | decisions | retained exchanges |
|---|---|---:|---:|---:|---:|---:|
| preactjs/preact | `6e2bef41bf19` | 1623 | 26 | 171 | 461 | 487 |

**Cost ledger** (provider-reported usage and cost)

| repository | space | request | requests | cost reported | input tokens | output tokens | cost USD | unit USD | projected USD |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| preactjs/preact | `families-embeddings-v1` | embedding-batch | 26 | 26 | 101545 | 0 | 0.001015 | 0.000039 | 0.003580 |
| preactjs/preact | `jev-families-raw-v1` | decision | 461 | 461 | 270037 | 20650 | 0.011342 | 0.000025 | 0.273600 |
| **total** | | | 487 | | | | 0.012357 | | 0.277180 |

Pass envelope: 50.000000 USD. Measured total: 0.012357 USD.

**Keyless replay proof**

| repository | table | rows | recorded identity | replayed identity | equal |
|---|---|---:|---|---|---|
| preactjs/preact | embedding-documents | 1623 | `33bf1cbb185b` | `33bf1cbb185b` | yes |
| preactjs/preact | embedding-batches | 26 | `28d230bf6150` | `28d230bf6150` | yes |
| preactjs/preact | embedding-ledger | 1 | `c09221202828` | `c09221202828` | yes |
| preactjs/preact | decisions | 461 | `4b61034a01a2` | `4b61034a01a2` | yes |
| preactjs/preact | family-outcomes | 171 | `c8bb36933e9f` | `c8bb36933e9f` | yes |
| preactjs/preact | decision-ledger | 1 | `be64bcf03dd7` | `be64bcf03dd7` | yes |

- preactjs/preact: 487 of 487 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
<!-- families:acquisition:end -->

The recorded spaces are tracked in git (like `repository-world-v1`) so the
replay law can read them as Bazel inputs:
`.attune/families-embeddings-v1/6e2bef41…/` holds the 26 raw batch bodies with
their base64 vectors and the three embedding tables, and
`.attune/jev-families-raw-v1/6e2bef41…/` holds the 461 raw decision exchanges
and the three decision tables.

**Review point.** Milestone 1 ends here: the protocol, the measured cost, and
the storage plan for the larger worlds go to the user before any further world
is acquired.

## Clustering record

The clustering method (`atlas-families-v1`, constants and steps in
[PROTOCOL.md](PROTOCOL.md#clustering-method-atlas-families-v1)) ran on the
recorded preact evidence as the hermetic Bazel actions `cluster_preact` and
`cluster_preact_rerun`, keyless, over the frozen world tables and the two
recorded evidence filegroups only. The two runs' tables are byte-identical.
The block below is projected from the built tables by `:clustering_report`.
Regenerate with
`nix develop --command bazel build //experiments/atlas-families:clustering_report --config=buildbuddy-rbe-arm64`.

<!-- families:clustering:begin -->
**Families**

| repository | snapshot | seeds | candidates | families | members | largest | singletons | held by 2+ frontiers | seed fallback | named by decision |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| preactjs/preact | `6e2bef41bf19` | 171 | 161 | 159 | 1623 | 120 | 29 | 133 | 166 | 158 |

**Affinity sources** (per member, weighted; ablations count members whose family changes)

| repository | mean structural | mean semantic | moved without semantic | moved without structure |
|---|---:|---:|---:|---:|
| preactjs/preact | 0.371468 | 0.179825 | 0 | 18 |

**Rollup**

| repository | files | files split across families | directories | directories with one family |
|---|---:|---:|---:|---:|
| preactjs/preact | 171 | 1 | 41 | 7 |

**Largest families**

| repository | family | name | kind | members | files | seeds | name provenance |
|---|---:|---|---|---:|---:|---:|---|
| preactjs/preact | 119 | `test/browser/components.test.js` | file | 120 | 1 | 1 | decision `576d7e1eb3f3` |
| preactjs/preact | 125 | `test/_util` | directory | 91 | 2 | 2 | decision `e7ccbed3ba92` |
| preactjs/preact | 139 | `test/browser/lifecycles/shouldComponentUpdate.test.js` | file | 60 | 1 | 1 | decision `1dd41edcf624` |
| preactjs/preact | 29 | `compat/test/browser/suspense.test.js` | file | 55 | 1 | 1 | decision `316bf125d6bf` |
| preactjs/preact | 121 | `test/browser/createContext.test.js` | file | 49 | 1 | 1 | decision `4d19da2e900e` |
| preactjs/preact | 49 | `debug/test/browser/debug.test.js` | file | 46 | 1 | 1 | decision `65bf7a6eec68` |
| preactjs/preact | 138 | `test/browser/lifecycles/lifecycle.test.js` | file | 43 | 1 | 1 | decision `e615908ba784` |
| preactjs/preact | 128 | `test/browser/lifecycles/componentDidCatch.test.js` | file | 40 | 1 | 1 | decision `78c0629e86d5` |
<!-- families:clustering:end -->

Reading the record:

- **Candidates.** The 171 recorded walks reach 161 distinct frontiers, and 159
  of those keep at least one member once every symbol has chosen. Every symbol
  of the world is in exactly one family. 133 symbols sit in two or more
  recorded frontiers and are decided by affinity; 166 sit in none and join
  their own file's seed family.
- **Names.** 158 of the 159 families are named by a recorded `family_name`
  decision; the remaining one is named by its frontier's only candidate
  location. The largest families above show the decision each name comes from.
- **Sources.** Both sources contribute to every recorded affinity, but on
  preact the semantic source is not decisive under the v1 weights: removing it
  moves no symbol, while removing the structural source moves 18. The weights
  stay as versioned; whether the semantic source should carry more weight is a
  question for the larger worlds, not a retune on preact.
- **Rollup.** Of the 171 files that define callables, one is split across
  families; 7 of the 41 directories with callables hold a single family.
- **Performance.** The families law, which re-derives the whole clustering
  in-process from the recorded evidence and checks every law against both
  built runs, ran in 5.3 s on the BuildBuddy arm64 runner.

## Laws

| Target | Law |
| --- | --- |
| `:families_test` | The inventory is an exact function of the admitted world; the inventory table has a pinned schema, round-trips exactly, and rejects a foreign protocol, a mistyped column, or a row count other than one; the report projection is deterministic in declared order. The acquisition laws: documents follow the frozen recipe with no query side and are cut at the frozen limit; a span outside the source root is rejected; navigation offers only the frontier domain's atoms; every request is acquired once and then served from evidence; keyless replay refuses a miss and the envelope stops live calls; evidence is content-addressed, never replaced, and a retained exchange for a different request is rejected; every decision payload is issue-blind structure; every typed table round-trips exactly and rejects a foreign world; the ledger sums the provider-reported usage; the replay proof is exact only when every table matches keylessly. The clustering laws on a nested three-file world: affinity components are the exact per-pair means of both sources, the weights decide between the sources and a tie keeps the least candidate, recorded routes replay to their exact frontier, unheld symbols fall back to their seed candidate, the rollup is exact at file and directory level, family identity is derived from the exact members only, and the clustering tables round-trip exactly and reject foreign or malformed rows. |
| `:issue_blindness_test` | The tool's sources name no Localization module, issue field, or gold or population space; every retained decision request is a families state and every retained embedding request is a document batch, and none names an issue or gold field. |
| `replay_preact` | Keyless replay over the recorded preact spaces regenerates all six tables bit-identically with zero provider calls and no key in the environment (the build fails otherwise). |
| `:atlas_families_table_test` | Every built `atlas-families-v1` table (families, members, rollups) decodes under its declared schema and encodes back to the stored rows, rewrites and reads back to the same rows, and is refused under a foreign schema. |
| `:atlas_families_law_test` | Over the recorded preact evidence: the independent rerun is byte-identical and an in-process recomputation equals the recorded tables (determinism); every symbol is a member of exactly one family and every member is its exact admitted symbol (no invention); every member row joins exactly one frozen world entity row on snapshot, domain, id, path, name, and span, and every seed file is a world file row (provenance); every family identity is the content-derived identity of its members; every name is its seed's recorded name, admitted by the recorded naming decision or the only candidate location (naming); the rollup equals its recomputation from the member table and each location sums to its members with one dominant family (rollup); every protocol weight is positive, both sources contribute to the recorded affinities, and the semantic affinity varies (both sources). |
| `:charter_test` | `AGENTS.md` keeps the no-reacquisition paragraph and the Typed Parquet rule verbatim and carries the dated, scoped carve-out; this report carries the charter sections. |
| `:report_test` | Every generated block in this report and in `PROTOCOL.md` equals its regenerated Bazel projection. |

The tests are aggregated by `:families_tests`, which the root `//:tests`
suite includes; `:report_test` depends on `replay_preact` and on the
clustering report built from `cluster_preact`. Run them with
`nix develop --command bazel test //experiments/atlas-families/... --config=buildbuddy-rbe-arm64`.
