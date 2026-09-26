/// The control specimen's static work-topology (PREREGISTRATION.md §6, §4, §5).
///
/// Three channels stay separated, never conflated:
///
///   BASIS  (T1-T8) direct statistics over the admitted relation `world#imports`:
///          the file count, the per-language histogram, the use-edge count, the
///          cross-region ratio, the greedy k=2..10 cuts, the K4 ownership-cell
///          cut, per-region coherence and independence, and hotspot pressure.
///   ATLAS  (T9-T10) unions of depth-<=2 File-domain route outputs of the frozen
///          composition family, evaluated by `Atlas.evaluate` over the
///          re-admitted world: region-pair Jaccard overlap and file blast radii.
///
/// The §4 ten-region conceptual partition and the §5 K4 ownership-cell partition
/// are reported separately and never conflated: a region is a semantic
/// subsystem, a cell is an ownership unit. The residual `other` bucket is
/// always reported, never dropped. Every number is a pure function of the
/// re-admitted control world and the frozen protocols in `ControlMap`.
mod ControlTopology {

    pub def topologyProtocol(): String = "attuneflix-topology-v1"
    pub def regionProtocol(): String = "attuneflix-regions-v1"
    pub def cellProtocol(): String = "attuneflix-cells-v1"
    pub def atlasFamily(): String = "atlas-composition-depth2-file-domain"
    pub def fourCells(): Vector[String] = Vector#{"world", "engine", "applications", "research"}
    pub def languageNames(): Vector[String] =
        Vector#{"flix", "java", "starlark", "javascript", "jsx", "typescript", "tsx"}
    pub def cutDepths(): Vector[Int32] = Vector.range(2, 11)

    // ---- The admitted basis graph (BASIS) ----

