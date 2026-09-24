# Attune Radii — SWE-Explore-First Refactor + Policy-Grammar / Reuse Architecture DETAILED SPEC

**Date:** 2026-09-20  
**Status:** Canonical active implementation specification — science-closeout + refactor execution edition  
**Project:** `attuneradii`  
**Supersedes:** the September 19 detailed Atlas/reuse spec, the September 18 SWE-Explore-first specs, and the September 17 refactor handoff  
**Primary implementation language:** Python 3.13  
**Native structural boundary:** Rust + PyO3/maturin  
**Deterministic Python memoization:** Rote  
**Effect system:** effect-python  
**Immutable external inputs:** Nix  
**Remote/model observation identity:** ObservationStore  
**Model partial-compute reuse:** provider KV/prefix cache where supported  
**First external benchmark:** SWE-Explore  

**2026-09-20 revision focus:** Close the MUI old-world science series; distinguish the fixed composition-only Atlas replication grammar from the richer post-Atlas policy-synthesis grammar; record the row-transition, relation-quotient, mixed-operator, bounded-cost, actual-vocabulary, canonical-bitmap, and fresh-process Rote results; make selection/reuse rather than exhaustive algebra closure the governing interpretation; and turn the current checkout into a small, strict, pytest-only refactor target.

---

# 0. Read this first — science is closed, implementation resumes

The old-world MUI science series is now complete enough to stop extending it.

The project is no longer waiting for another pre-refactor falsification experiment. The final sequence established all of the following strongly enough to proceed:

```text
repository structural regime survives issue removal
    +
small source-semantic basis has high reachability
    +
whole relations are mostly genuinely distinct
    +
row/state computation recurs extremely heavily
    +
public union materially expands policy semantics
    +
complete mixed algebra is far too generative to close exhaustively
    +
actual policy vocabulary remains highly generative at modest cost
    +
fresh-process Rote replay works when the deterministic boundary is honest
```

The immediate objective is therefore implementation, deletion, compression, and the first clean SWE-Explore Atlas path.

The governing sequence is now:

```text
freeze old-world scientific record in this spec
    ↓
compress the current repository around the architecture that survived
    ↓
make pytest the single execution / quality authority
    ↓
finish repository-native Grit facts + Rote reuse boundaries cleanly
    ↓
remove active SpIDER / temporary experiment machinery
    ↓
run the fixed Atlas replication grammar on SWE-Explore
    ↓
issue-conditioned SWE-Explore evaluation
    ↓
post-Atlas costed policy synthesis over the richer public grammar
```

Do not reopen the old algebra-census sequence merely because another depth, operator, ceiling, or repository could be measured. New science should now be driven by SWE-Explore, a concrete implementation blocker, or a direct policy-synthesis question.

## 0.1 Two grammars now exist and they have different jobs

This distinction is authoritative.

### Atlas replication grammar

The Atlas is a measurement protocol intended to reproduce and broaden the MUI/Vue/Darkreader structural-geometry result.

It uses only the six directed source relations:

```text
defines        File   -> Symbol
defined_in     Symbol -> File
imports        File   -> File
imported_by    File   -> File
calls          Symbol -> Symbol
callers        Symbol -> Symbol
```

and only unary typed composition through depth 7.

It deliberately does **not** recursively enumerate binary union or the full public policy grammar.

Its purpose is comparability, structural measurement, and a bounded external Atlas population.

### Policy-synthesis grammar

The eventual policy synthesizer reasons over the named public vocabulary and the public algebra:

```text
named concepts
    defines
    defined_in
    imports
    imported_by
    calls
    callers
    callees
    same_file
    import_neighbors
    importer_neighbors
    parent
    repository_adjacent

operators
    ~
    >>
    |
```

Named derived concepts are policy-level atoms even when their implementation expands compositionally. The policy author should be charged for the concept it writes, not for hidden implementation expansion.

Intersection `&` and difference `-` remain `Relation`-level scientific operators only. They are not public `Query` operators.

## 0.2 The strongest current scientific interpretation

The old-world experiments found **no small closed repository algebra worth compiling exhaustively**.

They instead found:

> **A small source-semantic basis generates a large and highly expressive policy language, while the physical row/state computations used to evaluate that language recur enormously. Attune should therefore optimize policy selection, semantic-state reuse, and durable computation reuse rather than attempt exhaustive algebra closure.**

This is the new architectural center.

## 0.3 Reuse remains co-equal with structural correctness

The governing long-term principle remains:

> **Acquire or compute a semantic fact once under the narrowest truthful identity, retain it at the layer that owns that identity, and make future exploration pay only for genuinely new work.**

The reuse hierarchy is still:

```text
immutable external artifact
    -> Nix store identity

deterministic Python transformation
    -> Rote dependency/source/input identity

repository source blob / admitted fact shard
    -> content identity + primitive/tool identity

compact relation row / process-local semantic state
    -> algorithmic interning / transition reuse

meaningful deterministic search/policy stage
    -> Rote durable replay where the boundary is worth persisting

exact remote/model request
    -> ObservationStore RequestId
    -> zero provider work on replay

new model request sharing an exact stable prefix
    -> provider KV/prompt-cache reuse where supported

process-scoped capability construction
    -> effect-python layer/runtime ownership
```

These identities must remain distinct.

## 0.4 Current checkout is already partway through the migration

Do not restart the migration from the historical Phase 0 plan.

At revision `87d1137a` / current working-copy parent, the checkout already contains:

```text
Rust + PyO3 Marzano/Grit adapter
pinned Marzano revision
TypeScript defines/imports/calls Grit programs
PyRoaring finite Relation implementation
public Query with ~, >>, |
named structural vocabulary
repository-native Atlas.build path
Rote-cached primitive fact and repository-resolution payloads
issue-blind structural-signature code
ObservationStore exact replay
Pydantic AI model / embedding effects
effect-python Nix capability
Fixit/LibCST Attune architecture law
pytest session quality gates
strict BasedPyright all-mode
refactor-compression checker logic currently exposed as a Nix app
```

The job is now to **compress, consolidate, delete transitional machinery, and finish the clean path from this actual state**.

## 0.5 One execution entrypoint: pytest

This is locked.

Human and agent verification has one canonical entrypoint:

```text
pytest
```

`pytest` owns the full quality/scientific gate. It may invoke pinned subprocess tools internally, but developers and agents should not need a second verification command.

The existing refactor-compression checker must **not disappear**. Its logic must be folded into pytest so that the same pytest invocation enforces:

```text
Ruff formatting
Ruff lint
Flake8 / Wemake constraints
Fixit rule self-tests
Fixit architecture lint
BasedPyright all-mode
interrogate 100% law
Grit semantic documentation/examples
architecture/effect/Rote laws
refactor subset/layout law
refactor LOC/file-count pressure
native checks that are worth keeping as canonical gates
scientific pytest laws
```

The standalone `refactor-check` command is not a second authority. Preserve the law; absorb the invocation into pytest.

Targeted pytest invocations are allowed during implementation, but they still pass through the same session-level quality gate.

## 0.6 Slow warm pytest is a correctness/performance smell

Tests and linters must stay on. Do not skip or weaken them merely because they are expensive.

But a repeatedly warm pytest run that becomes materially slow is itself evidence of a reuse/identity problem.

When warm pytest gets unexpectedly expensive, investigate:

```text
Rote invalidation boundary too broad
Rote key accidentally includes volatile state
native/Grit work bypassing durable reuse
Nix rebuild caused by unnecessary dependency coupling
ObservationStore replay bypassed
large relation/state materialization repeated unnecessarily
test fixture reacquiring immutable inputs
quality tool doing avoidable duplicated work
```

Do not respond by disabling the law.

The desired guarantee is:

> **We ran the law again, but unchanged expensive inputs and deterministic work replayed cheaply.**

## 0.7 Size pressure is architectural, not cosmetic

Current `scc` at the science-closeout checkpoint reported approximately:

```text
Python files:    28
Python code:     5,250 lines
Rust code:          99 lines
Nix code:          179 lines
```

The production Python pressure target remains:

```text
< ~2000 executable-ish production Python LOC
```

Tests may remain larger where they encode real static/scientific laws.

The route to the target is deletion and consolidation, not line golf or hiding code from counters.

During the refactor, preserve the stronger relative law as well:

```text
tracked src + tests Python LOC must not increase versus the frozen refactor baseline
tracked src + tests Python file count must not increase versus the frozen refactor baseline
new source modules must remain inside the accepted narrow layout
```

Use `87d1137a` as the stable historical baseline for this refactor gate rather than relying on a moving parent if the agent creates intermediate jj commits.

## 0.8 Storage policy

The machine currently has roughly 131 GiB free, so pre-emptive cleanup is unnecessary.

The implementation agent is authorized to manage the Nix store and other local storage, including deleting regeneratable artifacts outside this project when genuinely useful.

However, **heavy storage growth is an extremely strong architectural smell** for Attune because the project thesis is aggressive reuse under truthful identities.

Before accepting large new disk usage, ask whether the system is accidentally duplicating:

```text
repository snapshots
source blobs
Grit vendor/build trees
Rote values under over-specific identities
native relation materializations
benchmark normalization outputs
provider/model observations
profiling artifacts
Nix closures that should share dependencies
```

Prefer content identity, one immutable artifact, and replay.

Safe cleanup candidates may include regeneratable Nix store paths after confirming roots, build targets, transient profiler captures, and ignored scratch experiments when they are no longer scientifically needed.

Never delete source, uncommitted user work, unique scientific evidence, or retained provider/model observations merely to make a number smaller. ObservationStore contents represent already-paid-for observations and should be treated as valuable unless explicitly known to be disposable.

---

# 1. Science closeout — final old-world empirical record

This section is authoritative for the September 20 transition from experiment mode to implementation mode.

## 1.1 Repository geometry survives issue removal

The deterministic issue-blind seed ablation preserved the repository regimes:

```text
mean issue-blind Symbol-frontier density

Darkreader   0.5730
MUI          0.0410
Vue core     0.4941
```

The exact values moved with seed location, but the structural regimes did not collapse.

The strongest current statement is:

> **Issues choose where exploration begins; repository structure strongly determines how exploration propagates.**

This is sufficient motivation for the SWE-Explore structural Atlas.

## 1.2 Exact frontier recurrence was useful but not the deepest layer

The depth-7 composition tree contained:

```text
logical programs / transitions     3279
physical exact frontier transitions 1575
whole-frontier reuse                  2.082x
```

Whole-frontier caching matters, but later decomposition showed that much stronger recurrence exists below the frontier level.

Historical fine-grained recurrence included approximately:

```text
logical node requests            1,003,047
physical node requests             924,516
unique (atom,node) evidence          56,640
frontier memo reuse                   1.085x
remaining node recurrence             16.323x
total node evidence reuse              17.709x

logical requested memberships     2,561,315
physical requested memberships    2,348,001
unique evidence memberships          77,576
total membership reuse                33.017x
```

The lesson is not "cache whole frontiers harder." It is that large exploration trees repeatedly consume the same local relation evidence.

## 1.3 Global support/core compression was falsified

A dedicated support-stability experiment tested whether large recurrent structural supports could be replaced by a reusable pooled global core.

On untouched D/E/F seeds, representative source-coverage results were:

```text
plan       source coverage
exact          68.2%
closed         48.7%
core-100       14.1%
core-95        17.7%
core-90        27.0%
core-80        33.0%
```

The pooled global stable-core hypothesis therefore failed as a general replacement for exact path semantics.

Large supports can be individually stable while the mapping:

```text
derivation path -> structural region
```

remains seed/path sensitive.

Do not build a global `SupportCore` abstraction into the production architecture.

## 1.4 Whole-relation quotient is small

The exact composition-only relation quotient evaluated every source symbol rather than only a handful of issue frontiers.

Result:

```text
3279 syntactic programs
    ->
2876 exact complete finite relations

collapse = 1.140x
```

Through depth 4 there was effectively no whole-relation collapse; even at depth 7 most expressions remained extensionally distinct.

This falsifies the attractive hypothesis that the depth-7 grammar is mostly redundant syntax over a tiny repository-specific relation algebra.

Some exact identities do exist, especially around containment round trips such as:

```text
defined_in
== defined_in >> defines >> defined_in
== defined_in >> defines >> defined_in >> defines >> defined_in
```

but they are local rewrite opportunities, not evidence for a tiny global quotient.

## 1.5 Row-transition recurrence is enormous

The strongest physical recurrence result came from compiling complete relations as vectors of exact interned row states.

For the same composition-only relation census:

```text
complete-relation row applications     37,602,576
unique exact row transitions              379,386
recurrence                                  99.114x
```

Correctness was verified both against direct `Relation.then()` semantics and against all 3279 × 6 seed projections.

This changes the optimization target.

A complete relation is not itself the small reusable object. It is a large vector assembled from a much more recurrent local transition system:

```text
(row state, compatible atom)
        ->
next exact row state
```

The project should therefore preserve compact row adjacency, process-local state interning, and meaningful durable stage reuse without pretending whole relations collapse dramatically.

## 1.6 Canonical semantic identity must not use native Roaring serialization

One diagnostic produced the decisive combination:

```text
packed relation == live relation     True
row mismatches                          0
semantic digest                    different
```

The digest disagreement came from hashing `FrozenBitMap.serialize()` rather than a canonical logical set encoding.

Permanent law:

> **Native Roaring serialization is a physical representation, not Attune semantic identity.**

Where a bitmap/set participates in a persistent scientific identity, use a canonical encoding of the logical members, e.g. sorted uint32 values under explicit byte order, or another proven canonical logical representation.

Do not use construction-history-sensitive native serialization as the hash of mathematical equality.

## 1.7 Mixed set algebra is not usefully closed

The next experiment admitted row/relation operations under:

```text
>>
|
&
-
~ at relation level
```

The result rapidly hit explicit ceilings:

```text
row states        350,000 ceiling hit
relations           5,000 ceiling hit
```

Set operators alone created more than 170k novel row states before the cap.

Arbitrary-pair probes showed union remained overwhelmingly generative across FILE, SYMBOL, and LOCATION domains. The complete mixed algebra is mathematically finite but not usefully small for exhaustive production enumeration.

Therefore:

```text
do not raise ceilings and keep chasing closure
do not precompute the complete mixed relation algebra
do not describe the policy language as a small closed quotient
```

## 1.8 The binary operators have different structural character

The mixed experiments did establish useful qualitative distinctions.

### Union `|`

Union is strongly generative both at row and complete-relation levels.

This validates its place in public `Query`.

### Intersection `&`

Intersection often created genuinely new complete relations while creating relatively few novel row states, especially in later bounded-cost runs.

It appears **row-conservative but relation-expressive**: it recombines a familiar local neighborhood vocabulary across source rows rather than constantly inventing new local neighborhoods.

This is scientifically interesting, but not enough evidence to grow public `Query` before the Atlas.

### Difference `-`

Difference creates real semantics but expands directed candidate space heavily and had the weakest practical justification among the binary challengers.

Keep it out of public `Query`.

## 1.9 Bounded cost is more informative than exhaustive closure

A cost-bounded semantic census replaced the closure question with:

> How much new exact semantic behavior does each operator add at realistic expression complexity?

Under the underlying relation vocabulary, exact semantic relation counts grew approximately:

```text
cost 0       4
cost 1      17
cost 2      64
cost 3     258
cost 4   1,264
```

The search was not approaching semantic saturation at realistic costs.

This supports a **costed policy grammar**, not deeper blind closure.

## 1.10 Actual named policy vocabulary is the right synthesis unit

The final census treated the concepts an agent actually sees as atoms:

```text
defines
defined_in
imports
imported_by
calls
callers
callees
same_file
import_neighbors
importer_neighbors
parent
repository_adjacent
```

There were:

```text
12 syntactic names
11 exact semantic atoms
```

because:

```text
calls == callees
```

That semantic alias should be known to synthesis/canonicalization rather than rediscovered repeatedly.

## 1.11 Composition-only versus the real public grammar

Using the named vocabulary, the final experiment compared:

```text
composition-only     >>

versus

public grammar       ~  >>  |
```

The exact/sampled cumulative semantic counts were:

```text
cost    >> only    public ~ >> |    public / compose
-----------------------------------------------------
0           11          11              1.000x
1           52          64              1.231x
2          222         458              2.063x
3          563       1,078              1.915x
4        1,003       1,760              1.755x
```

The cost-4 public run ended at 299,999 of a 300,000 row-state budget. Treat that as effectively budget-bound; do not extrapolate a false saturation curve beyond it.

The important result is already visible much earlier: public union and composition create a large amount of additional semantic behavior over the same compact named basis.

## 1.12 Public operator novelty

Measured novelty among selected candidates was:

```text
cost 1
    ~      1 / 11    =  9.1%
    >>    41 / 49    = 83.7%
    |     11 / 23    = 47.8%

cost 2
    ~      3 / 53    =  5.7%
    >>   290 / 512   = 56.6%
    |    136 / 184   = 73.9%

cost 3 sampled
    ~     11 / 256   =  4.3%
    >>   428 / 512   = 83.6%
    |    186 / 256   = 72.7%

cost 4 sampled
    ~    181 / 256   = 70.7%
    >>   480 / 512   = 93.8%
    |    225 / 256   = 87.9%
```

Low-cost arbitrary inversion is mostly redundant because useful inverse concepts are already named. At higher mixed-expression costs, inversion again becomes generative.

Therefore public Python keeps `~`, but the synthesizer should canonicalize obvious inversions aggressively rather than branch blindly on them.

## 1.13 Policy selection, not primitive proliferation, is now the dominant research problem

The combined old-world evidence says:

```text
small basis
    -> high depth-7 reachability

mostly distinct whole relations
    -> grammar is not redundant enough to quotient away

public union
    -> substantial additional expressive power

mixed composition
    -> increasingly generative

oracle improves faster than best single fixed policy
    -> choosing the expression matters more than adding nouns
```

The default response to a localization miss should therefore **not** be to add another primitive.

The next primitive must still pass the admission law under equal budget.

## 1.14 Fresh-process Rote replay is now proven on the real cost-stage workload

Earlier telemetry contaminated cached computations and produced misleading no-speedup runs. The final harness put timing/RSS/printing outside the cached deterministic function and used a chained fresh-process canary before expensive science.

Results:

```text
canary stage
    cold 202.937 s
    warm   0.201 s
    speedup ~1007.9x

composition science stage total
    cold 622.030 s
    warm   0.552 s
    speedup ~1127.7x

public grammar science stage total
    cold 931.724 s
    warm   2.223 s
    speedup ~419.1x
```

Whole-process times also collapsed dramatically despite repository/world setup overhead.

The canary's warm Rote stats reported all six expensive stage computations as hits and approximately 202.6 seconds of saved work.

This validates the core Rote architecture when the boundary is deterministic and its semantic inputs are explicit.

Permanent lesson:

```text
telemetry may observe cached work from outside
telemetry must not inject time/process/memory effects into a supposedly pure Rote computation
```

## 1.15 Science stop rule

The old MUI algebra/reuse sequence is closed.

No further experiment should be added merely to answer:

```text
what happens at cost 5/6/7?
what if the row cap is 1 million?
what if the relation cap is 50 thousand?
what if we recursively add every binary operator?
what if we close the finite algebra completely?
```

Those questions are no longer likely to change architecture.

The next scientific population is SWE-Explore.

---

# 2. Final old-world control — completed before the refactor

The final pre-refactor control has now been run in the temporary implementation.

It added no new architecture and used the same depth-7 structural search machinery as the issue-conditioned census.

## 2.1 Question

The current structural-mixing census starts from the top semantic centers for each issue.

That leaves one important ambiguity:

> Are MUI/Vue/Darkreader signatures intrinsic properties of the repositories, or are they artifacts of where issue-conditioned semantic retrieval happened to start?

The last pre-refactor experiment should answer this.

## 2.2 Experiment: issue-blind seed ablation

Repeat the existing depth-7 relation-specific mixing census with **issue-independent deterministic seeds**.

For each repository snapshot:

1. enumerate the callable-symbol universe;
2. sort it by a stable content-independent hash of symbol identity;
3. select the first `MAX_CENTERS` symbols;
4. use those as the starting frontier;
5. run the exact same typed structural tree and mixing measurements.

Conceptually:

```python
key(node) = sha256(
    b"attune-structural-seed-v1\0" + node.encode()
).digest()

centers = first_8(sorted(callables, key=key))
```

The seed must not depend on:

```text
issue text
gold patch
semantic embedding rank
benchmark labels
wall clock
random module state
```

It should depend only on admitted repository symbol identities and a fixed seed-policy version.

## 2.3 Metrics

Produce the same repository × relation table, but distinguish two quantities:

