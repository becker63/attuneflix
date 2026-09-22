# Iteration 014 — Delta-aware expert selector

## Hypothesis

Iteration 013's deeper expert adds useful evidence on Preact 3454 but slightly
overshoots the stronger iteration-012 frontier on Preact 2757. Absolute
terminal top-eight previews may hide which prior-ranked symbols distinguish
two otherwise similar frontiers. Showing each expert's symbols exclusive to
the other should improve final arbitration without changing candidate
generation.

## Change from previous best

Replay the exact iteration-012 winner and exact iteration-013 deep expert.
Replace only their final neutral comparison. For each terminal alternative,
add the count and frozen-prior preview of symbols present only in that frontier
relative to the other. Keep every upstream model observation, structural
state, path, and ordinary terminal preview fixed.

## Why this might recover oracle headroom

The prior is the issue-conditioned signal available at deployment. An
exclusive-symbol preview exposes the actual marginal evidence contributed by
the deeper route, which should make a subtle useful expansion distinguishable
from a broad/noisy overshoot.

## Runtime information available to the policy

Issue text, frozen semantic prior, both exact terminal paths and states,
ordinary top-eight previews, exclusive/missing symbol counts, and the
prior-ranked preview of each alternative's exclusive symbols.

## Runtime information explicitly unavailable

Gold, official metrics, oracle paths/values, benchmark identifiers,
repository-specific exceptions, and previous per-case winner labels.

## Primary metric

Aggregate official line F1 over the frozen fifteen-case development set.

## Expected failure mode

Issue-relevant symbols may not rank highly in the frozen prior, or the model
may interpret additional exclusive symbols as evidence even when they add
noise. Since the experts often agree, the intervention has a narrow ceiling.

## Result

| Condition | Precision | Recall | F1 | HitFile | Context efficiency |
|---|---:|---:|---:|---:|---:|
| PRIOR | 0.286862 | 0.075187 | 0.058493 | 0.227778 | 0.407990 |
| Jev v1 | 0.196199 | 0.093466 | 0.078887 | 0.205556 | 0.267742 |
| Previous best (013) | **0.458034** | **0.179653** | **0.201549** | **0.341111** | **0.524766** |
| Iteration 014 | 0.436605 | 0.179476 | 0.191951 | 0.314444 | 0.506429 |
| STRUCTURAL ORACLE | 0.640725 | 0.295496 | 0.324831 | 0.410000 | 0.735848 |

Iteration 014 regresses the primary metric and every headline secondary metric
relative to iteration 013.

## Headroom capture

`50.1084%`, down from `53.7122%` for iteration 013.

## Secondary metrics

Weighted core coverage is `0.148022`, noise-region rate is `0.506667`, and
nDCG@100 is `0.481947`. Coverage rises relative to 013, but precision,
HitFile, efficiency, noise, and nDCG worsen.

## Per-case results

The delta selector restores Preact 2757 (`0.178273 -> 0.184497`) and improves
Preact 3689 (`0.137931 -> 0.213660`). It loses Immutable 2005
(`0.159915 -> 0.105379`), Immutable 2006 (`0.224969 -> 0.181373`), and Preact
3454 (`0.530435 -> 0.402640`). Other cases tie. Full results are in
`metrics.parquet`.

## Decision depth / model-call statistics

The composite policy retains 767 decisions (51.133/case), with 2,307,531 input
tokens, 156,432 output tokens, and `$0.096916302` from scratch. Only 12 final
comparisons are new: 16,272 input tokens, 732 output tokens, and `$0.000683424`.

## Oracle regret analysis

Residual aggregate F1 grows to `0.132880`. The delta representation finds a
better frontier for Preact 3689 but throws away the near-oracle Preact 3454
frontier and both strong Immutable winners. Its errors are arbitration errors,
not candidate-generation failures.

## Cases improved

Preact 2757 and Preact 3689.

## Cases regressed

Immutable 2005, Immutable 2006, and Preact 3454.

## Interesting trajectories

The selector favors long call-only chains for both Immutable cases and reverts
Preact 3454 to the broad `defined_in -> defines` frontier. Conversely it finds
a useful six-step route for Preact 3689. Explicit exclusive evidence therefore
does reveal some missed value, but induces a stronger novelty bias than the
absolute terminal comparison.

## Provider cost / observations

Twelve new observations cost `$0.000683424`. Replay reproduced all semantic
paths and model observations with zero network capability.

## Interpretation

Cross-expert delta is not a generally better final representation. It makes
the model attend to marginal symbols, but without a reliable notion of whether
those symbols are useful, novelty overwhelms the already effective absolute
terminal judgment. The Preact 3689 gain is evidence that the deep candidate is
valuable there; a future selector may use both absolute and delta views or a
separate arbitration mechanism, but 014 itself should not be promoted.

## Promote or reject

Reject. Best remains iteration 013.

## Next hypothesis

Candidate coverage, not another formatting mutation, is now the larger lever.
Train a tiny repository-agnostic route-template library from the fifteen
oracle paths, apply every learned template uniformly to every case, and ask
Jev to rank the resulting deployment-visible terminal previews alongside the
replayed iteration-013 winner. This is explicitly development-set training
performance and tests whether a compact learned policy vocabulary can expose
the remaining oracle basins without case-keyed lookup.

## Reproducibility

- Jujutsu change ID: `knrwunxu`
- protocol: `attune-jev-policy-hillclimb-014-delta-expert-selector-v1`
- model: `typesafe/jev-1.13`
- both candidate generators replay exactly; only final comparisons receive new
  observation identities
- replay outcomes SHA-256: `f68a5a51e62c7bcd1dd768af2a7c9c214bc590f4f9402bcde4732a0747a5a70c`
- evaluation SHA-256: `5b9b2f8228956137f782d1fece61507e3a09e83fc7c882107ac4d50db89af4b3`
- exact replay: all 12 new comparisons and both candidate generators replayed
  with zero network capability and identical semantic paths/rankings
