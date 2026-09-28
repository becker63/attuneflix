/// The Bazel law commands over the built `atlas-families-v1` tables of every
/// clustered world (`atlas_families_table_test`, `atlas_families_law_test`)
/// and the clustering report projection. The launcher passes each world's
/// identity, frozen world tables, recorded evidence spaces, and both
/// independently built runs as `attune.clustered.<index>.*` properties.
mod FamiliesClusteringLaw {
    import java.lang.Exception
    import java.nio.file.{Files, Paths}
    import java.security.MessageDigest
    import java.util.HexFormat

    type alias World = {
        prefix  = String,
        subject = Families.Pass.Subject,
        roots   = Families.Pass.Roots
    }

    def worlds(): Vector[World] \ IO =
        Vector.map(index -> {
            let prefix = "attune.clustered.${index}";
            {prefix = prefix, subject = FamiliesMain.subjectAt(prefix), roots = FamiliesMain.rootsAt(prefix)}
        }, Vector.range(0, Experiment.count("attune.clustered")))

    /// The built table file of one run (`run` or `rerun`).
    def file(world: World, build: String, name: String): String \ IO = Experiment.property("${world#prefix}.${build}.${name}")

    def read(world: World, build: String): Families.Cluster.Clustering \ IO = {
        let rows = name -> Vector.find(match (known, _, _, _) -> known == name, layoutOf(world))
            |> Option.map(match (_, _, schema, _) -> ScientificTable.read(file(world, build, name), schema))
            |> Option.getWithDefault(Vector.empty());
        Experiment.require(Families.Cluster.Table.decode(world#subject#identity#snapshotId, rows("families"), rows("members"), rows("rollups")))
    }

    /// The three tables' names and schemas (the rows of an empty clustering).
    def layoutOf(world: World): Vector[(String, String, ScientificTable.Schema, Vector[ScientificTable.Row])] =
        Families.Cluster.Table.layout({snapshotId = world#subject#identity#snapshotId, families = Vector.empty(), members = Vector.empty(), rollups = Vector.empty()})

    pub def report(label: String, results: Vector[(String, Result[String, Unit])]): Unit \ IO = {
        Vector.forEach(match (name, result) -> match result {
            case Ok(_) => println("OK   ${label} ${name}")
            case Err(error) => println("FAIL ${label} ${name}: ${error}")
        }, results);
        if (Vector.exists(match (_, result) -> Result.isErr(result), results)) bug!("${label}: a law failed") else ()
    }

    /// Exact round-trip of every built table: read under its declared physical
    /// schema, decoded to typed values and encoded back to the same rows,
    /// rewritten and read back to the same rows, and refused under a foreign
    /// schema.
    pub def tables(): Unit \ IO = {
        let scratch = Files.createTempDirectory("atlas-families").toString();
        Vector.forEach(world -> {
            let snapshotId = world#subject#identity#snapshotId;
            let recorded = read(world, "run");
            let encoded = Families.Cluster.Table.layout(recorded);
            report(world#subject#identity#repository, Vector.flatMap(match (name, fileName, schema, rows) -> {
                let path = file(world, "run", name);
                let stored = ScientificTable.read(path, schema);
                let copy = "${scratch}/${snapshotId |> String.replace(src = ":", dst = "-")}-${fileName}";
                let foreign = if (name == "members") Families.Cluster.Table.rollups() else Families.Cluster.Table.members();
                Vector#{
                    ("${name} typed round-trip", if (stored == rows and not Vector.isEmpty(rows)) Ok(())
                        else Err("decoded ${name} rows do not encode back to the stored rows")),
                    ("${name} parquet round-trip", if (ScientificTable.write(copy, schema, stored) == stored and
                        ScientificTable.read(copy, schema) == stored) Ok(()) else Err("${name} did not round-trip exactly")),
                    ("${name} foreign schema refused", refused(path, foreign))
                }
            }, encoded))
        }, worlds())
    }

    pub def refused(path: String, schema: ScientificTable.Schema): Result[String, Unit] \ IO = try {
        let _ = ScientificTable.read(path, schema);
        Err("${path} was admitted under ${schema#format}")
    } catch {
        case _: Exception => Ok(())
    }

    /// The families laws of every clustered world.
    pub def families(): Unit \ IO = Vector.forEach(world -> {
        let evidence = Experiment.require(Families.Recorded.read(world#subject, world#roots));
        let recomputed = Experiment.require(Families.Cluster.cluster(world#subject#identity#snapshotId, world#subject#world, evidence));
        let subject = {
            world = world#subject#world,
            entities = ScientificTable.read(Experiment.property("${world#prefix}.world_entities"), Repository.Table.entities()),
            evidence = evidence,
            recorded = read(world, "run"),
            rerun = read(world, "rerun"),
            recomputed = recomputed
        };
        let bytes = Vector.map(match (name, _, _, _) ->
            if (digest(file(world, "run", name)) == digest(file(world, "rerun", name))) Ok(())
            else Err("the rerun ${name} bytes differ"), layoutOf(world));
        report(world#subject#identity#repository, Vector.append(
            Vector#{("bit-identical rerun", Vector.traverse(x -> x, bytes) |> Result.map(_ -> ()))},
            Families.Cluster.Law.laws(subject)))
    }, worlds())

    def digest(path: String): String \ IO =
        HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(Files.readAllBytes(Paths.get(path))))

    /// The report view of every clustered world, with its single-source ablations.
    pub def clustered(): Vector[Families.Report.Clustered] \ IO = Vector.map(world -> {
        let value = world#subject;
        let evidence = Experiment.require(Families.Recorded.read(value, world#roots));
        let substrate = Experiment.require(Families.Affinity.substrate(value#world, evidence#vectors));
        let candidates = Experiment.require(Families.Cluster.candidates(value#world, evidence));
        let compared = Families.Cluster.options(substrate, candidates);
        {
            repository = value#identity#repository,
            clustering = read(world, "run"),
            seeds = Vector.length(evidence#outcomes),
            candidates = Vector.length(candidates),
            structuralOnly = Families.Cluster.moved(compared, Families.Method.structuralOnly()),
            semanticOnly = Families.Cluster.moved(compared, Families.Method.semanticOnly())
        }
    }, worlds())
}
