//! GritQL metavariable helpers for Attune's additional Grit languages.
//!
//! Grit recognizes a metavariable inside a snippet by parsing the substituted
//! snippet with the target grammar. Upstream Grit's grammars carry a dedicated
//! `grit_metavariable` token for that; the frozen Flix and Starlark grammars do
//! not, and the frozen closure never regenerates or forks a grammar to add one.
//!
//! Both of those grammars accept a non-ASCII leading identifier character, so
//! `$name` substitutes to `µname` exactly as upstream, and the dotted
//! metavariable `$...` substitutes to the five-byte identifier `µ0__`:
//!
//! * it is exactly one byte longer than `$...`, which is the contract the range
//!   mapping in `marzano-core` relies on (the same contract `µ` satisfies for
//!   `$name`), and
//! * it can never collide with a substituted metavariable name, because a GritQL
//!   metavariable name cannot start with a digit.

use grit_util::{AstNode, GritMetaValue};
use marzano_util::node_with_source::NodeWithSource;
use regex::Regex;
use std::sync::LazyLock;

/// The substitute for `$...`; see the module documentation for the contract.
pub(crate) const DOTS_PLACEHOLDER: &str = "µ0__";

static GRIT_VARIABLE_REGEX: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"\$(\.\.\.|[A-Za-z_][A-Za-z0-9_]*)").unwrap());

static REPLACED_METAVARIABLE_REGEX: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"µ(0__|[A-Za-z_][A-Za-z0-9_]*)").unwrap());

static EXACT_REPLACED_METAVARIABLE_REGEX: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^µ(0__|[A-Za-z_][A-Za-z0-9_]*)$").unwrap());

/// Replaces every GritQL metavariable in a snippet with its target-language form.
pub(crate) fn substitute(src: &str) -> String {
    GRIT_VARIABLE_REGEX
        .replace_all(src, |captures: &regex::Captures| {
            let name = &captures[1];
            if name == "..." {
                DOTS_PLACEHOLDER.to_owned()
            } else {
                format!("µ{name}")
            }
        })
        .to_string()
}

/// The regex that finds substituted metavariables in a parsed snippet.
pub(crate) fn replaced_regex() -> &'static Regex {
    &REPLACED_METAVARIABLE_REGEX
}

/// Translates substituted snippet text back into a Grit metavariable.
pub(crate) fn to_grit_metavalue(src: &str) -> Option<GritMetaValue> {
    match src.trim().strip_prefix('µ')? {
        "0__" => Some(GritMetaValue::Dots),
        "_" => Some(GritMetaValue::Underscore),
        name => Some(GritMetaValue::Variable(format!("${name}"))),
    }
}

/// True for the identifier token that stands in for one GritQL metavariable.
pub(crate) fn is_metavariable(node: &NodeWithSource<'_>) -> bool {
    if !node.node.is_named() || node.node.named_child_count() > 0 {
        return false;
    }
    match node.text() {
        Ok(text) => EXACT_REPLACED_METAVARIABLE_REGEX.is_match(text.trim()),
        Err(_) => false,
    }
}
