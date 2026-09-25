# PREREGISTRATION — AttuneFlix self-signature parallelism experiment

Status: preregistered. This file is committed as its own jj change BEFORE any
after-state structural measurement runs. The preregistration change strictly
precedes every measurement change in jj history (provable via `jj log`).

- Baseline revision (before): `bcfc126` ("read buildbuddy credential from
  environment first") — the mission's recorded starting revision, recovered
  from VCS history and evaluated in an isolated `git worktree`; never
  fabricated; the live worktree is never reset or mutated.
- Intervention: this mission's cleanup (concept deletion, one-owner-per-concept
  consolidation, tracked-Flix LOC reduction under the `< 4800` gate; amended
  pre-measurement 2026-09-25, round-3 ruling — see "Budget and reuse").
- Cleaned revision (after): recorded exactly in `REPORT.md` at measurement
  time (the sealed `reduction-completion` state plus this experiment's own
  changes).
- This preregistration revision: the jj change containing exactly this file
  (change id and commit id recorded in `REPORT.md`).

**Amended 2026-09-25 (v2, pre-measurement):** the section
"AMENDMENT — v2 acquisition" at the end of this file changes the *acquisition
system* only (v1 is the lexical/proxy measurement; v2 is Grit-acquired). The
metric set M1-M10, the region partition, the program family, and the two frozen
revisions are unchanged, and v1's measured numbers are preserved exactly.

## Hypotheses

**Primary hypothesis.** The cleanup reduces the repository's *coordination
surface* — the structural expansion/blast radii from ordinary source loci, the
overlap between neighborhoods of different semantic subsystems, and the number
of mandatory shared hotspot files — without reducing the expressive/semantic
architecture (the permanent story source -> admitted typed repository facts ->
Repository.Structure/Physical -> Radii -> Atlas -> signatures/applications is
preserved, and the frozen scientific laws are unchanged).

**Secondary hypothesis.** Subsystem boundaries align with useful parallel work
units (Repository; Radii; Atlas/signatures; Localization; tables; population;
census/experiments; tests and test infrastructure) — partitions forced by the
predefined path rule below, not optimized after seeing outcomes. If the
structure indicates better partitions, that is a finding, not a failure.

This is a descriptive architectural experiment over one repository and one
intervention. It is not causal proof, and a regression on any metric is
scientifically useful and will be reported as a finding.

## The admitted self-world (attuneflix-self-admission-v1)

AttuneFlix analyzes itself by admitting its own tracked sources into the same
typed world shape the census uses, then running the frozen Atlas machinery
(`Atlas.programsFrom`, `Atlas.evaluate`, `Repository.Physical`) over that
world. The admitted world for a revision R is derived deterministically from
R's tracked `.flix` files:

1. **Files.** The sorted list of tracked `.flix` paths at R
   (`git ls-files '*.flix' | sort`). `FileId` = index in this order.
2. **Modules.** A file's *declared module* is the maximal `[A-Za-z0-9.]` token
   following `mod `/`pub mod ` on the first line (in file order) whose trimmed
   text starts with `mod ` or `pub mod `. Files with no such line declare no
   module (root-namespace files).
3. **Code text.** All lines of a file except lines whose first non-whitespace
   characters are `//`. (Doc comments and line comments are excluded; trailing
   comments after code remain, a documented over-approximation.)
4. **Tokens.** Maximal runs of characters in `[A-Za-z0-9._]` within the code
   text.
5. **Use edge.** `(F -> G)` iff `F != G`, G declares module `M`, and some
   token `T` of F satisfies `T == M` or `T` starts with `M ++ "."`. Reaching a
   child name through its dotted path also uses the parent module name.
6. **World.** `files` = the sorted paths; `symbols` = one per declaring file
   (path = file path, name = declared module); `defines` = the one-to-one
   file/module pairs; `imports` = the use edges; `calls` = empty (symbol-level
   call structure is not derivable from this text-level admission — documented
   limitation); `parents` = empty (no Atlas atom reads parents);
   `unresolvedImports`/`unresolvedCalls` = 0.

The same instrument command, with the same definitions, produces the world for
both revisions. Facts are committed as typed Parquet using the existing
`Repository.Table` world schema (`attune-repository-world-{metadata,entities,
relations}-v1`), mirroring the `.attune` frozen-facts pattern.

