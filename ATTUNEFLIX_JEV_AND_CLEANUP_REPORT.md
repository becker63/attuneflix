# AttuneFlix Jev v1 and cleanup handoff

Date: 2026-09-21

This report closes the first frozen SWE-Explore Jev localization experiment
and its post-experiment cleanup. The detailed scientific ledger is
`JEV_LOCALIZATION_REPORT.md`; the complete per-case official results are in
`JEV_LOCALIZATION_RESULTS.json`.

## Outcome

The experiment distinguishes structural availability from decision quality.
The frozen six-atom, depth-seven tree contains substantial localization
headroom, and the first Jev interface captures a small but real part of it.
It does not yet select useful paths reliably.

| Condition | line precision | line recall | line F1 | HitFile | context efficiency |
|---|---:|---:|---:|---:|---:|
| PRIOR | 0.286862 | 0.075187 | 0.058493 | 0.227778 | 0.407990 |
| PRIOR + JEV | 0.196199 | 0.093466 | 0.078887 | 0.205556 | 0.267742 |
| STRUCTURAL ORACLE | 0.640725 | 0.295496 | 0.324831 | 0.410000 | 0.735848 |

Jev improves micro line F1 by 0.020394, or 34.9% relative, and recall by
24.3% relative. Precision, HitFile, early nDCG, noise, and context efficiency
get worse. The oracle is 4.12x Jev's F1 and 3.16x its recall. Jev captures
about 7.66% of the available micro F1 headroom.

### Repository behavior

| Repository | n | PRIOR F1 | JEV F1 | Oracle F1 | improved / tied / worsened |
|---|---:|---:|---:|---:|---:|
| Axios | 2 | 0.000000 | 0.000000 | 0.109981 | 0 / 2 / 0 |
| Immutable | 2 | 0.144158 | 0.157236 | 0.248569 | 1 / 1 / 0 |
| Preact | 11 | 0.053553 | 0.078985 | 0.377760 | 2 / 8 / 1 |

Across all cases Jev improves 3, ties 11, and worsens 1. Thirteen cases have
positive structural headroom; Jev captures positive headroom in only three.
Two cases have no F1 headroom under the frozen language and projection.

The strongest positive case is `preactjs__preact-2896`: F1 moves from
0.050955 to 0.340333, against an oracle of 0.825499. Important selection
failures include `preactjs__preact-3739` and `preactjs__preact-4436`, where
Jev stays at zero while the oracle reaches 0.502439 and 0.803506.

## Frozen protocol and evidence

Population:

```text
15 SWE-Explore cases
11 Preact
 2 Axios
 2 Immutable

CENTER_COUNT = 8
MAX_DEPTH    = 7
Atlas paths = six directed atoms, composition only
```

Semantic prior:

```text
provider          OpenRouter
model             qwen/qwen3-embedding-8b
documents         22,563
unique requests    3,894
raw batches           61
input tokens      458,230
artifact bytes    215,756,576
```

The recovered historical instruction, document form, 48,000-code-point
clipping, cosine ranking, and stable source-ordinal tie break are recorded in
the detailed ledger. The exact 15/15 issue join uses pinned SWE-bench
Multilingual revision `7566cd247075886ef34453ff5582908c0255f5e6`.

Jev:

```text
provider           OpenRouter
endpoint           /api/alpha/decisions
requested model    typesafe/jev-1.13
returned model     typesafe/jev-1.13-20260917 (78/78)
retained decisions 78
input tokens       98,358
output tokens       3,503
provider cost      $0.004131036
provider latency   unavailable (not retained during acquisition)
```

Embedding cost was not returned in a retained provider field and is therefore
not inferred. No paid-call latency is reconstructed from replay time.

### Operating regimes

The run did not retain enough provider timing to manufacture a product-latency
number. The three regimes therefore remain deliberately separate:

| Regime | Evidence from this run |
|---|---|
| Cold repository/prior | Offline corpus preparation was 1,346.1 s before retained embedding acquisition; the paid acquisition wall time was not retained as one comparable measurement. |
| Warm repository, new issue | Existing document vectors are reusable and structural precomputation averaged 98.8 ms/case, but new query-embedding and live Jev latency were not retained. No sub-second claim is made. |
| Full replay | The final 15-case embedding + Jev + oracle + full-test gate took 174.6 s, made zero network calls, and included evaluator/oracle work that is not part of a production query. |

