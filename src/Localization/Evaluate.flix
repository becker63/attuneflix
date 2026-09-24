/// Frozen SWE-Explore evaluation semantics.
///
/// Geometry is prepared once per case. The structural oracle scores each
/// unique semantic state and each unique top-five projection once, while the
/// first logical route remains the stable tie winner.
pub mod Localization.Evaluate {
    use Util.Json
    use Util.Json.Json.{JArray, JBool, JNumber, JObject, JString}
    use Util.Json.FromJson
    use Util.Json.ToJson

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
        states = Set[Radii.Compiled.ArenaStateId],
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

    pub def predictionRanking(instanceId: String, payload: String): Result[String, Vector[String]] =
        match Json.parse(payload) {
            case Err(error) => Err(ToString.toString(error))
            case Ok(JObject(fields)) => forM (
                actual <- stringField("instance_id", fields);
                _ <- if (actual == instanceId) Ok(()) else Err("prediction instance identity mismatch");
                ranking <- stringVectorField("ranking", fields)
            ) yield ranking
            case Ok(_) => Err("localization prediction must be an object")
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
        "protocol" => JString("attune-localization-oracle-telemetry-v1"),
        "instance_id" => JString(row#instanceId),
        "logical_routes" => ToJson.toJson(row#telemetry#logicalRoutes),
        "unique_states" => ToJson.toJson(row#telemetry#uniqueStates),
        "unique_projections" => ToJson.toJson(row#telemetry#uniqueProjections),
        "score_evaluations" => ToJson.toJson(row#telemetry#scoreEvaluations)
    }}

    /// Strict discrete parity and the established 1e-10 floating tolerance.
    pub def parityProof(instanceId: String, frozenPayload: String, row: ResultRow): Result[String, ScientificTable.Row] = forM (
        expected <- frozenRow(instanceId, frozenPayload);
        _ <- if (expected#oraclePath == row#oraclePath and
            projectionKey(expected#priorRegions) == projectionKey(row#priorRegions) and
            projectionKey(expected#selectedRegions) == projectionKey(row#selectedRegions) and
            projectionKey(expected#oracleRegions) == projectionKey(row#oracleRegions)) Ok(())
            else Err("frozen evaluator discrete parity mismatch");
        _ <- if (sameScore(expected#prior, row#prior) and
            sameScore(expected#selected, row#selected) and
            sameScore(expected#oracle, row#oracle)) Ok(())
            else Err("frozen evaluator metric parity mismatch")
    ) yield Map#{
        "protocol" => JString("attune-localization-evaluation-parity-v1"),
        "instance_id" => JString(instanceId), "exact_discrete" => JBool(true),
        "metrics_within_tolerance" => JBool(true), "tolerance" => ToJson.toJson(0.0000000001)
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
                        let state = Radii.Compiled.state(computed#evaluation, id);
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
        "protocol" => JString("attune-localization-evaluation-v1"),
        "instance_id" => JString(row#instanceId), "repository" => JString(row#repository),
        "base_revision" => JString(baseRevision), "snapshot_id" => JString(snapshotId),
        "condition" => JString(condition), "oracle_path" => JString(oraclePath),
        "precision" => ToJson.toJson(value#precision), "recall" => ToJson.toJson(value#recall),
        "f1_score" => ToJson.toJson(value#f1), "hit_file_rate" => ToJson.toJson(value#hitFile),
        "noise_file_rate" => ToJson.toJson(value#noiseFile), "hit_region_rate" => ToJson.toJson(value#hitRegion),
        "noise_region_rate" => ToJson.toJson(value#noiseRegion),
        "weighted_core_coverage" => ToJson.toJson(value#weightedCoreCoverage),
        "context_efficiency" => ToJson.toJson(value#contextEfficiency),
        "ndcg_at_100" => ToJson.toJson(value#ndcg100), "ndcg_at_300" => ToJson.toJson(value#ndcg300),
        "ndcg_at_500" => ToJson.toJson(value#ndcg500), "recall_at_100" => ToJson.toJson(value#recall100),
        "recall_at_300" => ToJson.toJson(value#recall300), "recall_at_500" => ToJson.toJson(value#recall500),
        "first_useful_hit" => ToJson.toJson(value#firstUsefulHit)
    }

    def conditionRegions(instanceId: String, condition: String, regions: Vector[SourceRegion]): Vector[ScientificTable.Row] =
        Vector.mapWithIndex((ordinal, span0) -> Map#{
            "protocol" => JString("attune-localization-evaluation-v1"),
            "instance_id" => JString(instanceId), "condition" => JString(condition),
            "ordinal" => ToJson.toJson(ordinal), "path" => JString(span0#path),
            "start_line" => ToJson.toJson(span0#start), "end_line" => ToJson.toJson(span0#end)
        }, regions)

    type alias Frozen = {
        prior = Score, selected = Score, oracle = Score, oraclePath = String,
        priorRegions = Vector[SourceRegion], selectedRegions = Vector[SourceRegion],
        oracleRegions = Vector[SourceRegion]
    }

    def frozenRow(instanceId: String, payload: String): Result[String, Frozen] = match Json.parse(payload) {
        case Err(error) => Err(ToString.toString(error))
        case Ok(JObject(fields)) => forM (
            values <- arrayField("cases", fields);
            value <- Vector.find(item -> caseId(item) == Some(instanceId), values)
                |> Option.toOk("missing frozen evaluation row: ${instanceId}");
            frozen <- decodeFrozen(value)
        ) yield frozen
        case Ok(_) => Err("frozen evaluation must be an object")
    }

    def decodeFrozen(value: Json): Result[String, Frozen] = match value {
        case JObject(fields) => forM (
            oraclePath <- stringField("oracle_path", fields);
            priorValue <- field("prior", fields); prior <- decodeCondition(priorValue);
            selectedValue <- field("jev", fields); selected <- decodeCondition(selectedValue);
            oracleValue <- field("structural_oracle", fields); oracle <- decodeCondition(oracleValue)
        ) yield {
            prior = fst(prior), selected = fst(selected), oracle = fst(oracle), oraclePath = oraclePath,
            priorRegions = snd(prior), selectedRegions = snd(selected), oracleRegions = snd(oracle)
        }
        case _ => Err("frozen evaluation case must be an object")
    }

    def decodeCondition(value: Json): Result[String, (Score, Vector[SourceRegion])] = match value {
        case JObject(fields) => forM (
            metricsValue <- field("metrics", fields); metrics <- decodeScore(metricsValue);
            regionValues <- arrayField("regions", fields); regions <- Vector.traverse(decodeRegion, regionValues)
        ) yield (metrics, regions)
        case _ => Err("evaluation condition must be an object")
    }

    def decodeScore(value: Json): Result[String, Score] = match value {
        case JObject(fields) => forM (
            precision <- floatField("precision", fields); recall <- floatField("recall", fields);
            f1 <- floatField("f1_score", fields); hitFile <- floatField("hit_file_rate", fields);
            noiseFile <- floatField("noise_file_rate", fields); hitRegion <- floatField("hit_region_rate", fields);
            noiseRegion <- floatField("noise_region_rate", fields);
            weighted <- floatField("weighted_core_coverage", fields); context <- floatField("context_efficiency", fields);
            ndcg100 <- floatField("ndcg_at_100", fields); ndcg300 <- floatField("ndcg_at_300", fields);
            ndcg500 <- floatField("ndcg_at_500", fields); recall100 <- floatField("recall_at_100", fields);
            recall300 <- floatField("recall_at_300", fields); recall500 <- floatField("recall_at_500", fields);
            first <- floatField("first_useful_hit", fields)
        ) yield {
            precision = precision, recall = recall, f1 = f1, hitFile = hitFile, noiseFile = noiseFile,
            hitRegion = hitRegion, noiseRegion = noiseRegion, weightedCoreCoverage = weighted,
            contextEfficiency = context, ndcg100 = ndcg100, ndcg300 = ndcg300, ndcg500 = ndcg500,
            recall100 = recall100, recall300 = recall300, recall500 = recall500, firstUsefulHit = first
        }
        case _ => Err("evaluation metrics must be an object")
    }

    def decodeRegion(value: Json): Result[String, SourceRegion] = match value {
        case JObject(fields) => forM (
            path <- stringField("path", fields); start <- intField("start", fields); end <- intField("end", fields)
        ) yield {path = path, start = Int32.max(1, start), end = end}
        case _ => Err("evaluation region must be an object")
    }

    def sameScore(left: Score, right: Score): Bool = Vector.forAll(pair ->
        Float64.abs(fst(pair) - snd(pair)) <= 0.0000000001, Vector#{
            (left#precision, right#precision), (left#recall, right#recall), (left#f1, right#f1),
            (left#hitFile, right#hitFile), (left#noiseFile, right#noiseFile),
            (left#hitRegion, right#hitRegion), (left#noiseRegion, right#noiseRegion),
            (left#weightedCoreCoverage, right#weightedCoreCoverage),
            (left#contextEfficiency, right#contextEfficiency), (left#ndcg100, right#ndcg100),
            (left#ndcg300, right#ndcg300), (left#ndcg500, right#ndcg500),
            (left#recall100, right#recall100), (left#recall300, right#recall300),
            (left#recall500, right#recall500), (left#firstUsefulHit, right#firstUsefulHit)
        })

    def caseId(value: Json): Option[String] = match value {
        case JObject(fields) => match Map.get("instance_id", fields) {
            case Some(JString(value0)) => Some(value0)
            case _ => None
        }
        case _ => None
    }

    def field(name: String, fields: Map[String, Json]): Result[String, Json] =
        Map.get(name, fields) |> Option.toOk("missing JSON field: ${name}")

    def stringField(name: String, fields: Map[String, Json]): Result[String, String] = match field(name, fields) {
        case Ok(JString(value)) => Ok(value)
        case Ok(_) => Err("${name}: expected string")
        case Err(error) => Err(error)
    }

    def intField(name: String, fields: Map[String, Json]): Result[String, Int32] =
        field(name, fields) |> Result.flatMap(value -> FromJson.fromJson(value) |> Result.mapErr(ToString.toString))

    def floatField(name: String, fields: Map[String, Json]): Result[String, Float64] =
        field(name, fields) |> Result.flatMap(value -> FromJson.fromJson(value) |> Result.mapErr(ToString.toString))

    def arrayField(name: String, fields: Map[String, Json]): Result[String, Vector[Json]] = match field(name, fields) {
        case Ok(JArray(values)) => Ok(values)
        case Ok(_) => Err("${name}: expected array")
        case Err(error) => Err(error)
    }

    def stringVectorField(name: String, fields: Map[String, Json]): Result[String, Vector[String]] =
        field(name, fields) |> Result.flatMap(value -> FromJson.fromJson(value) |> Result.mapErr(ToString.toString))

}