```text
output_at_or_above_50
    how often the resulting state is already global-ish

crossing_50
    how often this primitive specifically moves a state
    from below 50% to at least 50%
```

For each primitive direction report:

```text
mean output density
median output density
p90 output density
25% crossing rate
50% crossing rate
90% crossing rate
empty-output fraction
```

Also compute a compact signature vector:

```text
for each of six primitive directions:
    median_density
    p90_density
    crossing_50
    extinction_fraction
```

## 2.4 Comparison

Compare:

```text
issue-conditioned signature
vs
issue-blind signature
```

for each repository.

Report a simple mean absolute signature distance.

Also report pairwise distances between repositories.

The useful qualitative test is:

```text
within-repository seed change
    <<
between-repository structural difference
```

Do not force this conclusion.

If the issue-blind run collapses the difference, then the correct concept is:

```text
seed-conditioned structural geometry
```

rather than:

```text
intrinsic repository signature
```

That would still be useful science.

## 2.5 Result — repository regime survives issue removal

The control passed over the same 90 snapshots.

Repository-level mean symbol-frontier density under deterministic issue-blind seeds was:

```text
Darkreader   0.5730
MUI          0.0410
Vue core     0.4941
```

The qualitative relation regimes also survived:

```text
MUI
    all primitive directions remain strongly local
    no relation reaches 50% output density in aggregate
    p90 densities remain roughly 3.8%–14.7%

Vue core
    contains mean density      ~55.5%
    callers mean density       ~52.1%
    reverse imports            ~47.9%
    forward calls              ~41.3%
    >50% states remain common

Darkreader
    contains mean density      ~67.7%
    callers mean density       ~54.6%
    forward calls              ~51.6%
    reverse imports            ~49.4%
```

The exact numbers move with the starting frontier, as expected, but the repository regimes do not collapse.

The strongest current interpretation is therefore:

> **Issues choose where exploration begins; repository structure strongly determines how exploration propagates.**

This upgrades the phrase **repository structural signature** from a useful hypothesis to the working empirical model for the SWE-Explore Atlas.

The control also strengthens two architectural decisions:

1. intrinsic repository signatures should be computed without issue text or evaluator gold;
2. issue-conditioned localization should be analyzed as a second layer over that intrinsic geometry.

The ad hoc post-hoc Xonsh comparison snippet failed after the successful pytest run because it referenced `SYNTH_ATOMS` outside the test module namespace. That failure does not affect the experiment result and is not worth repairing before the refactor.

## 2.6 Why this ends the old-world experiment series

This was the last question whose answer could materially change what the SWE-Explore refactor should measure.

After it:

```text
stop extending the SpIDER experiment harness
stop adding temporary memo dictionaries
stop adding test_transfer.py census machinery
```

The next measurement must happen on the new repository-native stack.

---

# 3. First refactor milestone — SWE-Explore structural atlas

The first refactor milestone is not “clean architecture.”

It is a concrete artifact:

```text
SWE-Explore repository snapshots
    ↓
repository-native structural facts
    ↓
small typed relation algebra
    ↓
issue-blind structural seed panels
    ↓
relation-specific mixing signatures
    ↓
real Rote cold/warm reuse measurements
    ↓
STRUCTURAL ATLAS REPORT
```

Call this **Atlas Gate**.

Nothing in later sections is allowed to delay Atlas Gate unless it is a true prerequisite.

## 3.1 Atlas Gate definition of green

Atlas Gate is green when Attune can produce, from SWE-Explore snapshots:

```text
per repository:
    file count
    callable-symbol count
    primitive relation counts

per primitive direction:
    median output density
    p90 output density
    25/50/90 crossing rates
    extinction fraction

per repository search:
    logical structural programs considered
    deterministic computations physically executed
    Rote reuses
    cold wall time
    warm wall time
```

and can do so with:

```text
no SpIDER node/edge dependency
no ad hoc test-local memoization cache
no Mojo runtime
no hidden benchmark gold in structural-signature computation
```

## 3.2 Atlas Gate does not require

Do not block the first atlas on:

```text
historical issue supervision
policy-generation agents
Code Mode
references relation
canonical evidence DAG
interactive model explorer
provider KV/prefix optimization
full repository onboarding
final polish of the public API
all SWE-Explore languages at once
```

The provider KV/prefix work is **not required to block Atlas Gate**, but it is a locked downstream requirement of the full-session reuse thesis. Deferral here means sequencing only, not optionality.


## 3.3 Public developer API is a first-class product requirement

The Atlas-first ordering does **not** mean developer ergonomics are optional.

A core Attune goal is that the same small public Python API can be demonstrated in:

```text
ordinary Python
pytest
Xonsh
an interactive repository shell
small scripts / notebooks
Starship prompt integration
```

without reimplementing the science for each surface.

The governing rule is:

> **pytest and Xonsh call the same public functions over the same public domain values. Tests are demonstrations with assertions, not a second API.**

The first Atlas implementation should therefore expose ordinary typed functions rather than burying useful behavior inside pytest helpers, CLI handlers, or fixture-only code.

Conceptual shape:

```python
repo = attune.repository(snapshot)

signature = structural_signature(
    repo.relations,
    seeds=issue_blind(repo.symbols, count=8),
    depth=7,
)

signature.relations["calls"].p90_density
```

A pytest law should look like normal use plus assertions:

```python
def test_vue_callers_mix(vue: Repository) -> None:
    signature = structural_signature(
        vue.relations,
        seeds=issue_blind(vue.symbols, count=8),
        depth=7,
    )

    assert signature.relations["callers"].p90_density > 0.5
```

The equivalent Xonsh exploration should use the same names and objects:

```xonsh
from attune_radii import repository, structural_signature, issue_blind

repo = repository("vuejs/core@...")
sig = structural_signature(repo.relations, issue_blind(repo.symbols, 8), depth=7)
sig
sig.relations["callers"]
```

The exact API can become smaller during implementation, but it must preserve this **one-codepath** property.

### 3.3.1 Public values should be inspectable

Important values should have bounded, deterministic, useful representations:

```text
Repository
Relations
Query
StructuralSignature
RelationSignature
Policy / Localization result
Observation metadata when public
```

`repr()` must remain:

```text
pure
bounded
deterministic
credential-safe
free of accidental native pointer/object-address noise
```

A representation must never trigger:

```text
Nix evaluation
Grit extraction
model acquisition
ObservationStore lookup
Rote computation
filesystem scans
network access
```

Inspection is presentation, not execution.

### 3.3.2 Xonsh integration

After the core Atlas objects are stable, provide a very small Xonsh integration layer, preferably as a `xontrib` or equally conventional plugin surface.

Its job is only ergonomics:

```text
import convenient Attune names
pretty-print public values
provide tab completion where practical
expose a few thin aliases around the public API
surface current Attune repository/cache state
```

It must **not** contain a second localization engine, second memoization system, or shell-only semantics.

A useful interactive session should feel approximately like:

```xonsh
attune open .
attune signature --depth 7
attune relation calls
attune relation '~calls'
attune atlas
```

Those commands should be thin calls into the same Python functions pytest uses.

### 3.3.3 Starship custom module

Provide an optional Starship custom module for the Attune development environment.

This is presentation-only. It may display already-known local state such as:

```text
Attune active / inactive
current repository identity or short snapshot id
replay vs acquire mode
warm/cold deterministic cache state when cheaply known
current experiment/profile label
```

Example visual intent:

```text
attune:radii  atlas  warm
```

The Starship command must be fast and side-effect free. It must never trigger expensive work merely to render a prompt.

Specifically, prompt rendering may **not** cause:

```text
Nix realization
Grit/Marzano execution
embedding/model calls
Rote population of a missing result
repository traversal
benchmark loading
```

If a state is not already cheaply available, omit it from the prompt.

Prefer reading a tiny process/session status artifact or environment state deliberately published by Attune over introspecting the full system on every shell prompt.

### 3.3.4 CLI is an adapter, not the architecture

A CLI can exist because it is useful for demos and shell workflows, but it should remain approximately:

```text
parse arguments
construct ordinary public values
call ordinary public functions
format result
```

No scientific behavior should exist only in CLI code.

### 3.3.5 API quality gate

Before calling the first Atlas implementation presentation-ready, require one small end-to-end example to run unchanged in spirit across:

```text
Python REPL / script
pytest
Xonsh
```

The test version may add assertions; the Xonsh version may add pretty printing; neither may replace the underlying calls.

This public API quality is part of the project identity, not generic SDK polish to postpone indefinitely.

---

# 4. SWE-Explore is now the primary refactor target

SWE-Explore is the correct first external target because it isolates repository exploration rather than scoring only final repair.

The released benchmark currently contains:

```text
848 issues
203 open-source repositories
10 programming languages
```

Each instance contains repository snapshot metadata and trajectory-derived line-level exploration ground truth.

The benchmark distinguishes core context and optional context derived from successful repair trajectories.

This gives Attune two useful experimental layers.

## 4.1 Layer A — intrinsic / issue-blind structural atlas

Ignore benchmark labels and issue text.

Measure only repository geometry.

This asks:

```text
How local are calls in this repository?
How local are reverse calls?
How local are imports and importers?
How quickly does file→symbol projection become global?
How many structural states die out?
How much deterministic state convergence exists?
```

This is the direct replication of the MUI/Vue/Darkreader result.

## 4.2 Layer B — issue-conditioned exploration

Then introduce:

```text
issue text
frozen semantic prior
benchmark core/optional labels held by evaluator
```

Ask:

```text
Can structural paths recover the regions successful agents actually read?
How much gold context is structurally reachable?
At what structural depth does useful context first appear?
How dense is the frontier when useful context appears?
Which repository signatures favor which policies?
```

This is where Attune becomes an exploration system rather than only a structural atlas.

## 4.3 Use official benchmark labels

For SWE-Explore evaluation:

```text
use official SWE-Explore core / optional regions
```

Do not regenerate benchmark gold from patches.

Do not use the historical-supervisor path to replace official labels.

That separate supervision system remains a later repository-onboarding experiment.

---

# 5. Scope the first SWE-Explore implementation aggressively

The fastest path is staged.

## 5.1 First language slice

Start with:

```text
TypeScript / JavaScript
```

because:

```text
the current science is already TypeScript-heavy;
AttuneDeal already proved the Marzano TypeScript seam;
we have immediate fixture intuition for definitions/imports/calls;
we can test the new architecture without conflating it with language-port work.
```

The first successful SWE-Explore structural atlas may therefore be a TS/JS subset.

## 5.2 First broad slice

After TS/JS is green, expand across the benchmark languages supported by fixed Grit fixtures.

For the first broad run:

> **Exclude C/C++ rather than delaying the entire experiment on the hardest parser/resolution tail.**

Do not hard-code a filtered instance count.

Derive it from the pinned dataset at runtime.

## 5.3 Preserve the initial symbol ontology

The current experiment is about callable symbols.

For the first atlas, preserve that ontology:

```text
functions
methods
language-equivalent callable declarations
```

Do not simultaneously widen `SymbolId` to every class/type/field/module declaration while claiming to replicate the old result.

After Atlas Gate, widening the symbol universe becomes its own controlled experiment.

---

# 6. Permanent primitive vocabulary — keep it at four

The current evidence supports exactly this permanent basis:

```text
defines : FileId   → SymbolId
imports : FileId   → FileId
calls   : SymbolId → SymbolId
parent  : LocationId → LocationId
```

For the immediate replication of the current mixing experiment, only the first three are required.

The current six directions become:

```text
defines
~defines
imports
~imports
calls
~calls
```

`parent` should be added immediately after the first atlas because repository-tree locality has already shown useful behavior, but it must not block the six-direction replication.

## 6.1 Do not add `references` yet

The previous spec prematurely elevated `references` to a public primitive.

Undo that.

Current evidence does not justify it.

The primitive admission law remains:

> **A new primitive earns admission only if it compresses the search language under a fixed logical/physical budget or materially improves held-out structural reachability/localness.**

Potential future challengers include:

```text
references
inherits
overrides
tests_for
cochanged
```

None are part of Atlas Gate.

## 6.2 Naming

Use the semantically clearer names in the refactor:

```text
contains → defines
invokes  → calls
FunctionId → SymbolId
```

But do not force broad domain redesign before the first atlas.

If changing `RepoId`/`FileId` into one unified location domain would delay the first SWE run, defer it until after Atlas Gate.

---

# 7. Grit is the repository-native fact boundary

The structural path is:

```text
repository source snapshot
    ↓
fixed human-authored Grit patterns
    ↓
Marzano
    ↓
raw match / binding / diagnostic ranges
    ↓
small deterministic Python normalization / resolution
    ↓
primitive fact shards
    ↓
typed finite relations
```

Grit is not the policy language.

The policy language remains ordinary Python relation composition.

## 7.1 Rust + PyO3 only

The native implementation is:

```text
Python
    ↓
PyO3 extension
    ↓
small Rust adapter
    ↓
pinned Marzano/Grit crates
```

Explicitly do **not** use:

```text
Mojo
WIT
Wasmtime
Component Model
C ABI
ctypes for Grit
generated runtime clients
```

The existing AttuneDeal repository is a reference for Marzano semantics, not a runtime architecture to copy.

## 7.2 What to port from AttuneDeal

The useful native core is extremely small.

AttuneDeal already demonstrates:

```text
src_to_problem_libs(...)
    → CompilationResult
    → Problem

Problem.execute_files(...)
    → MatchResult stream

RichFile(path, content)
ExecutionContext::default()
```

and projection of:

```text
Match
Rewrite
CreateFile
RemoveFile
AnalysisLog
```

Radii should port only that core.

The AttuneDeal TypeScript language helper also demonstrates explicit Marzano target-language construction using the pinned Tree-sitter TypeScript grammars.

## 7.3 What not to port from AttuneDeal

Do not port:

```text
WIT resources
component handles
Wasmtime realm ownership
Mojo effect declarations
runtime code generation
Component Model serialization
coverage realm machinery
campaign infrastructure
```

Radii does not need those layers.

## 7.4 Candidate upstream revision

AttuneDeal's current Python façade records a known Grit revision:

```text
c80b3026471b229f41b279c3eb0c162dcdacfdb1
```

Treat this only as a known-good compatibility reference.

Attune Radii should pin its own exact upstream revision in Nix/Cargo and expose that identity in diagnostics/cache inputs.

Do not silently share a mutable external Grit installation.

---

# 8. Tiny PyO3 surface

Prefer one narrow native object or module.

Conceptual API:

```python
grit = Grit()

evaluation = grit.run(
    language="typescript",
    pattern=pattern_source,
    files=((path, source), ...),
    apply=False,
)
```

The native side may retain compiled `Problem`s process-locally by:

```text
(language, sha256(pattern_source), Grit revision)
```

This is **compiled-object reuse**, not Attune's durable scientific memoization system.

Rote remains the durable deterministic memoization layer.

## 8.1 Return ordinary Python data

Prefer compact tuples / dataclasses over a large PyO3 class hierarchy.

Required information:

```text
matches:
    kind
    path
    ranges
    bindings

diagnostics:
    phase
    level
    message
    path
    range

optional operations:
    rewrite/create/remove
    path
    content
```

For Atlas Gate, rewrite operations are unnecessary.

They exist only because later historical-supervision work may need them.

## 8.2 No syntax-tree API

Do not expose:

```text
Tree-sitter node pointers
node parent()
node children()
generic AST walk API
syntax-node object graph
```

The fixed Grit patterns themselves define what structural evidence Attune admits.

---

# 9. First Grit programs

The first fixed catalog is intentionally tiny.

For each supported language:

```text
defines.grit
imports.grit
calls.grit
```

`parent` is derived from repository paths, not Grit.

Suggested layout:

```text
grit/
  typescript/
    defines.grit
    imports.grit
    calls.grit

  javascript/
    defines.grit
    imports.grit
    calls.grit

  python/
    ...

  go/
    ...

  rust/
    ...

  java/
    ...
```

Only add a language directory when fixture laws exist.

## 9.1 `defines`

Atlas Gate semantics:

> A file defines one admitted callable symbol with an immutable source span and stable repository-relative identity.

Return enough data to construct:

```python
Symbol(
    path=...,
    start_byte=...,
    end_byte=...,
    name=...,
    kind=...,
)
```

The first ontology is callable-only.

## 9.2 `imports`

Grit discovers source import statements/specifiers.

Python performs deterministic repository-local resolution.

The public relation contains only resolved local file edges:

```text
imports : FileId → FileId
```

Unresolved/external package imports do not become fake repository edges.

## 9.3 `calls`

Grit discovers call sites and the relevant callee binding/range.

Python resolves only unambiguous repository-local targets for the first implementation.

```text
calls : SymbolId → SymbolId
```

Ambiguous dynamic calls remain observations, not false edges.

The first atlas values precision of structural semantics over pretending to resolve the entire language.

---

# 10. Structural fact model

Do not jump directly from native matches into live `RoaringRel` objects as the durable cache payload.

Rote should cache stable Python-native fact data.

Conceptual values:

```python
SourceBlob(
    path,
    language,
    digest,
    content,
)

DefinitionFact(
    path,
    symbol_key,
    start_byte,
    end_byte,
    kind,
)

ImportFact(
    source_path,
    specifier,
)

CallFact(
    source_symbol_key,
    target_text,
    call_span,
)
```

Then deterministic resolvers produce admitted edges.

## 10.1 Why cache facts rather than native relation objects

The permanent identity should survive:

```text
process boundaries
Python worker boundaries
relation implementation changes
RoaringRel upgrades
query implementation changes
```

Therefore prefer stable tuples/records as the Rote payload.

Construct the live compact relation representation cheaply from admitted facts.

---

# 11. Real memoization — Rote, not test-local dictionaries

This is a locked decision.

The old experiments used temporary dictionaries such as:

```python
transitions[(atom.name, frontier)] = reached
```

That was useful scientific instrumentation.

It is not the production architecture.

The refactor must use the actual Attune deterministic memoization system:

```text
Rote
```

## 11.1 No second durable cache

Do not create:

```text
StructuralCache
FactCache
PolicyCache
FrontierCache database
custom DAG persistence engine
hand-written source dependency tracker
```

Rote owns deterministic Python reuse.

Nix owns immutable external artifacts.

ObservationStore owns remote/model observations.

Those identities must remain separate.

## 11.2 Rote boundaries for Atlas Gate

Good first boundaries are:

```python
@rote.cache
def extract_blob_facts(...): ...

@rote.cache
def resolve_repository_facts(...): ...

@rote.cache
def build_atlas_case(...): ...

@rote.cache
def summarize_repository_signature(...): ...
```

More concretely:

```text
SourceBlob + primitive catalog identity + Grit engine identity
    → raw normalized fact shard

all fact shards + resolver version
    → resolved repository primitive facts

resolved facts + deterministic seed policy + depth
    → structural trajectory/statistics
```

## 11.3 Do not hide native dependencies from Rote

Do not rely on Rote noticing file access performed inside Rust or PyArrow.

All semantic inputs to a Rote-cached function must enter explicitly as stable arguments.

For example:

```text
blob digest
language
source bytes or immutable source artifact identity
Grit revision
Grit pattern digest
resolver version
```

If source bytes are passed directly, the computation is genuinely pure from Python's perspective.

## 11.4 State interning is not the memoization claim

An exhaustive finite search may still canonicalize equivalent in-memory states so it does not deliberately execute duplicate algebra.

That is an algorithmic representation choice.

Do not report it as Rote cache reuse.

Telemetry must distinguish:

```text
logical syntax considered
unique semantic states
Rote physical executions
Rote reuses
native Grit executions
```

This separation prevents the temporary whole-frontier dictionary trick from being mistaken for the actual memoization architecture.

## 11.5 Cold/warm law

Every Atlas Gate report must include at least two runs:

```text
cold Rote state
warm Rote state
```

Required behavior:

```text
warm rerun:
    same structural results
    no repeated unchanged Grit fact extraction
    no repeated unchanged repository resolution
    substantially lower physical deterministic work
```

## 11.6 Invalidation law

Perturbation tests must show:

```text
change only atlas reporting code
    → fact extraction reused

change one Grit primitive
    → only that primitive's dependent fact/resolution work invalidates

change one source blob
    → only that blob's extraction and dependent cross-file resolution invalidates

change one policy/query expression later
    → repository fact extraction reused

change benchmark evaluator assertion
    → repository facts reused
```

## 11.7 Tree/subtree memoization is a permanent design requirement

The temporary depth-7 experiments exposed a broader pattern that must survive beyond Atlas Gate.

Search and policy evaluation form trees or DAGs of deterministic subcomputations. Repeated structure should not imply repeated physical evaluation.

The permanent research model is:

```text
normalized search/policy expression
        +
immutable repository/evidence/input state
        ↓
deterministic subtree result
```

When the same subtree is reached again under the same immutable semantic inputs, its deterministic result is reusable.

