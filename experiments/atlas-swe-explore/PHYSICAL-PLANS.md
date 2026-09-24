# Atlas physical-plan experiment

Status: secondary performance protocol, declared before the full census.

The primary Atlas census uses one fixed evaluator. Its signature must not
depend on an optimizer choosing an easier physical plan for one repository
than another. After those primary rows are frozen, this experiment asks a
different question:

> Can a repository's Atlas signature, together with a declared workload,
> choose a faster exact execution plan?

The loop under test is:

```text
repository
    -> fixed Atlas measurement
    -> repository signature
    -> inspectable physical-plan rule
    -> exact alternative Atlas execution
```

The planner receives two inputs because repository shape is not enough:

```text
(repository signature, workload signature) -> physical plan + explanation
```

A broad repository may favor one representation for a single-symbol query and
another for a full issue-blind census. The selected plan is physical only. It
cannot change the six atoms, legal programs, depth, seed set, result states, or
persisted state identities.

## Existing representation evidence

Roaring bitmaps are not an untried idea. AttuneRadii commit
`87d1137a4af395a287d5db1c3f3f5883515a11e6` replaced relation storage with
immutable PyRoaring `FrozenBitMap` frontiers and dense forward/reverse bitmap
rows. Its retained World-C measurements found a real representation win, while
frontier-composition reuse remained modest. The imported implementation and
record are preserved in
[`migration/attuneradii`](../../migration/attuneradii/README.md).

That result also established an identity law: native Roaring serialization is
a physical encoding, not scientific identity. Persistent states are identified
by the typed logical members in canonical order.

The later Flix port changed the measured bottleneck. On the retained Axios
timing seed, the current compiled Set evaluator measured 3.127 ms and the
experimental dense implementation measured 2.985 ms, a 0.142 ms / 4.8% gap.
Therefore this experiment will not begin by porting Roaring again. A bitmap
plan becomes a candidate only if post-Bazel profiles show enough dense bulk
work to make the earlier result material to the new workload.

## Workload signatures

The first workload classes are explicit and are never inferred from evaluator
gold:

```text
single-frontier
    one previously unseen File or Symbol state

repeated-snapshot-queries
    many issue-derived frontiers against one frozen snapshot

full-signature-panel
    all preregistered issue-blind census seeds against one snapshot

revision-delta
    update a previously prepared snapshot after a declared fact delta
```

`revision-delta` is a later experiment. It is listed now so incremental view
maintenance is not confused with ordinary cache reuse.

## Initial physical plans

The first implementation comparison is deliberately small.

### Demand

The current compiled evaluator walks only requested atoms, interns exact typed
states, shares program prefixes in a DAG, and memoizes compiled-node/state
answers. This is the baseline and likely plan for sparse, high-extinction
single-frontier work.

### Singleton basis

Composition of positive relations distributes over union:

```text
P(A union B) = P(A) union P(B)
```

For a frozen repository and Atlas program, precompute the result for singleton
File or Symbol inputs. A later multi-entity frontier is answered by looking up
and unioning those singleton results. Measure preparation time and bytes as
well as query time; this plan only wins after its build cost is amortized.

### Semantic classes

For one repository and seed panel, many logical programs can produce the same
exact typed state. Canonicalize these outcomes early and carry one semantic
class plus the stable first logical route used to explain it. Downstream work
operates on unique outcomes, not duplicate route slots. This must preserve the
complete route-to-state map and stable route ordering at the public boundary.

### Materialized compositions

Materialize only compositions whose measured reuse and density justify their
storage. This is a repository-specialized view, not a new Atlas atom. The
initial experiment may choose none; eager materialization is expected to lose
on repositories whose paths die early or whose composed relations become too
dense.

The first completed comparison must include Demand, Singleton basis, and
Semantic classes. Materialized compositions follow only when the census gives
a truthful candidate and size estimate. Bitmap and revision-delta plans remain
measurement-triggered rather than assumed wins.

## Inspectable planner

The first planner is a short deterministic rule table, not a learned model.
It may use only preregistered signature fields and declared workload fields,
for example:

```text
high extinction + one frontier
    -> Demand

many queries + high recurrence + small semantic state space
    -> Singleton basis, canonicalize semantic classes early

many queries + low extinction + dense normalized reach
    -> consider a dense/materialized plan after its byte budget is checked
```

Every choice records the input measurements and the rule that fired. A plan
may decline specialization and select Demand.

## Required parity

Every plan is checked against both permanent meanings:

```text
Repository.Structure / Datalog
    exact readable relation meaning

current Demand evaluator
    exact complete Atlas route -> state map
```

The alternative must preserve:

- every typed route and root order;
- every exact File/Symbol result set;
- stable first-route tie behavior;
- canonical persisted state identity;
- census measurements derived from those results.

Discrete outputs require exact equality. Timings and memory are telemetry and
cannot participate in scientific identity.

## Measurements

For each snapshot, workload, and physical plan record:

```text
preparation wall time
prepared artifact bytes
peak RSS
cold execution wall time
warm execution wall time
logical routes
unique semantic states
repository relation evaluations
memo/look-up operations
break-even query count versus Demand
exact parity result
```

BuildBuddy action time, cache hits, queueing, upload, and download are retained
separately from kernel time. A remote-cache hit proves derivation reuse; it is
not credited as evaluator speed.

## Promotion rule

A specialized plan enters the current evaluator only when it:

1. passes exact Datalog and Demand parity;
2. wins on the workload it claims to serve after preparation and artifact
   transfer are counted;
3. has a small inspectable selection rule;
4. does not make semantic identity depend on its representation;
5. deletes or isolates more mechanism than it adds to the public system.

Otherwise the result remains evidence and Demand remains the implementation.
