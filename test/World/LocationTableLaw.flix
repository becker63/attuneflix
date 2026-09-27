import java.lang.System

use ScientificTable.Value

/// The locations table law (VAL-LOC-005): the schema is declared in Flix and a
/// write/read round-trip through the typed Parquet seam is exact. It runs inside
/// the World law binary (which carries the Arrow `--add-opens` flags) as
/// `//test/World:location_table_test` with `attune.command=roundtrip`.
pub def roundTrip(): Unit \ IO = {
    checkSchema();
    let path = System.getProperty("java.io.tmpdir") + "/attune-locations-table-test.parquet";
    let snapshotId = "repository-snapshot-v1:locations-table-test";
    let expected = fixture();
    let written = Repository.Location.Table.write(path, snapshotId, expected);
    let readBack = Repository.Location.Table.read(path);
    requireOk(written == readBack, "locations write/read rows differ");
    requireOk(readBack == Repository.Location.Table.rows(snapshotId, expected),
        "locations read-back rows differ from the declared rows");
    println("locations_table: roundtrip ok rows=${Vector.length(readBack)}")
}

def checkSchema(): Unit \ IO = {
    let schema = Repository.Location.Table.locations();
    requireOk(schema#format == "attune-repository-locations-v1", "locations schema format");
    requireOk(Vector.map(column -> column#name, schema#columns) ==
        Vector#{"snapshot_id", "location_id", "path", "kind"}, "locations schema columns");
    requireOk(Vector.map(column -> column#kind, schema#columns) == Vector#{
        ScientificTable.ColumnType.Text, ScientificTable.ColumnType.Int64,
        ScientificTable.ColumnType.Text, ScientificTable.ColumnType.Text
    }, "locations schema column kinds");
    requireOk(Vector.count(column -> column#nullable, schema#columns) == 0,
        "locations schema columns must be non-null")
}

def requireOk(condition: Bool, message: String): Unit \ IO =
    if (condition) () else fail(message)

def fail(message: String): Unit \ IO = {
    println("locations_table: ${message}");
    System.exit(1)
}

def fixture(): Vector[Repository.Location.Location] = Vector#{
    (Repository.Structure.LocationId.LocationId(0), "src/a.ts", Repository.Location.LocationKind.File),
    (Repository.Structure.LocationId.LocationId(1), "src/b.ts", Repository.Location.LocationKind.File),
    (Repository.Structure.LocationId.LocationId(2), "", Repository.Location.LocationKind.Directory),
    (Repository.Structure.LocationId.LocationId(3), "src", Repository.Location.LocationKind.Directory)
}
