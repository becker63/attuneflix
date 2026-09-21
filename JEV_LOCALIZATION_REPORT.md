# Jev Localization v1

Status: SWE-Explore semantic-prior protocol, corpus, observations, and all 15
rankings are frozen. A fresh-process replay reproduced them without a provider
call. The compiled evaluator interlude and the frozen 15-case Jev run are
complete. The first official line-level score and structural-oracle bound are
recorded below.

## Frozen population

The localization population remains the previously frozen 15 SWE-Explore cases:
11 Preact, 2 Axios, and 2 Immutable cases. Atlas remains the six directed
composition-only primitives through depth 7, with `CENTER_COUNT = 8`.

## Historical semantic-prior recipe

This recipe was recovered from the finished AttuneRadii checkout, its retained
metadata, and the historical `tools/acquire_prior.py` revision. It is frozen
before acquisition.

- Provider: OpenRouter.
- Endpoint: `https://openrouter.ai/api/v1/embeddings`.
- Model: `qwen/qwen3-embedding-8b`.
- Query instruction: `Given a software bug report, retrieve the source-code function most relevant to fixing it.`
- Query text: `Instruct: {instruction}\nQuery:{issue}`. There is deliberately
  no space after `Query:`.
- Historical candidate entities: callable rows whose Spider type was
  `function` or `method`, ordered by original `node_ord`. Other node kinds were
  excluded.
- Document text: `{node_id}\n{code}`.
- Historical node identity: path plus callable identity; methods can be
  qualified (for example `lib/core/AxiosHeaders.js:AxiosHeaders.get`).
- Text limit: 48,000 Python characters, for both query and document.
- Truncation marker: `\n...[truncated for embedding]...\n`.
- Truncation: retain equal head and tail portions, with
  `half = (48000 - marker.length) // 2`.
- Provider batching: 64 texts per request; the historical acquirer used four
  workers. Batch shape is transport, not per-text semantic identity.
- Historical observation key: SHA-256 of `model UTF-8 + NUL + text UTF-8`.
- Stored vectors: float32; retained vectors have 4,096 dimensions.
- Similarity: cosine similarity using explicit L2 norms; a zero norm scores
  zero. Vectors were not normalized before storage.
- Ranking: descending similarity, then original `node_ord`; this is a stable
  source-order tie break.
- Historical identity fingerprints covered model, instruction, document
  representation, text limit, node source, normalization code/data, and the
  acquisition implementation.

The new observation identity will retain these semantics explicitly rather
than relying on provider configuration hidden outside the key. It will include
provider, model, exact clipped input text, query/document role and instruction
semantics, request-shaping parameters, and protocol version. The API key is
transport configuration and is never part of this identity.

## Issue source

Issue text is pinned to the original upload of the official
`SWE-bench/SWE-bench_Multilingual` test data:

- dataset revision: `7566cd247075886ef34453ff5582908c0255f5e6`
- object: `data/test-00000-of-00001.parquet`
- SHA-256 (Nix SRI): `sha256-KLf4dOSEljmQd9J2+fKxY6B33fCnDcUHwUjVjagmuqk=`
- realised store object: `/nix/store/fva4w77cpkzz02407znx0a2raiz684f5-swe-bench-multilingual-test.parquet`

Exact identity joins were checked for all 15 cases. Repository and base commit
agree with the frozen Atlas population, and all 15 have non-empty
`problem_statement` values. The solver-side projection will contain only
instance identity, repository, base commit, and problem statement. Patch,
tests, and evaluator gold are excluded.

## SWE-Explore corpus epoch

The historical embedding and ranking procedure is reconstructed over the
current AttuneFlix SWE-Explore world, not over the retired Spider graph. The
frozen documents are every callable admitted by the permanent Grit `Defines`
program, in `Repository.World.symbols` order. Their provider-visible text is:

```text
repository-relative path:local callable name
exact UTF-8 source bytes in the admitted callable span
```

