/// The preregistered self-signature instrument (PREREGISTRATION.md): admits
/// the extractor's fact lists as a typed repository world, evaluates the
/// frozen Atlas composition family over region seeds, and writes the
/// artifacts for the preregistered coordination-surface metrics.
mod Parallelism {
    import java.lang.Double
    import java.nio.file.{Files, Paths}
    use ScientificTable.Value

    /// The fixed region partition (attuneflix-regions-v1): first match wins.
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
        Vector#{"repository", "radii", "atlas", "localization", "tables", "population",
            "src-root", "tests", "build-src", "experiments"}

    /// The measured family: the frozen grammar, truncated at depth 2.
    pub def family(): Vector[Atlas.Program] = Atlas.programsFrom(Radii.Domain.File, 2)

    def testSide(region0: String): Bool = region0 == "tests" or region0 == "build-src"

    // Self-admission.

    /// Admit the self-world from the extractor's three fact lists (the sorted
    /// tracked files, one `module<TAB>path` row per declared module, and one
    /// `source<TAB>target` row per use edge).
    pub def selfWorld(files0: Vector[String], modules: Vector[(String, String)],
                      uses: Vector[(String, String)]): Repository.World = {
        let fileIds = Vector.mapWithIndex((index, path) ->
            (path, Repository.Structure.FileId.FileId(index)), files0) |> Vector.toMap;
        {
            files = files0,
            symbols = Vector.map(match (module0, path) ->
                {path = path, name = module0, startByte = 0, endByte = 0}, modules),
            defines = Vector.mapWithIndex((index, entry) -> match entry {
                case (_, path) => (fileIdOf(fileIds, path), Repository.Structure.SymbolId.SymbolId(index))
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

    /// Command `facts`: admit the self-world and write the standard typed
    /// repository-world Parquet triple.
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
            {repository = "attuneflix", baseRevision = revision, sourceTreeIdentity = sourceTreeIdentity,
                factIdentity = factIdentity, snapshotId = snapshotId},
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

    /// Read a committed self-world triple, identity restored from metadata.
    pub def readWorld(metadataPath: String, entitiesPath: String, relationsPath: String): Result[String, (Repository.Table.Identity, Repository.World)] \ IO =
        identityOf(metadataPath) |> Result.flatMap(identity ->
            Repository.Table.read(metadataPath, entitiesPath, relationsPath, identity)
                |> Result.map(world -> (identity, world)))

    /// Run one action over a world read from its committed triple.
    def withWorld(metadataPath: String, entitiesPath: String, relationsPath: String,
                  action: (Repository.Table.Identity, Repository.World) -> Unit \ IO): Unit \ IO =
        match readWorld(metadataPath, entitiesPath, relationsPath) {
            case Err(error) => bug!(error)
            case Ok((identity, world)) => action(identity, world)
        }

    def identityOf(metadataPath: String): Result[String, Repository.Table.Identity] \ IO =
        ScientificTable.exactlyOne("self-world metadata", ScientificTable.read(metadataPath, Repository.Table.metadata()))
            |> Result.flatMap(row -> forM (
                repository <- ScientificTable.text(row, "repository"); baseRevision <- ScientificTable.text(row, "base_revision");
                sourceTreeIdentity <- ScientificTable.text(row, "source_tree_identity"); factIdentity <- ScientificTable.text(row, "fact_identity");
                snapshotId <- ScientificTable.text(row, "snapshot_id")
            ) yield {
                repository = repository, baseRevision = baseRevision, sourceTreeIdentity = sourceTreeIdentity,
                factIdentity = factIdentity, snapshotId = snapshotId
            })

    // Measurement.

    /// The region's file frontier under the fixed partition rule.
    pub def regionSeed(world: Repository.World, region0: String): Set[Repository.Structure.FileId] =
        Vector.mapWithIndex((index, path) -> (path, Repository.Structure.FileId.FileId(index)), world#files)
            |> Vector.filterMap(match (path, id) -> if (regionOf(path) == region0) Some(id) else None)
            |> Vector.toSet

    /// File members of a state; symbol members project to their declaring file.
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

    def intersectionOf(a: Set[String], b: Set[String]): Set[String] =
        Set.filter(member -> Set.memberOf(member, b), a)

    def jaccard(a: Set[String], b: Set[String]): Float64 =
        ScientificTable.ratio(Set.size(intersectionOf(a, b)), Set.size(Set.union(a, b)))

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

    /// E1 coherence: internal edges over all edges leaving the region's files.
    def coherence(edges: Vector[(String, String)], region0: String): Float64 = {
        let internal = Vector.length(Vector.filter(match (f, g) -> f == region0 and g == region0, edges));
        let outgoing = Vector.length(Vector.filter(match (f, g) -> f == region0 and g != region0, edges));
        ScientificTable.ratio(internal, internal + outgoing)
    }

    def groupName(group: (String, Set[String])): String = match group {
        case (name, _) => name
    }

    /// Cross-group use edges between two groups, either direction.
    def interEdges(edges: Vector[(String, String)], a: Set[String], b: Set[String]): Int32 =
        Vector.length(Vector.filter(match (f, t) ->
            (Set.memberOf(f, a) and Set.memberOf(t, b)) or (Set.memberOf(f, b) and Set.memberOf(t, a)), edges))

    /// M10: greedy agglomerative merge of the non-empty regions until k
    /// groups remain (PREREGISTRATION.md): repeatedly merge the pair with
    /// maximal w(A, B) + w(B, A) (ties: the lexicographically smallest pair of
    /// names; the merged group keeps the smaller name).
    def mergeGroups(edges: Vector[(String, String)], k: Int32,
                    groups: Vector[(String, Set[String])]): Vector[(String, Set[String])] =
        if (Vector.length(groups) <= k) groups
        else {
            let weighted = Vector.flatMap(match (a, sa) -> Vector.filterMap(match (b, sb) ->
                if (a < b) Some((0 - interEdges(edges, sa, sb), a, b, sa, sb)) else None, groups), groups);
            match Vector.get(0, Vector.sortBy(match (weight, a, b, _, _) -> (weight, a, b), weighted)) {
                case (_, a, b, sa, sb) => {
                    let merged = (if (a < b) a else b, Set.union(sa, sb));
                    let rest = Vector.filterMap(match (name, members0) ->
                        if (name == a or name == b) None else Some((name, members0)), groups);
                    mergeGroups(edges, k, Vector.sortBy(groupName, Vector.append(rest, Vector#{merged})))
                }
            }
        }

    def groupOf(groups: Vector[(String, Set[String])], region0: String): String =
        Vector.foldLeft((found, entry) -> match entry {
            case (name, members0) => if (Set.memberOf(region0, members0)) name else found
        }, "", groups)

    /// M10 reported quantity: the inter-group use-edge count at k workers.
    pub def crossEdges(world: Repository.World, k: Int32): Int32 = {
        let edges = edgeRegions(world);
        let start = Vector.sortBy(groupName, Vector.filterMap(region0 ->
            if (Set.isEmpty(regionSeed(world, region0))) None
            else Some((region0, Set#{region0})), regions()));
        let groups = mergeGroups(edges, k, start);
        Vector.length(Vector.filter(match (f, t) ->
            groupOf(groups, f) != groupOf(groups, t), edges))
    }

    def nonEmptyRegions(world: Repository.World): Vector[String] =
        Vector.filter(region0 -> not Set.isEmpty(regionSeed(world, region0)), regions())

    /// The preregistered coordination-surface quantities, (name, value) pairs
    /// in fixed order. Definitions: PREREGISTRATION.md M1-M10 (M2, the raw
    /// LOC, is counted outside the instrument).
    pub def quantities(world: Repository.World): Vector[(String, Float64)] = {
        let edges = edgeRegions(world);
        let nonEmpty = nonEmptyRegions(world);
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
            ("cross_region_edge_ratio", ScientificTable.ratio(
                Vector.length(Vector.filter(match (f, g) -> f != g, edges)), Vector.length(edges))),
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

    // Commands.

    /// The executable surface: facts, region, compare (which also writes each
    /// revision's region-pairs table).
    pub def execute(): Unit \ IO = match Experiment.property("attune.command") {
        case "facts" => writeFacts()
        case "region" => writeRegion()
        case "compare" => writeCompare()
        case command => bug!("unknown parallelism command: ${command}")
    }

    /// The union-member row schema: one row per region shard carrying the
    /// depth-<=2 neighborhood membership plus the region's coherence and
    /// independence (the per-region quantities the oracle asserts).
    pub def membersSchema(): ScientificTable.Schema = {
        format = "attuneflix-parallelism-members-v1",
        columns = Vector#{
            ScientificTable.Columns.text("revision"), ScientificTable.Columns.text("region"),
            ScientificTable.Columns.int32("seed_size"), ScientificTable.Columns.int32("result_size"),
            ScientificTable.Columns.float64("coherence"),
            ScientificTable.Columns.boolean("independently_testable"),
            ScientificTable.Columns.textList("members")
        }
    }

    /// The region-pairs schema (PREREGISTRATION.md artifact schemas).
    pub def pairsSchema(): ScientificTable.Schema = {
        format = "attuneflix-parallelism-pairs-v1",
        columns = Vector#{
            ScientificTable.Columns.text("revision"), ScientificTable.Columns.text("region_a"),
            ScientificTable.Columns.text("region_b"), ScientificTable.Columns.int32("union_size"),
            ScientificTable.Columns.int32("intersection_size"), ScientificTable.Columns.float64("jaccard")
        }
    }

    /// Command `region`: one per-region shard. Computes the canonical Atlas
    /// signature of the region seed under the depth-2 family and writes the
    /// observation/physical rows plus the region's union-member row.
    def writeRegion(): Unit \ IO =
        withWorld(Experiment.property("attune.world_metadata"), Experiment.property("attune.world_entities"),
            Experiment.property("attune.world_relations"), (identity, world) -> {
            let region0 = Experiment.property("attune.region");
            let seed = regionSeed(world, region0);
            let seedState = Atlas.State.Files(seed);
            let seed0: Atlas.Signature.Seed = {domain = Radii.Domain.File,
                identity = region0, ordinal = 0, state = seedState};
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
                    let edges = edgeRegions(world);
                    let union = neighborhood(world, region0);
                    let _ = ScientificTable.write(Experiment.property("attune.output_members"),
                        membersSchema(), Vector#{Map#{
                            "revision" => Value.Text(identity#baseRevision), "region" => Value.Text(region0),
                            "seed_size" => Value.Int32(Set.size(seed)), "result_size" => Value.Int32(Set.size(union)),
                            "coherence" => Value.Float64(coherence(edges, region0)),
                            "independently_testable" => Value.Boolean(independentlyTestable(edges, region0)),
                            "members" => Value.TextList(Vector.sort(Set.toVector(union)))
                        }});
                    println("ATLAS_PARALLELISM_REGION revision=${identity#baseRevision} region=${region0} " +
                        "seed=${Set.size(seed)} neighborhood=${Set.size(union)}")
                }
            }
        })

    def pairsRows(identity: Repository.Table.Identity, world: Repository.World): Vector[ScientificTable.Row] = {
        let hoods = Vector.map(region0 -> (region0, neighborhood(world, region0)), nonEmptyRegions(world));
        Vector.flatMap(match (a, ha) ->
            Vector.filterMap(match (b, hb) -> if (a < b) Some((a, b, ha, hb)) else None, hoods), hoods)
            |> Vector.map(match (a, b, ha, hb) -> Map#{
                "revision" => Value.Text(identity#baseRevision),
                "region_a" => Value.Text(a), "region_b" => Value.Text(b),
                "union_size" => Value.Int32(Set.size(Set.union(ha, hb))),
                "intersection_size" => Value.Int32(Set.size(intersectionOf(ha, hb))),
                "jaccard" => Value.Float64(jaccard(ha, hb))
            })
    }

    /// Command `compare`: the before/after coordination-surface table over two
    /// committed self-world triples, plus each revision's region-pairs table.
    def writeCompare(): Unit \ IO = {
        let (baselineIdentity, baseline) = Experiment.require(readWorld(
            Experiment.property("attune.baseline_metadata"),
            Experiment.property("attune.baseline_entities"),
            Experiment.property("attune.baseline_relations")));
        let (afterIdentity, after) = Experiment.require(readWorld(
            Experiment.property("attune.after_metadata"),
            Experiment.property("attune.after_entities"),
            Experiment.property("attune.after_relations")));
        let _ = ScientificTable.write(Experiment.property("attune.baseline_pairs"),
            pairsSchema(), pairsRows(baselineIdentity, baseline));
        let _ = ScientificTable.write(Experiment.property("attune.after_pairs"),
            pairsSchema(), pairsRows(afterIdentity, after));
        // Diagnostic (not a preregistered metric): which pair attains M7's max.
        let hoods = Vector.map(region0 -> (region0, neighborhood(after, region0)), nonEmptyRegions(after));
        let best = Vector.foldLeft((m, pair) -> match pair {
            case (_, _, j) => if (j > m) j else m
        }, 0.0, Vector.flatMap(match (a, ha) ->
            Vector.filterMap(match (b, hb) -> if (a < b) Some((a, b, jaccard(ha, hb))) else None, hoods), hoods));
        let argmaxText = Vector.foldLeft((acc, pair) -> match pair {
            case (a, b, j) => if (j == best) "${acc}${a}+${b} " else acc
        }, "", Vector.flatMap(match (a, ha) ->
            Vector.filterMap(match (b, hb) -> if (a < b) Some((a, b, jaccard(ha, hb))) else None, hoods), hoods));
        println("argmax_pair ${argmaxText}");
        println("metric ${baselineIdentity#baseRevision} ${afterIdentity#baseRevision}");
        Vector.foldLeft((_, pair) -> match pair {
            case ((name, before), (_, value)) => println("${name} ${before} ${value}")
        }, (), Vector.zip(quantities(baseline), quantities(after)))
    }

    /// Command `oracle`: the standing parallel-work-friendliness law
    /// (PREREGISTRATION.md enshrinement). Asserts the preregistered
    /// coordination-surface thresholds — per-region values from the shard
    /// outputs, world-level values from the in-graph world — with the
    /// documented bounds; a violation fails the action and turns red.
    pub def writeOracle(): Unit \ IO = {
        let (_, world) = Experiment.require(readWorld(
            Experiment.property("attune.world_metadata"),
            Experiment.property("attune.world_entities"),
            Experiment.property("attune.world_relations")));
        let shards = Vector.map(shardRow, Experiment.paths("attune.members"));
        let q = Vector.toMap(quantities(world));
        let coherences = Vector.map(match (_, c, _, _) -> c, shards);
        let jaccards = Vector.flatMap(match (a, _, _, ma) ->
            Vector.filterMap(match (b, _, _, mb) -> if (a < b) Some(jaccard(ma, mb)) else None, shards), shards);
        let independent = Vector.filterMap(match (_, _, t, _) -> if (t) Some(()) else None, shards);
        let value = name -> match Map.get(name, q) { case Some(v) => v case None => 0.0 };
        let measured = Vector#{
            ("min_region_coherence", Vector.foldLeft((best, c) -> if (c < best) c else best, 1.0, coherences), 1),
            ("max_pair_jaccard", Vector.foldLeft((best, j) -> if (j > best) j else best, 0.0, jaccards), -1),
            ("shared_hotspots", value("shared_hotspots"), -1),
            ("max_hotspot_pressure", value("max_hotspot_pressure"), -1),
            ("independently_testable", Int32.toFloat64(Vector.length(independent)), 1),
            ("median_file_blast", value("median_file_blast"), -1)
        };
        let failures = Vector.filterMap(match (name, measured0, direction) -> {
            let bound = Double.parseDouble(Experiment.property("attune.threshold.${name}"));
            let ok = if (direction == 1) measured0 >= bound else measured0 <= bound;
            println("PARALLELISM_ORACLE ${name} measured=${measured0} bound=${bound} ${if (ok) "pass" else "FAIL"}");
            if (ok) None else Some(name)
        }, measured);
        if (Vector.isEmpty(failures)) ()
        else bug!("parallel-work-friendliness oracle violated: ${Vector.toString(failures)}")
    }

    /// One shard's members row: (region, coherence, independently testable,
    /// neighborhood members).
    def shardRow(path: String): (String, Float64, Bool, Set[String]) \ IO =
        ScientificTable.exactlyOne("parallelism members", ScientificTable.read(path, membersSchema()))
            |> Result.flatMap(row -> forM (
                region0 <- ScientificTable.text(row, "region"); c <- ScientificTable.number(row, "coherence");
                t <- ScientificTable.boolean(row, "independently_testable"); members0 <- textListOf(row, "members")
            ) yield (region0, c, t, Vector.toSet(members0))) |> Experiment.require

    def textListOf(row: ScientificTable.Row, name: String): Result[String, Vector[String]] =
        match Map.get(name, row) {
            case Some(Value.TextList(values)) => Ok(values)
            case _ => Err("missing ${name} text list")
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
