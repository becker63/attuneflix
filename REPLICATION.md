# Time-bounded repository replication

This report records the deterministic future-maintenance experiment over the
already materialized SWE-Explore TS/JS Nix snapshots.  Repository cutoffs,
heads, history projections, and source identities are frozen in
`replication.tsv`.  Each Flix run has a hard 15-minute wall-clock ceiling;
repositories that exceed it are reported as censored rather than silently
changing the protocol.

The source explanations below were produced by selecting exemplars from
measured hubs and predictor residuals before reading their source.  An
observation describes code present in the frozen snapshot.  A hypothesis is an
interpretation, not another measurement.

## Semantic gate

The current Python cold-facts artifact and AttuneFlix agree exactly for the
selected Axios snapshot:

| quantity | value |
|---|---:|
| files | 114 |
| symbols / defines | 295 |
| imports | 140 |
| calls | 220 |
| parent edges | 148 |

The fixed Grit program SHA-256 fingerprints are:

| program | SHA-256 |
|---|---|
| defines | `bba7b2aa5d958d3ea2369fae0b7025718d68fcd1ea10bdfc1351c676899552cb` |
| imports | `368c1c09ed1ba38437ddab45d1084710cb717adc8dc0c831e3b2e8c49f3ad14d` |
| calls | `de0e5436777fc93f96a517298386e5e728cd77fe5e46a027a5ae942287212147` |

Marzano revision: `c80b3026471b229f41b279c3eb0c162dcdacfdb1`.

## Completed prediction results

R@20 and MRR are shown here for compact comparison.  Full result rows also
include R@5, R@10, MAP, all-hidden recovery, and exposed-file cost.

| repository | predictor | R@20 | MRR |
|---|---|---:|---:|
| Axios | POPULARITY | 0.679 | 0.536 |
| | ATLAS | 0.311 | 0.205 |
| | HISTORY | 0.794 | 0.756 |
| | ROLE | 0.177 | 0.120 |
| | CONVENTION | 0.692 | 0.586 |
| | ATLAS+HISTORY | 0.812 | 0.608 |
| | ALL4 | 0.769 | 0.718 |
| Immutable | POPULARITY | 0.143 | 0.032 |
| | ATLAS | 0.273 | 0.307 |
| | HISTORY | 0.394 | 0.244 |
| | ROLE | 0.224 | 0.210 |
| | CONVENTION | 0.570 | 0.276 |
| | ATLAS+HISTORY | 0.422 | 0.401 |
| | ALL4 | 0.508 | 0.347 |
| Preact | POPULARITY | 0.573 | 0.365 |
| | ATLAS | 0.271 | 0.231 |
| | HISTORY | 0.628 | 0.452 |
| | ROLE | 0.084 | 0.127 |
| | CONVENTION | 0.452 | 0.189 |
| | ATLAS+HISTORY | 0.614 | 0.391 |
| | ALL4 | 0.523 | 0.320 |
| Vue | POPULARITY | 0.168 | 0.226 |
| | ATLAS | 0.448 | 0.349 |
| | HISTORY | 0.550 | 0.481 |
| | ROLE | 0.161 | 0.121 |
| | CONVENTION | 0.350 | 0.174 |
| | ATLAS+HISTORY | 0.573 | 0.459 |
| | ALL4 | 0.522 | 0.389 |
| NodeBB | POPULARITY | 0.064 | 0.101 |
| | ATLAS | 0.161 | 0.153 |
| | HISTORY | 0.415 | 0.386 |
| | ROLE | 0.108 | 0.127 |
| | CONVENTION | 0.258 | 0.224 |
| | ATLAS+HISTORY | 0.395 | 0.323 |
| | ALL4 | 0.383 | 0.318 |

Immutable has only 10 eligible future commits and 42 prediction tasks; its
point estimates should not be read with the same confidence as the three
100-commit populations.

Exact HISTORY beats marginal target-file POPULARITY on R@20, MRR, and MAP in
all four completed repositories.  High-HISTORY/low-ATLAS future-pair
enrichment is 5.87x for Axios, 2.45x for Immutable, 3.54x for Preact, and
1.24x for Vue.  High-HISTORY/low-POPULARITY enrichment is respectively 0.66x,
6.52x, 1.10x, and 1.88x.

