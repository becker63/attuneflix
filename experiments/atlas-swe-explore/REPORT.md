# Frozen SWE-Explore Atlas census

This is the first issue-blind census under `atlas-signature-swe-explore-v1`
and `atlas-composition-depth7-v1`. It uses no issue text, embeddings, Jev,
evaluator gold, or provider calls. The unit is a frozen repository snapshot.

```text
manifest cases       78
unique snapshots     78
repositories         11
seed executions      1248
logical observations 4092192
summary rows         234624
```

## Repository view

Every value below is a median across represented snapshots. `Import asym.` is
depth-seven `imported_by - imports` p90 reach; `call asym.` is
`callers - calls`. Positive values mean the reverse direction reaches farther.
Recurrence is logical observations per unique exact state. Physical compression
is logical programs per actual relation evaluation.

| Repository | Snaps | Files | Symbols | Extinct F/S | Reach p90 F/S | Recurrence F/S | Import asym. | Call asym. | Physical compression | Reuse |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| NodeBB/NodeBB | 22 | 746.5 | 1470.5 | 0.7503 / 0.6132 | 0.3064 / 0.2403 | 7.0104 / 6.4322 | 0.2161 | 0.0976 | 4.7844 | 0.9691 |
| axios/axios | 2 | 120.0 | 501.0 | 0.8729 / 0.7738 | 0.0126 / 0.0768 | 30.7466 / 28.2026 | 0.0459 | 0.0016 | 16.5392 | 0.9874 |
| babel/babel | 1 | 15286.0 | 13362.0 | 0.9948 / 0.6942 | 0.0000 / 0.0095 | 2623.2000 / 6.9710 | 0.0009 | 0.0192 | 273.2500 | 0.9854 |
| element-hq/element-web | 12 | 1592.0 | 7888.5 | 0.2714 / 0.4920 | 0.7062 / 0.5952 | 2.2910 / 3.2480 | 0.1236 | 0.1348 | 2.3159 | 0.9347 |
| facebook/docusaurus | 3 | 985.0 | 5001.0 | 0.7260 / 0.7736 | 0.0103 / 0.0318 | 10.2549 / 18.6175 | 0.0036 | 0.0465 | 11.1485 | 0.9821 |
| immutable-js/immutable-js | 2 | 193.5 | 618.0 | 0.6318 / 0.4253 | 0.3825 / 0.4118 | 7.7278 / 6.5562 | -0.1266 | 0.1412 | 3.3255 | 0.9566 |
| mrdoob/three.js | 2 | 1336.0 | 16709.5 | 0.4673 / 0.7142 | 0.0524 / 0.0387 | 4.4257 / 10.2524 | 0.0531 | 0.0226 | 6.4154 | 0.9675 |
| preactjs/preact | 11 | 247.0 | 1817.0 | 0.7547 / 0.8001 | 0.0240 / 0.0122 | 16.9896 / 23.3589 | 0.0020 | 0.0133 | 13.7679 | 0.9860 |
| protonmail/webclients | 14 | 4233.0 | 11014.0 | 0.5413 / 0.5672 | 0.1212 / 0.0874 | 3.9612 / 3.8227 | 0.0303 | 0.1058 | 3.8463 | 0.9549 |
| tutao/tutanota | 5 | 1049.0 | 9600.0 | 0.5075 / 0.6513 | 0.4233 / 0.3362 | 3.7235 / 4.8876 | -0.0279 | 0.0847 | 3.5688 | 0.9556 |
| vuejs/core | 4 | 519.0 | 4201.5 | 0.6309 / 0.5344 | 0.1638 / 0.1985 | 5.5860 / 5.0923 | 0.0944 | 0.1956 | 3.8156 | 0.9605 |

## Strongest cross-repository differences

| Dimension | Lowest repository | Value | Highest repository | Value |
| --- | --- | ---: | --- | ---: |
| file extinction | element-hq/element-web | 0.2714 | babel/babel | 0.9948 |
| symbol extinction | immutable-js/immutable-js | 0.4253 | preactjs/preact | 0.8001 |
| file p90 reach | babel/babel | 0.0000 | element-hq/element-web | 0.7062 |
| symbol p90 reach | babel/babel | 0.0095 | element-hq/element-web | 0.5952 |
| file recurrence | element-hq/element-web | 2.2910 | babel/babel | 2623.2000 |
| symbol recurrence | element-hq/element-web | 3.2480 | axios/axios | 28.2026 |
| reverse-import asymmetry | immutable-js/immutable-js | -0.1266 | NodeBB/NodeBB | 0.2161 |
| caller asymmetry | axios/axios | 0.0016 | vuejs/core | 0.1956 |
| physical compression | element-hq/element-web | 2.3159 | babel/babel | 273.2500 |

