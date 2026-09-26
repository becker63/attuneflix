/// Repository structure: the readable Datalog meaning. Nominal identities and
/// the physical relation shapes are owned by the Stable Contract Kernel; this
/// module keeps only the materialized world type and the permanent rules.
pub mod Repository.Structure {
    use Kernel.Contract.{Calls, Defines, FileId, Imports, LocationId, Parents, SymbolId}

    /// Materialized result of solving the permanent facts with the catalog.
    pub type alias Repository = #{
        Defines(FileId, SymbolId),
        Imports(FileId, FileId),
        Calls(SymbolId, SymbolId),
        Parent(LocationId, LocationId),
        DefinedIn(SymbolId, FileId),
        ImportedBy(FileId, FileId),
        Caller(SymbolId, SymbolId),
        SameFile(SymbolId, SymbolId),
        ImportNeighbor(SymbolId, SymbolId),
        ImporterNeighbor(SymbolId, SymbolId),
        RepositoryAdjacent(LocationId, LocationId)
    }

    /// The permanent basis is one typed, first-class constraint value.
    pub def repositoryFacts(
        defines: Defines,
        imports: Imports,
        calls: Calls,
        parents: Parents
    ): #{
        Defines(FileId, SymbolId),
        Imports(FileId, FileId),
        Calls(SymbolId, SymbolId),
        Parent(LocationId, LocationId) | r
    } = inject defines, imports, calls, parents into Defines/2, Imports/2, Calls/2, Parent/2

    /// The complete named catalog of structural rules.
    pub def structuralRules(): #{
        Defines(FileId, SymbolId),
        Imports(FileId, FileId),
        Calls(SymbolId, SymbolId),
        Parent(LocationId, LocationId),
        DefinedIn(SymbolId, FileId),
        ImportedBy(FileId, FileId),
        Caller(SymbolId, SymbolId),
        SameFile(SymbolId, SymbolId),
        ImportNeighbor(SymbolId, SymbolId),
        ImporterNeighbor(SymbolId, SymbolId),
        RepositoryAdjacent(LocationId, LocationId) | r
    } = #{
        DefinedIn(symbol, file) :- Defines(file, symbol).
        ImportedBy(target, source) :- Imports(source, target).
        Caller(callee, caller) :- Calls(caller, callee).
        SameFile(x, y) :- Defines(file, x), Defines(file, y).
        ImportNeighbor(x, y) :- Defines(source, x), Imports(source, target), Defines(target, y).
        ImporterNeighbor(x, y) :- Defines(target, x), Imports(source, target), Defines(source, y).
        RepositoryAdjacent(x, y) :- Parent(x, y).
        RepositoryAdjacent(x, y) :- Parent(y, x).
    }
}
