// One-time projection of repository-wide raw paid decision evidence into
// small typed per-case bundles. The provider envelopes remain authoritative;
// this migration only removes unrelated observations from each replay input.
import java.lang.System

use Fs.FileSystem
use Util.Json
use Util.Json.Json.{JArray, JObject, JString}
use Util.Json.FromJson

type alias CaseInput = {
    key = String,
    baseRevision = String,
    prediction = String,
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
        if (Vector.length(fields) != 4) Err("invalid localization migration case row")
        else {
            let prediction = Vector.get(2, fields);
            let payload0 = ScientificData.readObject(prediction);
            predictionResponseIds(payload0)
                |> Result.map(ids -> {
                    key = Vector.get(0, fields),
                    baseRevision = Vector.get(1, fields),
                    prediction = prediction,
                    output = Vector.get(3, fields),
                    responseIds = ids
                })
        }
    })

def lines(payload: String): Vector[String] =
    String.splitOn(substr = "\n", payload)
    |> List.filter(line -> not String.isEmpty(line))
    |> List.toVector

def predictionResponseIds(payload: String): Result[String, Set[String]] =
    match Json.parse(payload) {
        case Err(error) => Err(ToString.toString(error))
        case Ok(JObject(fields)) => forM (
            version <- integer("version", fields);
            _ <- if (version == 1) Ok(()) else Err("unsupported localization result version");
            decisions <- array("decisions", fields);
            ids <- Vector.traverse(value -> match value {
                case JObject(decision) => string("response_id", decision)
                case _ => Err("localization decision must be an object")
            }, decisions)
        ) yield Vector.toSet(ids)
        case Ok(_) => Err("localization result must be an object")
    }

def string(name: String, fields: Map[String, Json]): Result[String, String] =
    match Map.get(name, fields) {
        case Some(JString(value)) => Ok(value)
        case Some(_) => Err("${name} must be text")
        case None => Err("missing ${name}")
    }

def integer(name: String, fields: Map[String, Json]): Result[String, Int32] =
    match Map.get(name, fields) {
        case Some(value) => FromJson.fromJson(value) |> Result.mapErr(ToString.toString)
        case None => Err("missing ${name}")
    }

def array(name: String, fields: Map[String, Json]): Result[String, Vector[Json]] =
    match Map.get(name, fields) {
        case Some(JArray(values)) => Ok(values)
        case Some(_) => Err("${name} must be an array")
        case None => Err("missing ${name}")
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
