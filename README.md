# AttuneFlix

AttuneFlix maps software repositories with a small structural language.

It is a systems and research project, not a coding-agent framework. The main
object is Atlas: a fixed set of programs over definitions, imports, and calls.
Localization is one use of Atlas.

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
problems. The long-term question is therefore not only which model is best. It
is where each kind of computation belongs inside a heterogeneous executable
program: learned semantic acquisition, deterministic structural inference, or
learned discrimination. AttuneFlix is meant to measure that allocation rather
than hide it inside one large model call.

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

There is already retained evidence for this. The small frozen fixture executes
3,279 logical transitions using 30 physical transitions and 3,249 exact
reuses. In the real-repository tree-reuse study, the largest completed File
tier had 237.56× median primitive-transition compression across repositories;
repository medians ranged from 83.89× to 494.94×. Shared and independent
execution produced the same exact state maps. Issue-blind measurements also
found repository-specific behavior, such as NodeBB's broad reverse-import
propagation, before localization results were inspected.

See the [repository-signature evidence](docs/research/repository-signatures.md),
[tree reuse](docs/research/tree-reuse.md), and the
[replication study](docs/replication/README.md). The full SWE-Explore Atlas
census will produce one typed Parquet signature per unique frozen snapshot.
Only after that data is sealed will it be joined to localization outcomes.

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
        Radii.Compiled.Program / Evaluation
              region-memoized DAG
                       |
        Decide.Request -> Decide.Observation
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
- [`Radii.Compiled.Program`](src/Radii/Compiled.flix) is the shared program
  DAG; `Radii.Compiled.Evaluation` contains its query-local state arena and
  memo counts.
- [`Decide.Request`](src/Decide.flix) and `Decide.Observation` are the typed
  learned-choice boundary. This boundary will move under `Localization`
  during cleanup; its scientific request identity will not change.

Datalog does not call the physical evaluator. The physical evaluator does not
call Datalog. Tests compare them. This lets the execution representation change
without changing the definition of the relations.

`FileId`, `SymbolId`, and `LocationId` are different nominal types. Atlas and
unrestricted Radii expressions are different types. Mutable evaluator state is
region-local and cannot escape the public pure interface.

The data rule is:

```text
External formats vary.
Internal scientific datasets are Parquet.
JSON is the control plane.
Markdown is the human plane.
```

See [data architecture](docs/data-architecture.md) for the executable format
checks and current schemas.

Bazel owns declared builds, tests, and deterministic derived artifacts.
BuildBuddy remotely executes and caches that graph. Flix owns the scientific
semantics. Java and Rust are narrow foreign-runtime seams. Nix supplies the
developer shell while its former runtime responsibilities move into Bazel.

## Repository map

```text
src/                         current Flix implementation
test/                        permanent semantic laws
experiments/                 frozen protocols, Parquet results, and reports
docs/architecture/           implementation details
docs/research/               research history and interpretation
native/                      foreign runtime boundaries during migration
nix/                         pinned historical/build inputs during migration
```

The frozen 78-case study lives in
[`experiments/swe-explore-js-ts-scale/`](experiments/swe-explore-js-ts-scale/README.md).

The last complete pre-Bazel scientific checkpoint is verified with:

```console
nix develop --command ./verify
```

The target interface is ordinary Bazel:

```console
bazel test //...
bazel build //experiments/localization:replay
bazel build //experiments/atlas:signatures
bazel build //experiments/atlas:report
```

Heavy frozen experiments are explicit build targets, not part of the normal
edit/test loop.
