# Structural anchor counterfactual (derived)

Baseline pushed code commit: `7da9f5536333379bcde8065cc718267f12eb90f0`.
Frozen snapshot: `repository-snapshot-v1:002a462e6f58440bbf60071f1e945b38bb304fe46a38ca6fdfd578248693cf01` (`babel/babel` at `5134505bf93013c5fa7df66704df8d04becb7f7d`).
Protocol: 16 frozen issue-blind singleton seeds, six directed atoms, depth seven; same Atlas.Signature.compute for every row. Directory prefixes classify File/Symbol members but never enter the Atlas state domain.

Target: `packages/babel-types`. Boundary mask removes admitted imports and calls with exactly one endpoint under that prefix; internal edges, files, symbols, defines and parents remain.
Controls: the two sibling directories with positive crossing-edge volume nearest the target's volume, ties by path: `packages/babel-traverse`, `packages/babel-helper-create-class-features-plugin`.

## Anchor mass among non-empty states

| Domain | Distinct states containing target / live states | Unique mass | Observations containing target / live observations | Weighted mass |
| --- | ---: | ---: | ---: | ---: |
| File | 0 / 8 | 0.0 | 0 / 137 | 0.0 |
| Symbol | 2834 / 3761 | 0.7535229992023398 | 5314 / 8022 | 0.662428322114186 |

## Same signature protocol under boundary masks

| Intervention | Domain | Survival | p90 reach | Total recurrence | Live recurrence | Unique live states | Extinct observations | Physical compression | Reuse | Masked edges |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| baseline | File | 0.005222628850259225 | 0.0 | 2623.2 | 17.125 | 8 | 26095 / 26232 | 273.25 | 0.9853949774901519 | 0 imports + 0 calls |
| baseline | Symbol | 0.3058096980786825 | 0.009504565184852567 | 6.971033749667818 | 2.1329433661260304 | 3761 | 18210 / 26232 | 273.25 | 0.9853949774901519 | 0 imports + 0 calls |
| packages/babel-types | File | 0.005222628850259225 | 0.0 | 2623.2 | 17.125 | 8 | 26095 / 26232 | 273.25 | 0.9910224395047833 | 0 imports + 2262 calls |
| packages/babel-types | Symbol | 0.2327310155535224 | 0.0024205155043830954 | 11.972615244180739 | 2.7889447236180906 | 2189 | 20127 / 26232 | 273.25 | 0.9910224395047833 | 0 imports + 2262 calls |
| packages/babel-traverse | File | 0.005222628850259225 | 0.0 | 2623.2 | 17.125 | 8 | 26095 / 26232 | 273.25 | 0.9857291080472707 | 0 imports + 990 calls |
| packages/babel-traverse | Symbol | 0.3050853918877707 | 0.006803611147455188 | 7.410169491525424 | 2.2620124364047483 | 3538 | 18229 / 26232 | 273.25 | 0.9857291080472707 | 0 imports + 990 calls |
| packages/babel-helper-create-class-features-plugin | File | 0.005222628850259225 | 0.0 | 2623.2 | 17.125 | 8 | 26095 / 26232 | 273.25 | 0.9854125633089477 | 0 imports + 160 calls |
| packages/babel-helper-create-class-features-plugin | Symbol | 0.3058096980786825 | 0.009354886992965125 | 7.006410256410256 | 2.1437733832175305 | 3742 | 18210 / 26232 | 273.25 | 0.9854125633089477 | 0 imports + 160 calls |

## Absolute and relative deltas from baseline

### `packages/babel-types`

| Metric | Baseline | Masked | Absolute Δ | Relative Δ |
| --- | ---: | ---: | ---: | ---: |
| File survival fraction | 0.005222628850259225 | 0.005222628850259225 | 0.0 | 0.0% |
| File p90 reach | 0.0 | 0.0 | 0.0 | undefined (zero baseline) |
| File total recurrence | 2623.2 | 2623.2 | 0.0 | 0.0% |
| File live recurrence | 17.125 | 17.125 | 0.0 | 0.0% |
| File unique total states | 10.0 | 10.0 | 0.0 | 0.0% |
| File unique live states | 8.0 | 8.0 | 0.0 | 0.0% |
| File extinct observations | 26095.0 | 26095.0 | 0.0 | 0.0% |
| Symbol survival fraction | 0.3058096980786825 | 0.2327310155535224 | -0.07307868252516012 | -23.896783844427826% |
| Symbol p90 reach | 0.009504565184852567 | 0.0024205155043830954 | -0.007084049680469471 | -74.53312742553786% |
| Symbol total recurrence | 6.971033749667818 | 11.972615244180739 | 5.001581494512921 | 71.7480602464628% |
| Symbol live recurrence | 2.1329433661260304 | 2.7889447236180906 | 0.6560013574920602 | 30.755685683465945% |
| Symbol unique total states | 3763.0 | 2191.0 | -1572.0 | -41.77517937815573% |
| Symbol unique live states | 3761.0 | 2189.0 | -1572.0 | -41.79739431002393% |
| Symbol extinct observations | 18210.0 | 20127.0 | 1917.0 | 10.527182866556837% |
| physical compression | 273.25 | 273.25 | 0.0 | 0.0% |
| physical reuse fraction | 0.9853949774901519 | 0.9910224395047833 | 0.005627462014631379 | 0.5710869390632367% |

### `packages/babel-traverse`