The retained semantic identity separately includes repository, base commit,
path, start byte, end byte, and local callable name. Methods deliberately use
the source-visible local name produced by current Grit; Spider's class-qualified
identity is not reconstructed or used as a compatibility gate. Consequently,
this is a new frozen observation corpus using the recovered historical model,
instruction, clipping, document shape, similarity, and ranking semantics. It
is not claimed to be byte-identical to the retired Spider prior.

An offline Flix-test census completed before acquisition:

```text
cases                         15
document instances        22,563
unique exact requests      3,894
```

The exact per-case document counts are retained by the test output and will be
written with the acquired ranking artifact.

| Case | Documents |
|---|---:|
| `axios__axios-4731` | 295 |
| `axios__axios-5085` | 707 |
| `immutable-js__immutable-js-2005` | 618 |
| `immutable-js__immutable-js-2006` | 618 |
| `preactjs__preact-2757` | 1,623 |
| `preactjs__preact-2896` | 1,683 |
| `preactjs__preact-3010` | 1,733 |
| `preactjs__preact-3454` | 1,761 |
| `preactjs__preact-3562` | 1,787 |
| `preactjs__preact-3689` | 1,817 |
| `preactjs__preact-3739` | 1,852 |
| `preactjs__preact-3763` | 1,868 |
| `preactjs__preact-4152` | 2,014 |
| `preactjs__preact-4182` | 2,065 |
| `preactjs__preact-4436` | 2,122 |

## JVM and Flix implementation

The JVM seam is one low-level LangChain4j 1.18.1 OpenAI-compatible embedding
client behind `AttuneEmbed.embed(model, textsJson)`. It constructs the
OpenRouter client, reads `OPENROUTER_API_KEY`, batches the supplied texts, and
projects the provider response to one stable JSON envelope. It owns no request
identity, retention, replay, corpus, ranking, or experiment semantics.

`Localization.Embed` is the public Flix capability. Native, replay, and fixture
handlers exist; observation identity, response validation, cosine ranking, and
the scientific protocol are Flix code. Durable retention will likewise remain
in Flix. No LangChain4j agent, RAG, memory, tool, vector-store, or prompt-
orchestration API is admitted.

The facade and its exact Maven closure are built as a Nix derivation. Pinned
Nixpkgs Java setup hooks construct `CLASSPATH` from `share/java` build inputs
and normalize the resulting archive. There is no Maven/Gradle/Ant project and
no handwritten XML.

## Acquisition

The offline preparation gate passed in 1,346.1 seconds and performed no
network calls. The subsequent explicit acquisition retained:

```text
artifact bytes              215,756,576
raw provider batches                 61
cases                                15
ranked document instances        22,563
unique exact requests              3,894
live observations                  3,894
provider input tokens            458,230
provider total tokens            458,230
```

Each provider batch was atomically retained as a raw response before local
admission. The ranking artifact SHA-256 is
`73efdb1159aeb0be552ae16bf53f52ca85755c29d2ea35f478fc5469f521c914`.

## Replay and 15-case prior gate

**PASS.** A fresh process read the 61 retained raw batches and reported:

```text
exact request replays        3,894
live provider calls              0
new provider tokens              0
admitted observation parity  exact
ranking equality             exact
Flix tests                   34 / 34
replay-test wall time        1,321.1 s
full-suite wall time         1,356.3 s
```

`.env` remains ignored, and the API key entered neither source nor retained
evidence. This evidence is now the frozen semantic prior for the 15-case Jev
experiment. The evaluator migration is downstream of the prior and must not
alter its provider, text, clipping, identity, admission, corpus, cosine, or
stable-ordinal ranking semantics.

## Compiled evaluator interlude

The scientific protocol remains frozen while the general policy-family
evaluator is replaced beneath it. The frozen population is 11 Preact, 2 Axios,
and 2 Immutable cases; the semantic prior is the one above; Atlas remains its
separate six-directed-atom, composition-only, depth-7 grammar; and
`CENTER_COUNT = 8`. No Jev question or benchmark gold is used during this
implementation interlude.

