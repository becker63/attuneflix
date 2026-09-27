# Atlas Live

Atlas Live is the static viewer for the frozen repository worlds and recorded Atlas
evaluations. Flix owns what the repository means; the TypeScript here only projects that
evidence into a view.

Bazel owns the whole JavaScript toolchain: Node 24.18.0 (`rules_nodejs`), pnpm 10.34.5
(`@pnpm`), the npm graph (`npm_translate_lock` over `pnpm-lock.yaml`), TypeScript 7,
Oxlint, Oxfmt and Vitest. No action uses a host `node`, `npm`, `npx` or `pnpm`, and no
`node_modules` directory exists in the source tree (`REPO.bazel` ignores any that appear).

## Layout

| Path                                                    | Contents                                                                            |
| ------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `package.json`, `pnpm-lock.yaml`, `pnpm-workspace.yaml` | The single pnpm workspace root (`hoist: false`, linux/x64/glibc only).              |
| `tsconfig.base.json`                                    | Strict compiler options shared by every package.                                    |
| `.oxlintrc.json`, `.oxfmtrc.json`                       | Lint and format configuration for all packages.                                     |
| `defs.bzl`                                              | `atlas_ts_package`: the per-package typecheck, sources, and Vitest targets.         |
| `projection/`                                           | React-free TypeScript: world Parquet to viewer graph. Runs in Node and the browser. |
| `protocol/`                                             | React-free TypeScript: viewer events, sources, and the reducer.                     |
| `app/`                                                  | React 19 application.                                                               |
| `e2e/`                                                  | Playwright specs and helpers.                                                       |
| `deploy/`                                               | `//web/atlas-live:deploy` (copy, stamp, link, publish) and its Bazel tests.         |
| `vercel/config.json`                                    | The Build Output API v3 routes `:vercel_output` ships.                              |

`projection/` and `protocol/` must not import `react`, `react-dom`, `jotai`, `@base-ui/*`,
`@stylexjs/*`, `@cosmograph/*`, `@duckdb/*`, or anything under `app/` or `e2e/`. Oxlint
enforces this (`no-restricted-imports` override), and their tsconfig `lib` has no DOM.

Packages import each other through relative paths (for example
`../../protocol/src/status.ts`). A package that is imported sets `declarations = True` in
its `BUILD.bazel`, and the importer lists it in `packages`; its typecheck then reads the
emitted `.d.ts` files, and its Vitest test gets the sources at runtime.

## Tests

```sh
source /etc/profile.d/nix.sh
nix develop --command bazel test //web/atlas-live/... --config=buildbuddy-rbe
```

`//web/atlas-live:tests` collects every check and is part of the root `//:tests` suite, so
`./verify` runs it:

| Target                                  | Check                                                                       |
| --------------------------------------- | --------------------------------------------------------------------------- |
| `//web/atlas-live:oxlint_test`          | `oxlint --type-aware --deny-warnings` over all packages                     |
| `//web/atlas-live:oxfmt_test`           | `oxfmt --check` over all packages, the deploy scripts, and the root configs |
| `//web/atlas-live:layout_test`          | Build Output API v3 shape of `:vercel_output`                               |
| `//web/atlas-live:secret_scan_test`     | Credential scan of `:vercel_output` and the bundle sources                  |
| `//web/atlas-live/<pkg>:typecheck_test` | TypeScript 7 no-emit (or declaration-only) typecheck                        |
| `//web/atlas-live/<pkg>:unit_test`      | `vitest run` (projection, protocol, app)                                    |
| `//web/atlas-live/projection:data_test` | Validates `projection:data` against `ATLAS_WORLDS`                          |

## Formatting

The nix `bazel` wrapper appends flags after user arguments, so `bazel run //t -- args`
does not work. Write a run script and call it straight away:

```sh
source /etc/profile.d/nix.sh
nix develop --command bazel run --config=buildbuddy-rbe \
  --script_path=/tmp/atlas-live-format.sh //web/atlas-live:format
/tmp/atlas-live-format.sh --write "$PWD/web/atlas-live"
```

