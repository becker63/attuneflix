// One-time, lossless projection from the frozen JSON-tree Parquet artifacts
// into current typed semantic-prior and prediction tables. No provider is
// reachable from this executable.
import java.lang.System

use Util.Json
use Util.Json.Json.{JArray, JNull, JObject, JString}
use Util.Json.FromJson

def main(): Unit \ IO = {
    let priorPayload = ScientificData.readObject(property("attune.legacy_prior"));
    let predictionPayload = ScientificData.readObject(property("attune.legacy_prediction"));
    let prior = decodePrior(property("attune.instance_id"), priorPayload) |> require;
    let prediction = decodePrediction(property("attune.instance_id"), predictionPayload) |> require;
    let admittedPrior = Localization.PriorTable.write(
        property("attune.output_prior_metadata"), property("attune.output_prior_documents"),
        property("attune.output_prior_ranking"), prior);
    let admittedPrediction = Localization.PredictionTable.write(
        property("attune.output_prediction_summary"), property("attune.output_prediction_ranking"),
        property("attune.output_prediction_decisions"), property("attune.output_prediction_probabilities"),
        prediction);
    let instanceId = property("attune.instance_id");
    if (not Localization.PriorTable.exactEqual(admittedPrior, prior))
        bug!("typed semantic-prior migration round-trip mismatch: " +
            Localization.PriorTable.equalityPart(admittedPrior, prior))
    else if (not Localization.PredictionTable.exactEqual(admittedPrediction, prediction))
        bug!("typed prediction migration round-trip mismatch: " +
            Localization.PredictionTable.equalityPart(admittedPrediction, prediction))
    else println("LOCALIZATION_DATA_MIGRATION case=${instanceId}" +
        " documents=${Vector.length(prior#documents)} ranking=${Vector.length(prior#ranking)}" +
        " decisions=${Vector.length(prediction#decisions)} exact=true")
}

def decodePrior(instanceId: String, payload: String): Result[String, Localization.PriorTable.Tables] =
    parseObject("semantic-prior", payload) |> Result.flatMap(fields -> forM (
        _ <- keys("semantic-prior", Vector#{"version", "provider", "model", "instruction",
            "text_limit", "dimension", "issue_revision", "replayed", "live",
            "input_tokens", "total_tokens", "cases"}, fields);
        version <- integer("version", fields);
        _ <- if (version == 1) Ok(()) else Err("unsupported semantic-prior version");
        provider <- string("provider", fields); model <- string("model", fields);
        instruction <- string("instruction", fields); textLimit <- integer("text_limit", fields);
        dimension <- integer("dimension", fields); issueRevision <- string("issue_revision", fields);
        replayed <- integer("replayed", fields); live <- integer("live", fields);
        inputTokens <- optionalInteger("input_tokens", fields);
        totalTokens <- optionalInteger("total_tokens", fields);
        cases <- array("cases", fields);
        case0 <- exactlyOne("semantic-prior case", cases);
        caseFields <- object("semantic-prior case", case0);
        _ <- keys("semantic-prior case", Vector#{"instance_id", "repository", "base_commit",
            "documents", "ranking"}, caseFields);
        actualInstance <- string("instance_id", caseFields);
        _ <- equal("semantic-prior instance", instanceId, actualInstance);
        repository <- string("repository", caseFields);
        baseRevision <- string("base_commit", caseFields);
        documentValues <- array("documents", caseFields);
        documents <- Vector.mapWithIndex((ordinal, value) ->
            priorDocument(actualInstance, ordinal, value), documentValues) |> Vector.sequence;
        rankingValues <- array("ranking", caseFields);
        ranking <- Vector.mapWithIndex((rank, value) ->
            priorRanking(actualInstance, rank, value), rankingValues) |> Vector.sequence
    ) yield {
        metadata = Vector#{Localization.PriorTable.metadataRow(
            actualInstance, repository, baseRevision, provider, model, instruction,
            textLimit, dimension, issueRevision, replayed, live, inputTokens, totalTokens)},
        documents = documents,
        ranking = ranking
    })

