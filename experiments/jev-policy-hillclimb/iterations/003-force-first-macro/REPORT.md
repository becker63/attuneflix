# Iteration 003 — Force one ranked macro before stopping

## Hypothesis

Iteration 002's largest remaining losses are root stops. Requiring one
deployment-visible, model-ranked short continuation before exposing stop should
recover high-headroom cases whose useful signals appear only after structural
movement.

## Change from previous best

At depth zero only, the rank-stage winner executes without the binary stop
gate. From the next state onward, iteration 002's rank-then-binary-stop policy is
unchanged.

## Why this might recover oracle headroom

Nine iteration-002 cases stopped at root, including 4436, 3739, 3562, and 2757.
Their combined oracle gap dominates the remaining aggregate loss. The frozen
diagnosis also found most irreversible value loss at depth zero or one.

## Runtime information available to the policy

Unchanged from iteration 002: issue, prior, current/path preview, valid
one-to-three-action macros, terminal previews, then current-versus-proposal
comparisons after the first macro.

## Runtime information explicitly unavailable

Gold, official scores, oracle paths/values, case-specific exceptions, and
benchmark-derived runtime lookup tables.

## Primary metric

Aggregate official line F1 on the frozen fifteen-case development set.

## Expected failure mode

Forcing movement may destroy strong priors (especially Preact 3454) or no-
headroom cases. It also cannot help if Jev's macro ranking itself selects the
wrong root continuation.

## Result

| Condition | Precision | Recall | F1 | HitFile | Context efficiency |
|---|---:|---:|---:|---:|---:|
| PRIOR | 0.286862 | 0.075187 | 0.058493 | 0.227778 | 0.407990 |
| Jev v1 | 0.196199 | 0.093466 | 0.078887 | 0.205556 | 0.267742 |
| Previous best (002) | 0.241150 | 0.099412 | 0.091550 | 0.274444 | 0.355615 |
| Iteration 003 | 0.336475 | 0.144047 | 0.144274 | 0.261111 | 0.382407 |
| STRUCTURAL ORACLE | 0.640725 | 0.295496 | 0.324831 | 0.410000 | 0.735848 |

Iteration 003 improves F1 by 82.88% over v1 and 57.59% over iteration 002.

## Headroom capture

`32.2077%`, up from `12.4114%` for iteration 002.

## Secondary metrics

Weighted core coverage is `0.104712`, noise-region rate `0.653333`, and
nDCG@100 `0.347826`. Precision exceeds both PRIOR and v1. Context efficiency is
close to PRIOR while recall nearly doubles PRIOR.

## Per-case results

| Case | PRIOR | Iter 003 | ORACLE | Path |
|---|---:|---:|---:|---|
| axios-4731 | 0.000000 | 0.000000 | 0.011628 | callers >> defined_in >> defines |
| axios-5085 | 0.000000 | 0.000000 | 0.208333 | calls |
| immutable-2005 | 0.089503 | 0.019507 | 0.168700 | callers |
| immutable-2006 | 0.198813 | 0.224969 | 0.328438 | calls |
| preact-2757 | 0.000000 | 0.127774 | 0.201560 | callers >> callers |
| preact-2896 | 0.050955 | 0.379666 | 0.825499 | calls >> callers >> callers >> callers >> calls >> callers |
| preact-3010 | 0.000000 | 0.000000 | 0.000000 | defined_in >> defines |
| preact-3454 | 0.402640 | 0.402640 | 0.572770 | defined_in >> defines |
| preact-3562 | 0.016694 | 0.016694 | 0.325517 | defined_in >> defines |
| preact-3689 | 0.069498 | 0.137931 | 0.428571 | defined_in >> defines >> calls |
| preact-3739 | 0.000000 | 0.000000 | 0.502439 | defined_in >> defines |
| preact-3763 | 0.000000 | 0.000000 | 0.166320 | calls >> callers >> calls >> defined_in >> defines |
| preact-4152 | 0.000000 | 0.000000 | 0.000000 | defined_in >> defines >> callers |
| preact-4182 | 0.049296 | 0.051429 | 0.329177 | defined_in >> defines >> calls >> defined_in >> defines >> calls |
| preact-4436 | 0.000000 | 0.803506 | 0.803506 | defined_in >> imported_by >> defines |

## Decision depth / model-call statistics

Fifty-five calls, 3.667/case. Every case traverses at least one edge: depths are
1 (3), 2 (5), 3 (4), 5 (1), and 6 (2).

## Oracle regret analysis

The aggregate residual to oracle falls to `0.180556`. Preact 4436 reaches the
exact oracle path and exact `0.803506` F1. Preact 2757 recovers 63.4% of its
case-level oracle F1. The largest remaining absolute gaps are 2896 (`0.445833`),
3739 (`0.502439`), 3562 (`0.308823`), and 3689 (`0.290640`).

## Cases improved

Six cases improve over PRIOR. The decisive new recovery is Preact 4436, which
moves from zero to the exact oracle. Preact 2757 also moves from zero to
`0.127774`; 2896 retains iteration 002's `0.379666` gain.

## Cases regressed

Immutable 2005 regresses from PRIOR `0.089503` to `0.019507` because forced
movement executes `callers`; iteration 002 had reached `0.159915` by allowing
further selected structure. Preact 3763 loses HitFile despite unchanged F1 zero.

## Interesting trajectories

The exact 4436 oracle path is only three actions and becomes selectable once
root stop is removed—the cleanest causal evidence yet for the three-step
signal. In contrast, 3739 and 3562 select the idempotent same-file macro and
remain poor. Forced exploration solves stopping but exposes macro-ranking error.

## Provider cost / observations

Fifty-five exact observations were retained: 142,219 input tokens, 9,303
output tokens, and `$0.005973198`.

## Interpretation

Root stopping was a major bottleneck. Removing it recovers one full oracle case
and creates the largest aggregate gain so far. The residual has shifted: macro
ranking, especially attraction to state-preserving same-file expansion, now
dominates. Forced exploration is not universally safe, as Immutable 2005 shows.

## Promote or reject

Promote. This is the new best aggregate-F1 policy.

## Next hypothesis

Keep forced first exploration, but remove exact state-preserving macros from the
rank alternatives. This generic no-op pruning uses only deployment-visible
state identity and directly targets the failed 3739/3562 choices without
hardcoding an atom sequence.

## Reproducibility

- Jujutsu change ID: `wmymxtvm`
- protocol: `attune-jev-policy-hillclimb-003-force-first-macro-v1`
- model: `typesafe/jev-1.13`
- frozen machine and official scorer unchanged
- outcomes SHA-256: `f52c33d95b20bdff190b8dd29b02e7662dc6d605e89e4a5a0b8fec357775f368`
- evaluation SHA-256: `e5da6b536fd2f8240a09acf79ecd360c0e5d1ebd7b71ead20e54818e26a9c834`
- acquisition verification: 48 passed, 0 failed
- exact replay verification: 55 observations, zero network capability, identical paths/rankings, 48 passed
