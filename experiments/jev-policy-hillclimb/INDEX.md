# Jev Policy Hill-Climb Index

Frozen reference points:

- PRIOR F1: `0.0584933221`
- Jev v1 F1: `0.0788873780`
- structural oracle F1: `0.3248306670`
- Jev v1 headroom capture: `7.6572%`

| Iter | Description | F1 | Headroom | HitFile | Context efficiency | Calls | Promote |
|---:|---|---:|---:|---:|---:|---:|:---:|
| 000 | Frozen Jev v1 baseline | 0.078887 | 7.66% | 0.205556 | 0.267742 | 78 | baseline |
| 001 | Three-step terminal-preview continuations | 0.063789 | 1.99% | 0.227778 | 0.398673 | 19 | reject |
| 002 | Rank macro, then binary stop gate | 0.091550 | 12.41% | 0.274444 | 0.355615 | 50 | **promote** |
| 003 | Force first ranked macro | 0.144274 | 32.21% | 0.261111 | 0.382407 | 55 | **promote** |
| 004 | Prune exact semantic revisits | 0.144274 | 32.21% | 0.261111 | 0.382407 | 67 | reject (tie, costlier) |

## Synthesis after diagnosis

The best policy is still v1. It loses recoverable value predominantly at depth
zero or one. A one- or two-step oracle remains weak, while three-step lookahead
reaches `0.239664` F1 (68.02% of headroom). Exact sibling top-eight preview
aliasing is not the dominant defect. The first policy mutation therefore tests
one factor: direct choice among valid one-to-three-action continuations using
their terminal previews.