The production port is deliberately Flix-only. `Radii.Compiled` compiles a
stable ordered `Radii.Expr` family into shared `NodeId` nodes. Each call then
creates a fresh region containing a `Radii.Evaluate.State -> ArenaStateId` interner,
a state arena, and lazily allocated per-node dense rows. The compact result is
a vector of `ArenaStateId` values aligned with `Program.roots`, plus the arena.
`materializeLegacy` is retained only for parity/debugging. `Radii.Evaluate.StateId`
continues to mean the existing semantic Decide identity; it is not the compact
arena-relative integer.

No Java evaluator helper or new JVM dependency was retained. The production
module is 286 Flix LOC, versus 651 Flix LOC plus 161 Java LOC in the isolated
multi-ablation implementation. The old `Radii.Evaluate.evaluateAll` remains the
differential oracle during migration. Atlas and its separate grammar were not
changed.

Parity gates passed:

```text
public atoms                              12
normalized expressions through cost 4    79
synthetic three-way comparisons        1,185
synthetic mismatches                        0

Axios input                    FILE 37, lib/helpers/isAxiosError.js
File-compatible cost-7 roots                           2,463
compiled DAG nodes                                      3,164
interned query states                                     139
populated (NodeId, ArenaStateId) entries                 3,839
old/compiled result-map equality                         exact
root-order equality                                      exact
normal Flix tests                                      35 / 35
```

One in-process production-port timing check used 20 paired warmups and 100
forced paired samples. Compilation, Grit, repository admission, and legacy map
projection were outside the compact-kernel timer:

```text
compiled p50       3.127 ms
compiled p90       3.907 ms
compiled p95       4.155 ms
same-run old p50  16.542 ms       (5.29x)
isolated old p50  29.511 ms       (9.44x)
isolated dense     2.985 ms       (production within 4.8%)
```

The same-run comparison reflects a warmer/different host state than the
isolated profile, so both ratios are retained. The production extraction
preserves the intended order-of-magnitude result relative to the authoritative
isolated current-shared measurement without importing its Java/hash/profile
machinery.

## Frozen Jev protocol

The solver-side protocol is frozen before any live benchmark decision or gold
inspection:

```text
provider             OpenRouter
endpoint             POST https://openrouter.ai/api/alpha/decisions
model                typesafe/jev-1.13
protocol             attune-jev-localization-v1
question key         next_action
question type        choice
CENTER_COUNT         8
MAX_DEPTH            7

Symbol actions       stop, defined_in, calls, callers
File actions         defines, imports, imported_by
```

The exact question instruction is:

> Choose the next typed repository-structure action most likely to improve
> localization of the reported issue. Choose stop only when the current symbol
> preview is at least as useful as every available structural child.

The `state` string has the fixed `ATTUNE_LOCALIZATION_STATE_V1` header followed
by repository, base commit, issue text, current depth, the ordered structural
path, and the current preview. Each ordered choice criterion contains its
already-computed child preview. Symbol previews contain domain, cardinality,
and the first eight members in frozen semantic-prior order as `path :: symbol`.
File previews contain domain, cardinality, and the first eight files ordered by
their best frozen-prior symbol. The model sees no source body, history, gold,
or benchmark score.

The complete 3,279-path Atlas-shaped family is compiled once into the general
`Radii.Expr` evaluator. Every case is evaluated once as a shared compact DAG;
Jev only navigates its root-aligned results. A depth-seven result must be a
Symbol state, so a final File-producing edge is not offered and no hidden
`defines` step is added. Final localization is the frozen prior stably
partitioned by membership in the chosen Symbol state. Stopping at the root is
therefore exactly the semantic-prior baseline.

Decision identity includes the protocol, provider, endpoint, model, exact
model-visible payload, current semantic state, and ordered semantic
alternatives. The API key is transport-only. Raw OpenRouter responses are
atomically retained before admission under `.attune/jev-localization-v1`;
replay misses are explicit and never fall through to the network.

## Retained repository evidence

