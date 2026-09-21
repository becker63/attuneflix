# Iteration 008 — Pairwise root tournament

## Hypothesis

Jev's one-shot probability distribution over roughly twenty one-to-three-step
root continuations is nearly uninformative about oracle value-to-go. The same
model may still compare two concrete terminal previews reliably. A balanced
pairwise tournament tests that capability without changing the candidate set.

## Change from previous best

Replace iteration 003's single multiclass root ranking with a deterministic
balanced knockout tournament over the exact same complete root continuation
set, ordered by stable path text. Every match contains exactly two ordinary v1
terminal previews. Force the tournament winner, then use iteration 003's
multiclass rank plus binary-stop policy for all later decisions.

## Why this might recover oracle headroom

The diagnosis shows most value is lost at depth zero or one, while the complete
three-step oracle already reaches about `0.2397` F1. Decomposing one crowded
choice into binary judgments may reduce alternative overload and preserve a
high-value early basin.

## Runtime information available to the policy

Issue text, frozen semantic prior, current state/path, the exact same valid
one-to-three-action continuations and terminal top-eight previews as iteration
003, and the winners of earlier tournament rounds.

## Runtime information explicitly unavailable

Gold, official metrics, oracle values or paths, benchmark identifiers,
repository-specific rules, and future outcomes.

## Primary metric

Aggregate official line F1 over the frozen fifteen-case development set.

## Expected failure mode

Binary choices may remain poorly correlated with structural utility. The fixed
bracket may be order-sensitive, and locally plausible candidates may eliminate
the best continuation before a direct comparison.

## Result

| Condition | Precision | Recall | F1 | HitFile | Context efficiency |
|---|---:|---:|---:|---:|---:|
| PRIOR | 0.286862 | 0.075187 | 0.058493 | 0.227778 | 0.407990 |
| Jev v1 | 0.196199 | 0.093466 | 0.078887 | 0.205556 | 0.267742 |
| Best (003) | 0.336475 | 0.144047 | 0.144274 | 0.261111 | 0.382407 |
| Iteration 008 | 0.264403 | 0.098783 | 0.089326 | 0.277778 | 0.344419 |
| STRUCTURAL ORACLE | 0.640725 | 0.295496 | 0.324831 | 0.410000 | 0.735848 |

Pairwise selection is only slightly above v1 and loses `38.09%` F1 relative
to iteration 003 despite using more than six times as many calls.

## Headroom capture

`11.5765%`.

## Secondary metrics

Weighted core coverage `0.086450`, noise-region rate `0.693333`, and nDCG@100
`0.281159`. HitFile rises above iteration 003, but every precision/quality
measure relevant to the primary objective worsens.

## Per-case results

Four cases improve over PRIOR, one worsens, and ten tie. Full per-case metrics
and all binary judgments are retained in `metrics.json`.

## Decision depth / model-call statistics

342 calls (22.8/case), 20 of which are normally the complete root tournament.
The remaining calls are downstream multiclass ranking and binary stopping.

## Oracle regret analysis

Residual F1 is `0.235505`. The tournament's dominant loss is Preact 4436: it
selects `calls >> calls` instead of `defined_in >> imported_by >> defines`,
turning iteration 003's exact-oracle `0.803506` into zero. It also produces
small regressions on Preact 3454/2757 and Immutable 2006, with no F1 improvement
over iteration 003 on any case.

## Cases improved

None relative to iteration 003.

## Cases regressed

Preact 4436 (`-0.803506`), Preact 3454 (`-0.009092`), Immutable 2006
(`-0.008282`), and Preact 2757 (`-0.003347`).

## Interesting trajectories

The tournament does move Preact 3739 away from the same-file attractor to
`callers >> callers >> calls`, but that frontier still scores zero. In contrast,
it eliminates the single largest success of the best policy. Binary local
preference therefore changes behavior without tracking oracle usefulness.

## Provider cost / observations

342 observations: 467,546 input tokens, 19,023 output tokens, and
`$0.019636932`.

## Interpretation

Alternative overload is not the primary explanation for the poor value signal.
Decomposing the root choice into twenty binary comparisons amplifies plausible
but wrong local judgments rather than revealing the high-value continuation.
More inference alone is insufficient when the representation contains no
summary of downstream consequences.

## Promote or reject

Reject. Iteration 003 remains best.

## Next hypothesis

Return to iteration 003's one-shot macro ranking and expose a compact,
deployment-visible summary of each continuation's short-horizon descendants.
This directly tests the diagnosis that terminal previews are myopic while
holding the model and candidate roots fixed.

## Reproducibility

- Jujutsu change ID: `yktwsyqr`
- protocol: `attune-jev-policy-hillclimb-008-pairwise-root-tournament-v1`
- model: `typesafe/jev-1.13`
- bracket order: stable path text, balanced adjacent-pair knockout
- frozen machine and official scorer unchanged
- outcomes SHA-256: `fc3378f8709ef919f82065af49e35d67947c1ade88d94fa22b9079e760279b8c`
- evaluation SHA-256: `5bd2bede1018f9c198be07c9002ad61919e8e70e5cddbc6f22f87cf281230d4d`
- acquisition verification: 48 passed, 0 failed
- exact replay verification: 342 retained observations, zero network
  capability, identical paths/rankings, 48 passed, 0 failed
- exact replay verification: 342 retained observations, zero network
  capability, identical paths/rankings, 48 passed, 0 failed
