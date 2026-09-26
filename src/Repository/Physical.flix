pub mod Repository.Physical {
    type alias Index[a, b] = Map[a, Set[b]]

    /// Level 3 stores only admitted relations and their inexpensive inverses.
    /// Large derived relations (notably same-file cliques) are never materialized.
    pub type alias World = {
        defines    = Index[Kernel.Contract.FileId, Kernel.Contract.SymbolId],
        definedIn  = Index[Kernel.Contract.SymbolId, Kernel.Contract.FileId],
        imports    = Index[Kernel.Contract.FileId, Kernel.Contract.FileId],
        importedBy = Index[Kernel.Contract.FileId, Kernel.Contract.FileId],
        calls      = Index[Kernel.Contract.SymbolId, Kernel.Contract.SymbolId],
        callers    = Index[Kernel.Contract.SymbolId, Kernel.Contract.SymbolId],
        parents    = Index[Kernel.Contract.LocationId, Kernel.Contract.LocationId],
        children   = Index[Kernel.Contract.LocationId, Kernel.Contract.LocationId]
    }

    pub def fromBasis(
        defines: Kernel.Contract.Defines,
        imports: Kernel.Contract.Imports,
        calls: Kernel.Contract.Calls,
        parents: Kernel.Contract.Parents
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

    pub def defines(world: World, files: Set[Kernel.Contract.FileId]): Set[Kernel.Contract.SymbolId] =
        apply(world#defines, files)

    pub def definedIn(world: World, symbols: Set[Kernel.Contract.SymbolId]): Set[Kernel.Contract.FileId] =
        apply(world#definedIn, symbols)

    pub def imports(world: World, files: Set[Kernel.Contract.FileId]): Set[Kernel.Contract.FileId] =
        apply(world#imports, files)

    pub def importedBy(world: World, files: Set[Kernel.Contract.FileId]): Set[Kernel.Contract.FileId] =
        apply(world#importedBy, files)

    pub def calls(world: World, symbols: Set[Kernel.Contract.SymbolId]): Set[Kernel.Contract.SymbolId] =
        apply(world#calls, symbols)

    pub def callers(world: World, symbols: Set[Kernel.Contract.SymbolId]): Set[Kernel.Contract.SymbolId] =
        apply(world#callers, symbols)

    pub def sameFile(world: World, symbols: Set[Kernel.Contract.SymbolId]): Set[Kernel.Contract.SymbolId] =
        defines(world, definedIn(world, symbols))

    pub def importNeighbors(world: World, symbols: Set[Kernel.Contract.SymbolId]): Set[Kernel.Contract.SymbolId] =
        defines(world, imports(world, definedIn(world, symbols)))

    pub def importerNeighbors(world: World, symbols: Set[Kernel.Contract.SymbolId]): Set[Kernel.Contract.SymbolId] =
        defines(world, importedBy(world, definedIn(world, symbols)))

    pub def parents(world: World, locations: Set[Kernel.Contract.LocationId]): Set[Kernel.Contract.LocationId] =
        apply(world#parents, locations)

    pub def children(world: World, locations: Set[Kernel.Contract.LocationId]): Set[Kernel.Contract.LocationId] =
        apply(world#children, locations)

    pub def repositoryAdjacent(world: World, locations: Set[Kernel.Contract.LocationId]): Set[Kernel.Contract.LocationId] =
        Set.union(parents(world, locations), children(world, locations))

    def index(edges: Kernel.Contract.Relation[a, b]): Index[a, b] with Order[a], Order[b] =
        Set.foldLeft((known, edge) -> {
            let (source, target) = edge;
            Map.insert(source, Set.insert(target, Map.getWithDefault(source, Set.empty(), known)), known)
        }, Map.empty(), edges)

    def reverseIndex(edges: Kernel.Contract.Relation[a, b]): Index[b, a] with Order[a], Order[b] =
        index(Set.map(match (source, target) -> (target, source), edges))

    def apply(edges: Index[a, b], input: Set[a]): Set[b] with Order[a], Order[b] =
        Set.foldLeft((output, source) ->
            Set.union(output, Map.getWithDefault(source, Set.empty(), edges)),
            Set.empty(), input)
}
