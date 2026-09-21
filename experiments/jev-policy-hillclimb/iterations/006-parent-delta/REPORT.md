# Iteration 006 — Parent-to-terminal delta

## Hypothesis

Iteration 003 often asks Jev to compare terminal previews without saying what
the continuation changed. Explicit, deployment-visible set deltas should make
no-op, highly overlapping, and destructive continuations distinguishable from
continuations that introduce genuinely new structural evidence.

## Change from previous best

Start exactly from iteration 003's forced-first-macro policy. Add one compact
parent-to-terminal delta to every ranked continuation and to the proposed side
of the binary stop gate: symbols added, symbols removed, Jaccard overlap, and
exact-revisit status. The model instruction tells Jev to use that delta. No
candidate, traversal, stopping, or scoring semantics change.

## Why this might recover oracle headroom

The frozen diagnosis found a strong `defined_in >> defines` attractor whose
states were frequently idempotent or destructive and never improved oracle
value-to-go in the diagnosed occurrences. Iteration 005 also showed that Jev
can continue past a high-value state. Both failures are consistent with an
absolute terminal preview hiding the consequence of movement from the current
state.

## Runtime information available to the policy

Issue text, frozen semantic prior, current path/state preview, valid one-to-
three-action continuations, each terminal preview, and exact set differences
between the current and terminal symbol frontiers.

## Runtime information explicitly unavailable

Gold, official metrics, oracle values or paths, benchmark case identifiers,
future outcomes, and repository-specific exceptions.

## Primary metric

Aggregate official line F1 over the frozen fifteen-case development set.

## Expected failure mode

Set-change magnitude may be only weakly related to issue relevance. The model
may prefer novelty even when a small stable frontier is better, or ignore the
numeric delta exactly as v1 ignored weakly informative confidence cues.

## Result

| Condition | Precision | Recall | F1 | HitFile | Context efficiency |
|---|---:|---:|---:|---:|---:|
| PRIOR | 0.286862 | 0.075187 | 0.058493 | 0.227778 | 0.407990 |
| Jev v1 | 0.196199 | 0.093466 | 0.078887 | 0.205556 | 0.267742 |
| Best (003) | 0.336475 | 0.144047 | 0.144274 | 0.261111 | 0.382407 |
| Iteration 006 | 0.331953 | 0.121658 | 0.123474 | 0.261111 | 0.385122 |
| STRUCTURAL ORACLE | 0.640725 | 0.295496 | 0.324831 | 0.410000 | 0.735848 |

The delta policy remains substantially above v1 but loses 14.42% F1 relative
to iteration 003.

## Headroom capture

`24.39797%`, below iteration 003's `32.2077%`.

## Secondary metrics

Weighted core coverage `0.095945`, noise-region rate `0.653333`, and nDCG@100
`0.364990`. Context efficiency is slightly higher than iteration 003, while
HitFile is identical.

## Per-case results

| Case | PRIOR F1 | This F1 | ORACLE F1 | Chosen path |
|---|---:|---:|---:|---|
| axios-4731 | 0.000000 | 0.000000 | 0.011628 | defined_in >> defines |
| axios-5085 | 0.000000 | 0.000000 | 0.208333 | calls |
| immutable-2005 | 0.089503 | 0.019507 | 0.168700 | callers |
| immutable-2006 | 0.198813 | 0.224969 | 0.328438 | calls |
| preact-2757 | 0.000000 | 0.127774 | 0.201560 | callers >> callers |
| preact-2896 | 0.050955 | 0.379666 | 0.825499 | calls >> callers >> callers >> callers >> calls >> callers |
| preact-3010 | 0.000000 | 0.000000 | 0.000000 | defined_in >> defines |
| preact-3454 | 0.402640 | 0.402640 | 0.572770 | defined_in >> defines |
| preact-3562 | 0.016694 | 0.016694 | 0.325517 | defined_in >> defines |
| preact-3689 | 0.069498 | 0.137931 | 0.428571 | defined_in >> defines >> calls |
| preact-3739 | 0.000000 | 0.000000 | 0.502439 | calls >> callers >> callers >> calls >> callers >> callers >> calls |
| preact-3763 | 0.000000 | 0.000000 | 0.166320 | calls >> callers >> calls >> defined_in >> defines |
| preact-4152 | 0.000000 | 0.000000 | 0.000000 | defined_in >> defines >> callers >> callers >> calls |
| preact-4182 | 0.049296 | 0.060296 | 0.329177 | defined_in >> defines >> calls |
| preact-4436 | 0.000000 | 0.482636 | 0.803506 | defined_in >> imported_by >> defines >> defined_in >> imported_by >> defines >> calls |

## Decision depth / model-call statistics

59 calls (3.933/case), versus 55 for iteration 003. Macro decisions frequently
consume all remaining depth at once, so the number of decisions is much smaller
than the selected path length.

## Oracle regret analysis

Residual F1 is `0.201356`. The dominant avoidable regression remains Preact
4436: the first three actions reach its exact oracle, but the policy repeats the
same macro and appends `calls`, losing `0.320870` F1. Preact 3739 now escapes the
same-file route and traverses a seven-action call/caller path, but still scores
zero against `0.502439` oracle F1.

## Cases improved

Relative to iteration 003, only Preact 4182 improves (`+0.008867`). The delta
does change several zero-scoring trajectories, most visibly 3739, without yet
turning that movement into official quality.

## Cases regressed

Preact 4436 regresses by `0.320870`. Every other case ties iteration 003.

## Interesting trajectories

The deployment-visible delta is behaviorally active: 3739 moves from
`defined_in >> defines` to a full-depth call/caller trajectory. But the same
information does not make stopping reliable. In 4436, the model sees deltas and
still walks through an exact-oracle intermediate state to a substantially worse
terminal state.

## Provider cost / observations

59 observations: 177,434 input tokens, 9,487 output tokens, and
`$0.007452228`.

## Interpretation

Absolute previews were not the only issue, and simple set deltas are not a
sufficient value signal. They can break an attractor without identifying the
right basin. The strongest remaining evidence points to checkpoint selection:
the trajectory itself visits useful states that the online stop decision later
throws away.

## Promote or reject

Reject. Iteration 003 remains best.

## Next hypothesis

Return to iteration 003 and retain every visited macro endpoint. After the
ordinary trajectory terminates, ask one final deployment-time comparison to
choose among those checkpoints. This changes stopping selection without adding
branches or exposing unvisited descendants.

## Reproducibility

- Jujutsu change ID: `rluoxxlq`
- protocol: `attune-jev-policy-hillclimb-006-parent-delta-v1`
- model: `typesafe/jev-1.13`
- frozen machine and official scorer unchanged
- outcomes SHA-256: `e12ecf1ef904e39ac2bd11851e017aefedf9c67487c437ff58262a4bbd9d37a9`
- evaluation SHA-256: `2b53b699ce44958612bc926edbea43714b963efe3179a68006d2783b63e6773c`
- acquisition verification: 48 passed, 0 failed
- exact replay verification: 59 retained observations, zero network capability,
  identical paths/rankings, 48 passed, 0 failed
