import java.lang.System

use Fs.FileSystem
use ScientificTable.Value

type alias Metric = {
    instanceId = String, repository = String, revision = String, snapshot = String,
    condition = String, precision = Float64, recall = Float64, f1 = Float64,
    context = Float64
}

type alias Telemetry = {
    instanceId = String, logical = Float64, states = Float64,
    projections = Float64, scores = Float64
}

type alias Summary = {
    snapshot = String, scope = String, domain = String,
    metric = String, value = Float64
}

type alias Physical = {
    snapshot = String, compression = Float64, requests = Float64, reuses = Float64
}

type alias Case = {
    instanceId = String, repository = String, revision = String, snapshot = String,
    priorF1 = Float64, selectedF1 = Float64, oracleF1 = Float64,
    selectedDelta = Float64, headroom = Float64, captured = Float64,
    capturedDefined = Bool, priorPrecision = Float64, selectedPrecision = Float64,
    precisionDelta = Float64, priorRecall = Float64, selectedRecall = Float64,
    recallDelta = Float64, priorContext = Float64, selectedContext = Float64,
    contextDelta = Float64, fileExtinction = Float64, symbolExtinction = Float64,
    fileReach = Float64, symbolReach = Float64, fileRecurrence = Float64,
    symbolRecurrence = Float64, physicalCompression = Float64, reuseFraction = Float64,
    logical = Float64, states = Float64, projections = Float64, scores = Float64,
    routeStateCompression = Float64, stateProjectionCompression = Float64
}

type alias RepositoryResult = {
    repository = String, cases = Int32, priorF1 = Float64, selectedF1 = Float64,
    oracleF1 = Float64, selectedDelta = Float64, headroom = Float64,
    contextDelta = Float64, regressions = Int32, fileExtinction = Float64,
    symbolExtinction = Float64, fileReach = Float64, symbolReach = Float64,
    fileRecurrence = Float64, symbolRecurrence = Float64,
    physicalCompression = Float64
}

