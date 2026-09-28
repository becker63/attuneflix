/// The family-edge and export commands of the families tool: the edge
/// aggregation and export actions, the family-edge table and edge laws, the
/// cross-layer export parity law, and the export report projection. Every
/// launcher passes one world's identity and frozen world tables under a
/// property prefix, with its clustering tables under `<prefix>.cluster.*`,
/// its edge tables under `<prefix>.edges.*`, and (for exported worlds) its
/// export directory and snapshot digest.
mod FamiliesEdgeLaw {
    import java.nio.file.{Files, Paths}

    type alias Exported = {
        prefix  = String,
        subject = Families.Pass.Subject
    }

    /// The table name -> built file of every table of `layout` under `<prefix>.<stage>.<table>`.
    def files(prefix: String, stage: String, layout: Vector[(String, String, ScientificTable.Schema, Vector[ScientificTable.Row])]): Map[String, String] \ IO =
        Vector.map(match (table, _, _, _) -> (table, Experiment.property("${prefix}.${stage}.${table}")), layout) |> Vector.toMap

    def clusteringAt(prefix: String, snapshotId: String): Families.Cluster.Clustering \ IO =
        Experiment.require(Families.Cluster.Table.read(snapshotId, files(prefix, "cluster", Families.Cluster.Table.schemas(snapshotId))))

    def aggregationAt(prefix: String, snapshotId: String): Families.Edge.Aggregation \ IO =
        Experiment.require(Families.Edge.Table.read(snapshotId, files(prefix, "edges", Families.Edge.Table.schemas(snapshotId))))

    /// The built science file of every exported table.
    def science(prefix: String, snapshotId: String): Map[String, String] \ IO =
        Map.union(files(prefix, "cluster", Families.Cluster.Table.schemas(snapshotId)),
            files(prefix, "edges", Families.Edge.Table.schemas(snapshotId)))

