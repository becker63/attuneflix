/// Issue-blind callable embeddings under `attune-families-embeddings-v1`.
///
/// One document per admitted callable, in `Repository.World.symbols` order,
/// with the frozen document text `path:name\n{exact source bytes}` capped at
/// the frozen code-point limit. There is no query side: no issue, instruction,
/// or query text is ever embedded. Documents are batched in order under the
/// frozen 64-text boundary; each batch is one content-addressed request.
pub mod Families.Embedding {
    import attune.inference.AttuneOpenRouter
    import java.lang.{Exception, String => JavaString}
    import java.nio.{ByteBuffer, ByteOrder}
    import java.nio.charset.StandardCharsets
    import java.nio.file.{Files, Paths}
    import java.security.MessageDigest
    import java.util.HexFormat

    use Util.Json
    use Util.Json.Json.{JArray, JObject, JString}

    pub type alias Document = {
        ordinal   = Int32,
        nodeId    = String,
        path      = String,
        name      = String,
        startByte = Int32,
        endByte   = Int32,
        text      = String,
        truncated = Bool
    }

    pub type alias Batch = {
        ordinal   = Int32,
        documents = Vector[Document],
        request   = Families.Provider.Request
    }

    /// One admitted batch response. `vectors` holds, per document in batch
    /// order, the SHA-256 of its little-endian float32 vector bytes.
    pub type alias Observation = {
        batch        = Int32,
        identity     = String,
        responseId   = Option[String],
        provider     = Option[String],
        servedModel  = String,
        promptTokens = Option[Int32],
        totalTokens  = Option[Int32],
        cost         = Option[Float64],
        vectors      = Vector[String]
    }

    pub def nodeId(symbol: Repository.Symbol): String = "${symbol#path}:${symbol#name}"

    /// The frozen document text and whether the code-point limit cut it.
    pub def text(nodeId0: String, source: String): (String, Bool) \ IO = {
        let full = "${nodeId0}\n${source}";
        let limit = Families.Protocol.textLimit();
        if (full.codePointCount(0, String.length(full)) <= limit) (full, false)
        else (String.sliceLeft(end = full.offsetByCodePoints(0, limit), full), true)
    }