def priorDocument(instanceId: String, expectedOrdinal: Int32, value: Json): Result[String, ScientificTable.Row] = forM (
    fields <- object("semantic-prior document", value);
    _ <- keys("semantic-prior document", Vector#{"semantic_id", "node_id", "path", "name",
        "start_byte", "end_byte", "ordinal"}, fields);
    semanticId <- string("semantic_id", fields); nodeId <- string("node_id", fields);
    path <- string("path", fields); name <- string("name", fields);
    start <- integer("start_byte", fields); end <- integer("end_byte", fields);
    ordinal <- integer("ordinal", fields);
    _ <- if (ordinal == expectedOrdinal) Ok(()) else Err("semantic-prior document order mismatch")
) yield Localization.PriorTable.documentRow(
    instanceId, ordinal, semanticId, nodeId, path, name, start, end)

def priorRanking(instanceId: String, rank: Int32, value: Json): Result[String, ScientificTable.Row] = forM (
    fields <- object("semantic-prior ranking", value);
    _ <- keys("semantic-prior ranking", Vector#{"semantic_id", "score", "ordinal"}, fields);
    semanticId <- string("semantic_id", fields); score <- floating("score", fields);
    ordinal <- integer("ordinal", fields)
) yield Localization.PriorTable.rankingRow(instanceId, rank, semanticId, score, ordinal)

def decodePrediction(instanceId: String, payload: String): Result[String, Localization.PredictionTable.Tables] =
    parseObject("localization prediction", payload) |> Result.flatMap(fields -> forM (
        _ <- keys("localization prediction", Vector#{"version", "condition", "instance_id",
            "repository", "base_revision", "path", "decision_count", "decisions", "ranking",
            "structural_work"}, fields);
        version <- integer("version", fields);
        _ <- if (version == 1) Ok(()) else Err("unsupported localization prediction version");
        condition <- string("condition", fields); actualInstance <- string("instance_id", fields);
        _ <- equal("prediction instance", instanceId, actualInstance);
        repository <- string("repository", fields); baseRevision <- string("base_revision", fields);
        path <- stringVector("path", fields); decisionCount <- integer("decision_count", fields);
        decisionValues <- array("decisions", fields);
        _ <- if (decisionCount == Vector.length(decisionValues)) Ok(()) else Err("prediction decision count mismatch");
        decisionPairs <- Vector.mapWithIndex((ordinal, value) ->
            predictionDecision(actualInstance, ordinal, value), decisionValues) |> Vector.sequence;
        rankingValues <- stringVector("ranking", fields);
        structural <- field("structural_work", fields) |> Result.flatMap(value -> object("structural_work", value));
        _ <- keys("structural_work", Vector#{"states_interned", "memo_entries", "memo_slots"}, structural);
        states <- integer("states_interned", structural); entries <- integer("memo_entries", structural);
        slots <- integer("memo_slots", structural)
    ) yield {
        summary = Vector#{Localization.PredictionTable.summaryRow(
            condition, actualInstance, repository, baseRevision, path, decisionCount, states, entries, slots)},
        ranking = Vector.mapWithIndex((rank, semanticId) ->
            Localization.PredictionTable.rankingRow(actualInstance, rank, semanticId), rankingValues),
        decisions = Vector.map(fst, decisionPairs),
        probabilities = Vector.flatMap(snd, decisionPairs)
    })