## Region partition (attuneflix-regions-v1)

A pure function of the file path, fixed in advance and applied identically to
both revisions. In the first matching rule:

1. `src/Repository.flix` or prefix `src/Repository/` -> `repository`
2. `src/Radii.flix` or prefix `src/Radii/` -> `radii`
3. `src/Atlas.flix` or prefix `src/Atlas/` -> `atlas`
4. `src/Localization.flix` or prefix `src/Localization/` -> `localization`
5. `src/ScientificTable.flix` or prefix `src/ScientificTable/` -> `tables`
6. `src/Population.flix` or prefix `src/Population/` -> `population`
7. prefix `src/` -> `src-root`
8. prefix `test/` -> `tests`
9. prefix `build/src/` -> `build-src`
10. prefix `experiments/` -> `experiments`

Regions with no files at a revision are dropped from that revision's analyses.
`tests`, `build-src` are the *test-side* regions.

## Metric definitions (exact)

The program family `FAM` is `Atlas.programsFrom(File, 2)`: the 12 well-typed
composition-only Atlas programs of length <= 2 over the six frozen atoms, in
the stable enumeration order. For a file seed `{f}` or a region seed
`S_R = Files(R)`, outputs come from `Atlas.evaluate` over the admitted world.

- **M1 `tracked_files`** = number of files.
- **M2 `tracked_flix_loc`** = raw `wc -l` total over tracked `.flix` files
  (the mission LOC gate command; counted outside the instrument).
- **M3 `use_edges`** = `|imports|` in the admitted world.
- **M4 `cross_region_edge_ratio`** = `|{(f,g) in imports : region(f) != region(g)}| / |imports|`
  (0.0 when there are no edges).
- **M5 file blast radius.** `b(f) = |union of outputs of every program in FAM
  applied to {f}|`. Reported as `median` and `p90` over the multiset
  `{b(f) : f in files}`, nearest-rank: ascending sort, 0-based index
  `min(n-1, floor(p * n / 100))` for percentile `p`.
- **M6 region blast radius.** `blast(R) = max over FAM of
  |output(program, S_R)| / |S_R|`. Reported per region (artifact rows) and as
  `max_region_blast` = max over non-empty regions.
- **M7 cross-region neighborhood overlap.** `N(R) = S_R union (union of
  outputs of every program in FAM applied to S_R)` (the depth-<=2 neighborhood
  including the seed). For distinct regions A, B:
  `jaccard(A, B) = |N(A) intersect N(B)| / |N(A) union N(B)|` (0.0 when the
  union is empty). Overlap classes: high >= 0.5, medium > 0.2, low <= 0.2.
  Reported as `max_pair_jaccard` and `high_overlap_pairs` (count of pairs with
  jaccard >= 0.5).
- **M8 shared hotspots.** For a file g,
  `importing_regions(g) = |{region(f) : (f,g) in imports, region(f) != region(g)}|`.
  A *shared hotspot file* is a file with `importing_regions(g) >= 2`.
  Reported: `hotspot_count` and `max_hotspot_pressure` = max over files of
  `importing_regions(g)`.
- **M9 independently testable regions.** Region R is *independently testable*
  iff there is no use edge `(f -> g)` with `g in R`, `f not in R`, and
  `region(f)` not test-side (every non-test consumer of R's files lies inside
  R). Reported: `independently_testable` count over non-empty regions.
- **M10 worker partitions (documented heuristic; not optimal partitioning).**
  Work units = non-empty regions. `w(A, B)` (A != B) = number of use edges
  from a file of A to a file of B. Greedy agglomerative merge: start from the
  non-empty regions sorted by name; repeatedly merge the pair (A, B) with
  maximal `w(A, B) + w(B, A)` (tie broken by the lexicographically smallest
  pair of names), the merged group keeping the lexicographically smaller name,
  until `k` groups remain. Reported: `cross_group_edges_4` and
  `cross_group_edges_8` = the sum of inter-group edge counts over all distinct
  groups at k = 4 and k = 8 (if fewer than k regions are non-empty, no merge
  happens and the count is over the regions themselves).

