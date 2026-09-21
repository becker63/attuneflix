# Jev Policy Hill-Climb — Final Report

## Executive result

The best honest deployable policy found on the frozen fifteen-case development
set is iteration 013, the two-rollout deep-planner portfolio.

| Condition | Precision | Recall | F1 | HitFile | Context efficiency |
|---|---:|---:|---:|---:|---:|
| PRIOR | 0.286862 | 0.075187 | 0.058493 | 0.227778 | 0.407990 |
| Frozen Jev v1 | 0.196199 | 0.093466 | 0.078887 | 0.205556 | 0.267742 |
| **Best: iteration 013** | **0.458034** | **0.179653** | **0.201549** | **0.341111** | **0.524766** |
| STRUCTURAL ORACLE | 0.640725 | 0.295496 | 0.324831 | 0.410000 | 0.735848 |

Iteration 013 improves F1 by `+0.122662` over v1, or `2.55x` the v1 F1. It
captures `53.7122%` of the structural headroom between PRIOR and ORACLE, versus
`7.6572%` for v1. This is oracle-guided optimization/training performance on
the frozen fifteen-case development set, not an untouched generalization
estimate.

## Best policy architecture

The best policy composes two independently generated candidates:

1. Replay iteration 012's exact-revisit-pruned planner portfolio. That policy
   itself combines the forced-first-macro expert with a one-rollout
   hierarchical planner.
2. Build a deeper expert by making two sequential one-to-three-action rollout
   choices under every root continuation, pruning any rollout whose terminal
   semantic state exactly equals the query input or a prefix state.
3. Let Jev compare the two concrete terminal frontiers once using the ordinary
   issue-conditioned top-eight previews.

All structural states are computed by the frozen compiled Radii evaluator.
Gold, oracle values, instance IDs, and repository-specific rules are absent at
runtime. The policy changes only selection/planning.

The causal gains were:

- forced first macro: `0.091550 -> 0.144274` F1;
- hierarchical consequence visibility: `0.144274 -> 0.157611`;
- complementary terminal expert arbitration: `0.157611 -> 0.170048`;
- exact ancestor-state pruning: `0.170048 -> 0.193444`;
- second rollout level: `0.193444 -> 0.201549`.

## Why it works

Three mechanisms survived direct ablation:

1. **Short-horizon consequence visibility.** Greedy immediate choices leave
   value hidden. Per-root rollouts expose a more meaningful terminal state.
2. **Provable recurrence removal.** Exact state revisits are not merely wasted
   work; they can hide better candidates. Pruning them moved Preact 3739 from
   F1 `0` to `0.350943` without regressing any other case in iteration 012.
3. **Small concrete portfolios.** Jev reliably arbitrated two complementary
   terminal outcomes in iteration 011, exactly choosing the higher-F1 member
   on every consequential disagreement. Large flat fields did not work.

## Per-case training performance

| Case | PRIOR F1 | Best F1 | Oracle F1 | Best path |
|---|---:|---:|---:|---|
| axios-4731 | 0.000000 | 0.000000 | 0.011628 | callers / defined_in / defines |
| axios-5085 | 0.000000 | 0.189474 | 0.208333 | defined_in / defines / callers / defined_in / imports / defines |
| immutable-2005 | 0.089503 | 0.159915 | 0.168700 | callers / calls |
| immutable-2006 | 0.198813 | 0.224969 | 0.328438 | calls |
| preact-2757 | 0.000000 | 0.178273 | 0.201560 | defined_in / imported_by / defines / calls / calls |
| preact-2896 | 0.050955 | 0.379666 | 0.825499 | callers / callers / calls / callers / callers / calls / callers |
| preact-3010 | 0.000000 | 0.000000 | 0.000000 | defined_in / defines |
| preact-3454 | 0.402640 | 0.530435 | 0.572770 | defined_in / imported_by / defines / calls / calls |
| preact-3562 | 0.016694 | 0.016694 | 0.325517 | defined_in / defines |
| preact-3689 | 0.069498 | 0.137931 | 0.428571 | defined_in / defines / calls |
| preact-3739 | 0.000000 | 0.350943 | 0.502439 | defined_in / imports / defines / calls / callers / calls / calls |
| preact-3763 | 0.000000 | 0.000000 | 0.166320 | calls / callers / calls / defined_in / defines |
| preact-4152 | 0.000000 | 0.000000 | 0.000000 | defined_in / defines / calls / callers |
| preact-4182 | 0.049296 | 0.051429 | 0.329177 | defined_in / defines / calls / defined_in / defines / calls |
| preact-4436 | 0.000000 | 0.803506 | 0.803506 | defined_in / imported_by / defines |

## Secondary metrics

Best iteration 013 records:

```text
weighted core coverage   0.122910
noise-region rate        0.493333
nDCG@100                 0.547826
mean calls/case          51.133
```

Relative to v1, it improves precision, recall, F1, HitFile, context
efficiency, weighted coverage, noise rate, and nDCG. Its one regression versus
iteration 012 is a small recall/weighted-coverage tradeoff caused by accepting
a more precise deep frontier.

## Inference and retained evidence