These numbers must not be blended. In particular, full-suite replay is neither
provider latency nor the warm per-issue product path.

### Frozen identities

```text
Marzano/Grit revision
    c80b3026471b229f41b279c3eb0c162dcdacfdb1

defines.grit
    bba7b2aa5d958d3ea2369fae0b7025718d68fcd1ea10bdfc1351c676899552cb
imports.grit
    368c1c09ed1ba38437ddab45d1084710cb717adc8dc0c831e3b2e8c49f3ad14d
calls.grit
    de0e5436777fc93f96a517298386e5e728cd77fe5e46a027a5ae942287212147

Jev request schema
    fd12a2fb9d2f3c00adb338c19eb3382e61d8621f6ff70487afd05a80ce9cb55b
semantic-prior ranking
    73efdb1159aeb0be552ae16bf53f52ca85755c29d2ea35f478fc5469f521c914
experiment-frozen Jev outcome envelope
    0c7138eb48dadfdba7647fe3186156c9f2cc6d2ead84df23523c33c61f8c7dee
post-cleanup replay outcome envelope
    0901bf208bcf98ccdfce0c6281e9990f90b4823d8fd68ea0780e484cceb7636c
official prediction/result JSON
    70cedc1753711ec4acba7f547c4a4ad2f623a2ca48b98aea5d97c8c8d62dd541
```

The two outcome-envelope hashes differ only because that internal artifact
contains fresh `precompute_nanos`. Decisions, probabilities, paths, rankings,
predicted regions, and official metrics replay exactly. The official result
JSON remains byte-for-byte identical to the committed result copy. Timing is
telemetry, not semantic identity.

## Decision behavior

```text
choices
    defined_in  27
    defines     27
    calls       11
    stop         8
    callers      4
    imported_by  1

final depth
    0  2 cases
    1  3 cases
    6  3 cases
    7  7 cases

mean / median confidence           0.476 / 0.425
mean / median chosen probability   0.617 / 0.565
```

The common `defined_in -> defines` alternation often returns to a broad
same-file frontier without adding issue-specific discrimination. This is a
post-hoc description, not a prompt change.

## Structural execution

The policy family is compiled once, independent of repository and query:

```text
logical non-root routes              3,279
Symbol-ending routes                 1,643
compiled DAG nodes                   3,282
```

Each localization query creates a fresh region-scoped arena and dense memo:

```text
Program        stable policy-family lifetime
StateArena     one query lifetime
DenseMemo      one query lifetime
output         root-aligned Vector[ArenaStateId] + arena
legacy Map     parity/debug only
```

Across 15 cases:

```text
states interned                    14,159
populated node/state memo cells    68,034
allocated dense-memo slots         86,772
precompute wall total             1,481.5 ms
precompute mean / median             98.8 / 77.3 ms
```

The production evaluator is 286 lines of pure Flix. It retains nominal
semantic `StateId` separately from query-local `ArenaStateId`, uses collision-
safe structural state equality, and has no Java evaluator helper, OpenHFT,
XXH3, bitmap, session-global arena, or persistent policy-state memo.

The quiet production-port measurement was:

```text
compiled p50   3.127 ms
compiled p90   3.907 ms
compiled p95   4.155 ms
old p50       16.542 ms in the same process
old shared    29.511 ms in the isolated reference profile
```

The final all-gates replay ran concurrently with another CPU-bound Flix
process and measured 12.582 ms p50; that loaded-host number is retained as
telemetry, not evidence of a semantic or architectural regression.

## Repository-fact memoization

Immutable source observation is now retained before resolver admission under
`.attune/repository-facts-v1`. The key validates repository, base commit,
exact Nix store path, Marzano revision, and all three Grit program hashes.
Resolver changes re-admit retained facts instead of rerunning Marzano.

```text
frozen fact artifacts                 15
artifact bytes                27,974,538
cold oracle run                 1,032.4 s
warm fresh-process run             58.7 s
warm native Grit executions            0
result equality                    exact
speedup                            17.6x
```

This is durable repository evidence. It is distinct from process-local
compiled-Problem reuse and from query-local policy DAG memoization.

## Dual structural semantics

