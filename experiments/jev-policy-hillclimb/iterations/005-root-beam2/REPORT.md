# Iteration 005 — Width-two root beam

## Hypothesis

Iteration 004 showed that preserving one promising prefix does not prevent
later value loss. Retaining and independently rolling out the top two root
macros should reduce irreversible early commitment and let a final comparison
select a better terminal frontier.

## Change from previous best

Starting from iteration 003 (without iteration 004's no-op pruning), use the
root rank probabilities to retain two macros. Roll each branch out with the
iteration-003 rank/binary-stop policy, then ask Jev to choose between the two
final previews. No cross-branch state or model observation is shared.

## Why this might recover oracle headroom

The diagnosis found most value loss at depth zero or one, and iteration 004's
3739 trajectory showed a good `calls >> callers` prefix can later be lost. A
small beam preserves one alternative without enumerating the whole tree to the
model.

## Runtime information available to the policy

Issue, frozen prior, structural states and previews, Jev root probabilities,
both independently selected branch trajectories, and their final previews.

## Runtime information explicitly unavailable

Gold, official metrics, oracle values/paths, benchmark-specific rules, and
case identity lookup.

## Primary metric

Aggregate official line F1 over the frozen fifteen-case development set.

## Expected failure mode

Jev probabilities were nearly uncorrelated with oracle value in v1; the useful
root branch may not be in the probability top two. The final preview comparison
may also pick the worse rollout, and branch-local greedy decisions can still
destroy both prefixes.

## Result

| Condition | Precision | Recall | F1 | HitFile | Context efficiency |
|---|---:|---:|---:|---:|---:|
| PRIOR | 0.286862 | 0.075187 | 0.058493 | 0.227778 | 0.407990 |
| Jev v1 | 0.196199 | 0.093466 | 0.078887 | 0.205556 | 0.267742 |
| Best (003) | 0.336475 | 0.144047 | 0.144274 | 0.261111 | 0.382407 |
| Iteration 005 | 0.333287 | 0.151232 | 0.117612 | 0.272222 | 0.386456 |
| STRUCTURAL ORACLE | 0.640725 | 0.295496 | 0.324831 | 0.410000 | 0.735848 |

The beam improves recall and HitFile over iteration 003 but loses 18.48% F1.

## Headroom capture

`22.1971%`, below iteration 003's `32.2077%`.

## Secondary metrics

Weighted core coverage `0.124036`, noise-region rate `0.613333`, and nDCG@100
`0.372611`. These tail/ranking metrics improve over iteration 003, but the
primary line-F1 objective regresses.

## Per-case results

Four cases improve over PRIOR. Preact 2896 remains `0.379666`; 4182 improves to
`0.096220`; 4436 reaches `0.482636` but falls well below iteration 003's exact
oracle. Axios 4731 gains a small `0.003922`. Full details are in `metrics.parquet`.

## Decision depth / model-call statistics

127 calls (8.467/case), versus 55 for iteration 003. This includes both branch
rollouts and the final comparison; converged final paths are deterministically
merged before that comparison.

## Oracle regret analysis

Residual F1 is `0.207218`. Relative to iteration 003, the largest avoidable loss
is Preact 4436: the chosen beam extends the exact oracle path with `calls`,
reducing F1 by `0.320870`. Preact 2757 also falls from `0.127774` to zero.

## Cases improved

Axios 4731 and Preact 4182 improve over iteration 003.

## Cases regressed

Preact 4436 and 2757 regress substantially. Immutable 2005 remains below prior.

## Interesting trajectories

Two different root macros sometimes converge to an identical final path; this
is now treated as a beam merge. More importantly, the final model comparison
does not know that an intermediate state was better than the rollout terminal.
For 4436 it selects `defined_in >> imported_by >> defines >> calls`, one step
past the exact oracle state.

## Provider cost / observations

127 observations: 301,616 input tokens, 18,262 output tokens, and
`$0.012667872`.

## Interpretation

Branching improves coverage-like metrics but does not solve selection. The
critical missing capability is not merely preserving multiple root prefixes;
it is recognizing the best stopping point inside a trajectory. Rolling branches
to locally selected terminals can erase the value the beam was meant to save.

## Promote or reject

Reject. Iteration 003 remains best and uses 56.7% fewer calls.

## Next hypothesis

Return to iteration 003 and add parent-to-terminal delta telemetry to each macro
alternative. This directly addresses state-change interpretation without
adding a second search branch or changing the stopping rule.

## Reproducibility

- Jujutsu change ID: `pstwntys`
- protocol: `attune-jev-policy-hillclimb-005-root-beam2-v1`
- model: `typesafe/jev-1.13`
- frozen machine and official scorer unchanged
- outcomes SHA-256: `066ffb3548988c49d39b34fb3b30dad97048bf0ae69c3ec710e3a872412fe9b3`
- evaluation SHA-256: `4e39e940b53f06e407fc66e2fdfeeea0f35021559d42aaacf5b9406258fa861b`
- acquisition verification: 48 passed, 0 failed
- exact replay verification: 127 retained observations, zero network capability,
  identical paths/rankings, 48 passed, 0 failed
