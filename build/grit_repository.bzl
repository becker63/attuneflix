"""One content-addressed materialization of Attune's frozen Grit source."""

_GRIT_REVISION = "c80b3026471b229f41b279c3eb0c162dcdacfdb1"

_UNUSED_LANGUAGE_PARSERS = [
    ("tree-sitter-css", "tree-sitter-css"),
    ("tree-sitter-json", "tree-sitter-json"),
    ("tree-sitter-solidity", "tree-sitter-solidity"),
    ("tree-sitter-yaml", "tree-sitter-yaml"),
    ("tree-sitter-hcl", "tree-sitter-hcl"),
    ("tree-sitter-html", "tree-sitter-html"),
    ("tree-sitter-java", "tree-sitter-java"),
    ("tree-sitter-kotlin", "tree-sitter-kotlin"),
    ("tree-sitter-c-sharp", "tree-sitter-c-sharp"),
    ("tree-sitter-python", "tree-sitter-python"),
    ("tree-sitter-md", "tree-sitter-markdown"),
    ("tree-sitter-go", "tree-sitter-go"),
    ("tree-sitter-rust", "tree-sitter-rust"),
    ("tree-sitter-elixir", "tree-sitter-elixir"),
    ("tree-sitter-ruby", "tree-sitter-ruby"),
    ("tree-sitter-sql", "tree-sitter-sql"),
    ("tree-sitter-vue", "tree-sitter-vue"),
    ("tree-sitter-toml", "tree-sitter-toml"),
    ("tree-sitter-php", "tree-sitter-php"),
]

def _replace(repository_ctx, path, old, new):
    content = repository_ctx.read(path)
    if old not in content:
        fail("frozen Grit patch no longer applies to %s" % path)
    repository_ctx.file(path, content.replace(old, new))

def _drop_nested_workspace(repository_ctx, path):
    content = repository_ctx.read(path)
    marker = "\n[workspace]\n"
    if marker not in content:
        fail("expected nested workspace marker in %s" % path)
    repository_ctx.file(path, content.split(marker, 1)[0] + "\n")

def _rust_library_build(name, crate_name, external_deps, path_deps = [], crate_features = [], compile_data = []):
    return """load("@grit_crates//:defs.bzl", "aliases", "all_crate_deps", "crate_deps", "crate_edition")
load("@rules_rust//rust:defs.bzl", "rust_library")

rust_library(
    name = %s,
    srcs = glob(["src/**/*.rs"]),
    aliases = aliases(),
    compile_data = %s,
    crate_features = %s,
    crate_name = %s,
    edition = crate_edition(),
    proc_macro_deps = all_crate_deps(proc_macro = True),
    visibility = ["//visibility:public"],
    deps = crate_deps(%s) + %s,
)
""" % (
        repr(name),
        repr(compile_data),
        repr(crate_features),
        repr(crate_name),
        repr(external_deps),
        repr(path_deps),
    )

def _tree_sitter_parser_build(name, crate_name, crate_root, version):
    return """load("@rules_rust//cargo:defs.bzl", "cargo_build_script", "cargo_toml_env_vars")
load("@rules_rust//rust:defs.bzl", "rust_library")

cargo_toml_env_vars(
    name = "cargo_toml_env_vars",
    src = "Cargo.toml",
)

cargo_build_script(
    name = "build_script",
    srcs = glob(["**/*.rs"]),
    crate_name = "build_script_build",
    crate_root = "bindings/rust/build.rs",
    data = glob(["**"], exclude = ["BUILD.bazel"]),
    deps = ["@@rules_rust++crate+grit_crates__cc-1.0.106//:cc"],
    edition = "2021",
    pkg_name = %s,
    rustc_env_files = [":cargo_toml_env_vars"],
    version = %s,
)

rust_library(
    name = %s,
    srcs = glob(["**/*.rs"]),
    compile_data = glob(["**"], exclude = ["BUILD.bazel"]),
    crate_name = %s,
    crate_root = %s,
    deps = [
        ":build_script",
        "@@rules_rust++crate+grit_crates__tree-sitter-0.20.10//:tree_sitter",
    ],
    edition = "2021",
    visibility = ["//visibility:public"],
)
""" % (repr(name), repr(version), repr(name), repr(crate_name), repr(crate_root))