This includes:

```text
shared structural path prefixes
repeated relation applications
repeated policy subexpressions
repeated frontier/state evaluations
repeated scoring/reduction subtrees
later repeated tool/evidence transforms
```

Do not implement a separate persistent `TreeCache` or `FrontierCache`.

Use:

```text
Rote
    for meaningful durable deterministic transformations

compact Relation adjacency
    for cheap local graph operations

process-local interning/hash-consing
    for deliberate algorithmic deduplication inside one search

stable immutable identities
    so repeated subtrees can actually compare equal
```

The important claim is not that every AST node receives a cache entry.

The important claim is:

> **The physical work of exploring a search tree should scale with genuinely new semantic computation, not with the number of syntactic paths that happen to revisit the same state.**

## 11.8 Explicit memoization annotations are a legibility feature

For meaningful persistent deterministic boundaries, prefer explicit source such as:

```python
@rote.cache
def rank_prior(...):
    ...
```

over an invisible blanket autowrapper.

The annotation tells the reader that the function is intended to be:

```text
deterministic
dependency-aware
durably reusable
important enough that persistent reuse is worth its cost
```

Fixit may offer an autofix that adds or removes a `@rote.cache` annotation when the architectural intent is mechanically clear.

Fixit must not silently transform every ordinary function into cached behavior at import time.

Small pure helpers may remain undecorated.

The code should remain understandable by reading the checked-in Python source.

## 11.9 Effectful does not mean non-reusable

Do not encode the false rule:

```text
Effect -> never memoize/reuse
```

Effects represent capabilities and interactions. Their reuse semantics depend on which layer owns their identity.

Examples:

```text
Nix realization
    effectful boundary
    reuse owned by Nix store identity

model/provider observation
    effectful boundary
    exact replay owned by ObservationStore

model provider prefill
    effectful boundary
    partial physical reuse owned by provider KV/prefix cache

effect-python service construction
    effectful boundary
    process/run reuse owned by effect-python layer/runtime memoization
```

Rote still must not directly own stochastic provider acquisition or arbitrary external effects.

Also do not mistake caching an `Effect` description/value for memoizing the physical result of interpreting that Effect. Durable effect reuse belongs at the identity-owning boundary above.

---

# 12. Repository identity and blob reuse

SWE-Explore contains many repository snapshots.

Attune should exploit content overlap across them.

Do not key structural extraction solely by:

```text
repo + commit
```

Use content identity.

Conceptually:

```text
BlobId = sha256(source bytes)
```

Fact extraction identity:

```text
FactShardId = hash(
    BlobId,
    language,
    primitive program digest,
    Grit/Marzano revision,
    normalizer version,
)
```

Unchanged source across many issue snapshots should be extracted once.

This is exactly the kind of reuse Rote/Nix should make durable.

## 12.1 Cross-file resolution

Cross-file imports/calls cannot honestly be keyed by one blob alone.

Use the smallest explicit repository environment dependency practical for the first implementation.

Do not fake perfect incremental dependency precision before Atlas Gate.

A coarse but correct repository symbol/import environment identity is acceptable initially.

Then measure whether finer invalidation is worth building.

---

# 13. SWE-Explore input ownership

The official dataset/repository snapshots are immutable scientific inputs.

Nix should own the pinned dataset release and exact source snapshots used by an experiment.

## 13.1 Dataset adapter

Normalize official records into a minimal domain shape:

```python
ExploreCase(
    instance_id,
    repository,
    base_commit,
    language,
    problem_statement,
    core_regions,
    optional_regions,
)
```

The structural atlas needs only:

```text
instance_id
repository
base_commit
language
snapshot
```

Issue-conditioned evaluation additionally uses `problem_statement`.

Only evaluator code receives core/optional regions.

## 13.2 Snapshot strategy

Do not solve the entire 848-instance snapshot-distribution problem before the first TS/JS run.

Use staged pinning:

```text
stage 1:
    small TS/JS repository set
    exact pinned commits

stage 2:
    complete TS/JS benchmark subset

stage 3:
    supported non-C/C++ languages
```

The final run must be reproducible from pinned identities/hashes.

The early smoke slice may use a smaller checked manifest while the full snapshot lock is being constructed.

---

# 14. Structural atlas representation

Keep this tiny.

A permanent observer can be roughly:

```python
class Step(NamedTuple):
    atom: str
    depth: int
    before: int
    after: int
    source_size: int
    target_size: int
```

Derived pure metrics:

```python
input_density
output_density
threshold_crossing
extinction
```

Repository signatures should be ordinary immutable data.

Do not create a framework called `StructuralAtlasEngine`.

## 14.1 Permanent compact signature

For each primitive direction keep:

```text
median output density
p90 output density
50% crossing fraction
empty-output fraction
```

Separately keep deterministic execution metrics:

```text
logical programs
unique semantic states
Rote executions
Rote reuses
wall time
```

The density signature characterizes repository geometry.

The execution signature characterizes the cost/reuse regime.

Do not conflate them.

---

# 15. Search grammars — Atlas measurement versus policy synthesis

The project now has two intentionally different grammars.

Do not merge them merely for conceptual neatness.

## 15.1 Atlas replication grammar — fixed through Atlas Gate

The Atlas reproduces the old structural-geometry experiment under a stable protocol.

Atoms:

```text
defines      File   -> Symbol
defined_in   Symbol -> File
imports      File   -> File
imported_by  File   -> File
calls        Symbol -> Symbol
callers      Symbol -> Symbol
```

Start domain:

```text
Symbol
```

Operator:

```text
>> only
```

Search depth:

```text
7
```

The typed count laws remain:

```text
3279 cumulative non-root typed prefixes
1643 cumulative Symbol -> Symbol paths
```

These are parity laws for the Atlas implementation.

### Why the Atlas stays composition-only

The Atlas is measuring repository propagation/mixing under a protocol already observed on MUI/Vue/Darkreader.

Adding recursive union would:

```text
break direct comparability to the baseline
massively expand semantic state
mix policy-language expressivity into repository-geometry measurement
make broad SWE execution unnecessarily expensive
```

The final mixed-algebra and actual-vocabulary experiments already established that union is highly generative. We do not need to rediscover that on every Atlas repository.

Therefore:

> **The composition-only depth-7 Atlas grammar is a measurement protocol, not a claim that production policies should be composition-only.**

## 15.2 Post-Atlas policy-synthesis grammar — named concepts + public operators

When policy synthesis begins, the agent should reason over the named public vocabulary:

```text
defines
defined_in
imports
imported_by
calls
callers
callees
same_file
import_neighbors
importer_neighbors
parent
repository_adjacent
```

with public operators:

```text
~
>>
|
```

Intersection and difference remain excluded from public policy syntax.

## 15.3 Named concepts are synthesis atoms

The policy author sees:

```python
same_file
```

not an obligation to mentally expand:

```python
defined_in >> defines
```

Likewise for `import_neighbors`, `importer_neighbors`, and `repository_adjacent`.

The implementation may compile those names compositionally. The synthesis cost model should charge the public concept, not its hidden implementation expansion.

This is important because the final policy-vocabulary census showed that named concepts materially change the actual search surface.

## 15.4 Semantic aliases should be canonicalized

The current named vocabulary contains the deliberate alias:

```text
calls == callees
```

The public API may retain both names for readability, but synthesis should not spend separate search budget rediscovering the same semantics.

A private canonicalizer may map syntactic aliases to one semantic representative while preserving the shortest/readable public expression as presentation metadata.

## 15.5 Inversion normalization

Public `~` remains first-class, but synthesis should normalize obvious cases before branching.

Useful laws include:

```text
~~Q                     -> Q
~defines                -> defined_in
~defined_in             -> defines
~imports                -> imported_by
~imported_by             -> imports
~calls                  -> callers
~callers                -> calls
~(A >> B)               -> ~B >> ~A
~(A | B)                -> ~A | ~B
```

Do not require a giant theorem prover. A tiny trusted normalization layer for obvious public laws is enough.

## 15.6 No exhaustive algebra closure

The mixed closure experiments are definitive enough for architecture:

```text
complete mixed closure grows too quickly
arbitrary union remains highly generative
whole-relation quotient is too small to save us
```

Therefore policy search should use:

```text
cost bound
quality objective
physical-work budget
semantic interning
Rote replay of meaningful expensive stages
```

not exhaustive closure.

---

# 16. First SWE-Explore experiment sequence

Run these in this order.

## 16.1 E0 — Grit semantic fixtures

For TypeScript/JavaScript:

```text
defines fixture
imports fixture
calls fixture
reverse relation law
ambiguous-resolution negative fixture
```

Require exact deterministic facts.

## 16.2 E1 — one repository snapshot

Choose one SWE-Explore TS/JS snapshot.

Produce:

```text
file universe
symbol universe
defines edges
imports edges
calls edges
```

Then run depth 7 from issue-blind seeds.

No benchmark labels yet.

## 16.3 E2 — contrasting TS/JS repositories

Choose several repositories with visibly different architectures.

The goal is not cherry-picked performance.

It is to ensure the new Grit facts can express both:

```text
local / compartmentalized structure
and
highly mixing structure
```

## 16.4 E3 — full TS/JS structural atlas

Run the complete available SWE-Explore TS/JS subset.

Report repository signatures and within-repository variation across snapshots.

## 16.5 E4 — supported-language atlas

Add fixture-backed languages one by one.

Exclude C/C++ initially.

Produce the first broad structural atlas.

## 16.6 E5 — issue-conditioned overlay

Only after E3 is green at minimum.

For each issue:

```text
issue
    ↓
frozen embedding prior
    ↓
semantic centers
    ↓
structural paths
    ↓
ranked code regions
    ↓
official SWE-Explore evaluator
```

Compare issue-conditioned signatures against issue-blind repository signatures.

---

# 17. SWE-Explore evaluation metrics

Use the benchmark's official region-level evaluator where possible.

Always report at least:

```text
line precision
line recall
F1
hit-file rate
noise-file rate
hit-region rate
noise-region rate
weighted core coverage
context efficiency
recall@K / NDCG@K when relevant
first useful hit
```

Attune-specific metrics:

```text
structural depth to first core region
fraction of core regions structurally reachable
frontier density at first useful hit
shortest structural explanation depth
logical structural operations
unique semantic states
Rote executions / reuses
Grit executions
unique source blobs extracted
cold wall time
warm wall time
model/embedding observations acquired vs replayed
```

## 17.1 Evaluation leakage law

The following may not enter explorer/policy input:

```text
core regions
optional regions
successful trajectory reads
resolving patch
future gold
```

They belong only to evaluator-side values.

---

# 18. Frozen embedding prior

Do not redesign the semantic prior before Atlas Gate.

The structural atlas does not need it at all.

For issue-conditioned SWE-Explore evaluation, reuse the existing architectural pattern:

```text
model embedding effect
    ↓
ObservationStore durable raw/vector observation
    ↓
Rote local ranking
```

Do not buy the same embedding observation repeatedly because downstream structural policy changed.

## 18.1 Ranking identity

A ranking must be invalidated by changes to:

```text
query embedding identity
document embedding identities
symbol corpus identity
ranking implementation/source
```

Changing only a structural policy must not reacquire embeddings.

---

# 19. effect-python responsibilities

Keep effect-python for actual capabilities/effects.

Likely effectful boundaries:

```text
Nix snapshot realization
model embedding acquisition/replay
optional model policy selection later
tracing
```

The Grit execution itself should be deterministic local computation when source bytes/pattern identity are already supplied.

It does not need to become an Effect merely because it is native Rust.

Pure work remains ordinary Python:

```text
fact normalization
relation construction
query execution
atlas statistics
policy execution
benchmark metric projection
```

---

# 20. Current Nix boundary — do not rewrite it gratuitously

The current checkout already has a typed Nix capability and direct native Nix API integration.

Do not spend Atlas Gate time replacing that subsystem merely because a different Nix binding architecture might be prettier.

Change Nix only where necessary to expose:

```text
SWE-Explore dataset
snapshot manifests / source archives
Rust Grit build inputs
Grit source programs
```

The refactor is SWE-first, not Nix-refactor-first.

---

# 21. Query algebra — keep the public surface small, make synthesis semantics explicit

The public algebra remains:

```text
reverse:      ~
composition:  >>
union:        |
```

This is now supported by direct bounded-cost evidence, not only API preference.

The final actual-vocabulary census found that adding `~` and `|` to composition roughly doubled the number of reachable exact semantics around costs 2–4 under the tested budget, while union remained strongly novel.

Therefore:

```text
~   LOCKED
>>  LOCKED
|   LOCKED
```

Intersection and difference remain private `Relation` operations / challengers.

## 21.1 Preserve the locked vocabulary

Keep:

```python
defined_in = ~defines
imported_by = ~imports
callers = ~calls
callees = calls

same_file = defined_in >> defines
import_neighbors = defined_in >> imports >> defines
importer_neighbors = defined_in >> imported_by >> defines
repository_adjacent = parent | ~parent
```

Do not rename these casually; policy-search experiments and documentation should speak this language.

## 21.2 Primitive implementation lookup should become direct and typed

The current `name -> _primitive() -> attrgetter -> object -> cast` dispatch is transitional.

When the algebra is touched during the refactor, prefer an edge declaration that retains a typed getter directly.

The display name is metadata, not implementation lookup.

Do not turn this cleanup into a new framework.

## 21.3 Synthesis complexity model is now locked conceptually

The old census used `atom cost = 0` simply to label algebraic layers.

Production synthesis should use a human-legible complexity accounting such as:

```text
named policy atom             cost 1
reverse ~A                    +1 unless normalized to a named inverse
composition A >> B            +1
union A | B                   +1
```

The exact numeric penalty may be tuned later, but the semantics are locked:

1. charge the **public expression**;
2. do not charge hidden implementation expansion of named concepts;
3. prefer shorter readable expressions when quality is equal;
4. include physical-work cost as a separate or combined penalty;
5. canonicalize obvious aliases/reversals before spending search budget.

## 21.4 Selection is the dominant post-Atlas challenge

Do not respond to the expressive search space by adding a broad catalog of new structural nouns.

The existing language already generates a large hypothesis space.

The important future question is:

> **Which small expression is useful for this repository / issue under a fixed quality and physical-work budget?**

That is the policy-synthesis problem.

---

# 22. Real reuse telemetry

The old experiments used logical/physical counts derived from a local dictionary.

The new system must report actual source of reuse.

Every expensive operation should be classifiable by the layer that avoided physical work:

```text
computed now
Rote deterministic replay/reuse
ObservationStore exact replay
Nix already-realized artifact
process-local compiled Grit Problem reuse
process-local structural state interning
effect-python layer/runtime reuse
provider live with KV/prefix reuse
provider live without KV/prefix reuse
```

Do not collapse those into one “cache hit rate.”

For structural/search work, preserve at least:

```text
logical syntax/subtrees considered
unique semantic states
physical deterministic evaluations
Rote reuses
process-local interned-state reuses
frontier member volume
```

For model work, preserve at least:

```text
logical model decisions
exact ObservationStore replays
live provider requests
input tokens
provider cache-read tokens
provider cache-write tokens
fresh/uncached input tokens when derivable
output tokens
TTFT/latency where available
provider cost
```

Exact ObservationStore replay and provider KV reuse are different events. A replay performs zero provider inference. A KV hit still performs a live request but avoids recomputing some prefix prefill.

For Atlas Gate the headline should be expressible like:

```text
logical structural programs considered:  1,000,000
unique semantic states:                    130,000
Rote deterministic executions:             40,000
Rote reuses:                                90,000
native Grit blob executions:                 6,000
unique source blobs:                         6,000
warm native Grit blob executions:                0
```

The exact numbers are unknown until measured.

The shape of the report is locked.

---

# 23. Rote acceptance tests

Before calling the new SWE atlas memoized, prove:

## 23.1 Same call, same checkout

```text
cold call executes
warm call reuses
result byte-for-byte / value-equal identical
```

## 23.2 Source dependency change

Change a helper used transitively by the cached computation.

Require invalidation.

## 23.3 Grit program change

Change `calls.grit` only.

Require:

```text
calls fact work invalidates
unrelated defines/imports fact work remains reusable
```

If Rote's dependency granularity does not produce this automatically, make the primitive program identity an explicit argument.

## 23.4 Blob change

Change one source blob.

Require unchanged blob extraction reuse.

## 23.5 xdist

Run relevant cache laws under the normal worker model.

Corruption or stale reuse is a blocker.

Duplicate safe cold computation is tolerable initially if Rote's documented concurrency model allows it.

## 23.6 Shared deterministic subtree

Construct at least one finite search fixture in which multiple syntactic paths share an identical normalized deterministic prefix/state.

Require:

```text
logical paths considered > physical subtree evaluations
shared prefix/state result is reused
result equality is unchanged
telemetry distinguishes process-local state reuse from durable Rote reuse
```

This law prevents future policy synthesis from regressing to "enumerate the tree and recompute every node."

---

# 24. Rust implementation budget

The Rust layer should remain tiny enough to audit as a boundary adapter.

Target:

```text
~180–300 handwritten Rust LOC
```

A review is required if it grows beyond roughly:

```text
350–400 LOC
```

unless the increase is mostly straightforward multi-language target mapping.

Rust should own:

```text
Marzano target-language construction
Grit compile
Problem execution
match/log/diagnostic projection
optional rewrite projection
process-local compiled Problem reuse
```

Rust should not own:

```text
repository graph models
symbol resolution
Rote identity
policy synthesis
benchmark adaptation
SWE metrics
Nix orchestration
model calls
```

---

# 25. Python size pressure

The production Python target remains aggressively small.

Aim for:

```text
< 2000 executable-ish production Python LOC
```

Do not count Grit semantic programs as framework machinery.

They are declarations of repository facts.

The first atlas should make the codebase smaller by deleting:

```text
SpIDER parquet readers
SpIDER release normalization
SpIDER-specific routing projection
large temporary transfer experiments
manual memoization census machinery
```

while adding only:

```text
SWE adapter
small Grit façade
fact normalizer/resolver
small atlas observer
```

---

# 26. Target package shape before Atlas Gate

Keep the package boring.

One plausible shape:

```text
src/attune_radii/
  __init__.py
  nix.py
  observation.py
  model.py
  world.py
  swe.py
  grit.py
  facts.py
  atlas.py

  algebra/
    __init__.py
    relation.py
    query.py
    structure.py

  policies/
    __init__.py
    radii.py

native/grit/
  Cargo.toml
  src/
    lib.rs
    marzano.rs
    language.rs

grit/
  typescript/
    defines.grit
    imports.grit
    calls.grit
  javascript/
    ...
```

Do not create generic:

```text
engine/
workflow/
providers/
managers/
graph/
evidence/
policy_ir/
```

before pressure exists.

---

# 27. Migration / refactor plan — current checkout forward

The historical phase list described how the architecture was expected to be built. The checkout has now already implemented substantial pieces of that plan.

This section is the operational plan from the September 20 checkpoint.

## Phase A — freeze science and baseline

Completed.

Record and preserve:

```text
base revision                              87d1137a
old structural mixing / issue-blind result
relation quotient result                   3279 -> 2876
row transition recurrence                  ~99.114x
support-core negative result
mixed-operator closure negative result
bounded-cost operator result
actual policy vocabulary result            12 names / 11 semantics
public-vs-compose cost table
Rote chained replay canary                  ~1008x stage replay
```

No further old-world MUI census is planned.

## Phase B — make pytest the only verification entrypoint

Preserve every existing quality/refactor law but route it through pytest.

Specifically:

1. keep `tests/conftest.py` as the canonical session gate;
2. preserve Ruff, Flake8/Wemake, Fixit, BasedPyright, interrogate, and Grit checks;
3. move the existing refactor-compression/subset checker into pytest-owned Python code;
4. pin its refactor baseline to `87d1137a` for this migration;
5. preserve the accepted source-module subset/layout law;
6. preserve total src+tests LOC and file-count non-growth pressure;
7. remove the need to invoke a separate `refactor-check` application;
8. add native/Nix formatting or lint laws to pytest only where they are stable and warm-reusable;
9. keep testmon and xdist unless their explicit removal gates are satisfied.

Do not weaken a law to make the refactor easier.

## Phase C — compress current production Python

The codebase is intentionally oversized after several days of science and boundary work.

Delete or consolidate before adding new architecture.

Targets include:

```text
transitional helpers that duplicate Rote ownership
legacy SpIDER / Multi-SWE compatibility paths no longer needed by Atlas
old benchmark normalization code after SWE-Explore replacement exists
manual experiment-only memoization presented as architecture
dead alternative APIs
redundant wrapper classes
large printing / census / profiler scaffolding that belongs in ignored experiments
Nix outputs/apps that exist only to provide a second verification entrypoint
```

