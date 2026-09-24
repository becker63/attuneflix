import java.lang.System

use Fs.FileSystem
use Util.Json.Json.{JString}
use Util.Json.FromJson
use Util.Json.ToJson

type alias Summary = {
    repository = String, snapshot = String, scope = String, domain = String,
    depth = Option[Int32], atom = Option[String], metric = String, value = Float64
}

type alias Snapshot = {
    repository = String, revision = String, snapshot = String,
    files = Float64, symbols = Float64
}

type alias Physical = {
    repository = String, snapshot = String, logicalPerEvaluation = Float64,
    requests = Float64, reuses = Float64
}

type alias Feature = {
    snapshot = String, files = Float64, symbols = Float64,
    fileExtinction = Float64, symbolExtinction = Float64,
    fileReach = Float64, symbolReach = Float64,
    fileRecurrence = Float64, symbolRecurrence = Float64,
    importAsymmetry = Float64, callAsymmetry = Float64,
    physicalCompression = Float64, reuseFraction = Float64
}

type alias RepositoryResult = {
    repository = String, snapshots = Int32, files = Float64, symbols = Float64,
    fileExtinction = Float64, symbolExtinction = Float64,
    fileReach = Float64, symbolReach = Float64,
    fileRecurrence = Float64, symbolRecurrence = Float64,
    importAsymmetry = Float64, callAsymmetry = Float64,
    physicalCompression = Float64, reuseFraction = Float64,
    driftMean = Float64, driftMax = Float64
}

