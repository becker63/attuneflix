# Repository signatures before the full census

Atlas can characterize a repository without issue text, embeddings, a learned
decision model, or evaluator gold. It starts from admitted definitions,
imports, and calls, runs the same finite typed program family, and records how
the resulting structural states behave.

This note collects the repository-level evidence that already exists. It is
not the forthcoming full SWE-Explore census. The census protocol will be
preregistered and its typed Parquet result will supersede this small set of
measurements.

## What is being measured

The current evidence covers several parts of a signature:

- reach and density in each structural direction;
- extinction: how often a structural frontier becomes empty;
- recurrence: different logical programs reaching the same state;
- physical compression: logical work eliminated by shared evaluation;
- selectivity: whether broad structural reach still ranks a useful target
  near the front.

These quantities depend on the frozen repository facts and Atlas protocol.
They do not depend on the localization prior or Jev.

## Original MUI, Vue, and Darkreader result

The earliest issue-blind census is now retained in this repository as part of
the [AttuneRadii migration record](../../migration/attuneradii/README.md). It
ran the same fixed, composition-only depth-seven language after removing the
issue-conditioned semantic seed. The repository regimes remained distinct.

| Repository family | Mean Symbol-frontier density | Mechanical character |
| --- | ---: | --- |
| MUI | 0.0410 | wide modular component families; local islands; early extinction and high convergence |
| Vue core | 0.4941 | compact runtime/compiler graph; long-lived frontiers; rapid structural mixing |
| Darkreader | 0.5730 | dense call structure; broad propagation; low whole-frontier convergence |

The relation-specific census makes the contrast harder to explain away as
repository size. In MUI no primitive direction produced a state covering half
of its compatible domain; its p90 densities ranged from roughly 2.9% to
14.6%. In Vue, callers crossed 50% in 56.8% of observations, while containment
and reverse imports were also broad. Darkreader was similarly dense across
containment and call directions. These are normalized response measurements,
not raw file or symbol counts.

The source trees make the measurements understandable:

- MUI repeats a highly regular package/component pattern. Many components are
  locally rich but weakly joined to other components, so paths collapse or
  extinguish quickly. One extreme case reduced 3,279 logical prefixes to 15
  physical transitions and four unique frontiers.
- Vue has a regular package layout too, but its runtime-core, compiler,
  reactivity, and renderer packages form an interconnected library system.
  Structural paths keep finding new symbols instead of falling into isolated
  component islands.
- Darkreader's two retained cases have enough calls per symbol and enough
  cross-cutting propagation to behave much closer to Vue. Because that sample
  is only two cases, this is a strong snapshot observation, not yet a stable
  population estimate.

The exact protocol choice, depth counts, relation tables, and limitations are
in the retained [grammar decision](../../migration/attuneradii/spec.md#15-search-grammars--atlas-measurement-versus-policy-synthesis),
[finite depth study](../../migration/attuneradii/spec.md#42-finite-relational-language-search--exact-evidence-through-depth-7),
and [repository-character sections](../../migration/attuneradii/spec.md#45-structural-mixinglocalness--permanent-conceptual-model).

The numbers are useful because they lead back to recognizable source
architecture. After the measurements were frozen, the measured hubs and
residuals were opened and read. That source inspection found several different
mechanisms behind the signatures:

- **Axios** has a connected implementation core surrounded by generated
  bundles, public type contracts, and integration tests that deliberately do
  not import the internal file they exercise.
- **Immutable** groups maintenance by semantic operation families. Parallel
  `Map`, `Set`, `slice`, and `splice` tests are siblings in meaning even when
  no source edge joins them.
- **Preact** has a compact runtime core plus an outer layer joined through
  package aliases, declaration/runtime mirroring, and build configuration.
- **Vue** has a notably regular package layout. Runtime-core, reactivity,
  compiler, and renderer modules form visible structural hubs; the main
  residuals cross workspace package names and compiler/runtime name contracts.
- **NodeBB** exposes broad facade and plugin-hook surfaces. Its plugin index is
  a major import hub, its database implementation is selected through
  configuration, browser/server calls meet through string-addressed Socket.IO
  methods, and Redis behavior is spread across sibling modules installed on a
  shared backend object.

These are not labels supplied to Atlas. They are source-level explanations of
patterns Atlas measured without issue text or AI. The full observations and
the exact measured examples are in the
[replication report](../replication/README.md#provisional-taxonomy).

## Easy repository distinctions

### Vue: a statically explicit core

The frozen Vue world contains 516 files, 4,149 symbols, 1,177 imports, 4,594
calls, and 594 parent edges. Several Atlas seeds reach roughly 443–446 files.
The central runtime and compiler modules are visible as structural hubs. The
remaining misses concentrate around workspace aliases, build globals, and
compiler/runtime name contracts that the conservative resolver does not admit.

This is a repository where a large part of the maintenance structure is
explicit in the admitted graph. The retained future-maintenance experiment
accordingly found Atlas R@20 of 0.448 versus popularity R@20 of 0.168.

Evidence: [Vue replication section](../replication/README.md#vue-statically-explicit-core-with-cross-package-residuals).

### NodeBB: broad reverse-import propagation with weak selectivity

The frozen NodeBB signature is directionally asymmetric. `imported_by` has
median density 0.538 and p90 density 0.691, while forward `imports` has median
0.184 and p90 0.520. Extinction is low: about 1.3% for the import directions
and 4.7–5.3% for the call and definition directions. Some seeds reach 642 of
723 files.

That makes NodeBB easy to distinguish from Vue mechanically: static reach is
very broad, especially in the reverse direction, but it is less selective.
Important maintenance links also travel through configuration-selected
modules, string-addressed client/server protocols, and sibling backend
implementations rather than ordinary source edges.

Evidence: [NodeBB replication section](../replication/README.md#nodebb-serverclient-protocol-and-storage-family-coupling).

### Element: dense in every measured direction

The selected Element snapshot contains 831 admitted files, 5,727 definitions,
4,107 imports, and 6,556 calls. Median directional densities range from 0.166
for calls to 0.706 for `imported_by`; p90 densities range from 0.331 to 0.878.
None of the six measured directions becomes extinct for the selected seeds.

The time-bounded maintenance predictor run was censored, but the structural
signature was already computed independently and before maintenance outcomes
were opened. That is useful in its own right: Atlas can identify an unusually
dense structural regime even when no localization model or maintenance score
is available.

Evidence: [Element structural result](../replication/README.md#element).

## Reuse is also repository-specific

The tree-reuse experiment evaluated the same logical program family through
independent execution and a shared physical DAG. State maps were exactly
equal. At the largest completed File tier, median primitive-transition
compression differed substantially by repository:

| Repository | Median compression |
| --- | ---: |
| Axios | 494.94× |
| Immutable | 83.89× |
| Preact | 297.51× |
| Vue | 177.60× |

The cross-repository median was 237.56×. These differences are properties of
how the same Atlas family recurs over different repository structures, not of
an embedding model.

Evidence: [tree-reuse results](tree-reuse.md#conclusion).

## What this establishes

The retained evidence is enough for a narrow claim:

> A fixed, issue-blind Atlas program family produces visibly different and
> repeatable structural response profiles across repositories.

It does not yet establish that every repository has a stable signature across
revisions, that the signature predicts localization quality, or that these
few repositories define a taxonomy. Those are questions for the preregistered
full-snapshot census.
