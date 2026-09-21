# Jev Policy Hill-Climb Index

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