## Axios: artifact and public-contract coupling

Measured evidence:

- `dist/axios.js` and `dist/axios.min.js` co-change with support 74 and
  directional confidence approximately 0.96--0.99, but are Atlas-unreachable.
- `index.d.ts` and `test/typescript/axios.ts` have support 16 and are
  Atlas-unreachable.
- `lib/adapters/xhr.js` and `test/specs/requests.spec.js` have support 15 and
  are Atlas-unreachable.
- HISTORY ranks `test/unit/adapters/http.js` first from
  `lib/adapters/http.js` in a representative future task that Atlas misses.

Source observation: the HTTP adapter is an implementation hub for redirects,
proxies, cancellation, decompression, and Node networking.  Its integration
test enters through the package index and live servers rather than importing
the adapter directly.  The distribution files are committed generated
bundles, while the TypeScript test exercises the public declaration contract.

Hypothesis: generated artifacts, public type contracts, and integration tests
form important maintenance edges that are real but absent from admitted
source-level Defines/Imports/Calls geometry.

## Immutable: semantic siblings and type contracts

Measured evidence:

- `__tests__/Map.ts` and `__tests__/Set.ts`: support 33,
  Atlas-unreachable.
- `__tests__/Record.ts` and `src/Record.js`: support 24,
  Atlas-unreachable.
- `__tests__/splice.ts` and `__tests__/slice.ts`: support 22, lift 10.73,
  Atlas-unreachable.
- CONVENTION reaches R@20 0.570, but this repository has only 42 tasks.

Source observation: tests import the published `immutable` package surface,
not the corresponding implementation files.  Slice and splice are parallel
semantic suites rather than directly dependent files.  The public declaration
file is a monolithic type contract and its compile-time tests likewise enter
through the package name.

Hypothesis: this snapshot is island-like under the admitted resolver, while
maintenance follows semantic operation families and mirrored declaration
tests.  Immediate-parent convention benefits from changes spanning coherent
test and type-definition areas.

## Preact: alias-mediated runtime, type, and configuration coupling

Measured evidence:

- `src/index.d.ts` and `src/diff/index.js`: support 24,
  Atlas-unreachable.
- `src/index.d.ts` and `src/internal.d.ts`: support 15,
  Atlas-unreachable.
- `debug/src/debug.js` and `src/diff/index.js`: support 14,
  Atlas-unreachable.
- `demo/webpack.config.js` and `demo/index.js`: support 11, lift 17.43,
  Atlas-unreachable.

Source observation: the diff implementation is a richly connected runtime
core.  Internal declarations describe fields manipulated by that runtime.
Debug and compat code frequently enter through package names, and the demo's
webpack configuration defines the aliases on which its source relies.

Hypothesis: ordinary relative imports explain the runtime core, while package
aliases, declaration/runtime mirroring, and build configuration define an
outer maintenance layer captured better by exact history.  This also explains
why adding Atlas to HISTORY does not improve this cutoff.

## Vue: statically explicit core with cross-package residuals

The admitted world contains 516 files, 4,149 symbols/defines, 1,177 imports,
4,594 calls, 594 parent edges, and 684 resolved file-call edges.

Measured evidence:

- Import hubs include `runtime-core/src/component.ts`, `renderer.ts`, and
  compiler modules.
- Broad Atlas seeds include `arrayInstrumentations.ts`, `compileTemplate.ts`,
  `compileScript.ts`, and `vnode.ts`, reaching roughly 443--446 files.
- `packages/global.d.ts` and `rollup.config.js`: support 21, lift 25,
  Atlas-unreachable.
- `compiler-ssr/src/runtimeHelpers.ts` and `server-renderer/src/index.ts`:
  support 18, lift 53.88, but only Atlas rank 315 at depth six.
- The five historically hottest files explain only 4.9% of future ordered
  target mass.

Source observation: component and renderer code are genuine explicit internal
hubs.  Cross-workspace dependencies use names such as `@vue/reactivity`, which
the conservative repository resolver does not turn into source-file edges.
Build globals are jointly maintained with Rollup configuration.  SSR compiler
helper names must agree with server-renderer exports through an explicit name
contract.

