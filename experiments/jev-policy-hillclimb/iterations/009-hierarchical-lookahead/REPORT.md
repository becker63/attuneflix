# Iteration 009 — Hierarchical short-horizon lookahead

## Hypothesis

Root terminal previews remain myopic even when they represent three atomic
actions. Giving every root continuation one separately selected follow-on
continuation should expose whether it leads into a promising basin, allowing a
second-stage root choice to compare short plans rather than isolated states.

## Change from previous best

For each exact iteration-003 root macro, ask Jev to choose its best valid next
one-to-three-action continuation. Collapse duplicate resulting paths, then ask
Jev once to choose among those complete plans and execute the winning plan
atomically. Afterward, use iteration 003's ordinary macro-rank/binary-stop
policy. The structural tree and all candidate semantics remain unchanged.

## Why this might recover oracle headroom

The diagnosis found that three atomic steps contain much more oracle quality
than one or two, but local previews do not reliably expose value-to-go. This
hierarchy lets the root selector see one additional model-selected basin sample
under every root without presenting the entire descendant tree at once.

## Runtime information available to the policy

Issue text, frozen semantic prior, root and child structural states, ordinary
top-eight previews, valid continuations, and the model's own rollout choices.

## Runtime information explicitly unavailable

Gold, official metrics, oracle paths/values, benchmark identifiers,
repository-specific exceptions, and future outcomes.

## Primary metric

Aggregate official line F1 over the frozen fifteen-case development set.

## Expected failure mode

The rollout chooser may select a poor child under a good root, causing the
root-stage comparison to reject that entire basin. Executing a six-action plan
atomically may also skip a better intermediate stopping point.

## Result

| Condition | Precision | Recall | F1 | HitFile | Context efficiency |
|---|---:|---:|---:|---:|---:|
| PRIOR | 0.286862 | 0.075187 | 0.058493 | 0.227778 | 0.407990 |
| Jev v1 | 0.196199 | 0.093466 | 0.078887 | 0.205556 | 0.267742 |
| Previous best (003) | 0.336475 | 0.144047 | 0.144274 | 0.261111 | 0.382407 |
| Iteration 009 | 0.374584 | 0.154339 | **0.157611** | 0.318889 | 0.455570 |
| STRUCTURAL ORACLE | 0.640725 | 0.295496 | 0.324831 | 0.410000 | 0.735848 |

Iteration 009 is the new best on the primary metric and every secondary metric
shown above.

## Headroom capture

`37.2149%`, up from `32.2077%` for iteration 003.

## Secondary metrics

Weighted core coverage `0.134694`, noise-region rate `0.546667`, and nDCG@100
`0.573862`. These all improve substantially over iteration 003, so the F1 gain
does not come from a noisier context tradeoff.

## Per-case results

The largest gains over iteration 003 are Axios 5085 (`0 -> 0.189474`), Immutable
2005 (`0.019507 -> 0.159915`), and Preact 2757 (`0.127774 -> 0.184497`). Preact
4436 retains its exact-oracle `0.803506`. Full per-case metrics are retained in
`metrics.parquet`.

## Decision depth / model-call statistics

364 calls (24.267/case). Most are branch-local rollout choices; one compares
the deduplicated plans, with ordinary rank/stop calls only if depth remains.

## Oracle regret analysis

Residual F1 falls to `0.167220`. Preact 3739 remains the largest complete miss
(`0` vs `0.502439` oracle), followed by Preact 2896 (`0.379666` vs `0.825499`).
The planner nearly reaches oracle quality on Axios 5085, Immutable 2005, and
Preact 2757, demonstrating that short-horizon plans can expose useful basins.

## Cases improved

Axios 5085, Immutable 2005, and Preact 2757 improve materially over iteration
003.

## Cases regressed

Preact 3454 (`-0.081588`), Immutable 2006 (`-0.043597`), Preact 3689
(`-0.035179`), and Preact 4182 (`-0.026199`) regress.

## Interesting trajectories

Axios 5085 selects a six-action plan and reaches `91%` of its oracle F1.
Immutable 2005 reaches `95%` of oracle. Conversely, Preact 3739 selects repeated
same-file expansion and remains at zero, confirming that additional horizon
can amplify the attractor when rollout selection itself is poor.

## Provider cost / observations

364 observations: 1,175,914 input tokens, 93,010 output tokens, and
`$0.049388388`.

## Interpretation

Short-horizon consequence visibility is the first intervention to improve the
best aggregate policy. It raises precision, recall, HitFile, efficiency, and
nDCG together. The remaining weakness is branch-local rollout quality: one bad
child proposal can hide an otherwise useful root, and executing the whole plan
can pass an attractive intermediate state.

## Promote or reject

Promote. Iteration 009 is the new best.

## Next hypothesis

Retain the exact iteration-009 plan generation, but add a final checkpoint
choice over Symbol-ending prefixes of the selected plan before downstream
navigation. This tests whether atomic plan execution is causing the measured
regressions while holding root/rollout selection fixed.

## Reproducibility

- Jujutsu change ID: `vmxktqvx`
- protocol: `attune-jev-policy-hillclimb-009-hierarchical-lookahead-v1`
- model: `typesafe/jev-1.13`
- frozen machine and official scorer unchanged
- outcomes SHA-256: `c1a85dba520032911a80a816ac8b01429fb07957315e681ab3b8b64d0ec9cf8e`
- evaluation SHA-256: `c62d49787801d0097095938d0c100c539924ef12b16215d512b57e82de480fac`
- acquisition verification: 48 passed, 0 failed
- exact replay verification: 364 retained observations, zero network
  capability, identical paths/rankings, 48 passed, 0 failed
