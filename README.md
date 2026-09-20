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

The canonical verification command is:

```console
nix develop --command ./verify
```

That gate checks all twelve public structural names on five deterministic
repository worlds (180 atom/frontier comparisons), then exhaustively checks
all 79 normalized, well-sorted policy expressions through cost four on the
same worlds and three frontiers per source domain (1,185 complete-expression
comparisons). The Datalog cost is paid by verification and research, never by
normal policy execution.

The native seam is intentionally one sentence: Flix asks for Grit
observations; a tiny Java facade calls generated FFM bindings over a tiny Rust
C ABI; Rust owns Marzano and native lifetimes; everything returned to Flix is
stable ordinary data.
