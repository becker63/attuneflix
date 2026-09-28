/// The deterministic rollup of symbol-grain families to the admitted
/// locations: a file holds the members it defines (`Defines`), and a
/// directory holds the members of every file below it (the admitted `parent`
/// prefixes, root included). The rollup is a pure function of the member
/// assignment and the world, so it can always be recomputed from the typed
/// member table.
pub mod Families.Rollup {
    use Repository.Structure.{FileId, LocationId, SymbolId}

    /// How many members of one family one location holds, out of all the
    /// symbols it holds, and whether that family is the location's dominant
    /// one (the most members, the least family on a tie).
    pub type alias Rollup = {
        level           = String,
        locationId      = Int32,
        location        = String,
        family          = Int32,
        familyId        = String,
        members         = Int32,
        locationMembers = Int32,
        dominant        = Bool
    }

    pub def fileLevel(): String = "file"
    pub def directoryLevel(): String = "directory"

    /// Rollup rows from `(symbol, family, family identity)` assignments: file
    /// rows then directory rows, each by location id, then by family.
    pub def rollups(world: Repository.World, assignments: Vector[(Int32, Int32, String)]): Vector[Rollup] = {
        let locations = Repository.Location.locations(world);
        let directoryIds = Vector.filterMap(match (LocationId.LocationId(id), path, kind) ->
            if (kind == Repository.Location.LocationKind.Directory) Some((path, id)) else None, locations) |> Vector.toMap;
        let paths = Vector.map(match (_, path, _) -> path, locations);
        let definedIn = Set.toVector(world#defines) |> Vector.foldLeft((known, pair) -> {
            let (FileId.FileId(file), SymbolId.SymbolId(symbol)) = pair;
            Map.insertWith(Set.union, symbol, Set#{file}, known)
        }, Map.empty());
        let placesOf = symbol -> {
            let files = Map.getWithDefault(symbol, Set.empty(), definedIn);
            let directories = Set.flatMap(file -> ancestors(Vector.get(file, world#files))
                |> Vector.filterMap(path -> Map.get(path, directoryIds)) |> Vector.toSet, files);
            Set.union(Set.map(file -> (0, file), files), Set.map(id -> (1, id), directories))
        };
        let counts = Vector.foldLeft((known, assignment) -> {
            let (symbol, family, _) = assignment;
            Set.foldLeft((inner, place) -> Map.insertWith((later, earlier) -> Map.unionWith((a, b) -> a + b, earlier, later),
                place, Map#{family => 1}, inner), known, placesOf(symbol))
        }, Map.empty(), assignments);
        let familyIds = Vector.map(match (_, family, id) -> (family, id), assignments) |> Vector.toMap;
        Map.toVector(counts) |> Vector.flatMap(match ((rank, id), byFamily) -> {
            let total = Map.foldLeft((sum, count) -> sum + count, 0, byFamily);
            let dominant = Map.foldLeftWithKey((best, family, count) -> match best {
                case Some((_, kept)) if kept >= count => best
                case _ => Some((family, count))
            }, None, byFamily) |> Option.map(fst);
            Map.toVector(byFamily) |> Vector.map(match (family, count) -> {
                level = if (rank == 0) fileLevel() else directoryLevel(),
                locationId = id,
                location = Vector.get(id, paths),
                family = family,
                familyId = Map.getWithDefault(family, "", familyIds),
                members = count,
                locationMembers = total,
                dominant = dominant == Some(family)
            })
        })
    }

    /// Every directory prefix above an admitted path, nearest first, ending
    /// with the repository root `""`.
    pub def ancestors(path: String): Vector[String] = {
        let parent = Repository.Location.directory(path);
        if (parent == "") Vector#{""} else Vector.append(Vector#{parent}, ancestors(parent))
    }
}
