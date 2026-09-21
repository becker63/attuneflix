# Iteration 013 — Two-rollout deep-planner portfolio

## Hypothesis

Iteration 012 fixed one major miss by removing exact recurrence, but its
planner still samples only one branch-local continuation below each root.
Giving each root a second sequential rollout choice should expose deeper,
structurally distinct terminal candidates for the remaining large gaps. A
final comparison against the exact replayed iteration-012 winner should retain
the current best whenever the deeper candidate is worse.

## Change from previous best

Replay iteration 012 exactly as Expert A. Independently generate Expert B by
applying two one-to-three-action branch-local rollout choices under every root
continuation, with the same exact-ancestor-revisit pruning after each choice,
then choose one resulting plan and finish with the established macro
rank/binary-stop policy. Compare the two terminal frontiers once.

## Why this might recover oracle headroom

The diagnosis showed a large jump from two-step to three-step oracle lookahead,
and the remaining misses require routes absent from both previous experts.
Another rollout level increases consequence visibility and route coverage
without changing structural semantics or asking one prompt to compare the
entire 1,643-route family.

## Runtime information available to the policy

Issue text, frozen semantic prior, valid structural continuations, exact
ancestor-state equality, ordinary top-eight previews, action history, and the
two generated terminal frontiers.

## Runtime information explicitly unavailable

Gold, official metrics, oracle paths/values, benchmark identifiers,
repository-specific exceptions, and previous per-case winner labels.

## Primary metric

Aggregate official line F1 over the frozen fifteen-case development set.

## Expected failure mode

Sequential rollout errors may compound, and deeper endpoints may skip useful
intermediate stopping points. The final preview may reject good deep routes or
accept broad noisy ones. The exact 012 fallback bounds only what Jev recognizes,
not the candidate's true quality.

## Result

| Condition | Precision | Recall | F1 | HitFile | Context efficiency |
|---|---:|---:|---:|---:|---:|
| PRIOR | 0.286862 | 0.075187 | 0.058493 | 0.227778 | 0.407990 |
| Jev v1 | 0.196199 | 0.093466 | 0.078887 | 0.205556 | 0.267742 |
| Previous best (012) | 0.432332 | **0.180496** | 0.193444 | 0.341111 | 0.504705 |
| Iteration 013 | **0.458034** | 0.179653 | **0.201549** | 0.341111 | **0.524766** |
| STRUCTURAL ORACLE | 0.640725 | 0.295496 | 0.324831 | 0.410000 | 0.735848 |

Iteration 013 is the new primary best. It trades a small amount of recall and
weighted core coverage for substantially higher precision and context
efficiency, producing a net F1 gain.

## Headroom capture

`53.7122%`, up from `50.6692%` for iteration 012.

## Secondary metrics

Weighted core coverage is `0.122910`, noise-region rate is `0.493333`, and
nDCG@100 is `0.547826`. Precision, efficiency, noise, and nDCG improve; recall
and weighted coverage regress slightly. This is a real quality tradeoff rather
than uniform dominance.

## Per-case results

Preact 3454 improves from `0.402640` to `0.530435`, reaching `92.61%` of its
`0.572770` oracle F1. Preact 2757 regresses from `0.184497` to `0.178273` after
the selector accepts one extra `calls` step. Every other case ties iteration
012. Full per-case metrics are retained in `metrics.json`.

## Decision depth / model-call statistics

The complete composite policy uses 767 decisions (51.133/case), 2,304,931
input tokens, 156,417 output tokens, and `$0.096807102` from scratch. Iteration
013 adds 536 retained observations at `$0.066015516`; the remaining decisions
come from replayed iteration 012.

## Oracle regret analysis

Residual aggregate F1 is `0.123282`. Preact 2896 remains the largest gap
(`0.379666` vs `0.825499`), followed by Preact 3562 (`0.016694` vs `0.325517`),
Preact 3689 (`0.137931` vs `0.428571`), and Preact 4182 (`0.051429` vs
`0.329177`). The deeper expert materially narrows Preact 3454 but does not
offer selected improvements for the four dominant residuals.

## Cases improved

Preact 3454 improves by `+0.127795` F1.

## Cases regressed

Preact 2757 regresses by `-0.006224` F1.

## Interesting trajectories

For Preact 3454, the selector replaces the broad two-step same-file frontier
with:

```text
defined_in -> imported_by -> defines -> calls -> calls
```

That route nearly reaches oracle despite differing from the oracle's longer
suffix. For Preact 2757, the same additional call expansion slightly overshoots
the stronger four-step frontier. Terminal arbitration is therefore good but
not perfect once candidate differences become more subtle.

## Provider cost / observations

536 new observations cost `$0.066015516`. Exact replay reproduced all paths,
rankings, and admitted model observations with zero network capability.

## Interpretation

A second rollout level adds useful route coverage, confirming that planning
horizon remains causal. Its gain is concentrated in one case and requires
roughly 2.3x the calls of iteration 012, while one arbitration error appears.
The next improvement should target final comparison reliability or introduce a
qualitatively different candidate for the four unchanged dominant gaps rather
than simply adding a third rollout everywhere.

## Promote or reject

Promote on aggregate F1. Retain iteration 012 as a cheaper Pareto policy with
slightly higher recall and weighted core coverage.

## Next hypothesis

The 2757 regression shows that absolute terminal previews are insufficient for
fine arbitration. Add only parent-to-candidate delta telemetry to the final
012-vs-deep comparison, keeping both experts and all upstream observations
exact. This isolates whether explicit added/removed prior-ranked evidence can
preserve 013's Preact 3454 gain without accepting its Preact 2757 overshoot.

## Reproducibility

- Jujutsu change ID: `uzsxzwwl`
- protocol: `attune-jev-policy-hillclimb-013-deep-planner-portfolio-v1`
- model: `typesafe/jev-1.13`
- iteration 012 is replayed from its frozen observation store; all deep-planner
  and final-comparison observations have a new identity
- replay outcomes SHA-256: `1f28035240fd0b043ce850ca6da7acd680b277b21d83f475c0b655e5420aa96e`
- evaluation SHA-256: `52887d15badd682bbacfe137da9e834c3323ed9c4d58d4d08355e72dcdcd2351`
- acquisition gate: all 15 cases completed; all preceding ordinary tests
  passed before the unrelated heavyweight parity test began
- exact replay gate: 536 new observations plus iteration 012 replayed with
  zero network capability and identical semantic paths/rankings