def main(): Unit \ {FileSystem, IO} = {
    let summaries0 = ScientificTable.read(System.getProperty("attune.input_summaries"),
        Atlas.Signature.Summary.schema());
    let snapshots0 = ScientificTable.read(System.getProperty("attune.input_snapshots"),
        Atlas.Signature.Table.snapshots());
    let physical0 = ScientificTable.read(System.getProperty("attune.input_physical"),
        Atlas.Signature.Table.physical());
    match Vector.traverse(decodeSummary, summaries0) |> Result.flatMap(summaries ->
        Vector.traverse(decodeSnapshot, snapshots0) |> Result.flatMap(snapshots ->
        Vector.traverse(decodePhysical, physical0) |> Result.map(physical ->
            (summaries, snapshots, physical)))) {
        case Err(error) => bug!(error)
        case Ok((summaries, snapshots, physical)) => {
            let features = Vector.map(snapshot -> feature(snapshot, summaries, physical), snapshots);
            let repositories = Vector.map(row -> row#repository, snapshots)
                |> Vector.toSet |> Set.toVector |> Vector.sort;
            let results = Vector.map(repository -> repositoryResult(repository, snapshots, features), repositories);
            let written = ScientificTable.write(System.getProperty("attune.output_repository_summaries"),
                repositorySchema(), Vector.map(repositoryRow, results));
            let report0 = report(summaries, snapshots, physical, features, results);
            match FileSystem.write(str = report0, System.getProperty("attune.output_report")) {
                case Err(error) => bug!(ToString.toString(error))
                case Ok(_) => println("ATLAS_REPORT snapshots=${Vector.length(snapshots)}" +
                    " repositories=${Vector.length(written)}" +
                    " summary_rows=${Vector.length(summaries)}")
            }
        }
    }
}

def feature(snapshot: Snapshot, summaries: Vector[Summary], physical: Vector[Physical]): Feature = {
    let snapshotPhysical = Vector.filter(row -> row#snapshot == snapshot#snapshot, physical);
    let requests = sum(snapshotPhysical, row -> row#requests);
    let reuses = sum(snapshotPhysical, row -> row#reuses);
    {
        snapshot = snapshot#snapshot, files = snapshot#files, symbols = snapshot#symbols,
        fileExtinction = domainMetric(snapshot#snapshot, "file", "extinct_fraction", summaries),
        symbolExtinction = domainMetric(snapshot#snapshot, "symbol", "extinct_fraction", summaries),
        fileReach = domainMetric(snapshot#snapshot, "file", "reach_fraction_p90", summaries),
        symbolReach = domainMetric(snapshot#snapshot, "symbol", "reach_fraction_p90", summaries),
        fileRecurrence = domainMetric(snapshot#snapshot, "file", "logical_per_unique_state", summaries),
        symbolRecurrence = domainMetric(snapshot#snapshot, "symbol", "logical_per_unique_state", summaries),
        importAsymmetry = directionMetric(snapshot#snapshot, "imported_by", summaries) -
            directionMetric(snapshot#snapshot, "imports", summaries),
        callAsymmetry = directionMetric(snapshot#snapshot, "callers", summaries) -
            directionMetric(snapshot#snapshot, "calls", summaries),
        physicalCompression = median(Vector.map(row -> row#logicalPerEvaluation, snapshotPhysical)),
        reuseFraction = if (requests == 0.0) 0.0 else reuses / requests
    }
}

def repositoryResult(repository: String, snapshots: Vector[Snapshot], features: Vector[Feature]): RepositoryResult = {
    let ids = Vector.filter(row -> row#repository == repository, snapshots)
        |> Vector.map(row -> row#snapshot) |> Vector.toSet;
    let selected = Vector.filter(row -> Set.memberOf(row#snapshot, ids), features);
    let ranges = featureRanges(selected);
    {
        repository = repository, snapshots = Vector.length(selected),
        files = middle(selected, row -> row#files), symbols = middle(selected, row -> row#symbols),
        fileExtinction = middle(selected, row -> row#fileExtinction),
        symbolExtinction = middle(selected, row -> row#symbolExtinction),
        fileReach = middle(selected, row -> row#fileReach),
        symbolReach = middle(selected, row -> row#symbolReach),
        fileRecurrence = middle(selected, row -> row#fileRecurrence),
        symbolRecurrence = middle(selected, row -> row#symbolRecurrence),
        importAsymmetry = middle(selected, row -> row#importAsymmetry),
        callAsymmetry = middle(selected, row -> row#callAsymmetry),
        physicalCompression = middle(selected, row -> row#physicalCompression),
        reuseFraction = middle(selected, row -> row#reuseFraction),
        driftMean = meanValues(ranges), driftMax = maximum(ranges)
    }
}

def featureRanges(values: Vector[Feature]): Vector[Float64] = Vector#{
    relativeRange(values, row -> row#fileExtinction),
    relativeRange(values, row -> row#symbolExtinction),
    relativeRange(values, row -> row#fileReach),
    relativeRange(values, row -> row#symbolReach),
    relativeRange(values, row -> row#fileRecurrence),
    relativeRange(values, row -> row#symbolRecurrence),
    relativeRange(values, row -> row#importAsymmetry),
    relativeRange(values, row -> row#callAsymmetry),
    relativeRange(values, row -> row#physicalCompression),
    relativeRange(values, row -> row#reuseFraction)
}

def domainMetric(snapshot: String, domain: String, metric0: String, summaries: Vector[Summary]): Float64 =
    Vector.find(row -> row#snapshot == snapshot and row#scope == "seed_domain" and
        row#domain == domain and row#metric == metric0, summaries)
    |> Option.map(row -> row#value) |> Option.getWithDefault(0.0)

def directionMetric(snapshot: String, atom: String, summaries: Vector[Summary]): Float64 =
    Vector.filter(row -> row#snapshot == snapshot and row#scope == "seed_domain_depth_direction" and
        row#depth == Some(7) and row#atom == Some(atom) and row#metric == "reach_fraction_p90", summaries)
    |> Vector.map(row -> row#value) |> median

def report(summaries: Vector[Summary], snapshots: Vector[Snapshot], physical: Vector[Physical],
           features: Vector[Feature], repositories: Vector[RepositoryResult]): String = {
    let logical = sum(summaries, row -> if (row#scope == "seed_domain" and
        row#metric == "observation_count") row#value else 0.0);
    "# Frozen SWE-Explore Atlas census\n\n" +
    "This is the first issue-blind census under `atlas-signature-swe-explore-v1` and " +
    "`atlas-composition-depth7-v1`. It uses no issue text, embeddings, Jev, evaluator gold, " +
    "or provider calls. The unit is a frozen repository snapshot.\n\n" +
    "```text\nmanifest cases       ${Vector.length(snapshots)}\n" +
    "unique snapshots     ${Vector.length(snapshots)}\n" +
    "repositories         ${Vector.length(repositories)}\n" +
    "seed executions      ${Vector.length(physical)}\n" +
    "logical observations ${logical}\n" +
    "summary rows         ${Vector.length(summaries)}\n```\n\n" +
    "## Repository view\n\n" +
    "Every value below is a median across represented snapshots. `Import asym.` is depth-seven " +
    "`imported_by - imports` p90 reach; `call asym.` is `callers - calls`. Positive values mean " +
    "the reverse direction reaches farther. Recurrence is logical observations per unique exact " +
    "state. Physical compression is logical programs per actual relation evaluation.\n\n" +
    "| Repository | Snaps | Files | Symbols | Extinct F/S | Reach p90 F/S | Recurrence F/S | Import asym. | Call asym. | Physical compression | Reuse |\n" +
    "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n" +
    (Vector.map(repositoryLine, repositories) |> Vector.join("\n")) + "\n\n" +
    "## Strongest cross-repository differences\n\n" + differences(repositories) + "\n" +
    "## Within-repository stability\n\n" +
    "The final columns summarize the scale-normalized range of ten signature features across each " +
    "repository's represented revisions. Bounded fraction/asymmetry dimensions retain their absolute " +
    "range; recurrence and physical-compression ranges are divided by their median scale. A " +
    "single-snapshot repository has zero measurable drift.\n\n" +
    "| Repository | Snapshots | Mean feature range | Largest feature range |\n" +
    "| --- | ---: | ---: | ---: |\n" +
    (Vector.map(row -> "| ${row#repository} | ${row#snapshots} | ${row#driftMean} | ${row#driftMax} |", repositories)
        |> Vector.join("\n")) + "\n\n" +
    "## Size confounding\n\n" +
    "These are snapshot-level Pearson correlations. They are a direct confounding check, not a " +
    "causal model. Strong normalized differences that remain weakly correlated with domain size " +
    "cannot be explained by repository size alone.\n\n" +
    "| Size / normalized feature | Correlation |\n| --- | ---: |\n" +
    correlationLine("file count / file extinction", features, row -> row#files, row -> row#fileExtinction) +
    correlationLine("file count / file reach p90", features, row -> row#files, row -> row#fileReach) +
    correlationLine("file count / file recurrence", features, row -> row#files, row -> row#fileRecurrence) +
    correlationLine("symbol count / symbol extinction", features, row -> row#symbols, row -> row#symbolExtinction) +
    correlationLine("symbol count / symbol reach p90", features, row -> row#symbols, row -> row#symbolReach) +
    correlationLine("symbol count / symbol recurrence", features, row -> row#symbols, row -> row#symbolRecurrence) +
    "\n## Interpretation limits\n\n" +
    "This table describes repository response to one fixed six-atom language and sixteen " +
    "deterministic singleton seeds. It does not rank repository quality, identify authors, or " +
    "establish a localization cause. Localization relationships are intentionally deferred until " +
    "the two sealed datasets are joined as a separately labelled post-hoc analysis.\n"
}

def repositoryLine(row: RepositoryResult): String =
    "| ${row#repository} | ${row#snapshots} | ${row#files} | ${row#symbols} | " +
    "${row#fileExtinction} / ${row#symbolExtinction} | ${row#fileReach} / ${row#symbolReach} | " +
    "${row#fileRecurrence} / ${row#symbolRecurrence} | ${row#importAsymmetry} | " +
    "${row#callAsymmetry} | ${row#physicalCompression} | ${row#reuseFraction} |"

def differences(rows: Vector[RepositoryResult]): String = {
    let dimensions = Vector#{
        ("file extinction", row -> row#fileExtinction),
        ("symbol extinction", row -> row#symbolExtinction),
        ("file p90 reach", row -> row#fileReach),
        ("symbol p90 reach", row -> row#symbolReach),
        ("file recurrence", row -> row#fileRecurrence),
        ("symbol recurrence", row -> row#symbolRecurrence),
        ("reverse-import asymmetry", row -> row#importAsymmetry),
        ("caller asymmetry", row -> row#callAsymmetry),
        ("physical compression", row -> row#physicalCompression)
    };
    "| Dimension | Lowest repository | Value | Highest repository | Value |\n" +
    "| --- | --- | ---: | --- | ---: |\n" +
    (Vector.map(match (name, accessor) -> {
        let low = extreme(rows, accessor, true);
        let high = extreme(rows, accessor, false);
        "| ${name} | ${low#repository} | ${accessor(low)} | ${high#repository} | ${accessor(high)} |"
    }, dimensions) |> Vector.join("\n")) + "\n"
}

def extreme(rows: Vector[RepositoryResult], accessor: RepositoryResult -> Float64,
            lowest: Bool): RepositoryResult =
    Vector.foldLeft((best, row) -> if ((lowest and accessor(row) < accessor(best)) or
        (not lowest and accessor(row) > accessor(best))) row else best, Vector.get(0, rows), rows)

def correlationLine(name: String, rows: Vector[Feature], x: Feature -> Float64,
                    y: Feature -> Float64): String =
    "| ${name} | ${pearson(Vector.map(x, rows), Vector.map(y, rows))} |\n"

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

def repositorySchema(): ScientificTable.Schema = {
    format = "attune-atlas-repository-summary-v1",
    columns = Vector#{text("repository"), int64("snapshot_count"), float64("file_count_p50"),
        float64("symbol_count_p50"), float64("file_extinction"), float64("symbol_extinction"),
        float64("file_reach_p90"), float64("symbol_reach_p90"), float64("file_recurrence"),
        float64("symbol_recurrence"), float64("import_asymmetry"), float64("call_asymmetry"),
        float64("physical_compression"), float64("reuse_fraction"),
        float64("feature_range_mean"), float64("feature_range_max")}
}

def repositoryRow(row: RepositoryResult): ScientificTable.Row = Map#{
    "repository" => JString(row#repository), "snapshot_count" => ToJson.toJson(row#snapshots),
    "file_count_p50" => ToJson.toJson(row#files), "symbol_count_p50" => ToJson.toJson(row#symbols),
    "file_extinction" => ToJson.toJson(row#fileExtinction),
    "symbol_extinction" => ToJson.toJson(row#symbolExtinction),
    "file_reach_p90" => ToJson.toJson(row#fileReach), "symbol_reach_p90" => ToJson.toJson(row#symbolReach),
    "file_recurrence" => ToJson.toJson(row#fileRecurrence),
    "symbol_recurrence" => ToJson.toJson(row#symbolRecurrence),
    "import_asymmetry" => ToJson.toJson(row#importAsymmetry),
    "call_asymmetry" => ToJson.toJson(row#callAsymmetry),
    "physical_compression" => ToJson.toJson(row#physicalCompression),
    "reuse_fraction" => ToJson.toJson(row#reuseFraction),
    "feature_range_mean" => ToJson.toJson(row#driftMean),
    "feature_range_max" => ToJson.toJson(row#driftMax)
}

def decodeSummary(row: ScientificTable.Row): Result[String, Summary] = forM (
    repository <- string("repository", row); snapshot <- string("snapshot_id", row);
    scope <- string("scope", row); domain <- string("seed_domain", row);
    depth <- optionalInt("depth", row); atom <- optionalString("last_atom", row);
    metric0 <- string("metric", row); value <- number("value", row)
) yield {repository = repository, snapshot = snapshot, scope = scope, domain = domain,
    depth = depth, atom = atom, metric = metric0, value = value}

def decodeSnapshot(row: ScientificTable.Row): Result[String, Snapshot] = forM (
    repository <- string("repository", row); revision <- string("base_revision", row);
    snapshot <- string("snapshot_id", row); files <- number("file_count", row);
    symbols <- number("symbol_count", row)
) yield {repository = repository, revision = revision, snapshot = snapshot, files = files, symbols = symbols}

def decodePhysical(row: ScientificTable.Row): Result[String, Physical] = forM (
    repository <- string("repository", row); snapshot <- string("snapshot_id", row);
    compression <- number("logical_per_physical_evaluation", row);
    requests <- number("physical_transition_requests", row);
    reuses <- number("physical_transition_reuses", row)
) yield {repository = repository, snapshot = snapshot, logicalPerEvaluation = compression,
    requests = requests, reuses = reuses}

def string(name: String, row: ScientificTable.Row): Result[String, String] = match Map.get(name, row) {
    case Some(JString(value)) => Ok(value) case _ => Err("missing text field: ${name}")
}
def number(name: String, row: ScientificTable.Row): Result[String, Float64] = match Map.get(name, row) {
    case Some(value) => FromJson.fromJson(value) |> Result.mapErr(ToString.toString)
    case None => Err("missing numeric field: ${name}")
}
def optionalString(name: String, row: ScientificTable.Row): Result[String, Option[String]] = match Map.get(name, row) {
    case Some(Util.Json.Json.JNull) => Ok(None) case Some(JString(value)) => Ok(Some(value))
    case _ => Err("invalid optional text field: ${name}")
}
def optionalInt(name: String, row: ScientificTable.Row): Result[String, Option[Int32]] = match Map.get(name, row) {
    case Some(Util.Json.Json.JNull) => Ok(None)
    case Some(value) => FromJson.fromJson(value) |> Result.map(Some) |> Result.mapErr(ToString.toString)
    case None => Err("missing optional integer field: ${name}")
}

def middle(rows: Vector[a], accessor: a -> Float64): Float64 = Vector.map(accessor, rows) |> median
def median(values: Vector[Float64]): Float64 = {
    let sorted = Vector.sort(values); let length = Vector.length(sorted);
    if (length == 0) 0.0 else if (Int32.remainder(length, 2) == 1) Vector.get(length / 2, sorted)
    else (Vector.get(length / 2 - 1, sorted) + Vector.get(length / 2, sorted)) / 2.0
}
def range(rows: Vector[a], accessor: a -> Float64): Float64 = {
    let values = Vector.map(accessor, rows);
    if (Vector.isEmpty(values)) 0.0 else maximum(values) - minimum(values)
}
def relativeRange(rows: Vector[a], accessor: a -> Float64): Float64 = {
    let center = absolute(middle(rows, accessor));
    range(rows, accessor) / (if (center < 1.0) 1.0 else center)
}
def absolute(value: Float64): Float64 = if (value < 0.0) -value else value
def maximum(values: Vector[Float64]): Float64 = Vector.foldLeft((a, b) -> if (b > a) b else a, 0.0, values)
def minimum(values: Vector[Float64]): Float64 =
    if (Vector.isEmpty(values)) 0.0 else Vector.foldLeft((a, b) -> if (b < a) b else a, Vector.get(0, values), values)
def meanValues(values: Vector[Float64]): Float64 =
    if (Vector.isEmpty(values)) 0.0 else Vector.foldLeft((a, b) -> a + b, 0.0, values) / Int32.toFloat64(Vector.length(values))
def sum(values: Vector[a], accessor: a -> Float64): Float64 = Vector.foldLeft((a, b) -> a + accessor(b), 0.0, values)
def text(name: String): ScientificTable.Column = {name = name, kind = ScientificTable.ColumnType.Text, nullable = false}
def int64(name: String): ScientificTable.Column = {name = name, kind = ScientificTable.ColumnType.Int64, nullable = false}
def float64(name: String): ScientificTable.Column = {name = name, kind = ScientificTable.ColumnType.Float64, nullable = false}
