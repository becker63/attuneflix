"""One content-addressed materialization of Attune's frozen Grit source.

Grit stays pinned at `_GRIT_REVISION`; Attune's additional target languages are
**extensions of that closure**, never a reason to move the pin:

* Java is the upstream parser already inside the pin (`tree-sitter-java`), which
  this rule deliberately stopped stripping; and
* Flix and Starlark are two additional pinned Tree-sitter grammars materialized
  beside the others. The Flix grammar is the repository's ONE Flix grammar: the
  exact revision `zed/extension.toml` pins for the Zed extension.
"""

_GRIT_REVISION = "c80b3026471b229f41b279c3eb0c162dcdacfdb1"

# The one Flix syntax grammar in AttuneFlix: `zed/extension.toml` pins the same
# repository and revision for Zed. The Grit integration reuses it rather than
# introducing a second grammar, a fork, or an independently pinned version.
_FLIX_GRAMMAR = struct(
    directory = "tree-sitter-flix",
    name = "flix",
    repository = "omarjatoi/tree-sitter-flix",
    revision = "78cff149b2e9897456f94844872353b5ee0ca93b",
    sha256 = "d72c059bb82487e7c19cf276fcb3a8fa0466fa692a4ebc39c911a458e11b0d3c",
    version = "0.1.0",
)

# The maintained Starlark grammar, integrated inside the same frozen closure.
_STARLARK_GRAMMAR = struct(
    directory = "tree-sitter-starlark",
    name = "starlark",
    repository = "tree-sitter-grammars/tree-sitter-starlark",
    revision = "a453dbf3ba433db0e5ec621a38a7e59d72e4dc69",
    sha256 = "7b417fde027fd04bff8c68457e92072d0d88ea71988d9432bfe233633c09ab74",
    version = "1.3.0",
)

# Repository-local files copied into the materialized Grit closure. They are the
# Grit language implementations Attune adds to `marzano_language`, the ABI-14
# bindings for the two new grammars, and the shared metavariable helper.
_LANGUAGE_PATCH_DESTINATIONS = {
    "flix.rs": "crates/language/src/flix.rs",
    "flix_binding.rs": "resources/language-metavariables/tree-sitter-flix/bindings/rust/grit_language.rs",
    "starlark.rs": "crates/language/src/starlark.rs",
    "starlark_binding.rs": "resources/language-metavariables/tree-sitter-starlark/bindings/rust/grit_language.rs",
    "textual_metavariable.rs": "crates/language/src/textual_metavariable.rs",
}

# The list-bearing wrapper nodes of the two pinned grammars, mapped to the field
# name their declaring nodes already use. See `_copy_node_types`.
_WRAPPER_LIST_FIELDS = {
    "flix": {
        "argument_list": "arguments",
        "case_payload": "payload",
        "formal_parameters": "parameters",
        "lambda_parameters": "parameters",
    },
    "starlark": {
        "argument_list": "arguments",
        "lambda_parameters": "parameters",
        "parameters": "parameters",
    },
}

