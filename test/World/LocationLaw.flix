import java.lang.Integer

use ScientificTable.Value

/// The location law for the frozen worlds (VAL-LOC-003, VAL-LOC-004).
///
/// For every world, the parent edges re-derived from the exported locations
/// equal the stored `parent` relation exactly, the exported rows are dense over
/// `0 .. F+D-1`, and every file location carries the path of its file entity.
/// It runs as `//test/World:location_parity_test` with all 78 worlds staged and
/// the digest list passed as action transport properties.
def main(): Unit \ IO = match Experiment.property("attune.command") {
    case "roundtrip" => roundTrip()
    case _ => verifyWorlds()
}

/// The command is absent in the parity script; an explicit unknown command on
/// the parity path still verifies. Only `roundtrip` selects the table law.
def verifyWorlds(): Unit \ IO = {
    let count = Integer.parseInt(Experiment.property("attune.world_count"));
    match verifyRange(0, count, 0) {
        case Err(message) => bug!(message)
        case Ok(mismatches) =>
            if (mismatches == 0)
                println("location_parity: ${count} worlds, 0 mismatches")
            else
                bug!("location_parity: ${mismatches} of ${count} worlds mismatched")
    }
}

def verifyRange(index: Int32, count: Int32, mismatches: Int32): Result[String, Int32] \ IO =
    if (index >= count) Ok(mismatches)
    else match verifyOne(index) {
        case Ok(_) => verifyRange(index + 1, count, mismatches)
        case Err(message) =>
            println("location_parity: world ${index} mismatch: ${message}");
            verifyRange(index + 1, count, mismatches + 1)
    }

def verifyOne(index: Int32): Result[String, Unit] \ IO = {
    let digest = Experiment.property("attune.world.${index}");
    let worldDirectory = Experiment.property("attune.worlds_root") + "/" + digest;
    let metadataPath = worldDirectory + "/metadata.parquet";
    let identity = identityOf(metadataPath);
    match Repository.Table.read(metadataPath, worldDirectory + "/entities.parquet",
            worldDirectory + "/relations.parquet", identity) {
        case Err(error) => Err(error)
        case Ok(world) => {
            let rows = Repository.Location.Table.read(
                Experiment.property("attune.locations_root") + "/" + digest + "/locations.parquet");
            match decodeExported(rows) {
                case Err(error) => Err(error)
                case Ok(exported) => verifyWorld(identity#snapshotId, world, rows, exported)
            }
        }
    }
}

def identityOf(metadataPath: String): Repository.Table.Identity \ IO = {
    let row = match ScientificTable.read(metadataPath, Repository.Table.metadata()) {
        case rows => Vector.get(0, rows)
    };
    {
        repository = Experiment.require(ScientificTable.text(row, "repository")),
        baseRevision = Experiment.require(ScientificTable.text(row, "base_revision")),
        sourceTreeIdentity = Experiment.require(ScientificTable.text(row, "source_tree_identity")),
        factIdentity = Experiment.require(ScientificTable.text(row, "fact_identity")),
        snapshotId = Experiment.require(ScientificTable.text(row, "snapshot_id"))
    }
}

/// One exported location as it appears in the table: id, path, kind.
type alias Exported = (Int64, String, String)

def decodeExported(rows: Vector[ScientificTable.Row]): Result[String, Vector[Exported]] =
    Vector.traverse(decodeExportedRow, rows)

def decodeExportedRow(row: ScientificTable.Row): Result[String, Exported] = forM (
    id <- int64Field(row, "location_id");
    path <- ScientificTable.text(row, "path");
    kind <- ScientificTable.text(row, "kind")
) yield (id, path, kind)

def int64Field(row: ScientificTable.Row, name: String): Result[String, Int64] =
    match Map.get(name, row) {
        case Some(Value.Int64(value)) => Ok(value)
        case Some(_) => Err("${name} must be int64")
        case None => Err("missing ${name}")
    }

def verifyWorld(
    snapshotId: String,
    world: Repository.World,
    rows: Vector[ScientificTable.Row],
    exported: Vector[Exported]
): Result[String, Unit] = {
    let files = world#files;
    let directories = Repository.Location.directories(world);
    let total = Vector.length(files) + Vector.length(directories);
    if (Vector.length(exported) != total)
        Err("exported ${Vector.length(exported)} locations, expected ${total}")
    else forM (
        _ <- checkSnapshot(snapshotId, rows);
        _ <- checkDense(exported, files, directories);
        _ <- checkParents(world#parents, exported)
    ) yield ()
}

def checkSnapshot(snapshotId: String, rows: Vector[ScientificTable.Row]): Result[String, Unit] =
    Vector.map(row -> ScientificTable.requireText("snapshot_id", snapshotId, row, "locations"), rows)
        |> Vector.traverse(result -> result)
        |> Result.map(_ -> ())

def checkDense(
    exported: Vector[Exported],
    files: Vector[String],
    directories: Vector[String]
): Result[String, Unit] = {
    let fileCount = Vector.length(files);
    Vector.mapWithIndex((index, location) -> checkLocation(index, location, fileCount, files, directories),
            exported)
        |> Vector.traverse(result -> result)
        |> Result.map(_ -> ())
}

def checkLocation(
    index: Int32,
    location: Exported,
    fileCount: Int32,
    files: Vector[String],
    directories: Vector[String]
): Result[String, Unit] = {
    let (id, path, kind) = location;
    if (id != Int32.toInt64(index)) Err("location id ${id} is not dense at position ${index}")
    else if (index < fileCount) checkFile(index, path, kind, files)
    else checkDirectory(index - fileCount, path, kind, directories)
}

def checkFile(index: Int32, path: String, kind: String, files: Vector[String]): Result[String, Unit] =
    if (kind != "file") Err("location ${index} is not a file")
    else if (path != Vector.get(index, files)) Err("file location ${index} path mismatch")
    else Ok(())

def checkDirectory(index: Int32, path: String, kind: String,
                   directories: Vector[String]): Result[String, Unit] =
    if (kind != "directory") Err("location is not a directory")
    else if (path != Vector.get(index, directories)) Err("directory location ${index} path mismatch")
    else Ok(())

/// Re-derives each parent edge from the exported locations: every non-root
/// location to the location of its containing directory, and none for the root.
def checkParents(stored: Repository.Structure.Parents, exported: Vector[Exported]): Result[String, Unit] = {
    let directoryIds = Vector.foldLeft((known, location) -> match location {
        case (id, path, "directory") => Map.insert(path, id, known)
        case _ => known
    }, Map.empty(), exported);
    let derived = Vector.filterMap(location -> match location {
        case (id, path, _) =>
            if (path == "") None
            else Map.get(Repository.Location.directory(path), directoryIds)
                |> Option.map(parent -> (id, parent))
    }, exported) |> Vector.toSet;
    let stored64 = Set.map(match (source, target) -> (Int32.toInt64(source |> locationId),
        Int32.toInt64(target |> locationId)), stored);
    if (derived == stored64) Ok(())
    else Err("derived ${Set.size(derived)} parent edges, stored ${Set.size(stored64)}")
}

def locationId(id0: Repository.Structure.LocationId): Int32 =
    let Repository.Structure.LocationId.LocationId(value) = id0;
    value
