# Static structural separation

Atlas Live measures possible convergence of hypothetical work origins from one
repository snapshot. It does not observe tasks, reads, writes, agent conflicts,
or scheduling. The proposed link from repository signature to structural work
capacity is a hypothesis under separate empirical study, not a measured
parallel-speedup claim.

The H1-v1 lesson in the user's research brief is decisive: a static conflict
relation did not become an actual write conflict when the workload escaped into
independent test files. The viewer therefore reports *potential convergence*,
never observed contention. Shared dependency territory may be a stable read
substrate while mutation surfaces remain separate.

## Exact definitions

The current visible frontier and enabled `imports`/`calls` relations produce
directed projected wires. A `StructuralOrigin` is a visible region or an
explicitly selected file. A region starts from all visible projected entities
physically contained beneath it, including the region itself; a file starts
from itself and any visible descendants. The origin set is excluded from its
own reachable neighborhood. Containment only chooses origin seeds: parent and
defines facts never become dependency hops. Nested regions can have overlapping
origin sets, and all pair values use those sets without correction or a
qualitative class.

Clicking a file or symbol already drawn in the fixed layout reveals its
necessary containment ancestors in one projection update. Its physical
position stays fixed; direct selection does not require manual expansion.

`N_d(s)` contains distinct visible entities reached within at most `d` directed
projected-wire hops, for `d=1,2,3`. It is cumulative: `N_1 ⊆ N_2 ⊆ N_3`.
Growth is `[|N_1|,|N_2|,|N_3|]`, with increments at degrees two and three.
Pair overlap is ordinary Jaccard intersection/union, defined as zero when
both neighborhoods are empty. Convergence depth is the first degree with a
nonempty intersection, or `>3°` (censored), never infinity.

At the selected depth and display threshold `τ`, the structural convergence
graph has one node per aggregate region and an edge for pairs with Jaccard
overlap `≥τ`. Degree-ascending greedy acceptance with stable-ID ties gives a
**greedy separated set**, not a maximum independent set. Degree-descending
greedy coloring gives **greedy structural waves**, not a chromatic number or
wall-clock schedule. The separated-set counts at degrees one, two, and three
form structural separation decay. Physical transition reuse remains the
existing depth-seven evaluator measurement and is independent of the
interactive depth and threshold.

## Computation and limits

The index is keyed by the immutable frontier projection, which incorporates
the relation mask. Selection, depth and threshold reuse its precomputed
degree-one/two/three `Uint32Array` neighborhoods. The three pair-overlap
matrices are populated once per projection, then threshold changes only scan
the matrices. If `n` visible nodes, `e` projected wires, and `m` aggregate
regions are indexed, construction uses approximately `O(e + m(n + e))` time
and `O(e + 3mn/32 + 3m²)` memory. Pair matrix construction visits `O(m²)`
region pairs and intersects only occupied bitset words. Selection comparisons
use the existing index. No file-by-file all-pairs scan is performed.

The aggregate compares at most 384 visible regions, ordered by containment
depth and stable ID; the UI reports both the included and eligible counts.
Explicitly selected files and other visible regions are still measured on
demand. This cap keeps large expanded worlds usable and is a computational
scope, not a scientific classification. The graph visually marks at most
1,500 points per pair selection, prioritizing the origins and shared
territory; the inspector retains exact counts and bounded example names.

The local `app:unit_test` benchmark on 2026-09-29 measured the following
projected frontiers. “Expanded” means the top-level region with the most
contained entities was opened; timing covers neighborhood construction and
all three pair matrices. Selection is the mean of 100 repeated pair lookups.
These are local observations, not cross-machine latency guarantees.

| World/frontier | Visible nodes | Indexed regions | Index ms | Pair matrices ms | Selection ms | Bitsets + matrices | Separation decay at τ=0.25 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| axios | 12 | 5 | 0.05 | 0.02 | 0.001 | 360 B | 3, 2, 2 |
| axios expanded | 21 | 12 | 0.12 | 0.10 | 0.001 | 1,872 B | 7, 5, 5 |
| preact | 13 | 10 | 0.06 | 0.03 | 0.001 | 1,320 B | 5, 4, 4 |
| preact expanded | 22 | 17 | 0.09 | 0.07 | <0.001 | 3,672 B | 9, 7, 7 |
| babel | 13 | 8 | 0.05 | 0.02 | 0.001 | 864 B | 4, 4, 3 |
| babel expanded | 157 | 152 | 1.44 | 5.52 | <0.001 | 286,368 B | 48, 42, 39 |

The bitset/matrix figure excludes JavaScript object and adjacency overhead.
The test prints current measurements on each run; compare that output before
making performance claims on a different host or projection.

The [frozen signature report](../../experiments/atlas-swe-explore/REPORT.md)
provides a separate depth-seven comparison. Babel's file p90 reach is 0.0000
with file extinction 0.9948 and recurrence 2,623.2×. Three.js also has low
file p90 reach (0.0524), but file extinction is 0.4673 and recurrence 4.43×;
Element's file p90 reach is 0.7062 with extinction 0.2714. Low reach can thus
coexist with very different surviving local populations. These repository
medians and the single-snapshot interactive decay rows above have different
scopes; neither establishes observed task contention.

Atlas Live requires no Git history, task trace, provider, embedding, learned
model, or change to Atlas semantics. A future empirical traffic layer should
remain separate from this static measurement.

## Reproduction

The pure laws are in `app/test/parallelism.test.ts` and run under
`//web/atlas-live/app:unit_test`. The UI interaction is exercised by the
Playwright web gate. The pinned AttuneFlix snapshot is an additional, clearly
separate world in `experiments/atlas-live-self/`; it does not change the frozen
78-world census. Its typed Grit basis is small and Bazel-declared, while
locations, signature, physical measurements and projected web data are Bazel
outputs eligible for BuildBuddy caching. Its frozen source snapshot admits
the languages supported by Repository.Grit; Rust source is not currently
admitted, and no semantic parser change is made to hide that limitation.
