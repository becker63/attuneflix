mod Atlas {
    /// The measurement grammar is a distinct type: Reverse and Union do not exist.
    pub enum Atom with Eq, Order, ToString, Hash {
        case Defines,
        case DefinedIn,
        case Imports,
        case ImportedBy,
        case Calls,
        case Callers
    }

    pub enum Expr with Eq, Order, ToString, Hash {
        case Atom(Atom),
        case Compose(Expr, Atom)
    }

    pub type alias Counts = {
        logical = Int32,
        complete = Int32
    }

    /// Count the fixed composition-only grammar without allocating 3,279 paths.
    pub def counts(depth: Int32): Counts = loop(depth, 1, 0, 0, 0)

    def loop(remaining: Int32, symbols: Int32, files: Int32, logical: Int32, complete: Int32): Counts =
        if (remaining <= 0) {
            logical = logical,
            complete = complete
        } else {
            // From either sort there are exactly three compatible directed atoms.
            let nextFiles = symbols + (2 * files);
            let nextSymbols = (2 * symbols) + files;
            loop(
                remaining - 1,
                nextSymbols,
                nextFiles,
                logical + nextFiles + nextSymbols,
                complete + nextSymbols
            )
        }
}
