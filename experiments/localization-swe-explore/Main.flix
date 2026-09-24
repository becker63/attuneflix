import java.lang.System

use Fs.FileSystem
use ScientificTable.Value

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
    let issue = Localization.IssueTable.read(property("attune.issue"), property("attune.instance_id"))
        |> require;
    let prepared = Localization.prepareWorld(
        property("attune.instance_id"), identity#repository,
        identity#baseRevision, identity#snapshotId, issue, world
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
                "protocol" => Value.Text("attune-keyless-localization-replay-v1"),
                "instance_id" => Value.Text(prepared#instanceId),
                "repository" => Value.Text(prepared#repository),
                "base_revision" => Value.Text(prepared#baseCommit),
                "snapshot_id" => Value.Text(prepared#snapshotId),
                "expected_prediction_id" => Value.Text(expectedId),
                "replay_prediction_id" => Value.Text(replayId),
                "exact_equal" => Value.Boolean(true),
                "decision_occurrences" => Value.Int32(Vector.length(outcome#decisions)),
                "unique_decisions" => Value.Int32(Map.size(wires)),
                "states_interned" => Value.Int32(outcome#metrics#statesInterned),
                "memo_entries" => Value.Int32(outcome#metrics#memoEntries),
                "memo_slots" => Value.Int32(outcome#metrics#memoSlots),
                "replay_nanos" => Value.Int64(elapsed)
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