Do not line-golf the core algebra or tests.

Pressure target:

```text
< ~2000 executable-ish production Python LOC
```

Relative migration law:

```text
src + tests LOC does not grow versus 87d1137a
src + tests file count does not grow versus 87d1137a
new source modules remain in the accepted narrow subset
```

## Phase D — correct reuse boundaries while compressing

The current checkout already has Rote-cached fact/repository payloads.

Refine them around the strongest learned law:

```text
content/source identity
    -> stable admitted facts
    -> stable resolved repository payload
    -> cheap process-local PyRoaring Relation reconstruction
```

Prefer per-blob / per-primitive cache identity where it buys truthful invalidation without multiplying framework code.

Do not cache live native-backed `Relation` objects as the durable payload.

Do not create a second cache system.

Process-local row/state interning is allowed as an algorithmic optimization and must be reported separately from durable Rote reuse.

## Phase E — preserve effect ownership

The implementation agent should use effect-python deliberately at real capability boundaries:

```text
Nix realization / immutable artifact access
ObservationStore/model acquisition paths
future benchmark snapshot acquisition if effectful
tracing where appropriate
```

Pure deterministic work remains ordinary Python and should be Rote-cached when it is a meaningful expensive reusable transformation.

The architecture test is authoritative:

```text
effects.service only inside @effects.fn
library code does not close Effects with run_sync
ad-hoc functools caches are rejected
Rote boundaries may not hide mutable outer state
```

Extend this law if the refactor introduces another recurrent architectural mistake.

## Phase F — replace active old benchmark plumbing with SWE-Explore

The final science target is SWE-Explore, not SpIDER and not a privately reconstructed patch-gold surrogate.

Use official SWE-Explore records/labels where available.

Bring one TS/JS SWE-Explore repository snapshot through the existing Nix identity boundary and repository-native Grit fact path.

Then run the fixed Atlas replication grammar.

The first clean vertical slice should be:

```text
immutable SWE-Explore snapshot
    -> repository source
    -> fixed Grit facts
    -> deterministic resolution
    -> compact Relations
    -> issue-blind seeds
    -> depth-7 composition-only Atlas
    -> structural signature + real reuse telemetry
```

## Phase G — prove warm reuse through pytest

A full warm verification should not reacquire or recompute unchanged expensive work.

Required checks include:

```text
same source / same Grit program -> Rote replay
one Grit primitive changed      -> affected primitive work invalidates
unrelated primitive work        -> remains reusable
one source blob changed         -> unrelated blob fact extraction remains reusable where boundary permits
same resolved repo              -> relation/Atlas reconstruction cheap
same model RequestId            -> ObservationStore replay
```

If repeated pytest becomes slow, treat the cause as an architectural bug until disproven.

## Phase H — TS/JS SWE structural Atlas

Only after the compressed vertical slice is green:

```text
run supported TS/JS SWE-Explore population
report repository-weighted and instance-weighted signatures
measure snapshot stability
report cold/warm physical work
compare local/mixing regimes
```

## Phase I — issue-conditioned SWE exploration

Restore issue text and the frozen semantic prior only after the issue-blind Atlas is stable.

Official benchmark gold remains evaluator-only.

## Phase J — costed policy synthesis

After Atlas Gate, synthesize ordinary typed Python over the **named policy grammar** from §15.2, not the Atlas grammar.

Use:

```text
cost bound
semantic normalization
semantic interning
held-out quality
physical-work penalty
Rote replay of expensive deterministic evaluation
```

Do not enumerate the complete mixed algebra.

---

# 28. Explicit work that is deferred until Atlas Gate

Do not spend first-pass refactor time on:

```text
references primitive
inheritance primitive
custom evidence store
canonical evidence DAG
policy JSON/IR
multi-agent workflow framework
historical supervisor harness
full Code Mode synthesis UI
new database warehouse
DuckDB analytics layer
Modal distributed execution
Mojo anything
WASM anything
SCIP integration
C/C++ support
```

The point of this spec is to prevent the refactor from becoming another broad architecture campaign before the new science survives on SWE-Explore.

---

# 29. Primitive admission after Atlas Gate

Once the broad atlas exists, evaluate new primitives scientifically.

Given base grammar `G` and challenger `r`:

```text
G
vs
G + r
```

under the same:

```text
search depth / program cost budget
seed policy
repository population
memoization configuration
held-out evaluation split
```

A primitive earns admission if it materially improves one or more of:

```text
core-region reachability
best held-out description length
shortest useful structural explanation
context efficiency
policy simplicity at equal quality
```

while not merely duplicating an existing composition.

This is where `references` can return as a challenger.

---

# 30. Policy-specific structural prior after Atlas Gate

A major follow-up question is:

> Does intrinsic repository structure predict which exploration policy works?

For each repository:

```text
structural signature
    ↓
best historical policy family / expression
```

Potential relationships:

```text
high reverse-call mixing
    → avoid repeated caller expansion

low call mixing
    → deeper call compositions remain useful

high importer mixing
    → prefer forward imports or repository locality

rapid containment expansion
    → avoid broad file→symbol projection late in a path
```

Do not hard-code these rules now.

The atlas should make them testable.

---

# 31. Downstream 10× session thesis

The structural atlas is not the product goal by itself.

The long-term objective remains:

> **Reduce complete coding-agent session latency by roughly an order of magnitude where reusable repository knowledge and deterministic exploration can replace repeated model work.**

The SWE-Explore-first refactor is valuable because it measures a large component of that problem directly:

```text
finding relevant repository context
```

The likely leverage stack is:

```text
precomputed repository facts
+ repository-specific structural policy
+ semantic prior
+ durable deterministic reuse
    ↓
less interactive search
less repeated reading
less repeated model deliberation
```

Later downstream repair experiments should test whether improved exploration actually shortens successful agent sessions.

But do not delay Atlas Gate to build that downstream harness.

---

# 32. Required laws

## 32.1 Native Grit laws

```text
invalid Grit → typed compile diagnostic
valid Grit → deterministic compiled behavior
same pattern/source → same projected matches
range bytes stay inside source bytes
no object-address identity leaks into result
```

## 32.2 Fact laws

```text
all Symbol spans belong to their source File
all public import edges resolve to repository-local files
all public call edges resolve to admitted symbols
no ambiguous unresolved observation becomes an invented edge
```

## 32.3 Algebra laws

```text
reverse is correct
composition is typed
union is extensional set union
wrong endpoint composition fails static checking
```

## 32.4 Rote laws

```text
cold executes
warm reuses
helper change invalidates
primitive program change invalidates dependent work
unrelated primitive facts remain reusable
one blob change does not invalidate every blob fact shard
xdist cannot corrupt reuse state
```

## 32.5 SWE laws

```text
snapshot identity corresponds to benchmark base commit
core/optional gold never enters atlas input
issue-blind atlas never reads problem statement
issue-conditioned explorer never receives evaluator gold
```

---

# 33. Telemetry and reporting

Extend the existing profiling/reporting surface rather than inventing a dashboard stack.

Useful events:

```text
grit.compile
grit.execute
facts.extract
facts.resolve
relations.build
atlas.case
atlas.repository
rote.hit
rote.miss
prior.rank
swe.evaluate
```

If Rote does not expose a stable event hook for hit/miss telemetry, instrument the cached function body/execution boundary in tests without implementing another cache.

Never infer a cache hit solely from elapsed time.

---

# 34. Expected first reports

## 34.1 `structural-atlas.json`

Conceptual shape:

```json
{
  "dataset": "SWE-Explore",
  "seed_policy": "issue-blind-v1",
  "depth": 7,
  "repositories": {
    "org/repo": {
      "snapshots": 12,
      "relations": {
        "calls": {
          "median_density": 0.08,
          "p90_density": 0.22,
          "cross_50": 0.01,
          "extinction": 0.16
        }
      }
    }
  }
}
```

The exact serialization can remain internal.

## 34.2 `reuse-report.json`

Conceptual shape:

```json
{
  "cold": {
    "grit_executions": 1234,
    "rote_executions": 5678,
    "wall_seconds": 90.0
  },
  "warm": {
    "grit_executions": 0,
    "rote_executions": 0,
    "rote_reuses": 5678,
    "wall_seconds": 4.0
  }
}
```

Again, values are unknown until measured.

The important requirement is provenance of physical work.

---

# 35. Decision rules after the first SWE atlas

The atlas should directly determine what we build next.

## If repository signatures are stable

Proceed with:

```text
repository-specific policy priors
policy synthesis conditioned on structural signature
```

## If signatures vary heavily by issue seed

Treat structure as:

```text
seed-conditioned local geometry
```

and make policy selection depend more strongly on issue/seed state.

## If one language has low fact coverage

Fix that language's Grit semantics before inventing new global primitives.

## If many official core regions are structurally unreachable

Inspect the unreachable cases before adding a primitive.

## If warm Rote reuse is poor

Fix cache boundaries/identities before scaling policy search.

## If Grit extraction dominates cold cost

Use blob identity and language parallelism before adding infrastructure.

---

# 36. Definition of success for this refactor stage

This refactor stage is successful when all of the following are true:

```text
[x] old-world structural science is frozen in this specification
[x] issue-blind repository regimes survived issue removal
[x] whole-relation quotient measured and found modest (~1.14x)
[x] row-transition recurrence measured and found extreme (~99.1x)
[x] mixed algebra closure was tested and rejected as a production strategy
[x] actual named policy vocabulary was cost-censused
[x] Rote fresh-process replay was proven on the real stage workload

[ ] pytest is the only canonical quality/scientific entrypoint
[ ] refactor-compression/subset law executes inside pytest
[ ] Ruff / Flake8 / Fixit / BasedPyright / interrogate remain fully enabled
[ ] architecture/effect/Rote static law remains enabled and is not weakened
[ ] warm pytest remains acceptably fast through reuse rather than skipped checks
[ ] no new ad-hoc durable cache exists
[ ] meaningful deterministic expensive transforms use Rote
[ ] actual capability/effect boundaries use effect-python
[ ] ObservationStore remains separate from deterministic Rote caching
[ ] native Grit seam remains small and auditable
[ ] TypeScript fixed defines/imports/calls semantics remain green
[ ] PyRoaring semantic identity never relies on noncanonical native serialization
[ ] active old SpIDER/temporary benchmark plumbing is deleted after replacement is green
[ ] one SWE-Explore TS/JS snapshot runs end to end through repository-native facts
[ ] fixed depth-7 Atlas replication grammar runs on that snapshot
[ ] cold/warm reuse is measured under the same pytest-driven architecture
[ ] production Python is moving aggressively toward < ~2000 executable-ish LOC
[ ] tracked src+tests LOC/file count do not grow relative to 87d1137a during the refactor
[ ] no large unexplained duplicated storage footprint is introduced
```

The refactor is **not** successful merely because modules were renamed or tests were made green by weakening their laws.

The intended endpoint is a visibly smaller implementation in which:

```text
Grit explains source facts
Relation/Query explains structural composition
Atlas code explains geometry measurement
Rote explains durable deterministic reuse
effect-python explains capability boundaries
ObservationStore explains exact provider replay
Nix explains immutable external identity
pytest proves all of the above together
```

---

# 37. Immediate implementation order for the refactor agent

The implementation agent should work from the actual current checkout, not from the historical migration narrative.

Use this order unless a concrete dependency forces a small reorder:

```text
1. read this entire spec.md
2. inspect jj status/diff and the current source/test/Nix layout
3. run pytest once and preserve the full baseline failure/pass picture
4. fold the existing refactor-compression/subset checker into pytest
5. ensure pytest remains the only canonical verification entrypoint
6. make the current architecture/strict-subset tests explicit blockers
7. inventory production Python LOC and deletion candidates
8. compress current modules before adding new ones
9. keep effect-python at capability boundaries and Rote at meaningful deterministic reuse boundaries
10. eliminate accidental ad-hoc/manual durable caching
11. preserve cheap process-local semantic interning only where it is actually algorithmic
12. remove or isolate obsolete SpIDER/Multi-SWE old-world plumbing once its replacement is green
13. preserve the small PyO3/Grit leaf and current fixed semantic programs
14. wire the first official SWE-Explore TS/JS snapshot through Nix
15. build repository-native facts / compact Relations
16. run the fixed composition-only Atlas replication grammar
17. prove cold/warm/invalidation behavior from pytest
18. run full pytest repeatedly until fully green and warm behavior is sane
19. report final LOC/file counts, storage deltas, jj diff/status, and remaining Atlas-gate work
```

Do not use the Codex session to start another open-ended grammar experiment.

The science has already told us what architecture to build.

---

# 38. Final architectural sentence

> **Attune Radii should measure repository geometry with a fixed, comparable composition-only Atlas grammar, then synthesize repository-specific policies over a richer named public grammar (`~`, `>>`, `|`) under explicit complexity and physical-work budgets. Fixed human Grit programs define a tiny repository-native semantic basis through a small Rust/PyO3 Marzano leaf; compact PyRoaring relations and process-local state interning make local algebra cheap; Rote durably replays meaningful deterministic transformations; effect-python owns true capability boundaries; ObservationStore owns exact model observations; Nix owns immutable external identity; and pytest is the single executable authority that keeps the whole small system correct, typed, linted, architecturally constrained, and aggressively reusable.**

---

# 39. Preserved decision ledger — do not reopen casually

This section exists because the project has accumulated several days of architectural and scientific decisions. The Atlas-first migration changes **ordering**, not the validity of every downstream design decision.

Treat each entry below according to its status:

```text
LOCKED
    implement unless a concrete blocker falsifies it

ATLAS-LOCKED
    fixed for the first SWE-Explore structural-atlas milestone

DEFERRED
    preserve the design and rationale, but do not implement before its gate

CHALLENGER
    an empirically motivated alternative that must earn admission

SUPERSEDED
    historical direction that should not return without new evidence

REJECTED
    intentionally excluded from the present architecture
```

## 39.1 Architecture ledger

| Decision | Status | Contract |
|---|---|---|
| SWE-Explore structural atlas is the first refactor milestone | **LOCKED** | Refactor work is judged first by whether it reproduces repository-mixing/localness results on SWE-Explore with repository-native facts and real reuse. |
| Python 3.13 remains the control/science language | **LOCKED** | Keep the algebra, evaluation, metrics, policy language, and experiment control in typed Python. |
| Rust + PyO3/maturin is the native Grit boundary | **LOCKED** | No Mojo, no WIT runtime, no Wasmtime component layer, no generated C ABI for Grit. |
| Marzano/Grit owns structural matching | **LOCKED** | Do not recreate a source parser or generic AST API in Python/Rust. |
| Rote owns deterministic Python memoization | **LOCKED** | No bespoke durable memoization graph, no `sys.monitoring` clone, no test-local dict presented as the production result. |
| hierarchical reuse is a primary project mechanism | **LOCKED** | Facts, deterministic transforms, structural/search subtrees, exact observations, model prefixes, and process-local services reuse work at distinct truthful identities. |
| structural/search subtree reuse must survive policy synthesis | **LOCKED, IMPLEMENTATION STAGED** | Repeated deterministic subexpressions/states under identical immutable inputs should not require repeated physical evaluation; Rote + compact algebra + process-local interning own different layers. |
| explicit `@rote.cache` boundaries are preferred for meaningful durable transforms | **LOCKED LEGIBILITY LAW** | Keep persistent memoization visible in ordinary source; Fixit may suggest safe annotations, but do not blanket-autowrap the codebase invisibly. |
| effect-python owns effect/capability composition | **LOCKED** | External capabilities remain typed; pure relation/policy work remains ordinary Python. Effectful operations may still reuse work through the identity-owning Nix/ObservationStore/KV/layer mechanism. |
| Nix owns immutable external artifacts | **LOCKED** | Dataset snapshots, native sources/toolchains, benchmark inputs, and fixed artifacts enter through immutable Nix identity rather than ambient shell setup. |
| ObservationStore owns exact model/network observation identity | **LOCKED** | Identical canonical requests replay retained observations with zero provider work; never put stochastic provider acquisition under Rote. |
| provider KV/prefix reuse is a required second model-reuse layer | **LOCKED, POST-ATLAS** | On an ObservationStore miss, preserve stable prefixes so supported providers can reuse prefill/KV work; cache residency is acceleration, never scientific truth. |
| faithful transcript prefix tree and canonical evidence DAG are distinct | **LOCKED DISTINCTION** | Prefix-tree reuse preserves exact ordered history; evidence-DAG canonicalization changes model-visible state and must be evaluated separately. |
| pytest remains the executable scientific host | **LOCKED** | Tests/laws/experiments remain ordinary pytest; xdist stays. |
| testmon is transitional | **DEFERRED REMOVAL** | Keep until warm full-suite reuse is proven; then delete if its removal criteria are satisfied. |
| SpIDER is bootstrap/history only | **SUPERSEDED** | No final SpIDER parity gate; delete active SpIDER data/runtime paths after Grit/SWE vertical slice is green. |
| No PolicyProgram JSON/IR | **REJECTED** | The policy artifact is ordinary typed Python using the relation algebra. |
| No generic graph framework | **REJECTED** | Four relations and a tiny typed algebra are enough until evidence says otherwise. |
| No generic evidence framework initially | **REJECTED** | `Region`/small immutable aliases and functions are enough until canonical evidence-DAG work actually requires richer state. |
| No syntax-tree API from native Grit | **REJECTED** | Surface match/log ranges and diagnostics only. |
| C/C++ in first SWE-Explore slice | **DEFERRED** | Do not add another parser/indexer merely to cover the tail. |

## 39.2 Structural-language ledger

| Decision | Status | Contract |
|---|---|---|
| `defines : FileId -> SymbolId` | **ATLAS-LOCKED** | Future name for current file→callable membership relation. |
| `imports : FileId -> FileId` | **ATLAS-LOCKED** | Local resolved static file/module dependency. |
| `calls : SymbolId -> SymbolId` | **ATLAS-LOCKED** | Statically admitted call relation; unresolved/ambiguous calls do not create false edges. |
| `parent` | **ATLAS-LOCKED vocabulary, later Atlas phase** | Repository topology relation; not required to block the first source-relation atlas. |
| reverse operator `~` | **LOCKED** | First-class algebra operation. |
| composition `>>` | **LOCKED** | First-class typed algebra operation. |
| union `|` | **LOCKED** | Actual-vocabulary cost census confirms that union is highly generative and materially expands the public policy language; keep. |
| intersection `&` in public `Query` | **CHALLENGER** | Mixed/costed experiments show it can be relation-expressive while reusing familiar row states, but evidence still does not justify growing public `Query`. |
| difference `-` in public `Query` | **CHALLENGER / LOW PRIORITY** | Generates real semantics but expands directed search heavily and remains the weakest public-language candidate; do not add now. |
| `references : SymbolId -> SymbolId` | **CHALLENGER** | Preserve design, but it must beat the four-primitive grammar under equal budget before admission. |
| Atlas grammar versus policy grammar | **LOCKED DISTINCTION** | Atlas stays six directed source relations + `>>` to depth 7 for comparability; post-Atlas synthesis uses named concepts + `~`, `>>`, `|` under a cost budget. |
| named derived concepts are synthesis atoms | **LOCKED** | `same_file`, `import_neighbors`, `importer_neighbors`, `repository_adjacent` are charged as public concepts, not by hidden implementation expansion. |
| complete mixed algebra closure | **REJECTED** | Explicit closure experiments hit large row/relation ceilings while arbitrary union remained highly novel; do not precompute exhaustive closure. |
| canonical bitmap semantic encoding | **LOCKED** | Persistent scientific identity must encode logical bitmap membership canonically; native Roaring serialization is not semantic identity. |
| inheritance/implements/overrides | **DEFERRED / NO CURRENT EVIDENCE** | Current TS census exposed no inheritance edges; do not add based on intuition. |
| owner/class locality primitive | **DEFERRED / WEAK EVIDENCE** | Current corpus showed almost no owner-locality value. |
| unify `FileId`/`RepoId` into a single `LocationId` | **OPEN CLEANUP** | Attractive simplification, but must not block the Atlas Gate. |

## 39.3 Scientific ledger