| Policy | Calls | Input tokens | Output tokens | Provider cost |
|---|---:|---:|---:|---:|
| Jev v1 | 78 | 98,358 | 3,503 | $0.004131 |
| Best iteration 013 | 767 | 2,304,931 | 156,417 | $0.096807 |

The goal explicitly optimized quality before inference count. Every model
observation has a protocol-specific retained identity. Iteration 013's 536 new
observations and all nested expert observations replay with zero network
capability and reproduce the same paths/rankings. A production compression
pass could later reduce calls, but was not allowed to change this result.

## Remaining oracle gap

Aggregate residual F1 is `0.123282`. Most remaining loss is concentrated in:

- Preact 2896: `0.379666` vs `0.825499`;
- Preact 3562: `0.016694` vs `0.325517`;
- Preact 3689: `0.137931` vs `0.428571`;
- Preact 4182: `0.051429` vs `0.329177`;
- Preact 3763: `0` vs `0.166320`.

The learned-template experiments prove that this gap is not simply eliminated
by placing the oracle terminal frontier in the choice set. Recognition and
decision organization remain limiting.

## Iteration history

| Iter | Policy | F1 | Headroom | Disposition |
|---:|---|---:|---:|---|
| 000 | frozen v1 | 0.078887 | 7.66% | baseline |
| 001 | one-shot macro terminal preview | 0.063789 | 1.99% | reject |
| 002 | macro rank + stop | 0.091550 | 12.41% | promote |
| 003 | forced first macro | 0.144274 | 32.21% | promote |
| 004 | exact-revisit pruning on classic path | 0.144274 | 32.21% | tie/reject |
| 005 | width-two root beam | 0.117612 | 22.20% | reject |
| 006 | parent delta | 0.123474 | 24.40% | reject |
| 007 | retrospective checkpoint | 0.144274 | 32.21% | tie/reject |
| 008 | pairwise root tournament | 0.089326 | 11.58% | reject |
| 009 | hierarchical one-rollout planning | 0.157611 | 37.21% | promote |
| 010 | selected-plan checkpoints | 0.157079 | 37.02% | reject/Pareto |
| 011 | complementary expert selector | 0.170048 | 41.88% | promote |
| 012 | revisit-pruned planner portfolio | 0.193444 | 50.67% | promote |
| **013** | **two-rollout deep planner portfolio** | **0.201549** | **53.71%** | **best** |
| 014 | delta-aware expert selector | 0.191951 | 50.11% | reject |
| 015 | flat learned route templates | 0.075687 | 6.46% | reject |
| 016 | pairwise learned-template tournament | 0.121302 | 23.58% | reject/Pareto efficiency |

## Failed approaches and what they taught

- Absolute parent/child delta alone did not improve selection.
- A wider root beam passed through useful states and often selected worse
  endpoints.
- Pairwise voting over raw root macros used many calls and regressed.
- Retrospective stopping and exact pruning on the classic path tied the prior
  best rather than improving it.
- Exclusive-symbol delta improved one residual but induced novelty bias and
  lost several established winners.
- A flat learned library containing every development oracle route collapsed
  toward the semantic prior and scored below v1.
- A pairwise tournament made that same library usable on some cases (including
  exact oracle on Preact 2757) but remained preference/bracket sensitive.

These three final, materially different failures establish the plateau rather
than treating one negative prompt as decisive.

## Exact checkpoints and artifacts

- best scientific checkpoint/change ID: `uzsxzwwl`
- best commit ID: `df2b8dd7`
- best protocol: `attune-jev-policy-hillclimb-013-deep-planner-portfolio-v1`
- best outcomes SHA-256:
  `1f28035240fd0b043ce850ca6da7acd680b277b21d83f475c0b655e5420aa96e`
- best evaluation SHA-256:
  `52887d15badd682bbacfe137da9e834c3323ed9c4d58d4d08355e72dcdcd2351`
- every evaluated iteration has its own retained evidence, Markdown report,
  machine-readable metrics, and Jujutsu checkpoint.

## Verification

Every acquisition and replay gate completed all fifteen cases. Normal Flix
tests preceding the repository-scale heavyweight parity check remained green,
including Datalog/physical parity, effect/replay laws, compiled-program laws,
and native boundary tests.

Final canonical verification was run as:

```text
nix develop -c ./verify
```

Result:

```text
native Grit boundary tests     PASS
native Nix boundary tests      PASS
Flix tests                     48 passed, 0 failed, 0 skipped
Axios 2,463-policy parity      exact
compiled evaluator p50        3.498 ms
legacy evaluator p50          16.397 ms
measured speedup               4.69x on the concurrently loaded host
```

No embedding or Jev network acquisition was enabled during verification.

## Plateau conclusion

The hill climb improved substantially, then plateaued. Iteration 013 is the
best aggregate-F1 policy. The final experiments show that the next bottleneck
is not merely route coverage, prompt wording, or flat-vs-binary presentation;
it is learning a calibrated issue-conditioned value function over structural
frontiers without relying on case-keyed gold.

## Next untouched validation experiment

Freeze iteration 013 exactly and evaluate it on an untouched SWE-Explore
population with the same repositories/snapshot machinery and no policy edits.
Primary outcome: aggregate official line F1 and structural-headroom capture.
Also preregister calls/cost and per-repository breakdown. Do not use the new
cases to tune the policy until their validation result is frozen.
