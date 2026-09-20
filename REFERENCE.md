# Frozen Attune Radii reference

This implementation session froze the live reference before writing code.

- checkout: `/home/becker/projects/attuneradii`
- working-copy commit: `13312f487598` (`yyrtzvkv`), no description
- parent: `87d1137a4af3` (`kklvxxkz`), `perf: replace relation storage with PyRoaring`
- `spec.md`: 7,127 lines, SHA-256 `c906d1016e4aad5b5df5f9b6a2520f6ca2f3d706d4945b5442f1e6a46584db4f`
- Grit revision: `c80b3026471b229f41b279c3eb0c162dcdacfdb1`
- AttuneFlix toolchain pin: Flix 0.76.0 from the 2026-09-19 nixpkgs input

The working copy was dirty. The recorded `jj status` paths were:

```text
M flake.nix
M grit/typescript/calls.grit
M grit/typescript/defines.grit
M grit/typescript/imports.grit
A nix/swe-explore.nix
A spec.md
M src/_nix_ffi.py
M src/_nix_native.py
M src/attune_radii/algebra/query.py
M src/attune_radii/algebra/relation.py
M src/attune_radii/algebra/structure.py
M src/attune_radii/model.py
M src/attune_radii/nix.py
M src/attune_radii/observation.py
M src/attune_radii/policies/radii.py
M src/attune_radii/routing.py
M src/attune_radii/world.py
M tests/conftest.py
M tests/test_algebra.py
M tests/test_atlas.py
M tests/test_nix.py
M typings/rote/__init__.pyi
```

Important frozen oracle laws:

- depth-7 Atlas: 3,279 cumulative typed non-root prefixes and 1,643
  `Symbol -> Symbol` programs;
- public vocabulary: 12 names / 11 exact atoms because `calls == callees`;
- resolver admission is conservative: unresolved imports and ambiguous calls do
  not become edges;
- nested calls such as `Boolean(verify(name))` retain both projected matches;
- byte offsets are UTF-8 byte offsets, not character indexes;
- Atlas is composition-only; synthesis separately admits reverse,
  composition, and union under the public cost model.

Semantic source hashes are recorded below so later concurrent edits are not
silently chased:

```text
defines.grit  4c63ff6f2fba9e2584aa3a2fc5b511b84a2a29842ca6ee86d083e4ccd968a172
imports.grit  368c1c09ed1ba38437ddab45d1084710cb717adc8dc0c831e3b2e8c49f3ad14d
calls.grit    1a60e5914a860ae22770f9cc73c6f3158082c808992503920ea71959f992254a
query.py      429b3d2df7f7a2e5a5576551e83d6374d6743b261dce439f555d71c2eccfbe8c
relation.py   2305bc49efe7110b25beb1f8f190bfcec9b298b010c985f26103616ce844af38
structure.py  ba670bc7f3a9991e033fea171838f5217d89aa7e03a545d0342943ee5c125573
world.py      5baf77a2dfb2875777b51e06157bfad0fa15603ad9a10a86b6cadabea8286da0
test_algebra  c6ef844a9ef263b69c9173e90ad771838b083aec921d966474f7b645fffb1b6f
test_atlas    40b6ca932db80aa44e5d10da6f21f8b3260f58d8957d47f31a31cf87272ded79
```
