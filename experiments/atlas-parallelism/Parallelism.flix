/// The preregistered self-signature instrument (PREREGISTRATION.md).
///
/// AttuneFlix admits its own tracked Flix sources as a repository world
/// (attuneflix-self-admission-v1): the deterministic extractor names the
/// tracked files, their declared modules, and the dotted-token use edges; this
/// module gives those facts the standard typed world meaning, evaluates the
/// frozen Atlas composition family over region seeds, and writes canonical
/// Atlas signature artifacts plus the union-member rows the overlap metrics
/// need. Every command is deterministic over its declared inputs.
mod Parallelism {
    import java.nio.file.{Files, Paths}
    use ScientificTable.Value

    /// The fixed region partition (attuneflix-regions-v1): a pure function of
    /// the file path, applied identically to every revision.
    pub def regionOf(path: String): String =
        if (path == "src/Repository.flix" or String.startsWith(prefix = "src/Repository/", path)) "repository"
        else if (path == "src/Radii.flix" or String.startsWith(prefix = "src/Radii/", path)) "radii"
        else if (path == "src/Atlas.flix" or String.startsWith(prefix = "src/Atlas/", path)) "atlas"
        else if (path == "src/Localization.flix" or String.startsWith(prefix = "src/Localization/", path)) "localization"
        else if (path == "src/ScientificTable.flix" or String.startsWith(prefix = "src/ScientificTable/", path)) "tables"
        else if (path == "src/Population.flix" or String.startsWith(prefix = "src/Population/", path)) "population"
        else if (String.startsWith(prefix = "src/", path)) "src-root"
        else if (String.startsWith(prefix = "test/", path)) "tests"
        else if (String.startsWith(prefix = "build/src/", path)) "build-src"
        else if (String.startsWith(prefix = "experiments/", path)) "experiments"
        else "other"

