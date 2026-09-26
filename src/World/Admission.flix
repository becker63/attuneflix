/// Admission: turn one canonical set of raw Grit facts plus the admitted
/// source paths into the typed admitted world. Admission is pure — the world
/// is a function of its facts alone — so it stays independently testable from
/// the native acquisition effect, and every language reaches it through the
/// one fact protocol.
pub mod World.Admission {
    pub def admit(
        sources: Vector[Kernel.Contract.SourceFile],
        definitions0: Vector[Repository.Grit.Fact],
        importFacts: Vector[Repository.Grit.Fact],
        callFacts: Vector[Repository.Grit.Fact]
    ): Result[World.Error, Kernel.Contract.AdmittedWorld] = {
        let definitions = canonicalDefinitions(definitions0);
        let paths = Vector.map(source -> source#path, sources);
        let fileIds = Vector.mapWithIndex((index, path) -> (path, Kernel.Contract.FileId.FileId(index)), paths)
            |> Vector.toMap;
        let identities = Vector.mapWithIndex(
            (index, fact) -> (fact, Kernel.Contract.SymbolId.SymbolId(index)),
            definitions
        );
        let called = World.CallIndex.resolveCalls(identities, callFacts);
        forM (
            defines <- definitionEdges(fileIds, identities);
            imported <- resolveImports(fileIds, importFacts)
        ) yield {
            files = paths,
            symbols = Vector.map(fact -> {
                path = fact#path,
                name = fact#value,
                startByte = fact#startByte,
                endByte = fact#endByte
            }, definitions),
            defines = defines,
            imports = imported#edges,
            calls = called#edges,
            parents = parentEdges(paths),
            unresolvedImports = imported#rejected,
            unresolvedCalls = called#rejected
        }
    }

    /// Grit emits definitions in canonical source/byte order. Retained worlds
    /// therefore normally arrive sorted already. Detect that linear case
    /// before calling the standard-library quicksort: on very large snapshots
    /// its recursive partitioning otherwise takes the worst-case path for an
    /// already-sorted vector. Unordered API callers retain the exact previous
    /// sorting rule.
    def canonicalDefinitions(definitions: Vector[Repository.Grit.Fact]): Vector[Repository.Grit.Fact] =
        if (definitionsOrdered(definitions, 1)) definitions
        else Vector.sortBy(factKey, definitions)

    def definitionsOrdered(
        definitions: Vector[Repository.Grit.Fact],
        index: Int32
    ): Bool =
        if (index >= Vector.length(definitions)) true
        else if (Order.lessEqual(
            factKey(Vector.get(index - 1, definitions)),
            factKey(Vector.get(index, definitions))))
            definitionsOrdered(definitions, index + 1)
        else false

    def factKey(fact: Repository.Grit.Fact): (String, Int32, Int32, String) =
        (fact#path, fact#startByte, fact#endByte, fact#value)

    def definitionEdges(
        files: Map[String, Kernel.Contract.FileId],
        identities: Vector[World.Identity]
    ): Result[World.Error, Kernel.Contract.Defines] =
        Vector.traverse(match (fact, symbol) ->
            Map.get(fact#path, files)
                |> Option.toOk(World.Error.UnknownFactPath(fact#path))
                |> Result.map(file -> (file, symbol)),
            identities)
        |> Result.map(Vector.toSet)

    def resolveImports(
        files: Map[String, Kernel.Contract.FileId],
        facts: Vector[Repository.Grit.Fact]
    ): Result[World.Error, World.Resolution[Kernel.Contract.FileId, Kernel.Contract.FileId]] =
        Vector.foldLeft((checked, fact) -> checked |> Result.flatMap(resolved ->
            match Map.get(fact#path, files) {
                case None => Err(World.Error.UnknownFactPath(fact#path))
                case Some(source) => match World.Language.importTarget(fact, files) {
                    case None => Ok({edges = resolved#edges, rejected = resolved#rejected + 1})
                    case Some(target) => Ok({edges = Set.insert((source, target), resolved#edges), rejected = resolved#rejected})
                }
            }), Ok({edges = Set.empty(), rejected = 0}), facts)

    /// The admitted parent relation: each admitted file points at its directory
    /// location, and each nested directory at its parent. Directory locations
    /// are nominal ids offset past the file ordinals, so file and directory
    /// identities never collide.
    def parentEdges(paths: Vector[String]): Kernel.Contract.Parents = {
        let directories = Vector.foldLeft(
            (known, path) -> Set.union(known, World.directoryPrefixes(World.directory(path))),
            Set.singleton(""),
            paths
        ) |> Set.toVector |> Vector.sort;
        let offset = Vector.length(paths);
        let identities = Vector.mapWithIndex(
            (index, path) -> (path, Kernel.Contract.LocationId.LocationId(offset + index)),
            directories
        ) |> Vector.toMap;
        let fileParents = Vector.mapWithIndex((index, path) ->
            (Kernel.Contract.LocationId.LocationId(index), Option.getWithDefault(
                Kernel.Contract.LocationId.LocationId(0),
                Map.get(World.directory(path), identities)
            )), paths);
        let directoryParents = Vector.filterMap(path ->
            if (path == "") None
            else forM (
                child <- Map.get(path, identities);
                parent <- Map.get(World.directory(path), identities)
            ) yield (child, parent),
            directories);
        Vector.append(fileParents, directoryParents) |> Vector.toSet
    }
}