    /// Reads every admitted callable span from the retained source root and
    /// rejects any span the root cannot supply exactly.
    pub def documents(world: Repository.World, sourceRoot: String): Result[String, Vector[Document]] \ IO = region rc {
        let files = MutMap.empty(rc);
        Vector.mapWithIndex((ordinal, symbol) -> (ordinal, symbol), world#symbols)
            |> Vector.traverse(match (ordinal, symbol) -> {
                let bytes = MutMap.getOrElsePut(symbol#path,
                    Files.readAllBytes(Paths.get("${sourceRoot}/${symbol#path}")), files);
                if (symbol#startByte < 0 or symbol#endByte < symbol#startByte or symbol#endByte > Array.length(bytes))
                    Err("span ${symbol#path}:${symbol#startByte}-${symbol#endByte} is outside the source root")
                else {
                    let source = new JavaString(bytes, symbol#startByte, symbol#endByte - symbol#startByte, StandardCharsets.UTF_8);
                    if (not String.contains(substr = symbol#name, source))
                        Err("callable ${nodeId(symbol)} does not name its admitted span")
                    else Ok(document(ordinal, symbol, source))
                }
            })
    }

    def document(ordinal: Int32, symbol: Repository.Symbol, source: String): Document \ IO = {
        let id = nodeId(symbol);
        let (body, truncated) = text(id, source);
        {
            ordinal = ordinal, nodeId = id, path = symbol#path, name = symbol#name,
            startByte = symbol#startByte, endByte = symbol#endByte, text = body, truncated = truncated
        }
    }

    /// A recorded document is admissible for this world exactly when it is
    /// the recipe applied to the admitted callable at the same ordinal.
    pub def verify(world: Repository.World, documents0: Vector[Document]): Result[String, Unit] \ IO =
        if (Vector.length(documents0) != Vector.length(world#symbols)) Err("document count differs from the world's callables")
        else Vector.mapWithIndex((ordinal, pair) -> (ordinal, pair), Vector.zip(world#symbols, documents0))
            |> Vector.traverse(match (ordinal, (symbol, recorded)) -> verifyDocument(ordinal, symbol, recorded))
            |> Result.map(_ -> ())

    def verifyDocument(ordinal: Int32, symbol: Repository.Symbol, recorded: Document): Result[String, Unit] \ IO = {
        let prefix = "${nodeId(symbol)}\n";
        if (recorded#ordinal != ordinal or recorded#nodeId != nodeId(symbol) or recorded#path != symbol#path or
            recorded#name != symbol#name or recorded#startByte != symbol#startByte or recorded#endByte != symbol#endByte)
            Err("document ${ordinal} is not the admitted callable ${nodeId(symbol)}")
        else if (not String.startsWith(prefix = prefix, recorded#text))
            Err("document ${ordinal} does not start with its node identity")
        else {
            let source = String.sliceRight(start = String.length(prefix), recorded#text);
            let sourceBytes = Array.length(source.getBytes(StandardCharsets.UTF_8));
            if (not recorded#truncated and sourceBytes != symbol#endByte - symbol#startByte)
                Err("document ${ordinal} does not carry exactly its admitted span")
            else if (recorded#truncated and
                recorded#text.codePointCount(0, String.length(recorded#text)) != Families.Protocol.textLimit())
                Err("document ${ordinal} is marked truncated but is not cut at the frozen limit")
            else Ok(())
        }
    }

    /// Documents in order, cut at the frozen batch boundary.
    pub def batches(documents0: Vector[Document]): Vector[Batch] \ IO = {
        let size = Families.Protocol.batchSize();
        let count = (Vector.length(documents0) + size - 1) / size;
        Vector.map(ordinal -> {
            let members = Vector.slice(start = ordinal * size, end = Int32.min((ordinal + 1) * size, Vector.length(documents0)), documents0);
            {ordinal = ordinal, documents = members, request = request(Vector.map(document0 -> document0#text, members))}
        }, Vector.range(0, count))
    }

    /// The provider-visible request body and its content-derived identity.
    pub def request(inputs: Vector[String]): Families.Provider.Request \ IO = {
        let payload = Json.toCompactString(JObject(Map#{
            "model" => JString(Families.Protocol.embeddingModel()),
            "input" => JArray(Vector.map(JString, inputs)),
            "encoding_format" => JString(Families.Protocol.encodingFormat())
        }));
        let identity = Families.Evidence.identity(Families.Protocol.embeddings(), Vector.append(Vector#{
            Families.Protocol.provider(), Families.Protocol.embeddingEndpoint(), Families.Protocol.embeddingModel(),
            Families.Protocol.encodingFormat(), Int32.toString(Families.Protocol.dimension()), payload
        }, inputs));
        {kind = Families.Provider.Kind.EmbeddingBatch, identity = identity, payload = payload, inputs = inputs}
    }

    /// Admits one provider body for a batch: usage and identity fields from
    /// the raw body, vectors through the SDK's own decoder, keylessly.
    pub def admit(batch: Batch, body: String): Result[String, Observation] \ IO = forM (
        fields <- Families.Wire.body(body);
        servedModel <- Families.Wire.text("model", fields);
        _ <- servedModelMatches(servedModel);
        responseId <- Families.Wire.optionalText("id", fields);
        provider <- Families.Wire.optionalText("provider", fields);
        usage <- Families.Wire.usage(fields);
        promptTokens <- Families.Wire.optionalInt32("prompt_tokens", usage);
        totalTokens <- Families.Wire.optionalInt32("total_tokens", usage);
        cost <- Families.Wire.optionalFloat64("cost", usage);
        vectors <- vectorDigests(batch, body)
    ) yield {
        batch = batch#ordinal, identity = batch#request#identity, responseId = responseId,
        provider = provider, servedModel = servedModel, promptTokens = promptTokens, totalTokens = totalTokens,
        cost = cost, vectors = vectors
    }

    /// OpenRouter reports the pinned model under its canonical casing
    /// (`Qwen/Qwen3-Embedding-8B`), so the match ignores case.
    def servedModelMatches(served: String): Result[String, Unit] =
        if (String.toLowerCase(served) == String.toLowerCase(Families.Protocol.embeddingModel())) Ok(())
        else Err("unexpected embedding model ${served}")

    def vectorDigests(batch: Batch, body: String): Result[String, Vector[String]] \ IO = try {
        let response = AttuneOpenRouter.embed(AttuneOpenRouter.replay(body),
            Families.Provider.embeddingRequest(batch#request#inputs)).parsedResponse();
        let data = response.data();
        let expected = Vector.length(batch#documents);
        if (data.size() != expected) Err("batch ${batch#ordinal} returned ${data.size()} vectors for ${expected} documents")
        else Vector.traverse(index -> {
            let embedding = data.get(index);
            let values = embedding.embedding();
            if (embedding.index().intValue() != index) Err("batch ${batch#ordinal} vector ${index} is out of order")
            else if (values.size() != Families.Protocol.dimension()) Err("batch ${batch#ordinal} vector ${index} has ${values.size()} dimensions")
            else {
                let buffer = ByteBuffer.allocate(4 * values.size()).order(ByteOrder.LITTLE_ENDIAN);
                Vector.forEach(coordinate -> { let _ = buffer.putFloat(values.get(coordinate).floatValue()); () },
                    Vector.range(0, values.size()));
                Ok(HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(buffer.array())))
            }
        }, Vector.range(0, expected))
    } catch {
        case error: Exception => Err(AttuneOpenRouter.describe(error))
    }
}