The first semantic-prior and Jev runs retained remote observations but
repeatedly reconstructed and then discarded repository facts. That was an
architectural defect: the 15 cases paid for all three Grit programs on every
fresh process even though their source snapshots are immutable.

Scientific preparation now uses `Repository.extractRetained`. Each artifact
contains the stable pre-resolution `Defines`, `Imports`, and `Calls`
observations. Its envelope validates:

```text
repository
base commit
exact Nix snapshot store path
Marzano revision c80b3026471b229f41b279c3eb0c162dcdacfdb1
SHA-256 of defines.grit
SHA-256 of imports.grit
SHA-256 of calls.grit
```

Resolution/admission deliberately reruns from retained facts, so resolver
changes do not require buying source observation again. Writes are atomic. The
15 frozen snapshots occupy 27 MiB under `.attune/repository-facts-v1`.

The first oracle run populated these artifacts and spent 1,032.4 seconds in
the heavyweight evaluator test. An immediate fresh-process replay produced
identical results in 58.7 seconds, a 17.6x reduction, with no native Grit
extraction. The entire 45-test suite took 97.0 seconds warm (111.5 seconds
including Nix-shell startup).

## First frozen localization result

Evaluator gold is separately pinned through Nix and never enters solver-side
case preparation:

```text
SWE-Explore benchmark revision  bdb0ae45d7c337d9e1dc3ebfe2a0af6bc7c1fbd9
official evaluator revision     5602f031f2d9562d0a805f83402b536e831a5a11
cases                            15
predicted source regions          5 per case
```

`JEV` means the frozen semantic prior plus Jev-selected structural promotion;
there is no Jev-only condition. `STRUCTURAL ORACLE` chooses, using gold only
inside the evaluator, the highest-line-F1 result among the root and every
Symbol-ending route in the same frozen depth-7 tree.

| Condition | Mean line F1 | Mean line recall | Mean HitFile |
|---|---:|---:|---:|
| PRIOR | 0.058493 | 0.075187 | 0.227778 |
| JEV | 0.078887 | 0.093466 | 0.205556 |
| STRUCTURAL ORACLE | 0.324831 | 0.295496 | 0.410000 |

Against PRIOR, Jev raises mean line F1 by 0.020394 (34.9% relative) and recall
by 0.018279 (24.3% relative), while lowering HitFile by 0.022222. Against Jev,
the oracle is 4.12x higher on mean F1 and 3.16x higher on mean recall. Thus the
frozen structural family contains substantial useful signal, but this first
Jev decision protocol captures only a small part of the available headroom.

The strongest positive case is `preactjs__preact-2896`:

```text
PRIOR F1             0.050955
JEV F1               0.340333
STRUCTURAL ORACLE    0.825499
```

There are also clear selection failures: `preactjs__preact-3739` scores zero
for PRIOR and JEV while its structural oracle reaches 0.502439, and
`preactjs__preact-4436` scores zero for PRIOR and JEV while its oracle reaches
0.803506. Two cases (`preactjs__preact-3010` and `preactjs__preact-4152`) have
zero oracle F1, demonstrating genuine failures of this candidate family rather
than route selection.

The oracle and all ordinary semantic/parity checks passed:

```text
Flix tests                  45 / 45
oracle result-map failures       0
warm score equality          exact
live embedding calls             0
live Jev calls                   0
```

## Complete official metric result

The Flix evaluator is a literal port of `quality/bench_metrics.py` at official
evaluator revision `5602f031f2d9562d0a805f83402b536e831a5a11`. Before oracle
rows were admitted, all 16 PRIOR and JEV aggregate metrics were differentially
checked against the pinned official Python evaluator to `1e-10`. The complete
per-case predictions and scores are retained in
`JEV_LOCALIZATION_RESULTS.json`.

### Micro aggregate (15 cases)

