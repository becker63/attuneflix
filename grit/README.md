# Attune JavaScript/TypeScript Grit frontends

This tree is the repository-visible semantic boundary for the three extracted
primitive relations: `defines`, `imports`, and `calls`. Each relation has an
explicit JavaScript, JSX, TypeScript, and TSX entry point. Attune derives
`defined_in`, `imported_by`, and `callers` by inversion; there are no
independent inverse extractors.

The first scale-out condition preserves the frozen extractor behavior. Plain
JavaScript is intentionally parsed by the JSX-capable frontend, as it was in
the historical 15-case run. The important change here is that this choice and
the TSX grammar are declared in files rather than produced by a native runtime
rewrite. A future switch to a different parser is a semantic extractor change
and must receive a new observation identity and a separate experimental
condition.

File routing is explicit:

| Extensions | Entry point | Grit declaration |
|---|---|---|
| `.js`, `.mjs`, `.cjs` | `javascript.grit` | `language js(jsx)` |
| `.jsx` | `jsx.grit` | `language js(jsx)` |
| `.ts`, `.mts`, `.cts` | `typescript.grit` | `language js(typescript)` |
| `.tsx` | `tsx.grit` | `language js(jsx)` |

Unknown extensions are rejected before Grit runs. Every entry point documents
positive examples, exclusions, normalization, parser selection, returned
values, and the later resolver/admission responsibilities.