    /// The preregistered region names, in fixed order.
    pub def regions(): Vector[String] =
        Vector#{"repository", "radii", "atlas", "localization", "tables",
            "population", "src-root", "tests", "build-src", "experiments"}

    /// The measured family: every well-typed composition-only Atlas program
    /// of length <= 2 over the File domain (the frozen grammar, truncated).
    pub def family(): Vector[Atlas.Program] = Atlas.programsFrom(Radii.Domain.File, 2)

    def testSide(region0: String): Bool = region0 == "tests" or region0 == "build-src"

    // ------------------------------------------------------------------
    // Self-admission: extracted fact lists -> standard typed world
    // ------------------------------------------------------------------

    /// Admit the self-world from the extractor's three fact lists: the sorted
    /// tracked files, one `module<TAB>path` row per declared module, and one
    /// `source<TAB>target` row per use edge.
    pub def selfWorld(files0: Vector[String], modules: Vector[(String, String)],
                      uses: Vector[(String, String)]): Repository.World = {
        let fileIds = Vector.mapWithIndex((index, path) ->
            (path, Repository.Structure.FileId.FileId(index)), files0) |> Vector.toMap;
        {
            files = files0,
            symbols = Vector.map(match (module0, path) ->
                {path = path, name = module0, startByte = 0, endByte = 0}, modules),
            defines = Vector.mapWithIndex((index, entry) -> match entry {
                case (_, path) =>
                    (fileIdOf(fileIds, path), Repository.Structure.SymbolId.SymbolId(index))
            }, modules) |> Vector.toSet,
            imports = Vector.map(match (source, target) ->
                (fileIdOf(fileIds, source), fileIdOf(fileIds, target)), uses) |> Vector.toSet,
            calls = Set.empty(),
            parents = Set.empty(),
            unresolvedImports = 0,
            unresolvedCalls = 0
        }
    }

    def fileIdOf(fileIds: Map[String, Repository.Structure.FileId], path: String): Repository.Structure.FileId =
        match Map.get(path, fileIds) {
            case Some(id) => id
            case None => bug!("extractor named an unknown file: ${path}")
        }

    /// Command `facts`: read the extractor's fact lists, admit the self-world,
    /// and write the standard typed repository-world Parquet triple.
    def writeFacts(): Unit \ IO = {
        let revision = Experiment.property("attune.revision");
        let files = factLines(Experiment.property("attune.files"));
        let modules = Vector.map(split2, factLines(Experiment.property("attune.modules")));
        let uses = Vector.map(split2, factLines(Experiment.property("attune.uses")));
        let world = selfWorld(files, modules, uses);
        let sourceTreeIdentity = "attuneflix-source-tree-v1:" + revision;
        let factIdentity = Repository.Table.factIdentity(sourceTreeIdentity, "attuneflix-self-admission-v1", world);
        let snapshotId = Repository.Table.snapshotIdentity("attuneflix", revision, sourceTreeIdentity, factIdentity);
        let _ = Repository.Table.write(
            Experiment.property("attune.world_metadata"),
            Experiment.property("attune.world_entities"),
            Experiment.property("attune.world_relations"),
            {repository = "attuneflix", baseRevision = revision,
                sourceTreeIdentity = sourceTreeIdentity, factIdentity = factIdentity, snapshotId = snapshotId},
            world);
        println("ATLAS_PARALLELISM_FACTS revision=${revision} files=${Vector.length(world#files)} " +
            "symbols=${Vector.length(world#symbols)} imports=${Set.size(world#imports)}")
    }

    def factLines(path: String): Vector[String] \ IO =
        String.lines(Files.readString(Paths.get(path))) |> List.toVector

    def split2(line: String): (String, String) = match String.splitOn(substr = "\t", line) {
        case left :: right :: _ => (left, right)
        case _ => bug!("fact line needs two tab-separated fields: ${line}")
    }

    /// Read a committed self-world triple, restoring its identity from the
    /// metadata row.
    pub def readWorld(metadataPath: String, entitiesPath: String, relationsPath: String): Result[String, (Repository.Table.Identity, Repository.World)] \ IO =
        identityOf(metadataPath) |> Result.flatMap(identity ->
            Repository.Table.read(metadataPath, entitiesPath, relationsPath, identity)
                |> Result.map(world -> (identity, world)))

    def identityOf(metadataPath: String): Result[String, Repository.Table.Identity] \ IO =
        ScientificTable.exactlyOne("self-world metadata", ScientificTable.read(metadataPath, Repository.Table.metadata()))
            |> Result.flatMap(row -> forM (
                repository <- ScientificTable.text(row, "repository");
                baseRevision <- ScientificTable.text(row, "base_revision");
                sourceTreeIdentity <- ScientificTable.text(row, "source_tree_identity");
                factIdentity <- ScientificTable.text(row, "fact_identity");
                snapshotId <- ScientificTable.text(row, "snapshot_id")
            ) yield {
                repository = repository,
                baseRevision = baseRevision,
                sourceTreeIdentity = sourceTreeIdentity,
                factIdentity = factIdentity,
                snapshotId = snapshotId
            })

    // ------------------------------------------------------------------
    // Measurement: regions, family evaluation, preregistered quantities
    // ------------------------------------------------------------------

    /// The region's file frontier under the fixed partition rule.
    pub def regionSeed(world: Repository.World, region0: String): Set[Repository.Structure.FileId] =
        Vector.mapWithIndex((index, path) -> (path, Repository.Structure.FileId.FileId(index)), world#files)
            |> Vector.filterMap(match (path, id) -> if (regionOf(path) == region0) Some(id) else None)
            |> Vector.toSet

    /// File members of a state; symbol members project to their declaring file
    /// through the one-to-one defines admission.
    def members(state: Atlas.State, world: Repository.World): Set[String] = match state {
        case Atlas.State.Files(ids) => Set.map(fileIdentity(world), ids)
        case Atlas.State.Symbols(ids) => Set.map(symbolFile(world), ids)
    }

    def fileIdentity(world: Repository.World, id: Repository.Structure.FileId): String =
        let Repository.Structure.FileId.FileId(index) = id;
        Vector.get(index, world#files)

    def symbolFile(world: Repository.World, id: Repository.Structure.SymbolId): String =
        let Repository.Structure.SymbolId.SymbolId(index) = id;
        Vector.get(index, world#symbols)#path

    def regionAt(world: Repository.World, id: Repository.Structure.FileId): String =
        regionOf(fileIdentity(world, id))

    /// The file-space union of every family output from one File seed.
    def outputUnion(world: Repository.World, seed: Set[Repository.Structure.FileId]): Set[String] = {
        let evaluation = Experiment.require(Atlas.evaluate(world, Atlas.State.Files(seed), family()));
        Vector.foldLeft((acc, output) -> Set.union(acc, members(output, world)), Set.empty(), evaluation#outputs)
    }

    /// M5 file blast radius: the output union size from one single-file seed.
    def blast(world: Repository.World, index: Int32): Int32 =
        Set.size(outputUnion(world, Set#{Repository.Structure.FileId.FileId(index)}))

    /// M7 neighborhood: the depth-<=2 member union including the seed files.
    def neighborhood(world: Repository.World, region0: String): Set[String] = {
        let seed = regionSeed(world, region0);
        Set.union(Set.map(fileIdentity(world), seed), outputUnion(world, seed))
    }

    def jaccard(a: Set[String], b: Set[String]): Float64 = {
        let intersection = Int32.toFloat64(Set.size(Set.filter(member -> Set.memberOf(member, b), a)));
        let union = Int32.toFloat64(Set.size(Set.union(a, b)));
        if (union == 0.0) 0.0 else intersection / union
    }

    /// Nearest-rank percentile over an Int32 sample (PREREGISTRATION.md M5).
    def percentile(values0: Vector[Int32], p: Int32): Int32 = {
        let values = Vector.sort(values0);
        let index = p * Vector.length(values) / 100;
        Vector.get(if (index >= Vector.length(values)) Vector.length(values) - 1 else index, values)
    }

    /// The region-edge list: one (source-region, target-region) per use edge.
    def edgeRegions(world: Repository.World): Vector[(String, String)] =
        Vector.map(match (source, target) -> (regionAt(world, source), regionAt(world, target)),
            Set.toVector(world#imports))

    /// M9: no non-test-side file outside the region uses into it.
    def independentlyTestable(edges: Vector[(String, String)], region0: String): Bool =
        not Vector.exists(match (source, target) ->
            target == region0 and source != region0 and not testSide(source), edges)

    /// E1 coherence: internal edges over all edges leaving the region's files;
    /// an isolated region is fully coherent.
    def coherence(edges: Vector[(String, String)], region0: String): Float64 = {
        let internal = Vector.length(Vector.filter(match (f, g) -> f == region0 and g == region0, edges));
        let outgoing = Vector.length(Vector.filter(match (f, g) -> f == region0 and g != region0, edges));
        if (internal + outgoing == 0) 1.0
        else Int32.toFloat64(internal) / Int32.toFloat64(internal + outgoing)
    }

    /// M10: order the non-empty regions by descending cross-region edge
    /// involvement (ties: ascending name); assign each region in that order to
    /// the worker sharing the fewest use edges with already-assigned regions
    /// (ties: lowest worker index); report the inter-worker edge count.
    pub def crossEdges(world: Repository.World, k: Int32): Int32 = {
        let edges = edgeRegions(world);
        let involvement = Vector.map(region0 -> (region0,
            Vector.length(Vector.filter(match (f, g) ->
                (f == region0 and g != region0) or (g == region0 and f != region0), edges))), regions());
        let order = Vector.sortBy(match (region0, weight) -> (0 - weight, region0),
            Vector.filterMap(match (region0, weight) ->
                if (Set.isEmpty(regionSeed(world, region0))) None else Some((region0, weight)), involvement));
        let final = Vector.foldLeft((workers, entry) -> match entry {
            case (region0, _) => assign(workers, region0, edges)
        }, Vector.map(_ -> Set.empty(), Vector.range(0, k)), order);
        Vector.foldLeft((sum, edge) -> match edge {
            case (f, g) => if (workerOf(final, f) == workerOf(final, g)) sum else sum + 1
        }, 0, edges)
    }

    def assign(workers: Vector[Set[String]], region0: String, edges: Vector[(String, String)]): Vector[Set[String]] = {
        let loads = Vector.map(group ->
            Vector.foldLeft((sum, edge) -> match edge {
                case (f, g) =>
                    if ((f == region0 and Set.memberOf(g, group)) or (g == region0 and Set.memberOf(f, group))) sum + 1 else sum
            }, 0, edges), workers);
        let best = Vector.foldLeft((bestIndex, entry) -> match entry {
            case (index, load) => if (load < Vector.get(bestIndex, loads)) index else bestIndex
        }, 0, Vector.mapWithIndex((index, load) -> (index, load), loads));
        Vector.mapWithIndex((index, group) ->
            if (index == best) Set.insert(region0, group) else group, workers)
    }

    def workerOf(workers: Vector[Set[String]], region0: String): Int32 =
        Vector.foldLeft((found, entry) -> match entry {
            case (index, group) => if (Set.memberOf(region0, group)) index else found
        }, 0, Vector.mapWithIndex((index, group) -> (index, group), workers))

    /// The preregistered coordination-surface quantities, (name, value) pairs
    /// in fixed order. Definitions: PREREGISTRATION.md M1-M10 (M2, the raw
    /// LOC, is counted outside the instrument).
    pub def quantities(world: Repository.World): Vector[(String, Float64)] = {
        let edges = edgeRegions(world);
        let nonEmpty = Vector.filter(region0 -> not Set.isEmpty(regionSeed(world, region0)), regions());
        let hoods = Vector.map(region0 -> (region0, neighborhood(world, region0)), nonEmpty);
        let pairs0 = Vector.flatMap(match (a, ha) ->
            Vector.filterMap(match (b, hb) -> if (a < b) Some((ha, hb)) else None, hoods), hoods);
        let jaccards = Vector.map(match (ha, hb) -> jaccard(ha, hb), pairs0);
        let blasts = Vector.mapWithIndex((index, _) -> blast(world, index), world#files);
        let pressures = Vector.foldLeft((acc, edge) -> match edge {
            case (f, g) => {
                let rf = regionAt(world, f);
                let rg = regionAt(world, g);
                if (rf == rg) acc
                else Map.insert(g, Set.insert(rf, Map.getWithDefault(g, Set.empty(), acc)), acc)
            }
        }, Map.empty(), Set.toVector(world#imports));
        let pressureSizes = Vector.map(match (_, fs) -> Set.size(fs), Map.toVector(pressures));
        Vector#{
            ("tracked_files", Int32.toFloat64(Vector.length(world#files))),
            ("use_edges", Int32.toFloat64(Vector.length(edges))),
            ("cross_region_edge_ratio", ratioOf(Vector.length(Vector.filter(match (f, g) -> f != g, edges)), Vector.length(edges))),
            ("median_file_blast", Int32.toFloat64(percentile(blasts, 50))),
            ("p90_file_blast", Int32.toFloat64(percentile(blasts, 90))),
            ("max_region_blast", Vector.foldLeft((best, region0) -> {
                let value = regionBlast(world, region0);
                if (value > best) value else best
            }, 0.0, nonEmpty)),
            ("max_pair_jaccard", Vector.foldLeft((best, value) -> if (value > best) value else best, 0.0, jaccards)),
            ("high_overlap_pairs", Int32.toFloat64(Vector.length(Vector.filter(value -> value >= 0.5, jaccards)))),
            ("shared_hotspots", Int32.toFloat64(Vector.length(Vector.filter(size -> size >= 2, pressureSizes)))),
            ("max_hotspot_pressure", Int32.toFloat64(Vector.foldLeft((best, size) -> if (size > best) size else best, 0, pressureSizes))),
            ("independently_testable", Int32.toFloat64(Vector.length(Vector.filter(region0 -> independentlyTestable(edges, region0), nonEmpty)))),
            ("min_region_coherence", Vector.foldLeft((best, region0) -> {
                let value = coherence(edges, region0);
                if (value < best) value else best
            }, 1.0, nonEmpty)),
            ("cross_group_edges_4", Int32.toFloat64(crossEdges(world, 4))),
            ("cross_group_edges_8", Int32.toFloat64(crossEdges(world, 8)))
        }
    }

    /// M6: the largest family output from the region seed, over the seed size.
    def regionBlast(world: Repository.World, region0: String): Float64 = {
        let seedSize = Set.size(regionSeed(world, region0));
        let evaluation = Experiment.require(Atlas.evaluate(world, Atlas.State.Files(regionSeed(world, region0)), family()));
        Int32.toFloat64(Vector.foldLeft((best, output) -> {
            let size = Atlas.cardinality(output);
            if (size > best) size else best
        }, 0, evaluation#outputs)) / Int32.toFloat64(seedSize)
    }

    def ratioOf(numerator: Int32, denominator: Int32): Float64 =
        if (denominator == 0) 0.0
        else Int32.toFloat64(numerator) / Int32.toFloat64(denominator)

    // ------------------------------------------------------------------
    // Commands
    // ------------------------------------------------------------------

    /// The executable surface: facts, region, compare.
    pub def execute(): Unit \ IO = match Experiment.property("attune.command") {
        case "facts" => writeFacts()
        case "region" => writeRegion()
        case "compare" => writeCompare()
        case command => bug!("unknown parallelism command: ${command}")
    }

    /// The union-member row schema: one row per region shard carrying the
    /// depth-<=2 neighborhood membership the overlap metrics consume.
    pub def membersSchema(): ScientificTable.Schema = {
        format = "attuneflix-parallelism-members-v1",
        columns = Vector#{
            ScientificTable.Columns.text("revision"),
            ScientificTable.Columns.text("region"),
            ScientificTable.Columns.int32("seed_size"),
            ScientificTable.Columns.int32("result_size"),
            ScientificTable.Columns.textList("members")
        }
    }

    /// Command `region`: one per-region shard. Computes the canonical Atlas
    /// signature of the region seed under the depth-2 family and writes the
    /// observation/physical rows plus the region's union-member row.
    def writeRegion(): Unit \ IO =
        match readWorld(Experiment.property("attune.world_metadata"),
            Experiment.property("attune.world_entities"),
            Experiment.property("attune.world_relations")) {
            case Err(error) => bug!(error)
            case Ok((identity, world)) => {
                let region0 = Experiment.property("attune.region");
                let seed = regionSeed(world, region0);
                let seedState = Atlas.State.Files(seed);
                let seed0: Atlas.Signature.Seed = {
                    domain = Radii.Domain.File, identity = region0, ordinal = 0, state = seedState
                };
                match Atlas.Signature.compute(world, seedState, 2) {
                    case Err(error) => bug!(error)
                    case Ok(signature) => {
                        let snapshot = snapshotOf(identity);
                        let _ = ScientificTable.write(Experiment.property("attune.output_observations"),
                            Atlas.Signature.Table.observations(),
                            Atlas.Signature.Table.observationRows(snapshot, seed0, signature));
                        let _ = ScientificTable.write(Experiment.property("attune.output_physical"),
                            Atlas.Signature.Table.physical(),
                            Vector#{Atlas.Signature.Table.physicalRow(snapshot, seed0, signature)});
                        let union = neighborhood(world, region0);
                        let _ = ScientificTable.write(Experiment.property("attune.output_members"),
                            membersSchema(), Vector#{Map#{
                                "revision" => Value.Text(identity#baseRevision),
                                "region" => Value.Text(region0),
                                "seed_size" => Value.Int32(Set.size(seed)),
                                "result_size" => Value.Int32(Set.size(union)),
                                "members" => Value.TextList(Vector.sort(Set.toVector(union)))
                            }});
                        println("ATLAS_PARALLELISM_REGION revision=${identity#baseRevision} region=${region0} " +
                            "seed=${Set.size(seed)} neighborhood=${Set.size(union)}")
                    }
                }
            }
        }

    /// Command `compare`: the before/after coordination-surface table over two
    /// committed self-world triples (same instrument, same definitions).
    def writeCompare(): Unit \ IO = {
        let (baselineIdentity, baseline) = Experiment.require(readWorld(
            Experiment.property("attune.baseline_metadata"),
            Experiment.property("attune.baseline_entities"),
            Experiment.property("attune.baseline_relations")));
        let (afterIdentity, after) = Experiment.require(readWorld(
            Experiment.property("attune.after_metadata"),
            Experiment.property("attune.after_entities"),
            Experiment.property("attune.after_relations")));
        println("metric ${baselineIdentity#baseRevision} ${afterIdentity#baseRevision}");
        Vector.foldLeft((_, pair) -> match pair {
            case ((name, before), (_, value)) =>
                println("${name} ${before} ${value}")
        }, (), Vector.zip(quantities(baseline), quantities(after)))
    }

    def snapshotOf(identity: Repository.Table.Identity): Atlas.Signature.Table.SnapshotIdentity = {
        signatureProtocol = "attuneflix-parallelism-v1",
        atlasProtocol = "atlas-composition-depth2-v1",
        repository = identity#repository,
        baseRevision = identity#baseRevision,
        sourceTreeIdentity = identity#sourceTreeIdentity,
        factIdentity = identity#factIdentity,
        snapshotId = identity#snapshotId
    }
}
