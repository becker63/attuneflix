/// Jev choice requests and admitted observations under `attune-jev-families-v1`.
///
/// A request is one choice question about one model-visible state. Its
/// identity covers the protocol, provider, endpoint, model, world snapshot,
/// exact payload, the exact semantic state, and every ordered alternative with
/// its exact semantic target, because previews are bounded and two different
/// frontiers can share one payload.
pub mod Families.Decision {
    use Util.Json
    use Util.Json.Json.{JObject, JString}

    pub type alias Alternative = {
        key       = String,
        criterion = String,
        target    = String
    }

    pub type alias Request = {
        question     = String,
        alternatives = Vector[Alternative],
        provider     = Families.Provider.Request
    }

    pub type alias Observation = {
        identity      = String,
        choice        = String,
        choiceIndex   = Int32,
        confidence    = Float64,
        probabilities = Vector[(String, Float64)],
        provider      = String,
        servedModel   = String,
        responseId    = String,
        inputTokens   = Option[Int32],
        outputTokens  = Option[Int32],
        cost          = Option[Float64]
    }

    pub def request(
        snapshotId: String,
        stateId: String,
        state: String,
        question: String,
        instructions: String,
        alternatives: Vector[Alternative]
    ): Result[String, Request] \ IO = {
        let keys = Vector.map(alternative -> alternative#key, alternatives);
        if (Vector.length(alternatives) < 2) Err("a choice needs at least two alternatives")
        else if (Set.size(Vector.toSet(keys)) != Vector.length(keys)) Err("duplicate alternative keys: ${Vector.join(",", keys)}")
        else {
            let payload = Json.toCompactString(JObject(Map#{
                "model" => JString(Families.Protocol.decisionModel()),
                "state" => JString(state),
                "questions" => JObject(Map#{
                    question => JObject(Map#{
                        "type" => JString("choice"),
                        "instructions" => JString(instructions),
                        "criteria" => JObject(Vector.map(alternative ->
                            (alternative#key, JString(alternative#criterion)), alternatives) |> Vector.toMap)
                    })
                })
            }));
            let identity = Families.Evidence.identity(Families.Protocol.decisions(), Vector.append(Vector#{
                Families.Protocol.provider(), Families.Protocol.decisionEndpoint(), Families.Protocol.decisionModel(),
                snapshotId, payload, stateId
            }, Vector.flatMap(alternative -> Vector#{alternative#key, alternative#target}, alternatives)));
            Ok({
                question = question,
                alternatives = alternatives,
                provider = {kind = Families.Provider.Kind.Decision, identity = identity, payload = payload, inputs = Vector.empty()}
            })
        }
    }

    /// Admits one provider body: the typed choice answer, its per-alternative
    /// probabilities in alternative order, and the provider's own usage.
    pub def admit(request0: Request, body: String): Result[String, Observation] = forM (
        fields <- Families.Wire.body(body);
        answers <- Families.Wire.object("answers", fields);
        answer <- Families.Wire.object(request0#question, answers);
        answerType <- Families.Wire.text("type", answer);
        _ <- if (answerType == "choice") Ok(()) else Err("expected a choice answer, got ${answerType}");
        choice <- Families.Wire.text("choice", answer);
        choiceIndex <- indexOf(choice, request0#alternatives);
        confidence <- Families.Wire.float64("confidence", answer);
        reported <- Families.Wire.object("probabilities", answer);
        probabilities <- Vector.traverse(alternative -> Families.Wire.float64(alternative#key, reported)
            |> Result.map(probability -> (alternative#key, probability)), request0#alternatives);
        servedModel <- Families.Wire.text("model", fields);
        _ <- servedModelMatches(servedModel);
        provider <- Families.Wire.text("provider", fields);
        responseId <- Families.Wire.text("id", fields);
        usage <- Families.Wire.usage(fields);
        inputTokens <- Families.Wire.optionalInt32("input_tokens", usage);
        outputTokens <- Families.Wire.optionalInt32("output_tokens", usage);
        cost <- Families.Wire.optionalFloat64("cost", usage)
    ) yield {
        identity = request0#provider#identity, choice = choice, choiceIndex = choiceIndex,
        confidence = confidence, probabilities = probabilities, provider = provider,
        servedModel = servedModel, responseId = responseId, inputTokens = inputTokens,
        outputTokens = outputTokens, cost = cost
    }

    /// Asks the question through the provider boundary and admits the answer.
    pub def decide(request0: Request): Result[String, Observation] \ Families.Provider.Provider =
        Families.Provider.exchange(request0#provider) |> Result.flatMap(admit(request0))

    def indexOf(choice: String, alternatives: Vector[Alternative]): Result[String, Int32] =
        Vector.findIndexOf(alternative -> alternative#key == choice, alternatives)
            |> Option.toOk("choice ${choice} is not an offered alternative")

    /// The pinned model resolves to dated snapshots (`typesafe/jev-1.13-20260917`).
    def servedModelMatches(served: String): Result[String, Unit] = {
        let pinned = Families.Protocol.decisionModel();
        if (served == pinned or String.startsWith(prefix = pinned + "-", served)) Ok(())
        else Err("unexpected decision model ${served}")
    }
}
