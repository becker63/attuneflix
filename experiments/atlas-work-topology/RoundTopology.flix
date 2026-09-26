/// The candidate's static work-topology (PREREGISTRATION.md §4, §5, §6;
/// VAL-HC1-003).
///
/// The frozen control basis graph is kept exactly as measured (no
/// re-acquisition, §11); every endpoint is translated to its candidate
/// `current_path` on the §9 logical-identity layer, and then the SAME fixed §4
/// region rule and the §5-amended cell rule are applied to the candidate paths.
/// A pure move therefore re-homes the moved law files (e.g. `build/src/...` law
/// leaves the `build-src` region, which becomes empty and is dropped per §4)
/// without touching one admitted relation. Partition-agnostic machinery
/// (`mergeBy`, `crosses`, `interGroups`, `jaccard`, `percentile`, the depth-2
/// Atlas family) is reused from `ControlTopology`, never reimplemented.
mod RoundTopology {
    pub type alias Mapping = Map[String, String]

    /// Translate one control path to its candidate path (identity if unmapped).
    pub def current(mapping: Mapping, path: String): String = Map.getWithDefault(path, path, mapping)

    pub def regionEdges(world: Repository.World, mapping: Mapping): Vector[(String, String)] =
        Vector.map(match (source, target) ->
            (ControlMap.regionOf(current(mapping, source)), ControlMap.regionOf(current(mapping, target))),
            ControlTopology.edgePaths(world))

    pub def cellEdges(world: Repository.World, mapping: Mapping): Vector[(String, String)] =
        Vector.map(match (source, target) ->
            (ControlMap.roundCellOf(current(mapping, source)), ControlMap.roundCellOf(current(mapping, target))),
            ControlTopology.edgePaths(world))

