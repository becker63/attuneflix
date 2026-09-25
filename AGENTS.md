# AGENTS.md

Operating manual for agents and humans working in this repository. The
README tells the research story; this file states only the operating rules
and laws. Nothing here changes what the code means.

## Canonical environment

- Non-login shells do not see the toolchain: first run
  `source /etc/profile.d/nix.sh`, then execute tools through the Nix dev
  shell from the repo root: `nix develop --command <tool>` (bazel, jj).
  Plain `rg`, `git`, and `wc` work directly.
- The toolchain is pinned: Bazel 8.6.0 via the bazelisk wrapper
  (`flake.nix`), Flix 0.76.0 (`MODULE.bazel`). No services, no ports, no
  new dependencies.

## Canonical verification

- `./verify` is the one gate. It runs the full law suite:
  `nix develop --command bazel test //... --config=buildbuddy-rbe`.
- While working, run the narrowest affected `//test:*` targets with the
  same config, batched into ONE invocation; escalate to `./verify` at
  milestones. Never run two Bazel invocations concurrently (the local
  resource caps assume exclusivity).

## Bazel authority

- Bazel is the single derivation and validation graph: every artifact and
  every law goes through a Bazel target. Keep BUILD wiring in sync with
  any file move or deletion (`test/BUILD.bazel`, `build/BUILD.bazel`
  exports, the root `tests` suite, census fatjar srcs).
- Nix is developer bootstrap only (dev shell, credential helper) — never
  project construction. Rust and Java are narrow seams (the Grit engine,
  the JVM data/provider seam), not places to host logic.

## BuildBuddy use

- Remote cache and RBE run via `--config=buildbuddy-rbe`. Aggressive reuse
  is intended: a warm cached rerun is preservation evidence, not a skipped
  check.
- The credential is `BUILDBUDDY_API_KEY` in the environment; the
  credential helper reads the env var first and the git-ignored `.env`
  file as a local fallback (see `.env.example`). Never print or commit it.
- Never run `bazel clean`, never delete local or remote caches, never
  touch the `bazel-*` / `bazel-out` symlinks.

## jj workflow

- jj is the project VCS model, colocated with git, initialized on the
  frozen checkpoint `main@bcfc126`. Use `nix develop --command jj ...`.
- Keep one coherent described change per unit of work (title + body: what
  changed, the surviving owner, laws preserved, tests run, LOC delta); end
  with `jj new` so `@` is an empty working-copy change.
- Never rewrite history at or below `main@bcfc126`; preserve scientific
  checkpoints; never push without explicit authorization.

## Layering law

```text
source -> admitted typed facts -> Repository -> Radii -> Atlas -> applications
```

- Repository holds the readable Datalog meaning (`Repository.Structure`,
  `Repository.Reference`) and the independent physical evaluator
  (`Repository.Physical`); neither calls the other — exact parity tests
  compare them, and that split is permanent.
- Radii is the typed relation algebra; Atlas is the frozen finite program
  family over it. Atlas is the project: repository signatures, the census,
  and Localization are applications of Atlas.

## Scientific no-reacquisition rules

The frozen science is never re-run or retuned because implementation
changed. Never: reacquire embeddings or Jev decisions; invoke OpenRouter or
any provider; retune iteration 013; alter the frozen localization
population, the two Three.js censors, Atlas's six directed atoms, depth
seven, Datalog meaning, or the official evaluator meaning; expose evaluator
gold to Localization; alter retained provider evidence; or create new
scientific identities from path/refactor changes. Replay stays keyless;
Atlas stays issue-, inference-, and gold-independent; exact replay and
parity laws are never weakened.

## Typed Parquet rule

Scientific data lives in content-addressed, typed Parquet under `.attune/`.
It is read-only evidence: never modify, regenerate, or hand-edit it (this
includes the frozen census parquet and REPORT.md). Scientific tables keep
explicit schemas with exact round-trips; the `*_table_test` targets guard
them.

## Tracked Flix LOC law

- Every tracked handwritten `.flix` file counts (there are no generated
  Flix files); the combined total must stay below 4,800 raw lines. The
  gate was adjusted 4,000 -> 4,300 -> 4,600 -> 4,800 by user rulings
  (2026-09-25); `< 4,800` is the single criterion. Measure with exactly:

```bash
git ls-files '*.flix' | while read -r f; do printf '%6d  %s\n' "$(wc -l < "$f")" "$f"; done | sort -rn
git ls-files '*.flix' | xargs wc -l | tail -1
```

- A tracked `.flix` file over 400 raw lines is a standing flag. User
  steering (2026-09-25) relaxed the flag for the parallelism-experiment
  instrument `experiments/atlas-parallelism/Parallelism.flix` (470 lines);
  it remains the standing limit for every other tracked Flix file.
- Reduction means fewer concepts and fewer duplicated representations —
  never minification, never semantics moved into other languages, never
  merged giant files, never deleted law tests.
