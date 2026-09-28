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
    family-formation objective (merge and naming decisions), through the
    in-tree inference client. Protocol `attune-jev-families-v1`, space
    `jev-families-raw-v1`.
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

## Laws

| Target | Law |
| --- | --- |
| `:families_test` | The inventory is an exact function of the admitted world; the inventory table has a pinned schema, round-trips exactly, and rejects a foreign protocol, a mistyped column, or a row count other than one; the report projection is deterministic in declared order. |
| `:charter_test` | `AGENTS.md` keeps the no-reacquisition paragraph and the Typed Parquet rule verbatim and carries the dated, scoped carve-out; this report carries the charter sections. |
| `:report_test` | Every generated block in this report equals its regenerated Bazel projection. |

All three are aggregated by `:families_tests`, which the root `//:tests`
suite includes. Run them with
`nix develop --command bazel test //experiments/atlas-families/... --config=buildbuddy-rbe-arm64`.
