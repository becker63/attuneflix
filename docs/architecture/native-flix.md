# Native Flix pass

This pass used the pinned Flix 0.76.0 compiler and its own tests as the syntax
authority. Experimental files lived outside the repository and were removed
after the conclusions below were recorded.

## Compiler experiments

| Experiment | Flix 0.76 result | Production decision |
|---|---|---|
| Nominal repository IDs | `enum FileId(Int32)` works in fixpoint predicates; a `FileId` in a `SymbolId` position is a compile error. | Adopted. All permanent predicates carry their real endpoint types. |
| First-class schemas | Row-polymorphic facts and rule functions compose directly in `query` and `solve`. A solved/projected constraint value composes into a later stage. | Adopted. `repositoryFacts` and `structuralRules` are ordinary constraint values. |
| Restrictable policy variants | Closed constructor rows compile and reject `Union` at an Atlas-typed call site. A recursive two-constructor expression then crashes at runtime with `ClassCastException: Tag$Obj$Obj cannot be cast to Tag$Obj`. | Rejected for Flix 0.76. Atlas and synthesis use separate ordinary enums instead. |
| Region-local memoization | `region rc` with `MutHashMap`, `MutHashSet`, and `Ref` compiles as an externally pure function; returning a region-owned map is a compile error. | Adopted. No mutable value or region effect is public. |
| Grit effect | A fixture handler eliminates the capability; a native handler reinterprets it as `IO`. Calling it from a pure function is a compile error. | Adopted. Application code requests `Grit.Eval`, not arbitrary `IO`. |
| Functional predicate | `let symbol = adjacent(file, index)` works in a rule and preserves nominal types. | Valid, but not adopted as the policy backend yet; see measurement below. |
| Lattice predicate | `Cost(state; Down[Int32])` retains the minimum discovered cost and converges over a small graph. | Valid and deferred. It is promising for later minimum-cost discovery, not needed by the current evaluator. |

The supported schema conclusion is deliberately precise:

```text
FIRST-CLASS SCHEMA COMPOSITION: YES
GENERIC ROW-EXTENSION COMBINATOR: NO
```

Flix can compose independently typed fragments that share predicate names:

```flix
query repositoryFacts(...), structuralRules()
    select (x, y) from ImportNeighbor(x, y)
```

It can also solve and project one stage, then compose the resulting constraint
value with another rule stage. Flix 0.76 does not expose the absence/lacks
constraint needed to type a generic `Schema[r] -> Schema[P | r]` function when
`r` might already contain `P`. Attune does not need that record-extension model.

## Functional-predicate measurement

An isolated warmed JVM experiment used 100,000 `Defines` edges, 1,000 input
files, 10,000 output symbols, and ten measured runs. The result is directional,
not a full benchmark suite:

| Representation | Mean wall time per run |
|---|---:|
| Plain Datalog facts and join | 4.123 s |
| Datalog functional predicate over a `Map` index | 159.6 ms |
| Ordinary typed `Set` relation application | 29.1 ms |

The functional predicate was about 25.8x faster than reinjecting and joining
all facts, but about 5.5x slower than the current simple typed set scan. It does
not justify replacing the current physical evaluator. A repository-scale
benchmark should decide whether an adjacency index is worth adding.

## Permanent dual semantics

AttuneFlix has three explicit semantic levels:

1. admitted `Defines`, `Imports`, `Calls`, and `Parent` facts;
2. authoritative Flix Datalog rules in `Structure.flix`;
3. independently implemented physical relation application in
   `Physical.flix`, used by the pure memoized evaluator.

Level 2 defines what each named relation means. Level 3 determines how it runs.
The Datalog catalog never calls the physical evaluator, and the physical hot
path contains no `query` or solved constraint. The initial physical world keeps
the primitive relations and their inverses only. It computes `SameFile` as
`DefinedIn >> Defines`, import neighbors as typed three-step chains, and
repository adjacency as the union of parent and child expansion. This avoids
materializing the potentially large derived relations.

The canonical Flix suite compares both paths on five deterministic worlds that
cover empty relations, self edges, cliques, chains, cycles, fan-in/out,
disconnected components, and multiply-defined symbols. It checks:

- all 12 public names over three frontier shapes: 180 comparisons;
- all 79 normalized, well-sorted expressions through cost four over the same
  worlds and frontiers: 1,185 comparisons;
