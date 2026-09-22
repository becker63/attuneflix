# Jev v1 Selection Diagnosis

## Executive conclusion

Jev v1 is mainly failing on **planning horizon**, with a secondary
high-confidence same-file attractor and poorly calibrated stopping. It is not
primarily failing because the frozen tree lacks useful structure, because good
routes are universally absent, or because exact top-eight preview collisions
make the immediate alternatives indistinguishable.

The clearest diagnostic is the post-hoc receding-horizon oracle:

| Selector | Mean line F1 | Structural headroom captured |
|---|---:|---:|
| frozen PRIOR | 0.058493 | 0.0% |
| frozen Jev v1 | 0.078887 | 7.66% |
| 1-step oracle | 0.093513 | 13.15% |
| 2-step oracle | 0.108597 | 18.81% |
| 3-step oracle | 0.239664 | 68.02% |
| full oracle | 0.324831 | 100.0% |

The discontinuity is between two and three steps. This is post-hoc gold
analysis, not a new localization result, but it establishes that much of the
selection problem is not locally identifiable from one immediate child.

Jev loses all remaining oracle value at depth 0 in six cases, depth 1 in six,
and depth 2 in one. The other two cases have no structural F1 headroom. Thus
every positive-headroom case has suffered an irreversible loss by its third
choice.

The smallest justified next experiment is therefore one change: replace
single-atom alternatives with **typed macro alternatives of up to three
steps**, showing the same frozen terminal-state preview for each macro. Keep
the model, prompt objective, prior, tree, center count, max depth, projection,
and cases fixed.

## Evidence and immutability

This is a post-hoc diagnosis over the completed frozen experiment. It made no
embedding or Jev requests and did not run Grit. Repository worlds came from
the 15 retained fact artifacts.

The diagnostic records these frozen inputs:

```text
outcomes   0901bf208bcf98ccdfce0c6281e9990f90b4823d8fd68ea0780e484cceb7636c
evaluation 70cedc1753711ec4acba7f547c4a4ad2f623a2ca48b98aea5d97c8c8d62dd541
prior      73efdb1159aeb0be552ae16bf53f52ca85755c29d2ea35f478fc5469f521c914
```

The implementation is one opt-in branch of `JevOracleTest`. It reuses the
literal official evaluator port, builds the same 3,279-route tree, and writes
only `.attune/jev-selection-diagnosis-v1/diagnosis.parquet`. Normal tests perform
no heavyweight analysis.

## Method

For every root and route prefix, the diagnostic retained the exact compiled
state and official score when stopping was valid. It then computed:

```text
V_F1(prefix) = maximum final line F1 under that prefix
```

and the corresponding recall, HitFile, and context-efficiency values of the
stable first best descendant. For each of the 78 frozen Jev decisions it
compared the chosen branch with every available action, including stop, and
recorded immediate score, value-to-go, regret, preview, frontier size,
prior-rank summaries, revisit status, and frozen model probability.

The 1/2/3-step diagnostics are receding-horizon gold oracles: at each state
they select the stable first branch containing the best valid Symbol stopping
state visible within that many transitions, advance one transition, and
replan. They diagnose required horizon; they are not deployable selectors.

`substantially better` is fixed post hoc as an absolute F1 gain of at least
0.05. Near-oracle counts use relative gaps of 1%, 5%, and 10%.

## Where Jev loses the tree

Exact Jev-path versus stable-oracle-path divergence occurs at depth 0 in eight
cases and depth 1 in seven, but that overstates failure because different
prefixes can retain the same value-to-go. The stronger irreversible-value
measure is:

| First depth with positive regret | Cases |
|---:|---:|
| 0 | 6 |
| 1 | 6 |
| 2 | 1 |
| none | 2 |

Across all 78 decisions, mean F1 regret is 0.04730, median is zero, and the
maximum is 0.64236. Fifty-three decisions have a genuine value distinction
between alternatives. Jev selects a value-optimal action in only 23 of those
53 (43.4%). Regret is concentrated early: depth 0 mean regret is 0.06730 and
depth 1 mean regret is 0.08906, the largest depth mean.

## Are good routes rare?

The answer depends on whether `good` means useful or nearly optimal.

Among the 13 positive-headroom cases, the median case has:

```text
167 / 1,644 routes better than PRIOR            10.16%
131 / 1,644 routes at least +0.05 F1 better      7.97%
  5 / 1,644 routes within 5% of the oracle        0.30%
 15 / 1,644 routes within 10% of the oracle       0.91%
```

