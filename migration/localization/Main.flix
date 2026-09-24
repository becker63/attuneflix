// One-time projection of repository-wide raw paid decision evidence into
// small typed per-case bundles. The provider envelopes remain authoritative;
// this migration only removes unrelated observations from each replay input.
import java.lang.System

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
    let cases = read(System.getProperty("attune.case_manifest"))
        |> Result.flatMap(parseCases)
        |> require;
    let rawPaths = read(System.getProperty("attune.raw_manifest"))
        |> Result.map(lines)
        |> require;
    let selected = collect(rawPaths, cases, 0, Map.empty()) |> require;
    let total = writeCases(cases, selected, 0, 0) |> require;
    println("LOCALIZATION_DECISION_MIGRATION cases=${Vector.length(cases)}" +
        " raw_envelopes=${Vector.length(rawPaths)} selected=${total}")
}

def read(path: String): Result[String, String] \ FileSystem =
    FileSystem.read(path) |> Result.mapErr(ToString.toString)

def parseCases(payload: String): Result[String, Vector[CaseInput]] \ IO =
    lines(payload)
    |> Vector.traverse(line -> {
        let fields = String.splitOn(substr = "\t", line) |> List.toVector;
        if (Vector.length(fields) != 7) Err("invalid localization migration case row")
        else {
            let summary = Vector.get(2, fields);
            let ranking = Vector.get(3, fields);
            let decisions = Vector.get(4, fields);
            let probabilities = Vector.get(5, fields);
            Localization.PredictionTable.read(summary, ranking, decisions, probabilities)
                |> Result.flatMap(Localization.PredictionTable.responseIds)
                |> Result.map(ids -> {
                    key = Vector.get(0, fields),
                    baseRevision = Vector.get(1, fields),
                    predictionSummary = summary,
                    predictionRanking = ranking,
                    predictionDecisions = decisions,
                    predictionProbabilities = probabilities,
                    output = Vector.get(6, fields),
                    responseIds = ids
                })
        }
    })

def lines(payload: String): Vector[String] =
    String.splitOn(substr = "\n", payload)
    |> List.filter(line -> not String.isEmpty(line))
    |> List.toVector

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
