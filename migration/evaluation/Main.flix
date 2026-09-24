import java.lang.System

use Fs.FileSystem
use Util.Json
use Util.Json.Json.{JArray, JObject, JString}
use Util.Json.FromJson

def main(): Unit \ {FileSystem, IO} = match System.getProperty("attune.command") {
    case "gold" => migrateGold()
    case "geometry" => migrateGeometry()
    case command => bug!("unknown evaluation migration command: ${command}")
}

def migrateGold(): Unit \ IO = {
    let payload = ScientificData.readObject(property("attune.legacy_gold"));
    let count = Localization.EvaluationData.writeGold(property("attune.output_gold"), payload)
        |> require;
    println("EVALUATION_GOLD_MIGRATION cases=${count} exact=true")
}

/// Local one-time source oracle. The emitted table contains no source text and
/// no Nix pathname; remote evaluator actions consume only this table.
def migrateGeometry(): Unit \ {FileSystem, IO} = {
    let oraclePayload = FileSystem.read(property("attune.oracle"))
        |> Result.mapErr(ToString.toString) |> require;
    let oracle = decodeOracle(oraclePayload) |> require;
    let identity = FileSystem.read(property("attune.world_identity"))
        |> Result.mapErr(ToString.toString)
        |> Result.flatMap(Repository.Identity.decode) |> require;
    if (identity#repository != oracle#repository or
        identity#baseRevision != oracle#baseRevision)
        bug!("evaluation geometry oracle/world identity mismatch")
    else {
        let world = Repository.Table.read(
            property("attune.world_metadata"), property("attune.world_entities"),
            property("attune.world_relations"), identity) |> require;
        let sources = Vector.map(path -> {
            let full = "${oracle#legacySnapshot}/${path}";
            let content = FileSystem.read(full) |> Result.mapErr(ToString.toString) |> require;
            {path = path, content = content}
        }, oracle#sourcePaths);
        let documents = Vector.mapWithIndex((ordinal, symbol) -> {
            ordinal = ordinal, path = symbol#path,
            startByte = symbol#startByte, endByte = symbol#endByte
        }, world#symbols);
        let geometry = Localization.EvaluationData.writeGeometry(
            property("attune.output_geometry"), oracle#instanceId, sources, documents)
            |> require;
        println("EVALUATION_GEOMETRY_MIGRATION case=${oracle#instanceId}" +
            " sources=${Map.size(geometry#counts)}" +
            " documents=${Vector.length(geometry#documentRegions)} exact=true")
    }
}

type alias Oracle = {
    instanceId     = String,
    repository     = String,
    baseRevision   = String,
    legacySnapshot = String,
    sourcePaths    = Vector[String]
}

def decodeOracle(payload: String): Result[String, Oracle] = match Json.parse(payload) {
    case Err(error) => Err(ToString.toString(error))
    case Ok(JObject(fields)) => forM (
        version <- intField("version", fields);
        _ <- if (version == 1) Ok(()) else Err("unsupported evaluation oracle");
        instanceId <- stringField("instance_id", fields);
        repository <- stringField("repository", fields);
        baseRevision <- stringField("base_revision", fields);
        legacySnapshot <- stringField("legacy_snapshot", fields);
        sourcePaths <- stringVectorField("source_paths", fields)
    ) yield {
        instanceId = instanceId, repository = repository,
        baseRevision = baseRevision, legacySnapshot = legacySnapshot,
        sourcePaths = sourcePaths
    }
    case Ok(_) => Err("evaluation oracle must be an object")
}

def property(name: String): String \ IO = System.getProperty(name)

def require(result: Result[String, a]): a = match result {
    case Ok(value) => value
    case Err(error) => bug!(error)
}

def field(name: String, fields: Map[String, Json]): Result[String, Json] =
    Map.get(name, fields) |> Option.toOk("missing oracle field: ${name}")

def stringField(name: String, fields: Map[String, Json]): Result[String, String] = match field(name, fields) {
    case Ok(JString(value)) => Ok(value)
    case Ok(_) => Err("${name}: expected string")
    case Err(error) => Err(error)
}

def intField(name: String, fields: Map[String, Json]): Result[String, Int32] =
    field(name, fields) |> Result.flatMap(value -> FromJson.fromJson(value)
        |> Result.mapErr(ToString.toString))

def stringVectorField(name: String, fields: Map[String, Json]): Result[String, Vector[String]] =
    match field(name, fields) {
        case Err(error) => Err(error)
        case Ok(JArray(values)) => Vector.traverse(match value -> match value {
            case JString(text) => Ok(text)
            case _ => Err("${name}: expected string elements")
        }, values)
        case Ok(_) => Err("${name}: expected array")
    }