So useful routes are not generally needles, but near-oracle routes usually
are. The population is heterogeneous:

- Immutable-2005 has 897 routes better than prior and 238 within 5% of its
  oracle, yet Jev stops at the root.
- Preact-2757 has 963 better routes and 156 near-oracle routes, yet Jev also
  stops at the root.
- Preact-3763 has only two routes better than prior and one near-oracle route.
- Preact-4182 has one route within 5% of oracle; Preact-3739 has two.

This rules out a single `needle in every case` explanation. Early stopping can
miss broad basins, while several other cases genuinely require a narrow path.

## Immediate observables versus eventual value

Across 271 action alternatives, simple Pearson correlations with oracle F1
value-to-go were:

| Property | Correlation |
|---|---:|
| immediate child F1 (gold diagnostic, not model-visible) | +0.530 |
| frontier cardinality | -0.095 |
| cardinality delta | +0.068 |
| new prior-ranked members | +0.034 |
| removed prior-ranked members | -0.196 |
| minimum prior rank | -0.138 |
| mean prior rank | -0.123 |
| Jev action probability | approximately 0.000 |

Even unavailable immediate gold quality is only a moderate proxy for eventual
quality. The cheap model-visible summaries are weak proxies. Jev chooses the
largest displayed frontier in 37/78 decisions, and the chosen frontier has
mean cardinality 60.4 versus 51.6 averaged over each decision's alternatives,
showing a modest broadening preference rather than a complete size heuristic.

## Stopping

Jev explicitly stops eight times:

```text
correct stop      3
premature stop    5
```

The five premature stops are:

| Case | Depth | Confidence | Stop F1 | Best descendant F1 | Regret |
|---|---:|---:|---:|---:|---:|
| Immutable-2005 | 0 | 0.10 | 0.0895 | 0.1687 | 0.0792 |
| Immutable-2006 | 1 | 0.17 | 0.2250 | 0.3081 | 0.0832 |
| Preact-2757 | 0 | 0.16 | 0 | 0.2016 | 0.2016 |
| Preact-3739 | 1 | 0.07 | 0 | 0.5024 | 0.5024 |
| Preact-4436 | 1 | 0.08 | 0 | 0.1611 | 0.1611 |

All five have low stated confidence. That makes confidence-aware search a
plausible later intervention, but not the cleanest first test: across all 30
positive-regret decisions, a value-optimal action appears in Jev's top two
probabilities only 14 times. Top-two branching alone would leave more than
half of the observed mistakes uncovered.

## The `defined_in -> defines` attractor

The exact two-step motif occurs 26 times.

```text
exactly state-idempotent cycles       14 / 26
mean symbol-set Jaccard                    0.615
mean new symbols after the closure          51.85
mean removed symbols                          0
cycles with positive branch regret         9 / 26
mean confidence on the `defines` choice      0.851
```

The first closure can be meaningful: it projects seed symbols to files and
returns all symbols defined in those files. It is always extensive in this
sample (no symbols removed). Repeating it is often a literal no-op: 14 cycles
return exactly the input symbol state. The model nevertheless chooses the
second `defines` step with very high confidence on average.

This is a real secondary failure mechanism. The absolute preview does not say
`this returns to an earlier state`, so a semantically familiar same-file
expansion can consume depth while hiding imports. But banning the motif would
be overfitting: first closure steps sometimes retain good branches, and the
dominant horizon result is broader than this one action pair.

## Preview information

The final artifact reports semantic-state and exact-preview collisions both
globally and within each actual decision. These diagnostics distinguish
literal information loss from merely insufficient lookahead.

Across the full route forest, the 49,200 case/node observations collapse to
14,159 unique semantic states and 12,173 exact preview strings. There are
1,229 preview strings shared by more than one semantic state. Some global
preview groups have different value-to-go, but this is not literal model
aliasing: they occur at different paths/depths, both of which v1 exposes.

The decisive within-choice check is much cleaner. Across the 78 decisions,
only four sets of sibling alternatives have an identical exact preview, and
none has different F1 value-to-go. Thus no observed v1 decision required Jev
to distinguish two alternatives whose complete displayed preview was exactly
the same. Near-similar text may still tax the model, but exact top-eight
aliasing is not the dominant mechanism.

The current evidence therefore does not justify `show more than eight items`
as the first intervention. The stronger failure is that an immediate preview
does not expose what becomes reachable after a short sequence.

## Confidence and regret