| Decision | Status | Contract |
|---|---|---|
| normalized frontier density is the primary localness observable | **LOCKED** | Prefer density/threshold crossing over raw expansion factor. |
| measure 25% / 50% / 90% thresholds | **LOCKED** | Preserve output-above-threshold and true crossing-from-below statistics separately. |
| measure extinction/absorbing behavior | **LOCKED** | Empty/frontier collapse is scientifically and computationally meaningful. |
| memoization must report logical vs physical work | **LOCKED** | Never reduce the reuse story to a hit-rate percentage alone. |
| marginal physical exploration cost should fall as valid reusable state accumulates | **LOCKED LONG-TERM THESIS** | More prior facts, subtrees, observations, and stable prefixes should reduce new physical work without weakening correctness. |
| exact model replay and provider KV reuse must be reported separately | **LOCKED** | Exact replay performs zero provider work; KV reuse accelerates a live miss and must retain provider cache-read/write accounting where available. |
| repository signature must be tested issue-blind | **LOCKED PRE-REFACTOR CONTROL** | The final old-world experiment removes issue-conditioned centers. |
| one public Python API must serve pytest, Xonsh, CLI, and demos | **LOCKED PRODUCT/API DECISION** | Tests and shell tooling adapt the library; they do not reimplement it. |
| optional Starship integration must be presentation-only and side-effect free | **LOCKED UX LAW** | Prompt rendering may show cheaply published state but may never trigger Nix/Grit/model/cache population work. |
| depth 8 is not automatically justified | **LOCKED UNTIL NEW EVIDENCE** | Depth 7 already exposes strong coverage and mixing; more depth can create structural fog. |
| primitive admission is a language-compression test | **LOCKED** | A new primitive must shorten useful explanations / improve held-out score under equal compute, not merely sound semantically appealing. |
| whole-relation quotient is not the primary compression layer | **LOCKED RESULT** | 3279 composition programs yielded 2876 exact full relations (~1.14x); do not design around a hypothetical tiny quotient. |
| exact row/state transition reuse is a primary physical optimization | **LOCKED RESULT** | Composition census observed ~37.6M row applications but ~379k unique exact transitions (~99.1x recurrence). |
| global pooled support-core replacement | **REJECTED BY EXPERIMENT** | Support recurrence exists, but pooled cores lost too much source coverage to replace exact path semantics. |
| Rote fresh-process replay on meaningful deterministic stages | **PROVEN** | Chained canary and science workloads replayed hundreds-to-thousands-fold faster when telemetry stayed outside the pure cached function. |
| old-world MUI algebra census | **CLOSED** | No further depth/operator/closure extension absent a new blocker or SWE-driven question. |

---

# 40. Full empirical record that motivated the Atlas-first refactor

This record is intentionally preserved even though the temporary implementation will be deleted. The numbers explain why the permanent system is being built the way it is.

## 40.1 Six primitive directions in the temporary search grammar

The pre-refactor finite search used:

```text
contains      File   -> Symbol
~contains     Symbol -> File
imports       File   -> File
~imports      File   -> File
invokes       Symbol -> Symbol
~invokes      Symbol -> Symbol
```

The post-refactor semantic names are:

```text
defines       File   -> Symbol
~defines      Symbol -> File
imports       File   -> File
~imports      File   -> File
calls         Symbol -> Symbol
~calls        Symbol -> Symbol
```

The rename is semantic cleanup only. It must not silently change the meaning of the admitted facts.

## 40.2 Primitive-discovery census before finite synthesis

Sixteen candidate microscopes were evaluated over the 90-case TypeScript slice.

Direct candidates:

```text
file_peers
owner_peers
callees
callers
imported_members
importer_members
inherit_forward_members
inherit_reverse_members
```

Compositions:

```text
callee_file_peers
caller_file_peers
callee_owner_peers
caller_owner_peers
file_peer_callees
file_peer_callers
imported_member_callees
importer_member_callers
```

Aggregate results:

```text
proposal                            mean n  nonempty  gold cases  gold total   gold/100n unique best
----------------------------------------------------------------------------------------------------
callee_file_peers                    115.1        85          24          55       0.531           1
callee_owner_peers                     4.2        27           1           1       0.267           0
callees                               14.4        81          11          17       1.308           0
caller_file_peers                     51.7        64          14          29       0.623           0
caller_owner_peers                     3.1        13           2           2       0.722           0
callers                                5.8        53           7          15       2.868           0
file_peer_callees                     50.5        86          19          36       0.793           0
file_peer_callers                     51.5        79          19          42       0.906           1
file_peers                            33.0        85          20          42       1.416           0
imported_member_callees              137.5        76          17          33       0.267           1
imported_members                     119.3        78          18          41       0.382           1
importer_member_callers              158.1        57          15          37       0.260           5
importer_members                     111.7        69          10          27       0.269           1
inherit_forward_members                0.0         0           0           0       0.000           0
inherit_reverse_members                0.0         0           0           0       0.000           0
owner_peers                            0.7         6           1           1       1.613           0
```

Interpretation to preserve:

```text
inheritance was dead in this slice;
owner locality was almost absent;
containment, calls, and imports created useful non-equivalent behavior;
composition produced genuinely new useful microscopes without adding primitives;
importer_member_callers had five unique-best cases.
```

This is why the refactor begins with a **small universal vocabulary plus composition**, not a large catalog of source facts.

## 40.3 Direct-microscope overlap

Mean Jaccard overlaps across direct microscopes were low:

```text
file_peers <-> callees          0.099
file_peers <-> callers          0.091
file_peers <-> imported         0.087
file_peers <-> importers        0.104
callees <-> callers             0.098
callees <-> imported            0.094
callees <-> importers           0.093
callers <-> imported            0.118
callers <-> importers           0.214
imported <-> importers          0.231
```

The basis is therefore small but behaviorally diverse.

## 40.4 Constructive mathematical distinctness witness

Keep the permanent finite witness proving the current structural microscopes are extensionally distinct on at least one common input.

The present law has the shape:

```python
def test_structural_microscopes_are_extensionally_distinct() -> None:
    microscopes = (
        same_file,
        callees,
        callers,
        import_neighbors,
        importer_neighbors,
    )

    outputs = tuple(
        select(RELATIONS, microscope, VERIFY_ONLY)
        for microscope in microscopes
    )

    assert len(frozenset(outputs)) == len(microscopes)
```

The rationale matters:

> A single finite witness on which every function returns a different value constructively proves that no pair denotes the same function.

The fixture should be rewritten in the post-Grit vocabulary, not deleted as SpIDER debris.

---

# 41. Structural localness scoring law

The finite-language search used a simple two-part description-length view of structural locality.

For a case universe `U`:

```text
L0(g) = log2 |U|
```

For a structural query `Q`, calibrate:

```text
p_Q = (gold_inside + 1) / (gold_total + 2)
```

If gold is inside `Q`:

```text
L_Q(g) = -log2(p_Q) + log2(|Q|)
```

If gold is outside `Q`:

```text
L_Q(g) = -log2(1 - p_Q) + log2(|U - Q|)
```

Bits saved:

```text
DeltaI_Q = L0 - L_Q
```

Plain interpretation:

> Encode the hidden gold globally, or first encode whether it lies inside this structural neighborhood and then encode it locally within the selected partition.

Important statistical caveat:

The exploratory run calibrated and scored `p_Q` on the same 90 cases. That was acceptable for grammar exploration, not final evidence. Permanent evaluation should use held-out calibration such as repository-held-out or explicit train/evaluation splits.

Do not silently promote exploratory same-population description-length numbers into benchmark claims.

---

# 42. Finite relational-language search — exact evidence through depth 7

The project deliberately exhausted a meaningful finite grammar before adding more primitive nouns.

## 42.1 Typed path-count law

Starting from `Symbol`, with the six directed primitive atoms above, the number of exact-depth well-typed `Symbol -> Symbol` paths was:

```text
depth 1:      2
depth 2:      5
depth 3:     14
depth 4:     41
depth 5:    122
depth 6:    365
depth 7:   1094
depth 8:   3281
depth 9:   9842
depth 10: 29525
```

Closed form:

```text
S_d = (3^d + 1) / 2
```

Cumulative complete `Symbol -> Symbol` paths:

```text
d4      62
d5     184
d6     549
d7    1643
d8    4924
d9   14766
d10  44291
```

All typed prefixes cumulative through maximum depth `d`:

```text
(3^(d + 1) - 3) / 2
```

At depth 7:

```text
typed prefixes = 3279
complete Symbol->Symbol paths = 1643
```

## 42.2 Baseline for the residual-gold experiment

```text
baseline_bits_per_gold = 10.992
remaining_gold = 233
```

## 42.3 Depth-by-depth result

### Depth 1

```text
candidates              2
unique                   2
gold reachable         30 / 233 = 12.88%
best                    invokes
best fixed save          0.1671 bits/gold
per-case oracle save     0.3587
```

### Depth 2

```text
cumulative paths         7
unique                   7
gold reachable          91 / 233 = 39.06%
new reachable          +61
best                    ~contains >> contains
best fixed save          0.4379
oracle save              0.9240
```

### Depth 3

```text
cumulative paths        21
unique                  21
gold reachable         137 / 233 = 58.8%
new reachable          +46
best fixed save          0.4379
oracle save              1.2134
```

### Depth 4

```text
cumulative paths        62
unique                  61
gold reachable         177 / 233 = 75.97%
new reachable          +40
best                    invokes >> ~invokes >> ~contains >> contains
best fixed save          0.5161
oracle save              1.5527
```

### Depth 5

```text
cumulative paths       184
unique                 175
gold reachable         204 / 233 = 87.55%
new reachable          +27
best fixed save          0.5161
oracle save              1.8559
```

### Depth 6

```text
cumulative paths       549
unique                 503
gold reachable         209 / 233 = 89.70%
new reachable           +5
best                    invokes >> ~contains >> contains >> ~invokes >> ~contains >> contains
best fixed save          0.5166
oracle save              2.0261
```

### Depth 7

```text
cumulative paths      1643
unique                1455
gold reachable         218 / 233 = 93.56%
new reachable           +9
best                    invokes >> ~invokes >> invokes >> invokes >> ~invokes >> ~contains >> contains
best fixed save          0.5734
oracle save              2.2588
unreachable residual     15 / 233
```

## 42.4 What the depth result means

Preserve these conclusions:

1. The vocabulary has a rich hypothesis space despite having only three source-semantic primitive families plus direction.
2. `1455 / 1643` extensional behaviors at depth <= 7 means the grammar is still not dominated by redundant syntax.
3. `93.56%` residual-gold reachability is strong evidence that the primitive vocabulary is close to coverage-sufficient on this corpus.
4. The best **single fixed** expression improves slowly while the **oracle** improves strongly.
5. Therefore selection/routing is increasingly more limiting than raw expressivity for the reachable cases.
6. The 15 unreachable residual gold nodes are more informative for primitive admission than blindly increasing depth.
7. Depth 8 must not be run merely because it is next numerically; repository mixing indicates that longer paths can become structural fog rather than finer microscopes.

## 42.5 Top fixed paths from the depth-7 run

```text
0.5734 save, mean candidates 1110.3, gold 166/233
  invokes >> ~invokes >> invokes >> invokes >> ~invokes >> ~contains >> contains

0.5166 save, mean candidates 834.8, gold 148/233
  invokes >> ~contains >> contains >> ~invokes >> ~contains >> contains

0.5161 save, mean candidates 704.9, gold 136/233
  invokes >> ~invokes >> ~contains >> contains

0.5139 save, mean candidates 338.1, gold 101/233
  invokes >> ~contains >> contains >> ~invokes

0.4379 save, mean candidates 33.0, gold 42/233
  ~contains >> contains
```

The first path's high fixed score does **not** imply that returning ~1110 candidates is a desirable production policy. The description-length objective and later repository-mixing analysis are precisely why candidate density must remain visible.

---

# 43. Repository-locality radius result

Repository-path locality was separately tested using bounded parent-tree radii.

```text
repository_r1  save  0.4379, bits/gold 10.5541, mean candidates   33.0, gold  42/233
repository_r2  save  0.7071, bits/gold 10.2849, mean candidates  257.9, gold  90/233
repository_r4  save  0.3870, bits/gold 10.6050, mean candidates  767.3, gold 174/233
repository_r8  save -0.0184, bits/gold 11.0105, mean candidates 1793.8, gold 213/233
```

This is a direct empirical localness curve:

```text
radius too small
    misses useful evidence

moderate radius
    strong compression/locality

large radius
    floods the repository and loses information value
```

This result is one reason `parent` remains part of the permanent vocabulary even though it does not block the first source-relation Atlas Gate.

---

# 44. Binary-operator frontier — why union stays and intersection/difference wait

One-layer binary challengers were evaluated over structural path outputs.

Depth-4 path behaviors:

```text
62 syntax paths
61 extensional behaviors
```

Pairwise challenger counts:

```text
union:
    1830 pairs
    1806 novel extensional behaviors

intersection:
    1830 pairs
    1806 novel extensional behaviors

difference:
    3660 directed pairs
    3637 novel extensional behaviors
```

Oracle-frontier improvement:

```text
paths + repository oracle save      1.6709
+ union                             1.9440   (+0.2731)
+ intersection                      2.1056   (+0.1616)
+ difference                        2.1770   (+0.0714)
```

Decision:

```text
union
    public and permanent

intersection
    scientifically interesting challenger
    not yet worth growing Query

difference
    weakest incremental value
    doubles directed candidate space
    do not add now
```

Do not recursively enumerate arbitrary binary ASTs before the Atlas Gate. The one-layer experiment already established the ranking of these operators well enough for present architectural decisions.

---

# 45. Structural mixing/localness — permanent conceptual model

The repository census changed the interpretation of the finite-language search.

The useful concept is not merely path depth. It is **how quickly a relation sequence loses locality**.

For a frontier `S` in typed universe `V`:

```text
density(S) = |S| / |V|
```

For one primitive relation `R`:

```text
expansion(R, S) = |R(S)| / max(|S|, 1)
```

But density is the more important localization quantity.

Potential repository-level mixing times:

```text
T25 = first depth reaching 25% of typed universe
T50 = first depth reaching 50%
T90 = first depth reaching 90%
```

A useful informal phrase is **localness half-life**: the amount of relational traversal available before a neighborhood stops being meaningfully local.

Do not call this literal information-theoretic entropy unless an actual entropy statistic is defined. "Structural entropy" has been useful conversational shorthand only.

## 45.1 MUI character

Observed averages in the repository memoization census:

```text
cases                  41
mean files           2741.6
mean callables       1927.9
mean imports         1305.3
mean invokes         1106.7
mean input frontier    48.43
mean physical          767.4
mean unique fronts     588.1
whole-frontier reuse     4.273x
mean seconds             0.099
```

Interpretation:

```text
wide
modular
repetitive component families
many local structural islands
many collapsing / empty frontier states
high semantic-state convergence
```

A representative extreme case collapsed:

```text
3279 logical prefixes
15 physical transitions
4 unique frontiers
218.6x reuse
```

The tree reached an absorbing empty state by roughly depth 4.

## 45.2 Vue core character

Observed averages:

```text
cases                  47
mean files            464.7
mean callables       2127.7
mean imports         1123.3
mean invokes         5483.0
mean input frontier   492.79
mean physical        2689.5
mean unique fronts   2437.3
whole-frontier reuse    1.219x
mean seconds            3.278
```

Interpretation:

```text
compact source tree
densely interconnected runtime/compiler/reactivity/rendering machinery
long-lived non-empty frontiers
rapid expansion toward the callable universe
low whole-frontier convergence
```

The concise contrast to preserve is:

> **MUI is wide and modular. Vue is compact and deeply interconnected.**

## 45.3 Darkreader character

Only two cases were present, so treat this as suggestive rather than population-stable.

Observed behavior was between/near Vue rather than MUI:

```text
call density              ~2.6–2.73 invokes/callable
mean frontier             ~210–225
whole-frontier reuse      ~1.26–1.36x
seconds                   ~1.24–1.34
```

The relation-specific mixing run then showed mean symbol-density behavior near Vue.

## 45.4 Runtime correlation result

Across the 90 temporary cases, runtime tracked total frontier-member volume almost perfectly:

```text
mean_input_frontier          0.9950
mean_output_frontier         0.9956
physical_input_members       0.9995
physical_output_members      0.9992
max_input_frontier           0.9820
max_output_frontier          0.9772
invokes                      0.9798
invokes_per_callable         0.9659
physical                     0.9210
unique_frontiers             0.9349
```

Raw file-count correlations were strongly confounded by repository family and must not be interpreted causally.

The robust mechanical lesson is:

> In the temporary Python/frozenset implementation, runtime was dominated by the number of set members flowing through physical transitions, not by source-tree size alone.

This is why the production system must distinguish:

```text
evidence reuse
    do not reacquire primitive facts

state reuse
    do not recompute identical semantic frontiers

algebra reuse
    do not repeatedly materialize giant set operations unnecessarily
```

Rote primarily addresses durable deterministic computation reuse. Compact `Relation` representation and good policy search address algebra work.

---

# 46. Relation-specific mixing result — exact pre-refactor baseline

The final semantic-seed relation-specific run completed 90 depth-7 cases in approximately 172 seconds after removing an instrumentation bug.

## 46.1 Darkreader

```text
relation      mean out   p90 out   outputs >=25%   >=50%   >=90%
-----------------------------------------------------------------
contains        0.612      83.1%        92.2%       75.1%     1.7%
~contains       0.250      37.1%        58.5%        0.0%     0.0%
imports         0.383      67.1%        68.8%       28.5%     0.0%
~imports        0.435      71.1%        88.5%       26.5%     0.0%
invokes         0.467      60.2%        88.3%       57.2%     0.0%
~invokes        0.490      62.2%        91.4%       62.0%     0.0%
```

## 46.2 MUI

```text
relation      mean out   p90 out   outputs >=25%   >=50%   >=90%
-----------------------------------------------------------------
contains        0.053      14.6%         0.1%        0.0%     0.0%
~contains       0.013       2.9%         0.0%        0.0%     0.0%
imports         0.022       5.7%         0.0%        0.0%     0.0%
~imports        0.027       6.6%         0.0%        0.0%     0.0%
invokes         0.019       5.4%         0.0%        0.0%     0.0%
~invokes        0.042      10.6%         0.1%        0.0%     0.0%
```

## 46.3 Vue core

```text
relation      mean out   p90 out   outputs >=25%   >=50%   >=90%
-----------------------------------------------------------------
contains        0.485      80.8%        86.0%       45.1%     3.3%
~contains       0.356      63.1%        62.9%       30.7%     0.0%
imports         0.259      41.2%        51.4%        0.0%     0.0%
~imports        0.407      62.8%        80.1%       34.3%     0.0%
invokes         0.373      56.6%        73.6%       28.9%     0.0%
~invokes        0.487      64.9%        90.6%       56.8%     0.0%
```

## 46.4 Cause versus state

The permanent metric must preserve two distinct threshold statistics:

```text
output_fraction >= threshold
    how often the resulting state is already globally dense

crossing_fraction
    how often this relation moved the state from below the threshold to above it
```

The second is closer to a causal transition diagnostic.

Example from Vue callers (`~invokes`):

```text
outputs >= 50%        56.78%
true 50% crossings    28.78%
```

Do not collapse those columns.

## 46.5 Key scientific statement to test on SWE-Explore

The current best formulation is:

> **Issues choose where exploration begins; repository geometry strongly constrains how exploration propagates.**

The issue-blind seed ablation must either support, weaken, or falsify that statement before the old scaffolding is deleted.

---

# 47. Memoization model — preserve the hierarchy, replace the temporary mechanism

The temporary depth-7 code used:

```python
transitions[(atom.name, whole_frontier)] = reached
```

That was scientifically useful because it let us count logical versus physical transition work. It is **not** the production memoization architecture.

## 47.1 Four different kinds of work

The production implementation and telemetry should distinguish:

```text
logical work
    policy/search AST nodes considered

frontier work
    distinct (operator, whole frontier) evaluations

evidence work
    distinct primitive facts or node-neighborhood queries physically acquired

set/algebra work
    unions/intersections/projections over retained evidence
```

A single "cache hit rate" cannot explain these layers.

## 47.2 Algebraic node/fact decomposition

Every primitive finite relation distributes over set union:

```text
R(A union B) = R(A) union R(B)
```

Therefore a stronger conceptual cache unit is:

```text
(atom, individual node) -> adjacent nodes
```

and a frontier step becomes:

```text
step(atom, frontier)
    = union(memo[atom, node] for node in frontier)
```

Do **not** implement a second persistent cache specifically for this.

The permanent approach is:

```text
Grit facts / admitted relation shards
    persistent deterministic transformations under Rote

Relation adjacency
    compact in-memory data structure

whole policy/search evaluation
    optionally Rote-cached at meaningful boundaries

search-state interning
    ordinary process-local algorithmic deduplication
```

## 47.3 Three semantic memoization levels

This is a permanent research model for later policy synthesis, not a disposable experiment detail:

### 1. Syntactic hash-consing

```text
ExprId = hash(normalized AST)
```

### 2. Evaluation/subtree memoization

Repeated subexpressions on identical immutable inputs reuse deterministic results.

### 3. Extensional empirical convergence

Different programs that produce the same behavior vector across a frozen population can be grouped into an empirical equivalence class:

