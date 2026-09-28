/// Shared row discipline for the families tables: every row carries its
/// table protocol and world snapshot, retained tables are written once and
/// never replaced, and a table's identity is the digest of its canonical rows.
pub mod Families.Rows {
    import java.nio.file.{Files, Paths}

    use ScientificTable.Value

    /// The protocol and snapshot columns every families row starts with.
    pub def header(schema: ScientificTable.Schema, snapshotId: String): ScientificTable.Row = Map#{
        "protocol" => Value.Text(schema#format),
        "snapshot_id" => Value.Text(snapshotId)
    }

    pub def require(schema: ScientificTable.Schema, snapshotId: String, row: ScientificTable.Row): Result[String, Unit] = forM (
        _ <- ScientificTable.requireText("protocol", schema#format, row, schema#format);
        _ <- ScientificTable.requireText("snapshot_id", snapshotId, row, schema#format);
        _ <- if (Map.keysOf(row) == Vector.toSet(Vector.map(column -> column#name, schema#columns))) Ok(())
             else Err("${schema#format}: row columns differ from the schema")
    ) yield ()

    pub def int64(row: ScientificTable.Row, name: String): Result[String, Int64] = match Map.get(name, row) {
        case Some(Value.Int64(value)) => Ok(value)
        case Some(_) => Err("${name} must be int64")
        case None => Err("missing ${name}")
    }

    pub def float64(row: ScientificTable.Row, name: String): Result[String, Float64] = match Map.get(name, row) {
        case Some(Value.Float64(value)) => Ok(value)
        case Some(_) => Err("${name} must be float64")
        case None => Err("missing ${name}")
    }

    pub def textList(row: ScientificTable.Row, name: String): Result[String, Vector[String]] = match Map.get(name, row) {
        case Some(Value.TextList(values)) => Ok(values)
        case Some(_) => Err("${name} must be a text list")
        case None => Err("missing ${name}")
    }

    /// Exact decimal text of a Float64: `Float64.toString` is the shortest
    /// representation that parses back to the same double.
    pub def decimal(value: Float64): String = Float64.toString(value)

    pub def parseDecimal(name: String, text: String): Result[String, Float64] =
        Float64.fromString(text) |> Option.toOk("${name}: ${text} is not a decimal")

    /// The table identity: a digest over the schema and its canonical rows.
    pub def identity(schema: ScientificTable.Schema, rows: Vector[ScientificTable.Row]): String \ IO =
        ScientificIdentity.versioned(schema#format,
            ScientificTable.schemaPayload(schema) + "\n" + ScientificTable.canonicalRows(rows))

    /// The rows of every table of a layout `(table, file, schema, _)`, each
    /// read from `files` (table name -> path) under its declared schema.
    pub def readLayout(
        layout: Vector[(String, String, ScientificTable.Schema, Vector[ScientificTable.Row])],
        files: Map[String, String]
    ): Result[String, Map[String, Vector[ScientificTable.Row]]] \ IO =
        Vector.traverse(match (table, _, schema, _) -> match Map.get(table, files) {
            case Some(path) => Ok((table, ScientificTable.read(path, schema)))
            case None => Err("no ${table} table")
        }, layout) |> Result.map(Vector.toMap)

    pub def rowsOf(tables: Map[String, Vector[ScientificTable.Row]], table: String): Vector[ScientificTable.Row] =
        Map.getWithDefault(table, Vector.empty(), tables)

    /// Writes a new table, or proves an existing one holds exactly these rows.
    /// Retained evidence tables are never replaced.
    pub def retain(path: String, schema: ScientificTable.Schema, rows: Vector[ScientificTable.Row]): Result[String, Unit] \ IO =
        if (Files.exists(Paths.get(path))) {
            if (ScientificTable.read(path, schema) == rows) Ok(())
            else Err("retained table ${path} differs from this pass; refusing to replace it")
        } else {
            let _ = Files.createDirectories(Paths.get(path).getParent());
            if (ScientificTable.write(path, schema, rows) == rows) Ok(())
            else Err("table ${path} did not round-trip exactly")
        }
}
