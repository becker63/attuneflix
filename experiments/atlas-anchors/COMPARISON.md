# Structural anchors in five more Atlas Live snapshots

The Babel result in [REPORT.md](REPORT.md) used one frozen snapshot and the
unchanged 16-seed, depth-seven Atlas signature evaluator. This comparison runs
that **same Flix action** on five more snapshots already published by Atlas Live.
No repository source, frozen world, provider evidence, or Atlas definition was
changed. The typed `anchors.parquet`, `scenarios.parquet`, and full per-world
`report.md` are Bazel outputs held in BuildBuddy's remote cache and staged into
the web deployment.

| Repository | Pinned source revision | Snapshot digest | Measured boundary |
| --- | --- | --- | --- |
| AttuneFlix | `88f97599901df1be52ce8cb06f2a701c464cbbbe` | `6bae5cbc218b494824fd4dbdd23e62cdad23301dc9243ee7040a32728daef59a` | `src` |
| Three.js | `8d9f8d50b923d5f8a673590ae138bc5d86a3a256` | `c09c5aceb7270db20383531fa1c5f16b9e592b3592cabb62da376e8a9a41a872` | `src` |
| Element Web | `8c13a0f8d48441eccdd69e41e76251478bdeab8c` | `e5bfbed1587a474108acc0a043858b1b6c6f118463bcafd6344a0d6e47e4af70` | `src/components` |
| Immutable.js | `77434b3cbbc8ee21206f4cc6965e1c9b09cc92b6` | `f0d3c13774ad53f40a97c6e74c61e2705718cdd2b215560b9ede898df79c22da` | `src/predicates` |
| Preact | `b17a932342bfdeeaf1dc0fbe4f436c83e258d6c8` | `6e2bef41bf19f638be084df8cb82127e4832d4abbafa8ca20ebd5db9be3ac8a9` | `hooks` |

These are **pinned viewer snapshots**, especially AttuneFlix at `88f97599`;
they do not claim to describe the current working tree. Before reading the
outcomes, the target in each world was chosen as the non-test directory with
the greatest admitted imports-plus-calls boundary volume among directories
having at least two positive-volume sibling controls. The two controls are the
siblings nearest the target's crossing-edge volume, with path as the tie break.
Paths and snapshot identities are declared in `BUILD.bazel`, so reruns use the
same population and intervention.

## Concentration among non-empty states

Each percentage has its exact numerator and denominator in the typed artifact.
Unique mass counts distinct live semantic states; weighted mass counts live
logical observations, including repeated states. File and Symbol are separate
typed domains. Directory paths classify members; directories are not themselves
Atlas states.

| Repository · boundary | File unique mass | File weighted mass | Symbol unique mass | Symbol weighted mass |
| --- | ---: | ---: | ---: | ---: |
| AttuneFlix · `src` | 75.66% (4312/5699) | 57.16% (7509/13137) | 65.86% (2842/4315) | 48.13% (4313/8962) |
| Three.js · `src` | 51.89% (3030/5839) | 30.52% (4263/13969) | 72.92% (2536/3478) | 68.31% (6539/9573) |
| Element Web · `src/components` | 97.09% (11396/11738) | 92.80% (18042/19442) | 96.75% (9779/10108) | 94.68% (14461/15274) |
| Immutable.js · `src/predicates` | 67.46% (2287/3390) | 67.90% (6558/9658) | 64.40% (2259/3508) | 68.63% (9396/13691) |
| Preact · `hooks` | 60.14% (863/1435) | 37.55% (2405/6405) | 49.78% (225/452) | 23.81% (878/3687) |

## Boundary-mask counterfactual

The transform removes only admitted imports/calls crossing the chosen
directory boundary, then runs the **same** signature evaluator and metric
definitions. The total logical observation count remains 26,232 per domain.
Live recurrence excludes observations in the typed empty state. Values below
are baseline → target mask; the individual Bazel reports contain absolute and
relative deltas for every metric.

| Repository | Masked imports + calls | File extinct observations | File live recurrence | Symbol extinct observations | Symbol live recurrence | File / Symbol p90 reach |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| AttuneFlix | 241 + 357 | 13095 → 15625 | 2.305 → 2.555× | 17270 → 18147 | 2.077 → 2.383× | 0.1912 → 0.1581 / 0.1250 → 0.0772 |
| Three.js | 521 + 310 | 12263 → 12848 | 2.392 → 2.614× | 16659 → 16900 | 2.752 → 2.850× | 0.0509 → 0.0403 / 0.0456 → 0.0367 |
| Element Web | 2640 + 3060 | 6790 → 11173 | 1.656 → 1.907× | 10958 → 13757 | 1.511 → 1.722× | 0.7427 → 0.2788 / 0.6696 → 0.2160 |
| Immutable.js | 68 + 53 | 16574 → 17835 | 2.849 → 2.828× | 12541 → 12856 | 3.903 → 4.302× | 0.3854 → 0.3073 / 0.3964 → 0.3594 |
| Preact | 15 + 91 | 19827 → 20182 | 4.463 → 5.193× | 22545 → 22656 | 8.157 → 8.596× | 0.0228 → 0.0173 / 0.0048 → 0.0048 |

| Repository | Control 1 (masked edges; Symbol live recurrence) | Control 2 (masked edges; Symbol live recurrence) |
| --- | --- | --- |
| AttuneFlix | `experiments` (502; 2.278×) | `test` (131; 2.330×) |
| Three.js | `examples` (790; 3.846×) | `test` (545; 2.781×) |
| Element Web | `src/utils` (1758; 1.760×) | `src/stores` (1211; 1.508×) |
| Immutable.js | `src/utils` (98; 4.368×) | `src/functional` (81; 4.247×) |
| Preact | `test` (100; 11.275×) | `compat` (79; 7.722×) |

The measured boundaries are prominent in very different ways. Element Web's
`src/components` is present in nearly all live states in this panel, whereas
Three.js's `src` is much more common in live Symbol observations than File
observations. Preact's `hooks` carries a smaller share of live Symbol traffic.
All five target masks increase extinction. The first four increase live
recurrence in both typed domains. Immutable.js is more nuanced: masking
`src/predicates` **slightly lowers File live recurrence** from 2.849× to 2.828×,
while Symbol live recurrence rises from 3.903× to 4.302×. Its total File
recurrence still rises from 7.733× to 8.829× because more File observations
extinguish. This distinction is why total and live recurrence must be shown
separately. A frequently visited anchor does not, by itself, explain high
recurrence as a removable bottleneck: masks change both which states survive
and how many distinct states remain.

The sibling controls are deterministic but are not volume matched in every
world. Element Web's target cuts 5,700 dependencies against controls of 1,758
and 1,211; its large effect cannot be assigned solely to architectural
identity. These are five pinned snapshots and sixteen issue-blind seeds per
world, not all possible origins or observed engineering work.

Reproduce the typed artifacts and generated per-world reports with:

```bash
nix develop --command bazel build \
  //experiments/atlas-anchors:attuneflix \
  //experiments/atlas-anchors:three \
  //experiments/atlas-anchors:element \
  //experiments/atlas-anchors:immutable \
  //experiments/atlas-anchors:preact \
  --config=buildbuddy-rbe-arm64
```

**Next test:** compare the same total masked-edge volume dispersed across
multiple boundaries against each single-region mask. That would better separate
boundary size from concentration around one anchor.