def _gritql_repository_impl(repository_ctx):
    repository_ctx.download_and_extract(
        url = "https://github.com/getgrit/gritql/archive/%s.tar.gz" % _GRIT_REVISION,
        sha256 = "87066b84963dc1b89b9344fbae046f941ed8fce5e983c48d74a26964f6e7cb48",
        stripPrefix = "gritql-%s" % _GRIT_REVISION,
    )
    repository_ctx.download_and_extract(
        url = "https://github.com/getgrit/tree-sitter-facade/archive/a26c147cea7049a5d2c42006499371b346b52648.tar.gz",
        sha256 = "bb0ed7d6ca292c97d7e84861ebddbe712b3a36250e38f14ddbbc085bca35f490",
        stripPrefix = "tree-sitter-facade-a26c147cea7049a5d2c42006499371b346b52648",
        output = "vendor/tree-sitter-facade",
    )
    repository_ctx.download_and_extract(
        url = "https://github.com/getgrit/tree-sitter-gritql/archive/f9d98660bd7ae78c9211cb52e295bcd6531a8121.tar.gz",
        sha256 = "1833096a60ed449417053bcb4f954eca6e74cfacb3ce23f5e950d3372e2a0253",
        stripPrefix = "tree-sitter-gritql-f9d98660bd7ae78c9211cb52e295bcd6531a8121",
        output = "vendor/tree-sitter-gritql",
    )
    repository_ctx.download_and_extract(
        url = "https://github.com/getgrit/web-tree-sitter/archive/9a01e452ec7288851405722e13aca08d9d90b6b1.tar.gz",
        sha256 = "d42925a4d986c3d875184f006e8f247eeea209e864c5b25ddd65be30a814bfd0",
        stripPrefix = "web-tree-sitter-9a01e452ec7288851405722e13aca08d9d90b6b1",
        output = "vendor/web-tree-sitter",
    )
    _drop_nested_workspace(repository_ctx, "vendor/tree-sitter-facade/Cargo.toml")
    _drop_nested_workspace(repository_ctx, "vendor/web-tree-sitter/Cargo.toml")

    for module in ["javascript", "tsx", "typescript"]:
        path = "crates/language/src/%s.rs" % module
        feature = "tree-sitter-javascript" if module == "javascript" else "tree-sitter-typescript"
        _replace(
            repository_ctx,
            path,
            '#[cfg(not(feature = "builtin-parser"))]',
            '#[cfg(not(feature = "%s"))]' % feature,
        )
        _replace(
            repository_ctx,
            path,
            '#[cfg(feature = "builtin-parser")]',
            '#[cfg(feature = "%s")]' % feature,
        )

    # Attune's frozen native boundary enables only GritQL, JavaScript, and
    # TypeScript parsers. Cargo resolves optional path dependencies even when
    # disabled, so make the generated manifest describe that admitted closure.
    for dependency, directory in _UNUSED_LANGUAGE_PARSERS:
        _replace(
            repository_ctx,
            "crates/language/Cargo.toml",
            '%s = { path = "../../resources/language-metavariables/%s", optional = true }\n' % (dependency, directory),
            "",
        )
        _replace(
            repository_ctx,
            "crates/language/Cargo.toml",
            '    "%s",\n' % dependency,
            "",
        )

    workspace = repository_ctx.read("Cargo.toml")
    member_marker = "members = ["
    exclude_marker = "exclude = ["
    if member_marker not in workspace or exclude_marker not in workspace:
        fail("frozen Grit workspace membership changed")
    prefix = workspace.split(member_marker, 1)[0]
    excluded = workspace.split(exclude_marker, 1)[1]
    repository_ctx.file(
        "Cargo.toml",
        prefix + """members = ["attune-grit"]
exclude = [
  "crates/*",
""" + excluded,
    )
    repository_ctx.file("Cargo.lock", repository_ctx.read(repository_ctx.attr.cargo_lock))
    repository_ctx.file("attune-grit/lib.rs", repository_ctx.read(repository_ctx.attr.attune_lib))

    repository_ctx.file(
        "crates/grit-util/BUILD.bazel",
        _rust_library_build(
            "grit_util",
            "grit_util",
            ["derive_builder", "once_cell", "regex", "serde", "thiserror"],
        ),
    )
    repository_ctx.file(
        "crates/grit-pattern-matcher/BUILD.bazel",
        _rust_library_build(
            "grit_pattern_matcher",
            "grit_pattern_matcher",
            ["elsa", "itertools", "rand", "regex"],
            path_deps = ["//crates/grit-util:grit_util"],
        ),
    )
    repository_ctx.file(
        "crates/util/BUILD.bazel",
        _rust_library_build(
            "marzano_util",
            "marzano_util",
            ["anyhow", "base64", "fs-err", "http", "serde", "serde_json", "sha2", "similar"],
            path_deps = [
                "//crates/grit-util:grit_util",
                "//vendor/tree-sitter-facade:tree_sitter_facade_sg",
            ],
        ),
    )
    repository_ctx.file(
        "crates/language/BUILD.bazel",
        _rust_library_build(
            "marzano_language",
            "marzano_language",
            ["anyhow", "clap", "itertools", "lazy_static", "regex", "serde", "serde_json"],
            path_deps = [
                "//crates/grit-util:grit_util",
                "//crates/util:marzano_util",
                "//resources/language-metavariables/tree-sitter-javascript:tree_sitter_javascript",
                "//resources/language-metavariables/tree-sitter-typescript:tree_sitter_typescript",
                "//vendor/tree-sitter-facade:tree_sitter_facade_sg",
                "//vendor/tree-sitter-gritql:tree_sitter_gritql",
            ],
            crate_features = [
                "grit-parser",
                "tree-sitter-gritql",
                "tree-sitter-javascript",
                "tree-sitter-typescript",
            ],
            compile_data = ["//resources/node-types:all"],
        ),
    )
    repository_ctx.file(
        "crates/core/BUILD.bazel",
        _rust_library_build(
            "marzano_core",
            "marzano_core",
            [
                "anyhow",
                "fs-err",
                "itertools",
                "log",
                "path-absolutize",
                "rand",
                "rayon",
                "regex",
                "serde",
                "serde_json",
                "sha2",
                "tracing",
                "uuid",
            ],
            path_deps = [
                "//crates/grit-pattern-matcher:grit_pattern_matcher",
                "//crates/grit-util:grit_util",
                "//crates/language:marzano_language",
                "//crates/util:marzano_util",
                "//vendor/tree-sitter-facade:tree_sitter_facade_sg",
            ],
            crate_features = ["grit-parser", "non_wasm"],
        ),
    )
    repository_ctx.file(
        "resources/node-types/BUILD.bazel",
        "filegroup(\n    name = \"all\",\n    srcs = glob([\"*.json\"]),\n    visibility = [\"//visibility:public\"],\n)\n",
    )
    repository_ctx.file(
        "vendor/tree-sitter-facade/BUILD.bazel",
        """load("@rules_rust//rust:defs.bzl", "rust_library")

rust_library(
    name = "tree_sitter_facade_sg",
    srcs = glob(["src/**/*.rs"]),
    # Cargo names the package tree-sitter-facade-sg but every admitted Marzano
    # crate depends on it through the explicit `tree-sitter` rename.
    crate_name = "tree_sitter",
    deps = [
        "@@rules_rust++crate+grit_crates__tree-sitter-0.20.10//:tree_sitter",
        "@@rules_rust++crate+grit_crates__wasm-bindgen-0.2.128//:wasm_bindgen",
    ],
    edition = "2021",
    visibility = ["//visibility:public"],
)
""",
    )
    repository_ctx.file(
        "vendor/tree-sitter-gritql/BUILD.bazel",
        _tree_sitter_parser_build(
            "tree_sitter_gritql",
            "tree_sitter_gritql",
            "bindings/rust/lib.rs",
            "0.1.0",
        ),
    )
    repository_ctx.file(
        "resources/language-metavariables/tree-sitter-javascript/BUILD.bazel",
        _tree_sitter_parser_build(
            "tree_sitter_javascript",
            "tree_sitter_javascript",
            "bindings/rust/lib.rs",
            "0.20.3",
        ),
    )
    repository_ctx.file(
        "resources/language-metavariables/tree-sitter-typescript/BUILD.bazel",
        _tree_sitter_parser_build(
            "tree_sitter_typescript",
            "tree_sitter_typescript",
            "bindings/rust/lib.rs",
            "0.20.5",
        ),
    )
    repository_ctx.file(
        "attune-grit/Cargo.toml",
        """[package]
name = "attune-grit-abi"
version = "0.1.0"
edition = "2024"
publish = false

[lib]
path = "lib.rs"
crate-type = ["cdylib", "rlib"]

[dependencies]
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"

[dependencies.marzano-core]
path = "../crates/core"
default-features = false
features = ["grit-parser", "non_wasm"]

[dependencies.marzano-language]
path = "../crates/language"
default-features = false
features = [
  "grit-parser",
  "tree-sitter-gritql",
  "tree-sitter-javascript",
  "tree-sitter-typescript",
]

[dependencies.marzano-util]
path = "../crates/util"
""",
    )
    repository_ctx.file(
        "BUILD.bazel",
        'exports_files(["Cargo.lock", "Cargo.toml"])\n',
    )
    repository_ctx.file(
        "attune-grit/BUILD.bazel",
        'exports_files(["Cargo.toml"])\n',
    )

gritql_repository = repository_rule(
    implementation = _gritql_repository_impl,
    attrs = {
        "attune_lib": attr.label(allow_single_file = True, mandatory = True),
        "cargo_lock": attr.label(allow_single_file = True, mandatory = True),
    },
)
