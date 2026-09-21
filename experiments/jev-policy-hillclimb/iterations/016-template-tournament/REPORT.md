# Iteration 016 — Learned-template pairwise tournament

## Hypothesis

Iteration 015 failed despite complete development-set route coverage because a
flat 14--15-way choice drove Jev toward the familiar semantic prior. Balanced
binary elimination over the exact same learned template frontiers should make
local comparisons tractable. A final binary comparison against the replayed
iteration-013 expert should preserve the established online search when the
tournament winner is unconvincing.

## Change from previous best

Hold the twelve learned route templates, root alternative, states, previews,
and replayed iteration-013 expert fixed. Replace the single multiclass template
choice with a stable balanced pairwise tournament over root plus templates,
then compare its winner against iteration 013 in one final binary decision.

## Why this might recover oracle headroom

The oracle state is in the template field by construction, but 015 proves that
Jev cannot rank the whole field at once. Binary elimination turns the same
problem into repeated concrete contrasts and tests decision structure without
changing candidate coverage.

## Runtime information available to the policy

Issue text, frozen semantic prior, exactly two terminal paths/previews per
tournament decision, tournament history through the surviving frontier, and
the final replayed search-expert comparison.

## Runtime information explicitly unavailable

Current-case gold, official metrics, oracle values, oracle-selected path label,
benchmark instance/repository identity, and case-keyed route lookup.

## Primary metric

Aggregate official line F1 over the frozen fifteen-case development set.

## Expected failure mode

Pairwise choices may be intransitive or sensitive to the fixed bracket order.
A strong template can be eliminated before meeting a weaker but more
semantically familiar candidate, and the final comparison can still reject a
good tournament winner.

## Result

| Condition | Precision | Recall | F1 | HitFile | Context efficiency |
|---|---:|---:|---:|---:|---:|
| PRIOR | 0.286862 | 0.075187 | 0.058493 | 0.227778 | 0.407990 |
| Jev v1 | 0.196199 | 0.093466 | 0.078887 | 0.205556 | 0.267742 |
| Best (013) | **0.458034** | **0.179653** | **0.201549** | **0.341111** | 0.524766 |
| Flat templates (015) | 0.356045 | 0.084918 | 0.075687 | 0.227778 | 0.476153 |
| Iteration 016 | 0.384050 | 0.111765 | 0.121302 | 0.338889 | **0.564661** |
| STRUCTURAL ORACLE | 0.640725 | 0.295496 | 0.324831 | 0.410000 | 0.735848 |

Pairwise structure substantially improves over flat template selection but
does not approach the best online planner on aggregate F1.

## Headroom capture

`23.5823%`, versus `6.4556%` for flat templates and `53.7122%` for iteration
013.

## Secondary metrics

Weighted core coverage is `0.119384`, noise-region rate is `0.493333`, and
nDCG@100 is `0.505540`. Context efficiency is the best observed in the entire
hill climb, but recall and F1 remain much lower than iteration 013.

## Per-case results

The tournament selects the exact oracle route for Preact 2757 (`0.201560`) and
retains iteration 013's near-oracle Preact 3454 (`0.530435`). It also retains
Axios 5085, Immutable 2006, Preact 2896, and Preact 3689. It loses the strong
iteration-013 outcomes for Immutable 2005, Preact 3739, Preact 4182, and the
exact-oracle Preact 4436 result.

## Decision depth / model-call statistics

The composite policy contains 962 decisions (64.133/case), 2,554,483 input
tokens, 169,180 output tokens, and `$0.107288286` from scratch. The tournament
and final comparisons add 195 observations, 249,552 input tokens, 12,763 output
tokens, and `$0.010481184`.

## Oracle regret analysis

Residual aggregate F1 is `0.203529`. Binary structure recovers one exact oracle
template, demonstrating that the candidate library is usable, but bracket-local
mistakes eliminate most case-optimal templates. The failure is now recognition
and comparison consistency, not candidate availability.

## Cases improved

Relative to flat iteration 015, Preact 2757, 2896, 3454, and several smaller
cases. Relative to best iteration 013, only Preact 2757 improves.

## Cases regressed

Relative to iteration 013: Immutable 2005, Preact 3739, Preact 4182, and Preact
4436 materially regress.

## Interesting trajectories

Preact 2757 reaches its exact oracle through the globally learned template
`defined_in -> imports -> imported_by -> defines`, proving that hierarchical
selection can unlock a template that flat selection ignored. Yet Preact 4436
still chooses root despite its three-step exact oracle template being in the
same field. Pairwise comparisons are therefore highly path/bracket dependent.

## Provider cost / observations

195 new retained observations cost `$0.010481184`. Exact replay reproduced all
paths and admitted observations with zero network capability.

## Interpretation

Hierarchy fixes flat overload but not the underlying issue-conditioned value
judgment. A complete trained route vocabulary is not enough: Jev's pairwise
preferences are inconsistent and lose high-value candidates. Further prompt
or bracket tuning on these fifteen cases would be increasingly likely to
overfit without teaching a new mechanism.

## Promote or reject

Reject on primary F1. Retain as the highest-context-efficiency Pareto result.
Best remains iteration 013.

## Next hypothesis

The search has plateaued across absolute-vs-delta arbitration, complete flat
template selection, and hierarchical template selection. The clean next
experiment is untouched validation of iteration 013, not another development-
set prompt mutation. If policy learning resumes later, use held-out splits to
train a calibrated deployment-feature scorer rather than tuning tournament
order on these same cases.

## Reproducibility

- Jujutsu change ID: `vxmppmrr`
- protocol: `attune-jev-policy-hillclimb-016-template-tournament-v1`
- model: `typesafe/jev-1.13`
- learned templates are byte-identical to iteration 015's training artifact
- iteration 013 replays exactly; tournament/final calls use a new store
- replay outcomes SHA-256: `cbacce8ba332566c02e8f7f603be789d88873a8f5b55215f0a21b9dee47c23a1`
- evaluation SHA-256: `08138ede9cf092e1d7c28ea83f85d643156fb2b41e12ff06c4edde705f748203`
- exact replay: 195 tournament/final observations and the replayed search
  expert ran with zero network capability and reproduced identical semantics
