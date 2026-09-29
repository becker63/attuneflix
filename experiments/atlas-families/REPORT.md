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

- **Envelope:** $5 per new acquisition pass, adjusted by the user at the
  milestone-1 review. Preact's immutable first-pass ledger records the original
  $50 cap and replays against that historical value.
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

### Atlas Live census population

The representative inventory above is the experiment's original comparison
set. The 2026-09-29 Atlas Live expansion applies the same issue-blind protocol
to the **78 frozen real snapshots across 11 repositories** listed in
`acquisition_population.json`; the generated synthetic stress fixture is not
scientific acquisition input. That manifest fixes each snapshot digest and
retained source-root identity before any live call. Its conservative projection
places 67 snapshots within the $5 whole-world pass cap and 11 above it (one
babel and ten protonmail snapshots). The latter use separately bounded
embedding and original-ordinal decision ranges, each at or below $5, then
materialize the same six whole-world typed tables keylessly. Pass ledgers live
beside the raw envelopes under `passes/` and are inputs to the BuildBuddy
evidence archive. The full population's replay, clustering, family-edge
aggregation, and web export use the Starlark targets declared from
`acquired_worlds.bzl`; no source evidence is added to git.

### Sealed cohort at the user stop (2026-09-29)

The user stopped further Families acquisition after **50 of the 78** frozen
snapshots had complete, sealed evidence. `acquired_worlds.bzl` is the exact
50-snapshot membership list; `evidence-cas-index.json` records their immutable
BuildBuddy CAS archive addresses. Atlas Live ships Families tables for this
cohort and explicitly identifies the other 28 snapshots as physical-only. The
independent depth-seven physical calculation covers all 78 snapshots.
Partially recorded provider exchanges for two Three.js snapshots were retained
but were not sealed, clustered, or included in the 50-snapshot cohort. No
further provider call is part of this release except a separately authorized
AttuneFlix self snapshot, if its existing acquisition route requires one.

## Acquisition record

The first pass ran on the smallest planned world, preactjs/preact, through
`acquire_preact` with the real OpenRouter API (protocol in
[PROTOCOL.md](PROTOCOL.md)). The pre-acquisition projection for that world was
0.277180 USD against the then-current 50 USD envelope, so the pass proceeded.
A second run over unchanged payloads resolved every request from retained
evidence and made zero provider calls. Subsequent worlds use the $5 per-pass
cap and the same keyless replay law. The block below is projected from recorded
ledgers and per-world replay proofs built by Bazel with no provider key or
transport. Regenerate with
`nix develop --command bazel build //experiments/atlas-families:acquisition_report --config=buildbuddy-rbe-arm64`.

<!-- families:acquisition:begin -->
**Recorded evidence**

| repository | snapshot | documents | batches | seeds | decisions | retained exchanges |
|---|---|---:|---:|---:|---:|---:|
| preactjs/preact | `6e2bef41bf19` | 1623 | 26 | 171 | 461 | 487 |
| NodeBB/NodeBB | `4b14c05228d2` | 1385 | 22 | 374 | 1035 | 1057 |
| NodeBB/NodeBB | `43d1969f5d5b` | 1400 | 22 | 378 | 1034 | 1056 |
| NodeBB/NodeBB | `d60aff465833` | 1488 | 24 | 391 | 1080 | 1104 |
| NodeBB/NodeBB | `b01273c831ec` | 1475 | 24 | 388 | 1070 | 1094 |
| NodeBB/NodeBB | `55d7a8cefbff` | 1408 | 22 | 378 | 1040 | 1062 |
| NodeBB/NodeBB | `8d83c9906172` | 1408 | 22 | 378 | 1039 | 1061 |
| NodeBB/NodeBB | `d13b9c7923b4` | 1367 | 22 | 370 | 1008 | 1030 |
| NodeBB/NodeBB | `0a4d2c8aacbb` | 1663 | 26 | 410 | 1142 | 1168 |
| NodeBB/NodeBB | `29e9da075af8` | 1451 | 23 | 379 | 1046 | 1069 |
| NodeBB/NodeBB | `47676c68fbcc` | 1437 | 23 | 378 | 1040 | 1063 |
| NodeBB/NodeBB | `945252fe6e86` | 1677 | 27 | 413 | 1142 | 1169 |
| NodeBB/NodeBB | `d81af495867c` | 1466 | 23 | 385 | 1061 | 1084 |
| NodeBB/NodeBB | `8037ac6f9244` | 1667 | 27 | 413 | 1146 | 1173 |
| NodeBB/NodeBB | `cb161a51dc34` | 1576 | 25 | 394 | 1085 | 1110 |
| NodeBB/NodeBB | `bb174a00f112` | 1393 | 22 | 374 | 1032 | 1054 |
| NodeBB/NodeBB | `72a6fb2a39b8` | 1614 | 26 | 400 | 1114 | 1140 |
| NodeBB/NodeBB | `962ea6c586b0` | 1396 | 22 | 374 | 1031 | 1053 |
| NodeBB/NodeBB | `f73daccf345e` | 1396 | 22 | 374 | 1026 | 1048 |
| NodeBB/NodeBB | `f4f3fb7417a2` | 1707 | 27 | 424 | 1176 | 1203 |
| NodeBB/NodeBB | `2d10a775f968` | 1679 | 27 | 413 | 1131 | 1158 |
| NodeBB/NodeBB | `ee4256c77f74` | 1668 | 27 | 413 | 1142 | 1169 |
| NodeBB/NodeBB | `c39f4787c4aa` | 1574 | 25 | 394 | 1093 | 1118 |
| axios/axios | `1e44a1c45ec4` | 295 | 5 | 46 | 126 | 131 |
| axios/axios | `af4495290bbc` | 707 | 12 | 56 | 155 | 167 |
| element-hq/element-web | `2ad7fd77595b` | 5714 | 90 | 741 | 2159 | 2249 |
| element-hq/element-web | `ea7c1240175d` | 5883 | 92 | 766 | 2235 | 2327 |
| facebook/docusaurus | `19fa623c87d7` | 5001 | 79 | 724 | 2169 | 2248 |
| facebook/docusaurus | `b9dd309ede37` | 5088 | 80 | 742 | 2200 | 2280 |
| facebook/docusaurus | `bc01d02e8d9b` | 4852 | 76 | 699 | 2082 | 2158 |
| immutable-js/immutable-js | `f0d3c13774ad` | 618 | 10 | 125 | 322 | 332 |
| immutable-js/immutable-js | `975db8fff535` | 618 | 10 | 124 | 317 | 327 |
| preactjs/preact | `7dcd08c6dcd8` | 1683 | 27 | 182 | 483 | 510 |
| preactjs/preact | `80b1792c5480` | 1733 | 28 | 187 | 490 | 518 |
| preactjs/preact | `4fdaac70f418` | 1761 | 28 | 190 | 503 | 531 |
| preactjs/preact | `1044506ddb44` | 1787 | 28 | 194 | 520 | 548 |
| preactjs/preact | `197d5a4deb6c` | 1817 | 29 | 195 | 524 | 553 |
| preactjs/preact | `69e49acea349` | 1852 | 29 | 197 | 525 | 554 |
| preactjs/preact | `8708b4d618d6` | 1868 | 30 | 197 | 521 | 551 |
| preactjs/preact | `000365e13105` | 2014 | 32 | 204 | 537 | 569 |
| preactjs/preact | `c1e88c310b4d` | 2065 | 33 | 205 | 537 | 570 |
| preactjs/preact | `409e2753ea0d` | 2122 | 34 | 210 | 556 | 590 |
| protonmail/webclients | `e79874736660` | 10629 | 167 | 3143 | 9866 | 10033 |
| tutao/tutanota | `38cc6652f983` | 9480 | 149 | 768 | 2252 | 2401 |
| tutao/tutanota | `6fa65b34fcfd` | 9884 | 155 | 792 | 2319 | 2474 |
| tutao/tutanota | `1b1bc8349e39` | 9730 | 153 | 783 | 2294 | 2447 |
| vuejs/core | `96c87d888005` | 4149 | 65 | 388 | 1063 | 1128 |
| vuejs/core | `9335add06b4a` | 4179 | 66 | 390 | 1066 | 1132 |
| vuejs/core | `3b5f437f41ce` | 4224 | 66 | 390 | 1069 | 1135 |
| vuejs/core | `678f8ed4bfb9` | 4224 | 66 | 390 | 1064 | 1130 |

**Cost ledger** (provider-reported usage and cost)

| repository | space | request | requests | cost reported | input tokens | output tokens | cost USD | unit USD | projected USD | envelope USD |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| preactjs/preact | `families-embeddings-v1` | embedding-batch | 26 | 26 | 101545 | 0 | 0.001015 | 0.000039 | 0.003580 | 50.000000 |
| preactjs/preact | `jev-families-raw-v1` | decision | 461 | 461 | 270037 | 20650 | 0.011342 | 0.000025 | 0.273600 | 50.000000 |
| NodeBB/NodeBB | `families-embeddings-v1` | embedding-batch | 22 | 22 | 223391 | 0 | 0.002473 | 0.000112 | 0.008309 | 5.000000 |
| NodeBB/NodeBB | `jev-families-raw-v1` | decision | 1035 | 1035 | 625051 | 49669 | 0.026252 | 0.000025 | 0.598400 | 5.000000 |
| NodeBB/NodeBB | `families-embeddings-v1` | embedding-batch | 22 | 22 | 225713 | 0 | 0.002610 | 0.000119 | 0.008399 | 5.000000 |
| NodeBB/NodeBB | `jev-families-raw-v1` | decision | 1034 | 1034 | 621308 | 49349 | 0.026095 | 0.000025 | 0.604800 | 5.000000 |
| NodeBB/NodeBB | `families-embeddings-v1` | embedding-batch | 24 | 24 | 240888 | 0 | 0.002409 | 0.000100 | 0.008997 | 5.000000 |
| NodeBB/NodeBB | `jev-families-raw-v1` | decision | 1080 | 1080 | 652130 | 51474 | 0.027389 | 0.000025 | 0.625600 | 5.000000 |
| NodeBB/NodeBB | `families-embeddings-v1` | embedding-batch | 24 | 24 | 237580 | 0 | 0.003008 | 0.000125 | 0.008868 | 5.000000 |
| NodeBB/NodeBB | `jev-families-raw-v1` | decision | 1070 | 1070 | 648041 | 51293 | 0.027218 | 0.000025 | 0.620800 | 5.000000 |
| NodeBB/NodeBB | `families-embeddings-v1` | embedding-batch | 22 | 22 | 226783 | 0 | 0.002268 | 0.000103 | 0.008441 | 5.000000 |
| NodeBB/NodeBB | `jev-families-raw-v1` | decision | 1040 | 1040 | 626256 | 49691 | 0.026303 | 0.000025 | 0.604800 | 5.000000 |
| NodeBB/NodeBB | `families-embeddings-v1` | embedding-batch | 22 | 22 | 226773 | 0 | 0.002554 | 0.000116 | 0.008440 | 5.000000 |
| NodeBB/NodeBB | `jev-families-raw-v1` | decision | 1039 | 1039 | 626471 | 49748 | 0.026312 | 0.000025 | 0.604800 | 5.000000 |
| NodeBB/NodeBB | `families-embeddings-v1` | embedding-batch | 22 | 22 | 220169 | 0 | 0.002202 | 0.000100 | 0.008187 | 5.000000 |
| NodeBB/NodeBB | `jev-families-raw-v1` | decision | 1008 | 1008 | 605345 | 48206 | 0.025424 | 0.000025 | 0.592000 | 5.000000 |
| NodeBB/NodeBB | `families-embeddings-v1` | embedding-batch | 26 | 26 | 273133 | 0 | 0.002849 | 0.000110 | 0.010204 | 5.000000 |
| NodeBB/NodeBB | `jev-families-raw-v1` | decision | 1142 | 1142 | 694265 | 54521 | 0.029159 | 0.000026 | 0.656000 | 5.000000 |
| NodeBB/NodeBB | `families-embeddings-v1` | embedding-batch | 23 | 23 | 232828 | 0 | 0.002770 | 0.000120 | 0.008697 | 5.000000 |
| NodeBB/NodeBB | `jev-families-raw-v1` | decision | 1046 | 1046 | 631555 | 49922 | 0.026525 | 0.000025 | 0.606400 | 5.000000 |
| NodeBB/NodeBB | `families-embeddings-v1` | embedding-batch | 23 | 23 | 231813 | 0 | 0.002318 | 0.000101 | 0.008663 | 5.000000 |
| NodeBB/NodeBB | `jev-families-raw-v1` | decision | 1040 | 1040 | 628700 | 49792 | 0.026405 | 0.000025 | 0.604800 | 5.000000 |
| NodeBB/NodeBB | `families-embeddings-v1` | embedding-batch | 27 | 27 | 276022 | 0 | 0.002760 | 0.000102 | 0.010310 | 5.000000 |
| NodeBB/NodeBB | `jev-families-raw-v1` | decision | 1142 | 1142 | 692656 | 54454 | 0.029092 | 0.000025 | 0.660800 | 5.000000 |
| NodeBB/NodeBB | `families-embeddings-v1` | embedding-batch | 23 | 23 | 235849 | 0 | 0.002358 | 0.000103 | 0.008804 | 5.000000 |
| NodeBB/NodeBB | `jev-families-raw-v1` | decision | 1061 | 1061 | 640757 | 50725 | 0.026912 | 0.000025 | 0.616000 | 5.000000 |
| NodeBB/NodeBB | `families-embeddings-v1` | embedding-batch | 27 | 27 | 274160 | 0 | 0.003633 | 0.000135 | 0.010242 | 5.000000 |
| NodeBB/NodeBB | `jev-families-raw-v1` | decision | 1146 | 1146 | 697685 | 54875 | 0.029303 | 0.000026 | 0.660800 | 5.000000 |
| NodeBB/NodeBB | `families-embeddings-v1` | embedding-batch | 25 | 25 | 254055 | 0 | 0.002541 | 0.000102 | 0.009508 | 5.000000 |
| NodeBB/NodeBB | `jev-families-raw-v1` | decision | 1085 | 1085 | 656721 | 51670 | 0.027582 | 0.000025 | 0.630400 | 5.000000 |
| NodeBB/NodeBB | `families-embeddings-v1` | embedding-batch | 22 | 22 | 224214 | 0 | 0.002476 | 0.000113 | 0.008340 | 5.000000 |
| NodeBB/NodeBB | `jev-families-raw-v1` | decision | 1032 | 1032 | 622439 | 49422 | 0.026142 | 0.000025 | 0.598400 | 5.000000 |
| NodeBB/NodeBB | `families-embeddings-v1` | embedding-batch | 26 | 26 | 261898 | 0 | 0.002619 | 0.000101 | 0.009797 | 5.000000 |
| NodeBB/NodeBB | `jev-families-raw-v1` | decision | 1114 | 1114 | 677230 | 53227 | 0.028444 | 0.000026 | 0.640000 | 5.000000 |
| NodeBB/NodeBB | `families-embeddings-v1` | embedding-batch | 22 | 22 | 224945 | 0 | 0.002249 | 0.000102 | 0.008369 | 5.000000 |
| NodeBB/NodeBB | `jev-families-raw-v1` | decision | 1031 | 1031 | 622565 | 49412 | 0.026148 | 0.000025 | 0.598400 | 5.000000 |
| NodeBB/NodeBB | `families-embeddings-v1` | embedding-batch | 22 | 22 | 224976 | 0 | 0.002797 | 0.000127 | 0.008371 | 5.000000 |
| NodeBB/NodeBB | `jev-families-raw-v1` | decision | 1026 | 1026 | 618014 | 49109 | 0.025957 | 0.000025 | 0.598400 | 5.000000 |
| NodeBB/NodeBB | `families-embeddings-v1` | embedding-batch | 27 | 27 | 281706 | 0 | 0.003151 | 0.000117 | 0.010523 | 5.000000 |
| NodeBB/NodeBB | `jev-families-raw-v1` | decision | 1176 | 1176 | 715241 | 56210 | 0.030040 | 0.000026 | 0.678400 | 5.000000 |
| NodeBB/NodeBB | `families-embeddings-v1` | embedding-batch | 27 | 27 | 276160 | 0 | 0.003095 | 0.000115 | 0.010315 | 5.000000 |
| NodeBB/NodeBB | `jev-families-raw-v1` | decision | 1131 | 1131 | 685786 | 54046 | 0.028803 | 0.000025 | 0.660800 | 5.000000 |
| NodeBB/NodeBB | `families-embeddings-v1` | embedding-batch | 27 | 27 | 274307 | 0 | 0.002743 | 0.000102 | 0.010248 | 5.000000 |
| NodeBB/NodeBB | `jev-families-raw-v1` | decision | 1142 | 1142 | 694028 | 54587 | 0.029149 | 0.000026 | 0.660800 | 5.000000 |
| NodeBB/NodeBB | `families-embeddings-v1` | embedding-batch | 25 | 25 | 253488 | 0 | 0.002820 | 0.000113 | 0.009489 | 5.000000 |
| NodeBB/NodeBB | `jev-families-raw-v1` | decision | 1093 | 1093 | 664273 | 52302 | 0.027899 | 0.000026 | 0.630400 | 5.000000 |
| axios/axios | `families-embeddings-v1` | embedding-batch | 5 | 5 | 32637 | 0 | 0.000326 | 0.000065 | 0.001337 | 5.000000 |
| axios/axios | `jev-families-raw-v1` | decision | 126 | 126 | 77079 | 6167 | 0.003237 | 0.000026 | 0.073600 | 5.000000 |
| axios/axios | `families-embeddings-v1` | embedding-batch | 12 | 12 | 81785 | 0 | 0.000818 | 0.000068 | 0.003236 | 5.000000 |
| axios/axios | `jev-families-raw-v1` | decision | 155 | 155 | 96624 | 7536 | 0.004058 | 0.000026 | 0.089600 | 5.000000 |
| element-hq/element-web | `families-embeddings-v1` | embedding-batch | 90 | 90 | 808987 | 0 | 0.009002 | 0.000100 | 0.038913 | 5.000000 |
| element-hq/element-web | `jev-families-raw-v1` | decision | 2159 | 2159 | 1569473 | 111216 | 0.065918 | 0.000031 | 1.185600 | 5.000000 |
| element-hq/element-web | `families-embeddings-v1` | embedding-batch | 92 | 92 | 832224 | 0 | 0.008498 | 0.000092 | 0.040057 | 5.000000 |
| element-hq/element-web | `jev-families-raw-v1` | decision | 2235 | 2235 | 1624872 | 115494 | 0.068245 | 0.000031 | 1.225600 | 5.000000 |
| facebook/docusaurus | `families-embeddings-v1` | embedding-batch | 79 | 79 | 813384 | 0 | 0.008670 | 0.000110 | 0.031604 | 5.000000 |
| facebook/docusaurus | `jev-families-raw-v1` | decision | 2169 | 2169 | 1519988 | 109105 | 0.063839 | 0.000029 | 1.158400 | 5.000000 |
| facebook/docusaurus | `families-embeddings-v1` | embedding-batch | 80 | 80 | 828423 | 0 | 0.008991 | 0.000112 | 0.032096 | 5.000000 |
| facebook/docusaurus | `jev-families-raw-v1` | decision | 2200 | 2200 | 1542286 | 110644 | 0.064776 | 0.000029 | 1.187200 | 5.000000 |
| facebook/docusaurus | `families-embeddings-v1` | embedding-batch | 76 | 76 | 802021 | 0 | 0.008676 | 0.000114 | 0.031151 | 5.000000 |
| facebook/docusaurus | `jev-families-raw-v1` | decision | 2082 | 2082 | 1448770 | 104439 | 0.060848 | 0.000029 | 1.118400 | 5.000000 |
| immutable-js/immutable-js | `families-embeddings-v1` | embedding-batch | 10 | 10 | 67848 | 0 | 0.001147 | 0.000115 | 0.002463 | 5.000000 |
| immutable-js/immutable-js | `jev-families-raw-v1` | decision | 322 | 322 | 189842 | 14932 | 0.007973 | 0.000025 | 0.200000 | 5.000000 |
| immutable-js/immutable-js | `families-embeddings-v1` | embedding-batch | 10 | 10 | 64216 | 0 | 0.000961 | 0.000096 | 0.002427 | 5.000000 |
| immutable-js/immutable-js | `jev-families-raw-v1` | decision | 317 | 317 | 186382 | 14606 | 0.007828 | 0.000025 | 0.198400 | 5.000000 |
| preactjs/preact | `families-embeddings-v1` | embedding-batch | 27 | 27 | 108203 | 0 | 0.001228 | 0.000045 | 0.003815 | 5.000000 |
| preactjs/preact | `jev-families-raw-v1` | decision | 483 | 483 | 282901 | 21759 | 0.011882 | 0.000025 | 0.291200 | 5.000000 |
| preactjs/preact | `families-embeddings-v1` | embedding-batch | 28 | 28 | 114867 | 0 | 0.001149 | 0.000041 | 0.004050 | 5.000000 |
| preactjs/preact | `jev-families-raw-v1` | decision | 490 | 490 | 286770 | 22152 | 0.012044 | 0.000025 | 0.299200 | 5.000000 |
| preactjs/preact | `families-embeddings-v1` | embedding-batch | 28 | 28 | 118563 | 0 | 0.001234 | 0.000044 | 0.004182 | 5.000000 |
| preactjs/preact | `jev-families-raw-v1` | decision | 503 | 503 | 293619 | 22651 | 0.012332 | 0.000025 | 0.304000 | 5.000000 |
| preactjs/preact | `families-embeddings-v1` | embedding-batch | 28 | 28 | 119750 | 0 | 0.001198 | 0.000043 | 0.004225 | 5.000000 |
| preactjs/preact | `jev-families-raw-v1` | decision | 520 | 520 | 305476 | 23508 | 0.012830 | 0.000025 | 0.310400 | 5.000000 |
| preactjs/preact | `families-embeddings-v1` | embedding-batch | 29 | 29 | 122092 | 0 | 0.001301 | 0.000045 | 0.004308 | 5.000000 |
| preactjs/preact | `jev-families-raw-v1` | decision | 524 | 524 | 306351 | 23567 | 0.012867 | 0.000025 | 0.312000 | 5.000000 |
| preactjs/preact | `families-embeddings-v1` | embedding-batch | 29 | 29 | 124100 | 0 | 0.001241 | 0.000043 | 0.004375 | 5.000000 |
| preactjs/preact | `jev-families-raw-v1` | decision | 525 | 525 | 307464 | 23631 | 0.012913 | 0.000025 | 0.315200 | 5.000000 |
| preactjs/preact | `families-embeddings-v1` | embedding-batch | 30 | 30 | 124867 | 0 | 0.001249 | 0.000042 | 0.004402 | 5.000000 |
| preactjs/preact | `jev-families-raw-v1` | decision | 521 | 521 | 305412 | 23545 | 0.012827 | 0.000025 | 0.315200 | 5.000000 |
| preactjs/preact | `families-embeddings-v1` | embedding-batch | 32 | 32 | 136450 | 0 | 0.001420 | 0.000044 | 0.004810 | 5.000000 |
| preactjs/preact | `jev-families-raw-v1` | decision | 537 | 537 | 314380 | 24248 | 0.013204 | 0.000025 | 0.326400 | 5.000000 |
| preactjs/preact | `families-embeddings-v1` | embedding-batch | 33 | 33 | 139663 | 0 | 0.001397 | 0.000042 | 0.004928 | 5.000000 |
| preactjs/preact | `jev-families-raw-v1` | decision | 537 | 537 | 315314 | 24337 | 0.013243 | 0.000025 | 0.328000 | 5.000000 |
| preactjs/preact | `families-embeddings-v1` | embedding-batch | 34 | 34 | 144673 | 0 | 0.001447 | 0.000043 | 0.005104 | 5.000000 |
| preactjs/preact | `jev-families-raw-v1` | decision | 556 | 556 | 327663 | 25098 | 0.013762 | 0.000025 | 0.336000 | 5.000000 |
| protonmail/webclients | `families-embeddings-v1` | embedding-batch | 167 | 167 | 2079669 | 0 | 0.021207 | 0.000127 | 0.101107 | 5.000000 |
| protonmail/webclients | `jev-families-raw-v1` | decision | 9866 | 9866 | 7433615 | 532358 | 0.312212 | 0.000032 | 5.028800 | 5.000000 |
| tutao/tutanota | `families-embeddings-v1` | embedding-batch | 149 | 149 | 1179261 | 0 | 0.014143 | 0.000095 | 0.045209 | 5.000000 |
| tutao/tutanota | `jev-families-raw-v1` | decision | 2252 | 2252 | 1635622 | 109927 | 0.068696 | 0.000031 | 1.228800 | 5.000000 |
| tutao/tutanota | `families-embeddings-v1` | embedding-batch | 155 | 155 | 1215674 | 0 | 0.013764 | 0.000089 | 0.046433 | 5.000000 |
| tutao/tutanota | `jev-families-raw-v1` | decision | 2319 | 2319 | 1681732 | 112741 | 0.070633 | 0.000030 | 1.267200 | 5.000000 |
| tutao/tutanota | `families-embeddings-v1` | embedding-batch | 153 | 153 | 1212845 | 0 | 0.013742 | 0.000090 | 0.046296 | 5.000000 |
| tutao/tutanota | `jev-families-raw-v1` | decision | 2294 | 2294 | 1666799 | 111770 | 0.070006 | 0.000031 | 1.252800 | 5.000000 |
| vuejs/core | `families-embeddings-v1` | embedding-batch | 65 | 65 | 470249 | 0 | 0.004889 | 0.000075 | 0.019473 | 5.000000 |
| vuejs/core | `jev-families-raw-v1` | decision | 1063 | 1063 | 739918 | 54521 | 0.031077 | 0.000029 | 0.620800 | 5.000000 |
| vuejs/core | `families-embeddings-v1` | embedding-batch | 66 | 66 | 472404 | 0 | 0.004724 | 0.000072 | 0.019561 | 5.000000 |
| vuejs/core | `jev-families-raw-v1` | decision | 1066 | 1066 | 739773 | 54633 | 0.031070 | 0.000029 | 0.624000 | 5.000000 |
| vuejs/core | `families-embeddings-v1` | embedding-batch | 66 | 66 | 475393 | 0 | 0.005133 | 0.000078 | 0.019687 | 5.000000 |
| vuejs/core | `jev-families-raw-v1` | decision | 1069 | 1069 | 743307 | 54843 | 0.031219 | 0.000029 | 0.624000 | 5.000000 |
| vuejs/core | `families-embeddings-v1` | embedding-batch | 66 | 66 | 475497 | 0 | 0.005299 | 0.000080 | 0.019692 | 5.000000 |
| vuejs/core | `jev-families-raw-v1` | decision | 1064 | 1064 | 737188 | 54554 | 0.030962 | 0.000029 | 0.624000 | 5.000000 |
| **total** | | | 64323 | | | | 1.936970 | | 35.620442 | |

Current pass cap: 5.000000 USD. Measured total: 1.936970 USD.

**Keyless replay proof**