The script runs the Bazel-provided Oxfmt 0.70.0. Pass absolute paths; the script does not
run in the current directory.

## Updating dependencies and the lockfile

`pnpm-lock.yaml` is generated only by the Bazel-hosted pnpm, never by a host `pnpm` or
`npm`. After editing `package.json` (exact versions only), from the repository root:

```sh
source /etc/profile.d/nix.sh
nix develop --command bazel run --config=buildbuddy-rbe \
  --script_path=/tmp/atlas-live-pnpm.sh @pnpm//:pnpm
/tmp/atlas-live-pnpm.sh --dir "$PWD/web/atlas-live" install --lockfile-only
```

Running the same two commands without editing `package.json` must leave
`pnpm-lock.yaml` unchanged; that is how to check the lockfile is in sync. Then run the
Formatting step (Oxfmt orders `package.json` keys) and the tests.

The full dependency set of the viewer is already installed, so features should not need
new packages. Forbidden as dependencies: Effect, RxJS, Tailwind, Next.js, Mosaic,
Storybook, a second graph renderer, and a second state library. `@duckdb/duckdb-wasm`
exists only for Cosmograph's self-hosted connection.

## Lint policy

`.oxlintrc.json` sets the `correctness` and `suspicious` categories to error and enables
the `typescript`, `unicorn`, `oxc`, `import`, `promise`, `react`, `react-perf` and
`jsx-a11y` plugins, plus the StyleX ESLint plugin through `jsPlugins`. Rules enabled on
top of the categories include:

- type-aware: `typescript/no-floating-promises`, `no-misused-promises`,
  `switch-exhaustiveness-check`, `await-thenable`, and the `no-unsafe-*` family;
- hooks: `react/rules-of-hooks` and `react/exhaustive-deps` (Oxlint's names for the
  `react-hooks` rules), and `react/no-unstable-nested-components`;
- React Compiler: `react/purity`, `refs`, `immutability`, `set-state-in-render`,
  `set-state-in-effect`, `static-components`, `globals`, `use-memo`,
  `preserve-manual-memoization`, `incompatible-library`, `unsupported-syntax`, and others;
- `import/no-cycle`, `jsx-a11y/*`, `stylex/valid-styles`, `stylex/valid-shorthands`,
  `stylex/no-unused`.

One rule is off: `react/react-in-jsx-scope`. It only applies to the classic JSX runtime,
and this project uses the automatic runtime (`"jsx": "react-jsx"`), which never needs
`React` in scope.

`react-perf/jsx-no-new-function-as-prop` is not enabled, because the React Compiler
memoizes inline callbacks. The object, array and JSX prop rules are enabled.

Close an exhaustive `switch` that returns with `default: return unreachable(value)` from
`protocol/src/unreachable.ts` (or an equivalent local helper). TypeScript then rejects a
missing case, `switch-exhaustiveness-check` still names it, and `consistent-return` is
satisfied.

Suppress a rule only on one line, name the rule, and give the reason:
`// oxlint-disable-next-line typescript/no-unsafe-assignment -- <reason>`.

## Projected world data

`//web/atlas-live/projection:data` projects all 78 census worlds (the `ATLAS_WORLDS`
list from `experiments/atlas-swe-explore/census/census.bzl`) into a content-addressed
tree:

```sh
nix develop --command bazel build //web/atlas-live/projection:data --config=buildbuddy-rbe
```

A Node CLI (`projection/src/cli.ts`, run through `js_run_binary`) stages each world's
Parquet via `copy_to_directory` from `//.attune/repository-world-v1/<digest>:world`,
projects it with `projectWorld`, and writes `data/<digest>/{metadata,entities,relations}.parquet`
(plus `locations.parquet` when a locations table is available) and a top-level
`manifest.json`. The manifest lists every world sorted by snapshot id with
`{snapshotId, snapshotDigest, repository, baseRevision, counts, assets, sha256}`; counts
satisfy `points = files + symbols + directories` with
`directories = parent - files + 1`, and `links = defines + imports + calls + parent`.
`//web/atlas-live/projection:data_test` re-checks the manifest against `ATLAS_WORLDS`,
the shipped metadata tables, and the file hashes.

