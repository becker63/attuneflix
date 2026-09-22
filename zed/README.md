# Flix for Zed

This local Zed extension deliberately delegates language intelligence to the
Flix compiler itself (`flix lsp`). It adds Flix file detection, a pinned
Tree-sitter grammar, syntax highlighting, outlines, and bracket matching.

Inside AttuneFlix the extension launches `zed/flix-lsp`, which enters the
project's Nix environment and starts the pinned compiler. That launcher adds a
small replacement `HoverProvider` ahead of the upstream Flix JAR to cover
declarations, named types, enum cases, struct fields, and Datalog predicates
that Flix 0.76 does not yet hover. Every other request goes directly to Flix's
native LSP.

In other Flix worktrees the extension falls back to `flix lsp` from `PATH`.

Install it as a Zed development extension by selecting this directory:

```text
zed/
```

After changing the extension source, reinstall the same development-extension
directory and run `language server: restart` for an already-open Flix buffer.