- the trusted reverse/compose/union and alias laws through a raw, non-normalizing
  Datalog interpreter;
- staged `solve ... project ...` followed by composition with later rules.

This is permanent executable specification, not migration scaffolding. A future
adjacency map, bitmap, JVM collection, or native kernel replaces only Level 3
and must pass the same Level-2 parity gate.

## Language-feature deletion audit

| Python-era mechanism | Native Flix outcome |
|---|---|
| effect-python / service protocols / dependency container | Replaced by declared effects and handlers for Grit and Decide. |
| Fixit effect-law linting | Replaced by inferred effect rows and effect subtraction in handlers. |
| Raw integer graph domains | Replaced by nominal `FileId`, `SymbolId`, and `LocationId`. |
| Domain-tagged integer states | Replaced by the closed `State.Files`, `State.Symbols`, and `State.Locations` sum. |
| Family of independent query objects | Replaced by composable first-class constraint fragments. |
| Mutable memo dictionaries in the public architecture | Replaced by region-scoped hash maps whose effect cannot escape. |
| Fixture-based service substitution | Replaced by ordinary handlers. |
| Rote source-dependency discovery | Not ported. The intended durable key is the coarse truthful tuple `KernelId, WorldId, ExprId, StateId`. |
| Runtime endpoint sorting | Retained for the dynamically enumerable synthesis language. Phantom wrappers added types but could not hide unsafe constructors; they were not an improvement. |

## Current static laws

- Atlas and synthesis expressions are different types.
- Atlas has no `Reverse` or `Union` constructor.
- Repository predicates distinguish files, symbols, and locations.
- A semantic state cannot contain members from the wrong domain.
- Policy evaluation is pure even though it uses mutable hash tables internally.
- Grit fixture handling and Decide replay are pure; only the native Grit handler exposes `IO`.
- The synthesis AST remains intentionally enumerable. Because Flix 0.76 has no
  ergonomic GADT/opaque-constructor combination for this use, its dynamic
  enumerator retains the small explicit endpoint checker.

## Native Grit packaging result

Bazel now owns the pinned Marzano adapter, its Rust tests, generated FFM
bindings, Java façade, native library, and runfiles. `rules_rust` uses a pinned
Rust toolchain and declared Cargo lock projection. A small repository rule
fetches the exact GritQL, Tree-sitter façade, GritQL grammar, and web-tree-
sitter archives with SHA-256 verification, then applies the three checked
JavaScript/TypeScript feature substitutions. A second content-addressed
repository rule supplies `jextract`; generated Java is an action output rather
than checked-in source.

Marzano's individual Tree-sitter feature flags compile, but its native
target-language constructors are still guarded by the coarse `builtin-parser`
cfg; explicit parser injection is gated to `wasm32`. Following the frozen
AttuneRadii build oracle, the Bazel repository rule projects that cfg onto the
selected JavaScript and TypeScript feature flags. Local and BuildBuddy
verification consume the same Bazel-built library. No Nix-store path,
`LD_LIBRARY_PATH`, ambient Cargo target, or manually staged JAR is part of the
runtime graph.

The JAR also carries the exact three admitted Grit programs as resources.
`Grit.Program` is a closed Flix enum, so application code cannot accidentally
turn the source-syntax boundary into an arbitrary-program capability. The raw
Java method remains available only at the low-level seam where invalid-program
classification is tested.

## First repository vertical slice

`Grit.decode` uses Flix 0.76's pure `Util.Json` parser. It rejects unknown wire
versions and malformed external shapes before admission. Fact projection uses
`String.toBytes`, selects the smallest enclosing syntax match, and reconstructs
values with `String.fromBytes`; Java UTF-16 indexes never enter the semantics.

`Repository.admit` then follows the frozen Python rules for the initial
TypeScript/JavaScript world: sorted dense identities, repository-relative
imports only, innermost lexical call ownership, local-then-global unambiguous
target resolution, and aligned file/directory locations. Missing imports and
ambiguous calls remain counted rejections rather than guessed edges.

On the frozen two-file fixture, native Grit produces five definitions, one
admitted import, one admitted call, and three parent edges. The depth-7 Atlas
walk executes all 3,279 typed prefixes and 1,643 Symbol-ending programs. Its
region-local transition memo performs 30 physical transitions and reuses 3,249
logical transitions. Datalog derives 13 same-file pairs from those same admitted
facts before the physical traversal is checked.