| Metric | PRIOR | JEV | STRUCTURAL ORACLE |
|---|---:|---:|---:|
| line precision | 0.286862 | 0.196199 | 0.640725 |
| line recall | 0.075187 | 0.093466 | 0.295496 |
| line F1 | 0.058493 | 0.078887 | 0.324831 |
| HitFile | 0.227778 | 0.205556 | 0.410000 |
| noise-file rate | 0.590000 | 0.643333 | 0.316667 |
| HitRegion | 0.152222 | 0.182222 | 0.347778 |
| noise-region rate | 0.626667 | 0.746667 | 0.266667 |
| weighted core coverage | 0.052784 | 0.073482 | 0.211935 |
| context efficiency | 0.407990 | 0.267742 | 0.735848 |
| nDCG@100 | 0.350386 | 0.306877 | 0.758407 |
| nDCG@300 | 0.383719 | 0.340210 | 0.826704 |
| nDCG@500 | 0.383719 | 0.382272 | 0.826704 |
| recall@100 | 0.023544 | 0.024071 | 0.189426 |
| recall@300 | 0.075187 | 0.092808 | 0.249015 |
| recall@500 | 0.075187 | 0.093466 | 0.281119 |
| first useful hit | 0.413333 | 0.413333 | 0.853333 |

### Macro aggregate (three repositories weighted equally)

| Metric | PRIOR | JEV | STRUCTURAL ORACLE |
|---|---:|---:|---:|
| line precision | 0.329562 | 0.266635 | 0.644638 |
| line recall | 0.057526 | 0.071906 | 0.262034 |
| line F1 | 0.065904 | 0.078740 | 0.245437 |
| HitFile | 0.219444 | 0.243434 | 0.545455 |
| noise-file rate | 0.575000 | 0.599242 | 0.212121 |
| HitRegion | 0.178283 | 0.219192 | 0.435354 |
| noise-region rate | 0.584848 | 0.666667 | 0.175758 |
| weighted core coverage | 0.044678 | 0.061524 | 0.209272 |
| context efficiency | 0.425024 | 0.316326 | 0.756554 |
| nDCG@100 | 0.431166 | 0.411389 | 0.890185 |
| nDCG@300 | 0.446317 | 0.426540 | 0.921229 |
| nDCG@500 | 0.446317 | 0.445659 | 0.921229 |
| recall@100 | 0.034052 | 0.035303 | 0.196004 |
| recall@300 | 0.057526 | 0.071607 | 0.240907 |
| recall@500 | 0.057526 | 0.071906 | 0.255499 |
| first useful hit | 0.460606 | 0.460606 | 0.933333 |

Jev therefore produces a real but sharply mixed tradeoff. Micro line F1 rises
34.9% and recall rises 24.3%; HitRegion and weighted coverage also improve.
Precision, HitFile, context efficiency, early nDCG, and both noise rates get
worse. The unchanged first-useful-hit aggregate means the treatment mostly
expands later useful coverage rather than moving the first useful region
earlier.

## Per-case paired result

`Captured` is `(JEV - PRIOR) / (ORACLE - PRIOR)` for line F1 when positive
oracle headroom exists.

