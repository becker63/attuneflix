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
    let prior = Localization.PriorTable.read(
        property("attune.prior_metadata"), property("attune.prior_documents"),
        property("attune.prior_ranking"), prepared#instanceId) |> require;
    let tree = Localization.Tree.compile();
    let computed = Localization.Tree.compute(prepared, prior, tree)
        |> Result.mapErr(ToString.toString) |> require;
    let wires = Decide.Table.read(property("attune.decisions")) |> require;
    let outcome = Localization.Policy.frozen013Replay(prepared, prior, computed, wires)
        |> Result.mapErr(ToString.toString) |> require;
    let replay = Localization.PredictionTable.rows(prepared, outcome);
    let expected = Localization.PredictionTable.read(
        property("attune.expected_summary"), property("attune.expected_ranking"),
        property("attune.expected_decisions"), property("attune.expected_probabilities")) |> require;
    if (not Localization.PredictionTable.exactEqual(replay, expected))
        bug!("exact localization replay mismatch for ${prepared#instanceId}")
    else {
        let _admitted = Localization.PredictionTable.write(
            property("attune.output_prediction_summary"), property("attune.output_prediction_ranking"),
            property("attune.output_prediction_decisions"), property("attune.output_prediction_probabilities"),
            replay);
        let readBack = Localization.PredictionTable.read(
            property("attune.output_prediction_summary"), property("attune.output_prediction_ranking"),
            property("attune.output_prediction_decisions"), property("attune.output_prediction_probabilities"))
            |> require;
        if (not Localization.PredictionTable.exactEqual(readBack, expected))
            bug!("replayed prediction persistence mismatch")
        else {
            let elapsed = System.nanoTime() - started;
            let expectedId = Localization.PredictionTable.identity(expected);
            // Identity is over the admitted typed representation. The fresh
            // in-memory rows may encode equal numeric values with a different
            // JSON number constructor; readBack is the canonical Parquet
            // admission already proven semantically equal above.
            let replayId = Localization.PredictionTable.identity(readBack);
            let proof = ScientificTable.write(property("attune.output_proof"), LocalizationReplay.schema(), Vector#{Map#{
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

def property(name: String): String \ IO = System.getProperty(name)

def require(result: Result[String, a]): a = match result {
    case Ok(value) => value
    case Err(error) => bug!(error)
}