| Metric | Baseline | Masked | Absolute Δ | Relative Δ |
| --- | ---: | ---: | ---: | ---: |
| File survival fraction | 0.005222628850259225 | 0.005222628850259225 | 0.0 | 0.0% |
| File p90 reach | 0.0 | 0.0 | 0.0 | undefined (zero baseline) |
| File total recurrence | 2623.2 | 2623.2 | 0.0 | 0.0% |
| File live recurrence | 17.125 | 17.125 | 0.0 | 0.0% |
| File unique total states | 10.0 | 10.0 | 0.0 | 0.0% |
| File unique live states | 8.0 | 8.0 | 0.0 | 0.0% |
| File extinct observations | 26095.0 | 26095.0 | 0.0 | 0.0% |
| Symbol survival fraction | 0.3058096980786825 | 0.3050853918877707 | -7.243061909118498E-4 | -0.23684866616803346% |
| Symbol p90 reach | 0.009504565184852567 | 0.006803611147455188 | -0.002700954037397379 | -28.417439250160456% |
| Symbol total recurrence | 6.971033749667818 | 7.410169491525424 | 0.43913574185760584 | 6.299435028248593% |
| Symbol live recurrence | 2.1329433661260304 | 2.2620124364047483 | 0.12906907027871783 | 6.051218814737693% |
| Symbol unique total states | 3763.0 | 3540.0 | -223.0 | -5.926122774382142% |
| Symbol unique live states | 3761.0 | 3538.0 | -223.0 | -5.929274129220952% |
| Symbol extinct observations | 18210.0 | 18229.0 | 19.0 | 0.1043382756727073% |
| physical compression | 273.25 | 273.25 | 0.0 | 0.0% |
| physical reuse fraction | 0.9853949774901519 | 0.9857291080472707 | 3.341305571187281E-4 | 0.03390828700687866% |

### `packages/babel-helper-create-class-features-plugin`

| Metric | Baseline | Masked | Absolute Δ | Relative Δ |
| --- | ---: | ---: | ---: | ---: |
| File survival fraction | 0.005222628850259225 | 0.005222628850259225 | 0.0 | 0.0% |
| File p90 reach | 0.0 | 0.0 | 0.0 | undefined (zero baseline) |
| File total recurrence | 2623.2 | 2623.2 | 0.0 | 0.0% |
| File live recurrence | 17.125 | 17.125 | 0.0 | 0.0% |
| File unique total states | 10.0 | 10.0 | 0.0 | 0.0% |
| File unique live states | 8.0 | 8.0 | 0.0 | 0.0% |
| File extinct observations | 26095.0 | 26095.0 | 0.0 | 0.0% |
| Symbol survival fraction | 0.3058096980786825 | 0.3058096980786825 | 0.0 | 0.0% |
| Symbol p90 reach | 0.009504565184852567 | 0.009354886992965125 | -1.49678191887442E-4 | -1.5748031496062993% |
| Symbol total recurrence | 6.971033749667818 | 7.006410256410256 | 0.03537650674243853 | 0.5074786324786376% |
| Symbol live recurrence | 2.1329433661260304 | 2.1437733832175305 | 0.01083001709150011 | 0.5077498663815995% |
| Symbol unique total states | 3763.0 | 3744.0 | -19.0 | -0.5049162901939942% |
| Symbol unique live states | 3761.0 | 3742.0 | -19.0 | -0.5051847912789151% |
| Symbol extinct observations | 18210.0 | 18210.0 | 0.0 | 0.0% |
| physical compression | 273.25 | 273.25 | 0.0 | 0.0% |
| physical reuse fraction | 0.9853949774901519 | 0.9854125633089477 | 1.758581879574006E-5 | 0.00178464668457434% |

## Interpretation limits

These are deterministic structural interventions, not observed task contention or a causal claim about software quality. Total recurrence can move because extinction changes; compare live recurrence and live-state counts separately. A boundary mask changes the admitted world, not Babel source or the frozen snapshot. A region's visual prominence at depth 1–3 is separate from its depth-seven state mass.

## What this experiment says about Babel

The File panel has 26,095 extinct observations among 26,232 (99.48%). Its
2623.20× total recurrence becomes 17.125× when extinct observations and the
typed empty states are removed. None of its eight distinct live states contains
`packages/babel-types`. Masking that region changes **none** of the measured
File quantities, including survival, recurrence, p90 reach, and median physical
compression. The visible Babel dependency wall does not explain the extreme
File recurrence of this frozen 16-seed panel.

The Symbol result is different. `babel-types` occurs in 2,834 of 3,761 distinct
live Symbol states (75.35%) and 5,314 of 8,022 live Symbol observations
(66.24%). Its boundary has 2,262 admitted crossing calls and no crossing
imports. Masking those calls reduces live Symbol observations to 6,105 and
distinct live Symbol states to 2,189. Live Symbol recurrence **rises** from
2.133× to 2.789× (+30.76%); total recurrence rises from 6.971× to 11.973×
as extinction also increases. Thus `babel-types` is a strong Symbol anchor in
the observed panel, but removing its boundary does not make the remaining
Symbol behavior space less recurrent. It eliminates many distinct live states.

The sibling controls were selected without looking at their outcomes, by
closest positive crossing-edge volume. Their volumes (990 for `babel-traverse`
and 160 for `babel-helper-create-class-features-plugin`) are substantially below
the target's 2,262. They show that these two smaller masks have smaller effects;
they do not isolate the effect of anchor identity from mask size. The sample is
one frozen Babel snapshot and sixteen issue-blind seeds, so the result does not
generalize to all origins or repositories. The viewer's incoming paths at depth
1–3 and the signature's File/Symbol states at depth seven answer different
questions; directory containment alone is never an Atlas state transition.

**Next testable hypothesis:** A volume-matched mask of dispersed crossing calls
will remove a similar number of live Symbol states. Compare it with the
`babel-types` boundary mask under the same seed panel to separate edge-volume
effects from concentration around one architectural region.
