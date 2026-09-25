use crate::{
    language::{fields_for_nodes, Field, MarzanoLanguage, NodeTypes, SortId, TSLanguage},
    textual_metavariable,
};
use grit_util::Language;
use marzano_util::node_with_source::NodeWithSource;
use regex::Regex;
use std::sync::OnceLock;

static NODE_TYPES_STRING: &str =
    include_str!("../../../resources/node-types/starlark-node-types.json");
static NODE_TYPES: OnceLock<Vec<Vec<Field>>> = OnceLock::new();
static LANGUAGE: OnceLock<TSLanguage> = OnceLock::new();

#[cfg(not(feature = "tree-sitter-starlark"))]
fn language() -> TSLanguage {
    unimplemented!(
        "tree-sitter parser must be initialized before use when [tree-sitter-starlark] is off."
    )
}
#[cfg(feature = "tree-sitter-starlark")]
fn language() -> TSLanguage {
    tree_sitter_starlark::language().into()
}

/// Starlark, parsed by the pinned `tree-sitter-grammars/tree-sitter-starlark`
/// grammar: `.bzl`, `BUILD`, `BUILD.bazel`, and `.bazel` sources.
#[derive(Debug, Clone, Copy)]
pub struct Starlark {
    node_types: &'static [Vec<Field>],
    metavariable_sort: SortId,
    comment_sort: SortId,
    language: &'static TSLanguage,
}

impl NodeTypes for Starlark {
    fn node_types(&self) -> &[Vec<Field>] {
        self.node_types
    }
}

impl Starlark {
    pub(crate) fn new(lang: Option<TSLanguage>) -> Self {
        let language = LANGUAGE.get_or_init(|| lang.unwrap_or_else(language));
        let node_types = NODE_TYPES.get_or_init(|| fields_for_nodes(language, NODE_TYPES_STRING));
        let metavariable_sort = language.id_for_node_kind("grit_metavariable", true);
        let comment_sort = language.id_for_node_kind("comment", true);
        Self {
            node_types,
            metavariable_sort,
            comment_sort,
            language,
        }
    }

    pub(crate) fn is_initialized() -> bool {
        LANGUAGE.get().is_some()
    }
}

impl Language for Starlark {
    use_marzano_base_delegate!();

    fn language_name(&self) -> &'static str {
        "Starlark"
    }

    fn snippet_context_strings(&self) -> &[(&'static str, &'static str)] {
        &[
            ("", ""),
            ("GRIT_VALUE = ", ""),
            ("def grit_function(", "):\n    return GRIT_VALUE\n"),
        ]
    }

    fn comment_prefix(&self) -> &'static str {
        "#"
    }

    fn substitute_metavariable_prefix(&self, src: &str) -> String {
        textual_metavariable::substitute(src)
    }

    fn snippet_metavariable_to_grit_metavariable(&self, src: &str) -> Option<grit_util::GritMetaValue> {
        textual_metavariable::to_grit_metavalue(src)
    }

    fn replaced_metavariable_regex(&self) -> &'static Regex {
        textual_metavariable::replaced_regex()
    }

    fn is_metavariable(&self, node: &NodeWithSource) -> bool {
        textual_metavariable::is_metavariable(node)
    }

    fn make_single_line_comment(&self, text: &str) -> String {
        format!("# {text}\n")
    }
}

impl<'a> MarzanoLanguage<'a> for Starlark {
    fn get_ts_language(&self) -> &TSLanguage {
        self.language
    }

    fn is_comment_sort(&self, id: SortId) -> bool {
        id == self.comment_sort
    }

    fn metavariable_sort(&self) -> SortId {
        self.metavariable_sort
    }
}
