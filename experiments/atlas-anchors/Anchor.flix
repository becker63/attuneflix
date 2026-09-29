/// Derived measurements over an unchanged, typed Atlas signature workload.
/// Directory prefixes identify candidates; only File/Symbol members enter states.
pub mod Anchor {
    use Repository.Structure.{FileId, SymbolId}

    pub type alias Decomposition = {
        observations = Int32,
        extinctObservations = Int32,
        liveObservations = Int32,
        uniqueStates = Int32,
        uniqueLiveStates = Int32,
        totalRecurrence = Float64,
        liveRecurrence = Float64
    }

    pub type alias Mass = {
        anchorPath = String,
        uniqueContaining = Int32,
        weightedContaining = Int32,
        uniqueLiveStates = Int32,
        liveObservations = Int32,
        uniqueFraction = Float64,
        weightedFraction = Float64
    }

    type alias Hits = {unique = Int32, weighted = Int32}

    /// One typed empty state per terminal domain. Extinct observations are
    /// excluded before computing live recurrence, never treated as zero work.
    pub def decompose(outputs: Vector[Atlas.State]): Decomposition = {
        let total = Vector.length(outputs);
        let live = Vector.filter(state -> Atlas.cardinality(state) > 0, outputs);
        let extinct = total - Vector.length(live);
        let unique = Set.size(Vector.toSet(outputs));
        let uniqueLive = Set.size(Vector.toSet(live));
        {
            observations = total,
            extinctObservations = extinct,
            liveObservations = Vector.length(live),
            uniqueStates = unique,
            uniqueLiveStates = uniqueLive,
            totalRecurrence = ScientificTable.ratio(total, unique),
            liveRecurrence = ScientificTable.ratio(Vector.length(live), uniqueLive)
        }
    }

    /// A boundary mask removes only admitted imports/calls with exactly one
    /// endpoint below the anchor path. All files, symbols, definitions and parents
    /// retain their original identities. Atlas evaluates the returned World
    /// with its ordinary unchanged evaluator.
    pub def maskBoundary(world: Repository.World, anchorPath: String): Repository.World = {
        let imports = Set.filter(match (FileId.FileId(source), FileId.FileId(target)) ->
            contains(Vector.get(source, world#files), anchorPath) ==
                contains(Vector.get(target, world#files), anchorPath), world#imports);
        let calls = Set.filter(match (SymbolId.SymbolId(source), SymbolId.SymbolId(target)) ->
            contains(Vector.get(source, world#symbols)#path, anchorPath) ==
                contains(Vector.get(target, world#symbols)#path, anchorPath), world#calls);
        {
            files = world#files, symbols = world#symbols, defines = world#defines,
            imports = imports, calls = calls, parents = world#parents,
            unresolvedImports = world#unresolvedImports,
            unresolvedCalls = world#unresolvedCalls
        }
    }

    pub def contains(path: String, anchorPath: String): Bool =
        anchorPath != "" and (path == anchorPath or String.startsWith(prefix = anchorPath + "/", path))

    pub def crossingVolume(world: Repository.World, anchorPath: String): Int32 = {
        let imports = Set.count(match (FileId.FileId(source), FileId.FileId(target)) ->
            contains(Vector.get(source, world#files), anchorPath) !=
                contains(Vector.get(target, world#files), anchorPath), world#imports);
        let calls = Set.count(match (SymbolId.SymbolId(source), SymbolId.SymbolId(target)) ->
            contains(Vector.get(source, world#symbols)#path, anchorPath) !=
                contains(Vector.get(target, world#symbols)#path, anchorPath), world#calls);
        imports + calls
    }

    /// Choose sibling directory controls closest in admitted crossing-edge
    /// volume, with path ordering as the deterministic tie break.
    pub def controls(world: Repository.World, target: String, count: Int32): Vector[String] = {
        let volume = crossingVolume(world, target);
        Repository.Location.directories(world)
            |> Vector.filter(path -> path != target and
                Repository.Location.directory(path) == Repository.Location.directory(target) and
                crossingVolume(world, path) > 0)
            |> Vector.sortBy(path -> (absolute(crossingVolume(world, path) - volume), path))
            |> Vector.take(count)
    }

    def absolute(value: Int32): Int32 = if (value < 0) -value else value

    /// A logical observation contributes once to its exact state; equal states
    /// are merged before walking the members, so unique and weighted masses
    /// share one state-to-anchor derivation.
    pub def masses(world: Repository.World, outputs: Vector[Atlas.State]): Vector[Mass] = {
        let counts = Vector.foldLeft((known, state) ->
            Map.insertWith((left, right) -> left + right, state, 1, known),
            Map.empty(), outputs);
        let live = Map.toVector(counts)
            |> Vector.filter(match (state, _) -> Atlas.cardinality(state) > 0);
        let totalWeighted = Vector.foldLeft((sum, pair) -> {
            let (_, weight) = pair;
            sum + weight
        }, 0, live);
        let byRegion = Vector.foldLeft((known, pair) -> {
            let (state, weight) = pair;
            Set.foldLeft((acc, anchorPath) ->
                Map.insertWith((left, right) -> {
                    unique = left#unique + right#unique,
                    weighted = left#weighted + right#weighted
                }, anchorPath, {unique = 1, weighted = weight}, acc),
                known, regionsInState(world, state))
        }, Map.empty(), live);
        Repository.Location.directories(world)
            |> Vector.filter(path -> path != "")
            |> Vector.map(anchorPath -> {
                let hits = Map.get(anchorPath, byRegion)
                    |> Option.getWithDefault({unique = 0, weighted = 0});
                {
                    anchorPath = anchorPath,
                    uniqueContaining = hits#unique,
                    weightedContaining = hits#weighted,
                    uniqueLiveStates = Vector.length(live),
                    liveObservations = totalWeighted,
                    uniqueFraction = ScientificTable.ratio(hits#unique, Vector.length(live)),
                    weightedFraction = ScientificTable.ratio(hits#weighted, totalWeighted)
                }
            })
            |> Vector.sortBy(row -> (-row#weightedContaining, -row#uniqueContaining, row#anchorPath))
    }

    def regionsInState(world: Repository.World, state: Atlas.State): Set[String] = match state {
        case Atlas.State.Files(files) => Set.foldLeft((known, file) -> match file {
            case FileId.FileId(id) => Set.union(known, ancestors(Vector.get(id, world#files)))
        }, Set.empty(), files)
        case Atlas.State.Symbols(symbols) => Set.foldLeft((known, symbol) -> match symbol {
            case SymbolId.SymbolId(id) => Set.union(known, ancestors(Vector.get(id, world#symbols)#path))
        }, Set.empty(), symbols)
    }

    def ancestors(path: String): Set[String] = ancestorsFrom(Repository.Location.directory(path), Set.empty())

    def ancestorsFrom(anchorPath: String, known: Set[String]): Set[String] =
        if (anchorPath == "") known
        else ancestorsFrom(Repository.Location.directory(anchorPath), Set.insert(anchorPath, known))
}
