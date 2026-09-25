//! ABI-14 Rust binding for the pinned `omarjatoi/tree-sitter-flix` grammar.
//!
//! The upstream binding exposes a `tree_sitter_language::LanguageFn`, which
//! needs a newer tree-sitter runtime than the one the frozen Grit closure pins
//! (see `build/grit_repository.bzl`). This file replaces only the *binding*: the
//! grammar's generated parser and scanner remain the pinned upstream sources,
//! patched solely where they declared the newer language ABI.

use tree_sitter::Language;

extern "C" {
    fn tree_sitter_flix() -> Language;
}

/// Returns the tree-sitter [`Language`] for this grammar.
pub fn language() -> Language {
    unsafe { tree_sitter_flix() }
}