def predictionDecision(
    instanceId: String,
    ordinal: Int32,
    value: Json
): Result[String, (ScientificTable.Row, Vector[ScientificTable.Row])] = forM (
    fields <- object("localization decision", value);
    _ <- keys("localization decision", Vector#{"choice", "choice_index", "probabilities",
        "confidence", "provider", "actual_model", "response_id", "input_tokens",
        "output_tokens", "cost"}, fields);
    choice <- string("choice", fields); choiceIndex <- integer("choice_index", fields);
    confidence <- floating("confidence", fields); provider <- string("provider", fields);
    actualModel <- string("actual_model", fields); responseId <- string("response_id", fields);
    inputTokens <- optionalInteger("input_tokens", fields);
    outputTokens <- optionalInteger("output_tokens", fields);
    cost <- optionalFloating("cost", fields);
    probabilityValue <- field("probabilities", fields);
    probabilityFields <- object("localization decision probabilities", probabilityValue);
    probabilities <- Map.toVector(probabilityFields)
        |> Vector.sortBy(fst)
        |> Vector.traverse(match (action, probability) ->
            FromJson.fromJson(probability)
            |> Result.mapErr(ToString.toString)
            |> Result.map(value0 -> Localization.PredictionTable.probabilityRow(
                instanceId, ordinal, action, value0)))
) yield (
    Localization.PredictionTable.decisionRow(instanceId, ordinal, choice, choiceIndex, confidence,
        provider, actualModel, responseId, inputTokens, outputTokens, cost),
    probabilities
)

def parseObject(name: String, payload: String): Result[String, Map[String, Json]] =
    match Json.parse(payload) {
        case Err(error) => Err(ToString.toString(error))
        case Ok(value) => object(name, value)
    }

def object(name: String, value: Json): Result[String, Map[String, Json]] = match value {
    case JObject(fields) => Ok(fields)
    case _ => Err("${name} must be an object")
}

def keys(name: String, expected: Vector[String], fields: Map[String, Json]): Result[String, Unit] = {
    let actual = Map.toVector(fields) |> Vector.map(fst) |> Vector.toSet;
    if (Set.size(actual) == Vector.length(expected) and Set.isSubsetOf(actual, Vector.toSet(expected))) Ok(())
    else Err("${name} fields changed; refusing lossy typed migration")
}

def field(name: String, fields: Map[String, Json]): Result[String, Json] =
    Map.get(name, fields) |> Option.toOk("missing ${name}")

def string(name: String, fields: Map[String, Json]): Result[String, String] =
    match Map.get(name, fields) {
        case Some(JString(value)) => Ok(value)
        case Some(_) => Err("${name} must be text")
        case None => Err("missing ${name}")
    }

def integer(name: String, fields: Map[String, Json]): Result[String, Int32] =
    field(name, fields) |> Result.flatMap(value -> FromJson.fromJson(value)
        |> Result.mapErr(ToString.toString))

def floating(name: String, fields: Map[String, Json]): Result[String, Float64] =
    field(name, fields) |> Result.flatMap(value -> FromJson.fromJson(value)
        |> Result.mapErr(ToString.toString))

def optionalInteger(name: String, fields: Map[String, Json]): Result[String, Option[Int32]] =
    match Map.get(name, fields) {
        case None => Err("missing ${name}")
        case Some(JNull) => Ok(None)
        case Some(value) => FromJson.fromJson(value) |> Result.map(Some) |> Result.mapErr(ToString.toString)
    }

def optionalFloating(name: String, fields: Map[String, Json]): Result[String, Option[Float64]] =
    match Map.get(name, fields) {
        case None => Err("missing ${name}")
        case Some(JNull) => Ok(None)
        case Some(value) => FromJson.fromJson(value) |> Result.map(Some) |> Result.mapErr(ToString.toString)
    }

def array(name: String, fields: Map[String, Json]): Result[String, Vector[Json]] =
    match Map.get(name, fields) {
        case Some(JArray(values)) => Ok(values)
        case Some(_) => Err("${name} must be an array")
        case None => Err("missing ${name}")
    }

def stringVector(name: String, fields: Map[String, Json]): Result[String, Vector[String]] =
    field(name, fields) |> Result.flatMap(value -> FromJson.fromJson(value)
        |> Result.mapErr(ToString.toString))

def exactlyOne(name: String, values: Vector[a]): Result[String, a] =
    if (Vector.length(values) == 1) Ok(Vector.get(0, values)) else Err("${name} requires exactly one row")

def equal(name: String, expected: String, actual: String): Result[String, Unit] =
    if (expected == actual) Ok(()) else Err("${name} mismatch")

def property(name: String): String \ IO = System.getProperty(name)

def require(result: Result[String, a]): a = match result {
    case Ok(value) => value
    case Err(error) => bug!(error)
}
