/// The per-pass cost ledger (`attune-families-ledger-v1`). Each space records
/// one row per world, derived only from the admitted observations and hence
/// from the provider's own usage and cost fields in the retained raw bodies;
/// keyless replay derives the same row again. The projected cost is the
/// protocol's pre-acquisition upper bound for the same world.
pub mod Families.Ledger {
    import java.nio.charset.StandardCharsets

    use ScientificTable.Value
    use ScientificTable.Columns.{float64, int32, int64, text}

    pub type alias Entry = {
        space        = String,
        kind         = String,
        requests     = Int32,
        reported     = Int32,
        inputTokens  = Int64,
        outputTokens = Int64,
        costUsd      = Float64,
        unitCostUsd  = Float64,
        projectedUsd = Float64,
        envelopeUsd  = Float64
    }

    pub def schema(): ScientificTable.Schema = {
        format = Families.Protocol.ledger(),
        columns = Vector#{
            text("protocol"), text("snapshot_id"), text("space"), text("request_kind"),
            int32("requests"), int32("cost_reported"), int64("input_tokens"), int64("output_tokens"),
            float64("cost_usd"), float64("unit_cost_usd"), float64("projected_usd"), float64("envelope_usd")
        }
    }

    pub def embeddings(documents: Vector[Families.Embedding.Document], observations: Vector[Families.Embedding.Observation], envelope: Float64): Entry \ IO =
        entry(
            Families.Protocol.embeddingSpace(), "embedding-batch",
            Vector.map(value -> (value#promptTokens, None, value#cost), observations),
            Families.Protocol.projectedEmbeddingUsd(documentBytes(documents)), envelope)

    pub def decisions(seeds: Int32, observations: Vector[Families.Decision.Observation], envelope: Float64): Entry =
        entry(
            Families.Protocol.decisionSpace(), "decision",
            Vector.map(value -> (value#inputTokens, value#outputTokens, value#cost), observations),
            Families.Protocol.projectedDecisionUsd(seeds), envelope)

    /// UTF-8 bytes of every embedded document, the token upper bound.
    pub def documentBytes(documents: Vector[Families.Embedding.Document]): Int64 \ IO =
        Vector.foldLeft((sum, document) ->
            sum + Int32.toInt64(Array.length(document#text.getBytes(StandardCharsets.UTF_8))), 0i64, documents)

    /// Usage per request: (input tokens, output tokens, cost), as reported.
    def entry(space: String, kind: String, usage: Vector[(Option[Int32], Option[Int32], Option[Float64])], projected: Float64, envelope: Float64): Entry = {
        let requests = Vector.length(usage);
        let tokens = values -> Vector.foldLeft((sum, value) -> sum + Int32.toInt64(Option.getWithDefault(0, value)), 0i64, values);
        let costs = Vector.map(match (_, _, value) -> value, usage);
        let cost = Vector.foldLeft((sum, value) -> sum + Option.getWithDefault(0.0, value), 0.0, costs);
        {
            space = space,
            kind = kind,
            requests = requests,
            reported = Vector.count(value -> not Option.isEmpty(value), costs),
            inputTokens = tokens(Vector.map(match (value, _, _) -> value, usage)),
            outputTokens = tokens(Vector.map(match (_, value, _) -> value, usage)),
            costUsd = cost,
            unitCostUsd = if (requests == 0) 0.0 else cost / Int32.toFloat64(requests),
            projectedUsd = projected,
            envelopeUsd = envelope
        }
    }

    pub def row(snapshotId: String, value: Entry): ScientificTable.Row =
        Map.union(Families.Rows.header(schema(), snapshotId), Map#{
            "space" => Value.Text(value#space),
            "request_kind" => Value.Text(value#kind),
            "requests" => Value.Int32(value#requests),
            "cost_reported" => Value.Int32(value#reported),
            "input_tokens" => Value.Int64(value#inputTokens),
            "output_tokens" => Value.Int64(value#outputTokens),
            "cost_usd" => Value.Float64(value#costUsd),
            "unit_cost_usd" => Value.Float64(value#unitCostUsd),
            "projected_usd" => Value.Float64(value#projectedUsd),
            "envelope_usd" => Value.Float64(value#envelopeUsd)
        })

    /// A space's ledger holds exactly one world's row.
    pub def decode(snapshotId: String, rows: Vector[ScientificTable.Row]): Result[String, Entry] =
        ScientificTable.exactlyOne("families ledger", rows) |> Result.flatMap(row -> forM (
            _ <- Families.Rows.require(schema(), snapshotId, row);
            space <- ScientificTable.text(row, "space");
            kind <- ScientificTable.text(row, "request_kind");
            requests <- ScientificTable.int32(row, "requests");
            reported <- ScientificTable.int32(row, "cost_reported");
            inputTokens <- Families.Rows.int64(row, "input_tokens");
            outputTokens <- Families.Rows.int64(row, "output_tokens");
            cost <- Families.Rows.float64(row, "cost_usd");
            unit <- Families.Rows.float64(row, "unit_cost_usd");
            projected <- Families.Rows.float64(row, "projected_usd");
            envelope <- Families.Rows.float64(row, "envelope_usd")
        ) yield {
            space = space, kind = kind, requests = requests, reported = reported,
            inputTokens = inputTokens, outputTokens = outputTokens, costUsd = cost,
            unitCostUsd = unit, projectedUsd = projected, envelopeUsd = envelope
        })
}