    pub def regionFiles(world: Repository.World, mapping: Mapping, region0: String): Vector[String] =
        Vector.filterMap(path ->
            if (ControlMap.regionOf(current(mapping, path)) == region0) Some(current(mapping, path)) else None,
            world#files)

    pub def regionCells(world: Repository.World, mapping: Mapping, cell0: String): Vector[String] =
        Vector.filter(path -> ControlMap.roundCellOf(current(mapping, path)) == cell0, world#files)

    /// §4: regions with no candidate files are dropped from the candidate's
    /// analyses rather than reported as zero-valued phantoms.
    pub def nonEmptyRegions(world: Repository.World, mapping: Mapping): Vector[String] =
        Vector.filter(region0 -> not Vector.isEmpty(regionFiles(world, mapping, region0)), ControlMap.regions())

    // ---- T4: the same frozen greedy k-way cut over candidate regions ----

    pub def regionGroups(world: Repository.World, mapping: Mapping, k: Int32): Vector[(String, Set[String])] = {
        let seeds = Vector.map(region0 -> (region0, Set#{region0}), nonEmptyRegions(world, mapping));
        ControlTopology.mergeBy((a, b) -> ControlTopology.interGroups(regionEdges(world, mapping), a, b), k,
            Vector.sortBy(match (name, _) -> name, seeds))
    }

    pub def crossEdges(world: Repository.World, mapping: Mapping, k: Int32): Int32 =
        Vector.count(match (f, t) -> ControlTopology.crosses(regionGroups(world, mapping, k), f, t),
            regionEdges(world, mapping))

    pub def cutCounts(world: Repository.World, mapping: Mapping): Vector[(Int32, Int32)] =
        Vector.map(k -> (k, crossEdges(world, mapping, k)), ControlTopology.cutDepths())

    // ---- T5: the amended K4 ownership-cell cut ----

    pub def cellCut(world: Repository.World, mapping: Mapping): ControlTopology.CellCut =
        ControlTopology.cellCutFor(ControlTopology.fourCells(), cellEdges(world, mapping))

    // ---- T6: coherence over candidate regions ----

    /// T8: non-empty candidate regions that no non-test-side region uses into.
    /// The frozen test-side rule is reused unchanged; after round 1 `tests` is
    /// the only test-side region left (`build-src` is empty and dropped).
    pub def independentlyTestableRegions(world: Repository.World, mapping: Mapping): Vector[String] = {
        let edges = regionEdges(world, mapping);
        Vector.filter(region0 -> ControlTopology.independentlyTestable(edges, region0),
            nonEmptyRegions(world, mapping))
    }

    pub def minCoherence(world: Repository.World, mapping: Mapping): (String, Float64) = {
        let edges = regionEdges(world, mapping);
        Vector.foldLeft((best, region0) -> {
            let value = ControlTopology.coherence(edges, region0);
            if (value < snd(best)) (region0, value) else best
        }, ("", 1.0), nonEmptyRegions(world, mapping))
    }

    // ---- T7: hotspot pressure over candidate regions ----

    pub def hotspotFiles(world: Repository.World, mapping: Mapping): Vector[(String, Vector[String], Int32)] = {
        let pressures = Vector.foldLeft((acc, edge) -> match edge {
            case (f, g) => {
                let rf = ControlMap.regionOf(current(mapping, ControlTopology.fileIdentity(world, f)));
                let rg = ControlMap.regionOf(current(mapping, ControlTopology.fileIdentity(world, g)));
                if (rf == rg) acc
                else Map.insert(g, Set.insert(rf, Map.getWithDefault(g, Set.empty(), acc)), acc)
            }
        }, Map.empty(), Set.toVector(world#imports));
        Vector.map(match (id, regions0) ->
            (current(mapping, ControlTopology.fileIdentity(world, id)), Vector.sort(Set.toVector(regions0)), Set.size(regions0)),
            Map.toVector(pressures))
            |> Vector.filter(match (_, _, pressure) -> pressure >= 2)
            |> Vector.sortBy(match (path, _, pressure) -> (0 - pressure, path))
    }

    pub def maxHotspotPressure(world: Repository.World, mapping: Mapping): Int32 =
        Vector.foldLeft((best, entry) -> match entry {
            case (_, _, pressure) => if (pressure > best) pressure else best
        }, 0, hotspotFiles(world, mapping))

    // ---- T9/T10: ATLAS depth-<=2 neighborhoods over candidate regions ----

    def regionSeed(world: Repository.World, mapping: Mapping, region0: String): Set[Repository.Structure.FileId] =
        Vector.mapWithIndex((index, path) -> (path, Repository.Structure.FileId.FileId(index)), world#files)
            |> Vector.filterMap(match (path, id) ->
                if (ControlMap.regionOf(current(mapping, path)) == region0) Some(id) else None)
            |> Vector.toSet

    def neighborhood(world: Repository.World, mapping: Mapping, region0: String): Set[String] = {
        let seed = regionSeed(world, mapping, region0);
        Set.union(
            Set.map(id -> current(mapping, ControlTopology.fileIdentity(world, id)), seed),
            Set.map(path -> current(mapping, path), ControlTopology.outputUnion(world, seed)))
    }

    /// T9 candidate region-pair Jaccard overlap, sorted by region pair.
    pub def overlaps(world: Repository.World, mapping: Mapping): Vector[ControlTopology.Overlap] = {
        let hoods = Vector.map(region0 -> (region0, neighborhood(world, mapping, region0)),
            nonEmptyRegions(world, mapping));
        let pairs0 = Vector.flatMap(match (a, hoodA) -> Vector.filterMap(match (b, hoodB) ->
            if (a < b) Some({left = a, right = b, jaccard = ControlTopology.jaccard(hoodA, hoodB)}) else None,
            hoods), hoods);
        Vector.sortBy(overlap -> (overlap#left, overlap#right), pairs0)
    }

    /// T10 candidate file blast radii. A move changes no set cardinality, so the
    /// values must equal control's byte-for-byte; that equality is a law test.
    pub def fileBlasts(world: Repository.World): Vector[Int32] = ControlTopology.fileBlasts(world)

    /// The largest candidate-region depth-<=2 output cardinality over seed size.
    pub def regionBlast(world: Repository.World, mapping: Mapping, region0: String): Float64 = {
        let seed = regionSeed(world, mapping, region0);
        let seedSize = Set.size(seed);
        if (seedSize == 0) 0.0
        else {
            let evaluation = Experiment.require(Atlas.evaluate(world, Atlas.State.Files(seed), ControlTopology.family()));
            let largest = Vector.foldLeft((best, output) -> {
                let size = Atlas.cardinality(output);
                if (size > best) size else best
            }, 0, evaluation#outputs);
            Int32.toFloat64(largest) / Int32.toFloat64(seedSize)
        }
    }

    pub def maxRegionBlast(world: Repository.World, mapping: Mapping): Float64 =
        Vector.foldLeft((best, region0) -> {
            let value = regionBlast(world, mapping, region0);
            if (value > best) value else best
        }, 0.0, nonEmptyRegions(world, mapping))
}
