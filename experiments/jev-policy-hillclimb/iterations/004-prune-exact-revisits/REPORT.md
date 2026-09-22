# Iteration 004 — Prune exact semantic revisits

## Hypothesis

The same-file attractor partly consists of continuations that return to the
identical semantic frontier. Removing exact no-op terminal states should force
the selector to spend its first exploration on genuinely new evidence and
improve the high-headroom misses.

## Change from previous best

Before each rank call, discard only continuations whose terminal
`Semantics.State` is exactly equal to the current state. If no state-changing
continuation exists, stop. Forced first exploration and all other iteration-003
behavior remain unchanged.

## Why this might recover oracle headroom

Fourteen of 26 diagnosed `defined_in -> defines` motifs were exactly
state-idempotent. The best policy still selects that motif in several failed
cases. Exact state equality is available at deployment time and independent of
atom names.

## Runtime information available to the policy

The iteration-003 issue/prior/current/terminal previews after deterministic
removal of exact no-op alternatives.

## Runtime information explicitly unavailable

Gold, official scores, oracle paths/values, benchmark identity rules, and any
empirically fitted threshold.

## Primary metric

Aggregate official line F1 over the frozen fifteen-case development set.

## Expected failure mode

Many harmful same-file macros are broadening rather than exactly idempotent, so
exact pruning may change few choices. Removing a no-op can also redirect Jev to
a worse state-changing continuation.

## Result

Aggregate metrics are exactly equal to iteration 003: precision `0.336475`,
recall `0.144047`, F1 `0.144274`, HitFile `0.261111`, and context efficiency
`0.382407`. It is an extensional quality tie, not an execution tie.

## Headroom capture

`32.2077%`, unchanged from iteration 003.

## Secondary metrics

Weighted core coverage `0.104712`, noise-region rate `0.653333`, nDCG@100
`0.347826`; all are unchanged.

## Per-case results

Every per-case official metric is unchanged from iteration 003. Paths change
for Axios 4731, Preact 3010, 3739, 3763, and 4152, but all five remain at zero
F1. The complete paths and scores are in `metrics.parquet`.

## Decision depth / model-call statistics

Sixty-seven calls (4.467/case), twelve more than iteration 003. Exact pruning
often causes additional traversal rather than earlier useful stopping.

## Oracle regret analysis

The aggregate residual remains `0.180556`. Preact 3739 now explores to depth
seven, beginning with `calls >> callers`, but still misses every gold line.
This shows that preserving a promising prefix is insufficient when later macro
choices discard its value.

## Cases improved

No case improves over iteration 003.

## Cases regressed

No official metric regresses, but the same score requires 21.8% more model
calls. This is a strict efficiency regression under the near-tie rule.

## Interesting trajectories

Preact 3739 changes from the idempotent-looking `defined_in >> defines` stop to
`calls >> callers >> callers >> calls >> callers >> callers >> calls`. Its
oracle also begins `calls >> callers`, yet the selected suffix still scores
zero. Exact revisit pruning can reveal a good coarse prefix without controlling
later value loss.

## Provider cost / observations

Sixty-seven observations: 161,708 input tokens, 9,983 output tokens, and
`$0.006791736`.

## Interpretation

Literal no-op recurrence is not the primary quality limiter. Harmful macros can
change the semantic state substantially, and longer traversal can erase an
initially promising prefix. A stronger intervention must improve ranking or
preserve multiple candidates, not merely prune equality.

## Promote or reject

Reject. Iteration 003 remains best because quality ties and it uses fewer calls.

## Next hypothesis

Test a small beam: retain the top two macro proposals from the rank distribution
instead of irrevocably committing to one. This targets later value loss while
using only deployment-visible model probabilities and structural states.

## Reproducibility

- Jujutsu change ID: `qyzoqvqw`
- protocol: `attune-jev-policy-hillclimb-004-prune-exact-revisits-v1`
- model: `typesafe/jev-1.13`
- frozen machine and official scorer unchanged
- outcomes SHA-256: `9310400412fa27d344f8abf3ee0f5f2297f67b8b73f6911f022e8a2baca152a0`
- evaluation SHA-256: `80bb3f8850aec687d45a35f61408531456ae835e01f2cafef8ae29a739c1c884`
- acquisition verification: 48 passed, 0 failed
- exact replay verification: 67 observations, zero network capability, identical paths/rankings, 48 passed
