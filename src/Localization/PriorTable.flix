/// Typed semantic-prior data used by Localization.
///
/// The provider observations remain immutable paid evidence. These tables are
/// their deterministic, reusable projection: one protocol row, the exact
/// document corpus, and the exact ranked field consumed by Atlas.
pub mod Localization.PriorTable {
    use Util.Json
    use Util.Json.Json.{JNull, JString}
    use Util.Json.FromJson
    use Util.Json.ToJson

    pub type alias Tables = {
        metadata = Vector[ScientificTable.Row],
        documents = Vector[ScientificTable.Row],
        ranking = Vector[ScientificTable.Row]
    }

    pub def protocol(): String = "attune-semantic-prior-v1"

    pub def metadata(): ScientificTable.Schema = {
        format = "attune-semantic-prior-metadata-v1",
        columns = Vector#{
            text("protocol"), text("instance_id"), text("repository"),
            text("base_revision"), text("provider"), text("model"),
            text("instruction"), int32("text_limit"), int32("dimension"),
            text("issue_revision"), int32("replayed"), int32("live"),
            optionalInt32("input_tokens"), optionalInt32("total_tokens")
        }
    }

    pub def documents(): ScientificTable.Schema = {
        format = "attune-semantic-prior-documents-v1",
        columns = Vector#{
            text("protocol"), text("instance_id"), int32("ordinal"),
            text("semantic_id"), text("node_id"), text("path"), text("name"),
            int32("start_byte"), int32("end_byte")
        }
    }

    pub def ranking(): ScientificTable.Schema = {
        format = "attune-semantic-prior-ranking-v1",
        columns = Vector#{
            text("protocol"), text("instance_id"), int32("rank"),
            text("semantic_id"), float64("score"), int32("document_ordinal")
        }
    }

    pub def write(
        metadataPath: String,
        documentsPath: String,
        rankingPath: String,
        tables: Tables
    ): Tables \ IO = {
        metadata = ScientificTable.write(metadataPath, metadata(), tables#metadata),
        documents = ScientificTable.write(documentsPath, documents(), tables#documents),
        ranking = ScientificTable.write(rankingPath, ranking(), tables#ranking)
    }

    pub def exactEqual(left: Tables, right: Tables): Bool =
        left#metadata == right#metadata and left#documents == right#documents and
        rankingValues(left#ranking) == rankingValues(right#ranking)

    pub def equalityPart(left: Tables, right: Tables): String =
        if (left#metadata != right#metadata) "metadata"
        else if (left#documents != right#documents) "documents"
        else if (rankingValues(left#ranking) != rankingValues(right#ranking)) "ranking"
        else "equal"

    def rankingValues(rows: Vector[ScientificTable.Row]): Result[String, Vector[(Int32, String, Float64, Int32)]] =
        Vector.traverse(row -> forM (
            rank <- integer("rank", row);
            semanticId <- string("semantic_id", row);
            score <- floating("score", row);
            ordinal <- integer("document_ordinal", row)
        ) yield (rank, semanticId, score, ordinal), rows)

    pub def read(
        metadataPath: String,
        documentsPath: String,
        rankingPath: String,
        expectedInstance: String
    ): Result[String, Localization.Tree.Prior] \ IO = {
        let tables = {
            metadata = ScientificTable.read(metadataPath, metadata()),
            documents = ScientificTable.read(documentsPath, documents()),
            ranking = ScientificTable.read(rankingPath, ranking())
        };
        prior(tables, expectedInstance)
    }

    pub def prior(tables: Tables, expectedInstance: String): Result[String, Localization.Tree.Prior] = forM (
        row <- exactlyOne("semantic-prior metadata", tables#metadata);
        _ <- requireProtocol(row);
        instanceId <- string("instance_id", row);
        _ <- equal("semantic-prior instance", expectedInstance, instanceId);
        repository <- string("repository", row);
        baseRevision <- string("base_revision", row);
        documentRows <- ordered("document", "ordinal", tables#documents);
        _ <- Vector.traverse(document -> validateDocument(instanceId, document), documentRows);
        rankingRows <- ordered("ranking", "rank", tables#ranking);
        ranking0 <- Vector.traverse(row0 -> decodeRanking(instanceId, documentRows, row0), rankingRows)
    ) yield {
        instanceId = instanceId,
        repository = repository,
        baseCommit = baseRevision,
        ranking = ranking0
    }

    pub def metadataRow(
        instanceId: String,
        repository: String,
        baseRevision: String,
        provider: String,
        model: String,
        instruction: String,
        textLimit: Int32,
        dimension: Int32,
        issueRevision: String,
        replayed: Int32,
        live: Int32,
        inputTokens: Option[Int32],
        totalTokens: Option[Int32]
    ): ScientificTable.Row = Map#{
        "protocol" => JString(protocol()), "instance_id" => JString(instanceId),
        "repository" => JString(repository), "base_revision" => JString(baseRevision),
        "provider" => JString(provider), "model" => JString(model),
        "instruction" => JString(instruction), "text_limit" => ToJson.toJson(textLimit),
        "dimension" => ToJson.toJson(dimension), "issue_revision" => JString(issueRevision),
        "replayed" => ToJson.toJson(replayed), "live" => ToJson.toJson(live),
        "input_tokens" => ToJson.toJson(inputTokens), "total_tokens" => ToJson.toJson(totalTokens)
    }

    pub def documentRow(
        instanceId: String,
        ordinal: Int32,
        semanticId: String,
        nodeId: String,
        path: String,
        name: String,
        startByte: Int32,
        endByte: Int32
    ): ScientificTable.Row = Map#{
        "protocol" => JString(protocol()), "instance_id" => JString(instanceId),
        "ordinal" => ToJson.toJson(ordinal), "semantic_id" => JString(semanticId),
        "node_id" => JString(nodeId), "path" => JString(path), "name" => JString(name),
        "start_byte" => ToJson.toJson(startByte), "end_byte" => ToJson.toJson(endByte)
    }

    pub def rankingRow(
        instanceId: String,
        rank: Int32,
        semanticId: String,
        score: Float64,
        documentOrdinal: Int32
    ): ScientificTable.Row = Map#{
        "protocol" => JString(protocol()), "instance_id" => JString(instanceId),
        "rank" => ToJson.toJson(rank), "semantic_id" => JString(semanticId),
        "score" => ToJson.toJson(score), "document_ordinal" => ToJson.toJson(documentOrdinal)
    }

    def validateDocument(instanceId: String, row: ScientificTable.Row): Result[String, Unit] = forM (
        _ <- requireProtocol(row);
        actual <- string("instance_id", row);
        _ <- equal("semantic-prior document instance", instanceId, actual);
        start <- integer("start_byte", row);
        end <- integer("end_byte", row);
        _ <- if (start >= 0 and end >= start) Ok(()) else Err("invalid semantic-prior document byte range");
        _ <- string("semantic_id", row); _ <- string("node_id", row);
        _ <- string("path", row); _ <- string("name", row)
    ) yield ()

    def decodeRanking(
        instanceId: String,
        documents0: Vector[ScientificTable.Row],
        row: ScientificTable.Row
    ): Result[String, Localization.Ranked] = forM (
        _ <- requireProtocol(row);
        actual <- string("instance_id", row);
        _ <- equal("semantic-prior ranking instance", instanceId, actual);
        identity <- string("semantic_id", row);
        score <- floating("score", row);
        ordinal <- integer("document_ordinal", row);
        _ <- if (ordinal >= 0 and ordinal < Vector.length(documents0)) Ok(())
             else Err("semantic-prior ranking has an invalid document ordinal");
        documentIdentity <- string("semantic_id", Vector.get(ordinal, documents0));
        _ <- equal("semantic-prior ranking/document identity", documentIdentity, identity)
    ) yield {identity = identity, score = score, ordinal = ordinal}

    def requireProtocol(row: ScientificTable.Row): Result[String, Unit] = forM (
        actual <- string("protocol", row);
        _ <- equal("semantic-prior protocol", protocol(), actual)
    ) yield ()

    def ordered(name: String, ordinalName: String, rows: Vector[ScientificTable.Row]): Result[String, Vector[ScientificTable.Row]] = {
        let decoded = Vector.traverse(row -> integer(ordinalName, row) |> Result.map(ordinal -> (ordinal, row)), rows);
        decoded |> Result.flatMap(values -> {
            // Canonical migrations write ordinal order. Avoid feeding tens of
            // thousands of already-sorted rows to Flix's recursive quicksort.
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

    def string(name: String, fields: Map[String, Json]): Result[String, String] =
        match Map.get(name, fields) {
            case Some(JString(value)) => Ok(value)
            case Some(_) => Err("${name} must be text")
            case None => Err("missing ${name}")
        }

    def integer(name: String, fields: Map[String, Json]): Result[String, Int32] =
        match Map.get(name, fields) {
            case Some(value) => FromJson.fromJson(value) |> Result.mapErr(ToString.toString)
            case None => Err("missing ${name}")
        }

    def floating(name: String, fields: Map[String, Json]): Result[String, Float64] =
        match Map.get(name, fields) {
            case Some(value) => FromJson.fromJson(value) |> Result.mapErr(ToString.toString)
            case None => Err("missing ${name}")
        }

    def text(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Text, nullable = false}
    def int32(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Int32, nullable = false}
    def optionalInt32(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Int32, nullable = true}
    def float64(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Float64, nullable = false}
}
