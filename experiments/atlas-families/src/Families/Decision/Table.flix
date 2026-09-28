/// Typed projections of the `jev-families-raw-v1` space for one world: every
/// admitted decision in navigation order, and every seed's terminal family.
pub mod Families.Decision.Table {
    use ScientificTable.Value
    use ScientificTable.Columns.{boolean, float64, int32, optionalFloat64, optionalInt32, text, textList}

    /// One decision row: where it was asked, what was offered, what came back.
    pub type alias Entry = {
        seed        = Int32,
        step        = Int32,
        depth       = Int32,
        question    = String,
        route       = Vector[String],
        stateId     = String,
        keys        = Vector[String],
        targets     = Vector[String],
        observation = Families.Decision.Observation
    }

    /// One seed's family as recorded: the chosen route, the exact terminal
    /// frontier identity, and its name.
    pub type alias Family = {
        seed        = Int32,
        file        = Int32,
        path        = String,
        route       = Vector[String],
        domain      = String,
        cardinality = Int32,
        stateId     = String,
        name        = String,
        nameKind    = String,
        named       = Bool,
        decisions   = Int32
    }

    pub def decisions(): ScientificTable.Schema = {
        format = "attune-families-decisions-v1",
        columns = Vector#{
            text("protocol"), text("snapshot_id"), int32("seed"), int32("step"), int32("depth"),
            text("question"), textList("route"), text("state_id"), text("identity"),
            textList("alternatives"), textList("targets"), text("choice"), int32("choice_index"),
            float64("confidence"), textList("probabilities"), text("provider"), text("served_model"),
            text("response_id"), optionalInt32("input_tokens"), optionalInt32("output_tokens"),
            optionalFloat64("cost_usd")
        }
    }

    pub def outcomes(): ScientificTable.Schema = {
        format = "attune-families-outcomes-v1",
        columns = Vector#{
            text("protocol"), text("snapshot_id"), int32("seed"), int32("file"), text("path"),
            textList("route"), text("domain"), int32("cardinality"), text("state_id"), text("name"),
            text("name_kind"), boolean("named"), int32("decisions")
        }
    }

    pub def entries(outcome: Families.Navigation.Outcome): Vector[Entry] =
        Vector.mapWithIndex((step, record) -> {
            seed = record#seed,
            step = step,
            depth = record#depth,
            question = record#request#question,
            route = Vector.map(Families.Navigation.atomKey, record#route),
            stateId = record#stateId,
            keys = Vector.map(alternative -> alternative#key, record#request#alternatives),
            targets = Vector.map(alternative -> alternative#target, record#request#alternatives),
            observation = record#observation
        }, outcome#records)

    pub def family(world: Repository.World, outcome: Families.Navigation.Outcome): Family = {
        seed = outcome#seed,
        file = outcome#file,
        path = Vector.get(outcome#file, world#files),
        route = Vector.map(Families.Navigation.atomKey, outcome#route),
        domain = Families.Navigation.domainName(outcome#state),
        cardinality = Atlas.cardinality(outcome#state),
        stateId = outcome#stateId,
        name = outcome#name,
        nameKind = outcome#nameKind,
        named = outcome#named,
        decisions = Vector.length(outcome#records)
    }

    pub def decisionRow(snapshotId: String, value: Entry): ScientificTable.Row = {
        let observation = value#observation;
        Map.union(Families.Rows.header(decisions(), snapshotId), Map#{
            "seed" => Value.Int32(value#seed),
            "step" => Value.Int32(value#step),
            "depth" => Value.Int32(value#depth),
            "question" => Value.Text(value#question),
            "route" => Value.TextList(value#route),
            "state_id" => Value.Text(value#stateId),
            "identity" => Value.Text(observation#identity),
            "alternatives" => Value.TextList(value#keys),
            "targets" => Value.TextList(value#targets),
            "choice" => Value.Text(observation#choice),
            "choice_index" => Value.Int32(observation#choiceIndex),
            "confidence" => Value.Float64(observation#confidence),
            "probabilities" => Value.TextList(Vector.map(match (_, p) -> Families.Rows.decimal(p), observation#probabilities)),
            "provider" => Value.Text(observation#provider),
            "served_model" => Value.Text(observation#servedModel),
            "response_id" => Value.Text(observation#responseId),
            "input_tokens" => ScientificTable.optionalInt32Value(observation#inputTokens),
            "output_tokens" => ScientificTable.optionalInt32Value(observation#outputTokens),
            "cost_usd" => ScientificTable.optionalFloat64Value(observation#cost)
        })
    }

    pub def outcomeRow(snapshotId: String, value: Family): ScientificTable.Row =
        Map.union(Families.Rows.header(outcomes(), snapshotId), Map#{
            "seed" => Value.Int32(value#seed),
            "file" => Value.Int32(value#file),
            "path" => Value.Text(value#path),
            "route" => Value.TextList(value#route),
            "domain" => Value.Text(value#domain),
            "cardinality" => Value.Int32(value#cardinality),
            "state_id" => Value.Text(value#stateId),
            "name" => Value.Text(value#name),
            "name_kind" => Value.Text(value#nameKind),
            "named" => Value.Boolean(value#named),
            "decisions" => Value.Int32(value#decisions)
        })

    pub def decodeDecisions(snapshotId: String, rows: Vector[ScientificTable.Row]): Result[String, Vector[Entry]] =
        Vector.traverse(decodeDecision(snapshotId), rows)

    def decodeDecision(snapshotId: String, row: ScientificTable.Row): Result[String, Entry] = forM (
        _ <- Families.Rows.require(decisions(), snapshotId, row);
        seed <- ScientificTable.int32(row, "seed");
        step <- ScientificTable.int32(row, "step");
        depth <- ScientificTable.int32(row, "depth");
        question <- ScientificTable.text(row, "question");
        route <- Families.Rows.textList(row, "route");
        stateId <- ScientificTable.text(row, "state_id");
        identity <- ScientificTable.text(row, "identity");
        keys <- Families.Rows.textList(row, "alternatives");
        targets <- Families.Rows.textList(row, "targets");
        _ <- if (Vector.length(keys) == Vector.length(targets)) Ok(()) else Err("decision alternatives and targets differ in length");
        choice <- ScientificTable.text(row, "choice");
        choiceIndex <- ScientificTable.int32(row, "choice_index");
        _ <- if (Vector.nth(choiceIndex, keys) == Some(choice)) Ok(()) else Err("decision choice ${choice} is not alternative ${choiceIndex}");
        confidence <- Families.Rows.float64(row, "confidence");
        reported <- Families.Rows.textList(row, "probabilities");
        _ <- if (Vector.length(reported) == Vector.length(keys)) Ok(()) else Err("decision probabilities differ from its alternatives");
        probabilities <- Vector.traverse(Families.Rows.parseDecimal("probabilities"), reported);
        provider <- ScientificTable.text(row, "provider");
        servedModel <- ScientificTable.text(row, "served_model");
        responseId <- ScientificTable.text(row, "response_id");
        inputTokens <- ScientificTable.optionalInt32(row, "input_tokens");
        outputTokens <- ScientificTable.optionalInt32(row, "output_tokens");
        cost <- ScientificTable.optionalFloat64(row, "cost_usd")
    ) yield {
        seed = seed, step = step, depth = depth, question = question, route = route,
        stateId = stateId, keys = keys, targets = targets,
        observation = {
            identity = identity, choice = choice, choiceIndex = choiceIndex, confidence = confidence,
            probabilities = Vector.zip(keys, probabilities), provider = provider, servedModel = servedModel,
            responseId = responseId, inputTokens = inputTokens, outputTokens = outputTokens, cost = cost
        }
    }

    pub def decodeOutcomes(snapshotId: String, rows: Vector[ScientificTable.Row]): Result[String, Vector[Family]] =
        Vector.traverse(decodeOutcome(snapshotId), rows) |> Result.flatMap(values ->
            if (Vector.map(value -> value#seed, values) == Vector.range(0, Vector.length(values))) Ok(values)
            else Err("family outcomes must be contiguous from seed zero"))

    def decodeOutcome(snapshotId: String, row: ScientificTable.Row): Result[String, Family] = forM (
        _ <- Families.Rows.require(outcomes(), snapshotId, row);
        seed <- ScientificTable.int32(row, "seed");
        file <- ScientificTable.int32(row, "file");
        path <- ScientificTable.text(row, "path");
        route <- Families.Rows.textList(row, "route");
        domain <- ScientificTable.text(row, "domain");
        cardinality <- ScientificTable.int32(row, "cardinality");
        stateId <- ScientificTable.text(row, "state_id");
        name <- ScientificTable.text(row, "name");
        nameKind <- ScientificTable.text(row, "name_kind");
        named <- ScientificTable.boolean(row, "named");
        decisions0 <- ScientificTable.int32(row, "decisions")
    ) yield {
        seed = seed, file = file, path = path, route = route, domain = domain, cardinality = cardinality,
        stateId = stateId, name = name, nameKind = nameKind, named = named, decisions = decisions0
    }
}
