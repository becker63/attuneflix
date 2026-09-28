/// Typed projections of the `families-embeddings-v1` space for one world: the
/// exact embedded documents and the admitted batch observations. Vectors stay
/// in the retained raw bodies; each batch row carries the SHA-256 of every
/// decoded vector, in document order, so a vector read later is checked
/// against its admitted digest.
pub mod Families.Embedding.Table {
    use ScientificTable.Value
    use ScientificTable.Columns.{boolean, int32, optionalFloat64, optionalInt32, optionalText, text, textList}

    pub def documents(): ScientificTable.Schema = {
        format = "attune-families-embedding-documents-v1",
        columns = Vector#{
            text("protocol"), text("snapshot_id"), int32("ordinal"), text("node_id"), text("path"),
            text("name"), int32("start_byte"), int32("end_byte"), boolean("truncated"), text("text")
        }
    }

    pub def batches(): ScientificTable.Schema = {
        format = "attune-families-embedding-batches-v1",
        columns = Vector#{
            text("protocol"), text("snapshot_id"), int32("batch"), text("identity"),
            optionalText("response_id"), optionalText("provider"), text("served_model"), optionalInt32("prompt_tokens"),
            optionalInt32("total_tokens"), optionalFloat64("cost_usd"), textList("vector_sha256")
        }
    }

    pub def documentRow(snapshotId: String, value: Families.Embedding.Document): ScientificTable.Row =
        Map.union(Families.Rows.header(documents(), snapshotId), Map#{
            "ordinal" => Value.Int32(value#ordinal),
            "node_id" => Value.Text(value#nodeId),
            "path" => Value.Text(value#path),
            "name" => Value.Text(value#name),
            "start_byte" => Value.Int32(value#startByte),
            "end_byte" => Value.Int32(value#endByte),
            "truncated" => Value.Boolean(value#truncated),
            "text" => Value.Text(value#text)
        })

    pub def batchRow(snapshotId: String, value: Families.Embedding.Observation): ScientificTable.Row =
        Map.union(Families.Rows.header(batches(), snapshotId), Map#{
            "batch" => Value.Int32(value#batch),
            "identity" => Value.Text(value#identity),
            "response_id" => ScientificTable.optionalTextValue(value#responseId),
            "provider" => ScientificTable.optionalTextValue(value#provider),
            "served_model" => Value.Text(value#servedModel),
            "prompt_tokens" => ScientificTable.optionalInt32Value(value#promptTokens),
            "total_tokens" => ScientificTable.optionalInt32Value(value#totalTokens),
            "cost_usd" => ScientificTable.optionalFloat64Value(value#cost),
            "vector_sha256" => Value.TextList(value#vectors)
        })

    /// Documents in contiguous ordinal order from zero.
    pub def decodeDocuments(snapshotId: String, rows: Vector[ScientificTable.Row]): Result[String, Vector[Families.Embedding.Document]] =
        Vector.traverse(decodeDocument(snapshotId), rows) |> Result.flatMap(values ->
            if (Vector.map(value -> value#ordinal, values) == Vector.range(0, Vector.length(values))) Ok(values)
            else Err("embedding documents must be contiguous from ordinal zero"))

    def decodeDocument(snapshotId: String, row: ScientificTable.Row): Result[String, Families.Embedding.Document] = forM (
        _ <- Families.Rows.require(documents(), snapshotId, row);
        ordinal <- ScientificTable.int32(row, "ordinal");
        nodeId <- ScientificTable.text(row, "node_id");
        path <- ScientificTable.text(row, "path");
        name <- ScientificTable.text(row, "name");
        startByte <- ScientificTable.int32(row, "start_byte");
        endByte <- ScientificTable.int32(row, "end_byte");
        truncated <- ScientificTable.boolean(row, "truncated");
        body <- ScientificTable.text(row, "text")
    ) yield {
        ordinal = ordinal, nodeId = nodeId, path = path, name = name,
        startByte = startByte, endByte = endByte, text = body, truncated = truncated
    }

    pub def decodeBatches(snapshotId: String, rows: Vector[ScientificTable.Row]): Result[String, Vector[Families.Embedding.Observation]] =
        Vector.traverse(decodeBatch(snapshotId), rows) |> Result.flatMap(values ->
            if (Vector.map(value -> value#batch, values) == Vector.range(0, Vector.length(values))) Ok(values)
            else Err("embedding batches must be contiguous from batch zero"))

    def decodeBatch(snapshotId: String, row: ScientificTable.Row): Result[String, Families.Embedding.Observation] = forM (
        _ <- Families.Rows.require(batches(), snapshotId, row);
        batch <- ScientificTable.int32(row, "batch");
        identity <- ScientificTable.text(row, "identity");
        responseId <- ScientificTable.optionalText(row, "response_id");
        provider <- ScientificTable.optionalText(row, "provider");
        servedModel <- ScientificTable.text(row, "served_model");
        promptTokens <- ScientificTable.optionalInt32(row, "prompt_tokens");
        totalTokens <- ScientificTable.optionalInt32(row, "total_tokens");
        cost <- ScientificTable.optionalFloat64(row, "cost_usd");
        vectors <- Families.Rows.textList(row, "vector_sha256")
    ) yield {
        batch = batch, identity = identity, responseId = responseId, provider = provider, servedModel = servedModel,
        promptTokens = promptTokens, totalTokens = totalTokens, cost = cost, vectors = vectors
    }
}
