# Attune Grit frontends

This tree is the repository-visible semantic boundary for the three extracted
primitive relations: `defines`, `imports`, and `calls`. Each relation has an
explicit entry point per admitted source language. Attune derives `defined_in`,
`imported_by`, and `callers` by inversion; there are no independent inverse
extractors.

Every language emits the same `Repository.Grit.Fact` shape and flows through
ordinary Repository admission. There are no per-language fact types, and the
native host never normalizes syntax differently for Atlas: language-specific
syntax is parsed by Grit (inside the frozen closure), and `Repository.Acquire`
turns the one wire envelope into one canonical `Repository.World`.

File routing is explicit:

| Extensions | Entry point | Grit declaration |
|---|---|---|
| `.js`, `.mjs`, `.cjs` | `javascript.grit` | `language js(jsx)` |
| `.jsx` | `jsx.grit` | `language js(jsx)` |
| `.ts`, `.mts`, `.cts` | `typescript.grit` | `language js(typescript)` |
| `.tsx` | `tsx.grit` | `language js(jsx)` |
| `.java` | `java.grit` | `language java` |
| `.flix` | `flix.grit` | `language flix` |
| `.bzl`, `.bazel`, `.star` | `starlark.grit` | `language starlark` |
| `BUILD`, `BUILD.bazel`, `WORKSPACE`, `WORKSPACE.bazel` | `starlark.grit` | `language starlark` |

`Repository.language(path)` (`Repository.Grit.language`) is the one detection
table; unknown extensions are rejected before Grit runs. Every entry point
documents positive examples, exclusions, normalization, parser selection,
returned values, and the later resolver/admission responsibilities.

The extractor behavior for plain JavaScript is preserved: it is parsed by the
JSX-capable frontend, as it was in the historical 15-case run. The important
change here is that this choice and the TSX grammar are declared in files rather
than produced by a native runtime rewrite. A future switch to a different parser
is a semantic extractor change and must receive a new observation identity and a
separate experimental condition.

The three admitted languages use the pinned Grammars inside the frozen Grit
closure: Java via the upstream parser, Flix via the repository's one pinned
`omarjatoi/tree-sitter-flix` grammar (shared with Zed), and Starlark/Bazel via a
maintained Tree-sitter Starlark grammar. Tree-sitter is an implementation detail
inside Grit; it is never exposed as a second frontend to Repository or Atlas.

Flix references are actual syntax nodes, not the v1 dotted-textual-prefix proxy:
`use`/`import` declarations and qualified `type_name` nodes. Import/reference
resolution is explicit per language behind the one admission abstraction: Flix
resolves a qualified module name to the admitted file whose module path it names
(longest dotted prefix wins), Java resolves a dotted type reference to its source
file, and Starlark resolves a repository-relative file label. JavaScript/TypeScript
keep relative-path semantics. Only a unique admitted target is admitted;
ambiguous and unknown references stay conservative.

Starlark adds exactly one narrow relation-word extension: a log with kind
`dependency` for a label/dependency reference that is a real repository
dependency but not a function call, so it never enters `calls`. It is reused
consistently and admitted through the ordinary `Imports` relation like every
other reference.

The native host memoizes serialized evaluator output only when language,
program bytes, path, and source bytes are all exact matches. It retains at most
one source/result per program and path, so unchanged files are reused across
repository revisions without changing extraction semantics or allowing old
revisions to grow memory without bound.