    /// The family-edge aggregation of one world under its built clustering.
    pub def edges(): Unit \ IO = {
        let value = FamiliesMain.subjectAt("attune");
        let snapshotId = value#identity#snapshotId;
        let aggregation = Families.Edge.aggregate(value#world, clusteringAt("attune", snapshotId));
        let output = Experiment.property("attune.output_edges");
        Vector.forEach(match (name, file, schema, rows) ->
            if (ScientificTable.write("${output}/${file}", schema, rows) == rows) ()
            else bug!("${name} did not round-trip exactly"),
            Families.Edge.Table.layout(aggregation));
        println("ATLAS_FAMILY_EDGES snapshot=${snapshotId} edges=${Vector.length(aggregation#edges)} " +
            "contributions=${Vector.length(aggregation#contributions)}")
    }

    /// The web export of one world. It refuses edge tables that are not the
    /// aggregation of the world under the clustering beside them.
    pub def export(): Unit \ IO = {
        let value = FamiliesMain.subjectAt("attune");
        let snapshotId = value#identity#snapshotId;
        let clustering = clusteringAt("attune", snapshotId);
        let aggregation = aggregationAt("attune", snapshotId);
        let rows = x -> Vector.map(match (_, _, _, r) -> r, Families.Edge.Table.layout(x));
        if (rows(Families.Edge.aggregate(value#world, clustering)) != rows(aggregation))
            bug!("the edge tables of ${snapshotId} are not the aggregation of its clustering")
        else {
            let written = Experiment.require(Families.Export.write(Experiment.property("attune.output_export"), clustering, aggregation));
            println("ATLAS_FAMILIES_EXPORT snapshot=${snapshotId} " +
                Vector.join(" ", Vector.map(match (file, count) -> "${file}=${count}", written)))
        }
    }

    def exported(): Vector[Exported] \ IO =
        Vector.map(index -> {
            let prefix = "attune.exported.${index}";
            {prefix = prefix, subject = FamiliesMain.subjectAt(prefix)}
        }, Vector.range(0, Experiment.count("attune.exported")))

    def snapshotOf(world: Exported): String = world#subject#identity#snapshotId

    /// Exact round-trip of every built family-edge table, and of every table
    /// of the export: read under its declared schema, decoded and encoded back
    /// to the stored rows, rewritten and read back to the same rows, and
    /// refused under a foreign schema.
    pub def tables(): Unit \ IO = {
        let scratch = Files.createTempDirectory("atlas-family-edges").toString();
        Vector.forEach(world -> {
            let snapshotId = snapshotOf(world);
            let directory = Experiment.property("${world#prefix}.export");
            let (clustering, aggregation) = Experiment.require(Families.Export.readExported(snapshotId, directory));
            let edgeFiles = files(world#prefix, "edges", Families.Edge.Table.schemas(snapshotId));
            let built = Vector.map(match (table, file, schema, rows) ->
                ("${table}", Map.getWithDefault(table, "", edgeFiles), file, schema, rows),
                Families.Edge.Table.layout(aggregationAt(world#prefix, snapshotId)));
            let shipped = Vector.map(match (table, file, schema, rows) ->
                ("export ${table}", "${directory}/${file}", file, schema, rows),
                Families.Export.layout(clustering, aggregation));
            let foreign = schema -> if (schema#format == Families.Edge.Table.edges()#format)
                Families.Edge.Table.contributions() else Families.Edge.Table.edges();
            FamiliesClusteringLaw.report(world#subject#identity#repository, Vector.flatMap(match (name, path, file, schema, rows) -> {
                let stored = ScientificTable.read(path, schema);
                let copy = "${scratch}/${String.replace(src = ":", dst = "-", snapshotId)}-${file}";
                Vector#{
                    ("${name} typed round-trip", if (stored == rows and not Vector.isEmpty(rows)) Ok(())
                        else Err("decoded ${name} rows do not encode back to the stored rows")),
                    ("${name} parquet round-trip", if (ScientificTable.write(copy, schema, stored) == stored and
                        ScientificTable.read(copy, schema) == stored) Ok(()) else Err("${name} did not round-trip exactly")),
                    ("${name} foreign schema refused", FamiliesClusteringLaw.refused(path, foreign(schema)))
                }
            }, Vector.append(built, shipped)))
        }, exported())
    }

    def subjectOf(world: Exported, clustering: Families.Cluster.Clustering, recorded: Families.Edge.Aggregation): Families.Edge.Law.Subject \ IO = {
        world = world#subject#world,
        relations = ScientificTable.read(Experiment.property("${world#prefix}.world_relations"), Repository.Table.relations()),
        clustering = clustering,
        recorded = recorded
    }

    /// The family-edge laws of every exported world over its built tables.
    pub def laws(): Unit \ IO = Vector.forEach(world -> {
        let snapshotId = snapshotOf(world);
        let subject = subjectOf(world, clusteringAt(world#prefix, snapshotId), aggregationAt(world#prefix, snapshotId));
        FamiliesClusteringLaw.report(world#subject#identity#repository, Families.Edge.Law.laws(subject))
    }, exported())

    def names(directory: String): Vector[String] \ IO = {
        let file = Paths.get(directory).toFile();
        if (not file.isDirectory()) Vector.empty() else Array.toVector(file.list()) |> Vector.sort
    }

    /// The cross-layer parity law: the web projection staging holds exactly
    /// the exported worlds, each with exactly the exported files; every staged
    /// file has the bytes and the typed rows of the Flix-built science table
    /// it ships; and the family-edge laws hold over the staged tables against
    /// the frozen world.
    pub def parity(): Unit \ IO = {
        let root = Experiment.property("attune.staging_root");
        let worlds = exported();
        let digests = Vector.map(world -> Experiment.property("${world#prefix}.digest"), worlds);
        FamiliesClusteringLaw.report("staging", Vector#{("staged worlds are the exported worlds",
            if (names(root) == Vector.sort(digests) and not Vector.isEmpty(digests)) Ok(())
            else Err("staged ${Vector.join(",", names(root))}, exported ${Vector.join(",", digests)}"))});
        Vector.forEach(world -> {
            let snapshotId = snapshotOf(world);
            let staged = "${root}/${Experiment.property("${world#prefix}.digest")}";
            let built = science(world#prefix, snapshotId);
            let clustering = clusteringAt(world#prefix, snapshotId);
            let aggregation = aggregationAt(world#prefix, snapshotId);
            let layout = Families.Export.layout(clustering, aggregation);
            let expectedFiles = Vector.map(match (_, file, _, _) -> file, layout) |> Vector.sort;
            let fileLaws = Vector.flatMap(match (table, file, schema, rows) -> {
                let path = "${staged}/${file}";
                Vector#{
                    ("${file} bytes are the built ${table} table", if (Families.Export.sha256(path) ==
                        Families.Export.sha256(Map.getWithDefault(table, "", built))) Ok(()) else Err("${file} bytes differ")),
                    ("${file} rows are the built ${table} rows", if (ScientificTable.read(path, schema) == rows) Ok(())
                        else Err("${file} rows differ"))
                }
            }, layout);
            let (shippedClustering, shippedAggregation) = Experiment.require(Families.Export.readExported(snapshotId, staged));
            let edgeLaws = Families.Edge.Law.laws(subjectOf(world, shippedClustering, shippedAggregation))
                |> Vector.map(match (name, result) -> ("staged ${name}", result));
            FamiliesClusteringLaw.report(world#subject#identity#repository, Vector.flatten(Vector#{
                Vector#{("staged files are the exported files", if (names(staged) == expectedFiles) Ok(())
                    else Err("staged ${Vector.join(",", names(staged))}"))},
                fileLaws, edgeLaws
            }))
        }, worlds)
    }

    /// The report view of every exported world.
    pub def exportedReport(): Vector[Families.Report.Edged] \ IO = Vector.map(world -> {
        let snapshotId = snapshotOf(world);
        let directory = Experiment.property("${world#prefix}.export");
        let clustering = clusteringAt(world#prefix, snapshotId);
        let aggregation = aggregationAt(world#prefix, snapshotId);
        {
            repository = world#subject#identity#repository,
            world = world#subject#world,
            clustering = clustering,
            aggregation = aggregation,
            files = Vector.map(match (_, file, _, rows) ->
                (file, Vector.length(rows), Families.Export.sha256("${directory}/${file}")),
                Families.Export.layout(clustering, aggregation))
        }
    }, exported())
}
