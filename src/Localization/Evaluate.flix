/// Frozen SWE-Explore evaluation semantics.
///
/// Geometry is prepared once per case. The structural oracle scores each
/// unique semantic state and each unique top-five projection once, while the
/// first logical route remains the stable tie winner.
pub mod Localization.Evaluate {
    use ScientificTable.Value

    pub type alias SourceRegion = Localization.EvaluationData.SourceRegion
    pub type alias Gold = Localization.EvaluationData.Gold
    pub type alias Geometry = Localization.EvaluationData.Geometry

    pub type alias Score = {
        precision = Float64,
        recall = Float64,
        f1 = Float64,
        hitFile = Float64,
        noiseFile = Float64,
        hitRegion = Float64,
        noiseRegion = Float64,
        weightedCoreCoverage = Float64,
        contextEfficiency = Float64,
        ndcg100 = Float64,
        ndcg300 = Float64,
        ndcg500 = Float64,
        recall100 = Float64,
        recall300 = Float64,
        recall500 = Float64,
        firstUsefulHit = Float64
    }

    pub type alias OracleTelemetry = {
        logicalRoutes = Int32,
        uniqueStates = Int32,
        uniqueProjections = Int32,
        scoreEvaluations = Int32
    }

    pub type alias ResultRow = {
        instanceId = String,
        repository = String,
        prior = Score,
        selected = Score,
        oracle = Score,
        oraclePath = String,
        priorRegions = Vector[SourceRegion],
        selectedRegions = Vector[SourceRegion],
        oracleRegions = Vector[SourceRegion],
        telemetry = OracleTelemetry
    }

    type alias Context = {
        counts = Map[String, Int32],
        coreLines = Set[(String, Int32)],
        optionalLines = Set[(String, Int32)],
        usefulLines = Set[(String, Int32)],
        documentRegions = Vector[Option[SourceRegion]]
    }

    type alias Best = {
        path = String,
        score = Score,
        regions = Vector[SourceRegion],
        telemetry = OracleTelemetry
    }

    type alias CandidateBest = {
        path = String,
        f1 = Float64,
        regions = Vector[SourceRegion]
    }

    type alias CandidateSearch = {
        best = CandidateBest,
        states = Set[Radii.Evaluate.ArenaStateId],
        projections = Set[Vector[(String, Int32, Int32)]],
        telemetry = OracleTelemetry
    }

    type alias BudgetCoverage = {
        covered = Set[(String, Int32)],
        consumed = Int32
    }

    type alias Gain = {gain = Float64, lines = Int32, ordinal = Int32}

