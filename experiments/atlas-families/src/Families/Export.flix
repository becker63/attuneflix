/// The Atlas Live export of one world's families, on the locations-export
/// route: the three clustering tables and the two family-edge tables, under
/// the file names the web data tree ships them as. The exported rows are the
/// science tables' rows under the same schemas, so the web consumes the
/// derived Parquet as is and never derives any of it.
pub mod Families.Export {
    import java.nio.file.{Files, Paths}
    import java.security.MessageDigest
    import java.util.HexFormat

    type alias Entry = (String, String, ScientificTable.Schema, Vector[ScientificTable.Row])

    /// `(table, exported file, schema, rows)` of one world's export, in
    /// clustering then edge table order.
    pub def layout(clustering: Families.Cluster.Clustering, aggregation: Families.Edge.Aggregation): Vector[Entry] =
        exported(Vector.append(Families.Cluster.Table.layout(clustering), Families.Edge.Table.layout(aggregation)))

    def exported(entries: Vector[Entry]): Vector[Entry] =
        Vector.map(match (table, _, schema, rows) -> (table, fileName(table), schema, rows), entries)

    /// The catalog ships as `families.parquet`, every other table as
    /// `family_<table>.parquet`, beside the world's `locations.parquet`.
    pub def fileName(table: String): String = if (table == "families") "families.parquet" else "family_${table}.parquet"

    /// The export layout with no rows: every table's name, file, and schema.
    pub def schemas(snapshotId: String): Vector[Entry] =
        exported(Vector.append(Families.Cluster.Table.schemas(snapshotId), Families.Edge.Table.schemas(snapshotId)))

    /// The clustering and aggregation stored in `files` (table name -> path).
    pub def read(snapshotId: String, files: Map[String, String]): Result[String, (Families.Cluster.Clustering, Families.Edge.Aggregation)] \ IO = forM (
        clustering <- Families.Cluster.Table.read(snapshotId, files);
        aggregation <- Families.Edge.Table.read(snapshotId, files)
    ) yield (clustering, aggregation)

    /// The export in `directory`, read under the exported file names.
    pub def readExported(snapshotId: String, directory: String): Result[String, (Families.Cluster.Clustering, Families.Edge.Aggregation)] \ IO =
        read(snapshotId, Vector.map(match (table, file, _, _) -> (table, "${directory}/${file}"), schemas(snapshotId)) |> Vector.toMap)

    /// Writes the export into `directory`; every table must round-trip
    /// exactly. Returns each exported file with its row count.
    pub def write(
        directory: String,
        clustering: Families.Cluster.Clustering,
        aggregation: Families.Edge.Aggregation
    ): Result[String, Vector[(String, Int32)]] \ IO = {
        let _ = Files.createDirectories(Paths.get(directory));
        Vector.traverse(match (table, file, schema, rows) ->
            if (ScientificTable.write("${directory}/${file}", schema, rows) == rows) Ok((file, Vector.length(rows)))
            else Err("${table} did not round-trip exactly"),
            layout(clustering, aggregation))
    }

    /// The SHA-256 of a file's bytes, lowercase hex.
    pub def sha256(path: String): String \ IO =
        HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(Files.readAllBytes(Paths.get(path))))
}
