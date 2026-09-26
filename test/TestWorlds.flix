/// The shared a/b test world used by the Atlas grammar and Localization
/// law tests: a.js defines a, b.js defines b, a imports b, and a calls b.
pub mod TestWorlds {
    pub def abWorld(): Repository.World = {
        let f0 = Repository.Structure.FileId.FileId(0);
        let f1 = Repository.Structure.FileId.FileId(1);
        let s0 = Repository.Structure.SymbolId.SymbolId(0);
        let s1 = Repository.Structure.SymbolId.SymbolId(1);
        {
            files = Vector#{"a.js", "b.js"},
            symbols = Vector#{
                {path = "a.js", name = "a", startByte = 0, endByte = 1},
                {path = "b.js", name = "b", startByte = 0, endByte = 1}
            },
            defines = Set#{(f0, s0), (f1, s1)},
            imports = Set#{(f0, f1)},
            calls = Set#{(s0, s1)},
            parents = Set.empty(),
            unresolvedImports = 0,
            unresolvedCalls = 0
        }
    }
}
