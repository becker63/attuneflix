import java.lang.System

use Fs.FileSystem
use ScientificTable.Value

def main(): Unit \ {FileSystem, IO} = {
    let manifest = FileSystem.read(System.getProperty("attune.input_manifest"))
        |> Result.mapErr(ToString.toString)
        |> require;
    let paths = String.splitOn(substr = "\n", manifest)
        |> List.filter(path -> not String.isEmpty(path))
        |> List.toVector;
    let rows = Vector.flatMap(path ->
        ScientificTable.read(path, LocalizationReplay.schema()), paths);
    let ids = Vector.traverse(validate, rows) |> require |> Vector.toSet;
    if (Vector.length(rows) != 61) bug!("expected 61 replay proofs")
    else if (Set.size(ids) != 61) bug!("replay proof instance identities are not unique")
    else {
        let admitted = ScientificTable.write(
            System.getProperty("attune.output_proof"), LocalizationReplay.schema(), rows);
        if (Vector.length(admitted) != 61) bug!("aggregate replay proof write/read mismatch")
        else println("LOCALIZATION_REPLAY_AGGREGATE cases=61 exact=true")
    }
}

def validate(row: ScientificTable.Row): Result[String, String] =
    match (Map.get("protocol", row), Map.get("instance_id", row),
        Map.get("expected_prediction_id", row), Map.get("replay_prediction_id", row),
        Map.get("exact_equal", row)) {
        case (Some(Value.Text("attune-keyless-localization-replay-v1")), Some(Value.Text(instanceId)),
            Some(Value.Text(expected)), Some(Value.Text(replay)), Some(Value.Boolean(true)))
            if expected == replay => Ok(instanceId)
        case _ => Err("invalid or unequal localization replay proof")
    }

def require(result: Result[String, a]): a = match result {
    case Ok(value) => value
    case Err(error) => bug!(error)
}