```text
EquivalenceClass
    representative = shortest readable expression
    alternatives   = other observed equivalent expressions
```

Possible future loop:

```text
enumerate syntax
    ↓
memoized evaluation
    ↓
discover empirical equivalence
    ↓
try to falsify equivalence on synthetic worlds
    ↓
promote proven rewrite
    ↓
future synthesis avoids redundant syntax
```

Implementation of the full three-level synthesis loop is deferred until after Atlas Gate.

The requirement that repeated deterministic subtrees/states reuse work is **not** deferred; Atlas telemetry should already make logical-versus-physical convergence visible.

## 47.4 Shared-prefix tree evaluation

When policy/search expressions share a prefix:

```text
A >> B >> C
A >> B >> D
A >> B >> E
```

the system should not conceptually treat the `A >> B` state as unrelated work three times.

At minimum, process-local exploration should share the already-computed semantic state.

At meaningful persistent boundaries, Rote may retain the corresponding deterministic result across processes/runs.

Later synthesis should measure:

```text
syntactic nodes considered
unique normalized subexpressions
unique semantic states
physical subtree evaluations
Rote reuses
process-local subtree/state reuses
```

The goal is not line-level cleverness. It is to make the search cost proportional to new semantics rather than duplicated syntax.

---

# 48. Rote contract in detail

Rote is not just a convenience cache. It is the project's intended dependency-aware deterministic reuse engine.

## 48.1 What Rote owns

Good boundaries include:

```text
normalize Grit observations
build admitted fact shards
build compact Relations from stable facts
rank retained embeddings
resolve deterministic relation shards
evaluate a frozen policy over immutable cases
score one immutable benchmark shard
canonicalize later evidence state
```

Do not blanket-decorate every helper.

A Rote boundary should name a meaningful expensive deterministic transformation.

## 48.2 What Rote must never own

A Rote-cached function must not directly:

```text
call a model/network provider
run arbitrary subprocess acquisition
perform Nix evaluation/realization
write external mutable scientific state
read ambient environment configuration as semantic input
consume wall-clock/random/UUID entropy
```

Those are effects or external observations.

## 48.3 Immutable Nix identity must be explicit

For core external artifacts, pass a branded immutable input such as:

```python
NixPath = NewType("NixPath", Path)
```

Do not assume Rote can observe every native-library file read, particularly reads performed inside C/Rust extensions.

The immutable artifact identity must be an explicit argument to the deterministic transformation.

## 48.4 Serializer boundary

Do not assume live native-backed objects are good persistent cache payloads.

Potential problematic objects include:

```text
RoaringRel-backed Relation
live PyO3 Grit handles
native Nix evaluator objects
PyArrow-native objects
```

Preferred rule:

```text
cache stable serializable admitted values
reconstruct cheap native indexes/handles process-locally
```

## 48.5 Rote + BasedPyright law

The exact project configuration remains strict:

```text
typeCheckingMode = all
reportAny        = error
failOnWarnings   = true
```

A cached function must retain its visible type:

```python
@rote.cache
def f(x: A) -> B:
    ...

# BasedPyright must still see: (x: A) -> B
```

Do not weaken the checker to accommodate memoization.

## 48.6 xdist law

Exercise cold and warm identical calls under:

```text
pytest -n=8 --dist=worksteal
```

Required:

```text
no cache corruption
no partial write treated as a hit
deterministic result equality
safe cold races
```

Duplicate deterministic compute during a cold race is tolerable initially if correctness is preserved. Stale or corrupt reuse is not.

---

# 49. Nix ownership contract

Nix remains the immutable artifact boundary even though the first refactor milestone is structural science.

## 49.1 No ambient shell correctness

Application correctness must not depend on:

```text
shellHook exports
manually set benchmark paths
"remember to enter the right shell"
```

The current direct Nix API work already exists and should be preserved rather than replaced by environment-variable plumbing.

## 49.2 One coherent application-facing Nix world

Prefer an intentional attrset/surface rather than unrelated environment variables.

For the SWE-first architecture, the Nix-owned world should eventually identify at least:

```text
SWE-Explore dataset revision
repository snapshot acquisition inputs
pinned Marzano/Grit sources
Rust/PyO3 extension build
language grammar dependencies
Python environment
```

Do not force every derived local file into Nix merely because Nix exists. Nix owns immutable external/artifact identity; Rote owns deterministic transformation reuse.

## 49.3 Nix runtime ownership

The current project already has a native Nix evaluator/store path with explicit lifetime management. Do not gratuitously rewrite it during the Atlas Gate unless it blocks the SWE input surface.

---

# 50. effect-python contract

Keep effect-python as the typed physical capability layer.

Useful capabilities:

```text
Nix
ObservationStore
ModelProvider / EmbeddingModel
GritRuntime if repository acquisition/execution needs an effect boundary
CandidateRunner later
Tracer
```

Examples of the desired type shape:

```text
Effect[Success, ExpectedError, Requirements]
```

Pure work remains plain Python:

```text
Relation algebra
Query composition
structural signature reduction
policy execution
ranking projection
localness scoring
support counting
stopping rules
evidence canonicalization
```

Do not make `Query` itself an Effect program.

## 50.1 Layers and sealing

Use effect layers to construct and hide implementation dependencies when that improves the public capability surface.

Do not build a custom dependency-resolver graph around effect-python.

## 50.2 OTel

Preserve effect-python's tracing/OTel usefulness for execution observability, but traces are operational evidence, not scientific authority.

The scientific report must derive from explicit deterministic counters/records, not from whatever spans happened to be sampled.

---

# 51. ObservationStore and model-boundary contract

Model/network observations are separate from deterministic memoization, but they are not exempt from the project's reuse thesis.

Model inference has **two distinct reuse layers**:

```text
1. exact semantic request identity
       -> ObservationStore replay
       -> zero provider inference

2. new semantic request with an exact stable token prefix
       -> live provider request
       -> provider KV/prompt-cache reuse where supported
```

The first is durable semantic replay.

The second is partial physical inference reuse.

They must remain separately observable.

## 51.1 Canonical lifecycle

```text
canonical provider request
    ↓
RequestId
    ↓
ObservationStore
    ├── hit  -> replay retained raw observation
    └── miss -> explicit acquire mode required
```

Replay must never silently fall through to live acquisition.

## 51.2 Request identity

Provider-visible semantic inputs belong in request identity:

```text
provider/model identity
prompt/instructions
input payload
output/tool/schema contract
sampling/generation settings
reasoning/token settings when output-relevant
explicit sample/freshness policy
```

Local validation constraints that do not alter provider output should not force a new provider call.

## 51.3 Raw observation versus local admission

The architecture must support:

```text
change local decoder/validation
    -> deterministic admission recomputes
    -> retained raw provider response reused
    -> no provider request

change prompt/model/provider-visible settings
    -> RequestId changes
    -> replay misses
    -> explicit acquisition required
```

This remains important for the frozen embedding prior and later policy-agent work even though the initial issue-blind Atlas layer uses no model call.

## 51.4 DeepSeek-harness-inspired stable-prefix discipline

When a live model request is necessary, arrange provider-visible context so the most reusable material appears earliest and remains byte/token stable for as long as practical.

Canonical conceptual order:

```text
P0  fixed system/model-independent contract
P1  fixed Attune exploration/policy instructions
P2  fixed ordered tool / Code Mode schemas
P3  stable repository/index/context material
P4  issue/task-specific text
P5+ append-only evidence, tool results, actions, and continuation history
```

Guidelines:

```text
keep P0-P2 byte/token stable within a compatibility epoch
keep P3 stable for branches sharing the same repository context
append dynamic evidence/history instead of rewriting earlier turns
keep volatile metadata late
do not place timestamps/random IDs before reusable prefixes
do not reorder tool definitions or schema object keys casually
do not regenerate semantically identical stable context with nondeterministic formatting
```

This discipline is inspired by the DeepSeek harness work in which stable context ordering and append-oriented sessions produced dramatically better prefix-cache behavior.

One prior harness ordering experiment motivating this rule moved stable injected context before variable user content and observed approximately:

```text
provider cache reuse    ~42% -> ~94%
TTFT                     ~10s -> ~3s
```

Repeated identical prompts in that investigation approached near-total prefix reuse.

Treat those historical measurements as motivation, not as Attune benchmark results or acceptance thresholds.

## 51.5 Prefix identity

A faithful model prefix is identified by exact provider-visible semantics, conceptually:

```text
PrefixId = hash(
    provider/model revision,
    tokenizer/protocol revision where relevant,
    ordered system/instruction bytes or tokens,
    ordered tool/schema surface,
    ordered messages through the prefix boundary,
)
```

A branch may reuse prefix `S` only if the model sees the same ordered prefix under the relevant provider/cache semantics.

Do not call two prompts equivalent merely because they contain the same facts in a different order.

## 51.6 Cache-bust law

The system should make accidental prefix invalidation visible.

Examples of suspicious changes:

```text
same logical tool schema emitted in a different order
volatile cwd/session/timestamp inserted before the stable prefix
stable repository context regenerated with nondeterministic ordering
unchanged instructions reformatted on every request
earlier transcript rewritten instead of appending a suffix
```

Where provider accounting exists, tests/telemetry should preserve:

```text
cache_read_tokens
cache_write_tokens
fresh/uncached input tokens when derivable
TTFT
provider latency
output tokens
cost
```

A provider KV miss is not automatically a correctness failure, but unexplained cache busting on a supposedly stable prefix is an optimization regression worth surfacing.

## 51.7 Exact replay remains stronger than KV reuse

ObservationStore replay should always win when the canonical request is already retained.

Do not make a paid/live provider request merely to obtain a KV hit for an observation Attune already owns.

Conceptually:

```text
RequestId hit?
    yes -> replay retained observation
    no  -> live provider path
           -> maximize stable-prefix/KV reuse
```

Provider KV residency must never be required to reproduce a scientific result.

Durable observations/messages/evidence remain sufficient to reconstruct the logical run.

## 51.8 Model reuse acceptance laws

When the faithful-prefix phase begins, require at least the following executable laws.

### Exact observation replay

```text
first acquire
    -> provider live

same RequestId again
    -> ObservationStore replay
    -> zero provider request
```

### Stable-prefix live miss

For a supported provider/model and a deliberately changed suffix/request:

```text
stable P0-P3 prefix
changed P4/P5+ suffix
    -> RequestId miss
    -> provider live
    -> provider cache-read/KV reuse is observable when the provider reports it
```

Do not require a provider-specific positive cache hit in offline/unit tests. Preserve a deterministic request-layout law locally and run the provider accounting check in an explicit integration experiment.

### Cache-bust perturbation

Deliberately alter an early stable-prefix component and verify that the request/prefix identity changes.

Examples:

```text
tool schema order
system instruction bytes
stable repository context bytes
model/tokenizer/tool-surface identity
```

### Observation accounting persistence

Retained provider messages must preserve native usage/provenance fields needed to reconstruct:

```text
input tokens
cache-read tokens
cache-write tokens
output tokens
provider/model identity
```

---

# 52. Frozen semantic prior — preserve, do not entangle with structural truth

The embedding prior and repository relations answer different questions.

```text
semantic prior
    where should exploration start for this issue?

structural relations
    how does evidence propagate through this repository?
```

The issue-blind Atlas intentionally removes the first to characterize the second.

Issue-conditioned SWE evaluation restores the frozen prior after intrinsic structural geometry is measured.

## 52.1 Observation identity

Embedding acquisition remains an ObservationStore/model concern.

Local cosine ranking is deterministic and may be Rote-cached.

## 52.2 Current semantic-center lesson

The finite-search experiments strongly suggest that once the repository becomes sufficiently expressive, **policy selection** is more limiting than raw relation vocabulary for reachable cases.

Do not respond to every localization miss by adding a new primitive.

---

# 53. Grit/Marzano native boundary — detailed preserved design

AttuneDeal is useful prior art specifically for the native Marzano mechanics.

The relevant transferable pattern is:

```text
compile Grit source
    -> Marzano Problem
retain Problem process-locally
execute Problem over in-memory RichFile inputs
project MatchResult / AnalysisLog
return ordinary structured values
```

AttuneDeal's component implementation already demonstrates:

```text
src_to_problem_libs(...)
CompilationResult { problem, .. }
Problem.execute_files(...)
MatchResult::Match
MatchResult::Rewrite
MatchResult::CreateFile
MatchResult::RemoveFile
MatchResult::AnalysisLog
```

Radii should use the same upstream Marzano concepts directly through PyO3.

## 53.1 Explicitly do not port

Do not port AttuneDeal's:

```text
WIT interface layer
wit-bindgen resource model
Wasmtime Component Realm
Mojo runtime
canonical ABI machinery
runtime capability algebra
MCP machinery
component transport serialization
```

Those solved different problems.

## 53.2 Preferred Rust surface

The first Rust module should remain tiny and boring.

Conceptual API:

```python
grit = Grit()

result = grit.run(
    program_source,
    language,
    files,
    apply=False,
)
```

Internally:

```text
(program identity, language) already compiled?
    yes -> reuse process-local Problem
    no  -> compile and retain
```

Return Python-native values approximating:

```python
(
    matched,
    matches,
    logs,
    operations,
    diagnostics,
)
```

Do not expose a family of rich PyO3 domain classes unless the actual API becomes unmanageable without them.

## 53.3 Compile cache is not durable memoization

A process-local map from Grit-program identity to compiled `Problem` is analogous to a native client handle cache.

It is not the Attune memoization result.

Rote remains responsible for durable deterministic result reuse above the native call.

## 53.4 Error surface

Preserve enough diagnostic structure to distinguish:

```text
compile failure
execution diagnostic
unsupported language setup
host/native failure
```

Do not collapse every Marzano error into an untyped string if a small stable classification is easy to preserve.

## 53.5 Native concurrency

Do not assume one live `Problem` or execution context is safely shared across processes/threads until proven by the exact pinned upstream types.

The first correct model can be:

```text
process-local Grit owner
process-local compiled Problem cache
xdist process parallelism
```

Optimize sharing only after measurement.

---

# 54. Primitive semantic contracts in more detail

The permanent public vocabulary stays intentionally small.

## 54.1 `defines : FileId -> SymbolId`

Meaning:

> The file contains a source declaration/definition admitted as a symbol by Attune.

This is not arbitrary AST containment.

A `Symbol` should carry immutable metadata such as:

```python
Symbol(
    file=...,
    start_byte=...,
    end_byte=...,
    kind=...,
    name=...,
)
```

The source range is metadata, not a separate relation domain for the first Atlas implementation.

Grit extraction should match the complete declaration extent and log the smaller identity-bearing binding when necessary.

Python normalizes/resolves that observation into one admitted symbol identity.

## 54.2 `imports : FileId -> FileId`

Meaning:

> A source file has a statically admitted local dependency on another repository file/module.

Grit owns occurrence discovery of language import/module syntax.

Python owns repository-local path/module resolution.

External package dependencies do not become fake repository-file edges.

Ambiguous or unresolvable imports should remain unresolved observations or be dropped according to explicit rules, not guessed.

## 54.3 `calls : SymbolId -> SymbolId`

Meaning:

> A call lexically owned by the source symbol resolves with sufficient confidence to the target repository symbol.

Grit identifies call occurrences and relevant callee bindings.

Python owns deterministic symbol resolution.

Unresolved dynamic/member calls do not produce false target edges.

## 54.4 `parent`

Meaning:

> Direct repository path parenthood.

This is topology, not source-language semantics, so it does not require Grit.

Whether the permanent node type is `RepoId` or a unified `LocationId` remains open cleanup until after the Atlas Gate.

## 54.5 Private extraction facts are not automatically public primitives

Resolvers may need facts such as:

```text
definition-name range
module specifier
local imported binding
export binding
identifier occurrence
lexical owner
```

That does not mean policy authors should receive a public relation for each fact.

Public primitives are admitted because they improve the search language, not because extraction happened to produce them.

---

# 55. Primitive-admission law after the Atlas Gate

When evaluating a candidate primitive such as `references`, compare:

```text
Grammar A
    defines / imports / calls / parent

Grammar B
    Grammar A + candidate primitive
```

under the same:

```text
program-complexity budget
search depth/cost budget
physical compute budget
held-out evaluation protocol
```

A candidate earns admission only if it materially does one or more of:

```text
reaches previously unreachable useful evidence
improves held-out description length / exploration score
reduces shortest structural explanation cost
reduces policy complexity for equal quality
reduces physical work for equal quality
```

A primitive does **not** earn admission merely because it is a true semantic relation.

This is the intended meaning of:

> **A primitive should compress the policy/search language.**

---

# 56. The 15 unreachable residual gold nodes — preserved follow-up

At depth 7, 15 of 233 residual gold nodes remained unreachable by any primitive path in the temporary grammar.

Do not lose this diagnostic when deleting SpIDER scaffolding.

Before adding a new primitive after the Atlas Gate, classify analogous unreachable SWE-Explore core regions into categories such as:

```text
missing source-semantic relation
missing file/path relation
symbol mapping failure
cross-language/generated-code boundary
benchmark region not represented by current Symbol ontology
semantic-prior starting-point limitation
extraction/resolution bug
```

The unreachable set is a better primitive-discovery target than general intuition about what code graphs "should" contain.

---

# 57. Policy authorship model — preserved behind the Atlas Gate

There are three distinct authorship layers.

## 57.1 Human authors define permanent primitive semantics

Humans own:

```text
what `defines` means
what `imports` means
what `calls` means
what `parent` means
fixture laws
resolver admission rules
```

A model cannot redefine a primitive on one repository because a different interpretation scores better.

## 57.2 Supervisor agents may write raw Grit

The future supervision-building agent may write raw Grit because its task is different:

```text
historical issue
+
pre-patch repository
+
resolving patch / post-patch repository
        ↓
supervisor agent
        ↓
raw Grit transformation/check
        ↓
deterministic execution
        ↓
mechanical admission or rejection
```

This Grit is supervision machinery, not a production localization policy.

## 57.3 Policy-creation agents write ordinary Python only

The policy synthesizer never writes raw Grit.

It writes normal typed Python using the relation language.

Example:

```python
def policy(case: CaseInput) -> Proposal:
    centers = top(case.ranking, 8)
    visible = select(
        case.relations,
        same_file | callers | importer_neighbors,
        centers,
    )
    return project(case.ranking, visible, limit=20)
```

Promoted policy artifacts remain legible, diffable repository source.

---

# 58. No separate PolicyProgram IR

This is a settled subtraction.

Do not insert:

```text
Python policy source
    ↓
Attune JSON PolicyProgram
    ↓
custom compiler
    ↓
custom runtime
```

The Python relation language already is the policy language.

A private search AST may exist inside synthesis, but the promoted artifact is Python.

## 58.1 Candidate identity

A candidate can still have a stable identity:

```text
PolicyId = hash(
    normalized candidate source,
    primitive catalog version,
    semantic Python/package ABI inputs,
)
```

Do not use `repr()` as identity.

## 58.2 Candidate restrictions

Agent-authored source may use:

```text
attune_radii.algebra
approved pure policy helpers
immutable local values
comprehensions/generators
small deterministic local state
```

It may not use:

```text
filesystem I/O
network
subprocess
Nix
environment variables
ObservationStore/model provider
time/random/uuid
dynamic import
eval/exec
evaluator gold
```

Promotion runs the full static gate.

---

# 59. Policy synthesis surface — preserved design

Pydantic AI Code Mode remains the preferred future search host because it lets one model-produced program perform many local evaluation calls without requiring a model turn for every candidate.

Keep the model-visible tool surface extremely small.

Preferred conceptual tools:

```text
evaluate(source)
failures(source)
promote(source)
```

Do not introduce `PolicySearch`, `Population`, `EvolutionManager`, or a general agent-workflow framework unless actual implementation pressure demands them.

## 59.1 Candidate loop

```text
agent proposes Python
    ↓
AST/static admission
    ↓
deterministic evaluation on training cases
    ↓
compact metrics/failures
    ↓
agent revises
    ↓
promotion candidate
    ↓
full static + held-out gate
```

The agent proposes; deterministic machinery judges.

---

# 60. Automatic repository supervision from history — preserved design

The long-term onboarding loop remains:

```text
repository
    ↓
completed issues + resolving PRs/commits
    ↓
pre-change repository snapshots
    ↓
supervisor derives admitted examples
    ↓
frozen issue/code embedding priors
    ↓
policy synthesis
    ↓
promoted repository-specific Python policy
    ↓
future issues explore cheaply
```

This is deferred behind the Atlas Gate, not abandoned.

## 60.1 Supervisor input

At minimum:

```text
historical issue text
pre-patch repository snapshot
resolving patch / post-patch snapshot
fixed Grit/Marzano identity
```

## 60.2 Supervisor output

