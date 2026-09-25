use crate::{
    language::{fields_for_nodes, Field, MarzanoLanguage, NodeTypes, SortId, TSLanguage},
    textual_metavariable,
};
use grit_util::Language;
use marzano_util::node_with_source::NodeWithSource;
use regex::Regex;
use std::sync::OnceLock;

static NODE_TYPES_STRING: &str = include_str!("../../../resources/node-types/flix-node-types.json");
static NODE_TYPES: OnceLock<Vec<Vec<Field>>> = OnceLock::new();
static LANGUAGE: OnceLock<TSLanguage> = OnceLock::new();

#[cfg(not(feature = "tree-sitter-flix"))]
fn language() -> TSLanguage {
    unimplemented!(
        "tree-sitter parser must be initialized before use when [tree-sitter-flix] is off."
    )
}
#[cfg(feature = "tree-sitter-flix")]
fn language() -> TSLanguage {
    tree_sitter_flix::language().into()
}

/// Flix, parsed by the repository's one pinned `tree-sitter-flix` grammar.
#[derive(Debug, Clone, Copy)]
pub struct Flix {
    node_types: &'static [Vec<Field>],
    metavariable_sort: SortId,
    comment_sorts: [SortId; 3],
    language: &'static TSLanguage,
}

impl NodeTypes for Flix {
    fn node_types(&self) -> &[Vec<Field>] {
        self.node_types
    }
}

impl Flix {
    pub(crate) fn new(lang: Option<TSLanguage>) -> Self {
        let language = LANGUAGE.get_or_init(|| lang.unwrap_or_else(language));
        let node_types = NODE_TYPES.get_or_init(|| fields_for_nodes(language, NODE_TYPES_STRING));
        let metavariable_sort = language.id_for_node_kind("grit_metavariable", true);
        let comment_sorts = [
            language.id_for_node_kind("line_comment", true),
            language.id_for_node_kind("block_comment", true),
            language.id_for_node_kind("doc_comment", true),
        ];
        Self {
            node_types,
            metavariable_sort,
            comment_sorts,
            language,
        }
    }

    pub(crate) fn is_initialized() -> bool {
        LANGUAGE.get().is_some()
    }
}

impl Language for Flix {
    use_marzano_base_delegate!();

    fn language_name(&self) -> &'static str {
        "Flix"
    }

    fn snippet_context_strings(&self) -> &[(&'static str, &'static str)] {
        // A Flix module holds declarations, so an expression snippet needs a
        // declaration context; `grit_function` is lowercase because Flix
        // function names must be.
        &[
            ("", ""),
            ("def grit_function(): GRIT_TYPE = ", ""),
            ("def grit_function(): ", " = GRIT_VALUE"),
        ]
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
}

impl<'a> MarzanoLanguage<'a> for Flix {
    fn get_ts_language(&self) -> &TSLanguage {
        self.language
    }

    fn is_comment_sort(&self, id: SortId) -> bool {
        self.comment_sorts.contains(&id)
    }

    fn metavariable_sort(&self) -> SortId {
        self.metavariable_sort
    }
}