| repository | table | rows | recorded identity | replayed identity | equal |
|---|---|---:|---|---|---|
| preactjs/preact | embedding-documents | 1623 | `33bf1cbb185b` | `33bf1cbb185b` | yes |
| preactjs/preact | embedding-batches | 26 | `28d230bf6150` | `28d230bf6150` | yes |
| preactjs/preact | embedding-ledger | 1 | `c09221202828` | `c09221202828` | yes |
| preactjs/preact | decisions | 461 | `4b61034a01a2` | `4b61034a01a2` | yes |
| preactjs/preact | family-outcomes | 171 | `c8bb36933e9f` | `c8bb36933e9f` | yes |
| preactjs/preact | decision-ledger | 1 | `be64bcf03dd7` | `be64bcf03dd7` | yes |
| NodeBB/NodeBB | embedding-documents | 1385 | `557914a2e287` | `557914a2e287` | yes |
| NodeBB/NodeBB | embedding-batches | 22 | `ad1838a393f8` | `ad1838a393f8` | yes |
| NodeBB/NodeBB | embedding-ledger | 1 | `441f43eace71` | `441f43eace71` | yes |
| NodeBB/NodeBB | decisions | 1035 | `d05787fc0a7b` | `d05787fc0a7b` | yes |
| NodeBB/NodeBB | family-outcomes | 374 | `4e19f4458a92` | `4e19f4458a92` | yes |
| NodeBB/NodeBB | decision-ledger | 1 | `c5e327b85781` | `c5e327b85781` | yes |
| NodeBB/NodeBB | embedding-documents | 1400 | `406c0649b362` | `406c0649b362` | yes |
| NodeBB/NodeBB | embedding-batches | 22 | `05bc2f7c4b61` | `05bc2f7c4b61` | yes |
| NodeBB/NodeBB | embedding-ledger | 1 | `4a1150008b5a` | `4a1150008b5a` | yes |
| NodeBB/NodeBB | decisions | 1034 | `4c55729690b7` | `4c55729690b7` | yes |
| NodeBB/NodeBB | family-outcomes | 378 | `d94ecd1c90d9` | `d94ecd1c90d9` | yes |
| NodeBB/NodeBB | decision-ledger | 1 | `90c42fd82065` | `90c42fd82065` | yes |
| NodeBB/NodeBB | embedding-documents | 1488 | `ef0c89322bbe` | `ef0c89322bbe` | yes |
| NodeBB/NodeBB | embedding-batches | 24 | `71514ccdd8ad` | `71514ccdd8ad` | yes |
| NodeBB/NodeBB | embedding-ledger | 1 | `7d7acd0c4558` | `7d7acd0c4558` | yes |
| NodeBB/NodeBB | decisions | 1080 | `9e6c278ae7e0` | `9e6c278ae7e0` | yes |
| NodeBB/NodeBB | family-outcomes | 391 | `5485de707c6f` | `5485de707c6f` | yes |
| NodeBB/NodeBB | decision-ledger | 1 | `2d0a8d90fc85` | `2d0a8d90fc85` | yes |
| NodeBB/NodeBB | embedding-documents | 1475 | `22116722f9ea` | `22116722f9ea` | yes |
| NodeBB/NodeBB | embedding-batches | 24 | `b39c981fdcba` | `b39c981fdcba` | yes |
| NodeBB/NodeBB | embedding-ledger | 1 | `3bbd9a8b8cb5` | `3bbd9a8b8cb5` | yes |
| NodeBB/NodeBB | decisions | 1070 | `e05fc0a052cd` | `e05fc0a052cd` | yes |
| NodeBB/NodeBB | family-outcomes | 388 | `bdaf1cd1183d` | `bdaf1cd1183d` | yes |
| NodeBB/NodeBB | decision-ledger | 1 | `7ccaa9902140` | `7ccaa9902140` | yes |
| NodeBB/NodeBB | embedding-documents | 1408 | `bf4af93de460` | `bf4af93de460` | yes |
| NodeBB/NodeBB | embedding-batches | 22 | `18bd44d6aeac` | `18bd44d6aeac` | yes |
| NodeBB/NodeBB | embedding-ledger | 1 | `1d6cc236a4ac` | `1d6cc236a4ac` | yes |
| NodeBB/NodeBB | decisions | 1040 | `125d7ec9f26a` | `125d7ec9f26a` | yes |
| NodeBB/NodeBB | family-outcomes | 378 | `72d8f68d6445` | `72d8f68d6445` | yes |
| NodeBB/NodeBB | decision-ledger | 1 | `cf486b9550bb` | `cf486b9550bb` | yes |
| NodeBB/NodeBB | embedding-documents | 1408 | `6f635bbff43d` | `6f635bbff43d` | yes |
| NodeBB/NodeBB | embedding-batches | 22 | `2dba439ad272` | `2dba439ad272` | yes |
| NodeBB/NodeBB | embedding-ledger | 1 | `fe2b011be99c` | `fe2b011be99c` | yes |
| NodeBB/NodeBB | decisions | 1039 | `33d02e2b5195` | `33d02e2b5195` | yes |
| NodeBB/NodeBB | family-outcomes | 378 | `b27541f01901` | `b27541f01901` | yes |
| NodeBB/NodeBB | decision-ledger | 1 | `e5633b10f5f3` | `e5633b10f5f3` | yes |
| NodeBB/NodeBB | embedding-documents | 1367 | `172f6f09290a` | `172f6f09290a` | yes |
| NodeBB/NodeBB | embedding-batches | 22 | `6e6f7dab61df` | `6e6f7dab61df` | yes |
| NodeBB/NodeBB | embedding-ledger | 1 | `f442cfb9df1b` | `f442cfb9df1b` | yes |
| NodeBB/NodeBB | decisions | 1008 | `72d9e9b11d3f` | `72d9e9b11d3f` | yes |
| NodeBB/NodeBB | family-outcomes | 370 | `736529049aca` | `736529049aca` | yes |
| NodeBB/NodeBB | decision-ledger | 1 | `73a9ae0fa1cf` | `73a9ae0fa1cf` | yes |
| NodeBB/NodeBB | embedding-documents | 1663 | `2973bf751464` | `2973bf751464` | yes |
| NodeBB/NodeBB | embedding-batches | 26 | `beb5e7d386f5` | `beb5e7d386f5` | yes |
| NodeBB/NodeBB | embedding-ledger | 1 | `e449de06e091` | `e449de06e091` | yes |
| NodeBB/NodeBB | decisions | 1142 | `f3b101b28ce9` | `f3b101b28ce9` | yes |
| NodeBB/NodeBB | family-outcomes | 410 | `70da2e632bbf` | `70da2e632bbf` | yes |
| NodeBB/NodeBB | decision-ledger | 1 | `1ff2ef49e092` | `1ff2ef49e092` | yes |
| NodeBB/NodeBB | embedding-documents | 1451 | `d54e16e6eee3` | `d54e16e6eee3` | yes |
| NodeBB/NodeBB | embedding-batches | 23 | `3bf907adad3c` | `3bf907adad3c` | yes |
| NodeBB/NodeBB | embedding-ledger | 1 | `abf4b134d8b5` | `abf4b134d8b5` | yes |
| NodeBB/NodeBB | decisions | 1046 | `9b6e82f0b546` | `9b6e82f0b546` | yes |
| NodeBB/NodeBB | family-outcomes | 379 | `d88ce32e7d2f` | `d88ce32e7d2f` | yes |
| NodeBB/NodeBB | decision-ledger | 1 | `2cdad4479c57` | `2cdad4479c57` | yes |
| NodeBB/NodeBB | embedding-documents | 1437 | `f62294307c8a` | `f62294307c8a` | yes |
| NodeBB/NodeBB | embedding-batches | 23 | `d8b4332f06c4` | `d8b4332f06c4` | yes |
| NodeBB/NodeBB | embedding-ledger | 1 | `dae06f4b073a` | `dae06f4b073a` | yes |
| NodeBB/NodeBB | decisions | 1040 | `1118c6e65dcd` | `1118c6e65dcd` | yes |
| NodeBB/NodeBB | family-outcomes | 378 | `b58c3e9b2cd2` | `b58c3e9b2cd2` | yes |
| NodeBB/NodeBB | decision-ledger | 1 | `68de2b470507` | `68de2b470507` | yes |
| NodeBB/NodeBB | embedding-documents | 1677 | `149b17b2bef8` | `149b17b2bef8` | yes |
| NodeBB/NodeBB | embedding-batches | 27 | `5a267bf17c82` | `5a267bf17c82` | yes |
| NodeBB/NodeBB | embedding-ledger | 1 | `4d30d691c083` | `4d30d691c083` | yes |
| NodeBB/NodeBB | decisions | 1142 | `a9952f6f7689` | `a9952f6f7689` | yes |
| NodeBB/NodeBB | family-outcomes | 413 | `11ff6cbe5866` | `11ff6cbe5866` | yes |
| NodeBB/NodeBB | decision-ledger | 1 | `d4628c3eaf31` | `d4628c3eaf31` | yes |
| NodeBB/NodeBB | embedding-documents | 1466 | `a9abaa99b90d` | `a9abaa99b90d` | yes |
| NodeBB/NodeBB | embedding-batches | 23 | `5cd35e0005a5` | `5cd35e0005a5` | yes |
| NodeBB/NodeBB | embedding-ledger | 1 | `d22d5fe1973f` | `d22d5fe1973f` | yes |
| NodeBB/NodeBB | decisions | 1061 | `acdca72efb3d` | `acdca72efb3d` | yes |
| NodeBB/NodeBB | family-outcomes | 385 | `f821f2e2eaa3` | `f821f2e2eaa3` | yes |
| NodeBB/NodeBB | decision-ledger | 1 | `bf51464194cb` | `bf51464194cb` | yes |
| NodeBB/NodeBB | embedding-documents | 1667 | `100dfed16d06` | `100dfed16d06` | yes |
| NodeBB/NodeBB | embedding-batches | 27 | `ebd38164b291` | `ebd38164b291` | yes |
| NodeBB/NodeBB | embedding-ledger | 1 | `e0dbdc56c44c` | `e0dbdc56c44c` | yes |
| NodeBB/NodeBB | decisions | 1146 | `d502603d4d8e` | `d502603d4d8e` | yes |
| NodeBB/NodeBB | family-outcomes | 413 | `fd46b1f1342f` | `fd46b1f1342f` | yes |
| NodeBB/NodeBB | decision-ledger | 1 | `5c46fb05d11c` | `5c46fb05d11c` | yes |
| NodeBB/NodeBB | embedding-documents | 1576 | `40f1f441745a` | `40f1f441745a` | yes |
| NodeBB/NodeBB | embedding-batches | 25 | `fada119fd2fd` | `fada119fd2fd` | yes |
| NodeBB/NodeBB | embedding-ledger | 1 | `2861fa02e76f` | `2861fa02e76f` | yes |
| NodeBB/NodeBB | decisions | 1085 | `02eedc1409ce` | `02eedc1409ce` | yes |
| NodeBB/NodeBB | family-outcomes | 394 | `ca21a8200455` | `ca21a8200455` | yes |
| NodeBB/NodeBB | decision-ledger | 1 | `1bc5f484cfb4` | `1bc5f484cfb4` | yes |
| NodeBB/NodeBB | embedding-documents | 1393 | `8e06c166088f` | `8e06c166088f` | yes |
| NodeBB/NodeBB | embedding-batches | 22 | `88e66674b203` | `88e66674b203` | yes |
| NodeBB/NodeBB | embedding-ledger | 1 | `2e50d3d9e81b` | `2e50d3d9e81b` | yes |
| NodeBB/NodeBB | decisions | 1032 | `448a9c13f59e` | `448a9c13f59e` | yes |
| NodeBB/NodeBB | family-outcomes | 374 | `d9cdd7c0d547` | `d9cdd7c0d547` | yes |
| NodeBB/NodeBB | decision-ledger | 1 | `f6619003d21b` | `f6619003d21b` | yes |
| NodeBB/NodeBB | embedding-documents | 1614 | `03a2af815200` | `03a2af815200` | yes |
| NodeBB/NodeBB | embedding-batches | 26 | `e64712c4a1ed` | `e64712c4a1ed` | yes |
| NodeBB/NodeBB | embedding-ledger | 1 | `777790e25dc1` | `777790e25dc1` | yes |
| NodeBB/NodeBB | decisions | 1114 | `e7580a510eb2` | `e7580a510eb2` | yes |
| NodeBB/NodeBB | family-outcomes | 400 | `80a725874e89` | `80a725874e89` | yes |
| NodeBB/NodeBB | decision-ledger | 1 | `636e7f9ef34b` | `636e7f9ef34b` | yes |
| NodeBB/NodeBB | embedding-documents | 1396 | `8bbf6319d21f` | `8bbf6319d21f` | yes |
| NodeBB/NodeBB | embedding-batches | 22 | `a7ffac4c477b` | `a7ffac4c477b` | yes |
| NodeBB/NodeBB | embedding-ledger | 1 | `1bdee15f3fd8` | `1bdee15f3fd8` | yes |
| NodeBB/NodeBB | decisions | 1031 | `89623a0332ee` | `89623a0332ee` | yes |
| NodeBB/NodeBB | family-outcomes | 374 | `fef07b71a698` | `fef07b71a698` | yes |
| NodeBB/NodeBB | decision-ledger | 1 | `a566f26aa962` | `a566f26aa962` | yes |
| NodeBB/NodeBB | embedding-documents | 1396 | `b0d03b1c9ffb` | `b0d03b1c9ffb` | yes |
| NodeBB/NodeBB | embedding-batches | 22 | `7949e88a5d75` | `7949e88a5d75` | yes |
| NodeBB/NodeBB | embedding-ledger | 1 | `1c0c20024fd9` | `1c0c20024fd9` | yes |
| NodeBB/NodeBB | decisions | 1026 | `6a5c5d1a20a7` | `6a5c5d1a20a7` | yes |
| NodeBB/NodeBB | family-outcomes | 374 | `b73397603f88` | `b73397603f88` | yes |
| NodeBB/NodeBB | decision-ledger | 1 | `44d8fb5225f2` | `44d8fb5225f2` | yes |
| NodeBB/NodeBB | embedding-documents | 1707 | `989cef739191` | `989cef739191` | yes |
| NodeBB/NodeBB | embedding-batches | 27 | `beac1a1f45bf` | `beac1a1f45bf` | yes |
| NodeBB/NodeBB | embedding-ledger | 1 | `21a3e5c6cf43` | `21a3e5c6cf43` | yes |
| NodeBB/NodeBB | decisions | 1176 | `ef8d8b307d63` | `ef8d8b307d63` | yes |
| NodeBB/NodeBB | family-outcomes | 424 | `6239b6c937dd` | `6239b6c937dd` | yes |
| NodeBB/NodeBB | decision-ledger | 1 | `113c0162ca19` | `113c0162ca19` | yes |
| NodeBB/NodeBB | embedding-documents | 1679 | `f7ffeb9fa77c` | `f7ffeb9fa77c` | yes |
| NodeBB/NodeBB | embedding-batches | 27 | `f0184231f172` | `f0184231f172` | yes |
| NodeBB/NodeBB | embedding-ledger | 1 | `b3fa6ac9cc5e` | `b3fa6ac9cc5e` | yes |
| NodeBB/NodeBB | decisions | 1131 | `3f264d77d4fb` | `3f264d77d4fb` | yes |
| NodeBB/NodeBB | family-outcomes | 413 | `320ac09a7fc1` | `320ac09a7fc1` | yes |
| NodeBB/NodeBB | decision-ledger | 1 | `34dbf46ee6f4` | `34dbf46ee6f4` | yes |
| NodeBB/NodeBB | embedding-documents | 1668 | `7c8156f970c0` | `7c8156f970c0` | yes |
| NodeBB/NodeBB | embedding-batches | 27 | `af0c20a000a1` | `af0c20a000a1` | yes |
| NodeBB/NodeBB | embedding-ledger | 1 | `6df9642962a0` | `6df9642962a0` | yes |
| NodeBB/NodeBB | decisions | 1142 | `e2e4de93c051` | `e2e4de93c051` | yes |
| NodeBB/NodeBB | family-outcomes | 413 | `f992ec4a2a91` | `f992ec4a2a91` | yes |
| NodeBB/NodeBB | decision-ledger | 1 | `1f8b928278f3` | `1f8b928278f3` | yes |
| NodeBB/NodeBB | embedding-documents | 1574 | `c40c6c492d2b` | `c40c6c492d2b` | yes |
| NodeBB/NodeBB | embedding-batches | 25 | `a5720405d1cd` | `a5720405d1cd` | yes |
| NodeBB/NodeBB | embedding-ledger | 1 | `f072421199ec` | `f072421199ec` | yes |
| NodeBB/NodeBB | decisions | 1093 | `dfc3529273e9` | `dfc3529273e9` | yes |
| NodeBB/NodeBB | family-outcomes | 394 | `946f61cba055` | `946f61cba055` | yes |
| NodeBB/NodeBB | decision-ledger | 1 | `981f3aeb177d` | `981f3aeb177d` | yes |
| axios/axios | embedding-documents | 295 | `348a8b9d975b` | `348a8b9d975b` | yes |
| axios/axios | embedding-batches | 5 | `8d14639dd3bf` | `8d14639dd3bf` | yes |
| axios/axios | embedding-ledger | 1 | `3e02339ed744` | `3e02339ed744` | yes |
| axios/axios | decisions | 126 | `5a23df8aa33f` | `5a23df8aa33f` | yes |
| axios/axios | family-outcomes | 46 | `b3d75b4b6132` | `b3d75b4b6132` | yes |
| axios/axios | decision-ledger | 1 | `f4db85fa5298` | `f4db85fa5298` | yes |
| axios/axios | embedding-documents | 707 | `fd0b216aa2cf` | `fd0b216aa2cf` | yes |
| axios/axios | embedding-batches | 12 | `cc3c2d1ef184` | `cc3c2d1ef184` | yes |
| axios/axios | embedding-ledger | 1 | `c1fdcf988560` | `c1fdcf988560` | yes |
| axios/axios | decisions | 155 | `ab345c29af96` | `ab345c29af96` | yes |
| axios/axios | family-outcomes | 56 | `68e68b835fc6` | `68e68b835fc6` | yes |
| axios/axios | decision-ledger | 1 | `0e18b40ab681` | `0e18b40ab681` | yes |
| element-hq/element-web | embedding-documents | 5714 | `dc7e40d6acff` | `dc7e40d6acff` | yes |
| element-hq/element-web | embedding-batches | 90 | `26e0d894ab94` | `26e0d894ab94` | yes |
| element-hq/element-web | embedding-ledger | 1 | `5b67a0b5dc70` | `5b67a0b5dc70` | yes |
| element-hq/element-web | decisions | 2159 | `857eab96882f` | `857eab96882f` | yes |
| element-hq/element-web | family-outcomes | 741 | `378874162f50` | `378874162f50` | yes |
| element-hq/element-web | decision-ledger | 1 | `5fe78310011c` | `5fe78310011c` | yes |
| element-hq/element-web | embedding-documents | 5883 | `9b915d627202` | `9b915d627202` | yes |
| element-hq/element-web | embedding-batches | 92 | `1223a5f98257` | `1223a5f98257` | yes |
| element-hq/element-web | embedding-ledger | 1 | `8dac23661cbc` | `8dac23661cbc` | yes |
| element-hq/element-web | decisions | 2235 | `fc432acdcf05` | `fc432acdcf05` | yes |
| element-hq/element-web | family-outcomes | 766 | `36b2d3b7f48e` | `36b2d3b7f48e` | yes |
| element-hq/element-web | decision-ledger | 1 | `ab86c537fdac` | `ab86c537fdac` | yes |
| facebook/docusaurus | embedding-documents | 5001 | `5c85f0513840` | `5c85f0513840` | yes |
| facebook/docusaurus | embedding-batches | 79 | `233f31debe0b` | `233f31debe0b` | yes |
| facebook/docusaurus | embedding-ledger | 1 | `a521de801364` | `a521de801364` | yes |
| facebook/docusaurus | decisions | 2169 | `398470383b1e` | `398470383b1e` | yes |
| facebook/docusaurus | family-outcomes | 724 | `dd9c3e040eaf` | `dd9c3e040eaf` | yes |
| facebook/docusaurus | decision-ledger | 1 | `70a9605124b9` | `70a9605124b9` | yes |
| facebook/docusaurus | embedding-documents | 5088 | `71fbffb461ba` | `71fbffb461ba` | yes |
| facebook/docusaurus | embedding-batches | 80 | `99e5a234ba2e` | `99e5a234ba2e` | yes |
| facebook/docusaurus | embedding-ledger | 1 | `d1a15745fce3` | `d1a15745fce3` | yes |
| facebook/docusaurus | decisions | 2200 | `16ec770df1ea` | `16ec770df1ea` | yes |
| facebook/docusaurus | family-outcomes | 742 | `e2c7c12eed8a` | `e2c7c12eed8a` | yes |
| facebook/docusaurus | decision-ledger | 1 | `6cd3ae1a8439` | `6cd3ae1a8439` | yes |
| facebook/docusaurus | embedding-documents | 4852 | `7ef041bc274e` | `7ef041bc274e` | yes |
| facebook/docusaurus | embedding-batches | 76 | `6904b4927e43` | `6904b4927e43` | yes |
| facebook/docusaurus | embedding-ledger | 1 | `ec4c24444740` | `ec4c24444740` | yes |
| facebook/docusaurus | decisions | 2082 | `aa14d8a4c76e` | `aa14d8a4c76e` | yes |
| facebook/docusaurus | family-outcomes | 699 | `82a18edb1b57` | `82a18edb1b57` | yes |
| facebook/docusaurus | decision-ledger | 1 | `2b4f751d9148` | `2b4f751d9148` | yes |
| immutable-js/immutable-js | embedding-documents | 618 | `543374df799a` | `543374df799a` | yes |
| immutable-js/immutable-js | embedding-batches | 10 | `efa2c3f5f14c` | `efa2c3f5f14c` | yes |
| immutable-js/immutable-js | embedding-ledger | 1 | `dcb4987b74ae` | `dcb4987b74ae` | yes |
| immutable-js/immutable-js | decisions | 322 | `5a6821276a9d` | `5a6821276a9d` | yes |
| immutable-js/immutable-js | family-outcomes | 125 | `7e3cdbbaa856` | `7e3cdbbaa856` | yes |
| immutable-js/immutable-js | decision-ledger | 1 | `5959d5df8227` | `5959d5df8227` | yes |
| immutable-js/immutable-js | embedding-documents | 618 | `bec88da4cfd2` | `bec88da4cfd2` | yes |
| immutable-js/immutable-js | embedding-batches | 10 | `41cfe1b2220f` | `41cfe1b2220f` | yes |
| immutable-js/immutable-js | embedding-ledger | 1 | `683bf024a10d` | `683bf024a10d` | yes |
| immutable-js/immutable-js | decisions | 317 | `948dc7b8518d` | `948dc7b8518d` | yes |
| immutable-js/immutable-js | family-outcomes | 124 | `ccec92a4c325` | `ccec92a4c325` | yes |
| immutable-js/immutable-js | decision-ledger | 1 | `69b81d9c3413` | `69b81d9c3413` | yes |
| preactjs/preact | embedding-documents | 1683 | `83746ebbaa0d` | `83746ebbaa0d` | yes |
| preactjs/preact | embedding-batches | 27 | `779a929b5838` | `779a929b5838` | yes |
| preactjs/preact | embedding-ledger | 1 | `a10726c1bea0` | `a10726c1bea0` | yes |
| preactjs/preact | decisions | 483 | `85475ee7f870` | `85475ee7f870` | yes |
| preactjs/preact | family-outcomes | 182 | `bec3f73037dc` | `bec3f73037dc` | yes |
| preactjs/preact | decision-ledger | 1 | `af121a90a5c3` | `af121a90a5c3` | yes |
| preactjs/preact | embedding-documents | 1733 | `598e312ccae0` | `598e312ccae0` | yes |
| preactjs/preact | embedding-batches | 28 | `3a9868b73115` | `3a9868b73115` | yes |
| preactjs/preact | embedding-ledger | 1 | `4d3536ed904f` | `4d3536ed904f` | yes |
| preactjs/preact | decisions | 490 | `53e4344e9a73` | `53e4344e9a73` | yes |
| preactjs/preact | family-outcomes | 187 | `bb400c27a265` | `bb400c27a265` | yes |
| preactjs/preact | decision-ledger | 1 | `aa769c6d3ffc` | `aa769c6d3ffc` | yes |
| preactjs/preact | embedding-documents | 1761 | `3f29e6a272b5` | `3f29e6a272b5` | yes |
| preactjs/preact | embedding-batches | 28 | `21dd742f5397` | `21dd742f5397` | yes |
| preactjs/preact | embedding-ledger | 1 | `08cfec9e2b10` | `08cfec9e2b10` | yes |
| preactjs/preact | decisions | 503 | `d093bad1f491` | `d093bad1f491` | yes |
| preactjs/preact | family-outcomes | 190 | `8021164c94f5` | `8021164c94f5` | yes |
| preactjs/preact | decision-ledger | 1 | `8d20f9c06485` | `8d20f9c06485` | yes |
| preactjs/preact | embedding-documents | 1787 | `a7d2a77fba5c` | `a7d2a77fba5c` | yes |
| preactjs/preact | embedding-batches | 28 | `58a8198bc8d3` | `58a8198bc8d3` | yes |
| preactjs/preact | embedding-ledger | 1 | `75616d6af023` | `75616d6af023` | yes |
| preactjs/preact | decisions | 520 | `3711e41c5da0` | `3711e41c5da0` | yes |
| preactjs/preact | family-outcomes | 194 | `9d966a3f594f` | `9d966a3f594f` | yes |
| preactjs/preact | decision-ledger | 1 | `305ef105f1c7` | `305ef105f1c7` | yes |
| preactjs/preact | embedding-documents | 1817 | `adf2cee3c0e0` | `adf2cee3c0e0` | yes |
| preactjs/preact | embedding-batches | 29 | `d94177667771` | `d94177667771` | yes |
| preactjs/preact | embedding-ledger | 1 | `3de4b0cc6dca` | `3de4b0cc6dca` | yes |
| preactjs/preact | decisions | 524 | `ba2a1d1cce0f` | `ba2a1d1cce0f` | yes |
| preactjs/preact | family-outcomes | 195 | `34d0b8bf6362` | `34d0b8bf6362` | yes |
| preactjs/preact | decision-ledger | 1 | `06c962106648` | `06c962106648` | yes |
| preactjs/preact | embedding-documents | 1852 | `2485ccfdb9af` | `2485ccfdb9af` | yes |
| preactjs/preact | embedding-batches | 29 | `28aa21a2e613` | `28aa21a2e613` | yes |
| preactjs/preact | embedding-ledger | 1 | `7eadcf662ea6` | `7eadcf662ea6` | yes |
| preactjs/preact | decisions | 525 | `6b94649945e8` | `6b94649945e8` | yes |
| preactjs/preact | family-outcomes | 197 | `890d4afb18d2` | `890d4afb18d2` | yes |
| preactjs/preact | decision-ledger | 1 | `e6f1f1960dc1` | `e6f1f1960dc1` | yes |
| preactjs/preact | embedding-documents | 1868 | `6268b9ed458c` | `6268b9ed458c` | yes |
| preactjs/preact | embedding-batches | 30 | `bcea27723f78` | `bcea27723f78` | yes |
| preactjs/preact | embedding-ledger | 1 | `0399c9510487` | `0399c9510487` | yes |
| preactjs/preact | decisions | 521 | `92e68f65afa2` | `92e68f65afa2` | yes |
| preactjs/preact | family-outcomes | 197 | `b121b24fe079` | `b121b24fe079` | yes |
| preactjs/preact | decision-ledger | 1 | `3163a529480a` | `3163a529480a` | yes |
| preactjs/preact | embedding-documents | 2014 | `baabf5d1eaa0` | `baabf5d1eaa0` | yes |
| preactjs/preact | embedding-batches | 32 | `e59c6941ac35` | `e59c6941ac35` | yes |
| preactjs/preact | embedding-ledger | 1 | `c4fa90968f7a` | `c4fa90968f7a` | yes |
| preactjs/preact | decisions | 537 | `128347cc75c1` | `128347cc75c1` | yes |
| preactjs/preact | family-outcomes | 204 | `af82c9c0795c` | `af82c9c0795c` | yes |
| preactjs/preact | decision-ledger | 1 | `200f2772402e` | `200f2772402e` | yes |
| preactjs/preact | embedding-documents | 2065 | `e6ac80099019` | `e6ac80099019` | yes |
| preactjs/preact | embedding-batches | 33 | `8f751b75b6ff` | `8f751b75b6ff` | yes |
| preactjs/preact | embedding-ledger | 1 | `d4df8f8fbe91` | `d4df8f8fbe91` | yes |
| preactjs/preact | decisions | 537 | `c91011ad4a21` | `c91011ad4a21` | yes |
| preactjs/preact | family-outcomes | 205 | `9ed546861337` | `9ed546861337` | yes |
| preactjs/preact | decision-ledger | 1 | `2187835960d3` | `2187835960d3` | yes |
| preactjs/preact | embedding-documents | 2122 | `462edc14a109` | `462edc14a109` | yes |
| preactjs/preact | embedding-batches | 34 | `db814cdff289` | `db814cdff289` | yes |
| preactjs/preact | embedding-ledger | 1 | `936f97217887` | `936f97217887` | yes |
| preactjs/preact | decisions | 556 | `e8b2c3c618ad` | `e8b2c3c618ad` | yes |
| preactjs/preact | family-outcomes | 210 | `389b1b4a7416` | `389b1b4a7416` | yes |
| preactjs/preact | decision-ledger | 1 | `058ce410dced` | `058ce410dced` | yes |
| protonmail/webclients | embedding-documents | 10629 | `f5adca76484e` | `f5adca76484e` | yes |
| protonmail/webclients | embedding-batches | 167 | `89e2fc57d110` | `89e2fc57d110` | yes |
| protonmail/webclients | embedding-ledger | 1 | `8f5d4c4ef37e` | `8f5d4c4ef37e` | yes |
| protonmail/webclients | decisions | 9866 | `f9918abd7660` | `f9918abd7660` | yes |
| protonmail/webclients | family-outcomes | 3143 | `0cc807dfd132` | `0cc807dfd132` | yes |
| protonmail/webclients | decision-ledger | 1 | `1fe20691dc70` | `1fe20691dc70` | yes |
| tutao/tutanota | embedding-documents | 9480 | `d56baf243290` | `d56baf243290` | yes |
| tutao/tutanota | embedding-batches | 149 | `8c2f9397e09b` | `8c2f9397e09b` | yes |
| tutao/tutanota | embedding-ledger | 1 | `abfb87421f24` | `abfb87421f24` | yes |
| tutao/tutanota | decisions | 2252 | `36714c44427a` | `36714c44427a` | yes |
| tutao/tutanota | family-outcomes | 768 | `7d57dddc4ca2` | `7d57dddc4ca2` | yes |
| tutao/tutanota | decision-ledger | 1 | `75efc4e15cab` | `75efc4e15cab` | yes |
| tutao/tutanota | embedding-documents | 9884 | `553f6159faab` | `553f6159faab` | yes |
| tutao/tutanota | embedding-batches | 155 | `fe74fbdf5a85` | `fe74fbdf5a85` | yes |
| tutao/tutanota | embedding-ledger | 1 | `0fb3273bac71` | `0fb3273bac71` | yes |
| tutao/tutanota | decisions | 2319 | `c795a799aa47` | `c795a799aa47` | yes |
| tutao/tutanota | family-outcomes | 792 | `de41e6eeb8f0` | `de41e6eeb8f0` | yes |
| tutao/tutanota | decision-ledger | 1 | `82f0ab507318` | `82f0ab507318` | yes |
| tutao/tutanota | embedding-documents | 9730 | `109726361bad` | `109726361bad` | yes |
| tutao/tutanota | embedding-batches | 153 | `b912117fafbd` | `b912117fafbd` | yes |
| tutao/tutanota | embedding-ledger | 1 | `74a1af880f6a` | `74a1af880f6a` | yes |
| tutao/tutanota | decisions | 2294 | `8f625f9265e6` | `8f625f9265e6` | yes |
| tutao/tutanota | family-outcomes | 783 | `4eb4dd046f5f` | `4eb4dd046f5f` | yes |
| tutao/tutanota | decision-ledger | 1 | `063e7f82aeb0` | `063e7f82aeb0` | yes |
| vuejs/core | embedding-documents | 4149 | `4df2069a10f7` | `4df2069a10f7` | yes |
| vuejs/core | embedding-batches | 65 | `6546924d3cb7` | `6546924d3cb7` | yes |
| vuejs/core | embedding-ledger | 1 | `e9b1bb01a854` | `e9b1bb01a854` | yes |
| vuejs/core | decisions | 1063 | `b26393a5b917` | `b26393a5b917` | yes |
| vuejs/core | family-outcomes | 388 | `0cc99bd682b0` | `0cc99bd682b0` | yes |
| vuejs/core | decision-ledger | 1 | `74b0183c152c` | `74b0183c152c` | yes |
| vuejs/core | embedding-documents | 4179 | `68e8b6c3bfb7` | `68e8b6c3bfb7` | yes |
| vuejs/core | embedding-batches | 66 | `802d58e8ac1e` | `802d58e8ac1e` | yes |
| vuejs/core | embedding-ledger | 1 | `a058de9df59d` | `a058de9df59d` | yes |
| vuejs/core | decisions | 1066 | `bf008a5793f1` | `bf008a5793f1` | yes |
| vuejs/core | family-outcomes | 390 | `8d0566a5a609` | `8d0566a5a609` | yes |
| vuejs/core | decision-ledger | 1 | `4f49b698c892` | `4f49b698c892` | yes |
| vuejs/core | embedding-documents | 4224 | `e9c139355359` | `e9c139355359` | yes |
| vuejs/core | embedding-batches | 66 | `f880a96133ac` | `f880a96133ac` | yes |
| vuejs/core | embedding-ledger | 1 | `fa2ab2649cf8` | `fa2ab2649cf8` | yes |
| vuejs/core | decisions | 1069 | `46faa92753d6` | `46faa92753d6` | yes |
| vuejs/core | family-outcomes | 390 | `71521db569fe` | `71521db569fe` | yes |
| vuejs/core | decision-ledger | 1 | `4f69c3797df0` | `4f69c3797df0` | yes |
| vuejs/core | embedding-documents | 4224 | `c9261be70d7e` | `c9261be70d7e` | yes |
| vuejs/core | embedding-batches | 66 | `2b577b3d1901` | `2b577b3d1901` | yes |
| vuejs/core | embedding-ledger | 1 | `cc3963de927f` | `cc3963de927f` | yes |
| vuejs/core | decisions | 1064 | `e84e55a1db5a` | `e84e55a1db5a` | yes |
| vuejs/core | family-outcomes | 390 | `eee2368679a7` | `eee2368679a7` | yes |
| vuejs/core | decision-ledger | 1 | `be4019a299f9` | `be4019a299f9` | yes |

- preactjs/preact: 487 of 487 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- NodeBB/NodeBB: 1057 of 1057 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- NodeBB/NodeBB: 1056 of 1056 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- NodeBB/NodeBB: 1104 of 1104 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- NodeBB/NodeBB: 1094 of 1094 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- NodeBB/NodeBB: 1062 of 1062 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- NodeBB/NodeBB: 1061 of 1061 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- NodeBB/NodeBB: 1030 of 1030 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- NodeBB/NodeBB: 1168 of 1168 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- NodeBB/NodeBB: 1069 of 1069 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- NodeBB/NodeBB: 1063 of 1063 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- NodeBB/NodeBB: 1169 of 1169 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- NodeBB/NodeBB: 1084 of 1084 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- NodeBB/NodeBB: 1173 of 1173 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- NodeBB/NodeBB: 1110 of 1110 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- NodeBB/NodeBB: 1054 of 1054 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- NodeBB/NodeBB: 1140 of 1140 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- NodeBB/NodeBB: 1053 of 1053 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- NodeBB/NodeBB: 1048 of 1048 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- NodeBB/NodeBB: 1203 of 1203 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- NodeBB/NodeBB: 1158 of 1158 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- NodeBB/NodeBB: 1169 of 1169 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- NodeBB/NodeBB: 1118 of 1118 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- axios/axios: 131 of 131 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- axios/axios: 167 of 167 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- element-hq/element-web: 2249 of 2249 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- element-hq/element-web: 2327 of 2327 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- facebook/docusaurus: 2248 of 2248 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- facebook/docusaurus: 2280 of 2280 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- facebook/docusaurus: 2158 of 2158 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- immutable-js/immutable-js: 332 of 332 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- immutable-js/immutable-js: 327 of 327 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- preactjs/preact: 510 of 510 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- preactjs/preact: 518 of 518 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- preactjs/preact: 531 of 531 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- preactjs/preact: 548 of 548 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- preactjs/preact: 553 of 553 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- preactjs/preact: 554 of 554 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- preactjs/preact: 551 of 551 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- preactjs/preact: 569 of 569 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- preactjs/preact: 570 of 570 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- preactjs/preact: 590 of 590 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- protonmail/webclients: 10033 of 10033 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- tutao/tutanota: 2401 of 2401 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- tutao/tutanota: 2474 of 2474 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- tutao/tutanota: 2447 of 2447 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- vuejs/core: 1128 of 1128 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- vuejs/core: 1132 of 1132 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- vuejs/core: 1135 of 1135 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
- vuejs/core: 1130 of 1130 retained exchanges served, 0 provider calls, key absent: yes, exact: yes.
<!-- families:acquisition:end -->

The original preact evidence is the tracked exemplar:
`.attune/families-embeddings-v1/6e2bef41…/` holds its 26 raw batch bodies and
three embedding tables, and `.attune/jev-families-raw-v1/6e2bef41…/` holds its
461 raw decision exchanges and three decision tables. Later worlds' large
evidence stays out of git. Their small BUILD files declare the evidence to
Bazel, and content-addressed archives in BuildBuddy retain the raw and typed
inputs used for keyless replay.

**Review point (completed).** Milestone 1 reviewed the protocol, measured cost,
and storage plan before acquisition scaled to other worlds.

## Clustering record

