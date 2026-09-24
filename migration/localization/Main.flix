// One-time projection of repository-wide raw paid decision evidence into
// small typed per-case bundles. The provider envelopes remain authoritative;
// this migration only removes unrelated observations from each replay input.
use Fs.FileSystem
type alias CaseInput = {
    key = String,
    baseRevision = String,
    predictionSummary = String,
    predictionRanking = String,
    predictionDecisions = String,
    predictionProbabilities = String,
    output = String,
    responseIds = Set[String]
}

def main(): Unit \ {FileSystem, IO} = {
    let cases = readCases() |> require;
    let rawPaths = Experiment.paths("attune.raw_envelopes");
    let selected = collect(rawPaths, cases, 0, Map.empty()) |> require;
    let total = writeCases(cases, selected, 0, 0) |> require;
    println("LOCALIZATION_DECISION_MIGRATION cases=${Vector.length(cases)}" +
        " raw_envelopes=${Vector.length(rawPaths)} selected=${total}")
}

def read(path: String): Result[String, String] \ FileSystem =
    FileSystem.read(path) |> Result.mapErr(ToString.toString)

def readCases(): Result[String, Vector[CaseInput]] \ IO = {
    let count = Experiment.count("attune.cases");
    let summaries = Experiment.paths("attune.prediction_summaries");
    let rankings = Experiment.paths("attune.prediction_rankings");
    let decisions = Experiment.paths("attune.prediction_decisions");
    let probabilities = Experiment.paths("attune.prediction_probabilities");
    let outputs = Experiment.paths("attune.bundle_outputs");
    if (Vector.exists(paths -> Vector.length(paths) != count,
        Vector#{summaries, rankings, decisions, probabilities, outputs}))
        Err("decision migration input lists differ in length")
    else Vector.traverse(index -> {
            let summary = Vector.get(index, summaries);
            let ranking = Vector.get(index, rankings);
            let decisionRows = Vector.get(index, decisions);
            let probabilityRows = Vector.get(index, probabilities);
            Localization.PredictionTable.read(summary, ranking, decisionRows, probabilityRows)
                |> Result.flatMap(Localization.PredictionTable.responseIds)
                |> Result.map(ids -> {
                    key = Experiment.property("attune.case_keys.${index}"),
                    baseRevision = Experiment.property("attune.base_revisions.${index}"),
                    predictionSummary = summary,
                    predictionRanking = ranking,
                    predictionDecisions = decisionRows,
                    predictionProbabilities = probabilityRows,
                    output = Vector.get(index, outputs),
                    responseIds = ids
                })
    }, Vector.range(0, count))
}

def collect(
    paths: Vector[String],
    cases: Vector[CaseInput],
    index: Int32,
    selected: Map[String, List[ScientificTable.Row]]
): Result[String, Map[String, List[ScientificTable.Row]]] \ FileSystem =
    if (index >= Vector.length(paths)) Ok(selected)
    else forM (
        payload <- read(Vector.get(index, paths));
        row <- Decide.Table.row(payload);
        decisionId <- Decide.Table.decisionId(row);
        owner <- decisionOwner(decisionId, cases);
        next = match owner {
            case None => selected
            case Some(key) => Map.insert(key,
                row :: (Map.get(key, selected) |> Option.getWithDefault(Nil)), selected)
        };
        result <- collect(paths, cases, index + 1, next)
    ) yield result

/// The frozen scale population has one exact base revision per case. The
/// revision is part of every model-visible request state, so it assigns both
/// winning and discarded planning decisions without interpreting the policy.
def decisionOwner(identity: String, cases: Vector[CaseInput]): Result[String, Option[String]] = {
    let matches = Vector.filter(case0 -> String.contains(substr = case0#baseRevision, identity), cases);
    if (Vector.length(matches) > 1) Err("decision identity matches multiple frozen revisions")
    else if (Vector.length(matches) == 1) Ok(Some(Vector.get(0, matches)#key))
    else Ok(None)
}

def writeCases(
    cases: Vector[CaseInput],
    selected: Map[String, List[ScientificTable.Row]],
    index: Int32,
    total: Int32
): Result[String, Int32] \ IO =
    if (index >= Vector.length(cases)) Ok(total)
    else {
        let case0 = Vector.get(index, cases);
        let rows = Map.get(case0#key, selected)
            |> Option.getWithDefault(Nil)
            |> List.reverse
            |> List.toVector;
        let found = Vector.traverse(Decide.Table.responseId, rows)
            |> Result.map(Vector.toSet);
        match found {
            case Err(error) => Err(error)
            case Ok(foundIds) if not Set.isSubsetOf(case0#responseIds, foundIds) =>
                Err("decision bundle ${case0#key} is missing a response retained by its final prediction")
            case Ok(_) => {
            let admitted = Decide.Table.write(case0#output, rows);
            if (Vector.length(admitted) != Vector.length(rows))
                Err("decision bundle ${case0#key} write/read count mismatch")
            else writeCases(cases, selected, index + 1, total + Vector.length(rows))
            }
        }
    }

def require(result: Result[String, a]): a = match result {
    case Ok(value) => value
    case Err(error) => bug!(error)
}
