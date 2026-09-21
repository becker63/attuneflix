# Iteration 002 — Two-stage three-step selection

## Hypothesis

Iteration 001 failed because a single stop option dominated a large multiclass
comparison. Separating continuation ranking from a binary stopping decision
should preserve short-horizon visibility without inducing root-stop collapse.

## Change from previous best

The one-to-three-step continuations and terminal previews are unchanged from
iteration 001. Each decision now has two stages: rank non-stop continuations,
then compare the selected continuation directly with the current state.

## Why this might recover oracle headroom

Jev no longer has to compare one qualitatively different stop action against a
large set of structural paths. The second call asks the narrower calibrated
question: is this best proposal better than the current frontier?

## Runtime information available to the policy

Exactly the iteration-001 issue, prior, path, current preview, macro names and
terminal previews. The second stage sees only current versus the selected
proposal.

## Runtime information explicitly unavailable

Gold, official metrics, oracle paths/values, case-specific rules, and labels
derived from future decisions.

## Primary metric

Aggregate official line F1 on the frozen fifteen-case development set.

## Expected failure mode

The rank stage may still prefer the same-file attractor, and the binary stage
may remain overly conservative. Two separate myopic calls may not approximate
planning even when terminal states are visible.

## Result

| Condition | Precision | Recall | F1 | HitFile | Context efficiency |
|---|---:|---:|---:|---:|---:|
| PRIOR | 0.286862 | 0.075187 | 0.058493 | 0.227778 | 0.407990 |
| Jev v1 | 0.196199 | 0.093466 | 0.078887 | 0.205556 | 0.267742 |
| Previous iteration | 0.259517 | 0.078383 | 0.063789 | 0.227778 | 0.398673 |
| Iteration 002 | 0.241150 | 0.099412 | 0.091550 | 0.274444 | 0.355615 |
| STRUCTURAL ORACLE | 0.640725 | 0.295496 | 0.324831 | 0.410000 | 0.735848 |

Iteration 002 improves F1 16.05% over v1 and 43.52% over iteration 001.

## Headroom capture

`12.4114%`, compared with v1's `7.6572%` and iteration 001's `1.9883%`.

## Secondary metrics

Weighted core coverage is `0.088034`, noise-region rate `0.680000`, and
nDCG@100 `0.281159`. F1, recall, HitFile, and weighted coverage beat v1;
precision, context efficiency, and nDCG remain below the prior.

## Per-case results

| Case | PRIOR | Iter 002 | ORACLE | Path |
|---|---:|---:|---:|---|
| axios-4731 | 0.000000 | 0.000000 | 0.011628 | root |
| axios-5085 | 0.000000 | 0.000000 | 0.208333 | root |
| immutable-2005 | 0.089503 | 0.159915 | 0.168700 | callers >> calls |
| immutable-2006 | 0.198813 | 0.224969 | 0.328438 | calls |
| preact-2757 | 0.000000 | 0.000000 | 0.201560 | root |
| preact-2896 | 0.050955 | 0.379666 | 0.825499 | calls >> callers >> callers >> callers >> calls >> callers |
| preact-3010 | 0.000000 | 0.000000 | 0.000000 | root |
| preact-3454 | 0.402640 | 0.402640 | 0.572770 | root |
| preact-3562 | 0.016694 | 0.016694 | 0.325517 | root |
| preact-3689 | 0.069498 | 0.137931 | 0.428571 | defined_in >> defines >> calls |
| preact-3739 | 0.000000 | 0.000000 | 0.502439 | root |
| preact-3763 | 0.000000 | 0.000000 | 0.166320 | root |
| preact-4152 | 0.000000 | 0.000000 | 0.000000 | defined_in >> defines >> callers >> calls |
| preact-4182 | 0.049296 | 0.051429 | 0.329177 | defined_in >> defines >> calls >> defined_in >> defines >> calls |
| preact-4436 | 0.000000 | 0.000000 | 0.803506 | root |

## Decision depth / model-call statistics

Fifty model calls, 3.333 per case. Nine cases stop at depth zero; the remaining
depths are 1, 2, 3, 4, and two at 6. Two-stage choice more than halves v1's
calls while permitting materially deeper macro trajectories than iteration 001.

## Oracle regret analysis

The aggregate residual to oracle falls to `0.233281`, versus v1's `0.245943`.
Immutable 2005 reaches 94.8% of its oracle F1. The dominant remaining loss is
concentrated in root stops on Preact 4436 (`0.803506` available), 3739
(`0.502439`), 3562 (`0.308823` beyond prior), and 2757 (`0.201560`).

## Cases improved

Five cases improve over PRIOR. Immutable 2005 and 2006 both improve, Preact
2896 rises to `0.379666`, Preact 3689 doubles to `0.137931`, and Preact 4182
improves slightly.

## Cases regressed

No case regresses below PRIOR, but relative to v1 the policy gives up some of
2896's still-available oracle quality and fails to activate large-headroom root
cases. Nine exact ties with PRIOR show that stopping remains too conservative.

## Interesting trajectories

The two-stage split restores the successful 2896 behavior without following the
oracle path. It also discovers a near-oracle `callers >> calls` path for
Immutable 2005. The same-file motif remains in all three traversing Preact cases
other than 2896, including a repeated motif in 4182.

## Provider cost / observations

Fifty exact observations were retained under
`.attune/experiments/jev-policy-hillclimb/002-two-stage-macro3`: 114,104 input
tokens, 7,038 output tokens, and `$0.004792368`.

## Interpretation

Separating ranking from stopping is a real improvement: it prevents complete
root-stop collapse and improves the primary objective. Yet the binary gate is
still conservative enough to discard most aggregate oracle headroom. The rank
stage appears capable of useful choices when allowed to execute.

## Promote or reject

Promote. This is the new best aggregate-F1 policy.

## Next hypothesis

Hold the rank stage fixed and remove the binary stop gate until at least one
macro has executed. This changes only initial stopping availability and tests
whether root conservatism, rather than macro ranking, causes the dominant
remaining misses.

## Reproducibility

- Jujutsu change ID: `rrqzrpuw`
- protocol: `attune-jev-policy-hillclimb-002-two-stage-macro3-v1`
- model: `typesafe/jev-1.13`
- frozen machine and official scorer unchanged
- outcomes SHA-256: `d13c137bdc7f32689a94550c9e2aefba4240b976d64d54ad8dcd29d9632f4ad6`
- evaluation SHA-256: `97219669fdebb7289d1a576b040c63a8c87c959ddd8362c9c1dbd144318f2842`
- acquisition verification: 48 passed, 0 failed
- exact replay verification: 50 observations, zero network capability, identical paths/rankings, 48 passed
