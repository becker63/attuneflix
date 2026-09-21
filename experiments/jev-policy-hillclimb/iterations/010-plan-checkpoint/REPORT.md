# Iteration 010 — Checkpoint the selected short plan

## Hypothesis

Iteration 009's hierarchy exposes useful basins but executes its selected plan
atomically. Some regressions may come from passing through a better
Symbol-ending state on the way to the plan terminal. A single checkpoint choice
over that fixed plan should preserve the planning gain while repairing those
overshoots.

## Change from previous best

Replay iteration 009's exact rollout and root-plan observations, holding the
selected plan fixed. Before ordinary downstream navigation, show every
Symbol-ending prefix of that plan (plus root) in one new Jev checkpoint choice.
Resume iteration 009's ordinary rank/stop policy from the selected checkpoint.

## Why this might recover oracle headroom

Iteration 009 improves three cases dramatically but regresses four. Several
regressed paths contain plausible shorter Symbol frontiers, while the frozen
diagnosis records many failure-to-stop events. This isolates atomic plan
execution from plan generation.

## Runtime information available to the policy

Issue text, frozen semantic prior, the exact iteration-009 selected plan, and
ordinary top-eight previews for its Symbol-ending prefixes.

## Runtime information explicitly unavailable

Gold, official metrics, oracle paths/values, unselected branches, benchmark
identifiers, repository-specific exceptions, and future outcomes.

## Primary metric

Aggregate official line F1 over the frozen fifteen-case development set.

## Expected failure mode

Iteration 009's regressions may come from choosing the wrong plan rather than
overshooting within it. The checkpoint model may also select the same terminal
every time, reproducing iteration 009 with one extra call.

## Result

| Condition | Precision | Recall | F1 | HitFile | Context efficiency |
|---|---:|---:|---:|---:|---:|
| PRIOR | 0.286862 | 0.075187 | 0.058493 | 0.227778 | 0.407990 |
| Jev v1 | 0.196199 | 0.093466 | 0.078887 | 0.205556 | 0.267742 |
| Best (009) | 0.374584 | 0.154339 | **0.157611** | 0.318889 | 0.455570 |
| Iteration 010 | 0.389456 | 0.153884 | 0.157079 | **0.352222** | **0.503680** |
| STRUCTURAL ORACLE | 0.640725 | 0.295496 | 0.324831 | 0.410000 | 0.735848 |

Iteration 010 is a near-tie F1 regression but a Pareto candidate: it has the
best HitFile, precision, context efficiency, and noise rate of any learned
policy so far.

## Headroom capture

`37.0152%`, versus `37.2149%` for iteration 009.

## Secondary metrics

Weighted core coverage `0.128781`, noise-region rate `0.506667`, and nDCG@100
`0.551366`. Compared with iteration 009, HitFile rises by `0.033333` and context
efficiency by `0.048110`, while weighted coverage and nDCG fall.

## Per-case results

Thirteen cases are identical to iteration 009. Preact 4182 improves from
`0.025229` to `0.051429`; Preact 3689 falls from `0.102752` to `0.068571`.
Complete metrics are in `metrics.json`.

## Decision depth / model-call statistics

379 total calls (25.267/case): the exact iteration-009 planning observations,
15 new checkpoint calls, and only those downstream calls induced by the chosen
checkpoint.

## Oracle regret analysis

Residual F1 is `0.167752`. The checkpoint does not touch the largest misses:
Preact 3739 remains zero against `0.502439`, and Preact 2896 remains `0.379666`
against `0.825499`.

## Cases improved

Preact 4182 (`+0.026199` over iteration 009).

## Cases regressed

Preact 3689 (`-0.034181` over iteration 009).

## Interesting trajectories

The checkpoint selected the plan terminal in nearly every case. Its only
material path changes trade one moderate improvement for one larger regression.
The dominant 009 failures therefore originate in plan generation/selection,
not atomic execution through a better visible prefix.

## Provider cost / observations

The evaluated policy contains 379 observations and historical usage of
1,198,180 input tokens, 94,023 output tokens, and `$0.050323560`. Exactly 15
checkpoint observations are new to this iteration; planning is replayed.

## Interpretation

Checkpointing is not an F1 improvement, but it exposes a legitimate Pareto
tradeoff: better file hit rate and much cleaner context at essentially equal
F1. The primary hill climb remains iteration 009 because F1 is frozen as the
objective.

## Promote or reject

Reject for the primary objective; retain as a Pareto candidate. Iteration 009
remains best.

## Next hypothesis

Replay both complementary policies 003 and 009 and ask one final Jev call to
choose between their terminal frontiers. Their per-case gains differ, so a
deployable two-expert selector can improve only if the final previews reveal
which policy succeeded.

## Reproducibility

- Jujutsu change ID: `kvlkzuzy`
- protocol: `attune-jev-policy-hillclimb-010-plan-checkpoint-v1`
- planning replay protocol: `attune-jev-policy-hillclimb-009-hierarchical-lookahead-v1`
- model: `typesafe/jev-1.13`
- frozen machine and official scorer unchanged
- outcomes SHA-256: `4aa77dd71fb1611f418336fbf7670e03d53c08907f95e983e53bb1c3af368666`
- evaluation SHA-256: `b82e169e1efd94ae90ebbcd6fb4453d224be8361a0e6ffc4bc6ef052b8e10b85`
- acquisition verification: 48 passed, 0 failed
- exact replay verification: 15 new checkpoint observations plus retained 009
  planning/downstream observations, zero network capability, identical
  paths/rankings, 48 passed, 0 failed
