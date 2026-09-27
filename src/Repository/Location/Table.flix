/// Typed Parquet representation of one world's admitted locations. The schema
/// is declared here in Flix; the Arrow seam only realizes the declared columns.
pub mod Repository.Location.Table {
    use ScientificTable.Value
    use ScientificTable.Columns.{text, int64}

    pub def locations(): ScientificTable.Schema = {
        format = "attune-repository-locations-v1",
        columns = Vector#{
            text("snapshot_id"), int64("location_id"), text("path"), text("kind")
        }
    }

    pub def rows(
        snapshotId: String,
        values: Vector[Repository.Location.Location]
    ): Vector[ScientificTable.Row] =
        Vector.map(match (id, path, kind) -> Map#{
            "snapshot_id" => Value.Text(snapshotId),
            "location_id" => Value.Int64(Int32.toInt64(locationId(id))),
            "path" => Value.Text(path),
            "kind" => Value.Text(kindName(kind))
        }, values)

    /// Writes the table and returns the rows read back from the completed write.
    pub def write(
        path: String,
        snapshotId: String,
        values: Vector[Repository.Location.Location]
    ): Vector[ScientificTable.Row] \ IO =
        ScientificTable.write(path, locations(), rows(snapshotId, values))

    pub def read(path: String): Vector[ScientificTable.Row] \ IO =
        ScientificTable.read(path, locations())

    pub def kindName(kind: Repository.Location.LocationKind): String = match kind {
        case Repository.Location.LocationKind.File => "file"
        case Repository.Location.LocationKind.Directory => "directory"
    }

    def locationId(id0: Repository.Structure.LocationId): Int32 =
        let Repository.Structure.LocationId.LocationId(value) = id0;
        value
}