## Telemetry

`aspect_tools_telemetry`, pulled in by `rules_js` and `rules_ts`, is disabled in the root
`.bazelrc` with `--repo_env=ASPECT_TOOLS_TELEMETRY=-all`. An empty value does not disable
it.

## Default world

The app loads one default world from the bundled `projection:data` tree. The choice is
fixed in `app/src/world.ts` (`DEFAULT_REPOSITORY = "preactjs/preact"`) and resolved at
runtime by `chooseDefaultWorld`: it fetches `manifest.json`, keeps the worlds whose
`repository` matches, and picks the one with the fewest `points` (ties broken by
`snapshotId`). Among the preact worlds the smallest is
`repository-snapshot-v1:6e2bef41bf19…` (`preactjs/preact@b17a9323`, 1875 points /
2683 links) — a real census world, small enough that the whole graph is legible on one
screen and the browser session stays fast. No synthetic data is used.

## `window.__atlasLive`

`window.__atlasLive` is the read-only diagnostics hook for Playwright and agent-browser. It
never contains secrets and never mutates app state; every field is a live getter, so a
reader always sees the current value. It is installed by `app/src/main.tsx` before the
session boots and populated through `app/src/diagnostics.ts`.

| Field                      | Meaning                                                                                                                                                                  |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `ready`                    | `true` once the renderer has rebuilt the graph for the current session.                                                                                                  |
| `snapshotId`               | The projected world's content-addressed snapshot id (matches `manifest.json`).                                                                                           |
| `dataset`                  | `{ repository, baseRevision, synthetic }` of the loaded world, or `null`.                                                                                                |
| `sessionRevision`          | Monotonic counter, bumped whenever a new graph replaces the current one.                                                                                                 |
| `topologyRevision`         | Monotonic counter for the projected topology (points/links) of the current session.                                                                                      |
| `overlay`                  | `{ name, revision }` of the active node-colour overlay (`"structure"` in this slice).                                                                                    |
| `counts`                   | `{ points, links, files, symbols, directories, defines, imports, calls, parent }`, or `null` before load.                                                                |
| `hovered`                  | The hovered point's identity (`domain:localId`, e.g. `file:2`), or `null`.                                                                                               |
| `hoveredIndex`             | The hovered point's row index, or `null`.                                                                                                                                |
| `highlighted`              | `{ points: string[], links: number[] }`: identities of the hovered node and its neighbours, and the indices of incident links.                                           |
| `camera`                   | `{ zoom }` of the renderer, updated on zoom (null until the first fit).                                                                                                  |
| `perf`                     | Build timings in milliseconds (`duckDbMs`, `projectionMs`, `insertMs`, …).                                                                                               |
| `buildRevision`            | The baked build revision (`__ATLAS_BUILD_REVISION__`): the deployed commit on a deployed bundle, the placeholder `__ATLAS_LIVE_BUILD_REVISION__` on a plain Bazel build. |
| `error`                    | A boot error message, or `null`.                                                                                                                                         |
| `screenPositionOf(index)`  | Viewport `[x, y]` of a point's centre, or `null` if it cannot be computed. Used to aim the real mouse.                                                                   |
| `pointWithIncidentLinks()` | A point index with at least one incident link, or `null` if none. Used to pick a hover target deterministically.                                                         |

## Preview

`//web/atlas-live:preview` serves the built static tree (`//web/atlas-live:static`) on
`127.0.0.1:4173`:

```sh
source /etc/profile.d/nix.sh
nix develop --command bazel run --config=buildbuddy-rbe \
  --script_path=/tmp/atlas-live-preview.sh //web/atlas-live:preview
/tmp/atlas-live-preview.sh --port 4173
```

The static server (`serve.mjs`) defaults its root to the sibling `static/` directory, so
the run script needs no arguments. By default it copies that tree into a fresh temp
directory and serves the copy: Bazel deletes and re-creates the `copy_to_directory` output
under the runfiles tree on every `bazel build`, which would otherwise empty a running
preview's `static/` and kill it with ENOENT mid-session. Pass `--no-snapshot` to serve the
given root in place (the e2e test does, since nothing refreshes its tree during the run).
`//web/atlas-live/e2e:e2e_test` reuses the same server inside the Playwright noble
container (`test.container-image`), runs Chromium against SwiftShader software WebGL, and
drives a real mouse over a real point.

