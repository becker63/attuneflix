use ScientificTable.Value

def main(): Unit \ IO = {
    let metricPaths = Experiment.paths("attune.input_metrics");
    let regionPaths = Experiment.paths("attune.input_regions");
    let telemetryPaths = Experiment.paths("attune.input_telemetry");
    let proofPaths = Experiment.paths("attune.input_proofs");
    if (not sameLength(metricPaths, regionPaths, telemetryPaths, proofPaths))
        bug!("official evaluation aggregate input lists differ in length")
    else {
    let tables = load(metricPaths, regionPaths, telemetryPaths, proofPaths, 0, Nil, Nil, Nil, Nil);
    let metrics = List.reverse(tables#metrics) |> List.toVector |> Vector.flatten;
    let regions = List.reverse(tables#regions) |> List.toVector |> Vector.flatten;
    let telemetry = List.reverse(tables#telemetry) |> List.toVector |> Vector.flatten;
    let proofs = List.reverse(tables#proofs) |> List.toVector |> Vector.flatten;
    let totals = Vector.foldLeft(addTelemetry, {
        logical = 0i64, states = 0i64, projections = 0i64, scores = 0i64
    }, telemetry);
    let ids = Vector.traverse(validateProof, proofs) |> require |> Vector.toSet;
    if (Vector.length(metricPaths) != 61 or Vector.length(proofs) != 61 or Set.size(ids) != 61)
        bug!("official evaluation aggregate requires 61 unique parity proofs")
    else if (Vector.length(metrics) != 183 or Vector.length(telemetry) != 61)
        bug!("official evaluation aggregate row count mismatch")
    else {
        let admittedMetrics = ScientificTable.write(Experiment.property("attune.output_metrics"),
            Localization.EvaluationTable.metrics(), metrics);
        let admittedRegions = ScientificTable.write(Experiment.property("attune.output_regions"),
            Localization.EvaluationTable.regions(), regions);
        let admittedTelemetry = ScientificTable.write(Experiment.property("attune.output_telemetry"),
            Localization.EvaluationTable.telemetry(), telemetry);
        let admittedProofs = ScientificTable.write(Experiment.property("attune.output_proof"),
            Localization.EvaluationTable.proof(), proofs);
        if (Vector.length(admittedMetrics) != 183 or
            Vector.length(admittedTelemetry) != 61 or Vector.length(admittedProofs) != 61)
            bug!("official evaluation aggregate write/read mismatch")
        else println("LOCALIZATION_EVALUATION_AGGREGATE cases=61 metrics=183" +
            " regions=${Vector.length(admittedRegions)}" +
            " logical_routes=${totals#logical} unique_states=${totals#states}" +
            " unique_projections=${totals#projections} score_evaluations=${totals#scores}" +
            " parity=true")
    }}
}

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
    ScientificTable.int32(row, name) |> Result.map(Int32.toInt64) |> require

def sameLength(a: Vector[String], b: Vector[String], c: Vector[String], d: Vector[String]): Bool =
    Vector.length(a) == Vector.length(b) and Vector.length(a) == Vector.length(c) and
    Vector.length(a) == Vector.length(d)

def load(metricPaths: Vector[String], regionPaths: Vector[String], telemetryPaths: Vector[String],
         proofPaths: Vector[String], index: Int32,
         metrics: List[Vector[ScientificTable.Row]], regions: List[Vector[ScientificTable.Row]],
         telemetry: List[Vector[ScientificTable.Row]], proofs: List[Vector[ScientificTable.Row]]
        ): Tables \ IO =
    if (index >= Vector.length(metricPaths)) {
        metrics = metrics, regions = regions, telemetry = telemetry, proofs = proofs
    } else {
        load(metricPaths, regionPaths, telemetryPaths, proofPaths, index + 1,
            ScientificTable.read(Vector.get(index, metricPaths), Localization.EvaluationTable.metrics()) :: metrics,
            ScientificTable.read(Vector.get(index, regionPaths), Localization.EvaluationTable.regions()) :: regions,
            ScientificTable.read(Vector.get(index, telemetryPaths), Localization.EvaluationTable.telemetry()) :: telemetry,
            ScientificTable.read(Vector.get(index, proofPaths), Localization.EvaluationTable.proof()) :: proofs)
    }

def validateProof(row: ScientificTable.Row): Result[String, String] =
    match (Map.get("protocol", row), Map.get("instance_id", row),
        Map.get("exact_discrete", row), Map.get("metrics_within_tolerance", row)) {
        case (Some(Value.Text("attune-localization-evaluation-parity-v1")), Some(Value.Text(instanceId)),
            Some(Value.Boolean(true)), Some(Value.Boolean(true))) => Ok(instanceId)
        case _ => Err("invalid official evaluation parity proof")
    }

def require(result: Result[String, a]): a = match result {
    case Ok(value) => value
    case Err(error) => bug!(error)
}
