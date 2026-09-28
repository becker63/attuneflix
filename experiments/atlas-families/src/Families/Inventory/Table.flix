/// Typed Parquet representation of one world's acquisition inventory. The
/// schema is declared here in Flix and is the single owner of its column
/// literals; the Arrow seam only realizes the declared columns.
pub mod Families.Inventory.Table {
    use ScientificTable.Value
    use ScientificTable.Columns.{text, int32, int64}

    pub def protocol(): String = "attune-families-inventory-v1"

    pub def inventory(): ScientificTable.Schema = {
        format = protocol(),
        columns = Vector#{
            text("protocol"), text("snapshot_id"), text("repository"),
            int32("files"), int32("callables"), int32("directories"),
            int32("imports"), int32("calls"), int32("parents"),
            int64("callable_source_bytes")
        }
    }

    pub def row(value: Families.Inventory.Inventory): ScientificTable.Row = Map#{
        "protocol" => Value.Text(protocol()),
        "snapshot_id" => Value.Text(value#snapshotId),
        "repository" => Value.Text(value#repository),
        "files" => Value.Int32(value#files),
        "callables" => Value.Int32(value#callables),
        "directories" => Value.Int32(value#directories),
        "imports" => Value.Int32(value#imports),
        "calls" => Value.Int32(value#calls),
        "parents" => Value.Int32(value#parents),
        "callable_source_bytes" => Value.Int64(value#callableSourceBytes)
    }

    /// A table holds exactly one world's inventory.
    pub def decode(rows: Vector[ScientificTable.Row]): Result[String, Families.Inventory.Inventory] =
        ScientificTable.exactlyOne("families inventory", rows) |> Result.flatMap(decodeRow)

    /// Writes the table and returns the inventory decoded from the completed write.
    pub def write(path: String, value: Families.Inventory.Inventory): Result[String, Families.Inventory.Inventory] \ IO =
        decode(ScientificTable.write(path, inventory(), Vector#{row(value)}))

    pub def read(path: String): Result[String, Families.Inventory.Inventory] \ IO =
        decode(ScientificTable.read(path, inventory()))

    def decodeRow(row: ScientificTable.Row): Result[String, Families.Inventory.Inventory] = forM (
        _ <- ScientificTable.requireText("protocol", protocol(), row, "families inventory");
        snapshotId <- ScientificTable.text(row, "snapshot_id");
        repository <- ScientificTable.text(row, "repository");
        files <- ScientificTable.int32(row, "files");
        callables <- ScientificTable.int32(row, "callables");
        directories <- ScientificTable.int32(row, "directories");
        imports <- ScientificTable.int32(row, "imports");
        calls <- ScientificTable.int32(row, "calls");
        parents <- ScientificTable.int32(row, "parents");
        bytes <- int64Value(row, "callable_source_bytes")
    ) yield {
        snapshotId = snapshotId, repository = repository, files = files,
        callables = callables, directories = directories, imports = imports,
        calls = calls, parents = parents, callableSourceBytes = bytes
    }

    def int64Value(row: ScientificTable.Row, name: String): Result[String, Int64] = match Map.get(name, row) {
        case Some(Value.Int64(value)) => Ok(value)
        case Some(_) => Err("${name} must be int64")
        case None => Err("missing ${name}")
    }
}