The architecture permanently retains both implementations:

```text
Repository.Structure / Repository.Reference
    typed Flix Datalog oracle; defines meaning

Repository.Physical + Radii.Compiled
    indexed relation application and compact DAG; defines execution
```

Every public atom and all 79 normalized expressions through cost four are
differentially checked over deterministic worlds and compatible empty,
singleton, and full states. The real Axios 2,463-policy result map also agrees
exactly. Datalog remains the readable oracle and does not run in the production
hot path. The indexed Set backend is sufficient for this stage; no bitmap or
native relation backend is justified by current measurements.

## Cleanup

### Before

```text
src/
  Atlas.flix
  CompiledSemantics.flix
  Decide.flix
  Grit.flix
  History.flix
  Localization.flix
  LocalizationTree.flix
  Main.flix
  Nix.flix
  ParityTest.flix
  Physical.flix
  Policy.flix
  Reference.flix
  Repository.flix
  Semantics.flix
  Structure.flix
  Synthesis.flix
  Test.flix
```

### After

```text
src/
  Repository.flix
  Repository/
    Grit.flix
    Nix.flix
    Physical.flix
    Reference.flix
    Structure.flix

  Radii.flix
  Radii/
    Compiled.flix
    Evaluate.flix
    Synthesize.flix

  Atlas.flix
  Decide.flix
  Localization.flix
  Localization/
    Tree.flix

  Main.flix

test/
  CoreTest.flix
  ParityTest.flix
  TreeReuseTest.flix
  ... localization, prior, Decide, and oracle tests
```

The top-level science nouns are now:

```text
Repository
Radii
Atlas
Decide
Localization
```

`Experiment` is represented by ordinary Flix test modules and frozen reports,
not by a production framework. No generic Experiment helper was extracted:
after deleting the one-off maintenance reporter, no operation was repeated
across two experiments strongly enough to justify another public API.

### Source-size change

| Measure | Before | After | Change |
|---|---:|---:|---:|
| raw `src/*.flix` LOC | 6,019 | 4,108 | -1,911 |
| `test/*.flix` LOC | 1,608 | 2,393 | +785 |
| total Flix LOC | 7,627 | 6,501 | -1,126 |
| public Flix product types | 88 | 85 | -3 |
| raw-IO signatures in `src` | 12 | 11 | -1 |

Current handwritten source by language:

```text
Flix production    4,108 LOC
Flix tests         2,393 LOC
Rust                 408 LOC
Java production      561 LOC
Java tests           261 LOC
Nix                   671 LOC
shell build/check      60 LOC
```

Generated jextract bindings are build output and are excluded. The Java code
remains confined to the Grit FFM facade, Nix native facade, and low-level
LangChain4j/OpenRouter transport. No evaluator, identity hashing, ranking,
retention, or experiment semantics moved into Java.

### Deleted or internalized machinery

- Deleted the 1,125-line one-off `History.flix` reporting implementation.
- Deleted both ad-hoc Git-history shell runners after freezing `REPLICATION.md`
  and `replication.tsv`.
- Removed benchmark dispatch from `Main.flix` (71 lines to 3).
- Removed generated `repomix-output.xml` and ignored future copies.
- Moved all `@Test` modules out of production source.
- Replaced peer nouns `Policy`, `Synthesis`, `Semantics`, and
  `CompiledSemantics` with `Radii`, `Radii.Synthesize`, `Radii.Evaluate`, and
  `Radii.Compiled`.
- Nested Grit, Nix, physical relations, Datalog reference semantics, and typed
  repository structure beneath `Repository`.
- Nested the frozen decision tree beneath `Localization`.
- Replaced the 924-line tree-reuse measurement harness with a 67-line normal
  Flix law while preserving the complete 208-cell `TREE_REUSE_REPORT.md`.

Flix itself replaces Python-era effect frameworks, service protocols,
dependency injection, runtime domain tags at repository predicates, cache
ownership objects, query frameworks, and pytest fixture substitution. Regions
keep mutable evaluator state pure externally; effects make Grit, Nix,
embedding, and Decide capabilities explicit; first-class constraints keep the
Datalog catalog composable; nominal IDs prevent File/Symbol/Location mixing.

## Verification

Normal keyless suite after cleanup:

```text
46 passed
0 failed
0 skipped
```

