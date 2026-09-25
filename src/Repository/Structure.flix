pub mod Repository.Structure {
    /// Repository identities are nominal: the compiler rejects mixed domains.
    pub enum FileId(Int32) with Eq, Order, ToString, Hash
    pub enum SymbolId(Int32) with Eq, Order, ToString, Hash
    pub enum LocationId(Int32) with Eq, Order, ToString, Hash

    /// A physical shape, not a semantic relation name.
    pub type alias Relation[a, b] = Set[(a, b)]

    pub type alias Defines = Relation[FileId, SymbolId]
    pub type alias Imports = Relation[FileId, FileId]
    pub type alias Calls = Relation[SymbolId, SymbolId]
    pub type alias Parents = Relation[LocationId, LocationId]

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