    pub def evaluate(
        prepared: Localization.Prepared,
        prior: Localization.Tree.Prior,
        computed: Localization.Tree.Computed,
        selectedIdentities: Vector[String],
        gold: Gold,
        geometry: Geometry
    ): Result[String, ResultRow] = forM (
        selected <- reorder(prior#ranking, selectedIdentities);
        context = evaluationContext(gold, geometry);
        priorRegions = regionsFor(context, prior#ranking);
        selectedRegions = regionsFor(context, selected);
        priorScore = score(priorRegions, gold, context);
        selectedScore = score(selectedRegions, gold, context);
        oracle = structuralOracle(prior, computed, gold, context)
    ) yield {
        instanceId = prepared#instanceId,
        repository = prepared#repository,
        prior = priorScore,
        selected = selectedScore,
        oracle = oracle#score,
        oraclePath = oracle#path,
        priorRegions = priorRegions,
        selectedRegions = selectedRegions,
        oracleRegions = oracle#regions,
        telemetry = oracle#telemetry
    }

    pub def metricRows(
        row: ResultRow,
        baseRevision: String,
        snapshotId: String
    ): Vector[ScientificTable.Row] = Vector#{
        metricRow(row, baseRevision, snapshotId, "prior", "", row#prior),
        metricRow(row, baseRevision, snapshotId, "iteration-013", "", row#selected),
        metricRow(row, baseRevision, snapshotId, "structural-oracle", row#oraclePath, row#oracle)
    }

    pub def regionRows(row: ResultRow): Vector[ScientificTable.Row] = Vector.flatten(Vector#{
        conditionRegions(row#instanceId, "prior", row#priorRegions),
        conditionRegions(row#instanceId, "iteration-013", row#selectedRegions),
        conditionRegions(row#instanceId, "structural-oracle", row#oracleRegions)
    })

    pub def telemetryRows(row: ResultRow): Vector[ScientificTable.Row] = Vector#{Map#{
        "protocol" => Value.Text("attune-localization-oracle-telemetry-v1"),
        "instance_id" => Value.Text(row#instanceId),
        "logical_routes" => Value.Int32(row#telemetry#logicalRoutes),
        "unique_states" => Value.Int32(row#telemetry#uniqueStates),
        "unique_projections" => Value.Int32(row#telemetry#uniqueProjections),
        "score_evaluations" => Value.Int32(row#telemetry#scoreEvaluations)
    }}

    /// Compare a fresh evaluation with the admitted typed result tables.
    /// Region/order/string identity is exact; official floating metrics retain
    /// the established 1e-10 tolerance from the sealed experiment.
    pub def parityProof(
        instanceId: String,
        baseRevision: String,
        snapshotId: String,
        expectedMetrics: Vector[ScientificTable.Row],
        expectedRegions: Vector[ScientificTable.Row],
        row: ResultRow
    ): Result[String, ScientificTable.Row] = {
        let metrics0 = rowsFor(instanceId, expectedMetrics);
        let regions0 = rowsFor(instanceId, expectedRegions);
        let metrics1 = metricRows(row, baseRevision, snapshotId);
        let regions1 = regionRows(row);
        if (ScientificTable.canonicalRows(regions0) != ScientificTable.canonicalRows(regions1))
            Err("frozen evaluator discrete region parity mismatch")
        else if (not sameMetricRows(metrics0, metrics1))
            Err("frozen evaluator metric parity mismatch")
        else Ok(Map#{
            "protocol" => Value.Text("attune-localization-evaluation-parity-v1"),
            "instance_id" => Value.Text(instanceId), "exact_discrete" => Value.Boolean(true),
            "metrics_within_tolerance" => Value.Boolean(true), "tolerance" => Value.Float64(0.0000000001)
        })
    }

    def evaluationContext(gold: Gold, geometry: Geometry): Context = {
        let counts = Vector.foldLeft((result, span0) ->
            Map.insertWith(Int32.max, span0#path, Int32.max(1, span0#end), result),
            geometry#counts, gold#coreRegions ++ gold#optionalRegions);
        let core = lines(gold#coreRegions, counts);
        let optional = lines(gold#optionalRegions, counts);
        {
            counts = counts, coreLines = core, optionalLines = optional,
            usefulLines = Set.union(core, optional),
            documentRegions = geometry#documentRegions
        }
    }

    def structuralOracle(
        prior: Localization.Tree.Prior,
        computed: Localization.Tree.Computed,
        gold: Gold,
        context: Context
    ): Best = {
        let rootRegions = regionsFor(context, prior#ranking);
        let root: CandidateBest = {path = "root", f1 = lineF1(rootRegions, context), regions = rootRegions};
        let initial: CandidateSearch = {
            best = root, states = Set.empty(), projections = Set#{projectionKey(rootRegions)},
            telemetry = {logicalRoutes = 0, uniqueStates = 0, uniqueProjections = 0, scoreEvaluations = 1}
        };
        let search = bestRoute(context, prior, computed, 0, initial);
        let winner = search#best;
        {path = winner#path, score = score(winner#regions, gold, context),
            regions = winner#regions, telemetry = search#telemetry}
    }

    def bestRoute(
        context: Context,
        prior: Localization.Tree.Prior,
        computed: Localization.Tree.Computed,
        index: Int32,
        search: CandidateSearch
    ): CandidateSearch =
        if (index >= Vector.length(computed#tree#routes)) search
        else {
            let route = Vector.get(index, computed#tree#routes);
            let next = if (snd(Radii.endpoints(route#expression)) != Radii.Domain.Symbol) search
                else {
                    let id = Vector.get(index, computed#evaluation#outputs);
                    let counted = {
                        best = search#best, states = search#states, projections = search#projections,
                        telemetry = {logicalRoutes = search#telemetry#logicalRoutes + 1,
                            uniqueStates = search#telemetry#uniqueStates,
                            uniqueProjections = search#telemetry#uniqueProjections,
                            scoreEvaluations = search#telemetry#scoreEvaluations}
                    };
                    if (Set.memberOf(id, search#states)) counted
                    else {
                        let state = Radii.Evaluate.state(computed#evaluation, id);
                        let spans = regionsFor(context, Localization.Tree.promote(prior#ranking, state));
                        let key = projectionKey(spans);
                        let unique = {
                            best = search#best, states = Set.insert(id, search#states),
                            projections = search#projections,
                            telemetry = {logicalRoutes = counted#telemetry#logicalRoutes,
                                uniqueStates = counted#telemetry#uniqueStates + 1,
                                uniqueProjections = counted#telemetry#uniqueProjections,
                                scoreEvaluations = counted#telemetry#scoreEvaluations}
                        };
                        if (Set.memberOf(key, search#projections)) unique
                        else {
                            let candidate = {path = pathText(route#steps), f1 = lineF1(spans, context), regions = spans};
                            {
                                best = if (candidate#f1 > search#best#f1) candidate else search#best,
                                states = unique#states, projections = Set.insert(key, search#projections),
                                telemetry = {logicalRoutes = unique#telemetry#logicalRoutes,
                                    uniqueStates = unique#telemetry#uniqueStates,
                                    uniqueProjections = unique#telemetry#uniqueProjections + 1,
                                    scoreEvaluations = unique#telemetry#scoreEvaluations + 1}
                            }
                        }
                    }
                };
            bestRoute(context, prior, computed, index + 1, next)
        }

    def projectionKey(regions: Vector[SourceRegion]): Vector[(String, Int32, Int32)] =
        Vector.map(span0 -> (span0#path, span0#start, span0#end), regions)

    def regionsFor(context: Context, ranking: Vector[Localization.Ranked]): Vector[SourceRegion] =
        regionsFrom(context, ranking, 0, Set.empty(), Vector.empty())

    def regionsFrom(
        context: Context,
        ranking: Vector[Localization.Ranked],
        index: Int32,
        seen: Set[(String, Int32, Int32)],
        result: Vector[SourceRegion]
    ): Vector[SourceRegion] =
        if (Vector.length(result) >= 5 or index >= Vector.length(ranking)) result
        else {
            let item = Vector.get(index, ranking);
            match Vector.get(item#ordinal, context#documentRegions) {
                case None => regionsFrom(context, ranking, index + 1, seen, result)
                case Some(span0) => {
                    let key = (span0#path, span0#start, span0#end);
                    if (Set.memberOf(key, seen)) regionsFrom(context, ranking, index + 1, seen, result)
                    else regionsFrom(context, ranking, index + 1, Set.insert(key, seen),
                        Vector.append(result, Vector#{span0}))
                }
            }
        }

    /// Literal Flix port of quality/bench_metrics.py at evaluator revision
    /// 5602f031f2d9562d0a805f83402b536e831a5a11.
    def score(predictions: Vector[SourceRegion], gold: Gold, context: Context): Score = {
        let counts = context#counts;
        let predictedLines = lines(predictions, counts);
        let coreLines = context#coreLines;
        let overlap = Set.size(Set.intersection(predictedLines, coreLines));
        let precision = ratio(overlap, Set.size(predictedLines));
        let recall = ratio(overlap, Set.size(coreLines));
        let f1 = if (precision + recall == 0.0) 0.0 else 2.0 * precision * recall / (precision + recall);
        let visited = Vector.map(span0 -> span0#path, predictions) |> Vector.toSet;
        let usefulFiles = Set.union(gold#coreFiles, gold#optionalFiles);
        let noiseFiles = Set.difference(visited, usefulFiles);
        let hitRegions = Vector.count(core ->
            Vector.exists(predicted -> overlaps(core, predicted, counts), predictions), gold#coreRegions);
        let noiseRegions = Vector.count(predicted ->
            not Vector.exists(core -> overlaps(predicted, core, counts), gold#coreRegions) and
            not Vector.exists(optional -> overlaps(predicted, optional, counts), gold#optionalRegions), predictions);
        let weighted = weightedCoverage(gold#coreRegions, gold#mainFiles, predictedLines, counts);
        let gains = Vector.mapWithIndex((index, span0) ->
            regionGain(index, span0, coreLines, gold#mainFiles, counts), predictions);
        {
            precision = precision, recall = recall, f1 = f1,
            hitFile = ratio(Set.size(Set.intersection(visited, gold#coreFiles)), Set.size(gold#coreFiles)),
            noiseFile = ratio(Set.size(noiseFiles), Set.size(visited)),
            hitRegion = ratio(hitRegions, Vector.length(gold#coreRegions)),
            noiseRegion = ratio(noiseRegions, Vector.length(predictions)),
            weightedCoreCoverage = weighted,
            contextEfficiency = ratio(Set.size(Set.intersection(predictedLines, context#usefulLines)), Set.size(predictedLines)),
            ndcg100 = ndcg(gains, 100), ndcg300 = ndcg(gains, 300), ndcg500 = ndcg(gains, 500),
            recall100 = recallAt(predictions, coreLines, counts, 100),
            recall300 = recallAt(predictions, coreLines, counts, 300),
            recall500 = recallAt(predictions, coreLines, counts, 500),
            firstUsefulHit = firstUseful(predictions, coreLines, counts)
        }
    }

    def lineF1(predictions: Vector[SourceRegion], context: Context): Float64 = {
        let predictedLines = lines(predictions, context#counts);
        let overlap = Set.size(Set.intersection(predictedLines, context#coreLines));
        let precision = ratio(overlap, Set.size(predictedLines));
        let recall = ratio(overlap, Set.size(context#coreLines));
        if (precision + recall == 0.0) 0.0 else 2.0 * precision * recall / (precision + recall)
    }

    def resolve(span0: SourceRegion, counts: Map[String, Int32]): Option[(Int32, Int32)] =
        match Map.get(span0#path, counts) {
            case None => None
            case Some(total) => {
                let needsTotal = span0#end == -1 or span0#start < 0;
                if (needsTotal and total < 1) None
                else if (needsTotal) {
                    let end = if (span0#end == -1) total else span0#end;
                    let start = if (span0#start < 0) total + span0#start + 1 else span0#start;
                    Some((Int32.max(1, Int32.min(start, total)), Int32.max(1, Int32.min(end, total))))
                } else if (span0#end < 1) None
                else Some((Int32.max(1, span0#start), span0#end))
            }
        }

    def lines(regions: Vector[SourceRegion], counts: Map[String, Int32]): Set[(String, Int32)] =
        Vector.foldLeft((result, span0) -> match resolve(span0, counts) {
            case None => result
            case Some((start, end)) => addLines(span0#path, start, end, result)
        }, Set.empty(), regions)

    def addLines(path: String, current: Int32, end: Int32, result: Set[(String, Int32)]): Set[(String, Int32)] =
        if (current > end) result else addLines(path, current + 1, end, Set.insert((path, current), result))

    def overlaps(left: SourceRegion, right: SourceRegion, counts: Map[String, Int32]): Bool =
        if (left#path != right#path) false
        else match (resolve(left, counts), resolve(right, counts)) {
            case (Some((ls, le)), Some((rs, re))) => ls <= re and rs <= le
            case _ => false
        }

    def weightedCoverage(
        regions: Vector[SourceRegion],
        mainFiles: Set[String],
        predictedLines: Set[(String, Int32)],
        counts: Map[String, Int32]
    ): Float64 = {
        let (weighted, total) = Vector.foldLeft((acc, span0) -> match (acc, resolve(span0, counts)) {
            case ((sum0, total0), None) => (sum0, total0)
            case ((sum0, total0), Some((start, end))) => {
                let truth = addLines(span0#path, start, end, Set.empty());
                let coverage = ratio(Set.size(Set.intersection(predictedLines, truth)), Set.size(truth));
                let weight = if (Set.memberOf(span0#path, mainFiles)) 3.0 else 2.0;
                (sum0 + weight * coverage, total0 + weight)
            }
        }, (0.0, 0.0), regions);
        if (total == 0.0) 0.0 else weighted / total
    }

    def regionGain(
        ordinal: Int32, span0: SourceRegion, coreLines: Set[(String, Int32)],
        mainFiles: Set[String], counts: Map[String, Int32]
    ): Gain = match resolve(span0, counts) {
        case None => {gain = 0.0, lines = 0, ordinal = ordinal}
        case Some((start, end)) => {
            let weight = if (Set.memberOf(span0#path, mainFiles)) 1.5 else 1.0;
            let covered = Set.size(Set.intersection(addLines(span0#path, start, end, Set.empty()), coreLines));
            {gain = Int32.toFloat64(covered) * weight, lines = end - start + 1, ordinal = ordinal}
        }
    }

    def ndcg(gains: Vector[Gain], budget: Int32): Float64 = {
        let actual = dcg(gains, budget, 0, 0, 0.0);
        let ideal = Vector.sortBy(item -> (-(item#gain / Int32.toFloat64(Int32.max(item#lines, 1))), item#ordinal), gains);
        let best = dcg(ideal, budget, 0, 0, 0.0);
        if (best <= 0.0) 0.0 else Float64.min(actual / best, 1.0)
    }

    def dcg(gains: Vector[Gain], budget: Int32, index: Int32, cumulative: Int32, total: Float64): Float64 =
        if (index >= Vector.length(gains)) total
        else {
            let item = Vector.get(index, gains);
            let next = cumulative + item#lines;
            if (next > budget and index > 0) total
            else dcg(gains, budget, index + 1, next, total + item#gain / discount(index))
        }

    def discount(index: Int32): Float64 = match index {
        case 0 => 1.0
        case 1 => 1.584962500721156
        case 2 => 2.0
        case 3 => 2.321928094887362
        case _ => 2.584962500721156
    }

    def recallAt(
        predictions: Vector[SourceRegion], coreLines: Set[(String, Int32)],
        counts: Map[String, Int32], budget: Int32
    ): Float64 = {
        let result = budgetRegions(predictions, coreLines, counts, budget, 0,
            {covered = Set.empty(), consumed = 0});
        ratio(Set.size(result#covered), Set.size(coreLines))
    }

    def budgetRegions(
        predictions: Vector[SourceRegion], coreLines: Set[(String, Int32)],
        counts: Map[String, Int32], budget: Int32, index: Int32, result: BudgetCoverage
    ): BudgetCoverage =
        if (index >= Vector.length(predictions) or result#consumed >= budget) result
        else match resolve(Vector.get(index, predictions), counts) {
            case None => budgetRegions(predictions, coreLines, counts, budget, index + 1, result)
            case Some((start, end)) => {
                let next = budgetRange(Vector.get(index, predictions)#path, start, end, coreLines, budget, result);
                budgetRegions(predictions, coreLines, counts, budget, index + 1, next)
            }
        }

    def budgetRange(
        path: String, current: Int32, end: Int32, coreLines: Set[(String, Int32)],
        budget: Int32, result: BudgetCoverage
    ): BudgetCoverage =
        if (current > end or result#consumed >= budget) result
        else {
            let key = (path, current);
            budgetRange(path, current + 1, end, coreLines, budget, {
                covered = if (Set.memberOf(key, coreLines)) Set.insert(key, result#covered) else result#covered,
                consumed = result#consumed + 1
            })
        }

    def firstUseful(
        predictions: Vector[SourceRegion], coreLines: Set[(String, Int32)], counts: Map[String, Int32]
    ): Float64 = firstUsefulFrom(predictions, coreLines, counts, 0)

    def firstUsefulFrom(
        predictions: Vector[SourceRegion], coreLines: Set[(String, Int32)],
        counts: Map[String, Int32], index: Int32
    ): Float64 =
        if (index >= Vector.length(predictions) or Set.isEmpty(coreLines)) 0.0
        else match resolve(Vector.get(index, predictions), counts) {
            case None => firstUsefulFrom(predictions, coreLines, counts, index + 1)
            case Some((start, end)) => {
                let span0 = Vector.get(index, predictions);
                if (Set.exists(match (path, line) -> path == span0#path and start <= line and line <= end, coreLines))
                    1.0 - Int32.toFloat64(index) / Int32.toFloat64(Vector.length(predictions))
                else firstUsefulFrom(predictions, coreLines, counts, index + 1)
            }
        }

    def reorder(prior: Vector[Localization.Ranked], identities: Vector[String]): Result[String, Vector[Localization.Ranked]] = {
        let byIdentity = Vector.map(item -> (item#identity, item), prior) |> Vector.toMap;
        Vector.traverse(identity -> Map.get(identity, byIdentity)
            |> Option.toOk("prediction refers to missing document: ${identity}"), identities)
    }

    def ratio(numerator: Int32, denominator: Int32): Float64 =
        if (denominator == 0) 0.0 else Int32.toFloat64(numerator) / Int32.toFloat64(denominator)

    def pathText(path: Vector[Radii.Atom]): String =
        if (Vector.isEmpty(path)) "root"
        else Vector.map(atom -> Decide.actionKey(Decide.Action.Follow(atom)), path)
            |> Vector.toList |> List.intersperse(">>") |> List.fold

    def metricRow(
        row: ResultRow, baseRevision: String, snapshotId: String,
        condition: String, oraclePath: String, value: Score
    ): ScientificTable.Row = Map#{
        "protocol" => Value.Text("attune-localization-evaluation-v1"),
        "instance_id" => Value.Text(row#instanceId), "repository" => Value.Text(row#repository),
        "base_revision" => Value.Text(baseRevision), "snapshot_id" => Value.Text(snapshotId),
        "condition" => Value.Text(condition), "oracle_path" => Value.Text(oraclePath),
        "precision" => Value.Float64(value#precision), "recall" => Value.Float64(value#recall),
        "f1_score" => Value.Float64(value#f1), "hit_file_rate" => Value.Float64(value#hitFile),
        "noise_file_rate" => Value.Float64(value#noiseFile), "hit_region_rate" => Value.Float64(value#hitRegion),
        "noise_region_rate" => Value.Float64(value#noiseRegion),
        "weighted_core_coverage" => Value.Float64(value#weightedCoreCoverage),
        "context_efficiency" => Value.Float64(value#contextEfficiency),
        "ndcg_at_100" => Value.Float64(value#ndcg100), "ndcg_at_300" => Value.Float64(value#ndcg300),
        "ndcg_at_500" => Value.Float64(value#ndcg500), "recall_at_100" => Value.Float64(value#recall100),
        "recall_at_300" => Value.Float64(value#recall300), "recall_at_500" => Value.Float64(value#recall500),
        "first_useful_hit" => Value.Float64(value#firstUsefulHit)
    }

    def conditionRegions(instanceId: String, condition: String, regions: Vector[SourceRegion]): Vector[ScientificTable.Row] =
        Vector.mapWithIndex((ordinal, span0) -> Map#{
            "protocol" => Value.Text("attune-localization-evaluation-v1"),
            "instance_id" => Value.Text(instanceId), "condition" => Value.Text(condition),
            "ordinal" => Value.Int32(ordinal), "path" => Value.Text(span0#path),
            "start_line" => Value.Int32(span0#start), "end_line" => Value.Int32(span0#end)
        }, regions)

    def rowsFor(instanceId: String, rows: Vector[ScientificTable.Row]): Vector[ScientificTable.Row] =
        Vector.filter(row -> ScientificTable.text(row, "instance_id") == Ok(instanceId), rows)

    def sameMetricRows(
        expected: Vector[ScientificTable.Row],
        actual: Vector[ScientificTable.Row]
    ): Bool = Vector.length(expected) == 3 and Vector.length(actual) == 3 and
        Vector.forAll(match (left, right) -> sameMetricRow(left, right), Vector.zip(expected, actual))

    def sameMetricRow(left: ScientificTable.Row, right: ScientificTable.Row): Bool =
        Vector.forAll(name -> ScientificTable.text(left, name) == ScientificTable.text(right, name), Vector#{
            "protocol", "instance_id", "repository", "base_revision", "snapshot_id", "condition", "oracle_path"
        }) and Vector.forAll(name ->
            Float64.abs(float(left, name) - float(right, name)) <= 0.0000000001, Vector#{
                "precision", "recall", "f1_score", "hit_file_rate", "noise_file_rate",
                "hit_region_rate", "noise_region_rate", "weighted_core_coverage", "context_efficiency",
                "ndcg_at_100", "ndcg_at_300", "ndcg_at_500", "recall_at_100", "recall_at_300",
                "recall_at_500", "first_useful_hit"
            })

    def float(row: ScientificTable.Row, name: String): Float64 =
        match ScientificTable.float64(row, name) {
            case Ok(value) => value
            case Err(error) => bug!(error)
        }

}