Explicit all-gates keyless replay:

```text
ATTUNE_PRIOR_MODE=acquire
ATTUNE_JEV_MODE=replay
ATTUNE_JEV_EVALUATE=oracle
OPENROUTER_API_KEY absent

embedding replays             3,894
embedding live calls              0
embedding ranking equality    exact
Jev decisions replayed           78
Jev live calls                     0
official result equality      exact
tests passed                  46/46
elapsed                       174.6 s
```

Other enforced laws:

```text
Datalog / physical atom parity                  green
79-expression bounded differential parity       green
Atlas counts 3279 / 1643                         exact
Axios current semantic fingerprint               exact
Axios 2,463-policy old/compiled result map        exact
compiled root ordering                           exact
tree-reuse shared/independent result maps         exact
issue/gold type separation                       green
official Python evaluator differential parity    32/32 aggregates
```

Canonical repository check remains `./verify`; it builds the Nix-owned native
leaves, runs their lifetime tests, and runs the Flix suite. The explicit paid
or heavyweight modes are opt-in test modes, never `Main` dispatch.

## Security audit

```text
.env ignored                                  yes
actual OPENROUTER_API_KEY outside .env        not found
Authorization/Bearer value in retained data   not found
normal tests require key                      no
replay/oracle with key removed                passed
live acquisition requires explicit mode       yes
```

The native transport necessarily contains the literal header construction
`Authorization: Bearer <runtime key>`; the runtime value appears nowhere in
source, fixtures, reports, or retained observations. Raw retained provider
responses contain model-visible issue state and provider response IDs, but no
authorization header. They remain ignored scientific evidence, separate from
source and compact result fixtures.

## Version-control state

The stable working-copy change ID is `tvqmmxrovzww`. Its parent is commit
`4579918faec2` (`Run the frozen Atlas fixture end to end`). Earlier important
commits are `3cd375f7da63` (Grit FFM hardening/Nix packaging) and
`7fbbf56717b1` (native Flix core with dual semantics).

The working copy remains intentionally dirty: it contains the completed Jev
experiment, retained report/result fixtures, compiled evaluator, fact cache
support, Nix evaluation inputs, namespace cleanup, and tests. Ignored remote
observations and repository facts remain under `.attune/`; no reference
checkout was modified.

## Remaining debt and limits

- This is 15 cases, not a population estimate or repair-success experiment.
- Provider latency was not retained, so the earlier sub-second warm product
  prior is not validated by this run.
- The semantic-prior corpus uses current Grit callable identity rather than
  reproducing the retired Spider graph byte-for-byte.
- The current Jev request makes a useful choice in only a minority of cases.
- Fresh precompute timing is still stored beside semantic outcomes; the
  official result fixture is deterministic, but the internal outcome envelope
  is not byte-stable across replay.
- The old region-memo evaluator remains as the independent differential oracle.
- No persistent policy-state memo, cross-query arena, new relation, history
  signal, or learned fusion was introduced.

## What is now established

1. The recovered Qwen/OpenRouter semantic prior can be retained and replayed
   exactly without network access.
2. Immutable Grit facts can be durably reused with truthful Nix/program
   identity, making fresh-process structural science dramatically cheaper.
3. A large structural family compiles to a small, pure Flix DAG evaluator with
   exact Datalog/legacy parity and low-single-digit-millisecond quiet-host cost.
4. The frozen structural language contains large localization headroom on
   13/15 cases.
5. Typed Jev decisions sometimes exploit that headroom and improve aggregate
   recall/F1, but v1 selection is weak and incurs precision/noise costs.

## What remains a hypothesis

1. That a better frozen decision representation or model can capture a large
   fraction of structural-oracle headroom.
2. That warm localization can reach the projected 0.5--0.8 second product
   regime; provider latency was not measured here.
3. That these localization gains improve downstream repair success.
4. That durable policy-state memoization is worthwhile beyond retained source
   facts and process-local DAG reuse.

## Next smallest experiment

Preregister one selection-only follow-up over the same frozen 15 cases and
unchanged prior/tree, changing exactly one model-visible decision factor. Do
not alter relations, embeddings, projection, or evaluator. The purpose should
be to test why Jev leaves so much existing oracle headroom unused, not to add
another heuristic channel.
