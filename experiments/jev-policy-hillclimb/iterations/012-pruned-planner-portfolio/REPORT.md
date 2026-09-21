# Iteration 012 — Exact-revisit-pruned planner portfolio

## Hypothesis

The hierarchical planner wastes branch-local rollout choices on continuations
whose terminal state exactly revisits its input or an earlier prefix state.
Removing those structurally unproductive plans should expose a different
candidate under roots currently captured by the same-file attractor, while the
iteration-003 expert and terminal arbitration protect cases where the original
planner was already strong.

## Change from previous best

Recompute iteration 009's hierarchical planning with one generic filter: a
rollout continuation is excluded when its terminal semantic state equals the
root input or any state on that root continuation's prefix. Keep the complete
structural language, terminal previews, questions, downstream macro policy,
iteration-003 expert, and final two-expert selector otherwise unchanged.

## Why this might recover oracle headroom

The diagnosis found state-idempotent `defined_in -> defines` behavior, and the
largest iteration-011 miss (Preact 3739) gives both experts that same terminal
frontier. Exact state recurrence is available at deployment and indicates that
a continuation contributes no new frontier at its endpoint.

## Runtime information available to the policy

Issue text, frozen semantic prior, structural states, exact equality between a
candidate terminal state and ancestor states, valid continuations, and ordinary
top-eight previews.

## Runtime information explicitly unavailable

Gold, official metrics, oracle paths/values, benchmark identifiers,
repository-specific exceptions, and action-name-specific penalties.

## Primary metric

Aggregate official line F1 over the frozen fifteen-case development set.

## Expected failure mode

Same-file expansion often changes the state by adding symbols and therefore is
not an exact recurrence. The filter may remove few or no consequential plans,
or may remove a revisiting route whose later continuation would have escaped
into a useful basin.

## Result

| Condition | Precision | Recall | F1 | HitFile | Context efficiency |
|---|---:|---:|---:|---:|---:|
| PRIOR | 0.286862 | 0.075187 | 0.058493 | 0.227778 | 0.407990 |
| Jev v1 | 0.196199 | 0.093466 | 0.078887 | 0.205556 | 0.267742 |
| Previous best (011) | 0.407026 | 0.158742 | 0.170048 | 0.318889 | 0.479399 |
| Iteration 012 | **0.432332** | **0.180496** | **0.193444** | **0.341111** | **0.504705** |
| STRUCTURAL ORACLE | 0.640725 | 0.295496 | 0.324831 | 0.410000 | 0.735848 |

Iteration 012 is the new best on every headline metric and crosses the
preregistered fifty-percent structural-headroom landmark.

## Headroom capture

`50.6692%`, up from `41.8848%` for iteration 011 and `7.6572%` for frozen v1.

## Secondary metrics

Weighted core coverage is `0.152987`, noise-region rate is `0.520000`, and
nDCG@100 is `0.481159`. The improvement therefore adds useful coverage while
also reducing noise relative to the previous best.

## Per-case results

Preact 3739 moves from F1 `0` to `0.350943` (oracle `0.502439`) and HitFile
from `0` to `0.333333`. Every other case ties iteration 011 on official F1.
The selected path changes from the two-step same-file frontier to:

```text
defined_in -> imports -> defines -> calls -> callers -> calls -> calls
```

Full per-case metrics are retained in `metrics.json`.

## Decision depth / model-call statistics

The composite policy uses 331 decisions (22.067/case), fewer than iteration
011's 384 despite computing a new planner. It accounts for 1,097,695 input
tokens, 75,223 output tokens, and `$0.046103190` from scratch. This iteration
acquired 314 new observations; the unchanged classic expert contributed 17
replayed observations on the realized paths.

## Oracle regret analysis

Residual aggregate F1 falls to `0.131386`. Preact 2896 is now the largest
absolute gap (`0.379666` vs `0.825499`), followed by Preact 3562 (`0.016694`
vs `0.325517`), Preact 3689 (`0.137931` vs `0.428571`), and Preact 4182
(`0.051429` vs `0.329177`). Preact 3739 retains only `0.151496` F1 residual.

## Cases improved

Preact 3739 improves by `+0.350943` F1. No other case changes official F1.

## Cases regressed

None relative to iteration 011.

## Interesting trajectories

The exact-revisit filter changes internal planning and call count on many
cases, but terminal arbitration preserves the iteration-011 winner everywhere
except Preact 3739. On that case it prevents the shared same-file endpoint from
dominating and exposes a route with both import and call propagation. This is
the clearest causal success in the hill climb so far: a generic process-local
state law changes one major miss without introducing any regression.

## Provider cost / observations

314 new retained observations cost `$0.045173646`. Exact replay reproduced all
fifteen paths and admitted observations with zero network capability. As in
iteration 011, whole outcomes bytes include measured precompute nanoseconds;
the official evaluation artifact is stable.

## Interpretation

Exact recurrence was not merely incidental. It actively hid a high-value
basin from hierarchical planning in the largest complete miss. The improvement
also validates the portfolio architecture: pruning may perturb many planner
choices, while the unchanged classic expert plus terminal selector prevents
those perturbations from becoming regressions.

The remaining large gaps are no longer dominated by one obvious attractor.
They require a broader candidate-generation strategy capable of offering
routes absent from both the classic and single-rollout planner.

## Promote or reject

Promote. Iteration 012 is the new best.

## Next hypothesis

Add a third, structurally diverse expert that directly ranks complete
three-step root continuations and then continues with revisit-pruned planning,
then retain the same neutral terminal selector. The objective is not another
vote over identical endpoints; it is to increase candidate coverage on Preact
2896/3562/3689/4182 while preserving 012 through terminal arbitration.

## Reproducibility

- Jujutsu change ID: `lmsputpq`
- protocol: `attune-jev-policy-hillclimb-012-pruned-planner-portfolio-v1`
- model: `typesafe/jev-1.13`
- iteration-003 expert replays exactly; the modified planner and terminal
  selector use a new retained observation namespace
- replay outcomes SHA-256: `d3577f51fd28a6b1584629dd714b17d720977bc553c5f67518b2d8cf4362f41d`
- evaluation SHA-256: `745c2856005d84031fcf8da4e70b908fb1ce10d383e724ec7659d33a5ebc3485`
- acquisition gate: all 15 cases completed; all preceding ordinary tests
  passed before the unrelated heavyweight parity test began
- exact replay gate: 314 retained observations replayed with zero network
  capability and identical semantic paths/rankings
