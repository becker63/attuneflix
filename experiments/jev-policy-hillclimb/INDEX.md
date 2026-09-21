# Jev Policy Hill-Climb Index

Final synthesis: [FINAL_REPORT.md](FINAL_REPORT.md). Best scientific checkpoint
is iteration 013 (`uzsxzwwl`, commit `df2b8dd7`) at F1 `0.201549` and `53.71%`
structural-headroom capture.

Frozen reference points:

- PRIOR F1: `0.0584933221`
- Jev v1 F1: `0.0788873780`
- structural oracle F1: `0.3248306670`
- Jev v1 headroom capture: `7.6572%`

Reproducibility correction: the iteration reports, metrics, retained requests,
and production seams for iterations 001--005 were checkpointed, but the shared
experiment runner was accidentally matched by the repository-wide `lib/`
ignore rule. The runner becomes tracked starting with iteration 006. Earlier
checkpoints are preserved rather than rewritten; their exact model-visible
protocols remain recorded by their reports and retained raw request envelopes.

| Iter | Description | F1 | Headroom | HitFile | Context efficiency | Calls | Promote |
|---:|---|---:|---:|---:|---:|---:|:---:|
| 000 | Frozen Jev v1 baseline | 0.078887 | 7.66% | 0.205556 | 0.267742 | 78 | baseline |
| 001 | Three-step terminal-preview continuations | 0.063789 | 1.99% | 0.227778 | 0.398673 | 19 | reject |
| 002 | Rank macro, then binary stop gate | 0.091550 | 12.41% | 0.274444 | 0.355615 | 50 | **promote** |
| 003 | Force first ranked macro | 0.144274 | 32.21% | 0.261111 | 0.382407 | 55 | **promote** |
| 004 | Prune exact semantic revisits | 0.144274 | 32.21% | 0.261111 | 0.382407 | 67 | reject (tie, costlier) |
| 005 | Width-two root beam | 0.117612 | 22.20% | 0.272222 | 0.386456 | 127 | reject |
| 006 | Parent-to-terminal set delta | 0.123474 | 24.40% | 0.261111 | 0.385122 | 59 | reject |
| 007 | Retrospective choice among visited checkpoints | 0.144274 | 32.21% | 0.261111 | 0.382407 | 70 | reject (tie, costlier) |
| 008 | Balanced pairwise root tournament | 0.089326 | 11.58% | 0.277778 | 0.344419 | 342 | reject |
| 009 | Hierarchical one-rollout root planning | **0.157611** | **37.21%** | 0.318889 | 0.455570 | 364 | **promote** |
| 010 | Checkpoint selected short plan | 0.157079 | 37.02% | **0.352222** | **0.503680** | 379 | reject F1 / Pareto |
| 011 | Terminal selector over experts 003 and 009 | **0.170048** | **41.88%** | 0.318889 | 0.479399 | 384 | **promote** |
| 012 | Exact-ancestor-revisit-pruned planner portfolio | **0.193444** | **50.67%** | **0.341111** | **0.504705** | 331 | **promote** |
| 013 | Two-rollout deep planner vs replayed 012 | **0.201549** | **53.71%** | 0.341111 | **0.524766** | 767 | **promote** |
| 014 | Delta-aware final expert comparison | 0.191951 | 50.11% | 0.314444 | 0.506429 | 767 | reject |
| 015 | Flat learned oracle-route template library | 0.075687 | 6.46% | 0.227778 | 0.476153 | 782 | reject |
| 016 | Pairwise learned-template tournament | 0.121302 | 23.58% | 0.338889 | **0.564661** | 962 | reject / Pareto efficiency |

## Synthesis after iteration 015

Best remains iteration 013 at F1 `0.201549` and `53.71%` headroom capture.
Three consecutive causal lessons now hold: exact recurrence pruning can expose
a missing basin; deeper hierarchical rollout can add useful candidate
coverage; and flat multiclass selection fails catastrophically even when the
oracle route is explicitly present. Candidate coverage and decision structure
must therefore be improved together. Next: hold the complete learned template
library fixed and replace only flat selection with balanced pairwise
elimination plus a final comparison against the replayed best.

## Synthesis after iteration 012

Best primary policy: iteration 012, F1 `0.193444`, capturing `50.67%` of
structural headroom. Exact ancestor-state pruning changes the largest complete
miss, Preact 3739, from F1 `0` to `0.350943`, with no regressions because the
classic expert and terminal selector preserve prior winners. This establishes
a useful architecture: generate structurally diverse honest candidates, remove
provable recurrence, then let Jev arbitrate concrete terminal consequences.
Remaining error is candidate coverage on four large Preact gaps rather than
portfolio arbitration. Next: add one genuinely diverse route generator while
holding the successful terminal selector fixed.

## Synthesis after iteration 011

Best primary policy: iteration 011, F1 `0.170048`, capturing `41.88%` of
structural headroom. A neutral terminal comparison selected the better of the
classic and hierarchical experts in every consequential disagreement, exactly
realizing their post-hoc per-case maximum without gold at runtime. This is
strong evidence that Jev can arbitrate concrete outcomes even when it cannot
reliably generate the right path. The dominant residual is now candidate
generation shared by both experts, especially the same-file attractor on
Preact 3739. Next: prune exact revisits/no-op plans inside hierarchical rollout
generation, then recombine with the unchanged classic expert.

## Synthesis after iteration 010

Best primary policy: iteration 009, F1 `0.157611`, capturing `37.21%` of
structural headroom. The successful change is hierarchical consequence
visibility: branch-local rollouts followed by plan selection improve F1,
precision, recall, HitFile, efficiency, noise, and nDCG together. Pairwise
voting, absolute set deltas, exact-revisit pruning, root beams, and
retrospective stopping did not improve the best. Iteration 010 shows a genuine
secondary Pareto point (`0.352222` HitFile and `0.503680` context efficiency)
but confirms that the dominant residual is wrong-plan selection. Next: test a
two-expert final selector over the complementary 003 and 009 terminal states.

## Synthesis after diagnosis

The best policy is still v1. It loses recoverable value predominantly at depth
zero or one. A one- or two-step oracle remains weak, while three-step lookahead
reaches `0.239664` F1 (68.02% of headroom). Exact sibling top-eight preview
aliasing is not the dominant defect. The first policy mutation therefore tests
one factor: direct choice among valid one-to-three-action continuations using
their terminal previews.

## Synthesis after iteration 005

Best policy: iteration 003, F1 `0.144274`, capturing `32.21%` of structural
headroom. Short macro visibility works only when root stopping is removed.
Exact-revisit pruning changes trajectories but not quality. A width-two root
beam improves recall and HitFile but regresses F1 because branch rollouts pass
through useful states and the final selector sees only their endpoints. The
dominant residual is now interpreting parent-to-child change and selecting the
right stopping point, not lack of branching or exact recurrence. Next: add
explicit delta telemetry to the best single-branch policy.