def main(): Unit \ {FileSystem, IO} = {
    let metrics0 = ScientificTable.read(System.getProperty("attune.localization_metrics"),
        Localization.EvaluationTable.metrics());
    let telemetry0 = ScientificTable.read(System.getProperty("attune.localization_telemetry"),
        Localization.EvaluationTable.telemetry());
    let summaries0 = ScientificTable.read(System.getProperty("attune.atlas_summaries"),
        Atlas.Signature.Summary.schema());
    let physical0 = ScientificTable.read(System.getProperty("attune.atlas_physical"),
        Atlas.Signature.Table.physical());
    match Vector.traverse(decodeMetric, metrics0) |> Result.flatMap(metrics ->
        Vector.traverse(decodeTelemetry, telemetry0) |> Result.flatMap(telemetry ->
        Vector.traverse(decodeSummary, summaries0) |> Result.flatMap(summaries ->
        Vector.traverse(decodePhysical, physical0) |> Result.map(physical ->
            (metrics, telemetry, summaries, physical))))) {
        case Err(error) => bug!(error)
        case Ok((metrics, telemetry, summaries, physical)) => {
            let priorRows = Vector.filter(row -> row#condition == "prior", metrics);
            let cases = Vector.map(prior -> makeCase(prior, metrics, telemetry, summaries, physical), priorRows);
            let repositories = Vector.map(row -> row#repository, cases)
                |> Vector.toSet |> Set.toVector |> Vector.sort;
            let repositoryResults = Vector.map(repository -> repositoryResult(repository, cases), repositories);
            let written = ScientificTable.write(System.getProperty("attune.output_cases"),
                caseSchema(), Vector.map(caseRow, cases));
            if (Vector.length(cases) != 61 or Vector.length(written) != 61)
                bug!("post-hoc Atlas/localization analysis requires 61 completed cases")
            else match FileSystem.write(str = report(cases, repositoryResults),
                    System.getProperty("attune.output_report")) {
                case Err(error) => bug!(ToString.toString(error))
                case Ok(_) => println("ATLAS_LOCALIZATION_POSTHOC cases=61" +
                    " repositories=${Vector.length(repositoryResults)} frozen_inputs=true")
            }
        }
    }
}

def makeCase(prior: Metric, metrics: Vector[Metric], telemetry: Vector[Telemetry],
             summaries: Vector[Summary], physical: Vector[Physical]): Case = {
    let selected = condition(prior#instanceId, "iteration-013", metrics);
    let oracle = condition(prior#instanceId, "structural-oracle", metrics);
    let execution = Vector.find(row -> row#instanceId == prior#instanceId, telemetry)
        |> Option.getWithDefault({instanceId = prior#instanceId, logical = 0.0, states = 0.0,
            projections = 0.0, scores = 0.0});
    let snapshotPhysical = Vector.filter(row -> row#snapshot == prior#snapshot, physical);
    let requests = sum(snapshotPhysical, row -> row#requests);
    let reuses = sum(snapshotPhysical, row -> row#reuses);
    let headroom = oracle#f1 - prior#f1;
    {
        instanceId = prior#instanceId, repository = prior#repository, revision = prior#revision,
        snapshot = prior#snapshot, priorF1 = prior#f1, selectedF1 = selected#f1,
        oracleF1 = oracle#f1, selectedDelta = selected#f1 - prior#f1, headroom = headroom,
        captured = if (headroom == 0.0) 0.0 else (selected#f1 - prior#f1) / headroom,
        capturedDefined = headroom != 0.0,
        priorPrecision = prior#precision, selectedPrecision = selected#precision,
        precisionDelta = selected#precision - prior#precision,
        priorRecall = prior#recall, selectedRecall = selected#recall,
        recallDelta = selected#recall - prior#recall,
        priorContext = prior#context, selectedContext = selected#context,
        contextDelta = selected#context - prior#context,
        fileExtinction = domainMetric(prior#snapshot, "file", "extinct_fraction", summaries),
        symbolExtinction = domainMetric(prior#snapshot, "symbol", "extinct_fraction", summaries),
        fileReach = domainMetric(prior#snapshot, "file", "reach_fraction_p90", summaries),
        symbolReach = domainMetric(prior#snapshot, "symbol", "reach_fraction_p90", summaries),
        fileRecurrence = domainMetric(prior#snapshot, "file", "logical_per_unique_state", summaries),
        symbolRecurrence = domainMetric(prior#snapshot, "symbol", "logical_per_unique_state", summaries),
        physicalCompression = median(Vector.map(row -> row#compression, snapshotPhysical)),
        reuseFraction = if (requests == 0.0) 0.0 else reuses / requests,
        logical = execution#logical, states = execution#states,
        projections = execution#projections, scores = execution#scores,
        routeStateCompression = ratio(execution#logical, execution#states),
        stateProjectionCompression = ratio(execution#states, execution#projections)
    }
}

def condition(instanceId: String, name: String, rows: Vector[Metric]): Metric =
    match Vector.find(row -> row#instanceId == instanceId and row#condition == name, rows) {
        case Some(row) => row
        case None => bug!("missing localization condition ${name}: ${instanceId}")
    }

def domainMetric(snapshot: String, domain: String, name: String,
                 rows: Vector[Summary]): Float64 =
    Vector.find(row -> row#snapshot == snapshot and row#scope == "seed_domain" and
        row#domain == domain and row#metric == name, rows)
    |> Option.map(row -> row#value) |> Option.getWithDefault(0.0)

def repositoryResult(repository: String, rows: Vector[Case]): RepositoryResult = {
    let selected = Vector.filter(row -> row#repository == repository, rows);
    {
        repository = repository, cases = Vector.length(selected),
        priorF1 = mean(selected, row -> row#priorF1),
        selectedF1 = mean(selected, row -> row#selectedF1),
        oracleF1 = mean(selected, row -> row#oracleF1),
        selectedDelta = mean(selected, row -> row#selectedDelta),
        headroom = mean(selected, row -> row#headroom),
        contextDelta = mean(selected, row -> row#contextDelta),
        regressions = Vector.count(row -> row#selectedDelta < 0.0, selected),
        fileExtinction = median(Vector.map(row -> row#fileExtinction, selected)),
        symbolExtinction = median(Vector.map(row -> row#symbolExtinction, selected)),
        fileReach = median(Vector.map(row -> row#fileReach, selected)),
        symbolReach = median(Vector.map(row -> row#symbolReach, selected)),
        fileRecurrence = median(Vector.map(row -> row#fileRecurrence, selected)),
        symbolRecurrence = median(Vector.map(row -> row#symbolRecurrence, selected)),
        physicalCompression = median(Vector.map(row -> row#physicalCompression, selected))
    }
}

def report(cases: Vector[Case], repositories: Vector[RepositoryResult]): String =
    "# Atlas geometry and localization regime\n\n" +
    "This is a deterministic **post-hoc** join of two experiments that were sealed first: " +
    "the issue-blind Atlas census and the official 61-case SWE-Explore localization result. " +
    "It did not change the frozen prior, iteration-013 policy, Atlas protocol, or either result.\n\n" +
    "The snapshot is the join key. Every completed localization case has exactly one frozen " +
    "Atlas signature for the same repository revision and admitted fact identity. The 61 cases " +
    "cover seven repositories, so snapshot-level correlations are descriptive and are not 61 " +
    "independent repository experiments.\n\n" +
    "## Repository regimes\n\n" +
    "`013 delta` is iteration-013 F1 minus the untouched prior. `Headroom` is the structural " +
    "oracle F1 minus prior F1. Extinction, reach, and recurrence are issue-blind Atlas signature " +
    "medians for File/Symbol seeds.\n\n" +
    "| Repository | Cases | Prior F1 | 013 F1 | Oracle F1 | 013 delta | Headroom | Context delta | Regressions | Extinction F/S | Reach F/S | Recurrence F/S | Physical compression |\n" +
    "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n" +
    (Vector.map(repositoryLine, repositories) |> Vector.join("\n")) + "\n\n" +
    "## Snapshot-level relationships\n\n" +
    "Each value is a Pearson correlation over the 61 exact snapshot/case joins. Positive means " +
    "the outcome tends to rise with the signature feature; negative means it tends to fall. " +
    "These measurements locate follow-up questions. They do not establish cause, and the repeated " +
    "revisions from the same repositories make naive significance claims inappropriate.\n\n" +
    correlationTable(cases) + "\n" +
    "## Localization-side recurrence\n\n" +
    "The official oracle evaluator considered ${sum(cases, row -> row#logical)} logical routes, " +
    "${sum(cases, row -> row#states)} unique semantic states, " +
    "${sum(cases, row -> row#projections)} unique top-five projections, and performed " +
    "${sum(cases, row -> row#scores)} official score evaluations. Mean route/state compression " +
    "was ${mean(cases, row -> row#routeStateCompression)}x; mean state/projection compression " +
    "was ${mean(cases, row -> row#stateProjectionCompression)}x. These are application-side " +
    "counts and remain separate from the issue-blind Atlas signature.\n\n" +
    "## Limits\n\n" +
    "This analysis uses the completed 61-case JS/TS subset. The two Three.js localization censors " +
    "remain absent because no frozen prediction/evaluation exists for them, even though their " +
    "issue-blind Atlas signatures exist. The result is exploratory, not a retuning dataset for " +
    "iteration 013. A future claim about prediction should be preregistered and tested on new " +
    "repositories.\n"

def repositoryLine(row: RepositoryResult): String =
    "| ${row#repository} | ${row#cases} | ${row#priorF1} | ${row#selectedF1} | " +
    "${row#oracleF1} | ${row#selectedDelta} | ${row#headroom} | ${row#contextDelta} | " +
    "${row#regressions} | ${row#fileExtinction} / ${row#symbolExtinction} | " +
    "${row#fileReach} / ${row#symbolReach} | ${row#fileRecurrence} / " +
    "${row#symbolRecurrence} | ${row#physicalCompression} |"

def correlationTable(rows: Vector[Case]): String = {
    let features = Vector#{
        ("File extinction", row -> row#fileExtinction),
        ("Symbol extinction", row -> row#symbolExtinction),
        ("File reach p90", row -> row#fileReach),
        ("Symbol reach p90", row -> row#symbolReach),
        ("File recurrence", row -> row#fileRecurrence),
        ("Symbol recurrence", row -> row#symbolRecurrence),
        ("Physical compression", row -> row#physicalCompression),
        ("Physical reuse", row -> row#reuseFraction)
    };
    "| Signature feature | Prior F1 | 013 delta | Oracle headroom | Context-efficiency delta |\n" +
    "| --- | ---: | ---: | ---: | ---: |\n" +
    (Vector.map(match (name, feature) ->
        "| ${name} | ${correlation(rows, feature, row -> row#priorF1)} | " +
        "${correlation(rows, feature, row -> row#selectedDelta)} | " +
        "${correlation(rows, feature, row -> row#headroom)} | " +
        "${correlation(rows, feature, row -> row#contextDelta)} |", features)
        |> Vector.join("\n")) + "\n"
}

def correlation(rows: Vector[Case], x: Case -> Float64, y: Case -> Float64): Float64 =
    pearson(Vector.map(x, rows), Vector.map(y, rows))

def pearson(xs: Vector[Float64], ys: Vector[Float64]): Float64 = {
    let mx = meanValues(xs); let my = meanValues(ys);
    let numerator = Vector.zip(xs, ys) |> Vector.foldLeft((total, pair) -> {
        let (x, y) = pair; total + (x - mx) * (y - my)
    }, 0.0);
    let dx = Vector.foldLeft((total, x) -> total + (x - mx) * (x - mx), 0.0, xs);
    let dy = Vector.foldLeft((total, y) -> total + (y - my) * (y - my), 0.0, ys);
    if (dx == 0.0 or dy == 0.0) 0.0 else numerator / squareRoot(dx * dy)
}

def squareRoot(value: Float64): Float64 =
    if (value <= 0.0) 0.0 else squareRootFrom(value, value, 0)

def squareRootFrom(value: Float64, estimate: Float64, iteration: Int32): Float64 =
    if (iteration >= 32) estimate
    else squareRootFrom(value, (estimate + value / estimate) / 2.0, iteration + 1)

def caseSchema(): ScientificTable.Schema = {
    format = "attune-atlas-localization-posthoc-v1",
    columns = Vector#{
        text("protocol"), text("instance_id"), text("repository"), text("base_revision"),
        text("snapshot_id"), float64("prior_f1"), float64("iteration_013_f1"),
        float64("structural_oracle_f1"), float64("iteration_013_delta"),
        float64("oracle_headroom"), float64("captured_headroom"), boolean("captured_headroom_defined"),
        float64("prior_precision"), float64("iteration_013_precision"), float64("precision_delta"),
        float64("prior_recall"), float64("iteration_013_recall"), float64("recall_delta"),
        float64("prior_context_efficiency"), float64("iteration_013_context_efficiency"),
        float64("context_efficiency_delta"), float64("file_extinction"),
        float64("symbol_extinction"), float64("file_reach_p90"), float64("symbol_reach_p90"),
        float64("file_recurrence"), float64("symbol_recurrence"),
        float64("physical_compression"), float64("physical_reuse_fraction"),
        float64("localization_logical_routes"), float64("localization_unique_states"),
        float64("localization_unique_projections"), float64("localization_score_evaluations"),
        float64("localization_route_state_compression"),
        float64("localization_state_projection_compression")
    }
}

def caseRow(row: Case): ScientificTable.Row = Map#{
    "protocol" => Value.Text("attune-atlas-localization-posthoc-v1"),
    "instance_id" => Value.Text(row#instanceId), "repository" => Value.Text(row#repository),
    "base_revision" => Value.Text(row#revision), "snapshot_id" => Value.Text(row#snapshot),
    "prior_f1" => Value.Float64(row#priorF1), "iteration_013_f1" => Value.Float64(row#selectedF1),
    "structural_oracle_f1" => Value.Float64(row#oracleF1),
    "iteration_013_delta" => Value.Float64(row#selectedDelta),
    "oracle_headroom" => Value.Float64(row#headroom),
    "captured_headroom" => Value.Float64(row#captured),
    "captured_headroom_defined" => Value.Boolean(row#capturedDefined),
    "prior_precision" => Value.Float64(row#priorPrecision),
    "iteration_013_precision" => Value.Float64(row#selectedPrecision),
    "precision_delta" => Value.Float64(row#precisionDelta),
    "prior_recall" => Value.Float64(row#priorRecall),
    "iteration_013_recall" => Value.Float64(row#selectedRecall),
    "recall_delta" => Value.Float64(row#recallDelta),
    "prior_context_efficiency" => Value.Float64(row#priorContext),
    "iteration_013_context_efficiency" => Value.Float64(row#selectedContext),
    "context_efficiency_delta" => Value.Float64(row#contextDelta),
    "file_extinction" => Value.Float64(row#fileExtinction),
    "symbol_extinction" => Value.Float64(row#symbolExtinction),
    "file_reach_p90" => Value.Float64(row#fileReach),
    "symbol_reach_p90" => Value.Float64(row#symbolReach),
    "file_recurrence" => Value.Float64(row#fileRecurrence),
    "symbol_recurrence" => Value.Float64(row#symbolRecurrence),
    "physical_compression" => Value.Float64(row#physicalCompression),
    "physical_reuse_fraction" => Value.Float64(row#reuseFraction),
    "localization_logical_routes" => Value.Float64(row#logical),
    "localization_unique_states" => Value.Float64(row#states),
    "localization_unique_projections" => Value.Float64(row#projections),
    "localization_score_evaluations" => Value.Float64(row#scores),
    "localization_route_state_compression" => Value.Float64(row#routeStateCompression),
    "localization_state_projection_compression" => Value.Float64(row#stateProjectionCompression)
}

def decodeMetric(row: ScientificTable.Row): Result[String, Metric] = forM (
    instanceId <- string("instance_id", row); repository <- string("repository", row);
    revision <- string("base_revision", row); snapshot <- string("snapshot_id", row);
    condition0 <- string("condition", row); precision <- number("precision", row);
    recall <- number("recall", row); f1 <- number("f1_score", row);
    context <- number("context_efficiency", row)
) yield {instanceId = instanceId, repository = repository, revision = revision, snapshot = snapshot,
    condition = condition0, precision = precision, recall = recall, f1 = f1, context = context}

def decodeTelemetry(row: ScientificTable.Row): Result[String, Telemetry] = forM (
    instanceId <- string("instance_id", row); logical <- number("logical_routes", row);
    states <- number("unique_states", row); projections <- number("unique_projections", row);
    scores <- number("score_evaluations", row)
) yield {instanceId = instanceId, logical = logical, states = states, projections = projections, scores = scores}

def decodeSummary(row: ScientificTable.Row): Result[String, Summary] = forM (
    snapshot <- string("snapshot_id", row); scope <- string("scope", row);
    domain <- string("seed_domain", row); metric0 <- string("metric", row);
    value <- number("value", row)
) yield {snapshot = snapshot, scope = scope, domain = domain, metric = metric0, value = value}

def decodePhysical(row: ScientificTable.Row): Result[String, Physical] = forM (
    snapshot <- string("snapshot_id", row);
    compression <- number("logical_per_physical_evaluation", row);
    requests <- number("physical_transition_requests", row);
    reuses <- number("physical_transition_reuses", row)
) yield {snapshot = snapshot, compression = compression, requests = requests, reuses = reuses}

def string(name: String, row: ScientificTable.Row): Result[String, String] = ScientificTable.text(row, name)

def number(name: String, row: ScientificTable.Row): Result[String, Float64] = ScientificTable.number(row, name)

def sum[a: Type](rows: Vector[a], accessor: a -> Float64): Float64 =
    Vector.foldLeft((total, row) -> total + accessor(row), 0.0, rows)

def mean[a: Type](rows: Vector[a], accessor: a -> Float64): Float64 =
    if (Vector.isEmpty(rows)) 0.0 else sum(rows, accessor) / Int32.toFloat64(Vector.length(rows))

def meanValues(values: Vector[Float64]): Float64 =
    if (Vector.isEmpty(values)) 0.0
    else Vector.foldLeft((total, value) -> total + value, 0.0, values) /
        Int32.toFloat64(Vector.length(values))

def median(values: Vector[Float64]): Float64 = {
    let sorted = Vector.sort(values);
    if (Vector.isEmpty(sorted)) 0.0 else Vector.get((Vector.length(sorted) - 1) / 2, sorted)
}

def ratio(numerator: Float64, denominator: Float64): Float64 =
    if (denominator == 0.0) 0.0 else numerator / denominator

def text(name: String): ScientificTable.Column =
    {name = name, kind = ScientificTable.ColumnType.Text, nullable = false}

def float64(name: String): ScientificTable.Column =
    {name = name, kind = ScientificTable.ColumnType.Float64, nullable = false}

def boolean(name: String): ScientificTable.Column =
    {name = name, kind = ScientificTable.ColumnType.Boolean, nullable = false}