## Styling and the linked stylesheet

Component styling is StyleX (`@stylexjs/stylex`, compiled by `@stylexjs/unplugin`). The
entry module (`app/src/main.tsx`) imports one side-effect CSS file,
`app/src/styles.css`, which carries only the globals StyleX cannot express. That import is
load-bearing: because the entry has a real CSS asset, Vite emits it as one file, links it
from `index.html`, and `@stylexjs/unplugin` appends the compiled StyleX rules to that same
asset during `generateBundle`. Without a CSS import the plugin falls back to writing
`assets/stylex.css` that nothing links, so every StyleX class is inert.

`//web/atlas-live:layout_test` (`deploy/layout_check.mjs`) enforces the contract
(VAL-STYLE-001): `index.html` must link at least one same-origin stylesheet that exists in
the output, that stylesheet must contain compiled StyleX class selectors, and every
stylesheet in the output must be linked. `//web/atlas-live/e2e:e2e_test` additionally
asserts in the browser that a stylesheet is linked, exposes parsed rules, is requested with
a `200 text/css` response, and that app-owned elements have computed styles only the
stylesheet supplies.

## Build output and deploy

`//web/atlas-live:vercel_output` wraps `//web/atlas-live:static` in the
[Build Output API](https://vercel.com/docs/build-output-api/v3) v3 layout: `config.json`
at the root (`version: 3`, then `{ "handle": "filesystem" }` and the SPA fallback
`{ "src": "/(.*)", "dest": "/index.html" }`, from `vercel/config.json`) and everything the
static tree ships under `static/`. There is no `functions/` directory: the app is static,
and Vercel never builds from source.

`//web/atlas-live:deploy` publishes that tree to Vercel project `atlas-live` in team
`becker63s-projects` and prints the production URL:

```sh
source /etc/profile.d/nix.sh
nix develop --command bazel run --config=buildbuddy-rbe \
  --script_path=/tmp/atlas-live-deploy.sh //web/atlas-live:deploy
/tmp/atlas-live-deploy.sh            # VERCEL_TOKEN must be in the environment
```

The target reads `VERCEL_TOKEN` from the environment only: never `--token`, never printed,
and every line it prints is redacted. It copies the Bazel tree into a temp directory, links
the project through a temp `.vercel/project.json`, and runs the Bazel-provided Vercel CLI
60.1.3 with `deploy --prebuilt --prod`. `HOME` is redirected into that temp directory, and
the directory is removed before the command returns, so the deploy writes nothing outside
it.

**Build revision.** The bundle is built with the literal `__ATLAS_LIVE_BUILD_REVISION__`
as its build revision (`app/vite.config.mjs`), so no Bazel action depends on a commit id
and a new commit never invalidates a cached build. `:deploy` replaces that placeholder, in
the temp copy, with the revision it resolves: `--build-revision <commit>`, else
`ATLAS_LIVE_BUILD_REVISION`, else `jj log -r @-` through the Nix dev shell. A deployed
bundle therefore reports the deployed commit from `window.__atlasLive.buildRevision`, while
a plain Bazel build reports the placeholder. `--dry-run` copies, stamps and links the
project without publishing a deployment.

**Secret scan.** `//web/atlas-live:secret_scan_test` scans the whole `:vercel_output` tree
plus the checked-in sources the bundle is built from (`app/index.html`,
`app/vite.config.mjs`, `app/src`, `projection/src`, `protocol/src`) for GitHub, Vercel,
BuildBuddy, Factory and OpenRouter credential shapes, and for those variable names bound to
a value. It reports file names, pattern names and counts only, never a matched value, and it
is part of `//web/atlas-live:tests`. To see it bite, plant a fake token (`ghp_` plus 36
alphanumeric characters) in `app/index.html` or any scanned source, rebuild, and expect the
test to fail.
