# AttuneFlix

AttuneFlix maps software repositories with a small structural language.

It is a systems and research project, not a coding-agent framework. The main
object is Atlas: a fixed set of programs over definitions, imports, and calls.
Localization is one use of Atlas.

## Current localization result

This is the sealed JavaScript/TypeScript SWE-Explore result at the official
five-region budget. The rows are directly comparable with each other because
they use the same cases, evaluator, region projection, and metric definitions.
They are not a claim about rank on the full multilingual benchmark.

| Frozen population and condition | Completed | Line F1 | HitFile | Context efficiency | nDCG@500 |
| --- | ---: | ---: | ---: | ---: | ---: |
| New cases: Qwen semantic prior | 61/63 | **0.1275** | 0.2156 | 0.6125 | 0.6464 |
| New cases: prior + frozen iteration 013 | 61/63 | 0.1117 | 0.2180 | 0.6518 | **0.6702** |
| New cases: structural oracle, gold-only diagnostic | 61/63 | 0.2530 | 0.2524 | 0.7989 | 0.7830 |
| Untouched validation: Qwen semantic prior | 19/21 | **0.2104** | **0.2366** | **0.8521** | **0.8133** |
| Untouched validation: prior + frozen iteration 013 | 19/21 | 0.1581 | 0.2196 | 0.8251 | 0.8107 |
| Untouched validation: structural oracle, gold-only diagnostic | 19/21 | 0.3502 | 0.2300 | 0.9621 | 0.8007 |

For scale only, the next table puts those Attune rows beside selected rows from
the SWE-Explore paper's official `K = 5` table. The metric definitions match,
but the populations do not: the paper evaluates 848 issues across ten
languages and 203 repositories, while Attune's frozen scale study is the 61
completed new cases in its JS/TS population. This is an operating-range
comparison, **not a matched leaderboard claim**. The paper drives every
agentic explorer below with GPT-5.4.

| System and population | Line F1 | HitFile | Context efficiency | nDCG@500 | Measured latency or cost evidence |
| --- | ---: | ---: | ---: | ---: | --- |
| Attune Qwen prior, 61 completed new JS/TS cases | 0.128 | 0.216 | 0.613 | 0.646 | 27.86M retained embedding input tokens; provider omitted cost and request latency |
| Attune prior + iteration 013, same 61 cases | 0.112 | 0.218 | 0.652 | 0.670 | $0.581 total Jev cost; 229.53s/case live; exact replay 57.69s cold and 1.19s warm for all 61 cases |
| Attune structural oracle, same 61 cases; gold-only diagnostic | 0.253 | 0.252 | 0.799 | 0.783 | $0 provider work; all-condition official evaluation 51.70s cold and 0.153s warm |
| BM25 | 0.024 | 0.079 | 0.087 | 0.132 | not reported |
| Claude Code | 0.202 | 0.667 | 0.829 | 0.938 | not reported |
| Codex | 0.223 | 0.649 | 0.762 | 0.901 | not reported |
| AutoCodeRover | 0.291 | 0.280 | 0.738 | 0.720 | not reported |
| LocAgent | 0.241 | 0.540 | 0.799 | 0.950 | not reported |
| CoSIL | 0.602 | 0.544 | 0.898 | 0.824 | not reported |

