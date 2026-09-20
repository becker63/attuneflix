mod Structure {
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
    pub type alias SymbolRelation = Relation[SymbolId, SymbolId]
    pub type alias LocationRelation = Relation[LocationId, LocationId]

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

    pub def inverseRules(): #{
        Defines(FileId, SymbolId),
        Imports(FileId, FileId),
        Calls(SymbolId, SymbolId),
        DefinedIn(SymbolId, FileId),
        ImportedBy(FileId, FileId),
        Caller(SymbolId, SymbolId) | r
    } = #{
        DefinedIn(symbol, file) :- Defines(file, symbol).
        ImportedBy(target, source) :- Imports(source, target).
        Caller(callee, caller) :- Calls(caller, callee).
    }

    pub def sameFileRules(): #{
        Defines(FileId, SymbolId),
        SameFile(SymbolId, SymbolId) | r
    } = #{
        SameFile(x, y) :- Defines(file, x), Defines(file, y).
    }

    pub def importRules(): #{
        Defines(FileId, SymbolId),
        Imports(FileId, FileId),
        ImportNeighbor(SymbolId, SymbolId),
        ImporterNeighbor(SymbolId, SymbolId) | r
    } = #{
        ImportNeighbor(x, y) :- Defines(source, x), Imports(source, target), Defines(target, y).
        ImporterNeighbor(x, y) :- Defines(target, x), Imports(source, target), Defines(source, y).
    }

    pub def locationRules(): #{
        Parent(LocationId, LocationId),
        RepositoryAdjacent(LocationId, LocationId) | r
    } = #{
        RepositoryAdjacent(x, y) :- Parent(x, y).
        RepositoryAdjacent(x, y) :- Parent(y, x).
    }

    /// The complete named catalog is itself a composition of small rule values.
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
    } = inverseRules() <+> sameFileRules() <+> importRules() <+> locationRules()

    /// Tiny projections keep callers out of predicate plumbing while rules stay declarative.
    pub def sameFile(defines: Defines): SymbolRelation =
        let facts = inject defines into Defines/2;
        query facts, sameFileRules() select (x, y) from SameFile(x, y) |> Vector.toSet

    pub def callers(calls: Calls): SymbolRelation =
        let facts = inject calls into Calls/2;
        query facts, inverseRules() select (callee, caller) from Caller(callee, caller) |> Vector.toSet

    pub def importNeighbors(defines: Defines, imports: Imports): SymbolRelation =
        let facts = inject defines, imports into Defines/2, Imports/2;
        query facts, importRules() select (x, y) from ImportNeighbor(x, y) |> Vector.toSet

    pub def importerNeighbors(defines: Defines, imports: Imports): SymbolRelation =
        let facts = inject defines, imports into Defines/2, Imports/2;
        query facts, importRules() select (x, y) from ImporterNeighbor(x, y) |> Vector.toSet

    pub def repositoryAdjacent(parents: Parents): LocationRelation =
        let facts = inject parents into Parent/2;
        query facts, locationRules() select (x, y) from RepositoryAdjacent(x, y) |> Vector.toSet
}
