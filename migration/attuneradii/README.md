# AttuneRadii migration source

This directory is a temporary, read-only import of the earlier AttuneRadii
working tree. It is here because AttuneRadii established the small typed
relation grammar and the first MUI/Vue/Darkreader repository-signature result
that AttuneFlix is now absorbing.

It is not a second runtime and AttuneFlix does not depend on its Python or Nix
implementation. The migration order is:

```text
AttuneRadii grammar and retained result
    -> Flix Repository / Radii / Atlas definitions
    -> Bazel targets and typed Parquet evidence
    -> differential verification
    -> delete this staging tree
```

## Provenance

- source working tree: `/home/becker/projects/attuneradii`
- Jujutsu change ID at import: `yyrtzvkvkksk`
- Git commit at import: `bf44d51098b9`
- imported payload digest: `12a9a59476b9182fd122845086c56c0838f5fe621099f9e8b7dc8d2ce5966cb9`

The digest is the SHA-256 of the sorted per-file SHA-256 listing for every
imported file except this README. The source working copy was intentionally
dirty: its uncommitted scientific record is part of what is being preserved.

Only public source, tests, specifications, and exact dependency metadata were
copied. VCS state, credentials, retained observations, caches, build output,
and local Rote state were excluded.

The most useful entry points are:

- [`src/attune_radii/algebra/query.py`](src/attune_radii/algebra/query.py): the
  compact typed operators `~`, `>>`, and `|`;
- [`src/attune_radii/algebra/structure.py`](src/attune_radii/algebra/structure.py):
  the named repository vocabulary;
- [`spec.md`](spec.md#15-search-grammars--atlas-measurement-versus-policy-synthesis):
  why Atlas deliberately uses a smaller grammar than Radii;
- [`spec.md`](spec.md#42-finite-relational-language-search--exact-evidence-through-depth-7):
  the depth-seven evidence;
- [`spec.md`](spec.md#45-structural-mixinglocalness--permanent-conceptual-model):
  the MUI/Vue/Darkreader signature result.