    pub def fileIdentity(world: Repository.World, id: Repository.Structure.FileId): String =
        let Repository.Structure.FileId.FileId(index) = id;
        Vector.get(index, world#files)

    def symbolFile(world: Repository.World, id: Repository.Structure.SymbolId): String =
        let Repository.Structure.SymbolId.SymbolId(index) = id;
        Vector.get(index, world#symbols)#path

    pub def edgePaths(world: Repository.World): Vector[(String, String)] =
        Vector.map(match (source, target) -> (fileIdentity(world, source), fileIdentity(world, target)),
            Set.toVector(world#imports))

    pub def regionEdges(world: Repository.World): Vector[(String, String)] =
        Vector.map(match (source, target) -> (ControlMap.regionOf(source), ControlMap.regionOf(target)),
            edgePaths(world))

    pub def cellEdges(world: Repository.World): Vector[(String, String)] =
        Vector.map(match (source, target) -> (ControlMap.cellOf(source), ControlMap.cellOf(target)),
            edgePaths(world))

    // ---- §4 regions ----

    pub def regionFiles(world: Repository.World, region0: String): Vector[String] =
        Vector.filter(path -> ControlMap.regionOf(path) == region0, world#files)

    pub def nonEmptyRegions(world: Repository.World): Vector[String] =
        Vector.filter(region0 -> not Vector.isEmpty(regionFiles(world, region0)), ControlMap.regions())

    pub def internalEdges(edges: Vector[(String, String)], region0: String): Int32 =
        Vector.count(match (f, t) -> f == region0 and t == region0, edges)

    pub def outgoingEdges(edges: Vector[(String, String)], region0: String): Int32 =
        Vector.count(match (f, t) -> f == region0 and t != region0, edges)

    /// T6 `c(R) = internal(R) / (internal(R) + outgoing(R))`.
    pub def coherence(edges: Vector[(String, String)], region0: String): Float64 =
        ScientificTable.ratio(internalEdges(edges, region0),
            internalEdges(edges, region0) + outgoingEdges(edges, region0))

    /// T8: no non-test-side, non-region file uses into the region.
    pub def independentlyTestable(edges: Vector[(String, String)], region0: String): Bool =
        not Vector.exists(match (f, t) ->
            t == region0 and f != region0 and f != "tests" and f != "build-src", edges)

    pub def minCoherence(world: Repository.World, edges: Vector[(String, String)]): (String, Float64) =
        Vector.foldLeft((best, region0) -> {
            let value = coherence(edges, region0);
            if (value < snd(best)) (region0, value) else best
        }, ("", 1.0), nonEmptyRegions(world))

    // ---- T4: greedy agglomerative k-way cuts ----

    pub def interGroups(edges: Vector[(String, String)], a: Set[String], b: Set[String]): Int32 =
        Vector.count(match (f, t) ->
            (Set.memberOf(f, a) and Set.memberOf(t, b)) or (Set.memberOf(f, b) and Set.memberOf(t, a)), edges)

    /// Repeatedly merge the pair `(A, B)` maximizing `w(A,B) + w(B,A)`, ties by
    /// the lexicographically smallest pair of names, the merged group keeping
    /// the smaller name, until `k` groups remain. `other` is never a seed.
    pub def mergeBy(weight: (Set[String], Set[String]) -> Int32, k: Int32,
                    groups: Vector[(String, Set[String])]): Vector[(String, Set[String])] =
        if (Vector.length(groups) <= k) groups
        else {
            let candidates = Vector.flatMap(match (a, aMembers) -> Vector.filterMap(match (b, bMembers) ->
                if (a < b) Some((0 - weight(aMembers, bMembers), a, b, aMembers, bMembers)) else None, groups), groups);
            match Vector.get(0, Vector.sortBy(match (priority, a, b, _, _) -> (priority, a, b), candidates)) {
                case (_, a, b, aMembers, bMembers) => {
                    let merged = (if (a < b) a else b, Set.union(aMembers, bMembers));
                    let rest = Vector.filterMap(match (name, members0) ->
                        if (name == a or name == b) None else Some((name, members0)), groups);
                    mergeBy(weight, k, Vector.sortBy(match (name, _) -> name, Vector.append(rest, Vector#{merged})))
                }
            }
        }

    pub def regionGroups(world: Repository.World, k: Int32): Vector[(String, Set[String])] = {
        let seeds = Vector.map(region0 -> (region0, Set#{region0}), nonEmptyRegions(world));
        mergeBy((a, b) -> interGroups(regionEdges(world), a, b), k,
            Vector.sortBy(match (name, _) -> name, seeds))
    }

    pub def groupOf(groups: Vector[(String, Set[String])], region0: String): Option[String] =
        Vector.foldLeft((found, entry) -> match found {
            case Some(_) => found
            case None => match entry {
                case (name, members0) => if (Set.memberOf(region0, members0)) Some(name) else None
            }
        }, None, groups)

    /// §4 convention: an edge whose source or target is `other`-homed counts as
    /// crossing at every `k` (the residual group is not a merge seed).
    pub def crosses(groups: Vector[(String, Set[String])], fromRegion: String, toRegion: String): Bool =
        if (fromRegion == "other" or toRegion == "other") true
        else match (groupOf(groups, fromRegion), groupOf(groups, toRegion)) {
            case (Some(a), Some(b)) => a != b
            case _ => true
        }

    pub def crossEdges(world: Repository.World, k: Int32): Int32 =
        Vector.count(match (f, t) -> crosses(regionGroups(world, k), f, t), regionEdges(world))

    pub def cutCounts(world: Repository.World): Vector[(Int32, Int32)] =
        Vector.map(k -> (k, crossEdges(world, k)), cutDepths())

    // ---- T5: the K4 ownership-cell cut ----

    pub type alias CellCut = {
        shared        = Int32,
        considered    = Int32,
        fraction      = Float64,
        kernelEdges   = Int32,
        lawEdges      = Int32,
        otherEdges    = Int32
    }

    def fourCell(name: String): Bool =
        Vector.exists(member -> member == name, fourCells())

    /// `cell_cut_4` over an arbitrary list of four member cells; kernel-, law-
    /// and other-homed edges are excluded from numerator and denominator and
    /// reported separately. `cellCut` fixes the control cells so the control and
    /// every candidate share one counting rule.
    pub def cellCutFor(four: Vector[String], cells: Vector[(String, String)]): CellCut = {
        let inFour = name -> Vector.exists(member -> member == name, four);
        let considered = Vector.filter(match (a, b) -> inFour(a) and inFour(b), cells);
        let shared = Vector.count(match (a, b) -> a != b, considered);
        {
            shared = shared,
            considered = Vector.length(considered),
            fraction = ScientificTable.ratio(shared, Vector.length(considered)),
            kernelEdges = Vector.count(match (a, b) -> a == "kernel" or b == "kernel", cells),
            lawEdges = Vector.count(match (a, b) -> a == "law" or b == "law", cells),
            otherEdges = Vector.count(match (a, b) -> a == "other" or b == "other", cells)
        }
    }

    /// `cell_cut_4` over the four control cells (the initial, pre-Round-1 cut).
    pub def cellCut(cells: Vector[(String, String)]): CellCut = {
        let considered = Vector.filter(match (a, b) -> fourCell(a) and fourCell(b), cells);
        let shared = Vector.count(match (a, b) -> a != b, considered);
        {
            shared = shared,
            considered = Vector.length(considered),
            fraction = ScientificTable.ratio(shared, Vector.length(considered)),
            kernelEdges = Vector.count(match (a, b) -> a == "kernel" or b == "kernel", cells),
            lawEdges = Vector.count(match (a, b) -> a == "law" or b == "law", cells),
            otherEdges = Vector.count(match (a, b) -> a == "other" or b == "other", cells)
        }
    }

    // ---- T7: hotspot pressure ----

    pub def pressures(world: Repository.World): Map[Repository.Structure.FileId, Set[String]] =
        Vector.foldLeft((acc, edge) -> match edge {
            case (f, g) => {
                let rf = ControlMap.regionOf(fileIdentity(world, f));
                let rg = ControlMap.regionOf(fileIdentity(world, g));
                if (rf == rg) acc
                else Map.insert(g, Set.insert(rf, Map.getWithDefault(g, Set.empty(), acc)), acc)
            }
        }, Map.empty(), Set.toVector(world#imports))

    /// (path, sorted importing regions, pressure) for every shared hotspot.
    pub def hotspotFiles(world: Repository.World): Vector[(String, Vector[String], Int32)] =
        Vector.map(match (id, regions0) -> (fileIdentity(world, id), Vector.sort(Set.toVector(regions0)),
            Set.size(regions0)), Map.toVector(pressures(world)))
            |> Vector.filter(match (_, _, pressure) -> pressure >= 2)
            |> Vector.sortBy(match (path, _, pressure) -> (0 - pressure, path))

    pub def maxHotspotPressure(world: Repository.World): Int32 =
        Vector.foldLeft((best, entry) -> match entry {
            case (_, _, pressure) => if (pressure > best) pressure else best
        }, 0, hotspotFiles(world))

    // ---- T9/T10: ATLAS depth-<=2 File-domain neighborhoods ----

    pub def family(): Vector[Atlas.Program] = Atlas.programsFrom(Radii.Domain.File, 2)

    def regionSeed(world: Repository.World, region0: String): Set[Repository.Structure.FileId] =
        Vector.mapWithIndex((index, path) -> (path, Repository.Structure.FileId.FileId(index)), world#files)
            |> Vector.filterMap(match (path, id) -> if (ControlMap.regionOf(path) == region0) Some(id) else None)
            |> Vector.toSet

    def stateMembers(world: Repository.World, state: Atlas.State): Set[String] = match state {
        case Atlas.State.Files(ids) => Set.map(id -> fileIdentity(world, id), ids)
        case Atlas.State.Symbols(ids) => Set.map(id -> symbolFile(world, id), ids)
    }

    /// The file-space union of every depth-<=2 File-domain route output: every
    /// step is one real `Atlas.evaluate` transition over the admitted world.
    pub def outputUnion(world: Repository.World, seed: Set[Repository.Structure.FileId]): Set[String] = {
        let evaluation = Experiment.require(Atlas.evaluate(world, Atlas.State.Files(seed), family()));
        Vector.foldLeft((acc, output) -> Set.union(acc, stateMembers(world, output)), Set.empty(), evaluation#outputs)
    }

    /// T9 `N(R)`: the region's files plus its depth-<=2 Atlas output union.
    pub def neighborhood(world: Repository.World, region0: String): Set[String] =
        Set.union(Set.map(id -> fileIdentity(world, id), regionSeed(world, region0)),
            outputUnion(world, regionSeed(world, region0)))

    pub def intersectionOf(left: Set[String], right: Set[String]): Set[String] =
        Set.filter(member -> Set.memberOf(member, right), left)

    pub def jaccard(left: Set[String], right: Set[String]): Float64 =
        ScientificTable.ratio(Set.size(intersectionOf(left, right)), Set.size(Set.union(left, right)))

    pub type alias Overlap = {left = String, right = String, jaccard = Float64}

    pub def overlaps(world: Repository.World): Vector[Overlap] = {
        let hoods = Vector.map(region0 -> (region0, neighborhood(world, region0)), nonEmptyRegions(world));
        let pairs0 = Vector.flatMap(match (a, hoodA) -> Vector.filterMap(match (b, hoodB) ->
            if (a < b) Some({left = a, right = b, jaccard = jaccard(hoodA, hoodB)}) else None, hoods), hoods);
        Vector.sortBy(overlap -> (overlap#left, overlap#right), pairs0)
    }

    /// T10 `b(f)`: the depth-<=2 Atlas output union size from one file seed.
    pub def blast(world: Repository.World, id: Repository.Structure.FileId): Int32 =
        Set.size(outputUnion(world, Set#{id}))

    pub def fileBlasts(world: Repository.World): Vector[Int32] =
        Vector.mapWithIndex((index, _) -> blast(world, Repository.Structure.FileId.FileId(index)), world#files)

    /// Nearest-rank percentile (ascending sort, 0-based `floor(p*n/100)`).
    pub def percentile(values0: Vector[Int32], p: Int32): Int32 =
        if (Vector.isEmpty(values0)) 0
        else {
            let values = Vector.sort(values0);
            let index = p * Vector.length(values) / 100;
            Vector.get(if (index >= Vector.length(values)) Vector.length(values) - 1 else index, values)
        }

    /// The largest depth-<=2 File-domain output cardinality over the seed size.
    pub def regionBlast(world: Repository.World, region0: String): Float64 = {
        let seed = regionSeed(world, region0);
        let seedSize = Set.size(seed);
        if (seedSize == 0) 0.0
        else {
            let evaluation = Experiment.require(Atlas.evaluate(world, Atlas.State.Files(seed), family()));
            let largest = Vector.foldLeft((best, output) -> {
                let size = Atlas.cardinality(output);
                if (size > best) size else best
            }, 0, evaluation#outputs);
            Int32.toFloat64(largest) / Int32.toFloat64(seedSize)
        }
    }

    pub def maxRegionBlast(world: Repository.World): Float64 =
        Vector.foldLeft((best, region0) -> {
            let value = regionBlast(world, region0);
            if (value > best) value else best
        }, 0.0, nonEmptyRegions(world))
}
