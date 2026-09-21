# Iteration 000 — Frozen Jev v1 baseline

## Hypothesis

This is the immutable baseline, not a new policy. Capturing it inside the
hill-climb establishes an auditable parent for every later mutation.

## Change from previous best

None. The report projects already-retained v1 observations and official scores.

## Why this might recover oracle headroom

It does not. It fixes the denominator and prevents later policy-search results
from silently changing the baseline.

## Runtime information available to the policy

Issue text, frozen semantic prior, current typed structural state, current path,
top-eight prior-ordered state preview, cardinality, immediate valid actions, and
each immediate child's equivalent preview.

## Runtime information explicitly unavailable

Gold files/lines/regions, official scores, oracle values or paths, case-specific
labels, and future decisions.

## Primary metric

Aggregate official line F1 over the frozen fifteen cases.

## Expected failure mode

Greedy one-edge choices cannot see delayed value. Broad same-file expansions
can look attractive, and stopping may discard valuable descendants.

## Result

| Condition | Precision | Recall | F1 | HitFile | Context efficiency |
|---|---:|---:|---:|---:|---:|
| PRIOR | 0.286862 | 0.075187 | 0.058493 | 0.227778 | 0.407990 |
| Jev v1 / this iteration | 0.196199 | 0.093466 | 0.078887 | 0.205556 | 0.267742 |
| STRUCTURAL ORACLE | 0.640725 | 0.295496 | 0.324831 | 0.410000 | 0.735848 |

## Headroom capture

`(0.0788873780 - 0.0584933221) / (0.3248306670 - 0.0584933221) = 7.6572%`.

## Secondary metrics

Weighted core coverage is `0.073482`, noise-region rate is `0.746667`, and
nDCG@100 is `0.306877`. The retained run made 78 decisions (5.2 per case), used
98,358 input and 3,503 output tokens, and cost `$0.004131036`.

## Per-case results

The complete per-case metrics, paths, and decision counts are in
`metrics.json`. Thirteen cases have positive structural F1 headroom; v1 captures
positive headroom in only three.

## Decision depth / model-call statistics

Final depths are 0 for two cases, 1 for three, 6 for three, and 7 for seven.
Calls range from 1 to 7.

## Oracle regret analysis

The post-hoc diagnosis found 78 decisions with mean regret `0.047297`, median
zero, and maximum `0.642358`. Of 53 decisions with a strict value distinction,
v1 selected an optimal action 23 times. Recoverable value was first lost at
depth zero in six positive-headroom cases and depth one in another six.

## Cases improved

The dominant success is `preactjs__preact-2896`, from `0.050955` PRIOR F1 to
`0.340333`; oracle F1 is `0.825499`.

## Cases regressed

Several cases select structural states that score no better than the prior.
Notably, `preactjs__preact-3739` and `preactjs__preact-4436` finish at zero F1
despite oracle F1 of `0.502439` and `0.803506`.

## Interesting trajectories

`defined_in -> defines` occurs 26 times. Fourteen occurrences return exactly to
the same state; mean Jaccard overlap is `0.614797`; mean oracle value change is
negative. Three-step oracle lookahead reaches `0.239664` F1, compared with
`0.093513` at one step and `0.108597` at two.

## Provider cost / observations

No observations were acquired for this documentation iteration. It references
the immutable v1 store. The frozen acquisition had 78 calls and cost
`$0.004131036`.

## Interpretation

The available structure is substantially better than v1's selection. The
largest verified defect is planning horizon, with stop calibration and the
same-file attractor as secondary mechanisms. Exact sibling preview aliasing is
not the main explanation.

## Promote or reject

Retain as baseline only.

## Next hypothesis

Let Jev choose a typed one-to-three-action continuation by viewing its terminal
state, instead of making three independent greedy edge choices.

## Reproducibility

- Jujutsu change ID: `tnzlplxv`
- frozen protocol: `attune-jev-localization-v1`
- model: `typesafe/jev-1.13`
- outcomes SHA-256: `0901bf208bcf98ccdfce0c6281e9990f90b4823d8fd68ea0780e484cceb7636c`
- official evaluation SHA-256: `70cedc1753711ec4acba7f547c4a4ad2f623a2ca48b98aea5d97c8c8d62dd541`
- diagnosis SHA-256: `25436d39a72e2ff2039b2fcf0746ce2c6cccaad3af4190567064778f210c0ea4`
- command: frozen evidence projection only; no network, Grit, embedding, or Jev acquisition
