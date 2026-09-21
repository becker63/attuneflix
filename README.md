# AttuneFlix

AttuneFlix is a fresh Flix implementation of the semantic core of Attune
Radii. It keeps the policy language finite and explicit, uses Flix fixpoints as
readable structural semantics, and confines Marzano/Grit to a small native
leaf.

The semantic path is intentionally short, but structural meaning has two
independent implementations by design:

```text
                     Grit
                       |
             admitted nominal facts            Level 1
                    /     \
                   v       v
       composable Datalog   physical relations
       reference meaning    typed Set execution
              Level 2       Level 3
                   \       /
                    parity
                       |
             region-memoized DAG
                       |
                     Decide
```

`Structure.flix` is the readable, authoritative specification. `Physical.flix`
stores only the four primitive relations and their inexpensive inverses; it
applies derived concepts as adjacency chains and does not materialize
same-file or import-neighbor relations. `Reference.flix` interprets complete
policy expressions directly through solved Datalog constraints. Production
evaluation calls only `Physical`; routine tests require both interpretations
to agree.

`FileId`, `SymbolId`, and `LocationId` are distinct types. Atlas and synthesis
are distinct expression types. The evaluator's mutable hash tables cannot
escape their region. Grit and Decide substitution use ordinary Flix handlers.
The compile-tested language experiments and rejected alternatives are recorded
in [NATIVE-FLIX.md](NATIVE-FLIX.md).

The first vertical slice is executable rather than schematic. `Grit.flix`
strictly decodes the versioned native JSON and projects UTF-8 byte ranges into
stable facts. `Repository.flix` conservatively admits definitions, relative
imports, lexical call owners, unambiguous call targets, and file/directory
parents. The frozen two-file Python fixture then passes through native Grit,
typed Datalog rules, issue-blind seeds, and the complete depth-7 physical Atlas
tree. Its 3,279 logical transitions collapse to 30 physical transitions and
3,249 process-local reuses.

The canonical verification command is:

```console
nix develop --command ./verify
```

That gate first builds the Nix-owned native library and generated-FFM JAR,
then runs the Rust ownership/cache tests, the Java façade lifetime and
fresh-process tests, and the Flix suite. It checks all twelve public structural names on five deterministic
repository worlds (180 atom/frontier comparisons), then exhaustively checks
all 79 normalized, well-sorted policy expressions through cost four on the
same worlds and three frontiers per source domain (1,185 complete-expression
comparisons). The Datalog cost is paid by verification and research, never by
normal policy execution.

The native seam is intentionally one sentence: Flix asks for Grit
observations; a tiny Java facade calls generated FFM bindings over a tiny Rust
C ABI; Rust owns Marzano and native lifetimes; everything returned to Flix is
stable ordinary data.

`nix build .#attune-grit-native` and `nix build .#attune-grit-jar` are the
reproducible leaf builds. The latter embeds the immutable Nix-store identity of
the former in generated `jextract` bindings; normal execution needs no ambient
`LD_LIBRARY_PATH`. Generated bindings remain build output. Rust retains
compiled Marzano problems in one private process-global cache keyed by exact
language and program bytes. The three admitted Grit programs are resources in
that same Nix-built JAR; ordinary Flix code can select only `Defines`, `Imports`,
or `Calls`, not inject arbitrary Grit source.
