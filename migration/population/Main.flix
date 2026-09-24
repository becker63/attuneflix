// One-time admission of the frozen benchmark manifest into typed population
// tables. External JSON remains raw evidence; current science reads Parquet.
import java.lang.System

use Fs.FileSystem
use Util.Json
use Util.Json.Json.{JArray, JObject, JString}
use Util.Json.FromJson

def main(): Unit \ {FileSystem, IO} = {
    let payload = FileSystem.read(System.getProperty("attune.manifest"))
        |> Result.mapErr(ToString.toString) |> require;
    let frozen = parse(payload) |> require;
    let written = Population.Table.write(
        System.getProperty("attune.population_metadata"),
        System.getProperty("attune.population_cases"),
        Population.Table.rows(frozen));
    let admitted = Population.Table.frozen(written) |> require;
    let completed = Vector.count(case0 -> case0#outcome == Population.Outcome.Completed, admitted#cases);
    let censored = Vector.length(admitted#cases) - completed;
    if (completed != 76 or censored != 2) bug!("population outcome count changed")
    else println("POPULATION_MIGRATION cases=78 completed=76 censored=2 exact=true")
}

def parse(payload: String): Result[String, Population.Frozen] = match Json.parse(payload) {
    case Err(error) => Err(ToString.toString(error))
    case Ok(JObject(root)) => forM (
        version <- int("version", root);
        _ <- if (version == 1) Ok(()) else Err("unsupported manifest version");
        benchmark <- string("benchmark_revision", root);
        machine <- object("frozen_machine", root);
        routing <- object("source_dialect_routing", root);
        routingId <- string("identity", routing);
        sources <- object("source_artifacts", root);
        explore <- object("swe_explore", sources);
        multilingual <- object("swe_bench_multilingual", sources);
        pro <- object("swe_bench_pro", sources);
        exploreRevision <- string("revision", explore);
        _ <- if (exploreRevision == benchmark) Ok(()) else Err("benchmark revision mismatch");
        multilingualRevision <- string("revision", multilingual);
        proRevision <- string("revision", pro);
        depth <- int("max_depth", machine);
        centers <- int("center_count", machine);
        routes <- int("logical_non_root_routes", machine);
        symbols <- int("symbol_ending_routes", machine);
        values <- array("cases", root);
        indexed = Vector.mapWithIndex((ordinal, value) -> (ordinal, value), values);
        cases <- Vector.traverse(match (ordinal, value) -> decodeCase(ordinal, value), indexed);
        _ <- validate(cases)
    ) yield {
        protocol = {
            benchmarkRevision = benchmark,
            multilingualRevision = multilingualRevision,
            proRevision = proRevision,
            sourceRouting = routingId,
            atlasProtocol = "atlas-composition-depth7-v1",
            maxDepth = depth,
            centerCount = centers,
            logicalRoutes = routes,
            symbolRoutes = symbols
        },
        cases = cases
    }
    case Ok(_) => Err("manifest must be an object")
}

def decodeCase(ordinal: Int32, value: Json): Result[String, Population.Case] = match value {
    case JObject(row) => forM (
        instanceId <- string("instance_id", row);
        repository <- string("repository", row);
        revision <- string("base_revision", row);
        family <- string("dataset_family", row);
        language <- string("declared_benchmark_language", row);
        population <- string("population", row);
        split <- string("repository_group_split", row);
        routing <- string("source_dialect_routing", row);
        source <- string("source_identity", row)
    ) yield {
        ordinal = ordinal, instanceId = instanceId, repository = repository,
        baseRevision = revision, datasetFamily = family, language = language,
        population = population, split = split, sourceRouting = routing,
        sourceIdentity = source, outcome = outcome(instanceId)
    }
    case _ => Err("manifest case must be an object")
}

def outcome(instanceId: String): Population.Outcome =
    if (instanceId == "mrdoob__three.js-26589" or instanceId == "mrdoob__three.js-27395")
        Population.Outcome.Censored("frozen embedding input 40961 tokens exceeds provider limit 40960")
    else Population.Outcome.Completed

def validate(cases: Vector[Population.Case]): Result[String, Unit] = {
    let historical = Vector.count(case0 -> case0#split == "historical-development", cases);
    let optimization = Vector.count(case0 -> case0#split == "optimization-development", cases);
    let validation = Vector.count(case0 -> case0#split == "post-optimization-validation", cases);
    let distinct = Vector.map(case0 -> case0#instanceId, cases) |> Vector.toSet |> Set.size;
    if (Vector.length(cases) != 78) Err("manifest must contain 78 cases")
    else if (distinct != 78) Err("manifest case identities must be unique")
    else if (historical != 15 or optimization != 42 or validation != 21)
        Err("manifest population split changed")
    else Ok(())
}

def field(name: String, row: Map[String, Json]): Result[String, Json] =
    Map.get(name, row) |> Option.toOk("missing manifest field: ${name}")

def string(name: String, row: Map[String, Json]): Result[String, String] = match field(name, row) {
    case Ok(JString(value)) => Ok(value)
    case Ok(_) => Err("manifest ${name} must be text")
    case Err(error) => Err(error)
}

def int(name: String, row: Map[String, Json]): Result[String, Int32] =
    field(name, row) |> Result.flatMap(value -> FromJson.fromJson(value) |> Result.mapErr(ToString.toString))

def object(name: String, row: Map[String, Json]): Result[String, Map[String, Json]] = match field(name, row) {
    case Ok(JObject(value)) => Ok(value)
    case Ok(_) => Err("manifest ${name} must be an object")
    case Err(error) => Err(error)
}

def array(name: String, row: Map[String, Json]): Result[String, Vector[Json]] = match field(name, row) {
    case Ok(JArray(value)) => Ok(value)
    case Ok(_) => Err("manifest ${name} must be an array")
    case Err(error) => Err(error)
}

def require(result: Result[String, a]): a = match result {
    case Ok(value) => value
    case Err(error) => bug!(error)
}
