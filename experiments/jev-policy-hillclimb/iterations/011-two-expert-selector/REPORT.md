# Iteration 011 — Two-expert terminal selector

## Hypothesis

Iterations 003 and 009 are complementary honest policies: iteration 003's
forced first macro avoids some rollout errors, while iteration 009's
hierarchical root planning discovers useful basins that 003 misses. A single
final Jev comparison of their terminal frontiers may retain their respective
strengths better than either generator alone.

## Change from previous best

Replay the exact frozen iteration-003 and iteration-009 policies. If their
paths differ, present their two final structural frontiers as neutrally named
Expert A and Expert B and ask Jev to select one. If they agree, return the
shared result without a new call. No upstream decision is changed or
reacquired.

## Why this might recover oracle headroom

Iteration 009 materially improves Axios 5085, Immutable 2005, and Preact 2757,
while iteration 003 remains better on Preact 3454, Immutable 2006, Preact 3689,
and Preact 4182. The final selector sees the concrete deployment-visible
consequences of both distinct planning strategies rather than committing to a
single strategy before structural evaluation.

## Runtime information available to the policy

Issue text, frozen semantic prior, the two exact terminal paths, and the two
ordinary top-eight terminal previews with cardinalities.

## Runtime information explicitly unavailable

Gold, official metrics, oracle paths/values, benchmark identifiers,
repository-specific exceptions, and knowledge of which expert won on any
case. Expert labels carry no quality ordering.

## Primary metric

Aggregate official line F1 over the frozen fifteen-case development set.

## Expected failure mode

The terminal preview may still omit the evidence needed to distinguish the
better frontier. The two experts also agree on many cases, bounding the
possible gain, and a new comparison can select the worse member of a
complementary pair.

## Result

| Condition | Precision | Recall | F1 | HitFile | Context efficiency |
|---|---:|---:|---:|---:|---:|
| PRIOR | 0.286862 | 0.075187 | 0.058493 | 0.227778 | 0.407990 |
| Jev v1 | 0.196199 | 0.093466 | 0.078887 | 0.205556 | 0.267742 |
| Previous best (009) | 0.374584 | 0.154339 | 0.157611 | 0.318889 | 0.455570 |
| Iteration 011 | **0.407026** | **0.158742** | **0.170048** | 0.318889 | **0.479399** |
| STRUCTURAL ORACLE | 0.640725 | 0.295496 | 0.324831 | 0.410000 | 0.735848 |

Iteration 011 is the new best on the primary metric. It improves precision,
recall, F1, context efficiency, weighted core coverage, and noise over the
previous best while tying its HitFile result.

## Headroom capture

`41.8848%`, up from `37.2149%` for iteration 009 and `7.6572%` for frozen v1.

## Secondary metrics

Weighted core coverage is `0.146883`, noise-region rate is `0.546667`, and
nDCG@100 is `0.481159`. nDCG regresses from iteration 009 despite improved
official F1, showing that the selected compact frontiers can improve line
quality without preserving prior ordering quality.

## Per-case results

The selector chose the better expert on every case where 003 and 009 had
different official F1. In particular it retained 009's Axios 5085
(`0.189474`), Immutable 2005 (`0.159915`), and Preact 2757 (`0.184497`), while
recovering 003's Immutable 2006 (`0.224969`), Preact 3454 (`0.402640`), Preact
3689 (`0.137931`), and Preact 4182 (`0.051429`). Both experts agree on the
other cases. Thus this deployable selector exactly realizes the post-hoc
per-case maximum of its two inputs on this development set without seeing
gold.

## Decision depth / model-call statistics

The complete composite policy contains 384 decisions (25.6/case), of which
371 are exact replays from the two frozen experts and 13 are new terminal
comparisons. A from-scratch equivalent accounts for 1,201,959 input tokens,
90,722 output tokens, and `$0.050482278`; this iteration itself acquired only
16,964 input tokens, 698 output tokens, and `$0.000712488`.

## Oracle regret analysis

Residual aggregate F1 is `0.154783`. The dominant misses are unchanged:
Preact 3739 remains `0` against oracle `0.502439`, Preact 2896 remains
`0.379666` against `0.825499`, and Preact 3562 remains `0.016694` against
`0.325517`. The portfolio successfully resolves strategy-level regressions,
but cannot recover routes absent from both experts.

## Cases improved

Relative to iteration 009: Immutable 2006, Preact 3454, Preact 3689, and
Preact 4182. All other cases tie.

## Cases regressed

None relative to iteration 009, and none relative to PRIOR.

## Interesting trajectories

The final comparison correctly selected a one-action `calls` frontier over the
hierarchical alternative for Immutable 2006 and the six-action hierarchical
frontier for Axios 5085. It also retained the exact-oracle
`defined_in -> imported_by -> defines` route for Preact 4436. Conversely, both
experts propose `defined_in -> defines` for Preact 3739, so the selector has no
useful option to choose.

## Provider cost / observations

Thirteen new retained observations cost `$0.000712488`. Exact replay reproduced
all fifteen paths, rankings, and admitted observations with no API key/network
capability. The raw outcomes artifact includes measured precompute nanoseconds,
so its whole-file hash is expected to change between executions; the official
evaluation artifact remained exact.

## Interpretation

Terminal consequence comparison is reliable enough to combine genuinely
complementary search procedures: on this set Jev selected the higher-F1
frontier in every consequential disagreement. The remaining gap is therefore
not portfolio arbitration. It is candidate generation: the largest misses are
shared by both experts and require exposing a qualitatively different route.

## Promote or reject

Promote. Iteration 011 is the new best.

## Next hypothesis

Apply generic exact-revisit/no-op pruning inside iteration 009's branch-local
rollout generation before composing it with iteration 003. Iteration 004
showed that pruning does not help the classic expert alone, but the planner's
largest miss (Preact 3739) is caused by both experts presenting the same
same-file attractor. Pruning at plan generation changes candidate generation
rather than final arbitration while using only deployment-visible state
identity.

## Reproducibility

- Jujutsu change ID: `oqqkvynm`
- protocol: `attune-jev-policy-hillclimb-011-two-expert-selector-v1`
- model: `typesafe/jev-1.13`
- exact iteration-003 and iteration-009 observations replayed from their
  retained stores; only the final expert comparison is newly acquired
- replay outcomes SHA-256: `82ebe006e34491db01a28081e20157707ff8a85d453281c04d2da2742de3e52f`
- evaluation SHA-256: `6df08e8716e4703aacbc7755132ac5c296b6b39736ef9477cf0489cf677b3273`
- acquisition gate: hill-climb gate passed for all 15 cases; all preceding
  ordinary tests passed before the unrelated heavyweight parity test began
- exact replay gate: all 13 new decisions plus both retained experts replayed
  without network capability; all semantic paths/rankings were exact (only
  measured precompute nanoseconds differ between whole outcomes files)