Retain enough to reproduce admission:

```text
issue
repository snapshot identity
gold changed files
gold preimage regions
gold postimage regions
admitted generated Grit source
Grit engine identity
admission strength
provenance
```

## 60.3 Strong admission target

Ideal transformation admission:

```text
apply supervisor Grit to pre-patch source
    -> produced normalized diff
    == normalized target patch
```

Weaker characterization tasks must explicitly state what they prove.

## 60.4 Why SWE-Explore gold does not replace this

SWE-Explore provides external benchmark labels and should remain evaluator authority for the benchmark.

Historical supervision exists to prove a different product/scientific claim:

> A previously unseen repository can manufacture local policy-training evidence from its own change history.

Do not regenerate SWE-Explore benchmark gold with the supervisor.

---

# 61. Leakage law and temporal split

Historical gold may train policy creation.

Evaluation/future gold may not enter policy input.

Mechanically:

```text
history cutoff T

pre-T issues/patches
    supervisor may see resolving patch
    policy synthesis may train on admitted supervision

post-T / evaluation issue
    policy sees only issue + repository facts + frozen prior
    evaluator owns gold
```

For SWE-Explore:

```text
official core/optional regions
    never enter CaseInput
```

Effects cannot protect secrets already included in an argument. The data/type boundary must exclude evaluator gold by construction.

---

# 62. Evidence model — preserve minimalism

The first evidence representation should remain approximately:

```python
type Region = tuple[FileId, int, int]
type Evidence = frozenset[Region]
```

Do not initially create:

```text
EvidenceStore
EvidenceGraph
EvidenceNode
EvidenceEdge
EvidenceState hierarchy
```

The permanent structural atlas does not require them.

A richer state becomes justified only when the interactive canonical-DAG experiment needs to distinguish ordered transcript state from canonical evidence-equivalence state.

---

# 63. Faithful prefix tree versus canonical evidence DAG — preserve as separate experiments

These are not the same reuse claim, and this distinction is now locked.

The **faithful prefix tree** is the default acceleration model for model interactions because it preserves exact model-visible chronology.

The **canonical evidence DAG** is a later algorithmic challenger because it changes what history/state the model is shown.

## 63.1 Faithful transcript tree

```text
prefix S
    ├── branch A
    ├── branch B
    └── branch C
```

Children may reuse physical KV for prefix `S`, but the model-visible ordered history remains exact.

This is an acceleration-only mechanism and should eventually be treated as a normal performance feature of the model boundary, not a change to scientific semantics.

Branches should preferentially append:

```text
new tool result
new evidence packet
new policy branch instruction
new model continuation
```

rather than regenerate earlier shared context.

## 63.2 Canonical evidence DAG

Different exploration orders may reach the same logical evidence set:

```text
semantic -> callers -> imports -----┐
                                    ├-> same canonical Evidence
semantic -> imports -> callers -----┘
```

Canonicalization changes model-visible chronology/rendering and must therefore be evaluated as a separate algorithm, not described as a transparent cache.

## 63.3 KV is acceleration, not truth

KV identity must include the relevant model/tokenizer/tool/prefix semantics.

If provider KV disappears, durable messages/evidence must reconstruct the run.

No scientific result may depend on cache residency.

## 63.4 Required comparison when this phase begins

At minimum compare:

```text
FULL / unstable rendering
    ordinary provider calls with no deliberate prefix discipline

FAITHFUL PREFIX
    exact append-only transcript branches with stable P0-P3 prefix layout

CANONICAL EVIDENCE
    deterministic evidence-state rendering that may merge chronology
```

Report separately:

```text
task quality
exact ObservationStore replay rate
live provider requests
cache-read/cache-write tokens
fresh input tokens
TTFT/latency
output tokens
provider cost
logical model decisions
```

The first two should be semantically equivalent modulo provider stochasticity/request identity. The canonical-evidence mode is allowed to change behavior and must be judged as a separate algorithm.

---

# 64. Repository-specific policy thesis

The MUI/Vue result motivates a stronger claim than "graphs help localization."

The candidate thesis is:

> **The useful composition of a small universal structural vocabulary depends on the repository's relational geometry.**

Examples to test after the Atlas Gate:

```text
high call mixing
    -> repeated calls/callers traversal becomes structurally expensive
    -> favor other local relations or shallow call use

low call mixing
    -> call compositions remain precise microscopes

high reverse-import mixing
    -> importing-consumer traversals flood quickly

strong path-tree locality
    -> parent radii can provide useful bounded context
```

The repository's intrinsic structural signature may therefore provide a **prior over useful policies**.

Do not claim this until the SWE atlas shows that signatures are stable enough to predict policy behavior.

---

# 65. Cost model for post-Atlas policy synthesis — locked direction

Plain maximum depth is no longer the preferred synthesis search regime.

The actual-vocabulary census demonstrated that the public named grammar grows rapidly even at modest expression complexity. Search must therefore be explicitly budgeted.

## 65.1 Public policy atoms

The initial synthesis vocabulary is:

```text
defines
defined_in
imports
imported_by
calls
callers
callees
same_file
import_neighbors
importer_neighbors
parent
repository_adjacent
```

Semantically identical aliases may remain public for readability but should share one synthesis semantic identity.

Current known alias:

```text
calls == callees
```

## 65.2 Complexity accounting

Use a simple legible model unless held-out evidence motivates another:

```text
named atom                     1
~A                             cost(A) + 1
A >> B                         cost(A) + cost(B) + 1
A | B                          cost(A) + cost(B) + 1
```

Then normalize obvious named inverses/aliases before charging or enumerating where possible.

For example, `~calls` should normally canonicalize to `callers` rather than creating a gratuitously more expensive equivalent candidate.

The experiment's internal `atom cost = 0` convention was only a layer-numbering device. It is not the intended human-facing synthesis penalty.

## 65.3 Objective

A future synthesis objective should balance:

```text
held-out exploration/localization quality
    - expression complexity
    - physical deterministic work
    - model/tool work where applicable
```

The exact scalarization is open.

The requirement that complexity and physical work remain visible is locked.

## 65.4 Semantic interning and normalization

During one search process:

```text
normalized syntax identity
exact semantic state/relation identity where cheap enough
shared prefix/subexpression state
```

may be interned/hash-consed to avoid deliberate duplicate compute.

Do not report process-local interning as Rote reuse.

Meaningful expensive evaluation stages may be `@rote.cache` boundaries so repeated experiments/processes replay them durably.

## 65.5 Do not attempt complete closure

Search terminates by:

```text
cost budget
candidate/sample budget
quality/stopping rule
physical-work budget
```

not by reaching the complete finite algebraic closure.

The complete closure question has already been answered negatively for architecture.

---

# 66. SWE-Explore experiment design — detailed contract

The benchmark is not just a final score target. It is the new scientific population for repository geometry.

## 66.1 Two distinct layers

### Layer A — intrinsic structural atlas

No issue text and no evaluator gold.

For each immutable repository snapshot / canonical repository revision:

```text
extract facts
build typed relations
choose deterministic issue-blind seeds
run fixed structural grammar
reduce to repository structural signature
```

Questions:

```text
How local is each primitive direction?
How quickly do paths mix?
How often do frontiers die?
How much semantic-state convergence exists?
How much real deterministic reuse is available?
How stable is the signature across issue snapshots of the same repository?
```

### Layer B — issue-conditioned exploration

Restore:

```text
issue
frozen semantic prior
repository facts
```

Then score against official exploration ground truth.

Questions:

```text
How much core evidence is reachable?
At what structural depth/cost?
How dense was the frontier at first useful hit?
Which policy best preserves useful locality?
Does repository signature predict policy choice?
```

## 66.2 Unit of analysis

Report at least:

```text
instance
repository
language
repository family / repeated snapshot where applicable
```

Never let repositories with many benchmark issues silently dominate every aggregate.

Provide both instance-weighted and repository-weighted views where conclusions depend on aggregation.

## 66.3 Snapshot stability

Many issues from one repository may reference nearby revisions.

This is scientifically useful.

Measure whether a repository's structural signature is stable across its benchmark snapshots.

If signatures move dramatically across revisions, the system should model **revision-specific geometry**, not pretend one static repository label is sufficient.

## 66.4 Typed density denominators

Use the correct universe for each transition:

```text
Symbol -> File
    input density over Symbol universe
    output density over File universe

File -> Symbol
    input density over File universe
    output density over Symbol universe
```

Never compare raw frontier cardinalities across domains without normalization.

## 66.5 Primary structural signature fields

At minimum per primitive direction:

```text
median output density
p90 output density
25% output fraction
50% output fraction
90% output fraction
25% crossing fraction
50% crossing fraction
90% crossing fraction
extinction fraction
logical transitions
physical computations
real reuse factor
```

Optional but useful:

```text
mean density
max density
T25 / T50 / T90
mean/p90 expansion
unique extensional states
```

---

# 67. Mapping SWE-Explore line-level evidence into the symbol world

The benchmark evaluator works at source-region/line granularity while the initial relational policy language works primarily over files and symbols.

Do not add `RegionId` merely to bridge this mismatch.

Instead:

```text
Grit-admitted Symbol
    carries immutable file + byte/line span metadata

SWE official region
    intersects / maps to admitted symbols when possible
```

Score both levels:

```text
native benchmark line/region score
symbol-mapped structural reachability score
```

If an official core region cannot map to any current symbol, record that explicitly as an ontology/coverage miss rather than dropping it from the denominator silently.

This unmapped population is important evidence for whether the Symbol ontology needs expansion.

---

# 68. SWE-Explore metrics — permanent report contract

Always retain benchmark-native metrics such as:

```text
useful-file coverage
useful-code / useful-line coverage
returned-code usefulness / precision
context efficiency
rank/budget curves where evaluator supports them
first useful hit / ranked useful evidence where supported
```

Add Attune-specific structural metrics:

```text
core-region symbol mapping rate
core symbol reachability by depth/cost
shortest structural explanation depth
frontier density at first core hit
repository structural signature
policy expression cost
logical relation work
physical deterministic work
Rote reuse
Grit extraction work
unique blob bytes inspected
embedding observation replay/acquisition
wall clock
provider dollars when any provider is used
```

Do not reduce the system to one quality number or one speed number.

---

# 69. First SWE-Explore supported-language strategy

Do not attempt ten-language perfection before one end-to-end atlas is green.

## 69.1 First slice

Start with the smallest language slice that directly validates the current findings and the Grit/Rust boundary.

TypeScript/JavaScript are natural first targets because the existing old-world evidence is TypeScript and AttuneDeal already demonstrated Marzano TypeScript host setup.

## 69.2 Expansion order

Expand one language only after:

```text
fixture-backed defines/imports/calls semantics
repository snapshot acquisition
symbol-span projection
Atlas signature generation
Rote cold/warm laws
```

are green for that language.

## 69.3 C/C++

Explicitly deferred for the first broad Atlas slice.

Do not add another source-intelligence stack solely to avoid filtering them.

Compute the supported benchmark population from actual dataset metadata at runtime and report the filter transparently.

---

# 70. Current checkout seams that should disappear, compress, or become explicit

This section reflects the September 20 packed checkout rather than the earlier speculative module plan.

## 70.1 `algebra/query.py`

Current primitive execution still resolves a declaration name through a small string/`attrgetter` table and casts from `object`.

Target when touched:

```python
type Getter[S: int, T: int] = Callable[[Relations], Relation[S, T]]
```

and a direct typed getter stored by the primitive declaration.

Keep names as display metadata.

Do not build a general registry framework.

## 70.2 `algebra/relation.py`

The PyRoaring representation is the correct physical direction and should remain small.

Preserve:

```text
immutable forward rows
immutable reverse rows
native frontier multiway union
cheap reversal by index exchange
exact relation set operations
exact composition
```

Add/retain a canonical logical encoding helper only where persistent semantic identity actually requires it.

Do not use `FrozenBitMap.serialize()` as scientific equality/hash identity.

Do not inflate `Relation` into a graph framework.

## 70.3 `algebra/structure.py`

The locked names are already present.

Keep the vocabulary compact.

`RepositoryQuery` should survive only if it remains the smallest legible way to expose bounded path-tree locality. If simpler ordinary functions express the same semantics, prefer the smaller form.

## 70.4 `world.py`

The checkout already contains the repository-native source -> Grit fact -> resolved payload -> Relation path and meaningful Rote boundaries.

Refactor goals:

```text
make content/primitive identities narrow and truthful
avoid repository-wide invalidation where cheap per-blob reuse is obvious
cache stable serializable data, not live native objects
delete duplicated older classmethods/helpers after the cached path supersedes them
separate stable source/fact records from cheap live index reconstruction
```

There are visible duplicate old/new construction paths in the file. Delete superseded paths rather than preserving both for comfort.

## 70.5 `routing.py`

The issue-blind Atlas observer is useful, but its local `TransitionMemo` dictionary is algorithmic process-local deduplication only.

It must not be presented as the production durable memoization result.

Refactor it toward the permanent tiny observer:

```text
typed state
apply compatible primitive
record before/after typed density
process-local semantic interning where useful
reduce to RelationSignature / StructuralSignature
```

Rote ownership belongs at meaningful durable boundaries around immutable Atlas work, not in a second `FrontierCache` abstraction.

## 70.6 `grit.py` and native Rust adapter

These are already close to the intended narrow leaf.

Keep them boring.

The Rust code is currently well below the historical 180–300 LOC pressure target.

Do not move repository resolution or memoization policy into Rust.

## 70.7 `model.py` / `observation.py`

Preserve the separation:

```text
provider/model effect
    -> ObservationStore exact request identity
    -> deterministic local admission / reuse
```

Do not put stochastic provider acquisition under Rote.

Do not delete retained exact observations as routine cache cleanup.

## 70.8 `nix.py`, generated/native Nix binding seam, and `flake.nix`

Preserve the existing typed native Nix capability unless a concrete failure requires redesign.

Delete historical dataset outputs and benchmark plumbing only after the SWE-Explore replacement is green.

The old Nix `refactorCheck` executable should cease being a second developer command. **Move its laws into pytest**, then remove only the standalone app/wiring that creates a second entrypoint.

The refactor checker itself is important and must survive.

## 70.9 `tests/conftest.py`

This is the canonical quality host.

It should remain strict and may become slightly more capable, but avoid turning it into a bespoke build system.

Session-level laws should orchestrate stable pinned tools, while scientific tests remain ordinary pytest functions.

## 70.10 `tests/test_architecture.py`

Treat this as a core architectural contract, not optional lint decoration.

The existing Fixit rule correctly protects:

```text
no functools cache/lru_cache as hidden Attune memoization
service acquisition only under @effects.fn
library code does not close Effects
Rote-cached functions do not mutate global/nonlocal state
```

Preserve and extend only for concrete architectural mistakes.

Do not disable it to make generated/refactored code easier to accept.

## 70.11 Refactor subset / compression law

The existing checker currently constrains:

```text
accepted source module set
forbidden generic directories
total source+test Python LOC non-growth
source+test Python file-count non-growth
```

Move that logic into pytest and pin this refactor comparison to `87d1137a`.

Eventually, once the migration is complete, replace the historical comparison with a stable permanent production LOC/subset budget.

---

# 70A. Demonstration surface — Python, pytest, Xonsh, and Starship

The repository should be pleasant to demonstrate as a live technical object.

This is particularly important for Attune because many of its strongest ideas are easier to understand when a person can directly inspect a relation, execute a query, rerun a cached computation, and compare repository signatures interactively.

The implementation should therefore deliberately support the following progression:

```text
public Python API
        │
        ├── pytest laws
        │      same calls + assertions
        │
        ├── Xonsh / xontrib
        │      same calls + shell ergonomics
        │
        ├── CLI
        │      same calls + argument parsing
        │
        └── Starship custom module
               cheap display of already-known state only
```

Not:

```text
pytest implementation
Xonsh implementation
CLI implementation
prompt implementation
```

Each extra surface must be an adapter over the library.

## 70A.1 A good public Atlas API

Aim for operations that correspond to the nouns in the science:

```python
repo = repository(snapshot)
relations = repo.relations
seeds = issue_blind(repo.symbols, count=8)
signature = structural_signature(relations, seeds, depth=7)
```

Then ordinary relation exploration should remain equally direct:

```python
neighbors = select(relations, callers, seeds)
local = select(relations, same_file, seeds)
```

And policy execution later should look similarly ordinary:

```python
result = localize(case, policy)
```

Avoid APIs that require users to know internal cache keys, effect layers, Nix handles, Marzano handles, or benchmark adapters for normal exploration.

## 70A.2 Effects stay visible at real boundaries, not everywhere

The API should remain honest about capabilities without making pure relational exploration cumbersome.

For example:

```text
acquire repository snapshot     effectful
extract missing Grit facts      effectful boundary / cached deterministic transform
acquire embeddings              effectful
model observation               effectful

select relation frontier        pure
compose query                    pure
compute signature reductions    pure
evaluate frozen policy          pure once inputs are present
```

A user in Xonsh should be able to explore already-materialized relations without constructing an effect program by hand.

## 70A.3 Reprs and rich display

Prefer excellent `repr()` first.

Only after a few public values stabilize, consider optional richer display protocols.

Potential values:

```text
Query("~calls >> defined_in >> defines")
RelationSignature(mean=.413, p90=.570, cross50=.074, reuse=1.11)
StructuralSignature(repo="vuejs/core", depth=7, ...)
```

Keep tables/rendering outside identity and computation semantics.

## 70A.4 Xonsh plugin scope

A future `xontrib-attune` should be tiny enough to understand in one sitting.

Candidate conveniences:

```text
`attune` alias / command wrapper
completion for known relations and local snapshot ids
pretty printer registration
helpers for opening the current repo
helpers for showing the last Atlas/signature result
optional environment-mode commands: replay / acquire
```

No scientific logic belongs in the plugin.

## 70A.5 Starship module contract

The Starship module is allowed to consume only cheap status that Attune explicitly publishes.

A possible status file might contain something like:

```json
{
  "project": "radii",
  "mode": "replay",
  "snapshot": "abc1234",
  "experiment": "atlas",
  "cache": "warm"
}
```

The exact format is not locked.

The important law is that prompt latency remains bounded and rendering cannot accidentally launch computation.

## 70A.6 Public API demonstrations belong in documentation/tests

Keep at least one tiny executable demonstration that can be copied almost verbatim between README/docs, Xonsh, and pytest.

That example should exercise real library behavior rather than a toy facade.

This becomes a useful architectural pressure test: if a basic Atlas demonstration requires internal imports or fixture machinery, the public API is not yet good enough.

---

# 71. Permanent structural-signature implementation should stay tiny

Most of the current mixing experiment is scaffolding.

The permanent observer should be approximately:

```text
typed atom metadata             ~10–15 LOC
memoized/ordinary exploration   ~25–35 LOC
pure density reductions         ~20–30 LOC
one report/test                 ~20–30 LOC
```

Rough total:

```text
~75–110 Python LOC
```

This is a pressure target, not a line-golfing requirement.

The permanent mechanism is essentially:

```text
for each typed semantic state
    apply each applicable primitive
    record before/after typed density
    reduce by repository and primitive
```

Do not preserve giant JSON-printing helpers or custom profiler classes merely because the discovery experiment used them.

---

# 72. Python production-size pressure and refactor budget

The project is deliberately applying unusual pressure toward a small implementation because legibility is part of the scientific/product thesis.

September 20 `scc` checkpoint:

```text
Python files     28
Python lines   6211 total
Python code    5250
```

This is intentionally above the desired final state after the science sprint.

The production target remains:

```text
< ~2000 executable-ish production Python LOC
```

This target applies to the reusable implementation, not to every scientific law in tests.

## 72.1 How to get smaller

Expected compression should come primarily from deletion:

```text
remove duplicate old/new world-building paths
remove obsolete benchmark adapters
remove temporary experiment scaffolding from tracked code
remove second verification entrypoints
avoid separate cache framework
avoid policy IR/framework
avoid generic graph/evidence/workflow managers
avoid wrappers whose only job is renaming one library call
```

## 72.2 What not to do

Do not satisfy LOC pressure by:

```text
minifying code
packing logic into unreadable comprehensions
moving first-party code into generated strings
hiding source in unchecked directories
deleting tests that encode real laws
weakening types/docstrings/lints
moving ordinary Python semantics into Rust merely to change the counter
```

## 72.3 Relative refactor gate

Until the final permanent budget is re-established, pytest must preserve the migration pressure:

```text
src + tests Python LOC <= baseline at 87d1137a
src + tests Python file count <= baseline at 87d1137a
new src files belong to the accepted narrow module set
```

The accepted set may be updated only deliberately in the spec/test together, not ad hoc to silence a failure.

## 72.4 Warm runtime is also a size signal

