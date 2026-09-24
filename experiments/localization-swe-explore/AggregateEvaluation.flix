import java.lang.System

use Fs.FileSystem
use Util.Json.Json.{JBool, JString}
use Util.Json.FromJson

def main(): Unit \ {FileSystem, IO} = {
    let manifest = FileSystem.read(System.getProperty("attune.input_manifest"))
        |> Result.mapErr(ToString.toString) |> require;
    let inputs = String.splitOn(substr = "\n", manifest)
        |> List.filter(line -> not String.isEmpty(line))
        |> List.map(parseInput) |> List.sequence |> require |> List.toVector;
    let tables = load(inputs, 0, Nil, Nil, Nil, Nil);
    let metrics = List.reverse(tables#metrics) |> List.toVector |> Vector.flatten;
    let regions = List.reverse(tables#regions) |> List.toVector |> Vector.flatten;
    let telemetry = List.reverse(tables#telemetry) |> List.toVector |> Vector.flatten;
    let proofs = List.reverse(tables#proofs) |> List.toVector |> Vector.flatten;
    let totals = Vector.foldLeft(addTelemetry, {
        logical = 0i64, states = 0i64, projections = 0i64, scores = 0i64
    }, telemetry);
    let ids = Vector.traverse(validateProof, proofs) |> require |> Vector.toSet;
    if (Vector.length(inputs) != 61 or Vector.length(proofs) != 61 or Set.size(ids) != 61)
        bug!("official evaluation aggregate requires 61 unique parity proofs")
    else if (Vector.length(metrics) != 183 or Vector.length(telemetry) != 61)
        bug!("official evaluation aggregate row count mismatch")
    else {
        let admittedMetrics = ScientificTable.write(System.getProperty("attune.output_metrics"),
            Localization.EvaluationTable.metrics(), metrics);
        let admittedRegions = ScientificTable.write(System.getProperty("attune.output_regions"),
            Localization.EvaluationTable.regions(), regions);
        let admittedTelemetry = ScientificTable.write(System.getProperty("attune.output_telemetry"),
            Localization.EvaluationTable.telemetry(), telemetry);
        let admittedProofs = ScientificTable.write(System.getProperty("attune.output_proof"),
            Localization.EvaluationTable.proof(), proofs);
        if (Vector.length(admittedMetrics) != 183 or
            Vector.length(admittedTelemetry) != 61 or Vector.length(admittedProofs) != 61)
            bug!("official evaluation aggregate write/read mismatch")
        else println("LOCALIZATION_EVALUATION_AGGREGATE cases=61 metrics=183" +
            " regions=${Vector.length(admittedRegions)}" +
            " logical_routes=${totals#logical} unique_states=${totals#states}" +
            " unique_projections=${totals#projections} score_evaluations=${totals#scores}" +
            " parity=true")
    }
}

type alias Input = {metrics = String, regions = String, telemetry = String, proof = String}

type alias Tables = {
    metrics = List[Vector[ScientificTable.Row]],
    regions = List[Vector[ScientificTable.Row]],
    telemetry = List[Vector[ScientificTable.Row]],
    proofs = List[Vector[ScientificTable.Row]]
}

type alias TelemetryTotals = {
    logical = Int64, states = Int64, projections = Int64, scores = Int64
}

def addTelemetry(total: TelemetryTotals, row: ScientificTable.Row): TelemetryTotals = {
    logical = total#logical + int64("logical_routes", row),
    states = total#states + int64("unique_states", row),
    projections = total#projections + int64("unique_projections", row),
    scores = total#scores + int64("score_evaluations", row)
}

def int64(name: String, row: ScientificTable.Row): Int64 =
    Map.get(name, row) |> Option.toOk("missing telemetry value: ${name}")
    |> Result.flatMap(value -> FromJson.fromJson(value) |> Result.mapErr(ToString.toString))
    |> require

def parseInput(line: String): Result[String, Input] = {
    let fields = String.splitOn(substr = "\t", line) |> List.toVector;
    if (Vector.length(fields) != 4) Err("invalid official evaluation aggregate manifest row")
    else Ok({
        metrics = Vector.get(0, fields), regions = Vector.get(1, fields),
        telemetry = Vector.get(2, fields), proof = Vector.get(3, fields)
    })
}

def load(inputs: Vector[Input], index: Int32,
         metrics: List[Vector[ScientificTable.Row]], regions: List[Vector[ScientificTable.Row]],
         telemetry: List[Vector[ScientificTable.Row]], proofs: List[Vector[ScientificTable.Row]]
        ): Tables \ IO =
    if (index >= Vector.length(inputs)) {
        metrics = metrics, regions = regions, telemetry = telemetry, proofs = proofs
    } else {
        let input = Vector.get(index, inputs);
        load(inputs, index + 1,
            ScientificTable.read(input#metrics, Localization.EvaluationTable.metrics()) :: metrics,
            ScientificTable.read(input#regions, Localization.EvaluationTable.regions()) :: regions,
            ScientificTable.read(input#telemetry, Localization.EvaluationTable.telemetry()) :: telemetry,
            ScientificTable.read(input#proof, Localization.EvaluationTable.proof()) :: proofs)
    }

def validateProof(row: ScientificTable.Row): Result[String, String] =
    match (Map.get("protocol", row), Map.get("instance_id", row),
        Map.get("exact_discrete", row), Map.get("metrics_within_tolerance", row)) {
        case (Some(JString("attune-localization-evaluation-parity-v1")), Some(JString(instanceId)),
            Some(JBool(true)), Some(JBool(true))) => Ok(instanceId)
        case _ => Err("invalid official evaluation parity proof")
    }

def require(result: Result[String, a]): a = match result {
    case Ok(value) => value
    case Err(error) => bug!(error)
}
