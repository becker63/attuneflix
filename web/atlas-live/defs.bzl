"""One macro for every Atlas Live TypeScript package (projection, protocol, app, e2e)."""

load("@aspect_rules_js//js:defs.bzl", "js_library")
load("@aspect_rules_ts//ts:defs.bzl", "ts_config", "ts_project")
load("@npm//web/atlas-live:vitest/package_json.bzl", vitest_bin = "bin")

def _nm(pkg):
    return "//web/atlas-live:node_modules/" + pkg

def atlas_ts_package(
        npm_deps = [],
        packages = [],
        declarations = False,
        unit_test = True,
        test_data = [],
        test_env = {},
        test_size = "small"):
    """Declares the checked sources, the typecheck test, and the Vitest unit test of a package.

    Targets:
      :srcs            js_library of src/ (bin copies owned by this package), for runtime
                       consumers (Vitest, Vite) of this package and of packages importing it
      :test_srcs       js_library of test/
      :ts              ts_project over src/ and test/ (TypeScript 7 native, strict)
      :typecheck_test  the typecheck of :ts as a test
      :lint_files      all sources plus tsconfig.json and tool configs, for oxlint/oxfmt
      :unit_test       Vitest (`vitest run`), when unit_test = True

    Args:
      npm_deps: npm package names from web/atlas-live/package.json used by this package.
      packages: other Atlas Live packages (e.g. "protocol") imported through relative paths.
        Each must set declarations = True.
      declarations: emit .d.ts only, so that other packages typecheck against this one
        without pulling its sources outside their rootDir.
      unit_test: whether the package has a Vitest suite under test/.
      test_data: extra runfiles for the unit test.
      test_env: extra environment for the unit test.
      test_size: Bazel size of the unit test.
    """
    npm_labels = [_nm(p) for p in npm_deps]
    package_srcs = ["//web/atlas-live/%s:srcs" % p for p in packages]
    package_types = ["//web/atlas-live/%s:ts" % p for p in packages]

    js_library(
        name = "srcs",
        srcs = native.glob(["src/**/*.ts", "src/**/*.tsx"], allow_empty = True),
        deps = npm_labels,
        visibility = ["//web/atlas-live:__subpackages__"],
    )

    js_library(
        name = "test_srcs",
        srcs = native.glob(["test/**/*.ts", "test/**/*.tsx"], allow_empty = True),
        deps = [":srcs"],
    )

    ts_config(
        name = "tsconfig",
        src = "tsconfig.json",
        deps = ["//web/atlas-live:tsconfig_base"],
    )

    ts_project(
        name = "ts",
        srcs = [":srcs", ":test_srcs"],
        declaration = declarations,
        emit_declaration_only = declarations,
        # rules_ts actions use the default shell env, which is empty on RBE; the
        # launcher's `#!/usr/bin/env bash` then cannot find bash.
        exec_properties = {"env-overrides": "PATH=/usr/local/bin:/usr/bin:/bin"},
        no_emit = not declarations,
        tsconfig = ":tsconfig",
        deps = npm_labels + package_types,
        visibility = ["//web/atlas-live:__subpackages__"],
    )

    native.test_suite(
        name = "typecheck_test",
        tests = [":ts_typecheck_test"],
    )

    configs = ["tsconfig.json"]
    if unit_test:
        configs.append("vitest.config.mjs")

    js_library(
        name = "lint_files",
        srcs = configs,
        deps = [":srcs", ":test_srcs"],
        visibility = ["//web/atlas-live:__pkg__"],
    )

    if unit_test:
        vitest_bin.vitest_test(
            name = "unit_test",
            args = [
                "run",
                "--config",
                "vitest.config.mjs",
            ],
            chdir = native.package_name(),
            data = [
                ":test_srcs",
                "vitest.config.mjs",
                _nm("vitest"),
            ] + package_srcs + test_data,
            env = test_env,
            size = test_size,
        )
