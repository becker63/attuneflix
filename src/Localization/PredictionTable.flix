/// Typed frozen localization predictions.
///
/// Summary, ranking, decisions, and per-alternative probabilities are split
/// into ordinary columns. Exact replay compares these semantic rows directly;
/// JSON-tree serialization is not part of current prediction identity.
pub mod Localization.PredictionTable {
    use ScientificTable.Value

    pub type alias Tables = {
        summary = Vector[ScientificTable.Row],
        ranking = Vector[ScientificTable.Row],
        decisions = Vector[ScientificTable.Row],
        probabilities = Vector[ScientificTable.Row]
    }

    pub def protocol(): String = "attune-localization-prediction-v1"

    pub def summary(): ScientificTable.Schema = {
        format = "attune-localization-prediction-summary-v1",
        columns = Vector#{
            text("protocol"), text("condition"), text("instance_id"),
            text("repository"), text("base_revision"), textList("path"),
            int32("decision_count"), int32("states_interned"),
            int32("memo_entries"), int32("memo_slots")
        }
    }

    pub def ranking(): ScientificTable.Schema = {
        format = "attune-localization-prediction-ranking-v1",
        columns = Vector#{
            text("protocol"), text("instance_id"), int32("rank"), text("semantic_id")
        }
    }

    pub def decisions(): ScientificTable.Schema = {
        format = "attune-localization-prediction-decisions-v1",
        columns = Vector#{
            text("protocol"), text("instance_id"), int32("ordinal"),
            text("choice"), int32("choice_index"), float64("confidence"),
            text("provider"), text("actual_model"), text("response_id"),
            optionalInt32("input_tokens"), optionalInt32("output_tokens"), optionalFloat64("cost")
        }
    }

    pub def probabilities(): ScientificTable.Schema = {
        format = "attune-localization-prediction-probabilities-v1",
        columns = Vector#{
            text("protocol"), text("instance_id"), int32("decision_ordinal"),
            text("action"), float64("probability")
        }
    }

    pub def rows(prepared: Localization.Prepared, outcome: Localization.Tree.Outcome): Tables = {
        let instanceId = prepared#instanceId;
        {
            summary = Vector#{summaryRow(
                "frozen-iteration-013", instanceId, prepared#repository, prepared#baseCommit,
                Vector.map(atom -> Decide.actionKey(Decide.Action.Follow(atom)), outcome#path),
                Vector.length(outcome#decisions), outcome#metrics#statesInterned,
                outcome#metrics#memoEntries, outcome#metrics#memoSlots)},
            ranking = Vector.mapWithIndex((rank, item) -> rankingRow(instanceId, rank, item#identity),
                outcome#ranking),
            decisions = Vector.mapWithIndex((ordinal, observation) -> decisionRow(instanceId, ordinal,
                Decide.actionKey(observation#choice), observation#choiceIndex, observation#confidence,
                observation#provider, observation#actualModel, observation#responseId,
                observation#usage#inputTokens, observation#usage#outputTokens, observation#usage#cost),
                outcome#decisions),
            probabilities = Vector.mapWithIndex((ordinal, observation) ->
                Map.toVector(observation#probabilities)
                |> Vector.map(match (action, probability) ->
                    (Decide.actionKey(action), probability))
                |> Vector.sortBy(fst)
                |> Vector.map(match (action, probability) ->
                    probabilityRow(instanceId, ordinal, action, probability)), outcome#decisions)
                |> Vector.flatten
        }
    }

    pub def write(
        summaryPath: String,
        rankingPath: String,
        decisionsPath: String,
        probabilitiesPath: String,
        tables: Tables
    ): Tables \ IO = {
        summary = ScientificTable.write(summaryPath, summary(), tables#summary),
        ranking = ScientificTable.write(rankingPath, ranking(), tables#ranking),
        decisions = ScientificTable.write(decisionsPath, decisions(), tables#decisions),
        probabilities = ScientificTable.write(probabilitiesPath, probabilities(), tables#probabilities)
    }

    pub def read(
        summaryPath: String,
        rankingPath: String,
        decisionsPath: String,
        probabilitiesPath: String
    ): Result[String, Tables] \ IO = validate({
        summary = ScientificTable.read(summaryPath, summary()),
        ranking = ScientificTable.read(rankingPath, ranking()),
        decisions = ScientificTable.read(decisionsPath, decisions()),
        probabilities = ScientificTable.read(probabilitiesPath, probabilities())
    })

    pub def exactEqual(left: Tables, right: Tables): Bool =
        left#summary == right#summary and left#ranking == right#ranking and
        sameRows(left#decisions, right#decisions, sameDecision) and
        sameRows(left#probabilities, right#probabilities, sameProbability)

    pub def equalityPart(left: Tables, right: Tables): String =
        if (left#summary != right#summary) "summary"
        else if (left#ranking != right#ranking) "ranking"
        else if (not sameRows(left#decisions, right#decisions, sameDecision)) "decisions"
        else if (not sameRows(left#probabilities, right#probabilities, sameProbability)) "probabilities"
        else "equal"

    def sameRows(
        left: Vector[ScientificTable.Row],
        right: Vector[ScientificTable.Row],
        same: (ScientificTable.Row, ScientificTable.Row) -> Bool
    ): Bool = Vector.length(left) == Vector.length(right) and
        Vector.forAll(match (left0, right0) -> same(left0, right0), Vector.zip(left, right))

    def sameDecision(left: ScientificTable.Row, right: ScientificTable.Row): Bool =
        Vector.forAll(match name -> string(name, left) == string(name, right), Vector#{
            "protocol", "instance_id", "choice", "provider", "actual_model", "response_id"
        }) and
        Vector.forAll(match name -> integer(name, left) == integer(name, right), Vector#{
            "ordinal", "choice_index"
        }) and
        floating("confidence", left) == floating("confidence", right) and
        optionalInteger("input_tokens", left) == optionalInteger("input_tokens", right) and
        optionalInteger("output_tokens", left) == optionalInteger("output_tokens", right) and
        optionalFloating("cost", left) == optionalFloating("cost", right)

    def sameProbability(left: ScientificTable.Row, right: ScientificTable.Row): Bool =
        Vector.forAll(match name -> string(name, left) == string(name, right), Vector#{
            "protocol", "instance_id", "action"
        }) and integer("decision_ordinal", left) == integer("decision_ordinal", right) and
        floating("probability", left) == floating("probability", right)

    pub def identity(tables: Tables): String \ IO =
        ScientificIdentity.versioned("localization-prediction-v2",
            "summary=" + ScientificTable.canonicalRows(tables#summary) +
            "\nranking=" + ScientificTable.canonicalRows(tables#ranking) +
            "\ndecisions=" + ScientificTable.canonicalRows(tables#decisions) +
            "\nprobabilities=" + ScientificTable.canonicalRows(tables#probabilities))

    pub def rankingIdentities(instanceId: String, tables: Tables): Result[String, Vector[String]] = forM (
        actual <- tableInstance(tables);
        _ <- equal("prediction instance", instanceId, actual);
        orderedRows <- ordered("prediction ranking", "rank", tables#ranking);
        values <- Vector.traverse(row -> string("semantic_id", row), orderedRows)
    ) yield values

    pub def responseIds(tables: Tables): Result[String, Set[String]] =
        Vector.traverse(row -> string("response_id", row), tables#decisions)
        |> Result.map(Vector.toSet)

    pub def summaryRow(
        condition: String,
        instanceId: String,
        repository: String,
        baseRevision: String,
        path: Vector[String],
        decisionCount: Int32,
        statesInterned: Int32,
        memoEntries: Int32,
        memoSlots: Int32
    ): ScientificTable.Row = Map#{
        "protocol" => Value.Text(protocol()), "condition" => Value.Text(condition),
        "instance_id" => Value.Text(instanceId), "repository" => Value.Text(repository),
        "base_revision" => Value.Text(baseRevision), "path" => Value.TextList(path),
        "decision_count" => Value.Int32(decisionCount),
        "states_interned" => Value.Int32(statesInterned),
        "memo_entries" => Value.Int32(memoEntries), "memo_slots" => Value.Int32(memoSlots)
    }

    pub def rankingRow(instanceId: String, rank: Int32, semanticId: String): ScientificTable.Row = Map#{
        "protocol" => Value.Text(protocol()), "instance_id" => Value.Text(instanceId),
        "rank" => Value.Int32(rank), "semantic_id" => Value.Text(semanticId)
    }

    pub def decisionRow(
        instanceId: String,
        ordinal: Int32,
        choice: String,
        choiceIndex: Int32,
        confidence: Float64,
        provider: String,
        actualModel: String,
        responseId: String,
        inputTokens: Option[Int32],
        outputTokens: Option[Int32],
        cost: Option[Float64]
    ): ScientificTable.Row = Map#{
        "protocol" => Value.Text(protocol()), "instance_id" => Value.Text(instanceId),
        "ordinal" => Value.Int32(ordinal), "choice" => Value.Text(choice),
        "choice_index" => Value.Int32(choiceIndex), "confidence" => Value.Float64(confidence),
        "provider" => Value.Text(provider), "actual_model" => Value.Text(actualModel),
        "response_id" => Value.Text(responseId), "input_tokens" => optionalInt(inputTokens),
        "output_tokens" => optionalInt(outputTokens), "cost" => optionalFloat(cost)
    }

    pub def probabilityRow(
        instanceId: String,
        decisionOrdinal: Int32,
        action: String,
        probability: Float64
    ): ScientificTable.Row = Map#{
        "protocol" => Value.Text(protocol()), "instance_id" => Value.Text(instanceId),
        "decision_ordinal" => Value.Int32(decisionOrdinal), "action" => Value.Text(action),
        "probability" => Value.Float64(probability)
    }

    def validate(tables: Tables): Result[String, Tables] = forM (
        summary0 <- exactlyOne("prediction summary", tables#summary);
        instanceId <- string("instance_id", summary0);
        _ <- requireProtocol(summary0);
        decisionCount <- integer("decision_count", summary0);
        ranking0 <- ordered("prediction ranking", "rank", tables#ranking);
        decisions0 <- ordered("prediction decision", "ordinal", tables#decisions);
        _ <- if (decisionCount == Vector.length(decisions0)) Ok(()) else Err("prediction decision count mismatch");
        _ <- Vector.traverse(row -> requireInstance(instanceId, row), ranking0);
        _ <- Vector.traverse(row -> requireInstance(instanceId, row), decisions0);
        _ <- Vector.traverse(row -> validateProbability(instanceId, decisionCount, row), tables#probabilities)
    ) yield {summary = Vector#{summary0}, ranking = ranking0, decisions = decisions0,
        probabilities = canonicalProbabilities(tables#probabilities)}

    def tableInstance(tables: Tables): Result[String, String] = forM (
        row <- exactlyOne("prediction summary", tables#summary);
        instanceId <- string("instance_id", row)
    ) yield instanceId

    def requireInstance(instanceId: String, row: ScientificTable.Row): Result[String, Unit] = forM (
        _ <- requireProtocol(row);
        actual <- string("instance_id", row);
        _ <- equal("prediction row instance", instanceId, actual)
    ) yield ()

    def validateProbability(instanceId: String, decisionCount: Int32, row: ScientificTable.Row): Result[String, Unit] = forM (
        _ <- requireInstance(instanceId, row);
        ordinal <- integer("decision_ordinal", row);
        _ <- if (ordinal >= 0 and ordinal < decisionCount) Ok(()) else Err("prediction probability decision ordinal is invalid");
        _ <- string("action", row); _ <- floating("probability", row)
    ) yield ()

    def canonicalProbabilities(rows: Vector[ScientificTable.Row]): Vector[ScientificTable.Row] =
        Vector.sortBy(row -> {
            let ordinal = match integer("decision_ordinal", row) {
                case Ok(value) => value
                case Err(_) => -1
            };
            let action = match string("action", row) {
                case Ok(value) => value
                case Err(_) => ""
            };
            (ordinal, action)
        }, rows)

    def requireProtocol(row: ScientificTable.Row): Result[String, Unit] = forM (
        actual <- string("protocol", row);
        _ <- equal("prediction protocol", protocol(), actual)
    ) yield ()

    def ordered(name: String, ordinalName: String, rows: Vector[ScientificTable.Row]): Result[String, Vector[ScientificTable.Row]] = {
        let decoded = Vector.traverse(row -> integer(ordinalName, row) |> Result.map(ordinal -> (ordinal, row)), rows);
        decoded |> Result.flatMap(values -> {
            // Migration and replay emit canonical ordinal order. Checking that
            // linear form avoids Flix's recursive quicksort on large rankings;
            // non-canonical external input still takes the sorting path.
            let sorted = if (ordinalsOrdered(values)) values else Vector.sortBy(fst, values);
            match Vector.find(match (index, entry) -> fst(entry) != index,
                Vector.mapWithIndex((index, entry) -> (index, entry), sorted)) {
                case Some(_) => Err("${name} ordinals must be contiguous from zero")
                case None => Ok(Vector.map(snd, sorted))
            }
        })
    }

    def ordinalsOrdered(values: Vector[(Int32, a)]): Bool =
        Vector.forAll(match (index, entry) -> fst(entry) == index,
            Vector.mapWithIndex((index, entry) -> (index, entry), values))

    def exactlyOne(name: String, rows: Vector[a]): Result[String, a] =
        if (Vector.length(rows) == 1) Ok(Vector.get(0, rows))
        else Err("${name} requires exactly one row")

    def equal(name: String, expected: String, actual: String): Result[String, Unit] =
        if (expected == actual) Ok(()) else Err("${name} mismatch")

    def string(name: String, row: ScientificTable.Row): Result[String, String] =
        ScientificTable.text(row, name)

    def integer(name: String, row: ScientificTable.Row): Result[String, Int32] =
        ScientificTable.int32(row, name)

    def floating(name: String, row: ScientificTable.Row): Result[String, Float64] =
        ScientificTable.float64(row, name)

    def optionalInteger(name: String, row: ScientificTable.Row): Result[String, Option[Int32]] =
        ScientificTable.optionalInt32(row, name)

    def optionalFloating(name: String, row: ScientificTable.Row): Result[String, Option[Float64]] =
        ScientificTable.optionalFloat64(row, name)

    def optionalInt(value: Option[Int32]): ScientificTable.Value = match value {
        case Some(value0) => Value.Int32(value0)
        case None => Value.Null
    }

    def optionalFloat(value: Option[Float64]): ScientificTable.Value = match value {
        case Some(value0) => Value.Float64(value0)
        case None => Value.Null
    }

    def text(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Text, nullable = false}
    def textList(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.TextList, nullable = false}
    def int32(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Int32, nullable = false}
    def optionalInt32(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Int32, nullable = true}
    def float64(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Float64, nullable = false}
    def optionalFloat64(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Float64, nullable = true}
}