# Edits that register Flix and Starlark as ordinary Grit target languages in the
# frozen `crates/language` crate. Java needs no registry edit: upstream Grit
# already ships the Java language implementation and enum variant, and this
# closure only stopped stripping its parser.
_LANGUAGE_REGISTRY_PATCHES = [
    (
        "    elixir::Elixir,\n    go::Go,",
        "    elixir::Elixir,\n    flix::Flix,\n    go::Go,",
    ),
    (
        "    sql::Sql,\n    toml::Toml,",
        "    sql::Sql,\n    starlark::Starlark,\n    toml::Toml,",
    ),
    ("    Json,\n    Java,", "    Json,\n    Flix,\n    Java,"),
    ("    Sql,\n    Vue,", "    Sql,\n    Starlark,\n    Vue,"),
    (
        '            PatternLanguage::Css => write!(f, "css"),\n            PatternLanguage::Json => write!(f, "json"),',
        '            PatternLanguage::Css => write!(f, "css"),\n'
        + '            PatternLanguage::Flix => write!(f, "flix"),\n'
        + '            PatternLanguage::Json => write!(f, "json"),',
    ),
    (
        '            PatternLanguage::Sql => write!(f, "sql"),\n            PatternLanguage::Vue => write!(f, "vue"),',
        '            PatternLanguage::Sql => write!(f, "sql"),\n'
        + '            PatternLanguage::Starlark => write!(f, "starlark"),\n'
        + '            PatternLanguage::Vue => write!(f, "vue"),',
    ),
    ("            Self::Json,\n            Self::Java,", "            Self::Json,\n            Self::Flix,\n            Self::Java,"),
    ("            Self::Sql,\n            Self::Vue,", "            Self::Sql,\n            Self::Starlark,\n            Self::Vue,"),
    (
        '            "json" => Some(Self::Json),\n            "java" => Some(Self::Java),',
        '            "json" => Some(Self::Json),\n            "flix" => Some(Self::Flix),\n            "java" => Some(Self::Java),',
    ),
    (
        '            "sql" => Some(Self::Sql),\n            "vue" => Some(Self::Vue),\n            "toml" => Some(Self::Toml),',
        '            "sql" => Some(Self::Sql),\n'
        + '            "starlark" => Some(Self::Starlark),\n'
        + '            "vue" => Some(Self::Vue),\n'
        + '            "toml" => Some(Self::Toml),',
    ),
    (
        '            "sql" => Some(Self::Sql),\n            "vue" => Some(Self::Vue),\n            "php" | "phps" | "phtml" | "pht" => Some(Self::Php),',
        '            "sql" => Some(Self::Sql),\n'
        + '            // Bazel\'s build files are Starlark: `.bzl` and `.bazel` carry the\n'
        + '            // extension, and `BUILD`/`WORKSPACE` are named without one.\n'
        + '            "bzl" | "star" | "bazel" | "BUILD" | "BUILD.bazel" | "WORKSPACE" | "WORKSPACE.bazel" => {\n'
        + '                Some(Self::Starlark)\n'
        + '            }\n'
        + '            "vue" => Some(Self::Vue),\n'
        + '            "php" | "phps" | "phtml" | "pht" => Some(Self::Php),',
    ),
    (
        '            PatternLanguage::Java => &["java"],\n            PatternLanguage::Kotlin => &["kt", "kts"],',
        '            PatternLanguage::Java => &["java"],\n'
        + '            PatternLanguage::Flix => &["flix"],\n'
        + '            PatternLanguage::Kotlin => &["kt", "kts"],',
    ),
    (
        '            PatternLanguage::Sql => &["sql"],\n            PatternLanguage::Vue => &["vue"],',
        '            PatternLanguage::Sql => &["sql"],\n'
        + '            // Bazel/Starlark sources: `.bzl`, the `.bazel` files (`BUILD.bazel`,\n'
        + '            // `MODULE.bazel`), and Buck2-style `.star`.\n'
        + '            PatternLanguage::Starlark => &["bzl", "bazel", "star"],\n'
        + '            PatternLanguage::Vue => &["vue"],',
    ),
    (
        '            PatternLanguage::Java => Some("java"),\n            PatternLanguage::Kotlin => Some("kt"),',
        '            PatternLanguage::Java => Some("java"),\n'
        + '            PatternLanguage::Flix => Some("flix"),\n'
        + '            PatternLanguage::Kotlin => Some("kt"),',
    ),
    (
        '            PatternLanguage::Sql => Some("sql"),\n            PatternLanguage::Vue => Some("vue"),',
        '            PatternLanguage::Sql => Some("sql"),\n'
        + '            PatternLanguage::Starlark => Some("bzl"),\n'
        + '            PatternLanguage::Vue => Some("vue"),',
    ),
    (
        '            PatternLanguage::Java => Ok(TargetLanguage::Java(Java::new(Some(lang)))),\n            PatternLanguage::CSharp =>',
        '            PatternLanguage::Java => Ok(TargetLanguage::Java(Java::new(Some(lang)))),\n'
        + '            PatternLanguage::Flix => Ok(TargetLanguage::Flix(Flix::new(Some(lang)))),\n'
        + '            PatternLanguage::CSharp =>',
    ),
    (
        '            PatternLanguage::Sql => Ok(TargetLanguage::Sql(Sql::new(Some(lang)))),\n            PatternLanguage::Vue =>',
        '            PatternLanguage::Sql => Ok(TargetLanguage::Sql(Sql::new(Some(lang)))),\n'
        + '            PatternLanguage::Starlark => Ok(TargetLanguage::Starlark(Starlark::new(Some(lang)))),\n'
        + '            PatternLanguage::Vue =>',
    ),
    (
        "            TargetLanguage::CSharp(_)\n            | TargetLanguage::Go(_)",
        "            TargetLanguage::CSharp(_)\n            | TargetLanguage::Flix(_)\n            | TargetLanguage::Go(_)",
    ),
    (
        "            TargetLanguage::Python(_)\n            | TargetLanguage::Ruby(_)",
        "            TargetLanguage::Python(_)\n            | TargetLanguage::Starlark(_)\n            | TargetLanguage::Ruby(_)",
    ),
    ("    Sql,\n    Php,\n    PhpOnly\n}", "    Sql,\n    Php,\n    PhpOnly,\n    Starlark\n}"),
    (
        '            TargetLanguage::Json(_) => write!(f, "json"),\n            TargetLanguage::Java(_) => write!(f, "java"),',
        '            TargetLanguage::Json(_) => write!(f, "json"),\n'
        + '            TargetLanguage::Flix(_) => write!(f, "flix"),\n'
        + '            TargetLanguage::Java(_) => write!(f, "java"),',
    ),
    (
        '            TargetLanguage::Sql(_) => write!(f, "sql"),\n            TargetLanguage::Vue(_) => write!(f, "vue"),',
        '            TargetLanguage::Sql(_) => write!(f, "sql"),\n'
        + '            TargetLanguage::Starlark(_) => write!(f, "starlark"),\n'
        + '            TargetLanguage::Vue(_) => write!(f, "vue"),',
    ),
]

