pub mod Repository.Physical {
    type alias Index[a, b] = Map[a, Set[b]]

    /// Level 3 stores only admitted relations and their inexpensive inverses.
    /// Large derived relations (notably same-file cliques) are never materialized.
    pub type alias World = {
        defines    = Index[Repository.Structure.FileId, Repository.Structure.SymbolId],
        definedIn  = Index[Repository.Structure.SymbolId, Repository.Structure.FileId],
        imports    = Index[Repository.Structure.FileId, Repository.Structure.FileId],
        importedBy = Index[Repository.Structure.FileId, Repository.Structure.FileId],
        calls      = Index[Repository.Structure.SymbolId, Repository.Structure.SymbolId],
        callers    = Index[Repository.Structure.SymbolId, Repository.Structure.SymbolId],
        parents    = Index[Repository.Structure.LocationId, Repository.Structure.LocationId],
        children   = Index[Repository.Structure.LocationId, Repository.Structure.LocationId]
    }

    pub def fromBasis(
        defines: Repository.Structure.Defines,
        imports: Repository.Structure.Imports,
        calls: Repository.Structure.Calls,
        parents: Repository.Structure.Parents
    ): World = {
        defines = index(defines),
        definedIn = reverseIndex(defines),
        imports = index(imports),
        importedBy = reverseIndex(imports),
        calls = index(calls),
        callers = reverseIndex(calls),
        parents = index(parents),
        children = reverseIndex(parents)
    }

    pub def defines(world: World, files: Set[Repository.Structure.FileId]): Set[Repository.Structure.SymbolId] =
        apply(world#defines, files)

    pub def definedIn(world: World, symbols: Set[Repository.Structure.SymbolId]): Set[Repository.Structure.FileId] =
        apply(world#definedIn, symbols)

    pub def imports(world: World, files: Set[Repository.Structure.FileId]): Set[Repository.Structure.FileId] =
        apply(world#imports, files)

    pub def importedBy(world: World, files: Set[Repository.Structure.FileId]): Set[Repository.Structure.FileId] =
        apply(world#importedBy, files)

    pub def calls(world: World, symbols: Set[Repository.Structure.SymbolId]): Set[Repository.Structure.SymbolId] =
        apply(world#calls, symbols)

    pub def callers(world: World, symbols: Set[Repository.Structure.SymbolId]): Set[Repository.Structure.SymbolId] =
        apply(world#callers, symbols)

    pub def sameFile(world: World, symbols: Set[Repository.Structure.SymbolId]): Set[Repository.Structure.SymbolId] =
        defines(world, definedIn(world, symbols))

    pub def importNeighbors(world: World, symbols: Set[Repository.Structure.SymbolId]): Set[Repository.Structure.SymbolId] =
        defines(world, imports(world, definedIn(world, symbols)))

    pub def importerNeighbors(world: World, symbols: Set[Repository.Structure.SymbolId]): Set[Repository.Structure.SymbolId] =
        defines(world, importedBy(world, definedIn(world, symbols)))

    pub def parents(world: World, locations: Set[Repository.Structure.LocationId]): Set[Repository.Structure.LocationId] =
        apply(world#parents, locations)

    pub def children(world: World, locations: Set[Repository.Structure.LocationId]): Set[Repository.Structure.LocationId] =
        apply(world#children, locations)

    pub def repositoryAdjacent(world: World, locations: Set[Repository.Structure.LocationId]): Set[Repository.Structure.LocationId] =
        Set.union(parents(world, locations), children(world, locations))

    def index(edges: Repository.Structure.Relation[a, b]): Index[a, b] with Order[a], Order[b] =
        Set.foldLeft((known, edge) -> {
            let (source, target) = edge;
            Map.insert(source, Set.insert(target, Map.getWithDefault(source, Set.empty(), known)), known)
        }, Map.empty(), edges)

    def reverseIndex(edges: Repository.Structure.Relation[a, b]): Index[b, a] with Order[a], Order[b] =
        index(Set.map(match (source, target) -> (target, source), edges))

    def apply(edges: Index[a, b], input: Set[a]): Set[b] with Order[a], Order[b] =
        Set.foldLeft((output, source) ->
            Set.union(output, Map.getWithDefault(source, Set.empty(), edges)),
            Set.empty(), input)
}