| Instance | Prior F1 | Jev F1 | Delta | Oracle F1 | Captured | Jev path |
|---|---:|---:|---:|---:|---:|---|
| `axios__axios-4731` | 0.0000 | 0.0000 | +0.0000 | 0.0116 | 0.0% | defined_in -> defines -> defined_in -> defines -> defined_in -> defines |
| `axios__axios-5085` | 0.0000 | 0.0000 | +0.0000 | 0.2083 | 0.0% | calls -> defined_in -> defines -> defined_in -> defines -> defined_in -> defines |
| `immutable-js__immutable-js-2005` | 0.0895 | 0.0895 | +0.0000 | 0.1687 | 0.0% | stop |
| `immutable-js__immutable-js-2006` | 0.1988 | 0.2250 | +0.0262 | 0.3284 | 20.2% | calls |
| `preactjs__preact-2757` | 0.0000 | 0.0000 | +0.0000 | 0.2016 | 0.0% | stop |
| `preactjs__preact-2896` | 0.0510 | 0.3403 | +0.2894 | 0.8255 | 37.4% | calls -> callers -> callers -> defined_in -> defines -> defined_in -> defines |
| `preactjs__preact-3010` | 0.0000 | 0.0000 | +0.0000 | 0.0000 | n/a | defined_in -> defines -> defined_in -> defines -> defined_in -> defines -> callers |
| `preactjs__preact-3454` | 0.4026 | 0.4026 | +0.0000 | 0.5728 | 0.0% | defined_in -> defines -> defined_in -> defines -> defined_in -> defines |
| `preactjs__preact-3562` | 0.0167 | 0.0167 | +0.0000 | 0.3255 | 0.0% | defined_in -> defines -> defined_in -> defines -> defined_in -> defines |
| `preactjs__preact-3689` | 0.0695 | 0.0839 | +0.0144 | 0.4286 | 4.0% | defined_in -> defines -> calls -> defined_in -> defines -> defined_in -> defines |
| `preactjs__preact-3739` | 0.0000 | 0.0000 | +0.0000 | 0.5024 | 0.0% | calls |
| `preactjs__preact-3763` | 0.0000 | 0.0000 | +0.0000 | 0.1663 | 0.0% | defined_in -> defines -> defined_in -> defines -> defined_in -> defines -> calls |
| `preactjs__preact-4152` | 0.0000 | 0.0000 | +0.0000 | 0.0000 | n/a | defined_in -> defines -> calls -> defined_in -> imported_by -> defines -> calls |
| `preactjs__preact-4182` | 0.0493 | 0.0252 | -0.0241 | 0.3292 | -8.6% | defined_in -> defines -> calls -> defined_in -> defines -> calls -> callers |
| `preactjs__preact-4436` | 0.0000 | 0.0000 | +0.0000 | 0.8035 | 0.0% | calls |

On F1, Jev improves 3/15 cases, ties 11/15, and worsens 1/15. Positive
aggregate headroom captured is 7.66% micro and 7.15% macro. Thirteen cases
have a better route in the frozen tree; Jev captures positive headroom in only
three. Two cases have no F1 headroom at all under the frozen projection.

## Repository behavior

| Repository | n | Prior F1 | Jev F1 | Oracle F1 | Mean delta | Improved / tied / worsened |
|---|---:|---:|---:|---:|---:|---:|
| Axios | 2 | 0.000000 | 0.000000 | 0.109981 | 0.000000 | 0 / 2 / 0 |
| Immutable | 2 | 0.144158 | 0.157236 | 0.248569 | +0.013078 | 1 / 1 / 0 |
| Preact | 11 | 0.053553 | 0.078985 | 0.377760 | +0.025432 | 2 / 8 / 1 |

Axios falsifies useful Jev selection in this sample despite measurable oracle
headroom. Immutable shows a small clean improvement. Preact supplies almost
all aggregate gain, dominated by one very strong case, while also containing
the only regression and both no-headroom cases.

## Decision behavior and cost

Exact replay reconstructed all 78 retained decisions with no API key and no
network calls:

```text
decisions                         78
input tokens                  98,358
output tokens                  3,503
provider cost              $0.004131036
mean / median confidence       0.476 / 0.425
mean / median chosen prob.     0.617 / 0.565
returned model                 typesafe/jev-1.13-20260917 (78/78)

choices
    defined_in                    27
    defines                       27
    calls                         11
    stop                           8
    callers                        4
    imported_by                    1

final structural depth
    depth 0                        2 cases
    depth 1                        3 cases
    depth 6                        3 cases
    depth 7                        7 cases
```

The alternating `defined_in -> defines` pattern is prominent. It frequently
returns to a broad same-file symbol frontier without adding useful issue-
specific discrimination. This is descriptive post-hoc evidence, not a prompt
change. Provider latency was not persisted during the original paid
acquisition and cannot be recovered honestly from retained responses; it is
therefore recorded as unavailable. Replay wall time is not provider latency.

## Structural physical work