The clustering method (`atlas-families-v1`, constants and steps in
[PROTOCOL.md](PROTOCOL.md#clustering-method-atlas-families-v1)) runs keylessly
over each acquired world's frozen tables and two recorded-evidence filegroups.
The original `cluster_preact` and `cluster_preact_rerun` actions established
byte-identical reruns; the Starlark world targets extend that route and its
laws to the acquired population. The block below is projected from the built
tables by `:clustering_report`.
Regenerate with
`nix develop --command bazel build //experiments/atlas-families:clustering_report --config=buildbuddy-rbe-arm64`.

<!-- families:clustering:begin -->
**Families**

| repository | snapshot | seeds | candidates | families | members | largest | singletons | held by 2+ frontiers | seed fallback | named by decision |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| preactjs/preact | `6e2bef41bf19` | 171 | 161 | 159 | 1623 | 120 | 29 | 133 | 166 | 158 |
| NodeBB/NodeBB | `4b14c05228d2` | 374 | 361 | 332 | 1385 | 19 | 82 | 417 | 24 | 330 |
| NodeBB/NodeBB | `43d1969f5d5b` | 378 | 369 | 337 | 1400 | 19 | 88 | 420 | 23 | 335 |
| NodeBB/NodeBB | `d60aff465833` | 391 | 378 | 349 | 1488 | 21 | 89 | 486 | 29 | 347 |
| NodeBB/NodeBB | `b01273c831ec` | 388 | 372 | 344 | 1475 | 21 | 89 | 519 | 38 | 342 |
| NodeBB/NodeBB | `55d7a8cefbff` | 378 | 366 | 336 | 1408 | 20 | 87 | 421 | 24 | 334 |
| NodeBB/NodeBB | `8d83c9906172` | 378 | 366 | 333 | 1408 | 20 | 83 | 455 | 29 | 331 |
| NodeBB/NodeBB | `d13b9c7923b4` | 370 | 361 | 330 | 1367 | 19 | 82 | 380 | 21 | 328 |
| NodeBB/NodeBB | `0a4d2c8aacbb` | 410 | 397 | 370 | 1663 | 28 | 92 | 437 | 21 | 368 |
| NodeBB/NodeBB | `29e9da075af8` | 379 | 369 | 340 | 1451 | 21 | 86 | 501 | 21 | 338 |
| NodeBB/NodeBB | `47676c68fbcc` | 378 | 363 | 337 | 1437 | 20 | 86 | 441 | 26 | 335 |
| NodeBB/NodeBB | `945252fe6e86` | 413 | 399 | 376 | 1677 | 28 | 101 | 357 | 20 | 374 |
| NodeBB/NodeBB | `d81af495867c` | 385 | 374 | 345 | 1466 | 21 | 87 | 539 | 21 | 343 |
| NodeBB/NodeBB | `8037ac6f9244` | 413 | 401 | 372 | 1667 | 28 | 95 | 474 | 19 | 370 |
| NodeBB/NodeBB | `cb161a51dc34` | 394 | 382 | 356 | 1576 | 25 | 93 | 339 | 39 | 354 |
| NodeBB/NodeBB | `bb174a00f112` | 374 | 358 | 331 | 1393 | 19 | 82 | 348 | 31 | 329 |
| NodeBB/NodeBB | `72a6fb2a39b8` | 400 | 386 | 359 | 1614 | 28 | 92 | 455 | 26 | 357 |
| NodeBB/NodeBB | `962ea6c586b0` | 374 | 361 | 332 | 1396 | 19 | 82 | 398 | 23 | 330 |
| NodeBB/NodeBB | `f73daccf345e` | 374 | 361 | 333 | 1396 | 19 | 85 | 405 | 28 | 331 |
| NodeBB/NodeBB | `f4f3fb7417a2` | 424 | 410 | 383 | 1707 | 29 | 99 | 494 | 16 | 381 |
| NodeBB/NodeBB | `2d10a775f968` | 413 | 401 | 374 | 1679 | 28 | 98 | 447 | 21 | 372 |
| NodeBB/NodeBB | `ee4256c77f74` | 413 | 399 | 375 | 1668 | 28 | 98 | 387 | 20 | 373 |
| NodeBB/NodeBB | `c39f4787c4aa` | 394 | 378 | 351 | 1574 | 24 | 87 | 549 | 26 | 349 |
| axios/axios | `1e44a1c45ec4` | 46 | 38 | 33 | 295 | 83 | 6 | 81 | 1 | 30 |
| axios/axios | `af4495290bbc` | 56 | 50 | 43 | 707 | 130 | 10 | 129 | 0 | 39 |
| element-hq/element-web | `2ad7fd77595b` | 741 | 702 | 634 | 5714 | 90 | 56 | 3779 | 204 | 634 |
| element-hq/element-web | `ea7c1240175d` | 766 | 720 | 643 | 5883 | 90 | 59 | 3883 | 243 | 643 |
| facebook/docusaurus | `19fa623c87d7` | 724 | 650 | 633 | 5001 | 1106 | 242 | 654 | 187 | 633 |
| facebook/docusaurus | `b9dd309ede37` | 742 | 672 | 643 | 5088 | 1106 | 249 | 730 | 217 | 643 |
| facebook/docusaurus | `bc01d02e8d9b` | 699 | 631 | 607 | 4852 | 1106 | 239 | 657 | 161 | 607 |
| immutable-js/immutable-js | `f0d3c13774ad` | 125 | 119 | 111 | 618 | 111 | 52 | 398 | 13 | 111 |
| immutable-js/immutable-js | `975db8fff535` | 124 | 119 | 111 | 618 | 111 | 53 | 387 | 13 | 111 |
| preactjs/preact | `7dcd08c6dcd8` | 182 | 171 | 168 | 1683 | 120 | 31 | 220 | 161 | 167 |
| preactjs/preact | `80b1792c5480` | 187 | 177 | 175 | 1733 | 120 | 30 | 226 | 154 | 174 |
| preactjs/preact | `4fdaac70f418` | 190 | 179 | 175 | 1761 | 120 | 32 | 256 | 172 | 174 |
| preactjs/preact | `1044506ddb44` | 194 | 183 | 178 | 1787 | 120 | 31 | 230 | 233 | 177 |
| preactjs/preact | `197d5a4deb6c` | 195 | 181 | 177 | 1817 | 120 | 31 | 214 | 180 | 176 |
| preactjs/preact | `69e49acea349` | 197 | 187 | 183 | 1852 | 120 | 34 | 221 | 168 | 182 |
| preactjs/preact | `8708b4d618d6` | 197 | 186 | 182 | 1868 | 120 | 31 | 232 | 141 | 181 |
| preactjs/preact | `000365e13105` | 204 | 194 | 190 | 2014 | 126 | 33 | 258 | 157 | 189 |
| preactjs/preact | `c1e88c310b4d` | 205 | 195 | 191 | 2065 | 127 | 33 | 252 | 170 | 190 |
| preactjs/preact | `409e2753ea0d` | 210 | 197 | 194 | 2122 | 130 | 34 | 176 | 173 | 193 |
| protonmail/webclients | `e79874736660` | 3143 | 2629 | 2254 | 10629 | 100 | 486 | 6276 | 745 | 2254 |
| tutao/tutanota | `38cc6652f983` | 768 | 742 | 709 | 9480 | 381 | 82 | 3799 | 318 | 707 |
| tutao/tutanota | `6fa65b34fcfd` | 792 | 768 | 740 | 9884 | 468 | 90 | 3179 | 302 | 737 |
| tutao/tutanota | `1b1bc8349e39` | 783 | 758 | 730 | 9730 | 381 | 85 | 3211 | 345 | 728 |
| vuejs/core | `96c87d888005` | 388 | 365 | 328 | 4149 | 217 | 56 | 1500 | 669 | 326 |
| vuejs/core | `9335add06b4a` | 390 | 366 | 332 | 4179 | 217 | 57 | 1265 | 629 | 330 |
| vuejs/core | `3b5f437f41ce` | 390 | 365 | 329 | 4224 | 217 | 56 | 1388 | 622 | 327 |
| vuejs/core | `678f8ed4bfb9` | 390 | 369 | 332 | 4224 | 217 | 56 | 1241 | 688 | 330 |

**Affinity sources** (per member, weighted; ablations count members whose family changes)

| repository | mean structural | mean semantic | moved without semantic | moved without structure |
|---|---:|---:|---:|---:|
| preactjs/preact | 0.371468 | 0.179825 | 0 | 18 |
| NodeBB/NodeBB | 0.388250 | 0.150671 | 5 | 10 |
| NodeBB/NodeBB | 0.388421 | 0.150021 | 2 | 9 |
| NodeBB/NodeBB | 0.389312 | 0.151049 | 5 | 17 |
| NodeBB/NodeBB | 0.386998 | 0.150522 | 3 | 16 |
| NodeBB/NodeBB | 0.389084 | 0.150199 | 3 | 7 |
| NodeBB/NodeBB | 0.388600 | 0.150464 | 3 | 12 |
| NodeBB/NodeBB | 0.389380 | 0.150364 | 2 | 8 |
| NodeBB/NodeBB | 0.391987 | 0.151558 | 6 | 13 |
| NodeBB/NodeBB | 0.389368 | 0.150735 | 3 | 16 |
| NodeBB/NodeBB | 0.389078 | 0.150487 | 1 | 19 |
| NodeBB/NodeBB | 0.392906 | 0.151214 | 6 | 13 |
| NodeBB/NodeBB | 0.389490 | 0.151075 | 5 | 21 |
| NodeBB/NodeBB | 0.392545 | 0.151690 | 5 | 19 |
| NodeBB/NodeBB | 0.389434 | 0.150481 | 4 | 18 |
| NodeBB/NodeBB | 0.388386 | 0.150766 | 0 | 8 |
| NodeBB/NodeBB | 0.388369 | 0.150745 | 6 | 20 |
| NodeBB/NodeBB | 0.389502 | 0.150708 | 3 | 8 |
| NodeBB/NodeBB | 0.388525 | 0.150570 | 3 | 5 |
| NodeBB/NodeBB | 0.390219 | 0.151178 | 6 | 12 |
| NodeBB/NodeBB | 0.391618 | 0.151053 | 5 | 13 |
| NodeBB/NodeBB | 0.391594 | 0.151017 | 6 | 14 |
| NodeBB/NodeBB | 0.388339 | 0.150875 | 3 | 25 |
| axios/axios | 0.387521 | 0.158600 | 0 | 8 |
| axios/axios | 0.391144 | 0.153099 | 3 | 22 |
| element-hq/element-web | 0.361839 | 0.161432 | 26 | 337 |
| element-hq/element-web | 0.357964 | 0.160934 | 23 | 315 |
| facebook/docusaurus | 0.374959 | 0.166949 | 9 | 62 |
| facebook/docusaurus | 0.373477 | 0.167824 | 8 | 71 |
| facebook/docusaurus | 0.375414 | 0.166397 | 13 | 52 |
| immutable-js/immutable-js | 0.372737 | 0.143260 | 2 | 51 |
| immutable-js/immutable-js | 0.373334 | 0.142912 | 2 | 37 |
| preactjs/preact | 0.372902 | 0.179366 | 0 | 19 |
| preactjs/preact | 0.370812 | 0.179587 | 0 | 18 |
| preactjs/preact | 0.373891 | 0.179610 | 1 | 25 |
| preactjs/preact | 0.360133 | 0.175596 | 1 | 28 |
| preactjs/preact | 0.369760 | 0.179457 | 1 | 24 |
| preactjs/preact | 0.370027 | 0.179797 | 0 | 20 |
| preactjs/preact | 0.374903 | 0.180959 | 1 | 15 |
| preactjs/preact | 0.376663 | 0.180986 | 0 | 20 |
| preactjs/preact | 0.372585 | 0.180310 | 3 | 25 |
| preactjs/preact | 0.376024 | 0.180810 | 2 | 23 |
| protonmail/webclients | 0.325070 | 0.174828 | 174 | 766 |
| tutao/tutanota | 0.372769 | 0.156012 | 26 | 284 |
| tutao/tutanota | 0.374040 | 0.156875 | 20 | 324 |
| tutao/tutanota | 0.374972 | 0.156859 | 20 | 293 |
| vuejs/core | 0.348442 | 0.177762 | 10 | 103 |
| vuejs/core | 0.353348 | 0.178283 | 0 | 112 |
| vuejs/core | 0.351397 | 0.178392 | 0 | 114 |
| vuejs/core | 0.347589 | 0.177758 | 13 | 112 |

**Rollup**

| repository | files | files split across families | directories | directories with one family |
|---|---:|---:|---:|---:|
| preactjs/preact | 171 | 1 | 41 | 7 |
| NodeBB/NodeBB | 374 | 0 | 80 | 26 |
| NodeBB/NodeBB | 378 | 0 | 82 | 27 |
| NodeBB/NodeBB | 391 | 0 | 88 | 30 |
| NodeBB/NodeBB | 388 | 0 | 86 | 29 |
| NodeBB/NodeBB | 378 | 0 | 82 | 27 |
| NodeBB/NodeBB | 378 | 0 | 82 | 27 |
| NodeBB/NodeBB | 370 | 0 | 79 | 25 |
| NodeBB/NodeBB | 410 | 1 | 88 | 27 |
| NodeBB/NodeBB | 379 | 0 | 85 | 30 |
| NodeBB/NodeBB | 378 | 0 | 84 | 27 |
| NodeBB/NodeBB | 413 | 1 | 88 | 27 |
| NodeBB/NodeBB | 385 | 0 | 86 | 29 |
| NodeBB/NodeBB | 413 | 1 | 90 | 29 |
| NodeBB/NodeBB | 394 | 1 | 88 | 29 |
| NodeBB/NodeBB | 374 | 0 | 80 | 26 |
| NodeBB/NodeBB | 400 | 0 | 89 | 29 |
| NodeBB/NodeBB | 374 | 0 | 80 | 26 |
| NodeBB/NodeBB | 374 | 0 | 80 | 26 |
| NodeBB/NodeBB | 424 | 0 | 91 | 28 |
| NodeBB/NodeBB | 413 | 1 | 88 | 27 |
| NodeBB/NodeBB | 413 | 1 | 90 | 29 |
| NodeBB/NodeBB | 394 | 1 | 88 | 29 |
| axios/axios | 46 | 0 | 17 | 7 |
| axios/axios | 56 | 0 | 18 | 8 |
| element-hq/element-web | 741 | 5 | 100 | 18 |
| element-hq/element-web | 766 | 6 | 102 | 19 |
| facebook/docusaurus | 724 | 3 | 460 | 267 |
| facebook/docusaurus | 742 | 4 | 469 | 272 |
| facebook/docusaurus | 699 | 3 | 454 | 262 |
| immutable-js/immutable-js | 125 | 0 | 18 | 2 |
| immutable-js/immutable-js | 124 | 0 | 18 | 3 |
| preactjs/preact | 182 | 0 | 49 | 12 |
| preactjs/preact | 187 | 1 | 51 | 13 |
| preactjs/preact | 190 | 1 | 53 | 13 |
| preactjs/preact | 194 | 1 | 53 | 13 |
| preactjs/preact | 195 | 1 | 53 | 14 |
| preactjs/preact | 197 | 0 | 54 | 14 |
| preactjs/preact | 197 | 1 | 54 | 14 |
| preactjs/preact | 204 | 0 | 54 | 12 |
| preactjs/preact | 205 | 1 | 54 | 12 |
| preactjs/preact | 210 | 1 | 54 | 12 |
| protonmail/webclients | 3143 | 25 | 628 | 148 |
| tutao/tutanota | 768 | 7 | 158 | 38 |
| tutao/tutanota | 792 | 6 | 167 | 42 |
| tutao/tutanota | 783 | 7 | 165 | 41 |
| vuejs/core | 388 | 5 | 74 | 6 |
| vuejs/core | 390 | 1 | 74 | 6 |
| vuejs/core | 390 | 3 | 74 | 6 |
| vuejs/core | 390 | 6 | 74 | 6 |

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
| NodeBB/NodeBB | 41 | `public/src/client/category/tools.js` | file | 19 | 1 | 1 | decision `c3d5ab1ad5ee` |
| NodeBB/NodeBB | 111 | `public/src/modules/translator.js` | file | 19 | 1 | 1 | decision `6c6cb70538f8` |
| NodeBB/NodeBB | 90 | `public/src/modules/helpers.js` | file | 18 | 1 | 1 | decision `2d2205ff1cca` |
| NodeBB/NodeBB | 187 | `src/install.js` | file | 18 | 1 | 1 | decision `2151ccb965b3` |
| NodeBB/NodeBB | 18 | `public/src/admin/manage/users.js` | file | 17 | 1 | 1 | decision `e5c825aa8578` |
| NodeBB/NodeBB | 93 | `public/src/modules/navigator.js` | file | 17 | 1 | 1 | decision `b5516065ea0d` |
| NodeBB/NodeBB | 238 | `src/routes/feeds.js` | file | 16 | 1 | 1 | decision `75dc9a2cfbe2` |
| NodeBB/NodeBB | 243 | `src/search.js` | file | 16 | 1 | 1 | decision `004a13ad4fc2` |
| NodeBB/NodeBB | 41 | `public/src/client/category/tools.js` | file | 19 | 1 | 1 | decision `65e55de4c077` |
| NodeBB/NodeBB | 111 | `public/src/modules/translator.js` | file | 19 | 1 | 1 | decision `e8df172b7de2` |
| NodeBB/NodeBB | 189 | `src/install.js` | file | 19 | 1 | 1 | decision `3ee92d844a3d` |
| NodeBB/NodeBB | 90 | `public/src/modules/helpers.js` | file | 18 | 1 | 1 | decision `d02d83790ec5` |
| NodeBB/NodeBB | 18 | `public/src/admin/manage/users.js` | file | 17 | 1 | 1 | decision `d0bf9eeddde7` |
| NodeBB/NodeBB | 93 | `public/src/modules/navigator.js` | file | 17 | 1 | 1 | decision `97b95c6fc991` |
| NodeBB/NodeBB | 240 | `src/routes/feeds.js` | file | 16 | 1 | 1 | decision `376b52c405d2` |
| NodeBB/NodeBB | 68 | `public/src/client/topic/postTools.js` | file | 15 | 1 | 1 | decision `85e348f95a56` |
| NodeBB/NodeBB | 196 | `src/install.js` | file | 21 | 1 | 1 | decision `87c10280a113` |
| NodeBB/NodeBB | 91 | `public/src/modules/helpers.common.js` | file | 20 | 1 | 1 | decision `236c710165ba` |
| NodeBB/NodeBB | 113 | `public/src/modules/translator.common.js` | file | 20 | 3 | 3 | decision `338dccd2771b` |
| NodeBB/NodeBB | 42 | `public/src/client/category/tools.js` | file | 19 | 1 | 1 | decision `b49f0471e40c` |
| NodeBB/NodeBB | 95 | `public/src/modules/navigator.js` | file | 19 | 1 | 1 | decision `0843019afd5c` |
| NodeBB/NodeBB | 69 | `public/src/client/topic/postTools.js` | file | 18 | 1 | 1 | decision `127ab465450e` |
| NodeBB/NodeBB | 19 | `public/src/admin/manage/users.js` | file | 17 | 1 | 1 | decision `abec4f6c1c5f` |
| NodeBB/NodeBB | 247 | `src/routes/feeds.js` | file | 17 | 1 | 1 | decision `36cfe6fbd45b` |
| NodeBB/NodeBB | 193 | `src/install.js` | file | 21 | 1 | 1 | decision `86ec256403ed` |
| NodeBB/NodeBB | 91 | `public/src/modules/helpers.common.js` | file | 20 | 1 | 1 | decision `df97fb86c63d` |
| NodeBB/NodeBB | 113 | `public/src/modules/translator.common.js` | file | 20 | 3 | 3 | decision `fc08231750f5` |
| NodeBB/NodeBB | 42 | `public/src/client/category/tools.js` | file | 19 | 1 | 1 | decision `7113d1130694` |
| NodeBB/NodeBB | 95 | `public/src/modules/navigator.js` | file | 19 | 1 | 1 | decision `500c6c4c7fa1` |
| NodeBB/NodeBB | 69 | `public/src/client/topic/postTools.js` | file | 18 | 1 | 1 | decision `93e631891202` |
| NodeBB/NodeBB | 19 | `public/src/admin/manage/users.js` | file | 17 | 1 | 1 | decision `13cbb1d40074` |
| NodeBB/NodeBB | 242 | `src/routes/feeds.js` | file | 17 | 1 | 1 | decision `66945a493283` |
| NodeBB/NodeBB | 90 | `public/src/modules/helpers.js` | file | 20 | 1 | 1 | decision `975cd9cb853f` |
| NodeBB/NodeBB | 41 | `public/src/client/category/tools.js` | file | 19 | 1 | 1 | decision `4b5cbdad1047` |
| NodeBB/NodeBB | 111 | `public/src/modules/translator.js` | file | 19 | 1 | 1 | decision `e66bab399b67` |
| NodeBB/NodeBB | 191 | `src/install.js` | file | 19 | 1 | 1 | decision `e69d4e379509` |
| NodeBB/NodeBB | 18 | `public/src/admin/manage/users.js` | file | 17 | 1 | 1 | decision `ee4f575664ae` |
| NodeBB/NodeBB | 93 | `public/src/modules/navigator.js` | file | 17 | 1 | 1 | decision `1ae0fe203ef3` |
| NodeBB/NodeBB | 239 | `src/routes/feeds.js` | file | 16 | 1 | 1 | decision `2c6b17110045` |
| NodeBB/NodeBB | 68 | `public/src/client/topic/postTools.js` | file | 15 | 1 | 1 | decision `f384fa326f91` |
| NodeBB/NodeBB | 90 | `public/src/modules/helpers.js` | file | 20 | 1 | 1 | decision `ab4ffb69ad93` |
| NodeBB/NodeBB | 41 | `public/src/client/category/tools.js` | file | 19 | 1 | 1 | decision `19eb2f471ad3` |
| NodeBB/NodeBB | 111 | `public/src/modules/translator.js` | file | 19 | 1 | 1 | decision `bfcc679a346b` |
| NodeBB/NodeBB | 188 | `src/install.js` | file | 19 | 1 | 1 | decision `875508275de8` |
| NodeBB/NodeBB | 18 | `public/src/admin/manage/users.js` | file | 17 | 1 | 1 | decision `203ee51e3e95` |
| NodeBB/NodeBB | 93 | `public/src/modules/navigator.js` | file | 17 | 1 | 1 | decision `e0b3d630d122` |
| NodeBB/NodeBB | 238 | `src/routes/feeds.js` | file | 16 | 1 | 1 | decision `66360b2f8a3c` |
| NodeBB/NodeBB | 68 | `public/src/client/topic/postTools.js` | file | 15 | 1 | 1 | decision `061b3bd3a898` |
| NodeBB/NodeBB | 110 | `public/src/modules/translator.js` | file | 19 | 1 | 1 | decision `a22f37212a2a` |
| NodeBB/NodeBB | 41 | `public/src/client/category/tools.js` | file | 18 | 1 | 1 | decision `28071fcfc2af` |
| NodeBB/NodeBB | 89 | `public/src/modules/helpers.js` | file | 18 | 1 | 1 | decision `326acf8d4b4d` |
| NodeBB/NodeBB | 186 | `src/install.js` | file | 18 | 1 | 1 | decision `58edc66f60ea` |
| NodeBB/NodeBB | 18 | `public/src/admin/manage/users.js` | file | 17 | 1 | 1 | decision `d577fe486c9c` |
| NodeBB/NodeBB | 92 | `public/src/modules/navigator.js` | file | 17 | 1 | 1 | decision `6d925cbf9df1` |
| NodeBB/NodeBB | 237 | `src/routes/feeds.js` | file | 16 | 1 | 1 | decision `051cc47e1730` |
| NodeBB/NodeBB | 242 | `src/search.js` | file | 16 | 1 | 1 | decision `42dac2c9ff87` |
| NodeBB/NodeBB | 102 | `public/src/modules/helpers.common.js` | file | 28 | 1 | 1 | decision `d8090ca26e1b` |
| NodeBB/NodeBB | 106 | `public/src/modules/navigator.js` | file | 23 | 1 | 1 | decision `3bc8ff02f7de` |
| NodeBB/NodeBB | 209 | `src/install.js` | file | 22 | 1 | 1 | decision `56dc6b7917e1` |
| NodeBB/NodeBB | 44 | `public/src/client/category/tools.js` | file | 20 | 1 | 1 | decision `ce9547ec82f0` |
| NodeBB/NodeBB | 230 | `src/middleware/render.js` | file | 20 | 1 | 1 | decision `0446c2519d3f` |
| NodeBB/NodeBB | 125 | `public/src/modules/translator.common.js` | file | 19 | 2 | 3 | decision `796ff20fe153` |
| NodeBB/NodeBB | 22 | `public/src/admin/manage/users.js` | file | 18 | 1 | 1 | decision `84133bb4c910` |
| NodeBB/NodeBB | 79 | `public/src/client/topic/postTools.js` | file | 18 | 1 | 1 | decision `c9841f10f394` |
| NodeBB/NodeBB | 192 | `src/install.js` | file | 21 | 1 | 1 | decision `ee684d9d26bd` |
| NodeBB/NodeBB | 89 | `public/src/modules/helpers.js` | file | 20 | 1 | 1 | decision `bd3b94c878cd` |
| NodeBB/NodeBB | 41 | `public/src/client/category/tools.js` | file | 19 | 1 | 1 | decision `3391ebebc0ed` |
| NodeBB/NodeBB | 111 | `public/src/modules/translator.js` | file | 19 | 1 | 1 | decision `73ff38b72d54` |
| NodeBB/NodeBB | 67 | `public/src/client/topic/postTools.js` | file | 18 | 1 | 1 | decision `3bb6c9f4121e` |
| NodeBB/NodeBB | 18 | `public/src/admin/manage/users.js` | file | 17 | 1 | 1 | decision `a0eddcde882c` |
| NodeBB/NodeBB | 93 | `public/src/modules/navigator.js` | file | 17 | 1 | 1 | decision `e7829c1733fe` |
| NodeBB/NodeBB | 243 | `src/routes/feeds.js` | file | 17 | 1 | 1 | decision `7642b295e071` |
| NodeBB/NodeBB | 90 | `public/src/modules/helpers.js` | file | 20 | 1 | 1 | decision `577fb590ca10` |
| NodeBB/NodeBB | 41 | `public/src/client/category/tools.js` | file | 19 | 1 | 1 | decision `084c70200ee7` |
| NodeBB/NodeBB | 112 | `public/src/modules/translator.js` | file | 19 | 1 | 1 | decision `911b78ed1139` |
| NodeBB/NodeBB | 191 | `src/install.js` | file | 19 | 1 | 1 | decision `97cec8d7940c` |
| NodeBB/NodeBB | 68 | `public/src/client/topic/postTools.js` | file | 18 | 1 | 1 | decision `96c82deb15a5` |
| NodeBB/NodeBB | 18 | `public/src/admin/manage/users.js` | file | 17 | 1 | 1 | decision `99c23e711e62` |
| NodeBB/NodeBB | 94 | `public/src/modules/navigator.js` | file | 17 | 1 | 1 | decision `a5fdf8c0ae4c` |
| NodeBB/NodeBB | 239 | `src/routes/feeds.js` | file | 17 | 1 | 1 | decision `fd7b7369dcda` |
| NodeBB/NodeBB | 104 | `public/src/modules/helpers.common.js` | file | 28 | 1 | 1 | decision `9c10b7936fce` |
| NodeBB/NodeBB | 108 | `public/src/modules/navigator.js` | file | 24 | 1 | 1 | decision `abd0e47f7531` |
| NodeBB/NodeBB | 213 | `src/install.js` | file | 22 | 1 | 1 | decision `e6f6678034a1` |
| NodeBB/NodeBB | 45 | `public/src/client/category/tools.js` | file | 20 | 1 | 1 | decision `4409cff6ee98` |
| NodeBB/NodeBB | 234 | `src/middleware/render.js` | file | 20 | 1 | 1 | decision `67bb2c323da6` |
| NodeBB/NodeBB | 127 | `public/src/modules/translator.common.js` | file | 19 | 2 | 3 | decision `b470db515297` |
| NodeBB/NodeBB | 22 | `public/src/admin/manage/users.js` | file | 18 | 1 | 1 | decision `71eb62b9dbf1` |
| NodeBB/NodeBB | 80 | `public/src/client/topic/postTools.js` | file | 18 | 1 | 1 | decision `99c89793e276` |
| NodeBB/NodeBB | 193 | `src/install.js` | file | 21 | 1 | 1 | decision `9a429530e8a3` |
| NodeBB/NodeBB | 90 | `public/src/modules/helpers.js` | file | 20 | 1 | 1 | decision `0be2867f46a1` |
| NodeBB/NodeBB | 41 | `public/src/client/category/tools.js` | file | 19 | 1 | 1 | decision `f2a75581d960` |
| NodeBB/NodeBB | 94 | `public/src/modules/navigator.js` | file | 19 | 1 | 1 | decision `07a4e42c17dd` |
| NodeBB/NodeBB | 112 | `public/src/modules/translator.js` | file | 19 | 1 | 1 | decision `df2d7a89be39` |
| NodeBB/NodeBB | 68 | `public/src/client/topic/postTools.js` | file | 18 | 1 | 1 | decision `3c4014dc5b7c` |
| NodeBB/NodeBB | 18 | `public/src/admin/manage/users.js` | file | 17 | 1 | 1 | decision `4d9ea7745a83` |
| NodeBB/NodeBB | 243 | `src/routes/feeds.js` | file | 17 | 1 | 1 | decision `ead776135eb6` |
| NodeBB/NodeBB | 102 | `public/src/modules/helpers.common.js` | file | 28 | 1 | 1 | decision `d8678747f7b3` |
| NodeBB/NodeBB | 106 | `public/src/modules/navigator.js` | file | 23 | 1 | 1 | decision `e2a0896199a1` |
| NodeBB/NodeBB | 212 | `src/install.js` | file | 22 | 1 | 1 | decision `ee3b1eb5acb9` |
| NodeBB/NodeBB | 44 | `public/src/client/category/tools.js` | file | 20 | 1 | 1 | decision `1e0297d0242e` |
| NodeBB/NodeBB | 233 | `src/middleware/render.js` | file | 20 | 1 | 1 | decision `3ccf29148fed` |
| NodeBB/NodeBB | 125 | `public/src/modules/translator.common.js` | file | 19 | 2 | 3 | decision `1d5c37238516` |
| NodeBB/NodeBB | 22 | `public/src/admin/manage/users.js` | file | 18 | 1 | 1 | decision `3f8ae2d942d1` |
| NodeBB/NodeBB | 79 | `public/src/client/topic/postTools.js` | file | 18 | 1 | 1 | decision `6394d8407e4d` |
| NodeBB/NodeBB | 93 | `public/src/modules/helpers.common.js` | file | 25 | 1 | 1 | decision `2cd97f07a853` |
| NodeBB/NodeBB | 97 | `public/src/modules/navigator.js` | file | 23 | 1 | 1 | decision `1afafe8ea92b` |
| NodeBB/NodeBB | 198 | `src/install.js` | file | 22 | 1 | 1 | decision `a8223b1954e1` |
| NodeBB/NodeBB | 216 | `src/middleware/render.js` | file | 20 | 1 | 1 | decision `c2c4ab075d68` |
| NodeBB/NodeBB | 42 | `public/src/client/category/tools.js` | file | 19 | 1 | 1 | decision `71d782763660` |
| NodeBB/NodeBB | 116 | `public/src/modules/translator.common.js` | file | 19 | 2 | 3 | decision `b8e50c40d064` |
| NodeBB/NodeBB | 70 | `public/src/client/topic/postTools.js` | file | 18 | 1 | 1 | decision `aedf6797d681` |
| NodeBB/NodeBB | 270 | `src/topics/events.js` | file | 18 | 1 | 1 | decision `56416b628398` |
| NodeBB/NodeBB | 41 | `public/src/client/category/tools.js` | file | 19 | 1 | 1 | decision `adad79ba5e46` |
| NodeBB/NodeBB | 111 | `public/src/modules/translator.js` | file | 19 | 1 | 1 | decision `c7685d1f1373` |
| NodeBB/NodeBB | 188 | `src/install.js` | file | 19 | 1 | 1 | decision `c1b9ef7ba09c` |
| NodeBB/NodeBB | 90 | `public/src/modules/helpers.js` | file | 18 | 1 | 1 | decision `43f3b59a44f8` |
| NodeBB/NodeBB | 18 | `public/src/admin/manage/users.js` | file | 17 | 1 | 1 | decision `5d4d149b507b` |
| NodeBB/NodeBB | 93 | `public/src/modules/navigator.js` | file | 17 | 1 | 1 | decision `d6f357bd4519` |
| NodeBB/NodeBB | 236 | `src/routes/feeds.js` | file | 16 | 1 | 1 | decision `ea0c580af306` |
| NodeBB/NodeBB | 241 | `src/search.js` | file | 16 | 1 | 1 | decision `a904ef473fb3` |
| NodeBB/NodeBB | 96 | `public/src/modules/helpers.common.js` | file | 28 | 1 | 1 | decision `825177b7f595` |
| NodeBB/NodeBB | 100 | `public/src/modules/navigator.js` | file | 23 | 1 | 1 | decision `89f5cc483883` |
| NodeBB/NodeBB | 201 | `src/install.js` | file | 22 | 1 | 1 | decision `334f1c4a7fe4` |
| NodeBB/NodeBB | 42 | `public/src/client/category/tools.js` | file | 20 | 1 | 1 | decision `7826aaa1068a` |
| NodeBB/NodeBB | 218 | `src/middleware/render.js` | file | 20 | 1 | 1 | decision `c18b83e2ae53` |
| NodeBB/NodeBB | 119 | `public/src/modules/translator.common.js` | file | 19 | 2 | 3 | decision `6303a1eb9491` |
| NodeBB/NodeBB | 73 | `public/src/client/topic/postTools.js` | file | 18 | 1 | 1 | decision `2dbe775e2378` |
| NodeBB/NodeBB | 273 | `src/topics/events.js` | file | 18 | 1 | 1 | decision `dcc55a6d4d8b` |
| NodeBB/NodeBB | 41 | `public/src/client/category/tools.js` | file | 19 | 1 | 1 | decision `10e7428ac2b7` |
| NodeBB/NodeBB | 111 | `public/src/modules/translator.js` | file | 19 | 1 | 1 | decision `373c7189c551` |
| NodeBB/NodeBB | 187 | `src/install.js` | file | 19 | 1 | 1 | decision `dc17c5efa608` |
| NodeBB/NodeBB | 90 | `public/src/modules/helpers.js` | file | 18 | 1 | 1 | decision `d477038096c5` |
| NodeBB/NodeBB | 18 | `public/src/admin/manage/users.js` | file | 17 | 1 | 1 | decision `fae4934cd8b7` |
| NodeBB/NodeBB | 93 | `public/src/modules/navigator.js` | file | 17 | 1 | 1 | decision `3e01ad31d5f2` |
| NodeBB/NodeBB | 237 | `src/routes/feeds.js` | file | 16 | 1 | 1 | decision `1a3a8afac4c8` |
| NodeBB/NodeBB | 242 | `src/search.js` | file | 16 | 1 | 1 | decision `55bc2f435492` |
| NodeBB/NodeBB | 41 | `public/src/client/category/tools.js` | file | 19 | 1 | 1 | decision `01f9039f2702` |
| NodeBB/NodeBB | 111 | `public/src/modules/translator.js` | file | 19 | 1 | 1 | decision `794834408852` |
| NodeBB/NodeBB | 192 | `src/install.js` | file | 19 | 1 | 1 | decision `62d2742ed79c` |
| NodeBB/NodeBB | 90 | `public/src/modules/helpers.js` | file | 18 | 1 | 1 | decision `c7d7f1284155` |
| NodeBB/NodeBB | 18 | `public/src/admin/manage/users.js` | file | 17 | 1 | 1 | decision `57b2a446fafb` |
| NodeBB/NodeBB | 93 | `public/src/modules/navigator.js` | file | 17 | 1 | 1 | decision `f7015d50dd94` |
| NodeBB/NodeBB | 240 | `src/routes/feeds.js` | file | 16 | 1 | 1 | decision `85c25a87af1a` |
| NodeBB/NodeBB | 245 | `src/search.js` | file | 16 | 1 | 1 | decision `9a44fdd8cf72` |
| NodeBB/NodeBB | 106 | `public/src/modules/helpers.common.js` | file | 29 | 1 | 1 | decision `d37954a99e9a` |
| NodeBB/NodeBB | 110 | `public/src/modules/navigator.js` | file | 24 | 1 | 1 | decision `37fd2e499a4d` |
| NodeBB/NodeBB | 218 | `src/install.js` | file | 23 | 1 | 1 | decision `579bed10364f` |
| NodeBB/NodeBB | 46 | `public/src/client/category/tools.js` | file | 20 | 1 | 1 | decision `cdc5eafab552` |
| NodeBB/NodeBB | 239 | `src/middleware/render.js` | file | 20 | 1 | 1 | decision `a5cc7f12401b` |
| NodeBB/NodeBB | 292 | `src/topics/events.js` | file | 19 | 1 | 1 | decision `9e5cda5ad3f7` |
| NodeBB/NodeBB | 23 | `public/src/admin/manage/users.js` | file | 18 | 1 | 1 | decision `d53dfd6067e9` |
| NodeBB/NodeBB | 81 | `public/src/client/topic/postTools.js` | file | 18 | 1 | 1 | decision `1d004ff3686f` |
| NodeBB/NodeBB | 104 | `public/src/modules/helpers.common.js` | file | 28 | 1 | 1 | decision `008cc6a234a1` |
| NodeBB/NodeBB | 108 | `public/src/modules/navigator.js` | file | 24 | 1 | 1 | decision `11bb26654bf2` |
| NodeBB/NodeBB | 212 | `src/install.js` | file | 22 | 1 | 1 | decision `cfcb57133fcc` |
| NodeBB/NodeBB | 45 | `public/src/client/category/tools.js` | file | 20 | 1 | 1 | decision `9ed0bf04cb4b` |
| NodeBB/NodeBB | 233 | `src/middleware/render.js` | file | 20 | 1 | 1 | decision `e393aeacd1f6` |
| NodeBB/NodeBB | 127 | `public/src/modules/translator.common.js` | file | 19 | 2 | 3 | decision `0bb2076ed444` |
| NodeBB/NodeBB | 22 | `public/src/admin/manage/users.js` | file | 18 | 1 | 1 | decision `2bbfb8ff6c73` |
| NodeBB/NodeBB | 80 | `public/src/client/topic/postTools.js` | file | 18 | 1 | 1 | decision `963eab39b7ec` |
| NodeBB/NodeBB | 102 | `public/src/modules/helpers.common.js` | file | 28 | 1 | 1 | decision `49d2fd7d7dc2` |
| NodeBB/NodeBB | 106 | `public/src/modules/navigator.js` | file | 23 | 1 | 1 | decision `37a8593925ff` |
| NodeBB/NodeBB | 214 | `src/install.js` | file | 22 | 1 | 1 | decision `8ea8bf08938e` |
| NodeBB/NodeBB | 44 | `public/src/client/category/tools.js` | file | 20 | 1 | 1 | decision `fb8ad83ff47e` |
| NodeBB/NodeBB | 235 | `src/middleware/render.js` | file | 20 | 1 | 1 | decision `dd1e64da7775` |
| NodeBB/NodeBB | 125 | `public/src/modules/translator.common.js` | file | 19 | 2 | 3 | decision `16190f773eb3` |
| NodeBB/NodeBB | 22 | `public/src/admin/manage/users.js` | file | 18 | 1 | 1 | decision `9c5ff3e01dd2` |
| NodeBB/NodeBB | 79 | `public/src/client/topic/postTools.js` | file | 18 | 1 | 1 | decision `e80f5d3e5d0e` |
| NodeBB/NodeBB | 93 | `public/src/modules/helpers.common.js` | file | 24 | 1 | 1 | decision `18e2e2e49956` |
| NodeBB/NodeBB | 97 | `public/src/modules/navigator.js` | file | 23 | 1 | 1 | decision `165f603fadef` |
| NodeBB/NodeBB | 199 | `src/install.js` | file | 22 | 1 | 1 | decision `a4ee4006c3bb` |
| NodeBB/NodeBB | 217 | `src/middleware/render.js` | file | 20 | 1 | 1 | decision `b22dba96f513` |
| NodeBB/NodeBB | 42 | `public/src/client/category/tools.js` | file | 19 | 1 | 1 | decision `252b6f108318` |
| NodeBB/NodeBB | 116 | `public/src/modules/translator.common.js` | file | 19 | 2 | 3 | decision `9b25ec7954b9` |
| NodeBB/NodeBB | 70 | `public/src/client/topic/postTools.js` | file | 18 | 1 | 1 | decision `ec8c00ade07f` |
| NodeBB/NodeBB | 270 | `src/topics/events.js` | file | 18 | 1 | 1 | decision `969e03c4b929` |
| axios/axios | 0 | `dist/axios.js` | file | 83 | 1 | 1 | decision `5934f15e0200` |
| axios/axios | 26 | `test/manual/promise.js` | file | 42 | 1 | 1 | decision `45f6c0c3fbe4` |
| axios/axios | 1 | `dist/axios.min.js` | file | 28 | 1 | 1 | decision `cbbb2e25af01` |
| axios/axios | 22 | `lib/utils.js` | file | 23 | 1 | 1 | decision `56de4a63782c` |
| axios/axios | 31 | `test/typescript/axios.ts` | file | 11 | 1 | 1 | decision `348f0a07f645` |
| axios/axios | 8 | `lib/cancel` | directory | 8 | 7 | 1 | decision `50c5b4f7be24` |
| axios/axios | 18 | `lib/helpers/toFormData.js` | file | 8 | 1 | 1 | decision `00bef7f0cd23` |
| axios/axios | 29 | `test/specs/interceptors.spec.js` | file | 8 | 1 | 1 | decision `e3d060c7ef87` |
| axios/axios | 4 | `dist/node/axios.cjs` | file | 130 | 1 | 1 | decision `f1239e17a342` |
| axios/axios | 2 | `dist/esm/axios.js` | file | 112 | 1 | 1 | decision `e960c4b83fb8` |
| axios/axios | 0 | `dist/axios.js` | file | 108 | 1 | 1 | decision `66428d0a5e29` |
| axios/axios | 3 | `dist/esm/axios.min.js` | file | 77 | 1 | 1 | decision `2e079bb2b04e` |
| axios/axios | 1 | `dist/axios.min.js` | file | 57 | 1 | 1 | decision `aa72564955e7` |
| axios/axios | 34 | `test/manual/promise.js` | file | 42 | 1 | 1 | decision `16e0dc320120` |
| axios/axios | 30 | `lib/utils.js` | file | 28 | 1 | 1 | decision `bf9165512e1f` |
| axios/axios | 40 | `test/typescript/axios.ts` | file | 14 | 1 | 1 | decision `8b8651dcf020` |
| element-hq/element-web | 105 | `src/components/structures/RoomView.tsx` | file | 90 | 1 | 1 | decision `4fa5da5cfbf2` |
| element-hq/element-web | 165 | `src/components/views/dialogs/DevtoolsDialog.js` | file | 70 | 1 | 1 | decision `e63d88b054c3` |
| element-hq/element-web | 98 | `src/components/structures/MatrixChat.tsx` | file | 64 | 1 | 1 | decision `ab73a87b3d1f` |
| element-hq/element-web | 412 | `src/editor/parts.ts` | file | 63 | 1 | 1 | decision `47581c545665` |
| element-hq/element-web | 254 | `src/components/views` | directory | 54 | 2 | 1 | decision `bb8a415d70c8` |
| element-hq/element-web | 45 | `src` | directory | 52 | 3 | 1 | decision `3ae5ecaa71e7` |
| element-hq/element-web | 53 | `src` | directory | 50 | 14 | 2 | decision `472b46368fb9` |
| element-hq/element-web | 89 | `src/components/structures/GroupView.js` | file | 50 | 1 | 1 | decision `48091804630c` |
| element-hq/element-web | 103 | `src/components/structures/RoomView.tsx` | file | 90 | 1 | 1 | decision `000739cd4bc5` |
| element-hq/element-web | 164 | `src/components/views/dialogs/DevtoolsDialog.js` | file | 70 | 1 | 1 | decision `7e88830499bf` |
| element-hq/element-web | 96 | `src/components/structures/MatrixChat.tsx` | file | 64 | 1 | 1 | decision `387979f09364` |
| element-hq/element-web | 411 | `src/editor/parts.ts` | file | 64 | 1 | 1 | decision `b7cce90a4425` |
| element-hq/element-web | 54 | `src` | directory | 56 | 16 | 2 | decision `974634f4d9ed` |
| element-hq/element-web | 253 | `src/components/views` | directory | 54 | 2 | 1 | decision `60c57a3fa2fd` |
| element-hq/element-web | 48 | `src` | directory | 53 | 3 | 1 | decision `2b339d755ce6` |
| element-hq/element-web | 89 | `src/components/structures/GroupView.js` | file | 50 | 1 | 1 | decision `82d1e99dac84` |
| facebook/docusaurus | 16 | `jest/vendor/@mdx-js__mdx@3.0.0.js` | file | 1106 | 1 | 1 | decision `28dff1f9ded5` |
| facebook/docusaurus | 24 | `jest/vendor/remark@15.0.1.js` | file | 595 | 1 | 1 | decision `9ffb8a1e4335` |
| facebook/docusaurus | 22 | `jest/vendor/remark-mdx@3.0.0.js` | file | 324 | 1 | 1 | decision `9426472bf794` |
| facebook/docusaurus | 21 | `jest/vendor/remark-gfm@4.0.0.js` | file | 266 | 1 | 1 | decision `a1f00b28bd04` |
| facebook/docusaurus | 20 | `jest/vendor/remark-directive@3.0.0.js` | file | 138 | 1 | 1 | decision `bda05e1faeba` |
| facebook/docusaurus | 23 | `jest/vendor/remark-rehype@11.0.0.js` | file | 84 | 1 | 1 | decision `d7c8dbdbf1f1` |
| facebook/docusaurus | 19 | `jest/vendor/rehype-stringify@10.0.0.js` | file | 81 | 1 | 1 | decision `757428f8db76` |
| facebook/docusaurus | 95 | `packages/docusaurus-plugin-content-docs/src/sidebars` | directory | 33 | 2 | 2 | decision `4ed60224cc08` |
| facebook/docusaurus | 16 | `jest/vendor/@mdx-js__mdx@3.0.0.js` | file | 1106 | 1 | 1 | decision `fd5b93ec36c3` |
| facebook/docusaurus | 24 | `jest/vendor/remark@15.0.1.js` | file | 595 | 1 | 1 | decision `3dbe26896d3f` |
| facebook/docusaurus | 22 | `jest/vendor/remark-mdx@3.0.0.js` | file | 324 | 1 | 1 | decision `d7dd6179d0c6` |
| facebook/docusaurus | 21 | `jest/vendor/remark-gfm@4.0.0.js` | file | 266 | 1 | 1 | decision `ea9ecc83dbbc` |
| facebook/docusaurus | 20 | `jest/vendor/remark-directive@3.0.0.js` | file | 138 | 1 | 1 | decision `b9d67da111fc` |
| facebook/docusaurus | 23 | `jest/vendor/remark-rehype@11.0.0.js` | file | 84 | 1 | 1 | decision `d37f28a1729d` |
| facebook/docusaurus | 19 | `jest/vendor/rehype-stringify@10.0.0.js` | file | 81 | 1 | 1 | decision `e5974248d5ac` |
| facebook/docusaurus | 106 | `packages/docusaurus-plugin-content-docs/src/sidebars` | directory | 33 | 2 | 2 | decision `d1463958755e` |
| facebook/docusaurus | 15 | `jest/vendor/@mdx-js__mdx@3.0.0.js` | file | 1106 | 1 | 1 | decision `daddc2b9e929` |
| facebook/docusaurus | 23 | `jest/vendor/remark@15.0.1.js` | file | 595 | 1 | 1 | decision `d6dbd05eb5b6` |
| facebook/docusaurus | 21 | `jest/vendor/remark-mdx@3.0.0.js` | file | 324 | 1 | 1 | decision `3ca7403b1dbd` |
| facebook/docusaurus | 20 | `jest/vendor/remark-gfm@4.0.0.js` | file | 266 | 1 | 1 | decision `63d8d3041d65` |
| facebook/docusaurus | 19 | `jest/vendor/remark-directive@3.0.0.js` | file | 138 | 1 | 1 | decision `95b6c828ed56` |
| facebook/docusaurus | 22 | `jest/vendor/remark-rehype@11.0.0.js` | file | 84 | 1 | 1 | decision `e13f4f99218f` |
| facebook/docusaurus | 18 | `jest/vendor/rehype-stringify@10.0.0.js` | file | 81 | 1 | 1 | decision `023c0fa3cdea` |
| facebook/docusaurus | 94 | `packages/docusaurus-plugin-content-docs/src/sidebars` | directory | 33 | 2 | 2 | decision `814de57a7dc7` |
| immutable-js/immutable-js | 21 | `src/CollectionImpl.js` | file | 111 | 1 | 1 | decision `34835a9643da` |
| immutable-js/immutable-js | 27 | `src/Operations.js` | file | 41 | 1 | 1 | decision `ff7dd3826700` |
| immutable-js/immutable-js | 25 | `src/Map.js` | file | 38 | 1 | 1 | decision `3b5184db0c52` |
| immutable-js/immutable-js | 108 | `website/src/static/getTypeDefs.ts` | file | 35 | 1 | 1 | decision `b539983afca4` |
| immutable-js/immutable-js | 24 | `src/List.js` | file | 32 | 1 | 1 | decision `3e6a39d595f1` |
| immutable-js/immutable-js | 33 | `src/Seq.js` | file | 25 | 1 | 1 | decision `0312ef431499` |
| immutable-js/immutable-js | 34 | `src/Set.js` | file | 22 | 1 | 1 | decision `c4c0f5974a83` |
| immutable-js/immutable-js | 31 | `src/Record.js` | file | 21 | 1 | 1 | decision `725af5c58773` |
| immutable-js/immutable-js | 22 | `src/CollectionImpl.js` | file | 111 | 1 | 1 | decision `7b42c29342e9` |
| immutable-js/immutable-js | 28 | `src/Operations.js` | file | 41 | 1 | 1 | decision `8ac80d634180` |
| immutable-js/immutable-js | 26 | `src/Map.js` | file | 39 | 1 | 1 | decision `55c1b77cacb5` |
| immutable-js/immutable-js | 108 | `website/src/static/getTypeDefs.ts` | file | 35 | 1 | 1 | decision `06bfc6b6b3fc` |
| immutable-js/immutable-js | 25 | `src/List.js` | file | 32 | 1 | 1 | decision `f3f787d0c0cd` |
| immutable-js/immutable-js | 34 | `src/Seq.js` | file | 25 | 1 | 1 | decision `0c7e9f26dd99` |
| immutable-js/immutable-js | 35 | `src/Set.js` | file | 22 | 1 | 1 | decision `33828f09ac43` |
| immutable-js/immutable-js | 32 | `src/Record.js` | file | 21 | 1 | 1 | decision `b809f3ec9ddf` |
| preactjs/preact | 128 | `test/browser/components.test.js` | file | 120 | 1 | 1 | decision `a61bba7d5a2f` |
| preactjs/preact | 134 | `test/_util` | directory | 95 | 2 | 2 | decision `622fd216b332` |
| preactjs/preact | 148 | `test/browser/lifecycles/shouldComponentUpdate.test.js` | file | 60 | 1 | 1 | decision `ca0520d16358` |
| preactjs/preact | 36 | `compat/test/browser/suspense.test.js` | file | 55 | 1 | 1 | decision `760601fc5109` |
| preactjs/preact | 130 | `test/browser/createContext.test.js` | file | 49 | 1 | 1 | decision `cbf45582fa53` |
| preactjs/preact | 57 | `debug/test/browser/debug.test.js` | file | 46 | 1 | 1 | decision `fde7dff6394b` |
| preactjs/preact | 147 | `test/browser/lifecycles/lifecycle.test.js` | file | 43 | 1 | 1 | decision `b92a4b8ab353` |
| preactjs/preact | 137 | `test/browser/lifecycles/componentDidCatch.test.js` | file | 40 | 1 | 1 | decision `5a262ef09eed` |
| preactjs/preact | 134 | `test/browser/components.test.js` | file | 120 | 1 | 1 | decision `00dde6d4cfaa` |
| preactjs/preact | 140 | `test/_util` | directory | 88 | 1 | 1 | decision `2f5f4732b721` |
| preactjs/preact | 155 | `test/browser/lifecycles/shouldComponentUpdate.test.js` | file | 64 | 1 | 1 | decision `a978cb46eb0a` |
| preactjs/preact | 38 | `compat/test/browser/suspense.test.js` | file | 62 | 1 | 1 | decision `3785e997bbd1` |
| preactjs/preact | 136 | `test/browser/createContext.test.js` | file | 49 | 1 | 1 | decision `a85d097fb92c` |
| preactjs/preact | 61 | `debug/test/browser/debug.test.js` | file | 46 | 1 | 1 | decision `f2b9741bf94d` |
| preactjs/preact | 154 | `test/browser/lifecycles/lifecycle.test.js` | file | 43 | 1 | 1 | decision `47b85d325cc3` |
| preactjs/preact | 144 | `test/browser/lifecycles/componentDidCatch.test.js` | file | 40 | 1 | 1 | decision `631463322850` |
| preactjs/preact | 135 | `test/browser/components.test.js` | file | 120 | 1 | 1 | decision `964032f9e191` |
| preactjs/preact | 141 | `test/_util` | directory | 95 | 2 | 2 | decision `aa0540a134d1` |
| preactjs/preact | 155 | `test/browser/lifecycles/shouldComponentUpdate.test.js` | file | 64 | 1 | 1 | decision `d3ff49a674cb` |
| preactjs/preact | 37 | `compat/test/browser/suspense.test.js` | file | 62 | 1 | 1 | decision `36cde6450869` |
| preactjs/preact | 137 | `test/browser/createContext.test.js` | file | 49 | 1 | 1 | decision `4665fc02d963` |
| preactjs/preact | 60 | `debug/test/browser/debug.test.js` | file | 46 | 1 | 1 | decision `75ab0f9c01c8` |
| preactjs/preact | 154 | `test/browser/lifecycles/lifecycle.test.js` | file | 43 | 1 | 1 | decision `e54467574d4d` |
| preactjs/preact | 144 | `test/browser/lifecycles/componentDidCatch.test.js` | file | 40 | 1 | 1 | decision `b22a05b98b09` |
| preactjs/preact | 139 | `test/browser/components.test.js` | file | 120 | 1 | 1 | decision `b90ca1e5a82e` |
| preactjs/preact | 145 | `test/_util` | directory | 95 | 2 | 2 | decision `dff8eb3b088f` |
| preactjs/preact | 159 | `test/_util` | directory | 92 | 2 | 2 | decision `1ee655cd0031` |
| preactjs/preact | 40 | `compat/test/browser/suspense.test.js` | file | 62 | 1 | 1 | decision `2081c0a0cc01` |
| preactjs/preact | 141 | `test/browser/createContext.test.js` | file | 49 | 1 | 1 | decision `761d7cfb94f5` |
| preactjs/preact | 63 | `debug/test/browser/debug.test.js` | file | 46 | 1 | 1 | decision `b668cf6cc5f2` |
| preactjs/preact | 148 | `test/browser/lifecycles/componentDidCatch.test.js` | file | 43 | 1 | 1 | decision `a31bb76c1624` |
| preactjs/preact | 158 | `test/browser/lifecycles/lifecycle.test.js` | file | 43 | 1 | 1 | decision `6f14d4a55ccf` |
| preactjs/preact | 138 | `test/browser/components.test.js` | file | 120 | 1 | 1 | decision `2c009761ff2b` |
| preactjs/preact | 144 | `test/_util` | directory | 95 | 2 | 2 | decision `e9a57aed5340` |
| preactjs/preact | 158 | `test/browser/lifecycles/shouldComponentUpdate.test.js` | file | 64 | 1 | 1 | decision `74a3b5b4ed27` |
| preactjs/preact | 41 | `compat/test/browser/suspense.test.js` | file | 62 | 1 | 1 | decision `65d7c75e2b52` |
| preactjs/preact | 140 | `test/browser/createContext.test.js` | file | 49 | 1 | 1 | decision `87d4c92c04f2` |
| preactjs/preact | 63 | `debug/test/browser/debug.test.js` | file | 45 | 1 | 1 | decision `2c5d15ce9927` |
| preactjs/preact | 147 | `test/browser/lifecycles/componentDidCatch.test.js` | file | 43 | 1 | 1 | decision `06a7fe0c060d` |
| preactjs/preact | 157 | `test/browser/lifecycles/lifecycle.test.js` | file | 43 | 1 | 1 | decision `7fe75ac786f7` |
| preactjs/preact | 143 | `test/browser/components.test.js` | file | 120 | 1 | 1 | decision `050fa17df9e3` |
| preactjs/preact | 149 | `test/_util` | directory | 95 | 2 | 2 | decision `dd876349f368` |
| preactjs/preact | 163 | `test/browser/lifecycles/shouldComponentUpdate.test.js` | file | 64 | 1 | 1 | decision `b0c6647137db` |
| preactjs/preact | 42 | `compat/test/browser/suspense.test.js` | file | 62 | 1 | 1 | decision `6b6cdf8841c6` |
| preactjs/preact | 145 | `test/browser/createContext.test.js` | file | 49 | 1 | 1 | decision `c3e883ced87c` |
| preactjs/preact | 65 | `debug/test/browser/debug.test.js` | file | 45 | 1 | 1 | decision `3f96ebcbc6f1` |
| preactjs/preact | 152 | `test/browser/lifecycles/componentDidCatch.test.js` | file | 43 | 1 | 1 | decision `cb1249bd0461` |
| preactjs/preact | 162 | `test/browser/lifecycles/lifecycle.test.js` | file | 43 | 1 | 1 | decision `e791f7f0f4a4` |
| preactjs/preact | 142 | `test/browser/components.test.js` | file | 120 | 1 | 1 | decision `8666887a7a0f` |
| preactjs/preact | 148 | `test/_util` | directory | 96 | 2 | 2 | decision `9efb3ec896ea` |
| preactjs/preact | 162 | `test/browser/lifecycles/shouldComponentUpdate.test.js` | file | 64 | 1 | 1 | decision `89058541a7f6` |
| preactjs/preact | 43 | `compat/test/browser/suspense.test.js` | file | 62 | 1 | 1 | decision `c8cd2db94d08` |
| preactjs/preact | 144 | `test/browser/createContext.test.js` | file | 49 | 1 | 1 | decision `c811873467d4` |
| preactjs/preact | 66 | `debug/test/browser/debug.test.js` | file | 45 | 1 | 1 | decision `a0be26509517` |
| preactjs/preact | 151 | `test/browser/lifecycles/componentDidCatch.test.js` | file | 43 | 1 | 1 | decision `195c397009d3` |
| preactjs/preact | 161 | `test/browser/lifecycles/lifecycle.test.js` | file | 43 | 1 | 1 | decision `02345bab0e9e` |
| preactjs/preact | 148 | `test/browser/components.test.js` | file | 126 | 1 | 1 | decision `7ee24deac933` |
| preactjs/preact | 154 | `test/_util` | directory | 108 | 2 | 2 | decision `853647524091` |
| preactjs/preact | 168 | `test/browser/lifecycles/shouldComponentUpdate.test.js` | file | 69 | 1 | 1 | decision `30b7a5903970` |
| preactjs/preact | 46 | `compat/test/browser/suspense.test.js` | file | 65 | 1 | 1 | decision `6a01fac13002` |
| preactjs/preact | 69 | `debug/test/browser/debug.test.js` | file | 53 | 1 | 1 | decision `1a8a59bd0fee` |
| preactjs/preact | 150 | `test/browser/createContext.test.js` | file | 52 | 1 | 1 | decision `c0c7dfe2d6a8` |
| preactjs/preact | 157 | `test/browser/lifecycles/componentDidCatch.test.js` | file | 43 | 1 | 1 | decision `73bfc72ed263` |
| preactjs/preact | 167 | `test/browser/lifecycles/lifecycle.test.js` | file | 43 | 1 | 1 | decision `f2857a78df5b` |
| preactjs/preact | 149 | `test/browser/components.test.js` | file | 127 | 1 | 1 | decision `a22fb4bc958e` |
| preactjs/preact | 155 | `test/_util` | directory | 116 | 2 | 2 | decision `a795fd1145a1` |
| preactjs/preact | 169 | `test/browser/lifecycles/shouldComponentUpdate.test.js` | file | 69 | 1 | 1 | decision `5cf655e75bf9` |
| preactjs/preact | 46 | `compat/test/browser/suspense.test.js` | file | 65 | 1 | 1 | decision `cb7fcdb04e85` |
| preactjs/preact | 70 | `debug/test/browser/debug.test.js` | file | 53 | 1 | 1 | decision `4a3b7d514ea9` |
| preactjs/preact | 151 | `test/browser/createContext.test.js` | file | 52 | 1 | 1 | decision `e4a567820890` |
| preactjs/preact | 51 | `compat/test/browser/useSyncExternalStore.test.js` | file | 45 | 1 | 1 | decision `9b3376179087` |
| preactjs/preact | 158 | `test/browser/lifecycles/componentDidCatch.test.js` | file | 43 | 1 | 1 | decision `a48626ed2509` |
| preactjs/preact | 152 | `test/browser/components.test.js` | file | 130 | 1 | 1 | decision `43d678413b08` |
| preactjs/preact | 158 | `test/_util` | directory | 108 | 2 | 2 | decision `21c55b748228` |
| preactjs/preact | 171 | `test/browser/lifecycles/shouldComponentUpdate.test.js` | file | 69 | 1 | 1 | decision `043d03d5d6d7` |
| preactjs/preact | 71 | `debug/test/browser/debug.test.js` | file | 66 | 1 | 1 | decision `81dda3ecfa33` |
| preactjs/preact | 47 | `compat/test/browser/suspense.test.js` | file | 65 | 1 | 1 | decision `f266155afb2b` |
| preactjs/preact | 154 | `test/browser/createContext.test.js` | file | 52 | 1 | 1 | decision `e8c998192055` |
| preactjs/preact | 52 | `compat/test/browser/useSyncExternalStore.test.js` | file | 45 | 1 | 1 | decision `27170ce28996` |
| preactjs/preact | 161 | `test/browser/lifecycles/componentDidCatch.test.js` | file | 43 | 1 | 1 | decision `599d6d7093ef` |
| protonmail/webclients | 0 | `.yarn/plugins/@yarnpkg/plugin-workspace-tools.cjs` | file | 100 | 1 | 1 | decision `f75c514e7b6f` |
| protonmail/webclients | 1826 | `packages/encrypted-search/lib/esHelpers` | directory | 71 | 3 | 1 | decision `12a529961138` |
| protonmail/webclients | 1818 | `packages/crypto/lib` | directory | 55 | 1 | 1 | decision `3fc1dc4e1ab2` |
| protonmail/webclients | 1971 | `packages/shared/lib` | directory | 53 | 1 | 1 | decision `fe6792faae86` |
| protonmail/webclients | 1690 | `packages/components/containers/vpn/WireGuardConfigurationSection/WireGuardConfigurationSection.tsx` | file | 40 | 4 | 3 | decision `8c2f4f40f6f7` |
| protonmail/webclients | 1997 | `packages/shared/lib` | directory | 40 | 1 | 1 | decision `070d2a968ea6` |
| protonmail/webclients | 189 | `applications/calendar/src/app` | directory | 39 | 1 | 1 | decision `5ed7e94d7457` |
| protonmail/webclients | 2080 | `packages/shared/lib/helpers/subscription.ts` | file | 39 | 1 | 1 | decision `031b1d83207d` |
| tutao/tutanota | 33 | `libs/luxon.js` | file | 381 | 1 | 1 | decision `177266a1b2f0` |
| tutao/tutanota | 118 | `src/api/entities/sys/TypeRefs.ts` | file | 200 | 1 | 1 | decision `4d5f55e3ddf6` |
| tutao/tutanota | 57 | `packages/tutanota-crypto/lib/internal/crypto-jsbn-2012-08-09_1.js` | file | 177 | 1 | 1 | decision `1e18807983fc` |
| tutao/tutanota | 30 | `libs/jszip.js` | file | 148 | 1 | 1 | decision `cbef55a2b952` |
| tutao/tutanota | 119 | `src/api/entities/tutanota/TypeRefs.ts` | file | 120 | 1 | 1 | decision `ddb9f148c21c` |
| tutao/tutanota | 424 | `src` | directory | 120 | 3 | 1 | decision `b2637803c98f` |
| tutao/tutanota | 29 | `libs/cborg.js` | file | 118 | 1 | 1 | decision `f891d1609c10` |
| tutao/tutanota | 34 | `libs/mithril.js` | file | 91 | 1 | 1 | decision `8e5c053f8342` |
| tutao/tutanota | 36 | `libs/luxon.js` | file | 468 | 1 | 1 | decision `98bc09c68a67` |
| tutao/tutanota | 126 | `src/api/entities/sys/TypeRefs.ts` | file | 204 | 1 | 1 | decision `91546df18e2b` |
| tutao/tutanota | 60 | `packages/tutanota-crypto/lib/internal/crypto-jsbn-2012-08-09_1.js` | file | 177 | 1 | 1 | decision `bcdbfee0bc2f` |
| tutao/tutanota | 401 | `src/mail` | directory | 164 | 4 | 1 | decision `21162482ae35` |
| tutao/tutanota | 33 | `libs/jszip.js` | file | 148 | 1 | 1 | decision `c8d0c0c058a2` |
| tutao/tutanota | 127 | `src/api/entities/tutanota/TypeRefs.ts` | file | 128 | 1 | 1 | decision `50e91e1083cf` |
| tutao/tutanota | 32 | `libs/cborg.js` | file | 118 | 1 | 1 | decision `8f0a51809d77` |
| tutao/tutanota | 37 | `libs/mithril.js` | file | 91 | 1 | 1 | decision `88c6d0a23332` |
| tutao/tutanota | 33 | `libs/luxon.js` | file | 381 | 1 | 1 | decision `dc8b441deae8` |
| tutao/tutanota | 122 | `src/api/entities/sys/TypeRefs.ts` | file | 204 | 1 | 1 | decision `198069cb0006` |
| tutao/tutanota | 57 | `packages/tutanota-crypto/lib/internal/crypto-jsbn-2012-08-09_1.js` | file | 177 | 1 | 1 | decision `7b6015a619df` |
| tutao/tutanota | 30 | `libs/jszip.js` | file | 148 | 1 | 1 | decision `aed18caa0509` |
| tutao/tutanota | 437 | `src` | directory | 131 | 3 | 1 | decision `ac6fdca732ba` |
| tutao/tutanota | 123 | `src/api/entities/tutanota/TypeRefs.ts` | file | 126 | 1 | 1 | decision `d91aca5d32aa` |
| tutao/tutanota | 29 | `libs/cborg.js` | file | 118 | 1 | 1 | decision `ba616efddd81` |
| tutao/tutanota | 34 | `libs/mithril.js` | file | 91 | 1 | 1 | decision `73823a3d6f9a` |
| vuejs/core | 141 | `packages/runtime-core/__tests__/apiOptions.spec.ts` | file | 217 | 1 | 1 | decision `ffcc1093c2a4` |
| vuejs/core | 151 | `packages/runtime-core/src/components/Suspense.ts` | file | 150 | 2 | 2 | decision `0dfe30d05ef8` |
| vuejs/core | 301 | `packages/vue/__tests__/e2e` | directory | 136 | 6 | 4 | decision `9b42b42e03de` |
| vuejs/core | 173 | `packages/runtime-core/src/scheduler.ts` | file | 85 | 2 | 2 | decision `dc62533fe2fe` |
| vuejs/core | 256 | `packages/server-renderer/src` | directory | 82 | 2 | 1 | decision `5f468299b563` |
| vuejs/core | 6 | `packages-private/dts-test/defineComponent.test-d.tsx` | file | 81 | 1 | 1 | decision `43a7e09ff7bb` |
| vuejs/core | 150 | `packages/runtime-core/src/components/KeepAlive.ts` | file | 76 | 2 | 2 | decision `60cf99c9f2ff` |
| vuejs/core | 164 | `packages/runtime-core/src` | directory | 68 | 2 | 1 | decision `42891a8a8e4b` |
| vuejs/core | 143 | `packages/runtime-core/__tests__/apiOptions.spec.ts` | file | 217 | 1 | 1 | decision `a7508bf41f0a` |
| vuejs/core | 153 | `packages/runtime-core/src/components/Suspense.ts` | file | 150 | 2 | 2 | decision `3cb74007a52f` |
| vuejs/core | 305 | `packages/vue/__tests__/e2e` | directory | 141 | 6 | 3 | decision `e48f364250eb` |
| vuejs/core | 175 | `packages/runtime-core/src/scheduler.ts` | file | 85 | 2 | 2 | decision `a8740f9f0536` |
| vuejs/core | 6 | `packages-private/dts-test/defineComponent.test-d.tsx` | file | 84 | 1 | 1 | decision `89ee0f51c97e` |
| vuejs/core | 260 | `packages/server-renderer/__tests__/render.spec.ts` | file | 81 | 1 | 1 | decision `867478958ac2` |
| vuejs/core | 152 | `packages/runtime-core/src/components/KeepAlive.ts` | file | 79 | 2 | 2 | decision `8f8a3ef4b5b5` |
| vuejs/core | 147 | `packages/runtime-core/src/componentEmits.ts` | file | 65 | 2 | 2 | decision `2ffa4f598caf` |
| vuejs/core | 141 | `packages/runtime-core/__tests__/apiOptions.spec.ts` | file | 217 | 1 | 1 | decision `6ade62bd664a` |
| vuejs/core | 302 | `packages/vue/__tests__/e2e` | directory | 158 | 6 | 3 | decision `3cc71f88e213` |
| vuejs/core | 151 | `packages/runtime-core/src/components/Suspense.ts` | file | 150 | 2 | 2 | decision `34559ade0b63` |
| vuejs/core | 6 | `packages-private/dts-test/defineComponent.test-d.tsx` | file | 86 | 1 | 1 | decision `1352457f2d15` |
| vuejs/core | 258 | `packages/server-renderer/__tests__/render.spec.ts` | file | 86 | 1 | 1 | decision `2d36c8b00300` |
| vuejs/core | 173 | `packages/runtime-core/src/scheduler.ts` | file | 85 | 2 | 2 | decision `62a4f05da945` |
| vuejs/core | 150 | `packages/runtime-core/src/components/KeepAlive.ts` | file | 80 | 2 | 2 | decision `3ae8ff0bb004` |
| vuejs/core | 164 | `packages/runtime-core/src` | directory | 68 | 2 | 1 | decision `660879b72c8c` |
| vuejs/core | 141 | `packages/runtime-core/__tests__/apiOptions.spec.ts` | file | 217 | 1 | 1 | decision `9436ecde43d5` |
| vuejs/core | 304 | `packages/vue/__tests__/e2e` | directory | 151 | 5 | 2 | decision `735d4ed6bf0e` |
| vuejs/core | 151 | `packages/runtime-core/src/components/Suspense.ts` | file | 150 | 2 | 2 | decision `7e152cecb207` |
| vuejs/core | 258 | `packages/server-renderer/src` | directory | 87 | 2 | 1 | decision `e109fcbf5344` |
| vuejs/core | 6 | `packages-private/dts-test/defineComponent.test-d.tsx` | file | 86 | 1 | 1 | decision `fc16e0e0a0be` |
| vuejs/core | 173 | `packages/runtime-core/src/scheduler.ts` | file | 85 | 2 | 2 | decision `58eb1600c5c9` |
| vuejs/core | 150 | `packages/runtime-core/src/components/KeepAlive.ts` | file | 80 | 2 | 2 | decision `c821e1b219d1` |
| vuejs/core | 145 | `packages/runtime-core/src/componentEmits.ts` | file | 65 | 2 | 2 | decision `dc2349592e93` |
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

## Family edge and export record

The family-edge aggregation (`Families.Edge`, tables
`attune-atlas-family-edges-v1` and `attune-atlas-family-edge-contributions-v1`)
first ran on the clustered preact world as the hermetic Bazel action
`edges_preact`; the per-world Starlark targets apply the same aggregation to
every acquired world. Every exact
`imports` (file grain) and `calls` (symbol grain) edge of the world is exactly
one contribution row, attributed to the families of its endpoints (members at
symbol grain, dominant file rollups at file grain); the attributed
contributions of each relation and family pair aggregate to one family edge
whose multiplicity is their count. Imports touching a file that defines no
callable stay unattributed, and no edge is invented for them. The export route
is the locations precedent extended: each `export_<digest>` action writes the
`<digest>/` tree Atlas Live ships (`families.parquet` plus
`family_<table>.parquet` for the other four tables),
`//web/atlas-live/projection:families` stages it beside
`:locations`, and `project_cli` copies it into `data/<digest>/` with a manifest
entry. The block below is projected from the built tables by `:export_report`.
Regenerate with
`nix develop --command bazel build //experiments/atlas-families:export_report --config=buildbuddy-rbe-arm64`.

<!-- families:edges:begin -->
**Family edges**

| repository | snapshot | relation | grain | exact edges | attributed | unattributed | family edges | intra-family edges | intra-family multiplicity | cross-family multiplicity |
|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| preactjs/preact | `6e2bef41bf19` | imports | file | 205 | 169 | 36 | 159 | 6 | 9 | 160 |
| preactjs/preact | `6e2bef41bf19` | calls | symbol | 604 | 604 | 0 | 181 | 50 | 220 | 384 |
| NodeBB/NodeBB | `4b14c05228d2` | imports | file | 2442 | 1002 | 1440 | 709 | 11 | 27 | 975 |
| NodeBB/NodeBB | `4b14c05228d2` | calls | symbol | 1177 | 1177 | 0 | 586 | 170 | 604 | 573 |
| NodeBB/NodeBB | `43d1969f5d5b` | imports | file | 2488 | 1017 | 1471 | 812 | 10 | 28 | 989 |
| NodeBB/NodeBB | `43d1969f5d5b` | calls | symbol | 1129 | 1129 | 0 | 549 | 171 | 612 | 517 |
| NodeBB/NodeBB | `d60aff465833` | imports | file | 2590 | 1092 | 1498 | 900 | 7 | 28 | 1064 |
| NodeBB/NodeBB | `d60aff465833` | calls | symbol | 1201 | 1201 | 0 | 574 | 178 | 670 | 531 |
| NodeBB/NodeBB | `b01273c831ec` | imports | file | 2571 | 1072 | 1499 | 896 | 8 | 28 | 1044 |
| NodeBB/NodeBB | `b01273c831ec` | calls | symbol | 1195 | 1195 | 0 | 571 | 179 | 669 | 526 |
| NodeBB/NodeBB | `55d7a8cefbff` | imports | file | 2496 | 1017 | 1479 | 833 | 10 | 26 | 991 |
| NodeBB/NodeBB | `55d7a8cefbff` | calls | symbol | 1140 | 1140 | 0 | 554 | 170 | 616 | 524 |
| NodeBB/NodeBB | `8d83c9906172` | imports | file | 2495 | 1017 | 1478 | 818 | 12 | 32 | 985 |
| NodeBB/NodeBB | `8d83c9906172` | calls | symbol | 1140 | 1140 | 0 | 556 | 171 | 616 | 524 |
| NodeBB/NodeBB | `d13b9c7923b4` | imports | file | 2425 | 989 | 1436 | 792 | 9 | 27 | 962 |
| NodeBB/NodeBB | `d13b9c7923b4` | calls | symbol | 1137 | 1137 | 0 | 561 | 167 | 596 | 541 |
| NodeBB/NodeBB | `0a4d2c8aacbb` | imports | file | 2758 | 1309 | 1449 | 1195 | 10 | 19 | 1290 |
| NodeBB/NodeBB | `0a4d2c8aacbb` | calls | symbol | 1551 | 1551 | 0 | 707 | 193 | 805 | 746 |
| NodeBB/NodeBB | `29e9da075af8` | imports | file | 2519 | 1035 | 1484 | 867 | 5 | 22 | 1013 |
| NodeBB/NodeBB | `29e9da075af8` | calls | symbol | 1210 | 1210 | 0 | 582 | 175 | 663 | 547 |
| NodeBB/NodeBB | `47676c68fbcc` | imports | file | 2521 | 1024 | 1497 | 837 | 11 | 28 | 996 |
| NodeBB/NodeBB | `47676c68fbcc` | calls | symbol | 1186 | 1186 | 0 | 570 | 173 | 654 | 532 |
| NodeBB/NodeBB | `945252fe6e86` | imports | file | 2802 | 1331 | 1471 | 1186 | 9 | 22 | 1309 |
| NodeBB/NodeBB | `945252fe6e86` | calls | symbol | 1558 | 1558 | 0 | 710 | 193 | 815 | 743 |
| NodeBB/NodeBB | `d81af495867c` | imports | file | 2543 | 1054 | 1489 | 866 | 5 | 21 | 1033 |
| NodeBB/NodeBB | `d81af495867c` | calls | symbol | 1214 | 1214 | 0 | 581 | 177 | 667 | 547 |
| NodeBB/NodeBB | `8037ac6f9244` | imports | file | 2853 | 1330 | 1523 | 1173 | 9 | 24 | 1306 |
| NodeBB/NodeBB | `8037ac6f9244` | calls | symbol | 1555 | 1555 | 0 | 712 | 195 | 809 | 746 |
| NodeBB/NodeBB | `cb161a51dc34` | imports | file | 2619 | 1090 | 1529 | 906 | 7 | 23 | 1067 |
| NodeBB/NodeBB | `cb161a51dc34` | calls | symbol | 1429 | 1429 | 0 | 658 | 181 | 748 | 681 |
| NodeBB/NodeBB | `bb174a00f112` | imports | file | 2459 | 1008 | 1451 | 804 | 12 | 32 | 976 |
| NodeBB/NodeBB | `bb174a00f112` | calls | symbol | 1181 | 1181 | 0 | 585 | 169 | 610 | 571 |
| NodeBB/NodeBB | `72a6fb2a39b8` | imports | file | 2675 | 1113 | 1562 | 879 | 7 | 22 | 1091 |
| NodeBB/NodeBB | `72a6fb2a39b8` | calls | symbol | 1482 | 1482 | 0 | 681 | 186 | 767 | 715 |
| NodeBB/NodeBB | `962ea6c586b0` | imports | file | 2459 | 1008 | 1451 | 825 | 10 | 28 | 980 |
| NodeBB/NodeBB | `962ea6c586b0` | calls | symbol | 1184 | 1184 | 0 | 585 | 169 | 613 | 571 |
| NodeBB/NodeBB | `f73daccf345e` | imports | file | 2460 | 1009 | 1451 | 831 | 11 | 25 | 984 |
| NodeBB/NodeBB | `f73daccf345e` | calls | symbol | 1184 | 1184 | 0 | 586 | 169 | 613 | 571 |
| NodeBB/NodeBB | `f4f3fb7417a2` | imports | file | 3003 | 1414 | 1589 | 1313 | 11 | 20 | 1394 |
| NodeBB/NodeBB | `f4f3fb7417a2` | calls | symbol | 1592 | 1592 | 0 | 731 | 197 | 828 | 764 |
| NodeBB/NodeBB | `2d10a775f968` | imports | file | 2804 | 1331 | 1473 | 1178 | 10 | 25 | 1306 |
| NodeBB/NodeBB | `2d10a775f968` | calls | symbol | 1558 | 1558 | 0 | 709 | 193 | 815 | 743 |
| NodeBB/NodeBB | `ee4256c77f74` | imports | file | 2856 | 1330 | 1526 | 1168 | 11 | 25 | 1305 |
| NodeBB/NodeBB | `ee4256c77f74` | calls | symbol | 1556 | 1556 | 0 | 713 | 196 | 810 | 746 |
| NodeBB/NodeBB | `c39f4787c4aa` | imports | file | 2619 | 1090 | 1529 | 875 | 6 | 26 | 1064 |
| NodeBB/NodeBB | `c39f4787c4aa` | calls | symbol | 1429 | 1429 | 0 | 657 | 181 | 748 | 681 |
| axios/axios | `1e44a1c45ec4` | imports | file | 140 | 70 | 70 | 50 | 1 | 1 | 69 |
| axios/axios | `1e44a1c45ec4` | calls | symbol | 220 | 220 | 0 | 39 | 19 | 191 | 29 |
| axios/axios | `af4495290bbc` | imports | file | 163 | 85 | 78 | 63 | 1 | 1 | 84 |
| axios/axios | `af4495290bbc` | calls | symbol | 548 | 548 | 0 | 34 | 24 | 532 | 16 |
| element-hq/element-web | `2ad7fd77595b` | imports | file | 4099 | 3577 | 522 | 3349 | 37 | 46 | 3531 |
| element-hq/element-web | `2ad7fd77595b` | calls | symbol | 6550 | 6550 | 0 | 2387 | 392 | 2626 | 3924 |
| element-hq/element-web | `ea7c1240175d` | imports | file | 4274 | 3730 | 544 | 3452 | 44 | 63 | 3667 |
| element-hq/element-web | `ea7c1240175d` | calls | symbol | 6595 | 6595 | 0 | 2388 | 400 | 2696 | 3899 |
| facebook/docusaurus | `19fa623c87d7` | imports | file | 647 | 474 | 173 | 405 | 44 | 53 | 421 |
| facebook/docusaurus | `19fa623c87d7` | calls | symbol | 5863 | 5863 | 0 | 1138 | 258 | 4464 | 1399 |
| facebook/docusaurus | `b9dd309ede37` | imports | file | 647 | 479 | 168 | 409 | 51 | 64 | 415 |
| facebook/docusaurus | `b9dd309ede37` | calls | symbol | 5940 | 5940 | 0 | 1160 | 261 | 4510 | 1430 |
| facebook/docusaurus | `bc01d02e8d9b` | imports | file | 605 | 438 | 167 | 370 | 43 | 54 | 384 |
| facebook/docusaurus | `bc01d02e8d9b` | calls | symbol | 5728 | 5728 | 0 | 1076 | 241 | 4391 | 1337 |
| immutable-js/immutable-js | `f0d3c13774ad` | imports | file | 351 | 274 | 77 | 251 | 7 | 9 | 265 |
| immutable-js/immutable-js | `f0d3c13774ad` | calls | symbol | 793 | 793 | 0 | 186 | 38 | 404 | 389 |
| immutable-js/immutable-js | `975db8fff535` | imports | file | 358 | 278 | 80 | 262 | 8 | 10 | 268 |
| immutable-js/immutable-js | `975db8fff535` | calls | symbol | 799 | 799 | 0 | 189 | 37 | 406 | 393 |
| preactjs/preact | `7dcd08c6dcd8` | imports | file | 219 | 182 | 37 | 169 | 7 | 11 | 171 |
| preactjs/preact | `7dcd08c6dcd8` | calls | symbol | 660 | 660 | 0 | 200 | 58 | 247 | 413 |
| preactjs/preact | `80b1792c5480` | imports | file | 225 | 188 | 37 | 178 | 8 | 12 | 176 |
| preactjs/preact | `80b1792c5480` | calls | symbol | 696 | 696 | 0 | 210 | 61 | 259 | 437 |
| preactjs/preact | `4fdaac70f418` | imports | file | 229 | 189 | 40 | 176 | 9 | 12 | 177 |
| preactjs/preact | `4fdaac70f418` | calls | symbol | 734 | 734 | 0 | 218 | 61 | 261 | 473 |
| preactjs/preact | `1044506ddb44` | imports | file | 231 | 191 | 40 | 175 | 9 | 11 | 180 |
| preactjs/preact | `1044506ddb44` | calls | symbol | 745 | 745 | 0 | 221 | 63 | 264 | 481 |
| preactjs/preact | `197d5a4deb6c` | imports | file | 232 | 192 | 40 | 178 | 11 | 15 | 177 |
| preactjs/preact | `197d5a4deb6c` | calls | symbol | 779 | 779 | 0 | 225 | 63 | 267 | 512 |
| preactjs/preact | `69e49acea349` | imports | file | 233 | 193 | 40 | 179 | 8 | 13 | 180 |
| preactjs/preact | `69e49acea349` | calls | symbol | 801 | 801 | 0 | 225 | 64 | 275 | 526 |
| preactjs/preact | `8708b4d618d6` | imports | file | 233 | 193 | 40 | 179 | 8 | 11 | 182 |
| preactjs/preact | `8708b4d618d6` | calls | symbol | 808 | 808 | 0 | 230 | 65 | 272 | 536 |
| preactjs/preact | `000365e13105` | imports | file | 239 | 200 | 39 | 186 | 8 | 12 | 188 |
| preactjs/preact | `000365e13105` | calls | symbol | 873 | 873 | 0 | 246 | 70 | 295 | 578 |
| preactjs/preact | `c1e88c310b4d` | imports | file | 241 | 201 | 40 | 187 | 8 | 12 | 189 |
| preactjs/preact | `c1e88c310b4d` | calls | symbol | 947 | 947 | 0 | 263 | 71 | 316 | 631 |
| preactjs/preact | `409e2753ea0d` | imports | file | 249 | 205 | 44 | 192 | 9 | 14 | 191 |
| preactjs/preact | `409e2753ea0d` | calls | symbol | 967 | 967 | 0 | 271 | 72 | 316 | 651 |
| protonmail/webclients | `e79874736660` | imports | file | 9257 | 5331 | 3926 | 4185 | 229 | 363 | 4968 |
| protonmail/webclients | `e79874736660` | calls | symbol | 17415 | 17415 | 0 | 9664 | 1039 | 4059 | 13356 |
| tutao/tutanota | `38cc6652f983` | imports | file | 3780 | 3211 | 569 | 2997 | 27 | 38 | 3173 |
| tutao/tutanota | `38cc6652f983` | calls | symbol | 13017 | 13017 | 0 | 4072 | 473 | 5275 | 7742 |
| tutao/tutanota | `6fa65b34fcfd` | imports | file | 3639 | 3076 | 563 | 2898 | 26 | 32 | 3044 |
| tutao/tutanota | `6fa65b34fcfd` | calls | symbol | 13529 | 13529 | 0 | 4257 | 494 | 5418 | 8111 |
| tutao/tutanota | `1b1bc8349e39` | imports | file | 3688 | 3116 | 572 | 2948 | 26 | 34 | 3082 |
| tutao/tutanota | `1b1bc8349e39` | calls | symbol | 13523 | 13523 | 0 | 4204 | 486 | 5449 | 8074 |
| vuejs/core | `96c87d888005` | imports | file | 1177 | 1007 | 170 | 893 | 28 | 35 | 972 |
| vuejs/core | `96c87d888005` | calls | symbol | 4594 | 4594 | 0 | 1123 | 166 | 1641 | 2953 |
| vuejs/core | `9335add06b4a` | imports | file | 1184 | 1011 | 173 | 919 | 26 | 34 | 977 |
| vuejs/core | `9335add06b4a` | calls | symbol | 4605 | 4605 | 0 | 1130 | 163 | 1647 | 2958 |
| vuejs/core | `3b5f437f41ce` | imports | file | 1185 | 1012 | 173 | 899 | 29 | 36 | 976 |
| vuejs/core | `3b5f437f41ce` | calls | symbol | 4641 | 4641 | 0 | 1138 | 167 | 1648 | 2993 |
| vuejs/core | `678f8ed4bfb9` | imports | file | 1186 | 1012 | 174 | 891 | 28 | 35 | 977 |
| vuejs/core | `678f8ed4bfb9` | calls | symbol | 4642 | 4642 | 0 | 1134 | 165 | 1652 | 2990 |

**Heaviest cross-family edges**

| repository | relation | source family | target family | multiplicity | first contributing exact edge |
|---|---|---|---|---:|---|
| preactjs/preact | calls | 25 `compat/test/browser/portals.test.js` | 10 `compat/src/portals.js` | 18 | `compat/test/browser/portals.test.js#Foo` -> `compat/src/portals.js#createPortal` |
| preactjs/preact | calls | 86 `hooks/test/browser/combinations.test.js` | 84 `hooks/src/index.js` | 18 | `hooks/test/browser/combinations.test.js#Parent` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 111 `test-utils/test/shared/act.test.js` | 84 `hooks/src/index.js` | 17 | `test-utils/test/shared/act.test.js#StateContainer` -> `hooks/src/index.js#useEffect` |
| preactjs/preact | calls | 94 `hooks/test/browser/useLayoutEffect.test.js` | 84 `hooks/src/index.js` | 16 | `hooks/test/browser/useLayoutEffect.test.js#Comp` -> `hooks/src/index.js#useLayoutEffect` |
| preactjs/preact | calls | 18 `test/_util` | 84 `hooks/src/index.js` | 14 | `debug/test/browser/debug.options.test.js#HookApp` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 25 `compat/test/browser/portals.test.js` | 84 `hooks/src/index.js` | 14 | `compat/test/browser/portals.test.js#Foo` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 89 `hooks/test/browser/useContext.test.js` | 84 `hooks/src/index.js` | 14 | `hooks/test/browser/useContext.test.js#Comp` -> `hooks/src/index.js#useContext` |
| preactjs/preact | calls | 93 `hooks/test/browser/useImperativeHandle.test.js` | 84 `hooks/src/index.js` | 14 | `hooks/test/browser/useImperativeHandle.test.js#Comp` -> `hooks/src/index.js#useRef` |
| NodeBB/NodeBB | imports | 158 `src/controllers` | 254 `src` | 11 | `src/controllers/404.js` -> `src/meta/index.js` |
| NodeBB/NodeBB | imports | 181 `src/groups` | 254 `src` | 8 | `src/groups/create.js` -> `src/meta/index.js` |
| NodeBB/NodeBB | imports | 189 `src/messaging` | 254 `src` | 8 | `src/messaging/data.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 299 `src` | 254 `src` | 8 | `src/categories/index.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 232 `src/privileges` | 254 `src` | 7 | `src/privileges/global.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 213 `src/plugins` | 158 `src/controllers` | 6 | `src/controllers/index.js` -> `src/controllers/404.js` |
| NodeBB/NodeBB | imports | 299 `src` | 181 `src/groups` | 6 | `src/groups/index.js` -> `src/groups/create.js` |
| NodeBB/NodeBB | calls | 199 `src/meta/minifier.js` | 110 `public/src/modules/topicThumbs.js` | 6 | `src/meta/minifier.js#forkAction` -> `public/src/modules/topicThumbs.js#callback` |
| NodeBB/NodeBB | imports | 191 `src/messaging` | 259 `src` | 9 | `src/messaging/data.js` -> `src/user/index.js` |
| NodeBB/NodeBB | imports | 304 `src` | 259 `src` | 8 | `src/categories/index.js` -> `src/meta/index.js` |
| NodeBB/NodeBB | imports | 159 `src/controllers` | 259 `src` | 7 | `src/controllers/404.js` -> `src/meta/index.js` |
| NodeBB/NodeBB | imports | 259 `src` | 304 `src` | 7 | `src/meta/index.js` -> `src/groups/index.js` |
| NodeBB/NodeBB | imports | 215 `src/plugins` | 159 `src/controllers` | 6 | `src/controllers/index.js` -> `src/controllers/404.js` |
| NodeBB/NodeBB | imports | 304 `src` | 183 `src/groups` | 5 | `src/groups/index.js` -> `src/groups/create.js` |
| NodeBB/NodeBB | calls | 10 `public/src/admin/extend/widgets.js` | 21 `public/src/admin/modules/search.js` | 5 | `public/src/admin/extend/widgets.js#saveWidgets` -> `public/src/admin/modules/search.js#find` |
| NodeBB/NodeBB | calls | 135 `src/cli/reset.js` | 133 `src/cli/manage.js` | 5 | `src/cli/reset.js#resetSettings` -> `src/cli/manage.js#info` |
| NodeBB/NodeBB | imports | 327 `src/categories` | 198 `src/messaging` | 15 | `src/categories/index.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 327 `src/categories` | 187 `src` | 8 | `src/categories/index.js` -> `src/meta/index.js` |
| NodeBB/NodeBB | imports | 198 `src/messaging` | 327 `src/categories` | 6 | `src/plugins/index.js` -> `src/controllers/index.js` |
| NodeBB/NodeBB | calls | 139 `src/cli/manage.js` | 145 `src/cli/user.js` | 6 | `src/cli/manage.js#install` -> `src/cli/user.js#init` |
| NodeBB/NodeBB | imports | 167 `src/controllers` | 198 `src/messaging` | 5 | `src/controllers/404.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 190 `src/groups` | 198 `src/messaging` | 5 | `src/groups/create.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 198 `src/messaging` | 187 `src` | 5 | `src/messaging/edit.js` -> `src/meta/index.js` |
| NodeBB/NodeBB | imports | 327 `src/categories` | 167 `src/controllers` | 5 | `src/controllers/index.js` -> `src/controllers/404.js` |
| NodeBB/NodeBB | imports | 322 `src/categories` | 195 `src/messaging` | 9 | `src/categories/index.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 188 `src/groups` | 195 `src/messaging` | 7 | `src/groups/create.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 305 `src` | 188 `src/groups` | 6 | `src/groups/index.js` -> `src/groups/create.js` |
| NodeBB/NodeBB | imports | 305 `src` | 195 `src/messaging` | 6 | `src/groups/index.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 164 `src/controllers` | 195 `src/messaging` | 5 | `src/controllers/404.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 195 `src/messaging` | 185 `src` | 5 | `src/messaging/edit.js` -> `src/meta/index.js` |
| NodeBB/NodeBB | imports | 322 `src/categories` | 164 `src/controllers` | 5 | `src/controllers/index.js` -> `src/controllers/404.js` |
| NodeBB/NodeBB | imports | 322 `src/categories` | 185 `src` | 5 | `src/categories/index.js` -> `src/meta/index.js` |
| NodeBB/NodeBB | imports | 193 `src/messaging` | 258 `src` | 9 | `src/messaging/data.js` -> `src/user/index.js` |
| NodeBB/NodeBB | imports | 161 `src/controllers` | 258 `src` | 7 | `src/controllers/404.js` -> `src/meta/index.js` |
| NodeBB/NodeBB | imports | 320 `src` | 258 `src` | 7 | `src/categories/index.js` -> `src/meta/index.js` |
| NodeBB/NodeBB | imports | 217 `src/plugins` | 161 `src/controllers` | 6 | `src/controllers/index.js` -> `src/controllers/404.js` |
| NodeBB/NodeBB | imports | 303 `src` | 185 `src/groups` | 6 | `src/groups/index.js` -> `src/groups/create.js` |
| NodeBB/NodeBB | imports | 303 `src` | 258 `src` | 6 | `src/groups/index.js` -> `src/user/index.js` |
| NodeBB/NodeBB | imports | 258 `src` | 303 `src` | 5 | `src/meta/index.js` -> `src/groups/index.js` |
| NodeBB/NodeBB | calls | 10 `public/src/admin/extend/widgets.js` | 21 `public/src/admin/modules/search.js` | 5 | `public/src/admin/extend/widgets.js#saveWidgets` -> `public/src/admin/modules/search.js#find` |
| NodeBB/NodeBB | imports | 190 `src/messaging` | 257 `src` | 9 | `src/messaging/data.js` -> `src/user/index.js` |
| NodeBB/NodeBB | imports | 158 `src/controllers` | 257 `src` | 7 | `src/controllers/404.js` -> `src/meta/index.js` |
| NodeBB/NodeBB | imports | 318 `src` | 257 `src` | 7 | `src/categories/index.js` -> `src/meta/index.js` |
| NodeBB/NodeBB | imports | 214 `src/plugins` | 158 `src/controllers` | 6 | `src/controllers/index.js` -> `src/controllers/404.js` |
| NodeBB/NodeBB | imports | 302 `src` | 257 `src` | 6 | `src/groups/index.js` -> `src/user/index.js` |
| NodeBB/NodeBB | imports | 324 `test` | 257 `src` | 6 | `test/authentication.js` -> `src/meta/index.js` |
| NodeBB/NodeBB | imports | 257 `src` | 302 `src` | 5 | `src/meta/index.js` -> `src/groups/index.js` |
| NodeBB/NodeBB | imports | 302 `src` | 181 `src/groups` | 5 | `src/groups/index.js` -> `src/groups/create.js` |
| NodeBB/NodeBB | imports | 188 `src/messaging` | 257 `src` | 9 | `src/messaging/data.js` -> `src/user/index.js` |
| NodeBB/NodeBB | imports | 156 `src/controllers` | 257 `src` | 7 | `src/controllers/404.js` -> `src/meta/index.js` |
| NodeBB/NodeBB | imports | 212 `src/plugins` | 156 `src/controllers` | 6 | `src/controllers/index.js` -> `src/controllers/404.js` |
| NodeBB/NodeBB | imports | 257 `src` | 297 `src` | 6 | `src/meta/index.js` -> `src/groups/index.js` |
| NodeBB/NodeBB | calls | 198 `src/meta/minifier.js` | 109 `public/src/modules/topicThumbs.js` | 6 | `src/meta/minifier.js#forkAction` -> `public/src/modules/topicThumbs.js#callback` |
| NodeBB/NodeBB | imports | 297 `src` | 180 `src/groups` | 5 | `src/groups/index.js` -> `src/groups/create.js` |
| NodeBB/NodeBB | imports | 297 `src` | 257 `src` | 5 | `src/categories/index.js` -> `src/user/index.js` |
| NodeBB/NodeBB | calls | 10 `public/src/admin/extend/widgets.js` | 21 `public/src/admin/modules/search.js` | 5 | `public/src/admin/extend/widgets.js#saveWidgets` -> `public/src/admin/modules/search.js#find` |
| NodeBB/NodeBB | calls | 106 `public/src/modules/navigator.js` | 25 `public/src/admin/modules/search.js` | 10 | `public/src/modules/navigator.js#gotoMyNextPost` -> `public/src/admin/modules/search.js#find` |
| NodeBB/NodeBB | imports | 276 `src` | 212 `src/messaging` | 7 | `src/messaging/index.js` -> `src/groups/index.js` |
| NodeBB/NodeBB | imports | 186 `src` | 181 `src/controllers` | 6 | `src/controllers/index.js` -> `src/controllers/composer.js` |
| NodeBB/NodeBB | calls | 13 `public/src/admin/extend/widgets.js` | 25 `public/src/admin/modules/search.js` | 6 | `public/src/admin/extend/widgets.js#prepareWidgets` -> `public/src/admin/modules/search.js#find` |
| NodeBB/NodeBB | imports | 202 `src/groups` | 329 `src` | 5 | `src/groups/create.js` -> `src/database/index.js` |
| NodeBB/NodeBB | imports | 212 `src/messaging` | 202 `src/groups` | 5 | `src/groups/index.js` -> `src/groups/create.js` |
| NodeBB/NodeBB | imports | 276 `src` | 329 `src` | 5 | `src/messaging/index.js` -> `src/database/index.js` |
| NodeBB/NodeBB | calls | 2 `install/web.js` | 91 `public/src/modules/alerts.js` | 5 | `install/web.js#testDatabase` -> `public/src/modules/alerts.js#close` |
| NodeBB/NodeBB | imports | 320 `src/categories` | 194 `src/messaging` | 9 | `src/categories/index.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 304 `src` | 194 `src/messaging` | 6 | `src/groups/index.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 162 `src/controllers` | 194 `src/messaging` | 5 | `src/controllers/404.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 185 `src/groups` | 194 `src/messaging` | 5 | `src/groups/create.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 194 `src/messaging` | 183 `src` | 5 | `src/messaging/edit.js` -> `src/meta/index.js` |
| NodeBB/NodeBB | imports | 304 `src` | 185 `src/groups` | 5 | `src/groups/index.js` -> `src/groups/create.js` |
| NodeBB/NodeBB | imports | 320 `src/categories` | 162 `src/controllers` | 5 | `src/controllers/index.js` -> `src/controllers/404.js` |
| NodeBB/NodeBB | imports | 320 `src/categories` | 183 `src` | 5 | `src/categories/index.js` -> `src/meta/index.js` |
| NodeBB/NodeBB | imports | 193 `src/messaging` | 258 `src` | 9 | `src/messaging/data.js` -> `src/user/index.js` |
| NodeBB/NodeBB | imports | 160 `src/controllers` | 258 `src` | 6 | `src/controllers/404.js` -> `src/meta/index.js` |
| NodeBB/NodeBB | imports | 258 `src` | 305 `src` | 6 | `src/meta/index.js` -> `src/groups/index.js` |
| NodeBB/NodeBB | imports | 305 `src` | 258 `src` | 6 | `src/groups/index.js` -> `src/user/index.js` |
| NodeBB/NodeBB | imports | 320 `src` | 258 `src` | 6 | `src/categories/index.js` -> `src/meta/index.js` |
| NodeBB/NodeBB | imports | 216 `src/plugins` | 160 `src/controllers` | 5 | `src/controllers/index.js` -> `src/controllers/404.js` |
| NodeBB/NodeBB | imports | 305 `src` | 185 `src/groups` | 5 | `src/groups/index.js` -> `src/groups/create.js` |
| NodeBB/NodeBB | calls | 10 `public/src/admin/extend/widgets.js` | 21 `public/src/admin/modules/search.js` | 5 | `public/src/admin/extend/widgets.js#saveWidgets` -> `public/src/admin/modules/search.js#find` |
| NodeBB/NodeBB | calls | 108 `public/src/modules/navigator.js` | 25 `public/src/admin/modules/search.js` | 10 | `public/src/modules/navigator.js#gotoMyNextPost` -> `public/src/admin/modules/search.js#find` |
| NodeBB/NodeBB | imports | 189 `src` | 184 `src/controllers` | 6 | `src/controllers/index.js` -> `src/controllers/composer.js` |
| NodeBB/NodeBB | calls | 13 `public/src/admin/extend/widgets.js` | 25 `public/src/admin/modules/search.js` | 6 | `public/src/admin/extend/widgets.js#prepareWidgets` -> `public/src/admin/modules/search.js#find` |
| NodeBB/NodeBB | imports | 208 `src/groups` | 150 `src/categories` | 5 | `src/groups/delete.js` -> `src/database/index.js` |
| NodeBB/NodeBB | imports | 216 `src/messaging` | 208 `src/groups` | 5 | `src/groups/index.js` -> `src/groups/delete.js` |
| NodeBB/NodeBB | imports | 216 `src/messaging` | 269 `src/routes/write` | 5 | `src/groups/index.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | calls | 2 `install/web.js` | 93 `public/src/modules/alerts.js` | 5 | `install/web.js#testDatabase` -> `public/src/modules/alerts.js#close` |
| NodeBB/NodeBB | calls | 68 `public/src/client/search.js` | 25 `public/src/admin/modules/search.js` | 5 | `public/src/client/search.js#getSearchDataFromDOM` -> `public/src/admin/modules/search.js#find` |
| NodeBB/NodeBB | imports | 324 `src/categories` | 195 `src/messaging` | 13 | `src/categories/index.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 324 `src/categories` | 246 `src/routes/write` | 8 | `src/categories/index.js` -> `src/meta/index.js` |
| NodeBB/NodeBB | imports | 195 `src/messaging` | 324 `src/categories` | 6 | `src/plugins/index.js` -> `src/controllers/index.js` |
| NodeBB/NodeBB | imports | 163 `src/controllers` | 195 `src/messaging` | 5 | `src/controllers/404.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 187 `src/groups` | 195 `src/messaging` | 5 | `src/groups/create.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 195 `src/messaging` | 246 `src/routes/write` | 5 | `src/messaging/edit.js` -> `src/meta/index.js` |
| NodeBB/NodeBB | imports | 324 `src/categories` | 163 `src/controllers` | 5 | `src/controllers/index.js` -> `src/controllers/404.js` |
| NodeBB/NodeBB | imports | 324 `src/categories` | 187 `src/groups` | 5 | `src/groups/index.js` -> `src/groups/create.js` |
| NodeBB/NodeBB | calls | 106 `public/src/modules/navigator.js` | 25 `public/src/admin/modules/search.js` | 10 | `public/src/modules/navigator.js#gotoMyNextPost` -> `public/src/admin/modules/search.js#find` |
| NodeBB/NodeBB | imports | 190 `src` | 185 `src/controllers` | 6 | `src/controllers/index.js` -> `src/controllers/composer.js` |
| NodeBB/NodeBB | imports | 206 `src/groups` | 331 `src` | 6 | `src/groups/create.js` -> `src/database/index.js` |
| NodeBB/NodeBB | imports | 215 `src/messaging` | 206 `src/groups` | 6 | `src/groups/index.js` -> `src/groups/create.js` |
| NodeBB/NodeBB | calls | 13 `public/src/admin/extend/widgets.js` | 25 `public/src/admin/modules/search.js` | 6 | `public/src/admin/extend/widgets.js#prepareWidgets` -> `public/src/admin/modules/search.js#find` |
| NodeBB/NodeBB | imports | 215 `src/messaging` | 267 `src` | 5 | `src/groups/index.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 348 `src` | 331 `src` | 5 | `src/categories/index.js` -> `src/database/index.js` |
| NodeBB/NodeBB | calls | 2 `install/web.js` | 91 `public/src/modules/alerts.js` | 5 | `install/web.js#testDatabase` -> `public/src/modules/alerts.js#close` |
| NodeBB/NodeBB | calls | 97 `public/src/modules/navigator.js` | 23 `public/src/admin/modules/search.js` | 10 | `public/src/modules/navigator.js#gotoMyNextPost` -> `public/src/admin/modules/search.js#find` |
| NodeBB/NodeBB | imports | 171 `src/controllers` | 200 `src/messaging` | 7 | `src/controllers/404.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 176 `src` | 171 `src/controllers` | 7 | `src/controllers/index.js` -> `src/controllers/404.js` |
| NodeBB/NodeBB | imports | 192 `src/groups` | 200 `src/messaging` | 7 | `src/groups/create.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 207 `src/meta` | 192 `src/groups` | 6 | `src/groups/index.js` -> `src/groups/create.js` |
| NodeBB/NodeBB | imports | 152 `src/controllers` | 200 `src/messaging` | 5 | `src/controllers/accounts/edit.js` -> `src/user/index.js` |
| NodeBB/NodeBB | imports | 176 `src` | 200 `src/messaging` | 5 | `src/controllers/index.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 200 `src/messaging` | 190 `src` | 5 | `src/messaging/edit.js` -> `src/meta/index.js` |
| NodeBB/NodeBB | imports | 190 `src/messaging` | 255 `src` | 9 | `src/messaging/data.js` -> `src/user/index.js` |
| NodeBB/NodeBB | imports | 158 `src/controllers` | 255 `src` | 7 | `src/controllers/404.js` -> `src/meta/index.js` |
| NodeBB/NodeBB | imports | 127 `src/categories` | 183 `src/groups` | 6 | `src/groups/index.js` -> `src/groups/create.js` |
| NodeBB/NodeBB | imports | 214 `src/plugins` | 158 `src/controllers` | 6 | `src/controllers/index.js` -> `src/controllers/404.js` |
| NodeBB/NodeBB | calls | 200 `src/meta/minifier.js` | 110 `public/src/modules/topicThumbs.js` | 6 | `src/meta/minifier.js#forkAction` -> `public/src/modules/topicThumbs.js#callback` |
| NodeBB/NodeBB | calls | 10 `public/src/admin/extend/widgets.js` | 21 `public/src/admin/modules/search.js` | 5 | `public/src/admin/extend/widgets.js#saveWidgets` -> `public/src/admin/modules/search.js#find` |
| NodeBB/NodeBB | calls | 17 `public/src/admin/manage/tags.js` | 324 `test/posts.js` | 5 | `public/src/admin/manage/tags.js#handleCreate` -> `test/posts.js#emit` |
| NodeBB/NodeBB | calls | 135 `src/cli/reset.js` | 133 `src/cli/manage.js` | 5 | `src/cli/reset.js#resetSettings` -> `src/cli/manage.js#info` |
| NodeBB/NodeBB | imports | 174 `src/controllers` | 265 `src` | 10 | `src/controllers/404.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | calls | 100 `public/src/modules/navigator.js` | 23 `public/src/admin/modules/search.js` | 10 | `public/src/modules/navigator.js#gotoMyNextPost` -> `public/src/admin/modules/search.js#find` |
| NodeBB/NodeBB | imports | 179 `src` | 174 `src/controllers` | 9 | `src/controllers/index.js` -> `src/controllers/404.js` |
| NodeBB/NodeBB | imports | 196 `src/groups` | 265 `src` | 8 | `src/groups/create.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 203 `src/messaging` | 265 `src` | 7 | `src/messaging/data.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 318 `src` | 265 `src` | 7 | `src/categories/index.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 265 `src` | 196 `src/groups` | 6 | `src/groups/index.js` -> `src/groups/create.js` |
| NodeBB/NodeBB | imports | 179 `src` | 265 `src` | 5 | `src/controllers/index.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 189 `src/messaging` | 256 `src` | 9 | `src/messaging/data.js` -> `src/user/index.js` |
| NodeBB/NodeBB | imports | 158 `src/controllers` | 256 `src` | 7 | `src/controllers/404.js` -> `src/meta/index.js` |
| NodeBB/NodeBB | imports | 213 `src/plugins` | 158 `src/controllers` | 6 | `src/controllers/index.js` -> `src/controllers/404.js` |
| NodeBB/NodeBB | imports | 298 `src` | 181 `src/groups` | 6 | `src/groups/index.js` -> `src/groups/create.js` |
| NodeBB/NodeBB | imports | 315 `src` | 256 `src` | 6 | `src/categories/index.js` -> `src/user/index.js` |
| NodeBB/NodeBB | calls | 199 `src/meta/minifier.js` | 110 `public/src/modules/topicThumbs.js` | 6 | `src/meta/minifier.js#forkAction` -> `public/src/modules/topicThumbs.js#callback` |
| NodeBB/NodeBB | calls | 10 `public/src/admin/extend/widgets.js` | 21 `public/src/admin/modules/search.js` | 5 | `public/src/admin/extend/widgets.js#saveWidgets` -> `public/src/admin/modules/search.js#find` |
| NodeBB/NodeBB | calls | 17 `public/src/admin/manage/tags.js` | 325 `test/posts.js` | 5 | `public/src/admin/manage/tags.js#handleCreate` -> `test/posts.js#emit` |
| NodeBB/NodeBB | imports | 194 `src/messaging` | 259 `src` | 9 | `src/messaging/data.js` -> `src/user/index.js` |
| NodeBB/NodeBB | imports | 160 `src/controllers` | 259 `src` | 7 | `src/controllers/404.js` -> `src/meta/index.js` |
| NodeBB/NodeBB | imports | 218 `src/plugins` | 160 `src/controllers` | 6 | `src/controllers/index.js` -> `src/controllers/404.js` |
| NodeBB/NodeBB | imports | 317 `src` | 259 `src` | 6 | `src/categories/index.js` -> `src/meta/index.js` |
| NodeBB/NodeBB | calls | 204 `src/meta/minifier.js` | 110 `public/src/modules/topicThumbs.js` | 6 | `src/meta/minifier.js#forkAction` -> `public/src/modules/topicThumbs.js#callback` |
| NodeBB/NodeBB | imports | 300 `src` | 186 `src/groups` | 5 | `src/groups/index.js` -> `src/groups/create.js` |
| NodeBB/NodeBB | calls | 10 `public/src/admin/extend/widgets.js` | 21 `public/src/admin/modules/search.js` | 5 | `public/src/admin/extend/widgets.js#saveWidgets` -> `public/src/admin/modules/search.js#find` |
| NodeBB/NodeBB | calls | 17 `public/src/admin/manage/tags.js` | 326 `test/posts.js` | 5 | `public/src/admin/manage/tags.js#handleCreate` -> `test/posts.js#emit` |
| NodeBB/NodeBB | calls | 110 `public/src/modules/navigator.js` | 26 `public/src/admin/modules/search.js` | 10 | `public/src/modules/navigator.js#gotoMyNextPost` -> `public/src/admin/modules/search.js#find` |
| NodeBB/NodeBB | imports | 194 `src` | 189 `src/controllers` | 6 | `src/controllers/index.js` -> `src/controllers/composer.js` |
| NodeBB/NodeBB | calls | 13 `public/src/admin/extend/widgets.js` | 26 `public/src/admin/modules/search.js` | 6 | `public/src/admin/extend/widgets.js#prepareWidgets` -> `public/src/admin/modules/search.js#find` |
| NodeBB/NodeBB | imports | 213 `src/groups` | 156 `src/categories` | 5 | `src/groups/delete.js` -> `src/database/index.js` |
| NodeBB/NodeBB | imports | 221 `src/messaging` | 213 `src/groups` | 5 | `src/groups/index.js` -> `src/groups/delete.js` |
| NodeBB/NodeBB | imports | 221 `src/messaging` | 273 `src` | 5 | `src/groups/index.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | calls | 2 `install/web.js` | 95 `public/src/modules/alerts.js` | 5 | `install/web.js#testDatabase` -> `public/src/modules/alerts.js#close` |
| NodeBB/NodeBB | calls | 69 `public/src/client/search.js` | 26 `public/src/admin/modules/search.js` | 5 | `public/src/client/search.js#getSearchDataFromDOM` -> `public/src/admin/modules/search.js#find` |
| NodeBB/NodeBB | calls | 108 `public/src/modules/navigator.js` | 25 `public/src/admin/modules/search.js` | 10 | `public/src/modules/navigator.js#gotoMyNextPost` -> `public/src/admin/modules/search.js#find` |
| NodeBB/NodeBB | imports | 188 `src` | 183 `src/controllers` | 6 | `src/controllers/index.js` -> `src/controllers/composer.js` |
| NodeBB/NodeBB | calls | 13 `public/src/admin/extend/widgets.js` | 25 `public/src/admin/modules/search.js` | 6 | `public/src/admin/extend/widgets.js#prepareWidgets` -> `public/src/admin/modules/search.js#find` |
| NodeBB/NodeBB | imports | 207 `src/groups` | 333 `src` | 5 | `src/groups/delete.js` -> `src/database/index.js` |
| NodeBB/NodeBB | imports | 215 `src/messaging` | 207 `src/groups` | 5 | `src/groups/index.js` -> `src/groups/delete.js` |
| NodeBB/NodeBB | imports | 215 `src/messaging` | 269 `src` | 5 | `src/groups/index.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 350 `src` | 333 `src` | 5 | `src/categories/index.js` -> `src/database/index.js` |
| NodeBB/NodeBB | calls | 2 `install/web.js` | 93 `public/src/modules/alerts.js` | 5 | `install/web.js#testDatabase` -> `public/src/modules/alerts.js#close` |
| NodeBB/NodeBB | calls | 106 `public/src/modules/navigator.js` | 25 `public/src/admin/modules/search.js` | 10 | `public/src/modules/navigator.js#gotoMyNextPost` -> `public/src/admin/modules/search.js#find` |
| NodeBB/NodeBB | imports | 217 `src/messaging` | 334 `src` | 7 | `src/groups/index.js` -> `src/database/index.js` |
| NodeBB/NodeBB | imports | 209 `src/groups` | 334 `src` | 6 | `src/groups/create.js` -> `src/database/index.js` |
| NodeBB/NodeBB | imports | 217 `src/messaging` | 209 `src/groups` | 6 | `src/groups/index.js` -> `src/groups/create.js` |
| NodeBB/NodeBB | imports | 217 `src/messaging` | 270 `src` | 6 | `src/groups/index.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | calls | 13 `public/src/admin/extend/widgets.js` | 25 `public/src/admin/modules/search.js` | 6 | `public/src/admin/extend/widgets.js#prepareWidgets` -> `public/src/admin/modules/search.js#find` |
| NodeBB/NodeBB | calls | 2 `install/web.js` | 91 `public/src/modules/alerts.js` | 5 | `install/web.js#testDatabase` -> `public/src/modules/alerts.js#close` |
| NodeBB/NodeBB | calls | 67 `public/src/client/search.js` | 25 `public/src/admin/modules/search.js` | 5 | `public/src/client/search.js#getSearchDataFromDOM` -> `public/src/admin/modules/search.js#find` |
| NodeBB/NodeBB | calls | 97 `public/src/modules/navigator.js` | 23 `public/src/admin/modules/search.js` | 10 | `public/src/modules/navigator.js#gotoMyNextPost` -> `public/src/admin/modules/search.js#find` |
| NodeBB/NodeBB | imports | 328 `src/categories` | 191 `src` | 8 | `src/categories/index.js` -> `src/meta/index.js` |
| NodeBB/NodeBB | imports | 176 `src` | 171 `src/controllers` | 7 | `src/controllers/index.js` -> `src/controllers/404.js` |
| NodeBB/NodeBB | imports | 328 `src/categories` | 201 `src/messaging` | 7 | `src/categories/index.js` -> `src/plugins/index.js` |
| NodeBB/NodeBB | imports | 328 `src/categories` | 193 `src/groups` | 6 | `src/groups/index.js` -> `src/groups/create.js` |
| NodeBB/NodeBB | imports | 201 `src/messaging` | 328 `src/categories` | 5 | `src/messaging/data.js` -> `src/user/index.js` |
| NodeBB/NodeBB | calls | 12 `public/src/admin/extend/widgets.js` | 23 `public/src/admin/modules/search.js` | 5 | `public/src/admin/extend/widgets.js#saveWidgets` -> `public/src/admin/modules/search.js#find` |
| NodeBB/NodeBB | calls | 59 `public/src/client/search.js` | 23 `public/src/admin/modules/search.js` | 5 | `public/src/client/search.js#getSearchDataFromDOM` -> `public/src/admin/modules/search.js#find` |
| axios/axios | imports | 5 `lib/adapters/xhr.js` | 8 `lib/cancel` | 5 | `lib/adapters/xhr.js` -> `lib/core/buildFullPath.js` |
| axios/axios | imports | 8 `lib/cancel` | 22 `lib/utils.js` | 4 | `lib/core/transformData.js` -> `lib/utils.js` |
| axios/axios | imports | 17 `test/specs/helpers` | 6 `lib` | 4 | `lib/axios.js` -> `lib/cancel/isCancel.js` |
| axios/axios | imports | 4 `lib/adapters/http.js` | 10 `lib` | 3 | `lib/adapters/http.js` -> `lib/cancel/CanceledError.js` |
| axios/axios | imports | 10 `lib` | 6 `lib` | 3 | `lib/cancel/CanceledError.js` -> `lib/core/AxiosError.js` |
| axios/axios | calls | 0 `dist/axios.js` | 4 `lib/adapters/http.js` | 3 | `dist/axios.js#onloadend` -> `lib/adapters/http.js#resolve` |
| axios/axios | calls | 0 `dist/axios.js` | 21 `lib/platform/browser/classes/URLSearchParams.js` | 3 | `dist/axios.js#buildURL` -> `lib/platform/browser/classes/URLSearchParams.js#toString` |
| axios/axios | calls | 0 `dist/axios.js` | 31 `test/typescript/axios.ts` | 3 | `dist/axios.js#dispatchRequest` -> `test/typescript/axios.ts#adapter` |
| axios/axios | imports | 10 `test/specs/cancel` | 9 `lib` | 5 | `lib/axios.js` -> `lib/cancel/CancelToken.js` |
| axios/axios | imports | 8 `lib/adapters/xhr.js` | 11 `lib/cancel` | 4 | `lib/adapters/xhr.js` -> `lib/helpers/buildURL.js` |
| axios/axios | imports | 9 `lib` | 20 `lib` | 4 | `lib/cancel/CanceledError.js` -> `lib/core/AxiosError.js` |
| axios/axios | imports | 9 `lib` | 30 `lib/utils.js` | 3 | `lib/cancel/CanceledError.js` -> `lib/utils.js` |
| axios/axios | imports | 11 `lib/cancel` | 30 `lib/utils.js` | 3 | `lib/core/transformData.js` -> `lib/utils.js` |
| axios/axios | imports | 19 `test` | 9 `lib` | 3 | `lib/core/dispatchRequest.js` -> `lib/cancel/CanceledError.js` |
| axios/axios | imports | 20 `lib` | 30 `lib/utils.js` | 3 | `lib/adapters/index.js` -> `lib/utils.js` |
| axios/axios | calls | 1 `dist/axios.min.js` | 3 `dist/esm/axios.min.js` | 3 | `dist/axios.min.js#c` -> `dist/esm/axios.min.js#u` |
| element-hq/element-web | calls | 89 `src/components/structures/GroupView.js` | 442 `src/languageHandler.tsx` | 25 | `src/components/structures/GroupView.js#onAddRoomsToSummaryClicked` -> `src/languageHandler.tsx#_t` |
| element-hq/element-web | calls | 165 `src/components/views/dialogs/DevtoolsDialog.js` | 442 `src/languageHandler.tsx` | 23 | `src/components/views/dialogs/DevtoolsDialog.js#_buttons` -> `src/languageHandler.tsx#_t` |
| element-hq/element-web | calls | 41 `src/TextForEvent.js` | 442 `src/languageHandler.tsx` | 21 | `src/TextForEvent.js#textForMemberEvent` -> `src/languageHandler.tsx#_t` |
| element-hq/element-web | calls | 303 `src/components/views/right_panel/UserInfo.tsx` | 442 `src/languageHandler.tsx` | 20 | `src/components/views/right_panel/UserInfo.tsx#DeviceItem` -> `src/languageHandler.tsx#_t` |
| element-hq/element-web | calls | 405 `src/editor/deserialize.ts` | 412 `src/editor/parts.ts` | 18 | `src/editor/deserialize.ts#parseAtRoomMentions` -> `src/editor/parts.ts#split` |
| element-hq/element-web | calls | 522 `src/stores/room-list/previews` | 521 `src/stores/room-list` | 18 | `src/stores/room-list/previews/CallAnswerEventPreview.ts#getTextFor` -> `src/stores/room-list/previews/utils.ts#isSelf` |
| element-hq/element-web | calls | 181 `src/components/views/auth/RegistrationForm.tsx` | 442 `src/languageHandler.tsx` | 16 | `src/components/views/auth/RegistrationForm.tsx#description` -> `src/languageHandler.tsx#_t` |
| element-hq/element-web | calls | 511 `src/stores/room-list/RoomListStore.ts` | 549 `src/utils/MarkedExecution.ts` | 15 | `src/stores/room-list/RoomListStore.ts#makeReady` -> `src/utils/MarkedExecution.ts#mark` |
| element-hq/element-web | calls | 89 `src/components/structures/GroupView.js` | 441 `src/languageHandler.tsx` | 25 | `src/components/structures/GroupView.js#onAddRoomsToSummaryClicked` -> `src/languageHandler.tsx#_t` |
| element-hq/element-web | calls | 164 `src/components/views/dialogs/DevtoolsDialog.js` | 441 `src/languageHandler.tsx` | 23 | `src/components/views/dialogs/DevtoolsDialog.js#_buttons` -> `src/languageHandler.tsx#_t` |
| element-hq/element-web | calls | 44 `src/TextForEvent.js` | 441 `src/languageHandler.tsx` | 21 | `src/TextForEvent.js#textForMemberEvent` -> `src/languageHandler.tsx#_t` |
| element-hq/element-web | calls | 304 `src/components/views/right_panel/UserInfo.tsx` | 441 `src/languageHandler.tsx` | 20 | `src/components/views/right_panel/UserInfo.tsx#DeviceItem` -> `src/languageHandler.tsx#_t` |
| element-hq/element-web | calls | 404 `src/editor/deserialize.ts` | 411 `src/editor/parts.ts` | 18 | `src/editor/deserialize.ts#parseAtRoomMentions` -> `src/editor/parts.ts#split` |
| element-hq/element-web | calls | 522 `src/stores/room-list/previews` | 521 `src/stores/room-list` | 18 | `src/stores/room-list/previews/CallAnswerEventPreview.ts#getTextFor` -> `src/stores/room-list/previews/utils.ts#isSelf` |
| element-hq/element-web | imports | 54 `src` | 57 `src/components/views/elements` | 17 | `src/accessibility/context_menu/ContextMenuButton.tsx` -> `src/components/views/elements/AccessibleButton.tsx` |
| element-hq/element-web | calls | 511 `src/stores/room-list/RoomListStore.ts` | 550 `src/utils/MarkedExecution.ts` | 17 | `src/stores/room-list/RoomListStore.ts#makeReady` -> `src/utils/MarkedExecution.ts#mark` |
| facebook/docusaurus | calls | 21 `jest/vendor/remark-gfm@4.0.0.js` | 24 `jest/vendor/remark@15.0.1.js` | 46 | `jest/vendor/remark-gfm@4.0.0.js#toResult` -> `jest/vendor/remark@15.0.1.js#isArray` |
| facebook/docusaurus | calls | 16 `jest/vendor/@mdx-js__mdx@3.0.0.js` | 24 `jest/vendor/remark@15.0.1.js` | 35 | `jest/vendor/@mdx-js__mdx@3.0.0.js#isArray2` -> `jest/vendor/remark@15.0.1.js#isArray` |
| facebook/docusaurus | calls | 24 `jest/vendor/remark@15.0.1.js` | 16 `jest/vendor/@mdx-js__mdx@3.0.0.js` | 22 | `jest/vendor/remark@15.0.1.js#splice` -> `jest/vendor/@mdx-js__mdx@3.0.0.js#slice` |
| facebook/docusaurus | calls | 22 `jest/vendor/remark-mdx@3.0.0.js` | 16 `jest/vendor/@mdx-js__mdx@3.0.0.js` | 14 | `jest/vendor/remark-mdx@3.0.0.js#"node_modules/acorn/dist/acorn.js"` -> `jest/vendor/@mdx-js__mdx@3.0.0.js#slice` |
| facebook/docusaurus | calls | 22 `jest/vendor/remark-mdx@3.0.0.js` | 24 `jest/vendor/remark@15.0.1.js` | 14 | `jest/vendor/remark-mdx@3.0.0.js#mdxElement` -> `jest/vendor/remark@15.0.1.js#containerPhrasing` |
| facebook/docusaurus | calls | 21 `jest/vendor/remark-gfm@4.0.0.js` | 16 `jest/vendor/@mdx-js__mdx@3.0.0.js` | 13 | `jest/vendor/remark-gfm@4.0.0.js#handler` -> `jest/vendor/@mdx-js__mdx@3.0.0.js#slice` |
| facebook/docusaurus | calls | 521 `packages/docusaurus/src/server/plugins/plugins.ts` | 528 `packages/docusaurus/src/server/plugins/pluginsUtils.ts` | 9 | `packages/docusaurus/src/server/plugins/plugins.ts#executePluginContentLoading` -> `packages/docusaurus/src/server/plugins/pluginsUtils.ts#formatPluginName` |
| facebook/docusaurus | imports | 40 `packages/docusaurus-mdx-loader/src` | 36 `packages/docusaurus-mdx-loader/src` | 8 | `packages/docusaurus-mdx-loader/src/processor.ts` -> `packages/docusaurus-mdx-loader/src/remark/contentTitle/index.ts` |
| facebook/docusaurus | calls | 21 `jest/vendor/remark-gfm@4.0.0.js` | 24 `jest/vendor/remark@15.0.1.js` | 46 | `jest/vendor/remark-gfm@4.0.0.js#toResult` -> `jest/vendor/remark@15.0.1.js#isArray` |
| facebook/docusaurus | calls | 16 `jest/vendor/@mdx-js__mdx@3.0.0.js` | 24 `jest/vendor/remark@15.0.1.js` | 35 | `jest/vendor/@mdx-js__mdx@3.0.0.js#isArray2` -> `jest/vendor/remark@15.0.1.js#isArray` |
| facebook/docusaurus | calls | 24 `jest/vendor/remark@15.0.1.js` | 16 `jest/vendor/@mdx-js__mdx@3.0.0.js` | 22 | `jest/vendor/remark@15.0.1.js#splice` -> `jest/vendor/@mdx-js__mdx@3.0.0.js#slice` |
| facebook/docusaurus | calls | 22 `jest/vendor/remark-mdx@3.0.0.js` | 16 `jest/vendor/@mdx-js__mdx@3.0.0.js` | 14 | `jest/vendor/remark-mdx@3.0.0.js#"node_modules/acorn/dist/acorn.js"` -> `jest/vendor/@mdx-js__mdx@3.0.0.js#slice` |
| facebook/docusaurus | calls | 22 `jest/vendor/remark-mdx@3.0.0.js` | 24 `jest/vendor/remark@15.0.1.js` | 14 | `jest/vendor/remark-mdx@3.0.0.js#mdxElement` -> `jest/vendor/remark@15.0.1.js#containerPhrasing` |
| facebook/docusaurus | calls | 21 `jest/vendor/remark-gfm@4.0.0.js` | 16 `jest/vendor/@mdx-js__mdx@3.0.0.js` | 13 | `jest/vendor/remark-gfm@4.0.0.js#handler` -> `jest/vendor/@mdx-js__mdx@3.0.0.js#slice` |
| facebook/docusaurus | calls | 534 `packages/docusaurus/src/server/plugins/plugins.ts` | 541 `packages/docusaurus/src/server/plugins/pluginsUtils.ts` | 9 | `packages/docusaurus/src/server/plugins/plugins.ts#executePluginContentLoading` -> `packages/docusaurus/src/server/plugins/pluginsUtils.ts#formatPluginName` |
| facebook/docusaurus | calls | 23 `jest/vendor/remark-rehype@11.0.0.js` | 16 `jest/vendor/@mdx-js__mdx@3.0.0.js` | 8 | `jest/vendor/remark-rehype@11.0.0.js#normalizeUri` -> `jest/vendor/@mdx-js__mdx@3.0.0.js#slice` |
| facebook/docusaurus | calls | 20 `jest/vendor/remark-gfm@4.0.0.js` | 23 `jest/vendor/remark@15.0.1.js` | 46 | `jest/vendor/remark-gfm@4.0.0.js#toResult` -> `jest/vendor/remark@15.0.1.js#isArray` |
| facebook/docusaurus | calls | 15 `jest/vendor/@mdx-js__mdx@3.0.0.js` | 23 `jest/vendor/remark@15.0.1.js` | 35 | `jest/vendor/@mdx-js__mdx@3.0.0.js#isArray2` -> `jest/vendor/remark@15.0.1.js#isArray` |
| facebook/docusaurus | calls | 23 `jest/vendor/remark@15.0.1.js` | 15 `jest/vendor/@mdx-js__mdx@3.0.0.js` | 22 | `jest/vendor/remark@15.0.1.js#splice` -> `jest/vendor/@mdx-js__mdx@3.0.0.js#slice` |
| facebook/docusaurus | calls | 21 `jest/vendor/remark-mdx@3.0.0.js` | 15 `jest/vendor/@mdx-js__mdx@3.0.0.js` | 14 | `jest/vendor/remark-mdx@3.0.0.js#"node_modules/acorn/dist/acorn.js"` -> `jest/vendor/@mdx-js__mdx@3.0.0.js#slice` |
| facebook/docusaurus | calls | 21 `jest/vendor/remark-mdx@3.0.0.js` | 23 `jest/vendor/remark@15.0.1.js` | 14 | `jest/vendor/remark-mdx@3.0.0.js#mdxElement` -> `jest/vendor/remark@15.0.1.js#containerPhrasing` |
| facebook/docusaurus | calls | 20 `jest/vendor/remark-gfm@4.0.0.js` | 15 `jest/vendor/@mdx-js__mdx@3.0.0.js` | 13 | `jest/vendor/remark-gfm@4.0.0.js#handler` -> `jest/vendor/@mdx-js__mdx@3.0.0.js#slice` |
| facebook/docusaurus | calls | 22 `jest/vendor/remark-rehype@11.0.0.js` | 15 `jest/vendor/@mdx-js__mdx@3.0.0.js` | 8 | `jest/vendor/remark-rehype@11.0.0.js#normalizeUri` -> `jest/vendor/@mdx-js__mdx@3.0.0.js#slice` |
| facebook/docusaurus | calls | 75 `packages/docusaurus-plugin-content-docs/src/__tests__/index.test.ts` | 84 `packages/docusaurus-plugin-content-docs/src` | 8 | `packages/docusaurus-plugin-content-docs/src/__tests__/index.test.ts#loadSite` -> `packages/docusaurus-plugin-content-docs/src/index.ts#pluginContentDocs` |
| immutable-js/immutable-js | calls | 21 `src/CollectionImpl.js` | 27 `src/Operations.js` | 54 | `src/CollectionImpl.js#concat` -> `src/Operations.js#concatFactory` |
| immutable-js/immutable-js | calls | 27 `src/Operations.js` | 23 `src/Iterator.js` | 17 | `src/Operations.js#__iterator` -> `src/Iterator.js#iteratorValue` |
| immutable-js/immutable-js | calls | 33 `src/Seq.js` | 23 `src/Iterator.js` | 14 | `src/Seq.js#__iterator` -> `src/Iterator.js#iteratorValue` |
| immutable-js/immutable-js | calls | 27 `src/Operations.js` | 59 `src/predicates` | 10 | `src/Operations.js#groupByFactory` -> `src/predicates/isKeyed.js#isKeyed` |
| immutable-js/immutable-js | calls | 108 `website/src/static/getTypeDefs.ts` | 21 `src/CollectionImpl.js` | 9 | `website/src/static/getTypeDefs.ts#addData` -> `src/CollectionImpl.js#forEach` |
| immutable-js/immutable-js | calls | 21 `src/CollectionImpl.js` | 59 `src/predicates` | 8 | `src/CollectionImpl.js#toArray` -> `src/predicates/isKeyed.js#isKeyed` |
| immutable-js/immutable-js | calls | 24 `src/List.js` | 21 `src/CollectionImpl.js` | 8 | `src/List.js#toString` -> `src/CollectionImpl.js#__toString` |
| immutable-js/immutable-js | calls | 24 `src/List.js` | 36 `src/TrieUtils.js` | 7 | `src/List.js#get` -> `src/TrieUtils.js#wrapIndex` |
| immutable-js/immutable-js | calls | 22 `src/CollectionImpl.js` | 28 `src/Operations.js` | 54 | `src/CollectionImpl.js#concat` -> `src/Operations.js#concatFactory` |
| immutable-js/immutable-js | calls | 28 `src/Operations.js` | 24 `src/Iterator.js` | 17 | `src/Operations.js#__iterator` -> `src/Iterator.js#iteratorValue` |
| immutable-js/immutable-js | calls | 34 `src/Seq.js` | 24 `src/Iterator.js` | 14 | `src/Seq.js#__iterator` -> `src/Iterator.js#iteratorValue` |
| immutable-js/immutable-js | calls | 28 `src/Operations.js` | 61 `src/predicates` | 10 | `src/Operations.js#groupByFactory` -> `src/predicates/isKeyed.js#isKeyed` |
| immutable-js/immutable-js | calls | 108 `website/src/static/getTypeDefs.ts` | 22 `src/CollectionImpl.js` | 9 | `website/src/static/getTypeDefs.ts#addData` -> `src/CollectionImpl.js#forEach` |
| immutable-js/immutable-js | calls | 22 `src/CollectionImpl.js` | 61 `src/predicates` | 8 | `src/CollectionImpl.js#toArray` -> `src/predicates/isKeyed.js#isKeyed` |
| immutable-js/immutable-js | calls | 25 `src/List.js` | 22 `src/CollectionImpl.js` | 8 | `src/List.js#toString` -> `src/CollectionImpl.js#__toString` |
| immutable-js/immutable-js | calls | 25 `src/List.js` | 37 `src/TrieUtils.js` | 7 | `src/List.js#get` -> `src/TrieUtils.js#wrapIndex` |
| preactjs/preact | calls | 30 `compat/test/browser/portals.test.js` | 15 `compat/src/portals.js` | 18 | `compat/test/browser/portals.test.js#Foo` -> `compat/src/portals.js#createPortal` |
| preactjs/preact | calls | 93 `hooks/test/browser/combinations.test.js` | 91 `hooks/src/index.js` | 18 | `hooks/test/browser/combinations.test.js#Parent` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 98 `hooks/test/browser/useEffect.test.js` | 91 `hooks/src/index.js` | 18 | `hooks/test/browser/useEffect.test.js#Comp` -> `hooks/src/index.js#useEffect` |
| preactjs/preact | calls | 120 `test-utils/test/shared/act.test.js` | 91 `hooks/src/index.js` | 17 | `test-utils/test/shared/act.test.js#StateContainer` -> `hooks/src/index.js#useEffect` |
| preactjs/preact | calls | 101 `hooks/test/browser/useLayoutEffect.test.js` | 91 `hooks/src/index.js` | 16 | `hooks/test/browser/useLayoutEffect.test.js#Comp` -> `hooks/src/index.js#useLayoutEffect` |
| preactjs/preact | calls | 23 `test/_util` | 91 `hooks/src/index.js` | 14 | `debug/test/browser/debug.options.test.js#HookApp` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 30 `compat/test/browser/portals.test.js` | 91 `hooks/src/index.js` | 14 | `compat/test/browser/portals.test.js#Foo` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 96 `hooks/test/browser/useContext.test.js` | 91 `hooks/src/index.js` | 14 | `hooks/test/browser/useContext.test.js#Comp` -> `hooks/src/index.js#useContext` |
| preactjs/preact | calls | 32 `compat/test/browser/portals.test.js` | 16 `compat/src/portals.js` | 18 | `compat/test/browser/portals.test.js#Foo` -> `compat/src/portals.js#createPortal` |
| preactjs/preact | calls | 98 `hooks/test/browser` | 97 `hooks/src/index.js` | 18 | `hooks/test/browser/useEffect.test.js#Comp` -> `hooks/src/index.js#useEffect` |
| preactjs/preact | calls | 99 `hooks/test/browser/combinations.test.js` | 97 `hooks/src/index.js` | 18 | `hooks/test/browser/combinations.test.js#Parent` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 126 `test-utils/test/shared/act.test.js` | 97 `hooks/src/index.js` | 17 | `test-utils/test/shared/act.test.js#StateContainer` -> `hooks/src/index.js#useEffect` |
| preactjs/preact | calls | 107 `hooks/test/browser/useLayoutEffect.test.js` | 97 `hooks/src/index.js` | 16 | `hooks/test/browser/useLayoutEffect.test.js#Comp` -> `hooks/src/index.js#useLayoutEffect` |
| preactjs/preact | calls | 25 `test/_util` | 97 `hooks/src/index.js` | 14 | `debug/test/browser/debug.options.test.js#HookApp` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 32 `compat/test/browser/portals.test.js` | 97 `hooks/src/index.js` | 14 | `compat/test/browser/portals.test.js#Foo` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 102 `hooks/test/browser/useContext.test.js` | 97 `hooks/src/index.js` | 14 | `hooks/test/browser/useContext.test.js#Comp` -> `hooks/src/index.js#useContext` |
| preactjs/preact | calls | 97 `hooks/test/browser/combinations.test.js` | 95 `hooks/src/index.js` | 23 | `hooks/test/browser/combinations.test.js#Parent` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 102 `hooks/test/browser/useEffect.test.js` | 95 `hooks/src/index.js` | 23 | `hooks/test/browser/useEffect.test.js#Comp` -> `hooks/src/index.js#useEffect` |
| preactjs/preact | calls | 31 `compat/test/browser/portals.test.js` | 16 `compat/src/portals.js` | 20 | `compat/test/browser/portals.test.js#Foo` -> `compat/src/portals.js#createPortal` |
| preactjs/preact | calls | 31 `compat/test/browser/portals.test.js` | 95 `hooks/src/index.js` | 20 | `compat/test/browser/portals.test.js#Foo` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 105 `hooks/test/browser/useLayoutEffect.test.js` | 95 `hooks/src/index.js` | 19 | `hooks/test/browser/useLayoutEffect.test.js#Comp` -> `hooks/src/index.js#useLayoutEffect` |
| preactjs/preact | calls | 127 `test-utils/test/shared/act.test.js` | 95 `hooks/src/index.js` | 17 | `test-utils/test/shared/act.test.js#StateContainer` -> `hooks/src/index.js#useEffect` |
| preactjs/preact | calls | 24 `test/_util` | 95 `hooks/src/index.js` | 14 | `debug/test/browser/debug.options.test.js#HookApp` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 100 `hooks/test/browser/useContext.test.js` | 95 `hooks/src/index.js` | 14 | `hooks/test/browser/useContext.test.js#Comp` -> `hooks/src/index.js#useContext` |
| preactjs/preact | calls | 100 `hooks/test/browser` | 99 `hooks/src/index.js` | 25 | `hooks/test/browser/useEffect.test.js#Comp` -> `hooks/src/index.js#useEffect` |
| preactjs/preact | calls | 101 `hooks/test/browser/combinations.test.js` | 99 `hooks/src/index.js` | 23 | `hooks/test/browser/combinations.test.js#Parent` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 34 `compat/test/browser/portals.test.js` | 18 `compat/src/portals.js` | 21 | `compat/test/browser/portals.test.js#Foo` -> `compat/src/portals.js#createPortal` |
| preactjs/preact | calls | 110 `hooks/test/browser/useLayoutEffect.test.js` | 99 `hooks/src/index.js` | 21 | `hooks/test/browser/useLayoutEffect.test.js#Comp` -> `hooks/src/index.js#useLayoutEffect` |
| preactjs/preact | calls | 34 `compat/test/browser/portals.test.js` | 99 `hooks/src/index.js` | 20 | `compat/test/browser/portals.test.js#Foo` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 131 `test-utils/test/shared/act.test.js` | 99 `hooks/src/index.js` | 17 | `test-utils/test/shared/act.test.js#StateContainer` -> `hooks/src/index.js#useEffect` |
| preactjs/preact | calls | 109 `hooks/test/browser/useImperativeHandle.test.js` | 99 `hooks/src/index.js` | 16 | `hooks/test/browser/useImperativeHandle.test.js#Comp` -> `hooks/src/index.js#useRef` |
| preactjs/preact | calls | 26 `test/_util` | 99 `hooks/src/index.js` | 14 | `debug/test/browser/debug.options.test.js#HookApp` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 98 `hooks/test/browser` | 97 `hooks/src/index.js` | 29 | `hooks/test/browser/useEffect.test.js#Comp` -> `hooks/src/index.js#useEffect` |
| preactjs/preact | calls | 108 `hooks/test/browser/useLayoutEffect.test.js` | 97 `hooks/src/index.js` | 25 | `hooks/test/browser/useLayoutEffect.test.js#Comp` -> `hooks/src/index.js#useLayoutEffect` |
| preactjs/preact | calls | 99 `hooks/test/browser/combinations.test.js` | 97 `hooks/src/index.js` | 23 | `hooks/test/browser/combinations.test.js#Parent` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 35 `compat/test/browser/portals.test.js` | 18 `compat/src/portals.js` | 21 | `compat/test/browser/portals.test.js#Foo` -> `compat/src/portals.js#createPortal` |
| preactjs/preact | calls | 35 `compat/test/browser/portals.test.js` | 97 `hooks/src/index.js` | 20 | `compat/test/browser/portals.test.js#Foo` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 130 `test-utils/test/shared/act.test.js` | 97 `hooks/src/index.js` | 17 | `test-utils/test/shared/act.test.js#StateContainer` -> `hooks/src/index.js#useEffect` |
| preactjs/preact | calls | 107 `hooks/test/browser/useImperativeHandle.test.js` | 97 `hooks/src/index.js` | 16 | `hooks/test/browser/useImperativeHandle.test.js#Comp` -> `hooks/src/index.js#useRef` |
| preactjs/preact | calls | 26 `test/_util` | 97 `hooks/src/index.js` | 14 | `debug/test/browser/debug.options.test.js#HookApp` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 102 `hooks/test/browser` | 101 `hooks/src/index.js` | 29 | `hooks/test/browser/useEffect.test.js#Comp` -> `hooks/src/index.js#useEffect` |
| preactjs/preact | calls | 113 `hooks/test/browser/useLayoutEffect.test.js` | 101 `hooks/src/index.js` | 25 | `hooks/test/browser/useLayoutEffect.test.js#Comp` -> `hooks/src/index.js#useLayoutEffect` |
| preactjs/preact | calls | 103 `hooks/test/browser/combinations.test.js` | 101 `hooks/src/index.js` | 23 | `hooks/test/browser/combinations.test.js#Parent` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 36 `compat/test/browser/portals.test.js` | 19 `compat/src/portals.js` | 21 | `compat/test/browser/portals.test.js#Foo` -> `compat/src/portals.js#createPortal` |
| preactjs/preact | calls | 36 `compat/test/browser/portals.test.js` | 101 `hooks/src/index.js` | 20 | `compat/test/browser/portals.test.js#Foo` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 135 `test-utils/test/shared/act.test.js` | 101 `hooks/src/index.js` | 17 | `test-utils/test/shared/act.test.js#StateContainer` -> `hooks/src/index.js#useEffect` |
| preactjs/preact | calls | 111 `hooks/test/browser/useId.test.js` | 101 `hooks/src/index.js` | 16 | `hooks/test/browser/useId.test.js#Comp` -> `hooks/src/index.js#useId` |
| preactjs/preact | calls | 112 `hooks/test/browser/useImperativeHandle.test.js` | 101 `hooks/src/index.js` | 16 | `hooks/test/browser/useImperativeHandle.test.js#Comp` -> `hooks/src/index.js#useRef` |
| preactjs/preact | calls | 102 `hooks/test/browser` | 101 `hooks/src/index.js` | 29 | `hooks/test/browser/useEffect.test.js#Comp` -> `hooks/src/index.js#useEffect` |
| preactjs/preact | calls | 113 `hooks/test/browser/useLayoutEffect.test.js` | 101 `hooks/src/index.js` | 25 | `hooks/test/browser/useLayoutEffect.test.js#Comp` -> `hooks/src/index.js#useLayoutEffect` |
| preactjs/preact | calls | 103 `hooks/test/browser/combinations.test.js` | 101 `hooks/src/index.js` | 23 | `hooks/test/browser/combinations.test.js#Parent` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 37 `compat/test/browser/portals.test.js` | 20 `compat/src/portals.js` | 21 | `compat/test/browser/portals.test.js#Foo` -> `compat/src/portals.js#createPortal` |
| preactjs/preact | calls | 37 `compat/test/browser/portals.test.js` | 101 `hooks/src/index.js` | 20 | `compat/test/browser/portals.test.js#Foo` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 111 `hooks/test/browser/useId.test.js` | 101 `hooks/src/index.js` | 20 | `hooks/test/browser/useId.test.js#Comp` -> `hooks/src/index.js#useId` |
| preactjs/preact | calls | 134 `test-utils/test/shared/act.test.js` | 101 `hooks/src/index.js` | 17 | `test-utils/test/shared/act.test.js#StateContainer` -> `hooks/src/index.js#useEffect` |
| preactjs/preact | calls | 112 `hooks/test/browser/useImperativeHandle.test.js` | 101 `hooks/src/index.js` | 16 | `hooks/test/browser/useImperativeHandle.test.js#Comp` -> `hooks/src/index.js#useRef` |
| preactjs/preact | calls | 108 `hooks/test/browser` | 107 `hooks/src/index.js` | 33 | `hooks/test/browser/useEffect.test.js#Comp` -> `hooks/src/index.js#useEffect` |
| preactjs/preact | calls | 109 `hooks/test/browser/combinations.test.js` | 107 `hooks/src/index.js` | 32 | `hooks/test/browser/combinations.test.js#Parent` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 119 `hooks/test/browser/useLayoutEffect.test.js` | 107 `hooks/src/index.js` | 27 | `hooks/test/browser/useLayoutEffect.test.js#Comp` -> `hooks/src/index.js#useLayoutEffect` |
| preactjs/preact | calls | 117 `hooks/test/browser/useId.test.js` | 107 `hooks/src/index.js` | 25 | `hooks/test/browser/useId.test.js#Comp` -> `hooks/src/index.js#useId` |
| preactjs/preact | calls | 40 `compat/test/browser/portals.test.js` | 22 `compat/src/portals.js` | 21 | `compat/test/browser/portals.test.js#Foo` -> `compat/src/portals.js#createPortal` |
| preactjs/preact | calls | 40 `compat/test/browser/portals.test.js` | 107 `hooks/src/index.js` | 20 | `compat/test/browser/portals.test.js#Foo` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 118 `hooks/test/browser/useImperativeHandle.test.js` | 107 `hooks/src/index.js` | 17 | `hooks/test/browser/useImperativeHandle.test.js#Comp` -> `hooks/src/index.js#useRef` |
| preactjs/preact | calls | 140 `test-utils/test/shared/act.test.js` | 107 `hooks/src/index.js` | 17 | `test-utils/test/shared/act.test.js#StateContainer` -> `hooks/src/index.js#useEffect` |
| preactjs/preact | calls | 109 `hooks/test/browser` | 108 `hooks/src/index.js` | 33 | `hooks/test/browser/useEffect.test.js#Comp` -> `hooks/src/index.js#useEffect` |
| preactjs/preact | calls | 110 `hooks/test/browser/combinations.test.js` | 108 `hooks/src/index.js` | 32 | `hooks/test/browser/combinations.test.js#Parent` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 120 `hooks/test/browser/useLayoutEffect.test.js` | 108 `hooks/src/index.js` | 27 | `hooks/test/browser/useLayoutEffect.test.js#Comp` -> `hooks/src/index.js#useLayoutEffect` |
| preactjs/preact | calls | 118 `hooks/test/browser/useId.test.js` | 108 `hooks/src/index.js` | 25 | `hooks/test/browser/useId.test.js#Comp` -> `hooks/src/index.js#useId` |
| preactjs/preact | calls | 51 `compat/test/browser/useSyncExternalStore.test.js` | 20 `compat/src` | 23 | `compat/test/browser/useSyncExternalStore.test.js#App` -> `compat/src/index.js#useSyncExternalStore` |
| preactjs/preact | calls | 40 `compat/test/browser/portals.test.js` | 22 `compat/src/portals.js` | 21 | `compat/test/browser/portals.test.js#Foo` -> `compat/src/portals.js#createPortal` |
| preactjs/preact | calls | 40 `compat/test/browser/portals.test.js` | 108 `hooks/src/index.js` | 20 | `compat/test/browser/portals.test.js#Foo` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 119 `hooks/test/browser/useImperativeHandle.test.js` | 108 `hooks/src/index.js` | 17 | `hooks/test/browser/useImperativeHandle.test.js#Comp` -> `hooks/src/index.js#useRef` |
| preactjs/preact | calls | 113 `hooks/test/browser/combinations.test.js` | 111 `hooks/src/index.js` | 34 | `hooks/test/browser/combinations.test.js#Parent` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 112 `hooks/test/browser` | 111 `hooks/src/index.js` | 33 | `hooks/test/browser/useEffect.test.js#Comp` -> `hooks/src/index.js#useEffect` |
| preactjs/preact | calls | 121 `hooks/test/browser/useId.test.js` | 111 `hooks/src/index.js` | 27 | `hooks/test/browser/useId.test.js#Comp` -> `hooks/src/index.js#useId` |
| preactjs/preact | calls | 123 `hooks/test/browser/useLayoutEffect.test.js` | 111 `hooks/src/index.js` | 27 | `hooks/test/browser/useLayoutEffect.test.js#Comp` -> `hooks/src/index.js#useLayoutEffect` |
| preactjs/preact | calls | 52 `compat/test/browser/useSyncExternalStore.test.js` | 20 `compat/src` | 23 | `compat/test/browser/useSyncExternalStore.test.js#App` -> `compat/src/index.js#useSyncExternalStore` |
| preactjs/preact | calls | 41 `compat/test/browser/portals.test.js` | 22 `compat/src/portals.js` | 21 | `compat/test/browser/portals.test.js#Foo` -> `compat/src/portals.js#createPortal` |
| preactjs/preact | calls | 41 `compat/test/browser/portals.test.js` | 111 `hooks/src/index.js` | 20 | `compat/test/browser/portals.test.js#Foo` -> `hooks/src/index.js#useState` |
| preactjs/preact | calls | 122 `hooks/test/browser/useImperativeHandle.test.js` | 111 `hooks/src/index.js` | 17 | `hooks/test/browser/useImperativeHandle.test.js#Comp` -> `hooks/src/index.js#useRef` |
| protonmail/webclients | calls | 987 `packages/components/components/editor` | 146 `applications/calendar/src/app/containers/calendar` | 35 | `packages/components/components/editor/constants.ts#'#FFFFFF'` -> `applications/calendar/src/app/containers/calendar/recurrence/updateAllRecurrence.spec.js#c` |
| protonmail/webclients | calls | 1828 `packages/encrypted-search/lib/useEncryptedSearch.tsx` | 1826 `packages/encrypted-search/lib/esHelpers` | 31 | `packages/encrypted-search/lib/useEncryptedSearch.tsx#esDelete` -> `packages/encrypted-search/lib/esHelpers/esUtils.ts#removeESFlags` |
| protonmail/webclients | imports | 45 `applications/account/src/app/signup` | 33 `applications/account/src/app/public` | 27 | `applications/account/src/app/signup/AccountStep.tsx` -> `applications/account/src/app/public/Content.tsx` |
| protonmail/webclients | calls | 1619 `packages/components` | 1602 `packages/components/containers/payments/features/mail.ts` | 25 | `packages/components/containers/payments/features/plan.ts#getFreePlan` -> `packages/components/containers/payments/features/mail.ts#getNAddressesFeature` |
| protonmail/webclients | calls | 1620 `packages/components/containers/payments` | 146 `applications/calendar/src/app/containers/calendar` | 20 | `packages/components/containers/payments/features/vpn.ts#getFreeVPNConnectionTotal` -> `applications/calendar/src/app/containers/calendar/recurrence/updateAllRecurrence.spec.js#c` |
| protonmail/webclients | calls | 1998 `packages/shared/lib/constants.ts` | 146 `applications/calendar/src/app/containers/calendar` | 20 | `packages/shared/lib/constants.ts#getName` -> `applications/calendar/src/app/containers/calendar/recurrence/updateAllRecurrence.spec.js#c` |
| protonmail/webclients | calls | 151 `applications/calendar/src/app/containers/calendar/eventActions/inviteActions.ts` | 1972 `packages/shared/lib/calendar/integration/invite.ts` | 19 | `applications/calendar/src/app/containers/calendar/eventActions/inviteActions.ts#getUpdatedSaveInviteActions` -> `packages/shared/lib/calendar/integration/invite.ts#getHasUpdatedInviteData` |
| protonmail/webclients | calls | 1619 `packages/components` | 1620 `packages/components/containers/payments` | 19 | `packages/components/containers/payments/features/plan.ts#getBundlePlan` -> `packages/components/containers/payments/features/vpn.ts#getVPNAppFeature` |
| tutao/tutanota | calls | 199 `src/calendar/view/CalendarEventEditDialog.ts` | 443 `src` | 39 | `src/calendar/view/CalendarEventEditDialog.ts#showCalendarEventDialog` -> `src/calendar/date/CalendarEventViewModel.ts#isReadOnlyEvent` |
| tutao/tutanota | calls | 398 `src/mail/view/MailViewerHeader.ts` | 400 `src/mail/view/MailViewerViewModel.ts` | 30 | `src/mail/view/MailViewerHeader.ts#renderFolderText` -> `src/mail/view/MailViewerViewModel.ts#getFolderText` |
| tutao/tutanota | calls | 380 `src/mail/editor/MailEditor.ts` | 382 `src` | 26 | `src/mail/editor/MailEditor.ts#onEditorChanged` -> `src/mail/editor/SendMailModel.ts#markAsChangedIfNecessary` |
| tutao/tutanota | calls | 398 `src/mail/view/MailViewerHeader.ts` | 34 `libs/mithril.js` | 26 | `src/mail/view/MailViewerHeader.ts#view` -> `libs/mithril.js#m` |
| tutao/tutanota | calls | 152 `src/api/worker/facades/MailFacade.ts` | 119 `src/api/entities/tutanota/TypeRefs.ts` | 23 | `src/api/worker/facades/MailFacade.ts#createMailFolder` -> `src/api/entities/tutanota/TypeRefs.ts#createCreateMailFolderData` |
| tutao/tutanota | calls | 199 `src/calendar/view/CalendarEventEditDialog.ts` | 34 `libs/mithril.js` | 21 | `src/calendar/view/CalendarEventEditDialog.ts#renderEndValue` -> `libs/mithril.js#m` |
| tutao/tutanota | calls | 443 `src` | 191 `src/calendar/date/CalendarUtils.ts` | 20 | `src/calendar/date/CalendarEventViewModel.ts#rescheduleEvent` -> `src/calendar/date/CalendarUtils.ts#getStartOfDayWithZone` |
| tutao/tutanota | calls | 589 `src/subscription` | 602 `src/subscription` | 20 | `src/subscription/SignupPage.ts#headerTitle` -> `src/subscription/FeatureListProvider.ts#getDisplayNameOfSubscriptionType` |
| tutao/tutanota | calls | 219 `src/calendar/view/CalendarEventEditDialog.ts` | 220 `src` | 38 | `src/calendar/view/CalendarEventEditDialog.ts#showCalendarEventDialog` -> `src/calendar/date/CalendarEventViewModel.ts#isReadOnlyEvent` |
| tutao/tutanota | calls | 400 `src/mail/editor/MailEditor.ts` | 401 `src/mail` | 27 | `src/mail/editor/MailEditor.ts#onEditorChanged` -> `src/mail/editor/SendMailModel.ts#markAsChangedIfNecessary` |
| tutao/tutanota | calls | 420 `src/mail/view/MailViewerHeader.ts` | 401 `src/mail` | 27 | `src/mail/view/MailViewerHeader.ts#renderFolderText` -> `src/mail/view/MailViewerViewModel.ts#getFolderText` |
| tutao/tutanota | calls | 420 `src/mail/view/MailViewerHeader.ts` | 37 `libs/mithril.js` | 26 | `src/mail/view/MailViewerHeader.ts#view` -> `libs/mithril.js#m` |
| tutao/tutanota | calls | 166 `src/api/worker/facades/MailFacade.ts` | 127 `src/api/entities/tutanota/TypeRefs.ts` | 24 | `src/api/worker/facades/MailFacade.ts#createMailFolder` -> `src/api/entities/tutanota/TypeRefs.ts#createCreateMailFolderData` |
| tutao/tutanota | calls | 579 `src/settings/groups/GroupDetailsView.ts` | 578 `src/settings/groups/GroupDetailsModel.ts` | 23 | `src/settings/groups/GroupDetailsView.ts#renderHeader` -> `src/settings/groups/GroupDetailsModel.ts#getGroupType` |
| tutao/tutanota | calls | 219 `src/calendar/view/CalendarEventEditDialog.ts` | 37 `libs/mithril.js` | 21 | `src/calendar/view/CalendarEventEditDialog.ts#renderEndValue` -> `libs/mithril.js#m` |
| tutao/tutanota | calls | 206 `src/app.ts` | 133 `src/api/main/MainLocator.ts` | 20 | `src/app.ts#prepareRoute` -> `src/api/main/MainLocator.ts#baseHeaderAttrs` |
| tutao/tutanota | calls | 208 `src/calendar/view/CalendarEventEditDialog.ts` | 209 `src/calendar/date` | 38 | `src/calendar/view/CalendarEventEditDialog.ts#showCalendarEventDialog` -> `src/calendar/date/CalendarEventViewModel.ts#isReadOnlyEvent` |
| tutao/tutanota | calls | 411 `src/mail/view/MailViewerHeader.ts` | 413 `src/mail/view/MailViewerViewModel.ts` | 27 | `src/mail/view/MailViewerHeader.ts#renderFolderText` -> `src/mail/view/MailViewerViewModel.ts#getFolderText` |
| tutao/tutanota | calls | 411 `src/mail/view/MailViewerHeader.ts` | 34 `libs/mithril.js` | 26 | `src/mail/view/MailViewerHeader.ts#view` -> `libs/mithril.js#m` |
| tutao/tutanota | calls | 392 `src/mail/editor/MailEditor.ts` | 394 `src/mail` | 24 | `src/mail/editor/MailEditor.ts#onEditorChanged` -> `src/mail/editor/SendMailModel.ts#markAsChangedIfNecessary` |
| tutao/tutanota | calls | 160 `src/api/worker/facades/MailFacade.ts` | 123 `src/api/entities/tutanota/TypeRefs.ts` | 23 | `src/api/worker/facades/MailFacade.ts#createMailFolder` -> `src/api/entities/tutanota/TypeRefs.ts#createCreateMailFolderData` |
| tutao/tutanota | calls | 569 `src/settings/groups/GroupDetailsView.ts` | 568 `src/settings/groups/GroupDetailsModel.ts` | 23 | `src/settings/groups/GroupDetailsView.ts#renderHeader` -> `src/settings/groups/GroupDetailsModel.ts#getGroupType` |
| tutao/tutanota | calls | 208 `src/calendar/view/CalendarEventEditDialog.ts` | 34 `libs/mithril.js` | 21 | `src/calendar/view/CalendarEventEditDialog.ts#renderEndValue` -> `libs/mithril.js#m` |
| tutao/tutanota | calls | 209 `src/calendar/date` | 200 `src/calendar/date/CalendarUtils.ts` | 19 | `src/calendar/date/CalendarEventViewModel.ts#rescheduleEvent` -> `src/calendar/date/CalendarUtils.ts#getStartOfDayWithZone` |
| vuejs/core | calls | 151 `packages/runtime-core/src/components/Suspense.ts` | 155 `packages/runtime-core/src` | 117 | `packages/runtime-core/__tests__/components/Suspense.spec.ts#setup` -> `packages/runtime-core/src/h.ts#h` |
| vuejs/core | calls | 167 `packages/runtime-core/__tests__/rendererAttrsFallthrough.spec.ts` | 155 `packages/runtime-core/src` | 40 | `packages/runtime-core/__tests__/rendererAttrsFallthrough.spec.ts#setup` -> `packages/runtime-core/src/h.ts#h` |
| vuejs/core | calls | 171 `packages/runtime-core/__tests__/rendererOptimizedMode.spec.ts` | 224 `packages/runtime-core/src/vnode.ts` | 40 | `packages/runtime-core/__tests__/rendererOptimizedMode.spec.ts#renderWithBlock` -> `packages/runtime-core/src/vnode.ts#openBlock` |
| vuejs/core | calls | 150 `packages/runtime-core/src/components/KeepAlive.ts` | 155 `packages/runtime-core/src` | 37 | `packages/runtime-core/__tests__/components/KeepAlive.spec.ts#render` -> `packages/runtime-core/src/h.ts#h` |
| vuejs/core | calls | 227 `packages/runtime-dom/__tests__/customElement.spec.ts` | 155 `packages/runtime-core/src` | 36 | `packages/runtime-dom/__tests__/customElement.spec.ts#render` -> `packages/runtime-core/src/h.ts#h` |
| vuejs/core | calls | 41 `packages/compiler-core/src/tokenizer.ts` | 19 `packages/compiler-core/src` | 34 | `packages/compiler-core/src/tokenizer.ts#stateText` -> `packages/compiler-core/src/parser.ts#ontext` |
| vuejs/core | calls | 165 `packages/runtime-core/__tests__/hydration.spec.ts` | 155 `packages/runtime-core/src` | 34 | `packages/runtime-core/__tests__/hydration.spec.ts#Comp` -> `packages/runtime-core/src/h.ts#h` |
| vuejs/core | calls | 256 `packages/server-renderer/src` | 155 `packages/runtime-core/src` | 28 | `packages/server-renderer/__tests__/render.spec.ts#testRender` -> `packages/runtime-core/src/h.ts#h` |
| vuejs/core | calls | 153 `packages/runtime-core/src/components/Suspense.ts` | 157 `packages/runtime-core/src` | 117 | `packages/runtime-core/__tests__/components/Suspense.spec.ts#setup` -> `packages/runtime-core/src/h.ts#h` |
| vuejs/core | calls | 152 `packages/runtime-core/src/components/KeepAlive.ts` | 157 `packages/runtime-core/src` | 40 | `packages/runtime-core/__tests__/components/KeepAlive.spec.ts#render` -> `packages/runtime-core/src/h.ts#h` |
| vuejs/core | calls | 169 `packages/runtime-core/__tests__/rendererAttrsFallthrough.spec.ts` | 157 `packages/runtime-core/src` | 40 | `packages/runtime-core/__tests__/rendererAttrsFallthrough.spec.ts#setup` -> `packages/runtime-core/src/h.ts#h` |
| vuejs/core | calls | 173 `packages/runtime-core/__tests__/rendererOptimizedMode.spec.ts` | 227 `packages/runtime-core/src/vnode.ts` | 40 | `packages/runtime-core/__tests__/rendererOptimizedMode.spec.ts#renderWithBlock` -> `packages/runtime-core/src/vnode.ts#openBlock` |
| vuejs/core | calls | 230 `packages/runtime-dom/__tests__/customElement.spec.ts` | 157 `packages/runtime-core/src` | 36 | `packages/runtime-dom/__tests__/customElement.spec.ts#render` -> `packages/runtime-core/src/h.ts#h` |
| vuejs/core | calls | 43 `packages/compiler-core/src/tokenizer.ts` | 19 `packages/compiler-core/src` | 34 | `packages/compiler-core/src/tokenizer.ts#stateText` -> `packages/compiler-core/src/parser.ts#ontext` |
| vuejs/core | calls | 167 `packages/runtime-core/__tests__/hydration.spec.ts` | 157 `packages/runtime-core/src` | 34 | `packages/runtime-core/__tests__/hydration.spec.ts#Comp` -> `packages/runtime-core/src/h.ts#h` |
| vuejs/core | calls | 260 `packages/server-renderer/__tests__/render.spec.ts` | 157 `packages/runtime-core/src` | 28 | `packages/server-renderer/__tests__/render.spec.ts#testRender` -> `packages/runtime-core/src/h.ts#h` |
| vuejs/core | calls | 151 `packages/runtime-core/src/components/Suspense.ts` | 155 `packages/runtime-core/src` | 117 | `packages/runtime-core/__tests__/components/Suspense.spec.ts#setup` -> `packages/runtime-core/src/h.ts#h` |
| vuejs/core | calls | 150 `packages/runtime-core/src/components/KeepAlive.ts` | 155 `packages/runtime-core/src` | 40 | `packages/runtime-core/__tests__/components/KeepAlive.spec.ts#render` -> `packages/runtime-core/src/h.ts#h` |
| vuejs/core | calls | 167 `packages/runtime-core/__tests__/rendererAttrsFallthrough.spec.ts` | 155 `packages/runtime-core/src` | 40 | `packages/runtime-core/__tests__/rendererAttrsFallthrough.spec.ts#setup` -> `packages/runtime-core/src/h.ts#h` |
| vuejs/core | calls | 171 `packages/runtime-core/__tests__/rendererOptimizedMode.spec.ts` | 225 `packages/runtime-core/src/vnode.ts` | 40 | `packages/runtime-core/__tests__/rendererOptimizedMode.spec.ts#renderWithBlock` -> `packages/runtime-core/src/vnode.ts#openBlock` |
| vuejs/core | calls | 165 `packages/runtime-core/__tests__/hydration.spec.ts` | 155 `packages/runtime-core/src` | 36 | `packages/runtime-core/__tests__/hydration.spec.ts#Comp` -> `packages/runtime-core/src/h.ts#h` |
| vuejs/core | calls | 228 `packages/runtime-dom/__tests__/customElement.spec.ts` | 155 `packages/runtime-core/src` | 36 | `packages/runtime-dom/__tests__/customElement.spec.ts#render` -> `packages/runtime-core/src/h.ts#h` |
| vuejs/core | calls | 41 `packages/compiler-core/src/tokenizer.ts` | 19 `packages/compiler-core/src` | 34 | `packages/compiler-core/src/tokenizer.ts#stateText` -> `packages/compiler-core/src/parser.ts#ontext` |
| vuejs/core | calls | 258 `packages/server-renderer/__tests__/render.spec.ts` | 155 `packages/runtime-core/src` | 30 | `packages/server-renderer/__tests__/render.spec.ts#testRender` -> `packages/runtime-core/src/h.ts#h` |
| vuejs/core | calls | 151 `packages/runtime-core/src/components/Suspense.ts` | 155 `packages/runtime-core/src` | 117 | `packages/runtime-core/__tests__/components/Suspense.spec.ts#setup` -> `packages/runtime-core/src/h.ts#h` |
| vuejs/core | calls | 150 `packages/runtime-core/src/components/KeepAlive.ts` | 155 `packages/runtime-core/src` | 40 | `packages/runtime-core/__tests__/components/KeepAlive.spec.ts#render` -> `packages/runtime-core/src/h.ts#h` |
| vuejs/core | calls | 167 `packages/runtime-core/__tests__/rendererAttrsFallthrough.spec.ts` | 155 `packages/runtime-core/src` | 40 | `packages/runtime-core/__tests__/rendererAttrsFallthrough.spec.ts#setup` -> `packages/runtime-core/src/h.ts#h` |
| vuejs/core | calls | 171 `packages/runtime-core/__tests__/rendererOptimizedMode.spec.ts` | 225 `packages/runtime-core/src/vnode.ts` | 40 | `packages/runtime-core/__tests__/rendererOptimizedMode.spec.ts#renderWithBlock` -> `packages/runtime-core/src/vnode.ts#openBlock` |
| vuejs/core | calls | 165 `packages/runtime-core/__tests__/hydration.spec.ts` | 155 `packages/runtime-core/src` | 36 | `packages/runtime-core/__tests__/hydration.spec.ts#Comp` -> `packages/runtime-core/src/h.ts#h` |
| vuejs/core | calls | 228 `packages/runtime-dom/__tests__/customElement.spec.ts` | 155 `packages/runtime-core/src` | 36 | `packages/runtime-dom/__tests__/customElement.spec.ts#render` -> `packages/runtime-core/src/h.ts#h` |
| vuejs/core | calls | 41 `packages/compiler-core/src/tokenizer.ts` | 19 `packages/compiler-core/src` | 34 | `packages/compiler-core/src/tokenizer.ts#stateText` -> `packages/compiler-core/src/parser.ts#ontext` |
| vuejs/core | calls | 258 `packages/server-renderer/src` | 155 `packages/runtime-core/src` | 30 | `packages/server-renderer/__tests__/render.spec.ts#testRender` -> `packages/runtime-core/src/h.ts#h` |

**Exported files** (`data/<digest>/` in the Atlas Live data tree)

| repository | exported file | rows | sha256 |
|---|---|---:|---|
| preactjs/preact | `families.parquet` | 159 | `f748bdadf77e` |
| preactjs/preact | `family_members.parquet` | 1623 | `5e128df015e2` |
| preactjs/preact | `family_rollups.parquet` | 686 | `73e7aab0d702` |
| preactjs/preact | `family_edges.parquet` | 340 | `d79c4910166d` |
| preactjs/preact | `family_contributions.parquet` | 809 | `d81465f412ec` |
| NodeBB/NodeBB | `families.parquet` | 332 | `4e2d2d00d23a` |
| NodeBB/NodeBB | `family_members.parquet` | 1385 | `fb843cd52081` |
| NodeBB/NodeBB | `family_rollups.parquet` | 1575 | `46c1341e5cdd` |
| NodeBB/NodeBB | `family_edges.parquet` | 1295 | `7341715dfd00` |
| NodeBB/NodeBB | `family_contributions.parquet` | 3619 | `f5e22e8fb720` |
| NodeBB/NodeBB | `families.parquet` | 337 | `1104e8ce1230` |
| NodeBB/NodeBB | `family_members.parquet` | 1400 | `fe65f40fe817` |
| NodeBB/NodeBB | `family_rollups.parquet` | 1596 | `8306a1ae1450` |
| NodeBB/NodeBB | `family_edges.parquet` | 1361 | `2e8a40aaf395` |
| NodeBB/NodeBB | `family_contributions.parquet` | 3617 | `2eeac3af65f7` |
| NodeBB/NodeBB | `families.parquet` | 349 | `a3e02c0613e6` |
| NodeBB/NodeBB | `family_members.parquet` | 1488 | `b6edf29e5735` |
| NodeBB/NodeBB | `family_rollups.parquet` | 1653 | `73582c0b9944` |
| NodeBB/NodeBB | `family_edges.parquet` | 1474 | `15d95d184a00` |
| NodeBB/NodeBB | `family_contributions.parquet` | 3791 | `0057f1815ef6` |
| NodeBB/NodeBB | `families.parquet` | 344 | `a49a7c454b4a` |
| NodeBB/NodeBB | `family_members.parquet` | 1475 | `7228d91a3805` |
| NodeBB/NodeBB | `family_rollups.parquet` | 1631 | `6564b29114e8` |
| NodeBB/NodeBB | `family_edges.parquet` | 1467 | `777f23f58b26` |
| NodeBB/NodeBB | `family_contributions.parquet` | 3766 | `e71f0fce8dfb` |
| NodeBB/NodeBB | `families.parquet` | 336 | `92db1ac7f51d` |
| NodeBB/NodeBB | `family_members.parquet` | 1408 | `a4f73db7c107` |
| NodeBB/NodeBB | `family_rollups.parquet` | 1596 | `bf962b5c99d8` |
| NodeBB/NodeBB | `family_edges.parquet` | 1387 | `6df1f8703356` |
| NodeBB/NodeBB | `family_contributions.parquet` | 3636 | `503c89d4a5b2` |
| NodeBB/NodeBB | `families.parquet` | 333 | `8a9dc9bddc6c` |
| NodeBB/NodeBB | `family_members.parquet` | 1408 | `f60a82b9a894` |
| NodeBB/NodeBB | `family_rollups.parquet` | 1586 | `d1e5ab41ef8c` |
| NodeBB/NodeBB | `family_edges.parquet` | 1374 | `d7f4b5b698ff` |
| NodeBB/NodeBB | `family_contributions.parquet` | 3635 | `e69edb2b4f33` |
| NodeBB/NodeBB | `families.parquet` | 330 | `dca5b26e86b4` |
| NodeBB/NodeBB | `family_members.parquet` | 1367 | `a34e7e03bac8` |
| NodeBB/NodeBB | `family_rollups.parquet` | 1562 | `f3472faabf08` |
| NodeBB/NodeBB | `family_edges.parquet` | 1353 | `07a097615406` |
| NodeBB/NodeBB | `family_contributions.parquet` | 3562 | `d3fcb877976b` |
| NodeBB/NodeBB | `families.parquet` | 370 | `df2f55d8f25a` |
| NodeBB/NodeBB | `family_members.parquet` | 1663 | `faa6d97133e3` |
| NodeBB/NodeBB | `family_rollups.parquet` | 1753 | `b3f18801b086` |
| NodeBB/NodeBB | `family_edges.parquet` | 1902 | `0122c15e4862` |
| NodeBB/NodeBB | `family_contributions.parquet` | 4309 | `51289fd36dbf` |
| NodeBB/NodeBB | `families.parquet` | 340 | `643ca72b2552` |
| NodeBB/NodeBB | `family_members.parquet` | 1451 | `779031013467` |
| NodeBB/NodeBB | `family_rollups.parquet` | 1606 | `b8c829035ddb` |
| NodeBB/NodeBB | `family_edges.parquet` | 1449 | `daa3bfe6d9e6` |
| NodeBB/NodeBB | `family_contributions.parquet` | 3729 | `626e29d0ea79` |
| NodeBB/NodeBB | `families.parquet` | 337 | `24986cb8db32` |
| NodeBB/NodeBB | `family_members.parquet` | 1437 | `7495a9559214` |
| NodeBB/NodeBB | `family_rollups.parquet` | 1600 | `724dcce12721` |
| NodeBB/NodeBB | `family_edges.parquet` | 1407 | `bc878be0a8f0` |
| NodeBB/NodeBB | `family_contributions.parquet` | 3707 | `63a6544960ae` |
| NodeBB/NodeBB | `families.parquet` | 376 | `fbeba80d3a9b` |
| NodeBB/NodeBB | `family_members.parquet` | 1677 | `8948f9b55b16` |
| NodeBB/NodeBB | `family_rollups.parquet` | 1777 | `8a28affc4214` |
| NodeBB/NodeBB | `family_edges.parquet` | 1896 | `f03d28aa7a8c` |
| NodeBB/NodeBB | `family_contributions.parquet` | 4360 | `e3a0a7832a7d` |
| NodeBB/NodeBB | `families.parquet` | 345 | `653262119317` |
| NodeBB/NodeBB | `family_members.parquet` | 1466 | `c8b81ebcc5b6` |
| NodeBB/NodeBB | `family_rollups.parquet` | 1633 | `d0b9b940524e` |
| NodeBB/NodeBB | `family_edges.parquet` | 1447 | `196dcb88006e` |
| NodeBB/NodeBB | `family_contributions.parquet` | 3757 | `9d7491106a96` |
| NodeBB/NodeBB | `families.parquet` | 372 | `8cd8ac682e2e` |
| NodeBB/NodeBB | `family_members.parquet` | 1667 | `81ed49c2b3b9` |
| NodeBB/NodeBB | `family_rollups.parquet` | 1763 | `aed56832e510` |
| NodeBB/NodeBB | `family_edges.parquet` | 1885 | `6afae9b8a919` |
| NodeBB/NodeBB | `family_contributions.parquet` | 4408 | `a7a56b102f53` |
| NodeBB/NodeBB | `families.parquet` | 356 | `71ecd900d46c` |
| NodeBB/NodeBB | `family_members.parquet` | 1576 | `28eac9699959` |
| NodeBB/NodeBB | `family_rollups.parquet` | 1675 | `f107ed9b7463` |
| NodeBB/NodeBB | `family_edges.parquet` | 1564 | `2cddd60781c6` |
| NodeBB/NodeBB | `family_contributions.parquet` | 4048 | `b2f01ad7a576` |
| NodeBB/NodeBB | `families.parquet` | 331 | `d1859b0f922b` |
| NodeBB/NodeBB | `family_members.parquet` | 1393 | `f2803c00480b` |
| NodeBB/NodeBB | `family_rollups.parquet` | 1570 | `b6a6bcc292a0` |
| NodeBB/NodeBB | `family_edges.parquet` | 1389 | `3df53668345e` |
| NodeBB/NodeBB | `family_contributions.parquet` | 3640 | `61c252205f75` |
| NodeBB/NodeBB | `families.parquet` | 359 | `9b9f4904cde0` |
| NodeBB/NodeBB | `family_members.parquet` | 1614 | `d9d22e27c759` |
| NodeBB/NodeBB | `family_rollups.parquet` | 1702 | `81dfee65858b` |
| NodeBB/NodeBB | `family_edges.parquet` | 1560 | `288146be0803` |
| NodeBB/NodeBB | `family_contributions.parquet` | 4157 | `95af3159849c` |
| NodeBB/NodeBB | `families.parquet` | 332 | `379c9aadaff9` |
| NodeBB/NodeBB | `family_members.parquet` | 1396 | `8847042fa835` |
| NodeBB/NodeBB | `family_rollups.parquet` | 1575 | `63299d592657` |
| NodeBB/NodeBB | `family_edges.parquet` | 1410 | `d4e6d91bba1b` |
| NodeBB/NodeBB | `family_contributions.parquet` | 3643 | `612efd2f9d49` |
| NodeBB/NodeBB | `families.parquet` | 333 | `f37fd69441ff` |
| NodeBB/NodeBB | `family_members.parquet` | 1396 | `c4f70a51e8b0` |
| NodeBB/NodeBB | `family_rollups.parquet` | 1577 | `b4bcfbdd0ff5` |
| NodeBB/NodeBB | `family_edges.parquet` | 1417 | `0b1d04bb42f7` |
| NodeBB/NodeBB | `family_contributions.parquet` | 3644 | `9227738b5d8f` |
| NodeBB/NodeBB | `families.parquet` | 383 | `bb8a54d74917` |
| NodeBB/NodeBB | `family_members.parquet` | 1707 | `bcddd8405246` |
| NodeBB/NodeBB | `family_rollups.parquet` | 1817 | `3710e1466081` |
| NodeBB/NodeBB | `family_edges.parquet` | 2044 | `fff4246813b0` |
| NodeBB/NodeBB | `family_contributions.parquet` | 4595 | `1bb27462e4ac` |
| NodeBB/NodeBB | `families.parquet` | 374 | `e14fe97a80c0` |
| NodeBB/NodeBB | `family_members.parquet` | 1679 | `e74134452450` |
| NodeBB/NodeBB | `family_rollups.parquet` | 1773 | `f25723ee6953` |
| NodeBB/NodeBB | `family_edges.parquet` | 1887 | `9e2d4163cb73` |
| NodeBB/NodeBB | `family_contributions.parquet` | 4362 | `b4c856a4e7e8` |
| NodeBB/NodeBB | `families.parquet` | 375 | `f3d2de4ba2f0` |
| NodeBB/NodeBB | `family_members.parquet` | 1668 | `200a03e34f04` |
| NodeBB/NodeBB | `family_rollups.parquet` | 1771 | `c101c46adf3d` |
| NodeBB/NodeBB | `family_edges.parquet` | 1881 | `b9be60c336e6` |
| NodeBB/NodeBB | `family_contributions.parquet` | 4412 | `c83d3cd9828e` |
| NodeBB/NodeBB | `families.parquet` | 351 | `e5b419d613d8` |
| NodeBB/NodeBB | `family_members.parquet` | 1574 | `a9972e9bc044` |
| NodeBB/NodeBB | `family_rollups.parquet` | 1666 | `cc3f9cc7c9c8` |
| NodeBB/NodeBB | `family_edges.parquet` | 1532 | `7baed5f84154` |
| NodeBB/NodeBB | `family_contributions.parquet` | 4048 | `561735ab8c0b` |
| axios/axios | `families.parquet` | 33 | `cdbb0a381cc7` |
| axios/axios | `family_members.parquet` | 295 | `cb430d3f308c` |
| axios/axios | `family_rollups.parquet` | 140 | `908539ab0881` |
| axios/axios | `family_edges.parquet` | 89 | `00c89bc12548` |
| axios/axios | `family_contributions.parquet` | 360 | `be5fb90e22f1` |
| axios/axios | `families.parquet` | 43 | `9d95f2864647` |
| axios/axios | `family_members.parquet` | 707 | `45774581a07d` |
| axios/axios | `family_rollups.parquet` | 178 | `7cf560e6e62e` |
| axios/axios | `family_edges.parquet` | 97 | `c81859e6f415` |
| axios/axios | `family_contributions.parquet` | 711 | `17ec10c2dae7` |
| element-hq/element-web | `families.parquet` | 634 | `38eea86aee81` |
| element-hq/element-web | `family_members.parquet` | 5714 | `0a97173cd856` |
| element-hq/element-web | `family_rollups.parquet` | 3447 | `ae7f55471749` |
| element-hq/element-web | `family_edges.parquet` | 5736 | `1069c3e2c399` |
| element-hq/element-web | `family_contributions.parquet` | 10649 | `a23169cc3d8f` |
| element-hq/element-web | `families.parquet` | 643 | `3f60f6916b9d` |
| element-hq/element-web | `family_members.parquet` | 5883 | `96e60cddedba` |
| element-hq/element-web | `family_rollups.parquet` | 3509 | `4f89b54ab8e6` |
| element-hq/element-web | `family_edges.parquet` | 5840 | `dbc3358fb342` |
| element-hq/element-web | `family_contributions.parquet` | 10869 | `54d0f3f4fb8a` |
| facebook/docusaurus | `families.parquet` | 633 | `e336abf79623` |
| facebook/docusaurus | `family_members.parquet` | 5001 | `cd2d69d9ba5f` |
| facebook/docusaurus | `family_rollups.parquet` | 4355 | `9b233f09a72f` |
| facebook/docusaurus | `family_edges.parquet` | 1543 | `52c4f9e2d601` |
| facebook/docusaurus | `family_contributions.parquet` | 6510 | `0e0bbfa0a468` |
| facebook/docusaurus | `families.parquet` | 643 | `348ecaca4cff` |
| facebook/docusaurus | `family_members.parquet` | 5088 | `8105b831d703` |
| facebook/docusaurus | `family_rollups.parquet` | 4445 | `74e2de2fcf2f` |
| facebook/docusaurus | `family_edges.parquet` | 1569 | `421c773a1216` |
| facebook/docusaurus | `family_contributions.parquet` | 6587 | `ce56155e22e1` |
| facebook/docusaurus | `families.parquet` | 607 | `4826fdc2430e` |
| facebook/docusaurus | `family_members.parquet` | 4852 | `4467097628ef` |
| facebook/docusaurus | `family_rollups.parquet` | 4188 | `bc2f7fed70c8` |
| facebook/docusaurus | `family_edges.parquet` | 1446 | `a0846161e984` |
| facebook/docusaurus | `family_contributions.parquet` | 6333 | `7a3017a25a8c` |
| immutable-js/immutable-js | `families.parquet` | 111 | `9ed8e3a6df80` |
| immutable-js/immutable-js | `family_members.parquet` | 618 | `6734717e7d1c` |
| immutable-js/immutable-js | `family_rollups.parquet` | 442 | `2ae6e083fd13` |
| immutable-js/immutable-js | `family_edges.parquet` | 437 | `f69b0606b279` |
| immutable-js/immutable-js | `family_contributions.parquet` | 1144 | `f40ab5673143` |
| immutable-js/immutable-js | `families.parquet` | 111 | `d089094af1d7` |
| immutable-js/immutable-js | `family_members.parquet` | 618 | `eeb4b49835f2` |
| immutable-js/immutable-js | `family_rollups.parquet` | 439 | `3afd66478b87` |
| immutable-js/immutable-js | `family_edges.parquet` | 451 | `0d51fadf5d64` |
| immutable-js/immutable-js | `family_contributions.parquet` | 1157 | `e9b54b20ed56` |
| preactjs/preact | `families.parquet` | 168 | `194d77158f5e` |
| preactjs/preact | `family_members.parquet` | 1683 | `efe3842b9865` |
| preactjs/preact | `family_rollups.parquet` | 732 | `3a9819e48186` |
| preactjs/preact | `family_edges.parquet` | 369 | `69c9ce3c5213` |
| preactjs/preact | `family_contributions.parquet` | 879 | `7c38e34ff6b2` |
| preactjs/preact | `families.parquet` | 175 | `e39fda2d56ce` |
| preactjs/preact | `family_members.parquet` | 1733 | `2ea85827eb23` |
| preactjs/preact | `family_rollups.parquet` | 761 | `727f7f6e8c14` |
| preactjs/preact | `family_edges.parquet` | 388 | `e98e0393998e` |
| preactjs/preact | `family_contributions.parquet` | 921 | `1475550f5d96` |
| preactjs/preact | `families.parquet` | 175 | `c7ca596fa115` |
| preactjs/preact | `family_members.parquet` | 1761 | `e49a0b11aa60` |
| preactjs/preact | `family_rollups.parquet` | 764 | `fe03224975db` |
| preactjs/preact | `family_edges.parquet` | 394 | `34abd4813208` |
| preactjs/preact | `family_contributions.parquet` | 963 | `a95b37f51ccc` |
| preactjs/preact | `families.parquet` | 178 | `5661d9db0fb4` |
| preactjs/preact | `family_members.parquet` | 1787 | `8dfd302e50f1` |
| preactjs/preact | `family_rollups.parquet` | 777 | `2dc0ce919dc1` |
| preactjs/preact | `family_edges.parquet` | 396 | `2ddb2b83a09c` |
| preactjs/preact | `family_contributions.parquet` | 976 | `989c74742aa0` |
| preactjs/preact | `families.parquet` | 177 | `e3212285a1e6` |
| preactjs/preact | `family_members.parquet` | 1817 | `9edaf004a19b` |
| preactjs/preact | `family_rollups.parquet` | 776 | `49b2f8bbe445` |
| preactjs/preact | `family_edges.parquet` | 403 | `de0608a82c12` |
| preactjs/preact | `family_contributions.parquet` | 1011 | `fff0fa892171` |
| preactjs/preact | `families.parquet` | 183 | `dda043a9a21e` |
| preactjs/preact | `family_members.parquet` | 1852 | `46d78f927680` |
| preactjs/preact | `family_rollups.parquet` | 796 | `5cc8e5b76b80` |
| preactjs/preact | `family_edges.parquet` | 404 | `eee289814836` |
| preactjs/preact | `family_contributions.parquet` | 1034 | `89b82fec5189` |
| preactjs/preact | `families.parquet` | 182 | `cce84c3450c2` |
| preactjs/preact | `family_members.parquet` | 1868 | `ca40ec1bbd44` |
| preactjs/preact | `family_rollups.parquet` | 796 | `f8ebb1edd569` |
| preactjs/preact | `family_edges.parquet` | 409 | `800166f830f2` |
| preactjs/preact | `family_contributions.parquet` | 1041 | `d67c0ae04de1` |
| preactjs/preact | `families.parquet` | 190 | `ca5e6a03e62d` |
| preactjs/preact | `family_members.parquet` | 2014 | `5fe40722bb83` |
| preactjs/preact | `family_rollups.parquet` | 828 | `51b963d3f40a` |
| preactjs/preact | `family_edges.parquet` | 432 | `8f8cac9f49e1` |
| preactjs/preact | `family_contributions.parquet` | 1112 | `3d5f2e18bce5` |
| preactjs/preact | `families.parquet` | 191 | `c36ed8c3876a` |
| preactjs/preact | `family_members.parquet` | 2065 | `8b1b6b2b7338` |
| preactjs/preact | `family_rollups.parquet` | 834 | `b6b74a9eb2ef` |
| preactjs/preact | `family_edges.parquet` | 450 | `56ba9ac6ef30` |
| preactjs/preact | `family_contributions.parquet` | 1188 | `ea5f17825140` |
| preactjs/preact | `families.parquet` | 194 | `a044f16f5f98` |
| preactjs/preact | `family_members.parquet` | 2122 | `f41d76600f7b` |
| preactjs/preact | `family_rollups.parquet` | 849 | `6f6509e0f5db` |
| preactjs/preact | `family_edges.parquet` | 463 | `6b7a998ca39b` |
| preactjs/preact | `family_contributions.parquet` | 1216 | `0ef977eb0120` |
| protonmail/webclients | `families.parquet` | 2254 | `cfc455a56181` |
| protonmail/webclients | `family_members.parquet` | 10629 | `6989042df189` |
| protonmail/webclients | `family_rollups.parquet` | 16892 | `6e90052c12c9` |
| protonmail/webclients | `family_edges.parquet` | 13849 | `d59dbcc31945` |
| protonmail/webclients | `family_contributions.parquet` | 26672 | `b0edc2b59bb3` |
| tutao/tutanota | `families.parquet` | 709 | `d9a042cc3783` |
| tutao/tutanota | `family_members.parquet` | 9480 | `2d27e288cad7` |
| tutao/tutanota | `family_rollups.parquet` | 3578 | `8789068d3879` |
| tutao/tutanota | `family_edges.parquet` | 7069 | `bd540ef10ff3` |
| tutao/tutanota | `family_contributions.parquet` | 16797 | `393a5ce4ac7c` |
| tutao/tutanota | `families.parquet` | 740 | `002974bf94ed` |
| tutao/tutanota | `family_members.parquet` | 9884 | `e80ab11e888b` |
| tutao/tutanota | `family_rollups.parquet` | 3738 | `add2c25a59b2` |
| tutao/tutanota | `family_edges.parquet` | 7155 | `b3156dcf4ef7` |
| tutao/tutanota | `family_contributions.parquet` | 17168 | `d2a17e9fe938` |
| tutao/tutanota | `families.parquet` | 730 | `5118d4e5b848` |
| tutao/tutanota | `family_members.parquet` | 9730 | `f73066006667` |
| tutao/tutanota | `family_rollups.parquet` | 3689 | `7b8d0012c26d` |
| tutao/tutanota | `family_edges.parquet` | 7152 | `2f49bb4b9102` |
| tutao/tutanota | `family_contributions.parquet` | 17211 | `53eb65cbb311` |
| vuejs/core | `families.parquet` | 328 | `815779c45d82` |
| vuejs/core | `family_members.parquet` | 4149 | `2e13b173af14` |
| vuejs/core | `family_rollups.parquet` | 1845 | `bfcbe9bad19c` |
| vuejs/core | `family_edges.parquet` | 2016 | `16a53a808b50` |
| vuejs/core | `family_contributions.parquet` | 5771 | `ee315bede1de` |
| vuejs/core | `families.parquet` | 332 | `21bb87c7dd0b` |
| vuejs/core | `family_members.parquet` | 4179 | `20d274a295d2` |
| vuejs/core | `family_rollups.parquet` | 1858 | `f26974a17ac7` |
| vuejs/core | `family_edges.parquet` | 2049 | `48ac80b4293b` |
| vuejs/core | `family_contributions.parquet` | 5789 | `ce916fefb39b` |
| vuejs/core | `families.parquet` | 329 | `80d98dad2951` |
| vuejs/core | `family_members.parquet` | 4224 | `ece70e9f3ac3` |
| vuejs/core | `family_rollups.parquet` | 1843 | `ff5e52944126` |
| vuejs/core | `family_edges.parquet` | 2037 | `dc48dfa9173f` |
| vuejs/core | `family_contributions.parquet` | 5826 | `4c5248d99189` |
| vuejs/core | `families.parquet` | 332 | `ed88729704e2` |
| vuejs/core | `family_members.parquet` | 4224 | `79c8b0023680` |
| vuejs/core | `family_rollups.parquet` | 1865 | `e8ced7453469` |
| vuejs/core | `family_edges.parquet` | 2025 | `f2063211f295` |
| vuejs/core | `family_contributions.parquet` | 5828 | `8ddc4dc9abd4` |
<!-- families:edges:end -->

Reading the record:

- **Coverage.** All 604 calls attribute fully (every caller and callee is a
  member). 36 of the 205 imports stay unattributed because one endpoint is one
  of the 39 preact files that define no callable; the no-invention law carries
  them as contributions with no family edge.
- **Shape.** The 340 family edges collapse 809 exact edges: intra-family
  traffic accounts for 229 of 773 attributed edges (29.6%); calls alone have
  220 of 604 intra-family edges (36.4%). The heaviest cross-family edges are
  test families calling the implementation families they exercise — the
  map-legibility structure Atlas Live renders.
- **Route.** The same Starlark macro exports every clustered world; scaling
  the dataset adds a world's acquisition and extends `ACQUIRED_WORLDS`, nothing
  else.

## Measured topology contrast

The following snapshots connect two independently measured quantities. The
family columns come from the typed clustering and exact edge rows above;
physical reuse comes from the depth-seven evaluator's original file and symbol
seeds, exported as `physicalSummary` in the Atlas Live manifest. The call share
is intra-family call multiplicity divided by all exact calls. Physical reuse is
memoized `(State, Atom)` requests divided by all transition requests; it does
not measure wall-clock speedup or family cohesion.

| repository | snapshot | symbols | families | largest family | intra-family calls | physical reuse |
|---|---|---:|---:|---:|---:|---:|
| preactjs/preact | `6e2bef41bf19` | 1623 | 159 | 120 (7.4%) | 220 / 604 (36.4%) | 38,477,328 / 39,086,892 (98.4%) |
| axios/axios | `1e44a1c45ec4` | 295 | 33 | 83 (28.1%) | 191 / 220 (86.8%) | 8,570,787 / 8,721,516 (98.3%) |
| element-hq/element-web | `2ad7fd77595b` | 5714 | 634 | 90 (1.6%) | 2626 / 6550 (40.1%) | 131,609,349 / 139,501,608 (94.3%) |
| protonmail/webclients | `e79874736660` | 10629 | 2254 | 100 (0.9%) | 4059 / 17415 (23.3%) | 297,239,280 / 312,951,024 (95.0%) |

Axios concentrates most calls inside its families, while ProtonMail has many
more cross-family calls. Preact and Axios have similar physical reuse despite
their different call shares; physical transition reuse and family-local calls
are distinct views of repository topology. The Atlas Live comparison keeps the
exact physical percentage separate from the family's position and hue.

## Laws

| Target | Law |
| --- | --- |
| `:families_test` | The inventory is an exact function of the admitted world; the inventory table has a pinned schema, round-trips exactly, and rejects a foreign protocol, a mistyped column, or a row count other than one; the report projection is deterministic in declared order. The acquisition laws: documents follow the frozen recipe with no query side and are cut at the frozen limit; a span outside the source root is rejected; navigation offers only the frontier domain's atoms; every request is acquired once and then served from evidence; keyless replay refuses a miss and the envelope stops live calls; evidence is content-addressed, never replaced, and a retained exchange for a different request is rejected; every decision payload is issue-blind structure; every typed table round-trips exactly and rejects a foreign world; the ledger sums the provider-reported usage; the replay proof is exact only when every table matches keylessly. The clustering laws on a nested three-file world: affinity components are the exact per-pair means of both sources, the weights decide between the sources and a tie keeps the least candidate, recorded routes replay to their exact frontier, unheld symbols fall back to their seed candidate, the rollup is exact at file and directory level, family identity is derived from the exact members only, and the clustering tables round-trip exactly and reject foreign or malformed rows. |
| `:issue_blindness_test` | The tool's sources name no Localization module, issue field, or gold or population space; every retained decision request is a families state and every retained embedding request is a document batch, and none names an issue or gold field. |
| `replay_preact` | Keyless replay over the recorded preact spaces regenerates all six tables bit-identically with zero provider calls and no key in the environment (the build fails otherwise). |
| `:atlas_families_table_test` | A suite with one test per acquired world: every built `atlas-families-v1` table (families, members, rollups) decodes under its declared schema and encodes back to the stored rows, rewrites and reads back to the same rows, and is refused under a foreign schema. |
| `:atlas_families_law_test` | A suite with one test per acquired world: the independent rerun is byte-identical and an in-process recomputation equals the recorded tables (determinism); every symbol is a member of exactly one family and every member is its exact admitted symbol (no invention); every member row joins exactly one frozen world entity row on snapshot, domain, id, path, name, and span, and every seed file is a world file row (provenance); every family identity is the content-derived identity of its members; every name is its seed's recorded name, admitted by the recorded naming decision or the only candidate location (naming); the rollup equals its recomputation from the member table and each location sums to its members with one dominant family (rollup); every protocol weight is positive, both sources contribute to the recorded affinities, and the semantic affinity varies (both sources). |
| `:atlas_family_edges_table_test` | A suite with one test per acquired world: every built and exported family-edge and clustering table decodes under its declared schema and encodes back to the stored rows, rewrites and reads back to the same rows, and is refused under a foreign schema. |
| `:atlas_family_edges_law_test` | A suite with one test per acquired world: a fresh aggregation of the world under its clustering equals the recorded tables (determinism); the contributions of each relation are exactly the world's exact edges, each once and in edge order, and no family pair holds two edges of one relation (no invention); every contribution joins exactly one frozen world relation row (provenance); every endpoint carries the family the clustering gives it, and only a file that defines no callable lacks one (attribution); every multiplicity is the positive count of its contributions, and per relation the multiplicities plus the unattributed contributions sum to the world's exact edge count (multiplicity). |
| `:families_export_parity_test` | The web projection staging (`//web/atlas-live/projection:families`) holds exactly the exported worlds, each with exactly the exported files; every staged file has the bytes and the typed rows of the Flix-built science table it ships; and the edge laws hold over the staged tables against the frozen world. |
| `:charter_test` | `AGENTS.md` keeps the no-reacquisition paragraph and the Typed Parquet rule verbatim and carries the dated, scoped carve-out; this report carries the charter sections. |
| `:report_test` | Every generated block in this report and in `PROTOCOL.md` equals its regenerated Bazel projection. |

The tests are aggregated by `:families_tests`, which the root `//:tests`
suite includes. `:report_test` depends on the per-world replay, clustering, and
edge projections for the acquired population. Run them with
`nix develop --command bazel test //experiments/atlas-families/... --config=buildbuddy-rbe-arm64`.
