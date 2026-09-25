# Iteration 015 — Learned global route templates

## Hypothesis

The remaining gap is primarily candidate coverage. A tiny global vocabulary of
route shapes learned from oracle-labelled development decisions may expose
high-value structural basins that the online greedy/hierarchical generators do
not reach. Because route shapes are repository-agnostic policy parameters, the
same learned library can be evaluated uniformly for every future issue.

## Change from previous best

Freeze the twelve unique non-root oracle paths observed across the fifteen
development cases as a global template library. For every case, evaluate every
template using only the frozen structural world. Ask Jev once to choose among:

- the exact replayed iteration-013 winner;
- the unchanged semantic-prior/root state;
- every distinct learned-template terminal state.

No case or repository identity participates in candidate construction or
selection.

## Why this might recover oracle headroom

Every positive-headroom development oracle is reachable through this compact
library by construction, while the selector still receives only information
available at deployment. This cleanly tests whether the primary bottleneck is
online route generation or Jev's ability to recognize a strong terminal
frontier once it is explicitly presented.

## Runtime information available to the policy

Issue text, frozen semantic prior, current best terminal frontier, twelve
global route-template terminal frontiers, their structural paths, ordinary
top-eight previews, and the prior/root alternative.

## Runtime information explicitly unavailable

Current-case gold, official metrics, oracle values, oracle-selected path label,
benchmark instance/repository identity, and any case-keyed lookup. Oracle paths
from the full development set are used only as globally shared trained policy
parameters.

## Primary metric

Aggregate official line F1 over the frozen fifteen-case development set.

## Expected failure mode

This is an optimistic training-set coverage experiment. Jev may still fail to
distinguish the oracle terminal state from plausible alternatives, especially
when top-eight previews omit useful gold. The template library may also encode
route shapes that do not generalize beyond these repositories.

## Result

| Condition | Precision | Recall | F1 | HitFile | Context efficiency |
|---|---:|---:|---:|---:|---:|
| PRIOR | 0.286862 | 0.075187 | 0.058493 | 0.227778 | 0.407990 |
| Jev v1 | 0.196199 | 0.093466 | 0.078887 | 0.205556 | 0.267742 |
| Best (013) | **0.458034** | **0.179653** | **0.201549** | **0.341111** | **0.524766** |
| Iteration 015 | 0.356045 | 0.084918 | 0.075687 | 0.227778 | 0.476153 |
| STRUCTURAL ORACLE | 0.640725 | 0.295496 | 0.324831 | 0.410000 | 0.735848 |

Iteration 015 is worse than Jev v1 on aggregate F1 despite containing every
positive-headroom development oracle route as a candidate.

## Headroom capture

`6.4556%`, below v1's `7.6572%` and far below iteration 013's `53.7122%`.

## Secondary metrics

Weighted core coverage is `0.071370`, noise-region rate is `0.560000`, and
nDCG@100 is `0.438117`. Only context efficiency is respectable; the selector
achieves it mainly by retaining the compact prior rather than finding useful
structural frontiers.

## Per-case results

Jev chooses the semantic-prior/root alternative on nine cases, including
Immutable 2005/2006, Preact 2757/2896/3454/3739/4182/4436. It retains useful
search outcomes only for Axios 5085 and Preact 3689, with several no-headroom
or zero-output ties. The exact oracle route is present for every positive-
headroom case but is never selected as such.

## Decision depth / model-call statistics

The complete composite trace contains 782 decisions (52.133/case), 2,347,915
input tokens, 160,947 output tokens, and `$0.098612430` from scratch. The
template selector itself adds only fifteen calls: 42,984 input tokens, 4,530
output tokens, and `$0.001805328`.

## Oracle regret analysis

Residual aggregate F1 is `0.249144`, almost the entire structural headroom.
The flat selector discards the replayed iteration-013 winner on most of the
cases where it matters. This is not a coverage failure: the best route is
literally among the alternatives by construction.

## Cases improved

Relative to PRIOR, Axios 5085 and Preact 3689. None improve over iteration 013.

## Cases regressed

Most positive-headroom cases regress relative to iteration 013, including the
three largest prior successes Preact 2896, 3739, and 4436.

## Interesting trajectories

The model repeatedly chooses `Stop` even when a near-oracle or exact-oracle
template is displayed. Preact 4436 is the strongest example: its exact oracle
route `defined_in -> imported_by -> defines` is an explicit candidate, yet the
flat chooser returns the zero-F1 prior. This demonstrates that exposing a good
state is insufficient when it is embedded in a large unstructured choice.

## Provider cost / observations

Fifteen new observations cost `$0.001805328`. Exact replay reproduced every
choice/path with zero network capability.

## Interpretation

Flat multiclass overload is a stronger failure than candidate scarcity in this
configuration. The learned vocabulary provides complete development-set route
coverage, but Jev collapses toward the familiar prior. This also explains why
earlier hierarchical planning helped: staged comparisons are not merely a way
to generate candidates; they materially structure a decision that the model
cannot solve as one large ranking problem.

## Promote or reject

Reject decisively. Best remains iteration 013.

## Next hypothesis

Keep the exact same learned template candidates but replace the one 14--15-way
choice with a balanced pairwise tournament, then compare its winner against
the replayed iteration-013 expert. This changes only decision structure and
directly tests whether hierarchical elimination can unlock the complete
candidate coverage that flat selection failed to use.

## Reproducibility

- Jujutsu change ID: `znuvrlun`
- protocol: `attune-jev-policy-hillclimb-015-learned-route-templates-v1`
- model: `typesafe/jev-1.13`
- archived training artifact SHA-256:
  `b3167585ebf97deac33dd56cacd70ae909c9f791f1fae0bd335b69633099fcb8`
  (the exact JSON artifact remains in Jujutsu history; it is not a permanent
  internal scientific format)
- iteration 013 replays exactly; only one template-selection request per case
  receives a new observation identity
- replay outcomes SHA-256: `196b9611959abcd0a12e91b41803fc2963578b38a7ea36af4d1808ec36eea7de`
- evaluation SHA-256: `389664eb9a188e1b3ca2c2a576b073c029314368e2891e005686eabc17da3948`
- exact replay: all 15 template choices and the replayed search expert ran with
  zero network capability and reproduced identical semantic paths/rankings
