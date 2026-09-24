import java.lang.System

use Fs.FileSystem
use Util.Json.Json.{JBool, JString}
use Util.Json.ToJson

def main(): Unit \ {FileSystem, IO} = {
    let started = System.nanoTime();
    let identity = FileSystem.read(property("attune.world_identity"))
        |> Result.mapErr(ToString.toString)
        |> Result.flatMap(Repository.Identity.decode)
        |> require;
    let world = Repository.Table.read(
        property("attune.world_metadata"),
        property("attune.world_entities"),
        property("attune.world_relations"),
        identity
    ) |> require;
    let issuePayload = FileSystem.read(property("attune.issues"))
        |> Result.mapErr(ToString.toString)
        |> require;
    let prepared = Localization.prepareWorld(
        property("attune.instance_id"), identity#repository,
        identity#baseRevision, identity#snapshotId, issuePayload, world
    ) |> require;
    let prior = Localization.Tree.decodePrior(
        prepared#instanceId,
        ScientificData.readObject(property("attune.prior"))
    ) |> Result.mapErr(ToString.toString) |> require;
    let tree = Localization.Tree.compile();
    let computed = Localization.Tree.compute(prepared, prior, tree)
        |> Result.mapErr(ToString.toString) |> require;
    let wires = Decide.Table.read(property("attune.decisions")) |> require;
    let outcome = JevPolicyHillclimb.frozen013Replay(prepared, prior, computed, wires)
        |> Result.mapErr(ToString.toString) |> require;
    let replay = ScientificData.canonicalizeObject(Localization.Result.encode(prepared, outcome));
    let expected = ScientificData.readObject(property("attune.expected"));
    if (replay != expected) bug!("exact localization replay mismatch for ${prepared#instanceId}")
    else {
        let _admitted = ScientificData.writeObject(property("attune.output_prediction"), replay);
        let readBack = ScientificData.readObject(property("attune.output_prediction"));
        if (readBack != expected) bug!("replayed prediction persistence mismatch")
        else {
            let elapsed = System.nanoTime() - started;
            let expectedId = ScientificIdentity.versioned("localization-prediction-v1", expected);
            let replayId = ScientificIdentity.versioned("localization-prediction-v1", replay);
            let proof = ScientificTable.write(property("attune.output_proof"), proofSchema(), Vector#{Map#{
                "protocol" => JString("attune-keyless-localization-replay-v1"),
                "instance_id" => JString(prepared#instanceId),
                "repository" => JString(prepared#repository),
                "base_revision" => JString(prepared#baseCommit),
                "snapshot_id" => JString(prepared#snapshotId),
                "expected_prediction_id" => JString(expectedId),
                "replay_prediction_id" => JString(replayId),
                "exact_equal" => JBool(true),
                "decision_occurrences" => ToJson.toJson(Vector.length(outcome#decisions)),
                "unique_decisions" => ToJson.toJson(Map.size(wires)),
                "states_interned" => ToJson.toJson(outcome#metrics#statesInterned),
                "memo_entries" => ToJson.toJson(outcome#metrics#memoEntries),
                "memo_slots" => ToJson.toJson(outcome#metrics#memoSlots),
                "replay_nanos" => ToJson.toJson(elapsed)
            }});
            if (Vector.length(proof) != 1) bug!("replay proof write/read mismatch")
            else println("LOCALIZATION_REPLAY case=${prepared#instanceId}" +
                " decisions=${Vector.length(outcome#decisions)}" +
                " unique=${Map.size(wires)} nanos=${elapsed} exact=true")
        }
    }
}

def proofSchema(): ScientificTable.Schema = {
    format = "attune-localization-replay-proof-v1",
    columns = Vector#{
        text("protocol"), text("instance_id"), text("repository"),
        text("base_revision"), text("snapshot_id"),
        text("expected_prediction_id"), text("replay_prediction_id"),
        boolean("exact_equal"), int32("decision_occurrences"),
        int32("unique_decisions"), int32("states_interned"),
        int32("memo_entries"), int32("memo_slots"), int64("replay_nanos")
    }
}

def property(name: String): String \ IO = System.getProperty(name)

def text(name: String): ScientificTable.Column = {
    name = name, kind = ScientificTable.ColumnType.Text, nullable = false
}

def boolean(name: String): ScientificTable.Column = {
    name = name, kind = ScientificTable.ColumnType.Boolean, nullable = false
}

def int32(name: String): ScientificTable.Column = {
    name = name, kind = ScientificTable.ColumnType.Int32, nullable = false
}

def int64(name: String): ScientificTable.Column = {
    name = name, kind = ScientificTable.ColumnType.Int64, nullable = false
}

def require(result: Result[String, a]): a = match result {
    case Ok(value) => value
    case Err(error) => bug!(error)
}