The Pearson correlation between stated confidence and regret is -0.234. Low
confidence is somewhat informative but not a calibrated safety signal:

| Confidence tercile | Mean confidence | Mean regret | Positive-regret decisions |
|---|---:|---:|---:|
| low | 0.158 | 0.0966 | 14 / 26 |
| middle | 0.419 | 0.0124 | 8 / 26 |
| high | 0.851 | 0.0329 | 8 / 26 |

There are consequential high-confidence errors, particularly `defines` after
`defined_in`. Jev partly knows when it does not know, especially around stop,
but confidence is not sufficient to repair v1 by itself.

## Three key cases

### Preact-2896: a real success that still becomes myopic

Jev preserves full oracle value through its first two decisions:

```text
root --calls--> calls --callers--> calls>>callers
V_F1       0.8255                    0.8255
```

At depth 2 it chooses `callers` (probability 0.34) over `calls` (0.33) and
`defined_in` (0.21). The chosen branch's immediate F1 is slightly best
(0.3403 versus 0.3386 for `calls`), but its value-to-go falls from 0.8255 to
0.6615. This choice creates most of Jev's observed gain, so it is locally
sensible and globally suboptimal.

At depth 4 the failure is clearer. From a File state, Jev chooses `defines`
with probability 0.81 and confidence 0.72. Its value-to-go is 0.3698;
`imported_by` has value 0.6615. That one high-confidence same-file choice costs
0.2917 F1 headroom. Jev finishes at 0.3403 instead of the 0.8255 oracle.

This case shows both facts needed for v2: Jev can exploit structural signal,
but a locally attractive immediate state and a familiar action name do not
identify the best short plan.

### Preact-3739: the correct first branch, then premature stop

At the root all immediate alternatives score zero. Jev correctly chooses
`calls`, which retains the full 0.5024 oracle value. At depth 1 it stops with
confidence 0.07. Every immediate child still scores zero, but:

```text
calls -> callers        value-to-go 0.5024
calls -> calls          value-to-go 0.4460
calls -> defined_in     value-to-go 0.1450
stop                    value       0
```

The error is not a bad structural first move. It is a textbook horizon
failure: the useful evidence is invisible at the immediate stopping state.

### Preact-4436: indistinguishable immediate quality, wrong root branch

At the root, stop, `defined_in`, `calls`, and `callers` all have immediate F1
zero. Jev chooses `calls` with probability 0.31 and confidence 0.08. Their
future values differ radically:

```text
defined_in    0.8035
callers       0.8035
calls         0.1611
stop          0
```

Jev then stops at depth 1, losing the remaining 0.1611. The full oracle path
`defined_in >> imported_by >> defines` is only three steps long, and the
3-step receding-horizon diagnostic reaches the full 0.8035. This is the
cleanest single example supporting a three-step model-visible action horizon.

## Case-level failure taxonomy

Categories below describe the largest mechanistic loss; several cases also
have secondary errors.

| Case | PRIOR | Jev | Oracle | First value loss | Largest regret | Primary diagnosis |
|---|---:|---:|---:|---:|---:|---|
| Axios-4731 | 0 | 0 | 0.0116 | 1 | 0.0101 | same-file attractor; small headroom |
| Axios-5085 | 0 | 0 | 0.2083 | 0 | 0.1895 | same-file attractor after weak root loss |
| Immutable-2005 | 0.0895 | 0.0895 | 0.1687 | 0 | 0.0792 | premature root stop despite broad basin |
| Immutable-2006 | 0.1988 | 0.2250 | 0.3284 | 0 | 0.0832 | partial gain, then premature stop |
| Preact-2757 | 0 | 0 | 0.2016 | 0 | 0.2016 | premature root stop despite broad basin |
| Preact-2896 | 0.0510 | 0.3403 | 0.8255 | 2 | 0.2917 | successful early path, late same-file loss |
| Preact-3010 | 0 | 0 | 0 | none | 0 | no frozen structural headroom |
| Preact-3454 | 0.4026 | 0.4026 | 0.5728 | 1 | 0.1053 | repeated same-file attractor |
| Preact-3562 | 0.0167 | 0.0167 | 0.3255 | 1 | 0.1791 | repeated same-file attractor |
| Preact-3689 | 0.0695 | 0.0839 | 0.4286 | 0 | 0.2696 | wrong root family, then late attractor |
| Preact-3739 | 0 | 0 | 0.5024 | 1 | 0.5024 | premature stop; deep benefit invisible |
| Preact-3763 | 0 | 0 | 0.1663 | 1 | 0.1663 | same-file attractor; near-oracle needle |
| Preact-4152 | 0 | 0 | 0 | none | 0 | no frozen structural headroom |
| Preact-4182 | 0.0493 | 0.0252 | 0.3292 | 1 | 0.1515 | attractor plus failure to stop before regression |
| Preact-4436 | 0 | 0 | 0.8035 | 0 | 0.6424 | wrong root under local tie, then premature stop |

