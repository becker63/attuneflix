# Iteration 001 — Three-step terminal-preview continuations

## Hypothesis

Jev v1 loses value because greedy immediate edges hide delayed structural
consequences. Letting it choose among valid one-to-three-action continuations
using each continuation's terminal symbol preview should recover materially more
of the frozen oracle headroom.

## Change from previous best

One decision-structure change: alternatives are typed continuation suffixes of
length one through three that end in `Symbol`, rather than single structural
edges. A selected suffix executes atomically. Stop remains available at every
decision.

## Why this might recover oracle headroom

The diagnosed oracle curve jumps from `0.108597` F1 at two-step lookahead to
`0.239664` at three. Important cases have zero immediate reward while valuable
states first appear after three operations.

## Runtime information available to the policy

Issue text, frozen prior, current path/state preview, and for every valid
one-to-three-action suffix: its action sequence, length, terminal-state domain,
cardinality, and top-eight members in prior order.

## Runtime information explicitly unavailable

Gold, official scores, oracle values/paths, case IDs as special rules, and any
future outcome label.

## Primary metric

Aggregate official line F1 over the same frozen fifteen cases.

## Expected failure mode

The larger alternative set may exceed Jev's useful comparison capacity, or
terminal top-eight previews may still fail to communicate which delayed state
is useful. Atomic macros may also skip an intermediate state where stopping
would have been superior.

## Result

| Condition | Precision | Recall | F1 | HitFile | Context efficiency |
|---|---:|---:|---:|---:|---:|
| PRIOR | 0.286862 | 0.075187 | 0.058493 | 0.227778 | 0.407990 |
| Jev v1 | 0.196199 | 0.093466 | 0.078887 | 0.205556 | 0.267742 |
| Iteration 001 | 0.259517 | 0.078383 | 0.063789 | 0.227778 | 0.398673 |
| STRUCTURAL ORACLE | 0.640725 | 0.295496 | 0.324831 | 0.410000 | 0.735848 |

The candidate beats PRIOR F1 by 9.05% relative but regresses 19.14% from Jev
v1. It is not the new best.

## Headroom capture

`1.9883%`, down from v1's `7.6572%`.

## Secondary metrics

Weighted core coverage is `0.076074`, noise-region rate `0.640000`, and
nDCG@100 `0.363828`. Compared with v1, context efficiency and nDCG improve,
but the primary F1 and recall objectives regress.

## Per-case results

| Case | PRIOR | Iter 001 | ORACLE | Path |
|---|---:|---:|---:|---|
| axios-4731 | 0.000000 | 0.000000 | 0.011628 | root |
| axios-5085 | 0.000000 | 0.000000 | 0.208333 | calls |
| immutable-2005 | 0.089503 | 0.089503 | 0.168700 | root |
| immutable-2006 | 0.198813 | 0.198813 | 0.328438 | root |
| preact-2757 | 0.000000 | 0.000000 | 0.201560 | root |
| preact-2896 | 0.050955 | 0.050955 | 0.825499 | root |
| preact-3010 | 0.000000 | 0.000000 | 0.000000 | root |
| preact-3454 | 0.402640 | 0.402640 | 0.572770 | root |
| preact-3562 | 0.016694 | 0.016694 | 0.325517 | root |
| preact-3689 | 0.069498 | 0.137931 | 0.428571 | defined_in >> defines >> calls |
| preact-3739 | 0.000000 | 0.000000 | 0.502439 | root |
| preact-3763 | 0.000000 | 0.000000 | 0.166320 | root |
| preact-4152 | 0.000000 | 0.000000 | 0.000000 | defined_in >> defines >> callers |
| preact-4182 | 0.049296 | 0.060296 | 0.329177 | defined_in >> defines >> calls |
| preact-4436 | 0.000000 | 0.000000 | 0.803506 | root |

## Decision depth / model-call statistics

The candidate made 19 calls (1.267/case), versus v1's 78. Eleven cases stop
at depth zero, one at depth one, and three at depth three.

## Oracle regret analysis

Aggregate residual F1 to oracle is `0.261042`, versus `0.245943` for v1. The
largest losses remain the high-headroom cases 2896, 4436, and 3739; all three
stop at the root. The change therefore worsens the already-diagnosed premature
stopping mechanism rather than resolving delayed-value selection.

## Cases improved

Two cases improve over PRIOR: Preact 3689 (`+0.068433`) and Preact 4182
(`+0.011000`). Both choose the same-file projection followed by `calls`.

## Cases regressed

Relative to v1, the major regression is Preact 2896: v1's successful
`0.340333` trajectory is replaced by root F1 `0.050955`. Eleven root stops
discard almost all possible structural improvement.

## Interesting trajectories

The model chose `defined_in >> defines >> calls` twice and
`defined_in >> defines >> callers` once. Thus exposing macro terminal states
did not remove the same-file attractor. It made stop far more attractive:
73.3% of cases stop immediately, versus 13.3% in v1.

## Provider cost / observations

Nineteen exact observations were retained at
`.attune/experiments/jev-policy-hillclimb/001-macro3-terminal-preview`.
They used 66,671 input tokens, 5,089 output tokens, and `$0.002800182`.
A fresh replay reproduced all paths and rankings with zero possible network
calls.

## Interpretation

Three-step terminal previews are not sufficient when stop competes directly
with roughly an order of magnitude more actions. Jev responds by retaining the
prior, including in cases where the prior has zero F1. The few non-stop choices
still favor the same-file motif. This falsifies the simple hypothesis that
lookahead depth alone fixes v1.

## Promote or reject

Reject. Jev v1 remains best-so-far.

## Next hypothesis

Separate continuation ranking from stopping. First ask Jev to rank only the
non-stop macro continuations, then make a second binary decision between the
current state and the selected continuation. This preserves three-step
visibility while preventing a single stop option from dominating a large
multiclass comparison.

## Reproducibility

- Jujutsu change ID: `zpryxzuy`
- protocol: `attune-jev-policy-hillclimb-001-macro3-v1`
- model: `typesafe/jev-1.13`
- facts, prior, structural grammar, maximum depth, and scorer: frozen from v1
- outcomes SHA-256: `9c0db7418f35757ec9f3d1d634cd5be17301e16e20deb3b4cd8abfe9806f46f7`
- evaluation SHA-256: `9b74e41d15ac5cb3a1bb87326957a75c7dd63f4bf6fe3981703bbae288e6466b`
- verification: 48 passed, 0 failed; acquire and exact replay both green