These are not size aliases. File count has weak correlation with file
extinction (-0.0464) and p90 reach (-0.1939); symbol count has weak correlation
with symbol extinction (-0.2079) and p90 reach (-0.0736). File recurrence has
a stronger positive size correlation (0.6745), while symbol recurrence is
moderately negative (-0.3545). Size matters for some dimensions but does not
explain the signature.

The mechanical regimes are clear:

- Element keeps broad frontiers alive. It has the lowest file extinction,
  highest File/Symbol p90 reach, and lowest recurrence/compression.
- Babel's File-start programs almost always die or converge on the same empty
  state: 0.9948 extinction, zero p90 reach, 2623.2 logical observations per
  exact state, and 273.25 logical routes per physical relation evaluation.
- NodeBB has the strongest reverse-import asymmetry. This agrees with its
  facade, plugin-hook, configured-backend, and string-addressed protocol
  structure found by source inspection.
- Vue has the strongest caller asymmetry and the smallest multi-revision drift
  in this population. Its regular runtime/compiler/reactivity package structure
  is visible without an embedding model.
- Axios has very high recurrence and physical reuse despite being small. Many
  different programs repeatedly do the same structural work.

## Within-repository stability

The columns summarize the scale-normalized range of ten signature features
across represented revisions. Bounded fraction/asymmetry dimensions retain
their absolute range; recurrence and physical-compression ranges are divided by
their median scale. A single-snapshot repository has zero measurable drift.

| Repository | Snapshots | Mean feature range | Largest feature range |
| --- | ---: | ---: | ---: |
| NodeBB/NodeBB | 22 | 0.1687 | 0.5760 |
| axios/axios | 2 | 0.2218 | 0.8746 |
| babel/babel | 1 | 0.0000 | 0.0000 |
| element-hq/element-web | 12 | 0.2738 | 0.7734 |
| facebook/docusaurus | 3 | 0.0933 | 0.3133 |
| immutable-js/immutable-js | 2 | 0.0779 | 0.2798 |
| mrdoob/three.js | 2 | 0.1139 | 0.5295 |
| preactjs/preact | 11 | 0.4301 | 1.9413 |
| protonmail/webclients | 14 | 0.2256 | 0.6364 |
| tutao/tutanota | 5 | 0.1749 | 0.3889 |
| vuejs/core | 4 | **0.0239** | **0.1259** |

## Execution

The completed run used 78-way BuildBuddy ARM64 signature fanout followed by 78
independent summary actions. It produced 4,092,192 raw observations and 234,624
summary rows in 3m42.7s client wall time with a 221.0s Bazel critical path.
The scientific phase contained 156 remote actions. A same-daemon unchanged run
took 1.58s. A fresh output base then proved retained remote state with 284
remote-cache hits, zero remote executions, and a 1.82s action critical path;
its 48.7s client time was cold Bazel/module analysis.

The first writer repeatedly canonicalized identical large semantic states and
left Element running after 2,222s. Canonicalizing each unique exact state once
reduced Element to 162s: greater than 13.7x on the pathological shard without
changing any route, state, or output identity.

## Interpretation limits

This report describes repository response to one fixed six-atom language and
sixteen deterministic singleton seeds. It does not rank repository quality,
identify authors, or establish a localization cause. Localization relationships
are intentionally deferred until the two sealed datasets are joined as a
separately labelled post-hoc analysis.

The canonical generated artifacts are:

- `//experiments/atlas-swe-explore/census:signatures`: immutable per-snapshot raw observations;
- `//experiments/atlas-swe-explore/census:signature_summaries`: compact per-snapshot typed summaries;
- `//experiments/atlas-swe-explore/census:atlas_data`: aggregate summaries, snapshots, and physical rows;
- `//experiments/atlas-swe-explore/census:report`: this report plus typed repository summaries.