A smaller codebase that repeatedly recomputes expensive deterministic work is not a successful Attune refactor.

Evaluate both:

```text
source size / conceptual surface
and
warm physical work
```

The goal is a small explanation of a system that becomes cheaper as evidence accumulates.

---

# 73. Rust budget

The Grit host should remain a leaf.

Expected handwritten Rust budget:

```text
~180–250 LOC
```

A small increase is acceptable if it buys truthful diagnostics/lifetime safety.

A large native subsystem is a design smell.

Native responsibilities are only:

```text
language target setup
compile source -> Problem
execute Problem over in-memory files
project matches/logs/operations/diagnostics
process-local compiled-Problem reuse
PyO3 error/value conversion
```

Do not move policy logic, repository identities, relation algebra, memoization policy, or benchmark logic into Rust.

---

# 74. Grit source budget and philosophy

A few hundred lines of human-authored Grit across languages is acceptable because the patterns are **semantic specification**, not framework machinery.

Prefer:

```text
grit/
  typescript/
    defines.grit
    imports.grit
    calls.grit
  javascript/
    ...
  python/
    ...
  go/
    ...
```

Each primitive file should be understandable as the explanation of one semantic relation.

Do not invent shared abstraction layers inside Grit until concrete duplication hurts readability.

---

# 75. testmon migration contract

pytest remains the executable authority.

The intended clean end state may remove pytest-testmon, but only after the real reuse stack proves it unnecessary.

Removal criteria:

```text
1. warm full-suite wall time is acceptable without testmon
2. all assertions can run without repeating provider/model requests
3. unchanged Nix artifacts do not rebuild
4. Rote reuses expensive deterministic transformations
5. helper/transitive source edits invalidate relevant Rote results
6. explicit immutable input identity changes invalidate relevant results
7. changing only test assertions does not reacquire scientific inputs
8. changed local model admission reuses retained observation
9. changed provider-visible request misses explicitly
10. xdist remains safe/deterministic
11. no stale cache can make a perturbation/parity law pass incorrectly
12. reporting remains at least as useful
```

Only then remove:

```text
pytest-testmon dependency
--testmon options
.testmondata handling
compatibility code written only for testmon
```

The cleaner guarantee is:

> **We ran the law, but unchanged expensive evidence/computation was reused.**

rather than:

> We skipped the law because another dependency engine believed it was unchanged.

---

# 76. Telemetry ontology

Every important operation should make the difference between logical intent and physical origin observable.

Useful event families:

```text
grit.compile
grit.execute
facts.normalize
facts.resolve
relations.build
atlas.transition
atlas.signature
prior.rank
policy.evaluate
policy.promote
observation.replay
observation.acquire
prefix.hit
prefix.miss
```

For deterministic work, record a physical origin such as:

```text
computed
Rote reuse
fact reuse
process-local compiled reuse
```

For model work:

```text
observation replay
provider live
provider KV/prefix reuse
provider fresh prefill
```

Model events should retain fields when available:

```text
request_id
prefix_id
model/provider identity
observation_origin
input_tokens
cache_read_tokens
cache_write_tokens
fresh_input_tokens
output_tokens
TTFT
latency
cost
```

For tree/search work, useful event families should eventually include:

```text
search.subtree.compute
search.subtree.reuse
search.state.intern
search.state.reuse
```

The core reuse statement should be expressible as counts:

```text
logical operations       300,000
physical computations     18,000
```

not merely:

```text
cache hit rate 94%
```

---

# 77. Quality/static-law posture — pytest is the single authority

The codebase should remain unusually strict because the goal is a small, public, legible research system.

Keep all of the following on:

```text
Ruff format check
Ruff ALL-mode lint configuration
Flake8 / Wemake constraints
Fixit rule self-tests
Fixit Attune architecture lint
BasedPyright all-mode
reportAny = error
failOnWarnings = true
interrogate 100%
pytest
pytest-xdist
pytest-testmon until its removal criteria are truly satisfied
xdoctest
Grit semantic documentation/example law
refactor subset/layout/LOC law
```

## 77.1 Only one developer/agent verification command

Canonical invocation:

```text
pytest
```

The pytest session may call pinned tools internally.

Do not require developers or agents to remember a separate:

```text
refactor-check
ruff ...
flake8 ...
basedpyright
fixit lint ...
interrogate ...
```

sequence to know whether the repository is green.

The one-entrypoint rule is about authority and reproducibility, not about banning subprocess use inside the test host.

## 77.2 The refactor checker survives inside pytest

Preserve its semantics:

```text
historical baseline comparison
accepted source subset
forbidden generic directories
src+tests LOC non-growth
src+tests file-count non-growth
clear report on added/removed/legacy paths
```

Do not simply delete the checker because its standalone Nix app is removed.

## 77.3 Architecture/subset checks are hard blockers

The architecture law and refactor subset law are especially important during agent-driven implementation.

An agent may not "temporarily" bypass them to land a large refactor.

If the intended architecture truly requires changing a law, change the law and this spec explicitly, with a concrete reason.

## 77.4 Use effect-python and Rote deliberately and often at the right layer

The implementation agent will create or move many effectful/reusable boundaries.

Default architectural questions should be:

```text
Is this a real capability/effect?
    -> effect-python

Is this expensive deterministic work over explicit semantic inputs?
    -> consider @rote.cache

Is this exact remote/provider work already owned?
    -> ObservationStore

Is this immutable external artifact identity?
    -> Nix

Is this cheap within-process deduplication?
    -> ordinary interning/data structure, not another durable cache
```

Do not cargo-cult decorate trivial helpers with Rote merely to satisfy a slogan.

Do not hide real effects in ordinary functions merely to reduce ceremony.

## 77.5 Slow pytest law

Repeated warm pytest should be cheap enough that developers do not feel pressure to skip laws.

If it becomes slow:

1. measure where physical work occurs;
2. inspect Rote hit/miss/invalidation identity;
3. inspect Nix closure invalidation;
4. inspect Grit native recompilation/execution;
5. inspect model/ObservationStore replay;
6. inspect repeated relation materialization;
7. fix the ownership boundary.

Do not turn off the test.

## 77.6 Fixit remains an architecture layer, not an execution framework

Project-specific Fixit/LibCST laws may enforce concrete boundaries such as:

```text
policy module cannot import evaluator gold
effect service acquisition remains under @effects.fn
library code cannot close Effects
Rote boundary cannot hide mutable outer state
ad-hoc durable cache decorators are rejected
model acquisition routes through ObservationStore
import-time hidden acquisition is rejected
```

Keep rules understandable and autofixes conservative.

---

# 78. Rejected and superseded directions — explicit archive

The following ideas appeared during design but are not the active architecture.

## 78.1 Mojo for Radii native runtime

**SUPERSEDED.**

Radii uses Rust + PyO3/maturin.

Do not resurrect Mojo because older Attune/AttuneDeal code contains substantial Mojo runtime work.

## 78.2 WIT/Component Model Grit host

**REJECTED FOR RADII.**

AttuneDeal used WIT/Component machinery for a broader sandbox/runtime problem. Radii does not need it for a local structural fact extractor.

## 78.3 C ABI / generated bindings for Grit

**REJECTED.**

Use PyO3 directly.

## 78.4 SCIP

**REJECTED FOR FIRST IMPLEMENTATION.**

Do not add another code-intelligence graph dependency before testing the Grit fact basis.

## 78.5 Grit as the policy language

**REJECTED.**

Grit defines fixed source semantics and may be used by the future supervision agent. Learned production policy is ordinary Python relation composition.

## 78.6 Graph-as-product architecture

**REJECTED.**

The interesting object is not a graph container. It is the semantics and geometry of a small relation basis.

## 78.7 Polars as an architectural commitment

**SUPERSEDED / OPTIONAL.**

Use it only if a concrete data task benefits; it is not part of the design identity.

## 78.8 DuckDB as a required runtime dependency

**SUPERSEDED FOR RADII CORE.**

Do not carry experimental warehouse choices into the small runtime absent need.

## 78.9 Custom Python dependency tracker

**REJECTED WHILE ROTE SATISFIES REQUIREMENTS.**

Do not reimplement `sys.monitoring` + audit hooks + LibCST dependency hashing.

## 78.10 Final SpIDER parity campaign

**SUPERSEDED.**

The old repo history is sufficient as an oracle if reconstruction is ever necessary. The active target is Grit fact semantics + SWE-Explore.

## 78.11 Add many semantic primitives before search

**REJECTED.**

Finite synthesis showed strong coverage from the small basis. Add a primitive only through the admission law.

---

# 79. Open questions that remain legitimately open

Do not confuse these with settled decisions.

```text
1. [ANSWERED] Does the issue-blind seed ablation preserve the MUI/Vue/Darkreader regimes? Yes: the local-vs-mixing regimes survive issue removal.

2. How stable are structural signatures across multiple snapshots of the same SWE repository?

3. Which SWE languages can Marzano/Grit support cleanly with tiny primitive programs?

4. What fraction of official SWE core regions map cleanly onto the initial Symbol ontology?

5. Do four primitives maintain high structural reachability across languages?

6. Does `parent` materially improve the SWE exploration frontier after the first source-only atlas?

7. Does `references` compress policy search enough to earn admission?

8. Does intrinsic repository signature predict the policy expression that works best?

9. Where should Rote cache boundaries sit for the best cold/warm tradeoff with native-backed relation data?

10. Is `LocationId` unification worth doing after the Atlas Gate?

11. Does the permanent compact Relation implementation make Vue-like set work cheap enough, or is additional algebra optimization needed?

12. When does testmon become unnecessary?
```

These should be resolved by experiments or concrete implementation pressure, not aesthetics alone.

---

# 80. Detailed Atlas-first migration gates

The phase ordering in §27 remains authoritative. This section adds stronger entry/exit criteria.

## Gate A — old-world science closed

Completed at the September 20 checkpoint.

```text
[x] semantic-seed relation-specific mixing result retained
[x] issue-blind seed ablation completed; repository regimes survived issue removal
[x] paired interpretation recorded
[x] support/core stability hypothesis tested and rejected as a global replacement
[x] full composition relation quotient measured: 3279 -> 2876
[x] row-transition recurrence measured: ~99.114x
[x] canonical-bitmap identity bug isolated
[x] mixed algebra closure tested and rejected as a production strategy
[x] bounded-cost operator census retained
[x] actual named policy-vocabulary census retained
[x] composition-only vs public (~ >> |) comparison retained
[x] Rote chained fresh-process replay canary passed
[x] no further old-world depth/operator census planned
[x] final pre-refactor baseline revision identified: 87d1137a
```

After this gate, old `.attune` experiments are historical evidence, not the primary development surface.

Do not add new tracked old-world census machinery.

## Gate B — one native Grit fact

Required:

```text
[ ] Nix builds Rust/PyO3 extension from pinned upstream Grit/Marzano
[ ] Python can compile one fixed TypeScript Grit primitive
[ ] Python can execute it on one in-memory file
[ ] match/log ranges survive boundary exactly
[ ] compile failure is structured
[ ] compiled Problem reuse is process-local and deterministic
[ ] no Mojo/WIT/Wasmtime layer
```

## Gate C — three TypeScript source relations

Required:

```text
[ ] defines fixture semantics
[ ] imports fixture semantics
[ ] calls fixture semantics
[ ] reverse queries work via Python algebra
[ ] mathematical distinctness witness rewritten on Grit-derived facts
[ ] ambiguous call/import cases do not create false edges
```

## Gate D — one SWE snapshot end to end

Required:

```text
[ ] Nix identifies benchmark record and immutable repository snapshot
[ ] repository files load without SpIDER
[ ] Grit facts extract
[ ] facts normalize/resolve
[ ] compact Relations build
[ ] deterministic seed chosen
[ ] depth-bounded atlas runs
[ ] structural signature emitted
```

No policy synthesis is needed yet.

## Gate E — real Rote reuse

Required:

```text
[ ] cold run computes fact/normalization/relation work
[ ] second process reuses deterministic outputs through Rote
[ ] changed Grit source invalidates affected result
[ ] changed repository blob invalidates affected facts
[ ] unrelated blob reuse remains available
[ ] xdist safety tested
[ ] telemetry reports logical vs physical work
```

This is the point where the project can legitimately claim production memoization rather than experiment-local deduplication.

## Gate F — TypeScript/JavaScript structural atlas

Required:

```text
[ ] multiple repositories with different architecture represented
[ ] intrinsic signatures reported repository-weighted and instance-weighted
[ ] snapshot stability measured
[ ] MUI/Vue-like local-vs-mixing regimes either reproduced, refined, or falsified
[ ] cold/warm physical costs reported
```

## Gate G — supported-language broad atlas

Required:

```text
[ ] every included language has fixture-backed primitive semantics
[ ] filter/exclusion population is explicit
[ ] structural signature distribution across repositories/languages reported
[ ] relation failures/unmapped symbol populations reported, not hidden
```

## Gate H — issue-conditioned SWE evaluation

Required:

```text
[ ] frozen semantic prior enters only here
[ ] official evaluator gold remains hidden from CaseInput
[ ] core evidence mapping rate reported
[ ] reachability / shortest explanation / density at first useful hit reported
[ ] benchmark-native exploration metrics reported
[ ] real reuse telemetry accompanies quality metrics
```

Only after Gate H should policy synthesis/historical supervision become the primary development thread.

---

# 81. Post-Atlas work preserved in priority order

The Atlas Gate changes sequencing, not the long-term thesis.

After a successful atlas:

```text
1. inspect unreachable / unmapped SWE core evidence
2. test parent/repository topology
3. test primitive challengers under equal budget
4. synthesize repository-specific Python policies
5. test whether intrinsic signature predicts useful policy family
6. build repository-history supervision vertical slice
7. automate onboarding/history -> examples -> prior -> policy
8. harden structural/search subtree memoization under real policy synthesis
9. implement faithful model-prefix/KV reuse discipline and measure it
10. separately test canonical evidence-DAG mode
11. measure full coding-agent session impact with the complete reuse stack
```

The long-term target remains approximately **10× faster full coding-agent sessions**, not merely a faster standalone localizer.

The ordering after Atlas may change with evidence, but items 8-11 are not optional ideas. They are part of the project-level reuse thesis.

---

# 82. Full-session thesis — preserved context

Localization is the first bounded target because it is recurrent and expensive in coding-agent sessions.

The project should ultimately ask:

```text
How much session time/tokens are spent finding relevant evidence?
How much can repository-native policy remove?
Which observations/tools can be reused across session branches?
Which deterministic search subtrees/states can be reused instead of recomputed?
Which structural evidence remains useful after the first edit/test cycle?
How much provider prefill can faithful stable-prefix/KV reuse eliminate on unavoidable live calls?
Can dependency-aware reuse accelerate the entire repair loop?
```

A 20–40% standalone localization win is scientifically useful but insufficient as the final Attune claim.

The intended long-term bar remains:

> **Remove enough dominant latency across exploration/evidence/tool reuse that full coding-agent sessions become order-of-magnitude faster on meaningful workloads.**

Do not let the Atlas turn into an isolated graph-benchmark project disconnected from this end goal.

---

# 83. Implementation checklist for every permanent component

Before declaring a component complete:

```text
[ ] semantic purpose is one sentence
[ ] public type surface is narrow
[ ] BasedPyright all-mode green
[ ] Ruff/Wemake/Fixit relevant laws green
[ ] deterministic input identity explicit
[ ] effectful dependencies visible through effect-python where appropriate
[ ] no evaluator gold reachable from production input
[ ] no ambient shell/env correctness dependency
[ ] Rote boundary is meaningful rather than decorative
[ ] structural/search subtree reuse considered where repeated deterministic state exists
[ ] exact remote replay identity separated from provider KV/prefix reuse
[ ] model prefix stability measured when live model work is involved
[ ] cold/warm behavior measured if expensive
[ ] xdist behavior tested if shared persistence is involved
[ ] repr/logging does not define scientific identity
[ ] no duplicate cache/identity layer introduced
[ ] obsolete transitional implementation deleted after replacement is green
```

For native Grit specifically:

```text
[ ] fixed upstream revision/pin
[ ] fixture semantics exact
[ ] diagnostics preserved
[ ] ranges preserve byte/line meaning
[ ] unresolved semantics fail closed rather than inventing edges
[ ] process-local lifetime safe
```

For Atlas reports:

```text
[ ] repository identity explicit
[ ] snapshot identity explicit
[ ] language explicit
[ ] seed policy explicit
[ ] primitive catalog identity explicit
[ ] thresholds explicit
[ ] logical/physical counts explicit
[ ] cold/warm origin explicit
```

---

# 83A. Agent execution contract for the September 20 refactor

This section exists specifically for an autonomous coding agent operating against `spec.md`.

## 83A.1 Work to completion, do not merely propose

The agent should inspect the repository, edit it, run pytest repeatedly, and leave the checkout in the strongest complete state it can achieve in the current session.

Do not stop at a design memo if implementation is possible.

## 83A.2 Respect existing user work and jj state

Start with:

```text
jj status
jj diff
```

Do not discard uncommitted user changes.

Do not rewrite history unnecessarily.

Use the frozen baseline revision `87d1137a` only for the refactor-compression comparison, not as permission to reset current work.

## 83A.3 Verification loop

The canonical loop is:

```text
edit
pytest
inspect failure
edit
pytest
...
full pytest green
```

Targeted pytest selection is allowed, but session quality gates remain enabled.

Do not directly bypass quality failures by invoking only a narrower external lint command.

## 83A.4 Storage authority

The agent may inspect and manage disk/Nix storage as needed.

It may delete artifacts outside the project **only when they are confidently regeneratable**.

Before deleting anything substantial:

```text
identify what owns it
verify it is not source/uncommitted work/unique observation
prefer removing duplicate build/cache artifacts
record major cleanup in the final summary
```

Nix garbage collection is allowed when useful.

But a large new storage footprint should trigger architectural diagnosis before cleanup.

## 83A.5 No new science detour

Do not spend the refactor session running new MUI grammar closures or cost-6 experiments.

Use the retained science to make code smaller and prepare SWE-Explore.

## 83A.6 Final report

At the end, report at least:

```text
what was deleted / consolidated
what effect-python boundaries changed
what Rote boundaries changed
whether standalone refactor-check invocation was absorbed into pytest
full pytest result
warm pytest behavior if notable
production/source/test LOC and file-count delta
major Nix/store/storage changes
remaining Atlas Gate blockers
jj status / high-level diff summary
```

A green but larger, slower, less reusable system is not the intended success state.

---

# 84. Canonical interpretation of the refactor

After the September 20 science closeout, the refactor is not primarily:

```text
clean up modules
rename classes
replace one graph library
port old SpIDER behavior
```

It is:

```text
replace borrowed benchmark graph truth
with small repository-native semantic facts

replace experiment-local memo dictionaries
with dependency-aware deterministic reuse

make repeated structural/search trees pay for new semantic work
rather than duplicated syntax/state

make exact model requests replay with zero provider work
and make unavoidable new model calls preserve reusable KV prefixes

replace one three-repository observation
with a broad SWE-Explore structural atlas

then use that measured geometry
as the basis for repository-specific policy synthesis
and eventually faster complete coding-agent sessions
```

The implementation should remain small enough that the scientific mechanism is visible in the source.

The native Grit files explain **what structural facts mean**.

The typed Python algebra explains **how facts compose**.

The structural atlas explains **how a repository propagates evidence**.

Rote explains **which deterministic work needs to happen again**.

Search-state/subtree memoization explains **which repeated structural programs should not pay twice for the same semantics**.

ObservationStore explains **which exact provider observations Attune already owns**.

Stable-prefix/KV discipline explains **how unavoidable new model calls can reuse physical inference work without changing logical history**.

The policy explains **which paths are useful for this repository**.

SWE-Explore provides the first broad external test that those pieces correspond to useful engineering evidence.

That is the canonical architecture after the September 17–19 design work.


---

# 85. September 20 canonical closeout

The pre-refactor science phase is closed with the following durable interpretation:

> **Repository geometry is real and issue-independent enough to justify a broad Atlas; the current structural basis is already expressive enough that selection matters more than primitive proliferation; complete relation semantics remain mostly distinct while local row/state computation recurs enormously; union is a justified public policy operator but complete mixed closure is not a useful production target; named public concepts should define synthesis complexity; and Rote can make expensive deterministic policy/algebra evaluation almost free on fresh-process replay when the boundary is pure and explicit.**

The implementation consequence is equally direct:

> **Make the repository much smaller, keep every quality law on, make pytest the one execution authority, use effect-python for real capabilities and Rote for meaningful deterministic reuse, preserve compact PyRoaring algebra, replace old benchmark plumbing with SWE-Explore, and spend future scientific effort on repository-specific policy selection rather than ever-larger closure enumeration.**