The repository-independent program is compiled once:

```text
logical non-root routes             3,279
Symbol-ending routes                1,643
compiled DAG nodes                  3,282
```

Across the 15 query-local arenas:

```text
states interned                    14,159
populated (NodeId, StateId) cells  68,034
allocated dense-memo slots         86,772
precompute wall total            1,481.5 ms
precompute mean / median            98.8 / 77.3 ms
precompute range                    19.1 .. 228.4 ms
```

The compact production kernel intentionally removed the old evaluator's hot
transition/subtree counters. `memo_entries` is now the exact count of physical
compiled-node/state evaluations and `states_interned` the exact query-local
semantic-state cardinality. Richer historical counters are not reconstructed
or charged to production queries.

## Frozen identities

```text
working-copy revision at freeze    4209a88d72ed (jj change tvqmmxrovzww)

defines.grit SHA-256                bba7b2aa5d958d3ea2369fae0b7025718d68fcd1ea10bdfc1351c676899552cb
imports.grit SHA-256                368c1c09ed1ba38437ddab45d1084710cb717adc8dc0c831e3b2e8c49f3ad14d
calls.grit SHA-256                  de0e5436777fc93f96a517298386e5e728cd77fe5e46a027a5ae942287212147

Jev schema SHA-256                  fd12a2fb9d2f3c00adb338c19eb3382e61d8621f6ff70487afd05a80ce9cb55b
semantic-prior ranking SHA-256      73efdb1159aeb0be552ae16bf53f52ca85755c29d2ea35f478fc5469f521c914
Jev outcome SHA-256                 0c7138eb48dadfdba7647fe3186156c9f2cc6d2ead84df23523c33c61f8c7dee
prediction/result SHA-256           70cedc1753711ec4acba7f547c4a4ad2f623a2ca48b98aea5d97c8c8d62dd541
```

The schema hash is over the canonical sorted JSON description of protocol,
provider, endpoint, model, question key/type/instructions, state fields,
choice order, preview count, and maximum depth. Exact request identities also
include each full model-visible payload and ordered semantic alternatives.

## Leakage and replay audit

- Solver cases and evaluator evidence are separate Flix types and separate Nix
  acquisition methods.
- The issue fixture contains no gold fields; tests enforce that projection.
- The Jev request builder cannot accept evaluator evidence.
- Gold is opened only by `JevOracleTest` after retained outcomes exist.
- PRIOR, JEV, and oracle use the same five-region budget and byte-to-inclusive-
  line projection.
- `.env` is ignored. The replay and oracle runs explicitly removed
  `OPENROUTER_API_KEY` and made zero provider calls.
- All 45 Flix tests pass, including Datalog/physical parity, Atlas counts,
  compiled-evaluator parity, replay identity, and leakage laws.

## Scientific conclusion

The experiment lands in a mixture of the preregistered cases B, C, and D:

1. **Structural headroom is real.** Oracle F1 is 0.3248 versus prior 0.0585;
   the six-atom frozen tree is not the limiting factor for 13/15 cases.
2. **This frozen Jev interface captures some headroom.** Aggregate F1 and
   recall improve, and three cases show positive paired gains.
3. **Selection remains the dominant failure.** Jev captures only about 7.7%
   of aggregate F1 headroom, ties the baseline in 11 cases, and misses several
   routes with very large evaluator-side gains.
4. **The gain is not free.** Coverage rises while precision, noise, early
   ranking quality, and context efficiency degrade.

This establishes that issue-conditioned typed decisions can sometimes exploit
cheap precomputed structure, but it does not establish that Jev v1 is a
reliable selector or that the current tradeoff dominates the semantic prior.

## What this does not establish

- No full-agent repair or end-to-end coding-session speedup is measured.
- The 15 cases are deliberately small and not a population estimate.
- Oracle paths are evaluator-only and not deployable.
- No prompt/model/schema retuning has been performed after opening gold.
- No persistent policy-state memoization, history signal, embeddings beyond
  the frozen prior, or new relation was tested.
