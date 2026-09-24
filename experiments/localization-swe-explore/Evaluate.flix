import java.lang.System

use Fs.FileSystem

def main(): Unit \ {FileSystem, IO} = {
    let identity = FileSystem.read(property("attune.world_identity"))
        |> Result.mapErr(ToString.toString)
        |> Result.flatMap(Repository.Identity.decode) |> require;
    let world = Repository.Table.read(
        property("attune.world_metadata"), property("attune.world_entities"),
        property("attune.world_relations"), identity) |> require;
    let issue = Localization.IssueTable.read(property("attune.issue"), property("attune.instance_id"))
        |> require;
    let prepared = Localization.prepareWorld(
        property("attune.instance_id"), identity#repository, identity#baseRevision,
        identity#snapshotId, issue, world) |> require;
    let prior = Localization.PriorTable.read(
        property("attune.prior_metadata"), property("attune.prior_documents"),
        property("attune.prior_ranking"), prepared#instanceId) |> require;
    let computed = Localization.Tree.compute(prepared, prior, Localization.Tree.compile())
        |> Result.mapErr(ToString.toString) |> require;
    let prediction = Localization.PredictionTable.read(
        property("attune.prediction_summary"), property("attune.prediction_ranking"),
        property("attune.prediction_decisions"), property("attune.prediction_probabilities")) |> require;
    let selected = Localization.PredictionTable.rankingIdentities(prepared#instanceId, prediction) |> require;
    let gold = Localization.EvaluationData.readGold(
        property("attune.gold"), prepared#instanceId) |> require;
    let geometry = Localization.EvaluationData.readGeometry(
        property("attune.geometry"), prepared#instanceId, Vector.length(world#symbols)) |> require;
    let result = Localization.Evaluate.evaluate(
        prepared, prior, computed, selected, gold, geometry) |> require;
    let expectedMetrics = ScientificTable.read(
        property("attune.expected_metrics"), Localization.EvaluationTable.metrics());
    let expectedRegions = ScientificTable.read(
        property("attune.expected_regions"), Localization.EvaluationTable.regions());
    let proofRow = Localization.Evaluate.parityProof(
        prepared#instanceId, identity#baseRevision, identity#snapshotId,
        expectedMetrics, expectedRegions, result) |> require;
    let metrics = ScientificTable.write(property("attune.output_metrics"),
        Localization.EvaluationTable.metrics(),
        Localization.Evaluate.metricRows(result, identity#baseRevision, identity#snapshotId));
    let regions = ScientificTable.write(property("attune.output_regions"),
        Localization.EvaluationTable.regions(), Localization.Evaluate.regionRows(result));
    let telemetry = ScientificTable.write(property("attune.output_telemetry"),
        Localization.EvaluationTable.telemetry(), Localization.Evaluate.telemetryRows(result));
    let proof = ScientificTable.write(property("attune.output_proof"),
        Localization.EvaluationTable.proof(), Vector#{proofRow});
    if (Vector.length(metrics) != 3 or Vector.length(regions) > 15 or
        Vector.length(telemetry) != 1 or Vector.length(proof) != 1)
        bug!("evaluation typed-table round-trip mismatch")
    else println("LOCALIZATION_EVALUATION case=${prepared#instanceId}" +
        " logical_routes=${result#telemetry#logicalRoutes}" +
        " unique_states=${result#telemetry#uniqueStates}" +
        " unique_projections=${result#telemetry#uniqueProjections}" +
        " score_evaluations=${result#telemetry#scoreEvaluations} parity=true")
}

def property(name: String): String \ IO = System.getProperty(name)

def require(result: Result[String, a]): a = match result {
    case Ok(value) => value
    case Err(error) => bug!(error)
}
