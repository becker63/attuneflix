# Iteration 007 — Retrospective checkpoint selection

## Hypothesis

The best iteration-003 trajectory often visits a useful structural state and
then loses it through a later continuation. One final comparison over the
states already traversed should recover good stopping points without requiring
lookahead, branching, or any new structural computation.

## Change from previous best

Replay iteration 003's exact retained trajectory decisions and therefore hold
its path generation fixed. After it terminates, present every Symbol-ending
prefix on that one path—including the root and terminal state—in one new Jev
choice. Use the selected checkpoint as the final localization frontier.

## Why this might recover oracle headroom

Iteration 005 and 006 both pass through Preact 4436's exact-oracle three-step
state and then continue to worse frontiers. A retrospective checkpoint choice
turns stopping from a sequence of irreversible local decisions into one small
global comparison over evidence the policy has already generated.

## Runtime information available to the policy

Issue text, frozen semantic prior, the exact iteration-003 trajectory, and the
path plus ordinary top-eight preview of every Symbol-ending checkpoint along
that trajectory.

## Runtime information explicitly unavailable

Gold, official metrics, oracle values or paths, unvisited branches, future
outcomes, case identifiers, and repository-specific exceptions.

## Primary metric

Aggregate official line F1 over the frozen fifteen-case development set.

## Expected failure mode

The terminal previews may still be insufficient to distinguish the best
checkpoint, and many iteration-003 paths may never visit a useful basin. This
policy can repair stopping only; it cannot repair a wrong trajectory.

## Result

| Condition | Precision | Recall | F1 | HitFile | Context efficiency |
|---|---:|---:|---:|---:|---:|
| PRIOR | 0.286862 | 0.075187 | 0.058493 | 0.227778 | 0.407990 |
| Jev v1 | 0.196199 | 0.093466 | 0.078887 | 0.205556 | 0.267742 |
| Best (003) | 0.336475 | 0.144047 | 0.144274 | 0.261111 | 0.382407 |
| Iteration 007 | 0.336475 | 0.144047 | 0.144274 | 0.261111 | 0.382407 |
| STRUCTURAL ORACLE | 0.640725 | 0.295496 | 0.324831 | 0.410000 | 0.735848 |

The result is extensionally identical to iteration 003.

## Headroom capture

`32.2077%`, exactly tied with iteration 003.

## Secondary metrics

All secondary metrics are identical to iteration 003: weighted core coverage
`0.104712`, noise-region rate `0.653333`, and nDCG@100 `0.347826`.

## Per-case results

Every case has the same selected path and official score as iteration 003. Full
per-case metrics and all 70 policy observations are in `metrics.parquet`.

## Decision depth / model-call statistics

70 total policy calls (4.667/case): 55 exact replays from iteration 003 plus 15
new final checkpoint comparisons. The evaluated policy therefore adds exactly
one model call per case without changing the underlying trajectory.

## Oracle regret analysis

The final selector chose the existing iteration-003 terminal in all fifteen
cases. None of the earlier Symbol-ending checkpoints on those trajectories was
preferred. Thus the residual `0.180556` F1 gap is not explained by an obviously
better earlier stopping point on the best policy's actual paths.

## Cases improved

None relative to iteration 003.

## Cases regressed

None relative to iteration 003.

## Interesting trajectories

Preact 4436 is an important control: iteration 003 already terminates at
`defined_in >> imported_by >> defines`, its exact structural-oracle path. The
regression seen in iterations 005 and 006 came from those policies generating
different longer trajectories, not from iteration 003 failing to retain its
own best intermediate. Preact 3739's iteration-003 path never enters a useful
basin, so checkpoint selection has nothing to rescue.

## Provider cost / observations

15 new observations: 20,949 input tokens, 804 output tokens, and `$0.000879858`.
Including the 55 replayed trajectory decisions, the evaluated policy contains
70 calls and historical usage of 163,168 input tokens, 10,107 output tokens,
and `$0.006853056`.

## Interpretation

The best policy's stopping behavior is locally self-consistent. Its dominant
residual is upstream: it chooses trajectories that never visit oracle-useful
states. Another stopping representation is unlikely to help without first
improving root/early macro selection.

## Promote or reject

Reject as a strict costlier tie. Iteration 003 remains best.

## Next hypothesis

Replace the single multiclass root decision with pairwise comparison over the
same complete macro set, while keeping the downstream iteration-003 policy.
This tests whether the model can make reliable local comparisons even though
its one-shot probability distribution was uninformative about value-to-go.

## Reproducibility

- Jujutsu change ID: `qtyyurzn`
- protocol: `attune-jev-policy-hillclimb-007-retrospective-checkpoint-v1`
- trajectory protocol: `attune-jev-policy-hillclimb-003-force-first-macro-v1`
- model: `typesafe/jev-1.13`
- frozen machine and official scorer unchanged
- outcomes SHA-256: `9beda5bffeb80a8fd8608548639f9bf903fd8db4fad725b2da89ff061e6141be`
- evaluation SHA-256: `d551368aad205a46a0f33d93285994b787e86c0cf7b5af1c355fbc5dd259a996`
- acquisition verification: 48 passed, 0 failed
- exact replay verification: 15 new checkpoint observations plus 55 reused
  trajectory observations, zero network capability, identical paths/rankings,
  48 passed, 0 failed