The before/after table reports M1-M10 for both revisions, plus M11
`bazel_locality` summarized qualitatively (see the report's locality table).

## Bazel test/build locality table (report section)

Per region: its direct source surface (files), the Bazel targets that declare
it (`flix_check`/`flix_fatjar` srcs, read from the revision's BUILD files), a
bounded validation target a worker can run without the entire repository, and
shared validation hotspots (targets that compile many regions together, e.g.
the census fatjars). Derivation: deterministic reading of the declared
`srcs`/`deps` in the revision's tracked `BUILD.bazel` files; BuildBuddy cache
reuse is discussed explicitly as an execution-cost effect, not architectural
independence.

## Comparison plan

Identical instrument, identical definitions, zero redefinition between
revisions. Baseline facts are derived from the baseline worktree's files by
the committed instrument; after-state facts from the cleaned revision's
tracked files. Artifacts are committed for both revisions; the before/after
table uses only the metrics above. Any regression is reported as a finding.
Factory observations (worker sessions, ownership overlaps, reconciliation
events, validator findings) are reported from orchestrator-provided mission
records in a separate report section and never mixed into the structural
measurements.

## Artifact schemas

Typed Parquet via `ScientificTable`:

- **Region signature** (`attuneflix-parallelism-region-v1`): revision (text),
  region (text), program (text; comma-joined atom names, or `union_le2` for
  the depth-<=2 union row), depth (int32; 0 for the union row), seed_size
  (int32), result_size (int32), expansion (float64, nullable), reach (float64),
  extinct (boolean), members (list\<string>; sorted file paths of the result,
  union row includes the seed files).
- **Region pairs** (`attuneflix-parallelism-pairs-v1`): revision, region_a,
  region_b (text), union_size, intersection_size (int32), jaccard (float64).
- **World facts** for each revision: the existing
  `attune-repository-world-{metadata,entities,relations}-v1` schemas, with
  experiment identity strings `attuneflix-self-*` and the revision recorded in
  `base_revision`.

Committed artifact paths: `experiments/atlas-parallelism/facts/<revision-role>/`
(world triples) and `experiments/atlas-parallelism/artifacts/<revision-role>/`
(region + pairs tables), where `<revision-role>` is `baseline` or `after`.

## Protocol identities

- Admission/fact identity: `repository = "attuneflix"`,
  `fact_identity = repository-facts-v2 hash over the admitted self-world`,
  `source_tree_identity = "attuneflix-source-tree-v1:<revision>"`,
  `snapshot_id = repository-snapshot-v1 hash`, `base_revision = <revision>`.
- Region protocol: `attuneflix-regions-v1`; measurement protocol:
  `attuneflix-parallelism-v1`; program family: the frozen
  `atlas-composition-depth7-v1` grammar truncated at depth 2.

## Enshrinement plan and decision rule (steering addendum 2)

If — and only if — the after-state measurements satisfy ALL of the following
*pronounced-property* conditions, the measurement becomes a permanent oracle
test (an ordinary tracked test wired into the authoritative suite, plain
`./verify` runs it):

- **E1 coherence:** the minimum region coherence
  `c(R) = internal(R) / (internal(R) + outgoing(R))` (edges of R's files) over
  non-empty regions is >= 0.50.
- **E2 separation:** `max_pair_jaccard` <= 0.50 and `high_overlap_pairs` = 0.
- **E3 hotspot pressure:** `max_hotspot_pressure` <= 4 and `hotspot_count`
  <= half of `tracked_files`.
- **E4 independent validation:** `independently_testable` >= 4 regions.
- **E5 locality of change:** `median` file blast radius <= 0.5 x
  `tracked_files`.

Oracle thresholds are then fixed from the measured after-state values with
this margin policy (documented with provenance in REPORT.md): ratio/median
metrics bind at 1.5x the measured after value (2-decimal rounding);
`independently_testable` binds at the exact measured count (no region may
lose independence); `hotspot_count` binds at measured + 2;
`max_hotspot_pressure` binds at measured + 1. The oracle recomputes every
quantity in-graph from declared srcs (a deterministic facts action over the
declared tree feeds independent per-region shard actions, and one final
threshold-assertion action consumes the shard outputs), fails on a pronounced
structural regression, and is named and documented as the standing
parallelizable-monolith lint law. If the conditions do NOT hold, no oracle is
enshrined; the measured numbers and proposed threshold analysis go back to
the orchestrator.

## Budget and reuse

**Amendment (pre-measurement, 2026-09-25, round-3 user ruling — recorded in
`library/steering-memoized-evaluator.md` and
`library/parallelism-experiment-status.md`'s RESOLUTION section):** the shared
experiment Flix budget is **~450 raw Flix lines** (was ~200) and the
tracked-Flix gate is **< 4,800** (was < 4,600), cited at lines 12 and here
because both stale numbers appeared in this file. The metric set M1-M10 is
unchanged — this amendment touches constraints only, before any measurement
has run. Metric-neutral compression of the compiled instrument draft (doc
comments and row literals toward the ~350 instrument floor) is likewise
pre-measurement and metric-set-neutral.

All experiment-specific Flix (instrument + oracle assertion logic) lives in
`experiments/atlas-parallelism/` and shares one hard budget of ~450 raw Flix
lines, counted in the tracked-Flix total (< 4,800 gate). The instrument reuses
`Atlas`, `Repository`, `Repository.Physical`, `Repository.Table`,
`ScientificTable`, and `ScientificIdentity`; no new graph-analysis framework;
no permanent `src/` inflation.

---

# AMENDMENT — v2 acquisition: real Grit, actual Atlas neighborhoods

Status: **committed BEFORE the first v2 measurement** (steering 2026-09-25,
`library/experiment-genuineness-v2.md` §11 + `library/grit-language-integration.md`
§8-11). This amendment is an ancestor of every v2 measurement change in jj
history; no v2 number existed when it was committed. It changes the
**acquisition system** (a steering amendment), not the measured quantity: the
metric definitions M1-M10, the region partition `attuneflix-regions-v1`, the
program family, and the two frozen revisions are unchanged, so all four rows
stay directly comparable.

## Why the acquisition changed (v1 is a proxy, not the self-signature)

The world defined above (`attuneflix-self-admission-v1`) is a deliberately
reduced **lexical proxy**. `extract_self_facts.sh` reads `.flix` text only: one
symbol per declared module, use edges from dotted textual prefixes, `calls`
structurally empty, no Java, no Starlark, no byte ranges. It is useful and it
stays frozen exactly as measured, but it is NOT the authoritative Atlas
self-signature of AttuneFlix, and it partially punishes legitimate namespace
structure (every dotted child path also reaches its parent module name).

The authoritative acquisition is the repository's ONE source frontend: GritQL
programs under `src/grit/{defines,imports,calls}/{javascript,typescript,java,flix,starlark}.grit`
executed by the frozen hermetic Grit closure
(`getgrit/gritql @ c80b3026471b229f41b279c3eb0c162dcdacfdb1`, Flix via the one
pinned Zed grammar `omarjatoi/tree-sitter-flix @ 78cff149b2e9897456f94844872353b5ee0ca93b`),
normalizing all five languages into the ONE `Repository.Grit.Fact` protocol and
ordinary `Repository.admit`. There is no second frontend, no tree-sitter call
outside Grit, and no experiment-specific graph.

**v1 is preserved exactly** (world, artifacts, numbers, decision): it is
relabeled "v1 lexical/proxy" and reported as such. Nothing about the v1
measurement is rewritten or retroactively altered.

## The v2 admitted world (`attuneflix-grit-acquisition-v2`)

Inclusions, exact and identical for both revisions: every tracked file whose
path the closure's one detection table admits
(`Repository.Grit.language(path) != None`) — `.flix`, `.java`, `.js`/`.mjs`/
`.cjs`, `.jsx`, `.ts`/`.mts`/`.cts`, `.tsx`, `.bzl`/`.bazel`/`.star`, and the
extensionless/`.bazel` Bazel build files (`BUILD`, `BUILD.bazel`, `WORKSPACE`,
`WORKSPACE.bazel`) — **excluding** the frozen data tree `.attune/**`. The
resulting admitted list is committed verbatim per revision
(`v2/sources/<role>.sources.tsv`: path, sha256, byte length, language), which is
the exact inclusion record (`v2/README.md` documents the exclusions): frozen
data (`*.parquet`, `.attune/**`), documentation, environment/lock/JSON/TOML
plumbing, `*.rs` (the narrow native seam; Rust is not an admitted Grit target
language), `*.grit` (absent at both measured revisions), `.bazelrc` (command
line configuration, not Starlark).

`calls` and `parents` are real relations in the v2 world (`Repository.admit`
derives `parents` from the admitted paths); `defines` carries real definition
byte ranges, so symbol ownership is well defined. JS/TS: no tracked
`.js/.jsx/.ts/.tsx` exists at either revision, so those frontends contribute no
facts — recorded, not hidden.

## Acquisition execution (how the v2 facts come to exist)

The two revisions are materialized as isolated `git worktree`s (baseline
`bcfc126db7b7c7f535353ccc8afca44465903571`, cleaned
`ae2f5e68711121f8ecbf9ce94a7926ca7c7833d1`; never the live worktree, never
mutated, never fabricated). The repository's own acquisition path
(`Repository.Acquire.acquire` over the closure's frozen engine) is built by
Bazel and run over each worktree; its output is committed as typed Parquet
(`v2/grit/<role>.facts.parquet`: path, source_sha256, language, program, kind,
start_byte, end_byte, value) together with the source manifest above. The
in-graph steps then read the committed facts: ordinary `Repository.admit` ->
`Repository.World` -> `Repository.Physical` -> `Atlas.evaluate` ->
neighborhoods -> metrics. Exact reproduction commands are in `v2/README.md`.

## v2 file and region neighborhoods (the measurement path)

Per admitted file `f`: canonical file seed `Atlas.State.Files({f})` -> the
preregistered family `Atlas.programsFrom(Radii.Domain.File, 2)` -> the ACTUAL
`Atlas.evaluate` output states -> normalize to files:

- **file states** -> those files directly;
- **symbol states** -> the owning file through the canonical `DefinedIn`
  relation (a symbol has exactly one defining file in an admitted world);
- **location states** -> the File-domain family contains no Location atom, so
  no location state can occur in this measurement and no mapping is applied.
  This is documented rather than assumed: `Atlas.compatible(File)` is
  `{Defines, Imports, ImportedBy}`, none of whose targets is the Location
  domain.

`N_v2(f)` = the union of those normalized outputs. Region neighborhood
`N_v2(R) = union(N_v2(f) for f in R over the region's files)`. There is **no
handwritten BFS/DFS** over Imports/Calls in the v2 metric path: every expansion
is an `Atlas.evaluate` transition over the admitted world.

## Basis statistics vs Atlas-signature statistics (never conflated)

- **BASIS** (direct admitted-relation statistics, `world#imports`): M3
  `use_edges`, M4 `cross_region_edge_ratio`, per-region coherence, M8
  `shared_hotspots`/`hotspot_count`/`max_hotspot_pressure`, M9
  `independently_testable`, M10 `cross_group_edges_4`/`_8`.
- **ATLAS** (from actual Atlas output states): M5 `median_file_blast`/`p90`,
  M6 `max_region_blast` (+ per-region rows), M7 `max_pair_jaccard`,
  `high_overlap_pairs`, and every region-pair Jaccard.
- **COUNTS**: M1 `tracked_files`, M2 `tracked_flix_loc` (counted outside the
  instrument by the mission's verbatim LOC command).

The four-row table labels each metric's class; a BASIS value is never presented
as an Atlas signature.

## Bazel locality (separate execution/build evidence channel)

`bazel query` over the analyzed graph of each revision — target dependencies,
test ownership, `srcs` fan-out, independently runnable targets — is recorded as
a separate channel (`v2/bazel-locality/*.txt`) and reported in its own table,
compared against the source signature. It supplements and never replaces Grit
acquisition.

## Provenance (in-graph, mandatory)

The v2 measurement graph depends on the real `//src:Atlas.flix`,
`//src:Atlas/Signature.flix`, `//src:Repository/Physical.flix` and the real
admission code. A focused provenance fixture
(`//experiments/atlas-parallelism:parallelism_provenance_test`, wired into the
authoritative suite) fails unless the resulting neighborhood changes when the
Atlas program family or an admitted relation changes. If the v2 result could be
produced without Atlas, the design is wrong and is corrected, not excused.

## Enshrinement (unchanged rule, re-evaluated on v2)

E1-E5 above are re-evaluated on the **cleaned v2 world**. If they hold
pronouncedly the oracle is enshrined into the authoritative suite; if they do
not, no permanently-red test is added and the measured numbers plus the
threshold analysis are the deliverable (VAL-PARA-007 fallback). Hill-climbing
stays paused in this mission regardless of the outcome.
