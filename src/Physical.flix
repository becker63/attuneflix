mod Physical {
    /// Level 3 stores only admitted relations and their inexpensive inverses.
    /// Large derived relations (notably same-file cliques) are never materialized.
    pub type alias World = {
        defines    = Structure.Defines,
        definedIn  = Structure.Relation[Structure.SymbolId, Structure.FileId],
        imports    = Structure.Imports,
        importedBy = Structure.Relation[Structure.FileId, Structure.FileId],
        calls      = Structure.Calls,
        callers    = Structure.SymbolRelation,
        parents    = Structure.Parents,
        children   = Structure.LocationRelation
    }

    pub def fromBasis(
        defines: Structure.Defines,
        imports: Structure.Imports,
        calls: Structure.Calls,
        parents: Structure.Parents
    ): World = {
        defines = defines,
        definedIn = reverse(defines),
        imports = imports,
        importedBy = reverse(imports),
        calls = calls,
        callers = reverse(calls),
        parents = parents,
        children = reverse(parents)
    }

    pub def defines(world: World, files: Set[Structure.FileId]): Set[Structure.SymbolId] =
        apply(world#defines, files)

    pub def definedIn(world: World, symbols: Set[Structure.SymbolId]): Set[Structure.FileId] =
        apply(world#definedIn, symbols)

    pub def imports(world: World, files: Set[Structure.FileId]): Set[Structure.FileId] =
        apply(world#imports, files)

    pub def importedBy(world: World, files: Set[Structure.FileId]): Set[Structure.FileId] =
        apply(world#importedBy, files)

    pub def calls(world: World, symbols: Set[Structure.SymbolId]): Set[Structure.SymbolId] =
        apply(world#calls, symbols)

    pub def callers(world: World, symbols: Set[Structure.SymbolId]): Set[Structure.SymbolId] =
        apply(world#callers, symbols)

    pub def sameFile(world: World, symbols: Set[Structure.SymbolId]): Set[Structure.SymbolId] =
        defines(world, definedIn(world, symbols))

    pub def importNeighbors(world: World, symbols: Set[Structure.SymbolId]): Set[Structure.SymbolId] =
        defines(world, imports(world, definedIn(world, symbols)))

    pub def importerNeighbors(world: World, symbols: Set[Structure.SymbolId]): Set[Structure.SymbolId] =
        defines(world, importedBy(world, definedIn(world, symbols)))

    pub def parents(world: World, locations: Set[Structure.LocationId]): Set[Structure.LocationId] =
        apply(world#parents, locations)

    pub def children(world: World, locations: Set[Structure.LocationId]): Set[Structure.LocationId] =
        apply(world#children, locations)

    pub def repositoryAdjacent(world: World, locations: Set[Structure.LocationId]): Set[Structure.LocationId] =
        Set.union(parents(world, locations), children(world, locations))

    def reverse(edges: Structure.Relation[a, b]): Structure.Relation[b, a] with Order[a], Order[b] =
        Set.map(match (source, target) -> (target, source), edges)

    def apply(edges: Structure.Relation[a, b], input: Set[a]): Set[b] with Order[a], Order[b] =
        Set.foldLeft((output, edge) -> {
            let (source, target) = edge;
            if (Set.memberOf(source, input)) Set.insert(target, output) else output
        }, Set.empty(), edges)
}
