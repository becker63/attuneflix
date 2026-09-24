/// Typed durable decision bundles used by keyless Bazel replay.
///
/// Raw provider envelopes remain the irreplaceable paid evidence. This table
/// is a deterministic per-case projection containing every exact request and
/// response acquired while producing that case, including discarded planning
/// branches. Loading it once gives the replay handler a small immutable map
/// instead of repeatedly scanning a repository-wide observation store.
pub mod Decide.Table {
    use Util.Json
    use Util.Json.Json.{JObject, JString}
    use ScientificTable.Value

    pub def schema(): ScientificTable.Schema = {
        format = "attune-decision-bundle-v1",
        columns = Vector#{
            text("bundle_protocol"), text("provider"), text("model"),
            text("decision_id"), text("response_id"), text("response")
        }
    }

    pub def protocol(): String = "attune-keyless-decision-bundle-v1"

    /// Admit one immutable v1 raw provider envelope into the typed bundle.
    /// Both the request identity and provider response remain byte-for-byte.
    pub def row(payload: String): Result[String, ScientificTable.Row] =
        match Json.parse(payload) {
            case Err(error) => Err(ToString.toString(error))
            case Ok(JObject(fields)) => forM (
                version <- integer("version", fields);
                _ <- if (version == 1) Ok(()) else Err("unsupported decision envelope version");
                provider <- rawString("provider", fields);
                _ <- if (provider == Decide.provider()) Ok(()) else Err("decision provider mismatch");
                model <- rawString("model", fields);
                _ <- if (model == Decide.model()) Ok(()) else Err("decision model mismatch");
                decision <- rawString("decision_id", fields);
                response <- rawString("response", fields);
                responseId <- providerResponseId(response)
            ) yield Map#{
                "bundle_protocol" => Value.Text(protocol()),
                "provider" => Value.Text(provider),
                "model" => Value.Text(model),
                "decision_id" => Value.Text(decision),
                "response_id" => Value.Text(responseId),
                "response" => Value.Text(response)
            }
            case Ok(_) => Err("decision envelope must be an object")
        }

    pub def write(path: String, rows: Vector[ScientificTable.Row]): Vector[ScientificTable.Row] \ IO =
        ScientificTable.write(path, schema(), rows)

    pub def read(path: String): Result[String, Map[Radii.Evaluate.DecisionId, Decide.Wire]] \ IO = {
        let rows = ScientificTable.read(path, schema());
        let decoded = Vector.traverse(decodeRow, rows);
        decoded |> Result.flatMap(values -> {
            let wires = Vector.toMap(values);
            if (Map.size(wires) == Vector.length(values)) Ok(wires)
            else Err("decision bundle contains a duplicate decision identity")
        })
    }

    pub def responseId(row0: ScientificTable.Row): Result[String, String] =
        ScientificTable.text(row0, "response_id")

    pub def decisionId(row0: ScientificTable.Row): Result[String, String] =
        ScientificTable.text(row0, "decision_id")

    def decodeRow(row0: ScientificTable.Row): Result[String, (Radii.Evaluate.DecisionId, Decide.Wire)] = forM (
        actualProtocol <- ScientificTable.text(row0, "bundle_protocol");
        _ <- if (actualProtocol == protocol()) Ok(()) else Err("decision bundle protocol mismatch");
        provider <- ScientificTable.text(row0, "provider");
        _ <- if (provider == Decide.provider()) Ok(()) else Err("decision bundle provider mismatch");
        model <- ScientificTable.text(row0, "model");
        _ <- if (model == Decide.model()) Ok(()) else Err("decision bundle model mismatch");
        identity <- ScientificTable.text(row0, "decision_id");
        response <- ScientificTable.text(row0, "response");
        expectedResponseId <- ScientificTable.text(row0, "response_id");
        actualResponseId <- providerResponseId(response);
        _ <- if (actualResponseId == expectedResponseId) Ok(()) else Err("decision response identity mismatch")
    ) yield (Radii.Evaluate.DecisionId.DecisionId(identity), Decide.Wire.Wire(response))

    def providerResponseId(payload: String): Result[String, String] =
        match Json.parse(payload) {
            case Err(error) => Err(ToString.toString(error))
            case Ok(JObject(fields)) => rawString("id", fields)
            case Ok(_) => Err("provider decision response must be an object")
        }

    def rawString(name: String, fields: Map[String, Json]): Result[String, String] =
        match Map.get(name, fields) {
            case Some(JString(value)) => Ok(value)
            case Some(_) => Err("${name} must be text")
            case None => Err("missing ${name}")
        }

    def integer(name: String, fields: Map[String, Json]): Result[String, Int32] =
        match Map.get(name, fields) {
            case Some(value) => Util.Json.FromJson.fromJson(value)
                |> Result.mapErr(ToString.toString)
            case None => Err("missing ${name}")
        }

    def text(name: String): ScientificTable.Column = {
        name = name, kind = ScientificTable.ColumnType.Text, nullable = false
    }
}