Source: [SWE-Explore, Table 6](https://arxiv.org/pdf/2606.07297#page=8).
The missing final column matters. The published quality rows establish the
numerical neighborhood, but they do not provide a compatible wall-clock or
provider-cost denominator. Attune therefore reports its own measured work
directly below and does not invent prices or latencies for other systems.

Iteration 013 is mixed rather than a general win: across the 61 new cases it
improved 20, tied 28, and regressed 13. It raised aggregate context efficiency
and nDCG while losing mean F1, including a clear validation regression. The
oracle is not deployable. It says that substantially better states already
exist inside the same finite Atlas family and that selection is currently the
larger accuracy problem.

Because the localization result and issue-blind census were frozen separately,
their exact snapshot identities can also be joined without retuning either one.
The [post-hoc Atlas/localization report](experiments/atlas-localization/REPORT.md)
shows the seven repository regimes and the measured relationships between
extinction, reach, recurrence, physical reuse, prior quality, selector delta,
oracle headroom, and context-efficiency delta.

The execution result is at least as important as the score:

| Measured path | Provider work | Retained tokens | Reported decision cost | Whole-process wall time |
| --- | ---: | ---: | ---: | ---: |
| Frozen iteration-013 decision acquisition, 61 cases | 3,911 Jev decisions | 14,648,740 Jev tokens | $0.581381 total; $0.009531/case | 229.53s/case |
| Exact keyless replay, migration-era sequential runner | none | no new tokens | $0 | 41.00s/case |
| Same five-case replay before retained-store load-once | none | no new tokens | $0 | 1,943.99s |
| Same five-case replay after retained-store load-once | none | no new tokens | $0 | **95.62s (20.33x faster)** |
| Exact keyless replay, 61 independent BuildBuddy actions, cold | none | no new tokens | $0 | **57.69s total; 56.35s critical path** |
| Same 61-case Bazel graph, unchanged warm rerun | none | no new tokens | $0 | **1.19s Bazel wall time** |
| Official evaluation, seven sequential bounded-lifetime shards | none | no new tokens | $0 | 4,301.12s summed wall time; 70.51s/case |
| Official evaluation, 61 independent BuildBuddy actions + aggregate, cold | none | no new tokens | $0 | **51.70s total; 51.38s critical path** |
| Same official-evaluation graph, unchanged warm rerun | none | no new tokens | $0 | **0.153s Bazel wall time** |

The semantic prior also retained 27,858,287 embedding input tokens. Its
provider returned no cost field, so total spend is correctly reported as
$0.581381 of Jev cost plus unknown embedding cost. The provider envelopes did
not retain request latency; the wall times above are complete measured
processes, not invented provider percentiles. The distributed cold replay used
62 remote actions and turned roughly 41 minutes of measured sequential case
work into less than one minute of wall time; all 61 predictions remained
exactly equal. The official evaluator then used 61 bounded per-case actions and
one aggregate action. It reproduced all prior, iteration-013, and structural-
oracle regions and metrics with exact discrete equality and the frozen `1e-10`
floating tolerance. Compared with the retained 4,301.12 seconds of sequential
shard time, the 51.70-second cold graph is an **83.2x wall-clock reduction**.
Across the same cases, 100,223 logical oracle routes became 67,354 unique
semantic states, 18,325 unique top-five region projections, and 18,386 actual
official score evaluations. Atlas did not prune a route or change an answer;
the evaluator stopped rescoring identical outcomes. The
[cold evaluation](https://app.buildbuddy.io/invocation/a3369127-dbb9-4c93-8ac0-edcdcc614e7c)
and [unchanged warm evaluation](https://app.buildbuddy.io/invocation/0bdb72c0-f5ee-4516-a9db-b817425c27fc)
show the actual remote fanout and cache reuse. The
[sealed report](experiments/swe-explore-js-ts-scale/REPORT.md)
contains every metric and case, and the [usage record](experiments/swe-explore-js-ts-scale/USAGE.md)
contains the token, cost, latency, and memory evidence.

## The pipeline

```text
source repository
    |
    v
Grit extracts definitions, imports, and calls
    |
    v
Repository gives those facts a typed meaning
    |
    v
Radii executes relational operations
    |
    v
Atlas runs a finite family of structural programs
    |
    +----> repository signature
    |
    +----> applications such as localization
```

Localization is an intelligence sandwich:

```text
broad semantic acquisition       deterministic structural compression       narrow discrimination

 issue + repository                         repository facts
          |                                       |
          v                                       v
 qwen/qwen3-embedding-8b  ----------->          Atlas          ----------->  typesafe/jev-1.13
 high-recall prior                         states + signature                 selected localization
 reusable document vectors                 no provider calls                  small typed decision
```

The first learned stage answers a broad, high-recall question. Atlas then turns
that large and noisy problem into a small set of typed structural outcomes.
The last learned stage answers a much narrower question over those outcomes.
Atlas also emits the repository signature, which remains useful when both
learned stages are removed. The existing issue-blind measurements already
separate a [statically explicit Vue core, broad reverse-import NodeBB, and a
dense zero-extinction Element snapshot](docs/research/repository-signatures.md#easy-repository-distinctions).

In compact form, the current system is close to the simplest reasonable
version of every slot:

```text
generic embedding prior
        |
        | broad semantic seeding
        v
tiny deterministic structural machine
        |
        | Atlas compression + repository signature
        v
generic cheap learned judge
```

That is the research opportunity. The prior does not need to solve
localization by itself. It needs to place probability on seeds from which
Atlas can recover useful evidence. The tail does not need to understand an
entire repository. It needs to distinguish the small set of mistakes and
alternatives Atlas leaves behind.

```text
prior learns:   what seeds does Atlas need?
Atlas computes: what structure follows, and what repeats or collapses?
tail learns:    what mistakes does Atlas make?
```

Atlas changes both neighboring learning problems into smaller, specialized
problems. More importantly, AttuneFlix is an executable program, not a diagram
of three model roles. We can run it, inspect every intermediate value, replay
it without provider access, replace one component, and measure what changed.

That makes the research question larger than “which model is best?” It asks
where each kind of computation belongs inside one heterogeneous program:
learned semantic acquisition, deterministic structural inference, or learned
discrimination. Because the allocation is explicit code, we can optimize it
for several properties at once:

- legibility and understandability;
- exact semantic correctness;
- localization quality and coverage;
- fresh-query latency and developer wall clock;
- memory use;
- provider tokens and cost;
- deterministic reuse and cacheability;
- transfer to repositories that were not used to design the program.

## Why Flix

Flix was chosen for two practical reasons.

First, this project already knew that much of scientific work can live in a
build cache. Earlier work used Buck2 extensively, then AttuneRadii moved the
same idea inside an experimental Python system with Rote. That worked:
when the deterministic boundary was honest, a fresh process replayed six real
science stages as cache hits and avoided about 202.6 seconds of work.

The hard part was not calling a cache. It was knowing which code was safe to
cache. AttuneRadii enforced a deliberately narrow Python discipline with
BasedPyright, Ruff, Fixit/LibCST architecture rules, explicit `@rote.cache`
boundaries, effect-python services, immutable values, and bans on hidden
memoization and mutation inside cached functions. This made ordinary Python
obviously cacheable, but the enforcement system itself grew into a large
experimental Python project with many concepts. It was useful science and an
unpleasant language to make agents write correctly.

Flix moves that discipline into the language. Effects say which capabilities
a function needs. Immutable values are normal. Nominal types keep repository
identities apart. Regions keep evaluator mutation local while its public
meaning stays pure. Bazel and BuildBuddy cache declared processes; Flix makes
the code inside those processes honest enough to reason about. The system can
therefore get smaller as its reuse becomes more explicit.

Second, AttuneFlix needs a language for the repository meaning itself. In
AttuneRadii, types, effects, relations, architectural lint, and cache laws were
assembled around Python because Python did not supply the semantics the work
needed. Flix already has typed Datalog, closed enums and exhaustive matching,
effects, regions, and functional data. Repository relations can be executable
definitions instead of conventions spread across classes and linters.

The short version is: I first built the missing semantics myself, then found a
mature language that would do it for me. That leaves more attention for the
actual research, and makes the program much easier to present and inspect.

And programs let us pick niche domain-specific languages for our problems.
Grit was built for structural source matching. Flix Datalog was built for
stating relations and deriving new facts. These tools already have the syntax,
semantics, type checking, and execution machinery this problem needs; a model
does not have to rediscover them inside a prompt.

Admission begins with small Grit programs. These two patterns find static
module dependencies and ordinary calls while deliberately keeping dynamic
module loading out of the call relation:

```grit
// imports/typescript.grit
// Match both ES modules and CommonJS. $source is kept as source text so the
// repository boundary can resolve it under one explicit admission policy.
or {
  `import $source`,
  `require($source)`
} as $import where {
  log(message="import", variable=$source)
}

// calls/typescript.grit
// Match the expression being called, but do not pretend module loading is a
// call edge. Constructors are a different syntax node and are excluded too.
`$callee($...)` as $call where {
  $callee <: not r"^import$",
  $callee <: not r"^require$",
  log(message="call", variable=$callee)
}
```

The complete frozen frontends are under [`src/grit/`](src/grit/). They cover named
functions, methods, arrow-function bindings, static imports, CommonJS imports,
and calls for JavaScript, JSX, TypeScript, and TSX. Grit observes syntax;
AttuneFlix assigns repository identities and admits only unambiguous edges.

The admitted facts then enter a deliberately small Datalog catalog. This is
the intended compact shape of the final Flix definition (and the current
implementation already uses these rules):

```flix
/// Source extraction admits only three directed observations:
/// a file defines a symbol, a file imports a file, and a symbol calls a symbol.
/// FileId and SymbolId are nominal types, so these domains cannot be mixed.
pub def structuralRules(): #{
    Defines(FileId, SymbolId),
    Imports(FileId, FileId),
    Calls(SymbolId, SymbolId),
    Parent(LocationId, LocationId),
    DefinedIn(SymbolId, FileId),
    ImportedBy(FileId, FileId),
    Caller(SymbolId, SymbolId),
    SameFile(SymbolId, SymbolId),
    ImportNeighbor(SymbolId, SymbolId),
    ImporterNeighbor(SymbolId, SymbolId),
    RepositoryAdjacent(LocationId, LocationId) | r
} = #{
    // Give every directed source observation its readable inverse.
    DefinedIn(symbol, file) :- Defines(file, symbol).
    ImportedBy(target, source) :- Imports(source, target).
    Caller(callee, caller) :- Calls(caller, callee).

    // Symbols are neighbors when the repository places them in one file.
    SameFile(x, y) :- Defines(file, x), Defines(file, y).

    // Follow an import from a symbol in the importing file to every symbol
    // defined by the imported file.
    ImportNeighbor(x, y) :-
        Defines(source, x),
        Imports(source, target),
        Defines(target, y).

    // The reverse direction exposes symbols in files that depend on us.
    ImporterNeighbor(x, y) :-
        Defines(target, x),
        Imports(source, target),
        Defines(source, y).

    // Directory locality is deliberately separate from source dependencies.
    // Either direction in the repository tree counts as adjacent.
    RepositoryAdjacent(x, y) :- Parent(x, y).
    RepositoryAdjacent(x, y) :- Parent(y, x).
}
```

The full executable catalog is
[`Repository.Structure`](src/Repository/Structure.flix). Its Datalog rules are
the readable definition of meaning. A separate physical evaluator implements
the same relations with indexed sets and a shared DAG. Neither implementation
calls the other; parity tests compare them. That independence is what lets us
optimize execution aggressively without turning the definition above into an
opaque performance trick.

Radii turns those named relations into a small typed algebra. The Flix
declaration is ordinary closed data, so the compiler can check every case and
the program can inspect, normalize, compile, and enumerate its own queries:

```flix
pub enum Expr with Eq, Order, ToString, Hash {
    case Atom(Atom),
    case Reverse(Expr),
    case Compose(Expr, Expr),
    case Union(Expr, Expr)
}

/// Composition is legal only when the middle domains agree.
pub def compose(first: Expr, second: Expr): Option[Expr] = {
    let (_, firstTarget) = endpoints(first);
    let (secondSource, _) = endpoints(second);
    if (firstTarget == secondSource)
        Some(normalize(Expr.Compose(first, second)))
    else
        None
}
```

The operators are ordinary computer-science operations over finite sets of
pairs. Start with two tiny relations:

```text
defines = {
    (ui/Button.tsx, Button),
    (ui/Button.tsx, renderButton)
}

calls = {
    (Button, renderButton)
}
```

Changing direction just swaps the columns:

```text
defines                         defined_in
(ui/Button.tsx, Button)    ->   (Button, ui/Button.tsx)
(ui/Button.tsx, renderButton)  (renderButton, ui/Button.tsx)
```

Putting steps in sequence joins on the middle value and removes it from the
result:

```text
defined_in                     defines
(Button, ui/Button.tsx)   >>   (ui/Button.tsx, renderButton)

result
(Button, renderButton)
```

Union is the usual OR over membership. Intersection and difference were also
measured during grammar design, so the familiar set algebra is useful even
though those two operations are not part of frozen Atlas:

| In A | In B | `A \| B` (OR) | `A & B` (AND) | `A - B` (A AND NOT B) |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 0 | 0 | 0 | 0 |
| 0 | 1 | 1 | 0 | 0 |
| 1 | 0 | 1 | 0 | 1 |
| 1 | 1 | 1 | 1 | 0 |

The only extra rule is type compatibility. It is small enough to write as a
truth table too:

| First output | Next input | Legal sequence? |
| --- | --- | ---: |
| `Symbol` | `Symbol` | 1 |
| `Symbol` | `File` | 0 |
| `File` | `Symbol` | 0 |
| `File` | `File` | 1 |

That table is what `compose` checks. It is also the whole reason the Atlas
enumerator has only three continuations at every node instead of blindly
trying all six atoms.

The earlier AttuneRadii prototype made the same algebra unusually easy to
read. After seeing the Flix type above, its notation is almost literal:

```python
defined_in = ~defines
imported_by = ~imports
callers = ~calls

same_file = defined_in >> defines
import_neighbors = defined_in >> imports >> defines
importer_neighbors = defined_in >> imported_by >> defines

repository_adjacent = parent | ~parent
```

Here `~` reverses a relation, `>>` composes two relations, and `|` takes their
union. The [migration record](docs/research/attuneradii-history.md) identifies
the archived prototype; the permanent implementation is Flix. The point of
showing both is not the Python. It is that a tiny algebra can be written down,
type checked, executed, and exhaustively explored.

“Exhaustively” is literal here. Atlas starts in the `Symbol` domain. At depth
one there are exactly three legal programs:

```text
defined_in                         Symbol -> File
calls                              Symbol -> Symbol
callers                            Symbol -> Symbol
```

At depth two, each program receives every atom accepted by its current output
domain. The next exact level contains all nine legal permutations:

```text
defined_in >> defines              Symbol -> Symbol
defined_in >> imports              Symbol -> File
defined_in >> imported_by          Symbol -> File

calls      >> defined_in           Symbol -> File
calls      >> calls                Symbol -> Symbol
calls      >> callers              Symbol -> Symbol

callers    >> defined_in           Symbol -> File
callers    >> calls                Symbol -> Symbol
callers    >> callers              Symbol -> Symbol
```

At depth three, the rule does not change. Each of those nine programs gets
three compatible continuations:

```text
defined_in >> defines     >> { defined_in, calls, callers }
defined_in >> imports     >> { defines, imports, imported_by }
defined_in >> imported_by >> { defines, imports, imported_by }

calls      >> defined_in  >> { defines, imports, imported_by }
calls      >> calls       >> { defined_in, calls, callers }
calls      >> callers     >> { defined_in, calls, callers }

callers    >> defined_in  >> { defines, imports, imported_by }
callers    >> calls       >> { defined_in, calls, callers }
callers    >> callers     >> { defined_in, calls, callers }
```

That growing tree is the frozen Atlas measurement language. The surrounding
Radii algebra is not limited to `>>`. Complete paths can themselves become
inputs to the other finite-set operations:

```text
A = defined_in >> imports     >> defines
B = defined_in >> imported_by >> defines

~A          walk the same relation in the opposite direction
A | B       symbols reached by A OR B
A & B       symbols reached by A AND B
A - B       symbols reached by A AND NOT B
```

`~`, `>>`, and `|` are the current small public Radii grammar. `&` and `-`
were exhaustive one-layer scientific challengers: both found novel states,
but neither earned a permanent public constructor. Intersection added less
oracle value than union; difference added the least value while doubling the
directed candidate space.

Recursive union is also deliberately absent from the Atlas tree. Once every
path can be ORed with every other path, the number of expressions grows much
faster than the depth table below and the census starts measuring grammar
choice as much as repository structure. Applications may use the richer Radii
operators. Repository signatures keep the smaller `>>`-only protocol so the
same complete ruler is applied to every repository.

The growth is mechanical and monotonic:

| Maximum depth | New typed programs | Cumulative typed programs | Cumulative Symbol-ending programs |
| ---: | ---: | ---: | ---: |
| 1 | 3 | 3 | 2 |
| 2 | 9 | 12 | 7 |
| 3 | 27 | 39 | 21 |
| 4 | 81 | 120 | 62 |
| 5 | 243 | 363 | 184 |
| 6 | 729 | 1,092 | 549 |
| 7 | 2,187 | 3,279 | 1,643 |

There is no search heuristic in that table. Atlas constructs every row. A
program is rejected only when its source domain does not match the previous
program's target domain. The type rule is therefore both the language
definition and the enumerator's pruning rule.

The logical tree is much larger than the work needed to execute it. First,
programs share prefixes:

```text
calls
  +-- >> defined_in
  |       +-- >> defines
  |       +-- >> imports
  |       `-- >> imported_by
  +-- >> calls
  |       +-- ...
  `-- >> callers
          +-- ...
```

The compiled evaluator stores that as a DAG. It evaluates `calls` once for a
given input state, not once for every longer program beginning with `calls`.

Second, different programs can recur at the same semantic state:

```text
logical route A ----\
                     +--> state 42 -- imported_by --> state 91
logical route B ----/                    |
                                          `-- computed once
```

`state 42` is the exact typed set of files or symbols, not a probabilistic
similarity. Once two routes produce that same set, the next identical
transition has the same input and meaning. The evaluator interns the state and
reuses the transition. This gives three distinct counts worth retaining:

```text
logical programs        what the finite language says to evaluate
unique semantic states  what the repository actually distinguishes
physical transitions    what the evaluator actually had to compute
```

The gap between them is recurrence/compression, and it is part of the
repository signature. Bazel and BuildBuddy add a separate outer layer: if the
declared snapshot, facts, Atlas program, evaluator, and protocol are unchanged,
the whole deterministic action can be reused across runs. In-process DAG reuse
and cross-run build-cache reuse are measured separately.

### Why repositories have local grammar

Code is not random. Developers repeat names, layouts, call shapes, import
directions, and ways of extending a system. A repository develops house rules.

Three older results give this idea useful footing. [On the Naturalness of
Software](https://doi.org/10.1109/ICSE.2012.6227135) found that human-written
code is much more repetitive and predictable than the space of all possible
programs. [On the Localness of
Software](https://doi.org/10.1145/2635868.2635875) found that nearby code and
the current project are even more predictable because they repeat their own
choices. [The Plastic Surgery
Hypothesis](https://doi.org/10.1145/2635868.2635898) found a related fact about
change: much of the material needed for a change already exists in the program
being changed.

AttuneFlix turns that line of thought into a machine we can run:

```text
possible programs
      |
      | human software is repetitive
      v
small regular part of program space
      |
      | each repository repeats its own local choices
      v
repository-local grammar
      |
      | run the same complete finite Atlas language
      v
extinction + expansion + reach + recurrence + reuse
      |
      v
measured repository signature
```

First, one term: a **frontier** is only the current set of files or symbols.
An Atlas atom takes one frontier and returns the next one.

Imagine this small repository:

```text
app.js                         checks.js             db.js
  handler()                      validate()            save()

app.js imports checks.js and db.js
handler calls validate and save
```

Starting from the one-symbol frontier `{handler}`, Atlas can run:

```text
{handler}
    |
    | calls
    v
{validate, save}
    |
    | defined_in
    v
{checks.js, db.js}
```

It can reach the same file frontier another way:

```text
{handler}
    |
    | defined_in
    v
{app.js}
    |
    | imports
    v
{checks.js, db.js}
```

That is enough to explain the five measurements. They are not five names for
the same idea. They look at five different levels of the run:

```text
one route ends in {}                         extinction
one step changes 1 item into 2              expansion
one result contains 2 of 200 symbols        reach
two different routes return the same set    recurrence
the evaluator avoids doing that work twice  reuse
```

The first three describe structural behavior. Recurrence compares the answers
produced by different Atlas programs. Reuse describes what the evaluator can
avoid computing because of that overlap.

#### Extinction: where does a route die?

If neither `validate` nor `save` calls another admitted symbol, then:

```text
{handler} --calls--> {validate, save} --calls--> {}
```

The route became empty after its second operation. Atlas records that first
empty depth. Once a frontier is empty, every longer continuation of that route
also stays empty: there is nothing left to follow.

Across many seeds, this produces a survival curve. If 90 of 100 seeded call
routes are already empty by depth two, call structure usually dies early. If
90 remain non-empty through depth seven, calls keep carrying Atlas through the
repository. “Extinction” therefore means exactly “this typed set is now
empty,” not a model score or a judgment about code quality.

#### Expansion: how much did this one step grow or shrink the set?

The first `calls` step above changes one symbol into two:

```text
input size       1
output size      2
expansion        2 / 1 = 2x
```

A later step might turn 50 symbols into three files, an expansion of `3 / 50`.
Atlas keeps both the raw sizes and this ratio. Expansion measures fan-out and
collapse between adjacent steps. It is local to that one arrow. It does not
care how large the whole repository is.

#### Reach: how much of the repository did the set cover?

Suppose the repository has 200 admitted symbols. Reaching `{validate, save}`
means:

```text
reached symbols     2
all symbols       200
reach             2 / 200 = 1%
```

The same two-symbol result would have 20% reach in a ten-symbol repository.
That is why Atlas stores both cardinality and normalized reach. File reach is
divided by all admitted files; Symbol reach is divided by all admitted
symbols. Directions remain separate because `imports` can stay narrow while
`imported_by` reaches most of a repository.

This is the difference between expansion and reach:

```text
expansion = output size / input size       "did this step grow?"
reach     = output size / repository size  "is this result broad here?"
```

A step can expand 10x and still have tiny reach in a large repository. A step
can also shrink and retain broad reach when its input already covered most of
the repository.

#### Recurrence: did two different routes arrive at the same set?

The example has two programs:

```text
calls      >> defined_in  = {checks.js, db.js}
defined_in >> imports     = {checks.js, db.js}
```

They are different programs but their result is the same exact typed set. The
program text is different; the answer is not. Atlas therefore records two
logical route observations and one unique semantic state. It also records how
many routes collapse onto that state and at which depths they meet.

Recurrence is a fact about the repository under the Atlas language, even if we
use a deliberately slow evaluator. High recurrence means many different
structural questions converge on the same few exact answers.

#### Reuse: once routes meet, how much work can the machine skip?

Now extend both programs with `defines`:

```text
calls      >> defined_in  --\
                               +--> {checks.js, db.js} --defines--> {validate, save}
defined_in >> imports     --/                              computed once
```

After recurrence, both routes ask the same next question: apply `defines` to
the same two-file set. The answer must be identical, so the evaluator computes
it once and reuses it. Shared route prefixes are reused for the same reason.

Reuse is therefore not another repository property hiding behind a new word.
It is the execution consequence of shared prefixes and recurrence:

```text
recurrence   two Atlas programs have the same exact typed answer
reuse        the physical evaluator notices and skips duplicate work
```

We measure both because a repository may have strong semantic recurrence
while a poor evaluator fails to exploit it. Conversely, the evaluator cannot
claim semantic recurrence merely because it cached some implementation detail.

This is how one measured MUI case reduced 3,279 logical route prefixes to 15
actual relation evaluations. The number does not mean Atlas skipped programs.
It means Atlas answered every program while noticing that most requests were
exact repeats of work it had already done.

The signature keeps these measurements separated by File/Symbol seed, route,
direction, and depth. It is a table, not one magic score:

```text
measurement  compares                                      plain question
-----------  --------------------------------------------  ------------------------------
extinction   a route result with the empty set             did the route die, and when?
expansion    one step's output with that step's input      did this arrow grow or shrink?
reach        one result with its whole typed domain        how broad is the answer here?
recurrence   outputs of different logical programs         did different routes meet?
reuse        logical requests with physical evaluations    how much repeated work was skipped?
```

The papers do not prove the last three boxes. That is the part AttuneFlix is
measuring. A repository repeatedly chooses the same package layouts, import
directions, registration hooks, caller shapes, definition placement, extension
points, and boundaries. Together those choices act like a small local grammar.
Atlas applies the same finite set of typed programs to every snapshot and
records what that repository lets the programs do.

This is not a model describing a repository. It is a program we can run again:

```text
same admitted facts
+ same Atlas protocol
+ same seed protocol
--------------------
= same signature
```

The output is inspectable all the way down. A route extinguishes because a
particular typed set became empty. A route expands because a named relation
reaches more files or symbols. Two routes recur because they produce the same
exact set. A physical transition is reused because its typed input state and
operation are identical. The signature records these events rather than
hiding them in a learned representation.

The early evidence already separates repositories with ordinary counts. MUI
was wide and modular, with many local structural islands and extreme
recurrence. Vue had a compact, regular library layout with much denser
propagation. Darkreader also had dense reach but a different profile. NodeBB
had broad static reach around a plugin system while important runtime
connections were selected through strings and conventions. These are not style
scores. Attune got them by reading source next to measured Atlas behavior. The
counts, limits, and source-level interpretations are in the
[repository-signature evidence](docs/research/repository-signatures.md).

That creates useful work outside localization. Some examples are:

- **AI-slop detector.** Agent-written code can compile and pass tests while
  ignoring the way the repository normally works. Compare a proposed diff with
  the repository's existing local grammar. If it introduces an unusual
  dependency direction, bypasses the normal extension hook, or creates a new
  disconnected island, report the exact structural break as a deterministic
  lint finding. The same check catches human-written slop. It measures
  architectural divergence; it does not guess authorship.
- **Test selection.** Use changed entities and the repository's measured
  reachability to select the tests whose structural neighborhoods can be
  affected. This could avoid running unrelated tests while retaining an
  explicit conservative fallback when the admitted graph is incomplete.
- **Repository evolution.** Compare signatures across frozen revisions to see
  which structural habits remain stable, which drift, and when a new local
  grammar appears.
- **Programming-community studies.** Apply the same ruler across related
  projects to measure repeated architectural habits without reducing the
  comparison to framework names, file counts, or subjective style labels.
- **Build and analysis planning.** Recurrence and physical compression expose
  which structural queries share work. That information can guide memoization,
  incremental analysis, and action boundaries independently of localization.

These are experiments to run, not tools AttuneFlix already ships. The census
comes first. It checks whether signatures stay stable, separate repositories,
and say more than file and symbol counts. Localization is the first application
because its evaluator lets us check whether these local grammars expose useful
code under a fixed context budget.

The frozen baseline is:

```text
qwen/qwen3-embedding-8b
    -> depth-7 Atlas
    -> typesafe/jev-1.13 iteration 013
```

The three parts have different jobs:

| Part | Input | Output | Main job |
| --- | --- | --- | --- |
| Prior | issue text and repository documents | scores over repository entities | put useful starting points near the top |
| Atlas | repository facts and starting states | structural states and a signature | expose and compress deterministic structure |
| Decision | issue and candidate outcomes | selected localization | reject the wrong Atlas outcomes |

This is a useful baseline because the endpoints were simple first choices. The
prior is a capable general embedding model. The tail is a cheap, fast general
decision model. Neither was trained specifically for the job Atlas gives it.
The middle is deterministic, typed, and cheap. That leaves a direct research
curve: improve each slice, then measure how changes interact across the whole
sandwich.

The current implementation is not yet the ideal tiny tail shown above.
Iteration 013 is a two-rollout planning portfolio. The frozen 61-case run used
3,911 Jev decisions, with a median of 71 decisions per case. Replacing that
serial planning loop with one compact outcome scorer is an experiment still to
be run, not a result already achieved.

### Where speed matters

The 3.127 ms compiled Atlas kernel is not the current bottleneck. The frozen
scale run averaged 229.53 seconds per successful acquisition case and 41.00
seconds per keyless replay case. Structural precompute inside those paths was
2.439 and 2.213 seconds respectively. Making all of that structural work five
times faster would improve the old live path by only about 1.009x and replay by
about 1.045x. Optimizing the kernel first would be busywork.

The larger win is to remove the median 71 serial learned decisions:

```text
current iteration 013

Atlas -> Jev -> Atlas -> Jev -> ... about 71 decisions

target sandwich

good cached prior -> complete Atlas outcomes -> dedupe -> one small judge
```

That changes the budget. The earlier clean structural stage averaged 98.8 ms
per case. If a future warm query uses one to three 50–200 ms judgments, a
roughly 100 ms Atlas stage becomes a visible part of latency. Reducing it to 20
ms can then matter to the whole query.

The more useful reason to make Atlas faster is not to return the same answer
two milliseconds sooner. It is to spend cheap deterministic work before the
learned call:

```text
try several diverse prior seed sets
run exact structural counterfactuals
deduplicate equal semantic outcomes
compare context budgets and projections
hand a few complete alternatives to one judge
```

The prior's job is therefore not simply “rank the edited file first.” It should
find a small, diverse seed set from which Atlas can recover useful context. A
caller or entry point can be a better seed than the final edit location when a
short reliable Atlas route connects them. Better seeds reduce the number of
distinct outcomes the tail must judge; recurrence reduces it again.

```text
better prior
    -> fewer, better structural entry points
    -> fewer distinct Atlas outcomes
    -> fewer learned decisions and fewer tokens
    -> enough latency budget for more exact counterfactuals
```

This is a future performance program, not a claim about current serving
latency. The measured source is the [sealed usage record](experiments/swe-explore-js-ts-scale/USAGE.md),
and physical-plan work is kept behind the [post-census exact-parity
protocol](experiments/atlas-swe-explore/PHYSICAL-PLANS.md).

### The next prior experiment

Atlas wants a scored field over repository entities. That field does not have
to come from an embedding API. The current Qwen bi-encoder is the clean
baseline because repository vectors depend only on source content and model
identity. They can be computed once and reused for every later issue.

The next comparison should keep that boundary and change what produces the
scores:

```text
Qwen embedding prior
    -> current cheap reusable baseline

DeepSeek direct prior
    -> ask a generative code model to score or rank entities
    -> deliberately spend more learned compute before Atlas
    -> expensive query-dependent comparison condition

DeepSeek-distilled encoder
    -> use those rankings, hard negatives, bridges, and causal judgments as
       training data
    -> return to one query vector + cached repository vectors

Atlas-aware distilled encoder
    -> train for which seeds let Atlas recover useful context
    -> do not require the seed itself to be the edited location
```

The direct condition should not ask DeepSeek to print thousands of vector
coordinates. It should produce judgments that are exposed through the same
ordered-score interface Atlas already consumes. Distillation then asks whether
that software judgment can be compiled into a small reusable embedding space.

The final objective is not simply “put the gold file first.” A semantically
obvious caller, entry point, test, or architectural anchor can be a better seed
when a short Atlas program reliably reaches the useful code. The quantity to
measure is therefore recoverability from the top `k` seeds, together with seed
diversity, unique post-Atlas outcomes, tail tokens, decisions, latency, and
cost.

This is an intentional budget shift. A larger prior is allowed to cost more
than the current embedding lookup if it removes most of iteration 013's median
71 serial Jev decisions. The target is not “large model everywhere”:

```text
more capable prior once
    -> smaller and better seed uncertainty
    -> Atlas computes the complete local structure
    -> one to three small Jev decisions, eventually perhaps one
```

When the serial learned tail shrinks that far, Atlas becomes a measurable part
of the warm path. Its physical-plan and repository-specialization work then
improves end-to-end latency instead of shaving milliseconds from a minutes-long
decision loop. Faster Atlas can also be spent on more exact seed
counterfactuals before the remaining Jev decision.

```text
issue + cached repository representations
                |
                v
      small diverse seed field
                |
                v
        exhaustive typed Atlas
                |
                v
       few unique complete outcomes
                |
                v
          one narrow judgment
```

This experiment shows the sandwich clearly. The prior learns what entrances
the deterministic program needs. Atlas performs the exact structural work.
The tail learns only how to choose among the remaining outcomes. Each boundary
stays inspectable and each expensive observation keeps a semantic cache key.

## Atlas works without AI

Atlas does not depend on Qwen, Jev, issue text, provider access, or benchmark
gold.

For one frozen repository snapshot, Atlas has:

- six directed atoms: `defines`, `defined_in`, `imports`, `imported_by`,
  `calls`, and `callers`;
- composition only;
- typed routes;
- maximum depth seven;
- a deterministic complete program family.

Radii is the larger algebra shown above. Atlas deliberately selects a smaller
measurement language from it: the six directed atoms are already named, and
Atlas enumerates `Compose` only. Reverse and union remain useful Radii
operations for application policies, but they are not silently mixed into the
repository-signature protocol.

Depth is the core of the language. One atom is one typed structural step. A
depth-two program composes exactly two compatible atoms; a depth-seven program
composes seven. Atlas does not ask a model which programs to invent and it does
not stop after a promising beam. It enumerates every well-typed composition up
to the bound in stable order.

The cleanup is moving the existing enumerator out of Localization and onto the
small public `Atlas.programs` surface. Its final Flix shape is:

```flix
/// Atlas programs contain only composition. Radii's Reverse and Union
/// constructors are intentionally absent from this bounded language.
pub type alias Program = {
    steps = Vector[Atom],
    expression = Expr
}

pub def programs(maxDepth: Int32): Vector[Program] =
    programsFrom(Domain.Symbol, maxDepth)

pub def programsFrom(seedDomain: Domain, maxDepth: Int32): Vector[Program] =
    enumerateLevels(seedDomain, current = 1, maxDepth,
        previous = Vector.empty(), all = Vector.empty())

def enumerateLevels(
    seedDomain: Domain,
    current: Int32,
    maxDepth: Int32,
    previous: Vector[Program],
    all: Vector[Program]
): Vector[Program] =
    if (current > maxDepth)
        all
    else {
        // At depth one, begin with every atom legal for the declared seed.
        let exact = if (current == 1)
            Vector.map(atom -> {
                steps = Vector#{atom},
                expression = Expr.Atom(atom)
            }, compatible(seedDomain))
        else
            // Thereafter, extend every prior program with every atom whose
            // source domain matches the program's current terminal domain.
            Vector.flatMap(program -> Vector.map(atom -> {
                steps = Vector.append(program#steps, Vector#{atom}),
                expression = Expr.Compose(program#expression, atom)
            }, compatible(target(program#expression))), previous);

        enumerateLevels(
            seedDomain,
            current + 1,
            maxDepth,
            exact,
            Vector.append(all, exact)
        )
    }

def compatible(domain: Domain): Vector[Atom] = match domain {
    case Domain.Symbol => Vector#{Atom.DefinedIn, Atom.Calls, Atom.Callers}
    case Domain.File   => Vector#{Atom.Defines, Atom.Imports, Atom.ImportedBy}
}
```

Starting from Symbols, each level has exactly three legal continuations. The
terminal domain still changes which three they are. Through depth seven this
produces 3,279 logical programs in total, of which 1,643 end in Symbols and can
be projected directly back onto the semantic prior. Those cardinalities are
frozen tests, not observations that happen to vary by repository. Repository
behavior enters only when the complete language is evaluated over its facts.

Depth seven was not picked because seven sounded sufficient. The earlier
finite-language study exhausted every Symbol-ending program at each depth. At
depth seven, 1,455 of the 1,643 programs still had distinct extensional
behavior and the family reached 218 of 233 residual-gold symbols (93.56%). The
best single fixed path improved slowly while the per-case oracle kept
improving. That moved the practical bottleneck from “invent more syntax” to
“select the useful state.” The 15 unreachable symbols are better evidence for
new admitted relations than a blind depth increase; depth eight would triple
the family again and increasingly turn local neighborhoods into structural
fog.

This is why the grammar is frozen as a protocol. Composition-only depth seven
preserves direct comparison with the original MUI/Vue/Darkreader measurement,
keeps the complete family tractable, and separates repository geometry from
the richer policy language. It is not a claim that every future Atlas
application must use composition only. The
[migration record](docs/research/attuneradii-history.md) identifies the
checkpoint containing the full depth study, counts, and rejected alternatives.

An embedding prior chooses where a localization task enters the structure. It
does not define the structure. Replacing the embedding model or removing it
entirely does not change the issue-blind repository signature.

A signature records what a repository does under the fixed Atlas programs:

- where frontiers become empty;
- where they expand;
- how much of the compatible domain they reach;
- whether forward and reverse directions behave differently;
- how often different logical routes reach the same state;
- how much logical work collapses into shared physical work.

The signature key is the repository, base revision, exact admitted-fact
identity, Atlas protocol, and signature protocol. It is a property of a frozen
repository snapshot, not a property of the model used by Localization.

### Logical programs versus physical work

The easiest way to understand recurrence and reuse is to treat Atlas as a
deliberately stupid interpreter first. A state is the exact set of Files or
Symbols currently under inspection.

A **transition** is one Atlas atom applied once to one complete typed state.
It produces the complete next state. For example, suppose the admitted call
relation contains:

```text
handler  calls  validate
handler  calls  save
validate calls  normalize
```

Then this is one transition:

```text
input state                 atom          output state
{handler, validate}  --    calls    -->  {validate, save, normalize}
```

The evaluator takes every Symbol in the input set, follows every admitted
`calls` edge leaving those Symbols, unions the answers, and returns a new
Symbol set. Whether it finds zero edges or ten thousand edges, applying
`calls` to that whole set is one primitive transition.

The word does **not** mean any of these:

```text
one source-code edge
one complete Atlas program
one model/provider call
one unit of wall-clock time
```

A length-four Atlas program requests four transitions in sequence. Each
output state becomes the next transition's input:

```text
seed
  -- imported_by --> File state
  -- defines     --> Symbol state
  -- callers     --> Symbol state
  -- defined_in  --> File state
```

Inside one frozen repository world, the exact physical transition identity is
therefore:

```text
(input typed set, atom) -> output typed set
```

The repository/world identity is fixed outside that lookup. The same atom on
a different input set is different work. A different atom on the same set is
also different work. But the same atom on the same exact typed set must return
the same exact result, so computing it twice would be pointless.

This gives the counters precise meanings:

```text
transition request   an Atlas program asks for (input state, atom)
physical transition the evaluator actually applies the relation on a cache miss
transition reuse     the exact answer already exists, so no relation is applied

requests = physical transitions + transition reuses
```

“18 shared primitive transitions” therefore means eighteen distinct
state-and-atom relation applications actually ran. It does not mean eighteen
source edges were visited, and it does not mean the whole experiment had only
eighteen logical steps.

Thousands of legal programs contain common beginnings:

```text
A = imported_by >> defines >> callers
B = imported_by >> defines >> calls
C = imported_by >> defines >> callers >> defined_in
```

An independent interpreter runs each program from its seed and repeats those
beginnings:

```text
A: imported_by COMPUTE       defines COMPUTE       callers COMPUTE
B: imported_by COMPUTE AGAIN defines COMPUTE AGAIN calls   COMPUTE
C: imported_by COMPUTE AGAIN defines COMPUTE AGAIN callers COMPUTE AGAIN ...
```

Shared execution keeps exact answers. The lookup is mechanically shaped like:

```text
(typed input state, next atom) -> typed output state
```

The earlier AttuneRadii evaluator also memoized whole expression subtrees:

```text
(typed input state, remaining expression) -> final typed output state
```

The logical language still looks like a tree because every program exists and
receives an answer. Physical execution becomes a DAG because common work has
one node:

```text
                         seed
                           |
                     imported_by
                           |
                        defines
                      /        \
                     /          \
                 callers       calls
                    |
                defined_in
```

Nothing is approximated or pruned. Independent and shared evaluation must
return the same exact state for every program. The retained tree-reuse study
checked that equality across all 208 completed experiment cells.

One historical Axios cell makes the quantities concrete. This used the
earlier 2,463-program File-ending AttuneRadii tier, not the current frozen
3,279-program six-atom Atlas census:

```text
seed: test/specs/headers.spec.js

logical programs                         2,463
independent primitive transitions        8,909
shared primitive transitions                18
transition compression                  494.94x

independent intermediate state visits    7,377
shared unique semantic states                4
state recurrence                       1,844.25x
```

All 2,463 answers still exist. The surprising result is that, on this Axios
snapshot and seed, those programs repeatedly bounce among only four actual
sets of repository entities.

In the AttuneRadii Python dialect, the measured shape is easiest to picture
like this. The middle of `programs` is omitted here only so the README stays
readable; the experiment evaluated the complete typed family:

```python
programs = (
    imports,
    imported_by,
    defines >> defined_in,
    imported_by >> imports,
    imported_by >> defines >> callers >> defined_in,
    # ...every other well-typed File program through cost seven...
)

answers = tuple(
    select(relations, program, seed)
    for program in programs
)

assert len(answers) == 2_463
assert len(set(answers)) == 4
```

`select` returns an immutable typed set. The first assertion says Atlas did
not throw programs away: every syntactically distinct program still has an
answer. The second says those 2,463 answer slots contain only four distinct
sets. Programs such as `imports`, `defines >> defined_in`, and a much longer
mixed path may look unrelated on paper, yet on this exact repository seed
they can land on the same File set. That equality is discovered by executing
the relations; it is not declared by the grammar and it is not predicted by
an embedding model.

The same language behaves differently on another repository. For Immutable's
`src/Map.js` seed:

```text
independent primitive transitions        9,264
shared primitive transitions               318       29.13x compression

independent intermediate state visits   11,733
shared unique semantic states              377       31.12x recurrence
```

This is why the measurement is more than “memoization works.” Syntax reuse is
held fixed: the same program family and evaluator are used. The repository
changes how many syntactically different programs become the same behavior:

```text
                     execute on repository
large program space -------------------------> effective behavior space

Axios       many programs -------------------> very few exact states
Immutable   many programs -------------------> a larger set of exact states
```

At that File tier, repository median transition compression ranged from
83.89x for Immutable through 177.60x for Vue and 297.51x for Preact to 494.94x
for Axios. In representative cost-seven cells, the older evaluator reported
zero direct transition-cache hits but roughly 5,900 whole-subtree hits: it
reused the larger deterministic answer before descending far enough to repeat
the individual graph operations.

These are work ratios, not wall-clock claims. The corresponding large-tier
wall-clock speedups were roughly 2.7–3.6x because traversal, hashing, state
interning, allocation, JVM work, and bookkeeping remained. That gap tells us
where implementation overhead lived in that first evaluator; it does not
weaken the exact semantic collapse being measured.

Attune later removed much of that overhead. The production Flix evaluator compiles
the fixed family once into a node DAG, interns each exact typed set into a
query-local integer arena, and stores `(compiled node, arena state)` answers in
dense region-local rows. It no longer walks a boxed expression tree or rebuilds
large result maps on the hot path:

```text
fixed logical family                    3,279 routes
compiled physical program               3,282 DAG nodes

one query:
typed repository set -> ArenaStateId
(NodeId, ArenaStateId) -> ArenaStateId
```

The later timing benchmark used a different Axios seed:
`lib/helpers/isAxiosError.js`. On that exact seed the old experiment performed
9,199 independent transitions and 168 shared transitions, or 54.76x
semantic-work compression. The old and compiled evaluators returned the exact
same result for every one of the 2,463 File-compatible programs, in the same
root order. The quiet measurements were:

```text
compiled Flix p50                         3.127 ms
same-process old evaluator p50           16.542 ms       5.29x
isolated old shared evaluator p50        29.511 ms       9.44x
isolated dense prototype p50              2.985 ms
```

So this apples-to-apples benchmark compares 54.76x fewer repository-relation
applications with a 9.44x wall-clock speedup. The remaining gap is traversal,
lookup, interning, allocation, JVM, and bookkeeping overhead. The later
implementation reached roughly tenfold wall-clock territory against the
authoritative isolated old shared measurement while staying within 4.8% of
the experimental dense kernel. It remained pure Flix and kept exact parity
with both the old evaluator and the independent Datalog meaning.

The separate 494.94x result above remains real, but it belongs to
`test/specs/headers.spec.js`: 8,909 independent transitions became 18 shared
transitions. Its retained old-evaluator wall speedup was 2.69x, not 9.44x.
These cells demonstrate different amounts of recurrence in the same Axios
snapshot; they must not be combined into one ratio. See the [compiled evaluator
record](docs/research/jev/localization.md#compiled-evaluator-interlude) and the
[per-seed tree-reuse table](docs/research/tree-reuse.md#axios).

An engineer's version of the repository-signature question is therefore:

> How many Atlas programs that look different on paper actually do the same
> work on this repository?

The programs are a fixed test signal. The repository is the circuit. Its
extinction, expansion, reach, recurrence, and reuse profile is the measured
response. No embedding model is involved in that response.

There is already retained evidence for this. The small frozen fixture executes
3,279 logical transitions using 30 physical transitions and 3,249 exact
reuses. In the real-repository tree-reuse study, the largest completed File
tier had 237.56× median primitive-transition compression across repositories;
repository medians ranged from 83.89× to 494.94×. Shared and independent
execution produced the same exact state maps. Issue-blind measurements also
found strong repository-specific behavior before localization results were
inspected:

- MUI was wide, uniform, and modular: repetitive component families formed
  many small structural islands. No primitive direction reached 50% of its
  domain in the relation census, and an extreme case collapsed 3,279 logical
  prefixes into 15 physical transitions and four unique frontiers.
- Vue core was compact and deeply interconnected: runtime, compiler,
  reactivity, and rendering modules kept non-empty frontiers alive and mixed
  rapidly through the callable universe.
- Darkreader, though represented by only two cases in that study, behaved
  much closer to Vue than MUI: dense call structure, long-lived frontiers, and
  little whole-frontier convergence.
- NodeBB later showed a different kind of density: especially broad
  reverse-import propagation around facade and plugin-hook surfaces, with
  important links also carried by configured backends and string-addressed
  client/server methods.

Those are useful facts about repository construction, not model scores. In
the source, they correspond to recognizable designs: MUI's repeated component
packages, Vue's regular runtime/compiler package system, Darkreader's dense
call structure, and NodeBB's plugin and backend indirection. Removing the
semantic prior and learned decision stage did not remove these regimes.

See the [repository-signature evidence](docs/research/repository-signatures.md),
[tree reuse](docs/research/tree-reuse.md), the
[original AttuneRadii record](docs/research/attuneradii-history.md), and the
[replication study](docs/replication/README.md). The full SWE-Explore Atlas
census now contains 78 unique frozen snapshots from 11 repositories, 1,248
seed executions, and 4,092,192 logical observations. Its [seed, schema, metric,
and analysis protocol](experiments/atlas-swe-explore/PREREGISTRATION.md) was
frozen before the census, and the [first census report](experiments/atlas-swe-explore/REPORT.md)
contains the repository and execution results. Only after this data was sealed
can it be joined to localization outcomes.

The signature may later drive execution as well as describe it. A repository
with high extinction may prefer lazy demand evaluation; repeated queries over
a small recurrent behavior space may repay a precomputed singleton basis;
dense long-lived frontiers may eventually justify a dense or materialized
plan. That is a separate exact-parity experiment, not part of the primary
census. Its [workloads, initial plans, old Roaring evidence, measurements, and
promotion rules are declared here](experiments/atlas-swe-explore/PHYSICAL-PLANS.md).

## What the frozen localization experiment found

The experiment contains 78 frozen JavaScript/TypeScript cases:

```text
15 historical development
42 expanded optimization development
21 post-optimization validation
```

Two validation cases were censored. Their unchanged 48,000-codepoint inputs
tokenized to 40,961 tokens against a 40,960-token model limit. The model,
clipping rule, and document population were not changed to force them through.

| Population | Completed | Prior F1 | Iteration 013 F1 | Structural oracle F1 |
| --- | ---: | ---: | ---: | ---: |
| Historical policy development | 15/15 | 0.0585 | 0.2015 | 0.3248 |
| Expanded optimization development | 42/42 | 0.0900 | 0.0907 | 0.2090 |
| Post-optimization validation | 19/21 | **0.2104** | 0.1581 | 0.3502 |
| All completed new cases | 61/63 | **0.1275** | 0.1117 | 0.2530 |

The result is mixed, and the validation result is a regression. Iteration 013
improved 20 of the 61 new cases, tied 28, and regressed 13. Its large
regressions outweighed its improvements in mean F1.

It did improve some other aggregate measurements on the 61 new cases:

| Metric | Prior | Iteration 013 | Structural oracle |
| --- | ---: | ---: | ---: |
| Context efficiency | 0.6125 | 0.6518 | 0.7989 |
| nDCG@100 | 0.5925 | 0.6111 | 0.7040 |
| nDCG@300 | 0.6302 | 0.6589 | 0.7783 |
| nDCG@500 | 0.6464 | 0.6702 | 0.7830 |

The structural oracle uses evaluator gold to choose the best result available
inside the same finite Atlas family. It is a diagnostic, not a deployable
localizer. The gap between the prior and oracle says useful Atlas states exist.
The gap between iteration 013 and the oracle says the current selector does not
choose them reliably. The scale run therefore supports two statements at once:

1. Atlas exposes useful structural alternatives.
2. The current learned policy does not transfer reliably enough.

That is more useful than a single win/loss number. Repository behavior is
different: NodeBB and Tutanota show different selection regimes from ProtonMail,
Element, and Docusaurus. The full tables, case rows, denominators, and censoring
are in the
[sealed scale report](experiments/swe-explore-js-ts-scale/REPORT.md).

The completed new cases used 27,858,287 embedding input tokens and 14,648,740
Jev tokens. Jev reported $0.581380884 of decision cost. The embedding provider
did not return a cost field. Provider latency was not retained, so the report
does not invent it. See the
[usage record](experiments/swe-explore-js-ts-scale/USAGE.md).

## The next research loop

The next project is to optimize the whole executable system. It is not another
prompt hill climb.

The main questions are:

```text
What should the prior make recoverable?
What should Atlas preserve?
What should the final judge distinguish?
What source context should the system return?
```

### Prior

A conventional retriever tries to rank the changed file directly. An
Atlas-aware prior can instead rank a good structural starting point. A caller,
entry point, or imported module may be useful even when the repair is several
legal Atlas steps away.

The useful training target is downstream seed value:

```text
seed + legal Atlas programs -> useful context within the budget
```

Possible conditions include generic embeddings, code embeddings,
late-interaction retrieval, direct generative-model scoring, teacher-distilled
embeddings, and an Atlas-aware prior. A model such as DeepSeek can act as a
teacher for rankings, pairwise judgments, hard negatives, and hypothetical
repairs. Distillation can keep serving cheap and preserve content-addressed
document vectors. Atlas's own counterfactual outcomes can provide a less
subjective training signal: which seeds actually made useful context
recoverable?

The prior should be measured on recall, calibration, latency, cost,
cacheability, seed diversity, and **recoverability after Atlas**. Thousands of
routes from one issue are useful supervision, but they are not thousands of
independent tasks.

### Atlas and context projection

Atlas should be measured separately on:

- availability: was a good result present in the finite family?
- selection: could a practical policy find it without gold?
- presentation: did the selected entities become useful source regions under
  the five-region budget?

Compression alone is not the objective. The system must preserve useful
alternatives while removing duplicated work. Whole functions, neighboring
declarations, tests, file diversity, deduplication, and region-budget allocation
are explicit experimental variables. They must not be changed quietly inside a
selector experiment.

The physical evaluator has a separate mechanical objective: preserve exact
outputs and public semantics while reducing time, memory, and repeated work.

### Final decision

The highest-priority architectural experiment is:

```text
cached prior
    -> complete Atlas candidate outcomes
    -> compact outcome scorer
    -> selected context
```

This asks a model to compare complete outcomes instead of making dozens of
serial navigation decisions. “Keep the prior unchanged” must be a first-class
candidate. A useful target is the value added over the prior, not agreement
with a teacher on isolated nodes.

The outcome scorer can be Jev, a code reranker, a small classifier, or a simple
feature model. Signature-only scoring and signature-plus-source scoring should
be compared directly. That tells us whether a weak model is the problem or the
interface discarded information the model needed.

### Whole-system search

An outer optimizer can search a small executable candidate artifact containing:

- encoder and document representation;
- seed and diversity budgets;
- an Atlas policy or candidate portfolio;
- source-region projection rules;
- judge configuration.

Each candidate should receive structured diagnostics, not only a mean score:

```text
what was reachable
what survived compression
what was selected
where useful context was lost
what was paid once or repeated
what failed a semantic law
```

Agent-guided search should be compared with enumerative and random search under
the same budget. Start with small factorial experiments before unrestricted
search. Keep a Pareto set over quality, fresh-query latency, provider cost,
memory, and program complexity. New systems need new held-out repositories;
the current 61 cases stop being untouched once their failure patterns guide the
design.

## Permanent implementation rules

The semantic path is intentionally short, but structural meaning has two
independent implementations by design:

```text
              Repository.Grit.Fact
                       |
                 Repository.World               Level 1
        FileId / SymbolId / LocationId
                    /     \
                   v       v
 Repository.Structure.Repository   Repository.Physical.World
       composable Datalog          typed Set execution
       reference meaning      Level 3 physical relations
              Level 2
                   \       /
               exact parity
                       |
          Radii.Evaluate.Program / Evaluation
              region-memoized DAG
                       |
       Localization.Sandwich.Judge
            -> typed Selection
```

Those labels are current Flix names, not conceptual placeholders:

- [`Repository.Grit.Fact`](src/Repository/Grit.flix) is the admitted native
  observation shape.
- [`Repository.World`](src/Repository.flix) stores the admitted basis using
  `Repository.Structure.FileId`, `SymbolId`, and `LocationId`.
- [`Repository.Structure.Repository`](src/Repository/Structure.flix) is the
  first-class constraint set; `structuralRules` is the readable Datalog
  catalog.
- [`Repository.Physical.World`](src/Repository/Physical.flix) is the indexed
  physical representation of the same relations.
- [`Radii.Evaluate.Program`](src/Radii/Evaluate.flix) is the shared program
  DAG; `Radii.Evaluate.Evaluation` contains its query-local state arena and
  memo counts.
- [`Localization.Sandwich.Judge`](src/Localization/Sandwich.flix) is the one
  typed learned-choice effect. Acquisition, replay, and fixture handlers may
  satisfy it; Atlas itself has no provider capability.

Datalog does not call the physical evaluator. The physical evaluator does not
call Datalog. Tests compare them. This lets the execution representation change
without changing the definition of the relations.

`FileId`, `SymbolId`, and `LocationId` are different nominal types. Atlas and
unrestricted Radii expressions are different types. Mutable evaluator state is
region-local and cannot escape the public pure interface.

The data rule is:

```text
External formats vary.
Every admitted scientific value is typed Parquet.
Starlark wires File artifacts and never reads scientific rows.
Markdown is the human plane.
```

See [data architecture](docs/data-architecture.md) for the executable format
checks and current schemas.

The frozen repository data plane is now 78 typed `Repository.World` artifacts
in Parquet: metadata, nominal File/Symbol/Location entities, and admitted
definitions/imports/calls. Their identity is `repository + revision + exact
JS/TS source-tree digest + Grit/Marzano protocol + admitted facts`; it contains
no Nix store path. Normal Atlas, replay, and evaluation targets read these
tables directly. The one-time migration was checked by reproducing every Atlas
census output byte-for-byte, then by passing all 61 replay and official-
evaluation parity proofs. The migration implementation is preserved in the
scientific checkpoint that performed it, not carried as dead machinery at
HEAD.

The Atlas census is a tracked Starlark graph. A public checkout can inspect and
run it without private inputs. The 61 independent replay/evaluation graph that
proved the typed migration is preserved at the named scientific checkpoints;
the resulting typed aggregate evidence is tracked with the sealed report.

Bazel owns declared builds, tests, and deterministic derived artifacts.
BuildBuddy remotely executes and caches that graph. Flix owns the scientific
semantics. Java and Rust are narrow foreign-runtime seams. Nix supplies only
the developer shell and its secret-safe Bazel wrapper. There is no
`Repository.Nix`, Nix Java FFI, libnix dependency, manual JAR staging, or Nix
expression evaluation in a build, test, replay, evaluation, or census action.

## Repository map

```text
src/                         current Flix implementation
test/                        permanent semantic laws
experiments/                 frozen protocols, Parquet results, and reports
docs/architecture/           implementation details
docs/research/               research history and interpretation
src/native/                  narrow foreign runtime boundaries
```

The frozen 78-case study lives in
[`experiments/swe-explore-js-ts-scale/`](experiments/swe-explore-js-ts-scale/README.md).

The ordinary verification command is a tiny alias for the Bazel graph:

```console
./verify
```

With Bazel already on `PATH`, no project Nix evaluation is needed:

```console
bazel test //...
bazel build //experiments/atlas-swe-explore/census:signatures
bazel build //experiments/atlas-swe-explore/census:report
```

Heavy frozen experiments are explicit build targets, not part of the normal
edit/test loop.