Hypothesis: Vue's central runtime/compiler architecture is unusually visible
to static analysis, which explains Atlas's comparatively strong result.
History contributes a narrower but concrete layer of workspace-package,
build-global, compiler/runtime naming, and test-contract relationships.

## NodeBB: server/client protocol and storage-family coupling

The admitted world contains 723 files, 1,386 symbols/defines, 2,442 imports,
1,177 calls, 831 parent edges, and 1,092 resolved file-call edges.  Python's
frozen Atlas signature has especially strong reverse-import propagation:
`imported_by` median density is 0.538 and p90 density is 0.691, versus import
median 0.184 and p90 0.520.  Extinction is low (approximately 1.3% for import
directions and 4.7--5.3% for call/definition directions).

Measured evidence:

- Static import hubs are `src/database/index.js` (in-degree 248),
  `src/meta/index.js` (189), `src/user/index.js` (162), and
  `src/plugins/index.js` (158).
- Broad Atlas seeds such as `src/socket.io/index.js` and
  `src/meta/minifier.js` reach 642 files.
- `src/socket.io/modules.js` to `public/src/modules/chat.js` has historical
  support 37, confidence 0.319, lift 9.95, but only Atlas rank 635 at depth
  six.
- `src/database/mongo.js` to `src/routes/debug.js` has support 27 and lift
  11.82, but Atlas rank 519.
- The five hottest historical files explain only 3.2% of future ordered
  target mass.
- High-HISTORY/low-ATLAS future pairs are enriched 4.57x; high-HISTORY/
  low-POPULARITY pairs are enriched 4.51x.

Source observation: `src/user/index.js` is an explicit facade that loads many
user submodules and central services.  `src/database/index.js` dynamically
selects a database implementation from configuration.  Server chat behavior
is exposed as string-addressed Socket.IO methods such as
`modules.chats.getRecentChats`, while browser chat code emits those names from
an AMD module.  Redis operations are split into sibling modules (`hash.js`,
`sets.js`, `helpers.js`, and others) installed onto one shared backend object.

The clearest ALL4 rescue starts from `src/database/redis/connection.js`:
CONVENTION recovers the sibling Redis hash/helpers/sets modules that Atlas and
exact HISTORY rank poorly.  This is real subsystem-family generalization, not
file popularity.

Hypothesis: NodeBB combines a highly connected server-side facade graph with
important relationships communicated through configuration-selected modules,
string-addressed client/server socket protocols, and sibling storage backend
implementations.  Static reach is broad, but its ranking has weak selectivity;
exact history identifies the maintained counterpart substantially better.

The complete run took 833.93 seconds internally and 14:11 wall clock, with
3.64 GiB peak RSS.  Grit extraction used 215.63 seconds, Atlas construction
188.13 seconds, and scoring/report analysis 426.54 seconds.

## Provisional taxonomy

- **Artifact/contract coupled:** Axios.
- **Semantic-family coupled:** Immutable and parts of Preact.
- **Alias/configuration coupled:** Preact.
- **Statically explicit:** Vue.
- **Broad but protocol-mediated:** NodeBB.

ROLE cosine similarity is weak as a predictor even where similar-role pairs
are modestly enriched.  Structural role identifies a broad class of plausible
files but generally lacks the identity-specific information needed to choose
the maintained counterpart.

This document remains incomplete until every attempted repository has either a
verified result or a recorded 15-minute censoring outcome.

## Censored attempts

### Element

The frozen Element snapshot contains 831 admitted source files.  Its Flix run
reached the unchanged 15-minute ceiling and was terminated by the external
timeout with status 124.  Peak RSS was 4,479,840 KiB (4.27 GiB); no completed
report was emitted, so predictor results and an internal last-stage timing are
unavailable.  It was not restarted or tuned after observing the outcome.

The independent Python Atlas artifact still supplies its structural signature:
5,727 definitions, 4,107 imports, and 6,556 calls.  It is exceptionally dense:
median densities range from 0.166 for calls to 0.706 for imported-by, p90
densities range from 0.331 to 0.878, and extinction is zero for all six
directions at the selected snapshot.  This signature was observed before any
Element maintenance metrics were available.
