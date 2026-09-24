import java.lang.System

use Fs.FileSystem

def main(): Unit \ {FileSystem, IO} =
    match FileSystem.read(System.getProperty("attune.input_manifest"))
        |> Result.mapErr(ToString.toString)
        |> Result.flatMap(parseManifest) {
        case Err(error) => bug!(error)
        case Ok(inputs) => {
            let tables = load(inputs, Nil, Nil, Nil);
            let summaries = List.reverse(tables#summaries) |> List.toVector |> Vector.flatten;
            let snapshots = List.reverse(tables#snapshots) |> List.toVector |> Vector.flatten;
            let physical = List.reverse(tables#physical) |> List.toVector |> Vector.flatten;
            let writtenSummaries = ScientificTable.write(
                System.getProperty("attune.output_summaries"),
                Atlas.Signature.Summary.schema(), summaries);
            let writtenSnapshots = ScientificTable.write(
                System.getProperty("attune.output_snapshots"),
                Atlas.Signature.Table.snapshots(), snapshots);
            let writtenPhysical = ScientificTable.write(
                System.getProperty("attune.output_physical"),
                Atlas.Signature.Table.physical(), physical);
            if (Vector.length(inputs) != Vector.length(writtenSnapshots))
                bug!("Atlas aggregate must contain exactly one snapshot row per input shard")
            else println("ATLAS_AGGREGATE snapshots=${Vector.length(writtenSnapshots)}" +
                " summaries=${Vector.length(writtenSummaries)}" +
                " physical=${Vector.length(writtenPhysical)}")
        }
    }

type alias Input = {summary = String, snapshot = String, physical = String}

type alias Tables = {
    summaries = List[Vector[ScientificTable.Row]],
    snapshots = List[Vector[ScientificTable.Row]],
    physical  = List[Vector[ScientificTable.Row]]
}

def parseManifest(payload: String): Result[String, Vector[Input]] =
    String.splitOn(substr = "\n", payload)
    |> List.filter(line -> not String.isEmpty(line))
    |> List.map(parseLine)
    |> List.sequence
    |> Result.map(List.toVector)

def parseLine(line: String): Result[String, Input] = {
    let fields = String.splitOn(substr = "\t", line) |> List.toVector;
    if (Vector.length(fields) != 3) Err("invalid Atlas aggregate input manifest row")
    else Ok({
        summary = Vector.get(0, fields),
        snapshot = Vector.get(1, fields),
        physical = Vector.get(2, fields)
    })
}

def load(inputs: Vector[Input], summaries: List[Vector[ScientificTable.Row]],
         snapshots: List[Vector[ScientificTable.Row]],
         physical: List[Vector[ScientificTable.Row]]): Tables \ IO =
    loadFrom(inputs, 0, summaries, snapshots, physical)

def loadFrom(inputs: Vector[Input], index: Int32,
             summaries: List[Vector[ScientificTable.Row]],
             snapshots: List[Vector[ScientificTable.Row]],
             physical: List[Vector[ScientificTable.Row]]): Tables \ IO =
    if (index >= Vector.length(inputs)) {
        summaries = summaries, snapshots = snapshots, physical = physical
    } else {
        let input = Vector.get(index, inputs);
        loadFrom(inputs, index + 1,
            ScientificTable.read(input#summary, Atlas.Signature.Summary.schema()) :: summaries,
            ScientificTable.read(input#snapshot, Atlas.Signature.Table.snapshots()) :: snapshots,
            ScientificTable.read(input#physical, Atlas.Signature.Table.physical()) :: physical)
    }
