/// Frozen localization prediction wire semantics.
///
/// This module moved out of the experiment test runner so replay, migration,
/// and equality actions share one encoder. The v1 object is retained exactly
/// for pre/post-refactor parity; newer typed tables may be derived from it.
pub mod Localization.Result {
    use Util.Json
    use Util.Json.Json.{JArray, JObject, JString}
    use Util.Json.FromJson
    use Util.Json.ToJson

    pub def encode(
        prepared: Localization.Prepared,
        outcome: Localization.Tree.Outcome
    ): String = Json.toCompactString(JObject(Map#{
        "version" => ToJson.toJson(1),
        "condition" => JString("frozen-iteration-013"),
        "instance_id" => JString(prepared#instanceId),
        "repository" => JString(prepared#repository),
        "base_revision" => JString(prepared#baseCommit),
        "path" => JArray(Vector.map(atom ->
            JString(Decide.actionKey(Decide.Action.Follow(atom))), outcome#path)),
        "decision_count" => ToJson.toJson(Vector.length(outcome#decisions)),
        "decisions" => JArray(Vector.map(decisionJson, outcome#decisions)),
        "ranking" => JArray(Vector.map(item -> JString(item#identity), outcome#ranking)),
        "structural_work" => JObject(Map#{
            "states_interned" => ToJson.toJson(outcome#metrics#statesInterned),
            "memo_entries" => ToJson.toJson(outcome#metrics#memoEntries),
            "memo_slots" => ToJson.toJson(outcome#metrics#memoSlots)
        })
    }))

    /// Provider response IDs referenced by one frozen prediction. They are
    /// operational join keys for the one-time typed-bundle migration, never a
    /// substitute for reconstructing and checking the full decision identity.
    pub def responseIds(payload: String): Result[String, Set[String]] =
        match Json.parse(payload) {
            case Err(error) => Err(ToString.toString(error))
            case Ok(JObject(fields)) => forM (
                version <- integer("version", fields);
                _ <- if (version == 1) Ok(()) else Err("unsupported localization result version");
                decisions <- array("decisions", fields);
                ids <- Vector.traverse(responseId, decisions)
            ) yield Vector.toSet(ids)
            case Ok(_) => Err("localization result must be an object")
        }

    pub def instanceId(payload: String): Result[String, String] =
        match Json.parse(payload) {
            case Err(error) => Err(ToString.toString(error))
            case Ok(JObject(fields)) => string("instance_id", fields)
            case Ok(_) => Err("localization result must be an object")
        }

    def decisionJson(observation: Decide.Observation): Json = JObject(Map#{
        "choice" => JString(Decide.actionKey(observation#choice)),
        "choice_index" => ToJson.toJson(observation#choiceIndex),
        "probabilities" => JObject(Map.toVector(observation#probabilities)
            |> Vector.map(match (action, probability) ->
                (Decide.actionKey(action), ToJson.toJson(probability)))
            |> Vector.toMap),
        "confidence" => ToJson.toJson(observation#confidence),
        "provider" => JString(observation#provider),
        "actual_model" => JString(observation#actualModel),
        "response_id" => JString(observation#responseId),
        "input_tokens" => ToJson.toJson(observation#usage#inputTokens),
        "output_tokens" => ToJson.toJson(observation#usage#outputTokens),
        "cost" => ToJson.toJson(observation#usage#cost)
    })

    def responseId(value: Json): Result[String, String] = match value {
        case JObject(fields) => string("response_id", fields)
        case _ => Err("localization decision must be an object")
    }

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

    def array(name: String, fields: Map[String, Json]): Result[String, Vector[Json]] =
        match Map.get(name, fields) {
            case Some(JArray(values)) => Ok(values)
            case Some(_) => Err("${name} must be an array")
            case None => Err("missing ${name}")
        }
}