_UNUSED_LANGUAGE_PARSERS = [
    ("tree-sitter-css", "tree-sitter-css"),
    ("tree-sitter-json", "tree-sitter-json"),
    ("tree-sitter-solidity", "tree-sitter-solidity"),
    ("tree-sitter-yaml", "tree-sitter-yaml"),
    ("tree-sitter-hcl", "tree-sitter-hcl"),
    ("tree-sitter-html", "tree-sitter-html"),
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

def _materialize_grammar(repository_ctx, grammar):
    repository_ctx.download_and_extract(
        url = "https://github.com/%s/archive/%s.tar.gz" % (grammar.repository, grammar.revision),
        sha256 = grammar.sha256,
        stripPrefix = "%s-%s" % (grammar.directory, grammar.revision),
        output = "resources/language-metavariables/%s" % grammar.directory,
    )

def _patch_flix_language_abi(repository_ctx):
    """Compile the pinned Flix grammar for the ABI the frozen Grit runtime speaks.

    The pinned grammar is generated for a newer tree-sitter; the frozen closure
    runs 0.20.10, whose language ABI is 14. Both edits are mechanical and shaped
    to be upstreamable: the ABI version constant, and the lex-mode element type,
    whose ABI-15 `reserved_word_set_id` the frozen runtime must not read (this
    grammar leaves that field at zero for every state, so the ABI-14 layout is
    the same table). The rest of the grammar, including its scanner, is the
    pinned upstream source.
    """
    parser = "resources/language-metavariables/%s/src/parser.c" % _FLIX_GRAMMAR.directory
    _replace(repository_ctx, parser, "#define LANGUAGE_VERSION 15", "#define LANGUAGE_VERSION 14")
    header = "resources/language-metavariables/%s/src/tree_sitter/parser.h" % _FLIX_GRAMMAR.directory
    _replace(
        repository_ctx,
        header,
        """typedef struct {
  uint16_t lex_state;
  uint16_t external_lex_state;
  uint16_t reserved_word_set_id;
} TSLexerMode;""",
        """typedef struct {
  uint16_t lex_state;
  uint16_t external_lex_state;
} TSLexerMode;""",
    )

def _patch_gritql_language_names(repository_ctx):
    """Admit `language flix` and `language starlark` in the frozen GritQL grammar.

    The vendored GritQL parser spells its language names as a fixed keyword list
    (`getgrit/tree-sitter-gritql`); upstream adds a language by regenerating the
    grammar, which a hermetic repository rule cannot do. These are the two
    keyword chains that regeneration would emit, appended to the generated
    lexer: the literal chain ends on an existing language-name token, and the
    language registry reads the declaration's *text*, so the token's own
    spelling is inert. Everything else about the grammar is untouched.
    """
    parser = "vendor/tree-sitter-gritql/src/parser.c"
    _replace(
        repository_ctx,
        parser,
        """    case 7:
      if (lookahead == 'a') ADVANCE(38);
      END_STATE();""",
        """    case 7:
      if (lookahead == 'a') ADVANCE(38);
      if (lookahead == 'l') ADVANCE(1000);
      END_STATE();""",
    )
    _replace(
        repository_ctx,
        parser,
        """    case 158:
      if (lookahead == 't') ADVANCE(193);
      END_STATE();""",
        """    case 158:
      if (lookahead == 'l') ADVANCE(1002);
      if (lookahead == 't') ADVANCE(193);
      END_STATE();""",
    )
    _replace(
        repository_ctx,
        parser,
        """    case 269:
      ACCEPT_TOKEN(anon_sym_start_column);
      END_STATE();""",
        """    case 269:
      ACCEPT_TOKEN(anon_sym_start_column);
      END_STATE();
    case 1000:
      if (lookahead == 'i') ADVANCE(1001);
      END_STATE();
    case 1001:
      if (lookahead == 'x') ADVANCE(1005);
      END_STATE();
    case 1002:
      if (lookahead == 'a') ADVANCE(1003);
      END_STATE();
    case 1003:
      if (lookahead == 'r') ADVANCE(1004);
      END_STATE();
    case 1004:
      if (lookahead == 'k') ADVANCE(1005);
      END_STATE();
    case 1005:
      ACCEPT_TOKEN(anon_sym_cpp);
      END_STATE();""",
    )

def _copy_node_types(repository_ctx):
    """Project each pinned grammar's own node types into the Grit closure.

    Grit compiles a snippet's argument and parameter lists through the fields the
    node type declares. Both pinned grammars wrap those lists in a named
    `argument_list` / `formal_parameters` node and declare no field on the
    wrapper, so `` `$callee($...)` `` would compile as a literal-text leaf and
    never match. Declaring the wrapper's contents field (the field name the
    grammar already uses on the declaring node) keeps those snippets ordinary
    AST patterns; it is the same shape the upstream Java node types declare for
    `argument_list` and `formal_parameters`, and the frozen grammars themselves
    are untouched.
    """
    for grammar in [_FLIX_GRAMMAR, _STARLARK_GRAMMAR]:
        path = "resources/node-types/%s-node-types.json" % grammar.name
        repository_ctx.file(
            path,
            repository_ctx.read(
                "resources/language-metavariables/%s/src/node-types.json" % grammar.directory,
            ),
        )
        _extend_node_types(repository_ctx, path, _WRAPPER_LIST_FIELDS[grammar.name])

def _extend_node_types(repository_ctx, path, declarations):
    node_types = json.decode(repository_ctx.read(path))
    remaining = dict(declarations)
    for node_type in node_types:
        field = remaining.pop(node_type["type"], None)
        if field == None:
            continue
        children = node_type.get("children", {})
        node_type["fields"] = {
            field: {
                "multiple": True,
                "required": False,
                "types": children.get("types", []),
            },
        }
    if remaining:
        fail("pinned grammar no longer declares %s in %s" % (sorted(remaining.keys())[0], path))
    repository_ctx.file(path, json.encode(node_types) + "\n")

def _copy_language_sources(repository_ctx):
    patches = {}
    for label in repository_ctx.attr.language_patches:
        patches[label.name.split("/")[-1]] = repository_ctx.path(label)
    for basename, destination in _LANGUAGE_PATCH_DESTINATIONS.items():
        if basename not in patches:
            fail("the Grit language patch file %s is missing" % basename)
        repository_ctx.file(destination, repository_ctx.read(patches[basename]))

def _extend_language_registry(repository_ctx):
    """Admit Java, Flix, and Starlark into `marzano_language`.

    Every edit below extends the frozen Grit closure: the Java parser is simply
    no longer stripped, and Flix and Starlark arrive as ordinary Grit target
    languages with a Cargo/Bazel feature, a language implementation, an enum
    variant and dispatch arms, and their own node types.
    """
    language_cargo = "crates/language/Cargo.toml"

    # The upstream `marzano_language` manifest declares the Java parser; this
    # closure now uses it, so it is no longer stripped. The two new grammars are
    # declared beside the upstream parsers and admitted by the same feature.
    _replace(
        repository_ctx,
        language_cargo,
        'tree-sitter-javascript = { path = "../../resources/language-metavariables/tree-sitter-javascript", optional = true }\n',
        'tree-sitter-javascript = { path = "../../resources/language-metavariables/tree-sitter-javascript", optional = true }\n'
        + 'tree-sitter-flix = { path = "../../resources/language-metavariables/tree-sitter-flix", optional = true }\n'
        + 'tree-sitter-starlark = { path = "../../resources/language-metavariables/tree-sitter-starlark", optional = true }\n',
    )
    _replace(
        repository_ctx,
        language_cargo,
        '    "tree-sitter-gritql",\n',
        '    "tree-sitter-gritql",\n    "tree-sitter-flix",\n    "tree-sitter-starlark",\n',
    )

    language_lib = "crates/language/src/lib.rs"
    _replace(
        repository_ctx,
        language_lib,
        "pub mod elixir;\npub mod foreign_language;",
        "pub mod elixir;\npub mod flix;\npub mod foreign_language;",
    )
    _replace(
        repository_ctx,
        language_lib,
        "pub mod sql;\npub mod target_language;",
        "pub mod sql;\npub mod starlark;\nmod textual_metavariable;\npub mod target_language;",
    )

    target_language = "crates/language/src/target_language.rs"
    for old, new in _LANGUAGE_REGISTRY_PATCHES:
        _replace(repository_ctx, target_language, old, new)

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
    _patch_gritql_language_names(repository_ctx)

    # Extend the frozen closure with the two additional target-language grammars
    # and Attune's language implementations; Java needs no new grammar.
    for grammar in [_FLIX_GRAMMAR, _STARLARK_GRAMMAR]:
        _materialize_grammar(repository_ctx, grammar)
    _patch_flix_language_abi(repository_ctx)
    _copy_node_types(repository_ctx)
    _copy_language_sources(repository_ctx)

    for module, feature in [
        ("java", "tree-sitter-java"),
        ("javascript", "tree-sitter-javascript"),
        ("tsx", "tree-sitter-typescript"),
        ("typescript", "tree-sitter-typescript"),
    ]:
        path = "crates/language/src/%s.rs" % module
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

    # Attune's frozen native boundary enables only the admitted parsers: GritQL,
    # JavaScript, TypeScript, Java, Flix, and Starlark. Cargo resolves optional
    # path dependencies even when disabled, so make the generated manifest
    # describe exactly that admitted closure.
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

    _extend_language_registry(repository_ctx)

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
                "//resources/language-metavariables/tree-sitter-flix:tree_sitter_flix",
                "//resources/language-metavariables/tree-sitter-java:tree_sitter_java",
                "//resources/language-metavariables/tree-sitter-javascript:tree_sitter_javascript",
                "//resources/language-metavariables/tree-sitter-starlark:tree_sitter_starlark",
                "//resources/language-metavariables/tree-sitter-typescript:tree_sitter_typescript",
                "//vendor/tree-sitter-facade:tree_sitter_facade_sg",
                "//vendor/tree-sitter-gritql:tree_sitter_gritql",
            ],
            crate_features = [
                "grit-parser",
                "tree-sitter-gritql",
                "tree-sitter-flix",
                "tree-sitter-java",
                "tree-sitter-javascript",
                "tree-sitter-starlark",
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
        "resources/language-metavariables/tree-sitter-java/BUILD.bazel",
        _tree_sitter_parser_build(
            "tree_sitter_java",
            "tree_sitter_java",
            "bindings/rust/lib.rs",
            "0.20.2",
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

    # The two grammars Attune adds use the repository-local ABI-14 bindings
    # instead of the upstream bindings, which target a newer tree-sitter.
    repository_ctx.file(
        "resources/language-metavariables/%s/BUILD.bazel" % _FLIX_GRAMMAR.directory,
        _tree_sitter_parser_build(
            "tree_sitter_flix",
            "tree_sitter_flix",
            "bindings/rust/grit_language.rs",
            _FLIX_GRAMMAR.version,
        ),
    )
    repository_ctx.file(
        "resources/language-metavariables/%s/BUILD.bazel" % _STARLARK_GRAMMAR.directory,
        _tree_sitter_parser_build(
            "tree_sitter_starlark",
            "tree_sitter_starlark",
            "bindings/rust/grit_language.rs",
            _STARLARK_GRAMMAR.version,
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
  "tree-sitter-flix",
  "tree-sitter-java",
  "tree-sitter-javascript",
  "tree-sitter-starlark",
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
        "language_patches": attr.label_list(
            allow_files = True,
            mandatory = True,
        ),
    },
)