Primary-category counts among the 13 positive-headroom cases are four
premature-stop cases, five same-file-attractor cases, two wrong-root cases,
one partial-success/late-branch case, and one late failure-to-stop case. These
labels overlap; the common cause underneath most is that immediate-state
evidence poorly represents short-horizon consequences.

## Mechanistic answer

1. **Where is value lost?** Almost entirely in the first two decisions: 12/13
   positive-headroom cases lose value at depth 0 or 1; the remaining case
   loses it at depth 2.
2. **Are good routes rare?** Merely better routes are often plentiful; routes
   very near the oracle are usually sparse.
3. **Are they prefix-clustered?** Sometimes strongly, not universally. In
   Preact-2896, 136/167 top-decile routes (81%) begin with `calls`; in
   Preact-4436, 160/170 (94%) begin with `defined_in`. Preact-4182 is weaker
   but still has 85/167 (51%) under `calls`. Other cases are diffuse or have
   large zero-score ties. A coarse prefix decision can be powerful in some
   cases, but cannot be the entire selector.
4. **Does immediate quality predict eventual quality?** Only moderately even
   when measured with unavailable gold (r=0.53); cheap visible summaries are
   much weaker.
5. **How much lookahead is needed?** Three-step oracle lookahead captures 68%
   of available aggregate F1 headroom; one and two steps capture 13% and 19%.
6. **Is confidence calibrated?** Weakly. Low confidence carries more regret,
   but high-confidence same-file errors remain.
7. **What is the same-file motif?** A meaningful first closure followed by
   frequent exact no-ops; 14/26 cycles are idempotent and the model chooses
   `defines` with mean confidence 0.851.
8. **Does top-eight exact aliasing explain failure?** No. Only four actual
   decision sibling sets contain exact duplicate previews, with no observed
   value difference. The stronger loss is downstream information absent from
   any immediate preview.
9. **Are stops calibrated?** No: five of eight explicit stops are premature.
10. **Why did 2896 work?** Its first two choices retained oracle value and a
    locally attractive third choice delivered a large gain; it later lost
    most remaining value on a high-confidence same-file expansion.
11. **Dominant problem?** Greedy decision structure plus locally insufficient
    representation of downstream consequences. Prompt/model judgment and the
    same-file attractor contribute. Exact preview truncation is not currently
    the leading explanation.

## Smallest clean follow-up experiment

### Hypothesis

Jev v1 fails because single-atom alternatives expose only immediate states,
while most recoverable quality becomes distinguishable over approximately
three typed transitions.

### One changed factor

At each decision, replace single-atom follow alternatives with every valid
typed macro suffix of length one through three that ends in a Symbol state.
Show:

```text
macro path
same frozen terminal-state preview used by v1
```

`stop` remains available exactly where it is now. Applying a macro consumes
its actual depth, after which Jev makes the next decision normally. No oracle
score or gold-derived feature is exposed.

### Held fixed

```text
15 cases
semantic prior and all retained embeddings
six atoms and composition-only tree
MAX_DEPTH = 7
CENTER_COUNT = 8
compiled evaluator
stable-partition projection
Jev model/provider
prompt objective and issue text
official evaluator and five-region budget
```

### Primary outcome

Fraction of frozen structural F1 headroom captured:

```text
(F1_macro3 - F1_PRIOR) / (F1_ORACLE - F1_PRIOR)
```

Secondary outcomes are line recall, HitFile, context efficiency, premature
stops, and paid decision count.

### Failure criterion

The hypothesis fails if macro-3 does not materially exceed the frozen v1
7.66% headroom capture, or if any gain is purchased by enough context
expansion to erase F1/context-efficiency improvement.

### Expected direction

Macro-3 should reduce root/depth-1 regret, premature zero-score stops, and the
same-file no-op loop by making short typed plans model-visible. The post-hoc
68% figure is an upper bound from gold, not a performance prediction for Jev.

No v2 implementation or prompt tuning was performed in this diagnosis.
