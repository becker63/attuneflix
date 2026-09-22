mod Localization {
    import attune.embed.AttuneEmbed

    use Fs.FileSystem
    use Util.Json
    use Util.Json.Json.{JArray, JNull, JObject, JString}
    use Util.Json.FromJson
    use Util.Json.ToJson

    pub enum InputKind with Eq, Order, ToString, Hash {
        case Query,
        case Document
    }

    pub enum IssueText(String) with Eq

    pub enum GoldFiles(Set[String]) with Eq

    /// The canonical identity is deliberately opaque: callers cannot obtain
    /// issue/source text by formatting an observation key.
    pub enum RequestId with Eq, Order, Hash {
        case RequestId(String)
    }

    pub type alias Request = {
        id   = RequestId,
        kind = InputKind,
        text = String
    }

    pub type alias Observation = {
        id     = RequestId,
        vector = Vector[Float32]
    }

    pub type alias Ranked = {
        identity = String,
        score    = Float64,
        ordinal  = Int32
    }

    pub type alias Issue = {
        instanceId = String,
        repository = String,
        baseCommit = String,
        text = IssueText
    }

    pub type alias Candidate = {
        identity = String,
        ordinal  = Int32,
        vector   = Vector[Float32]
    }

    pub type alias Document = {
        semanticId = String,
        nodeId     = String,
        path       = String,
        name       = String,
        startByte  = Int32,
        endByte    = Int32,
        ordinal    = Int32,
        text       = String,
        request    = Request
    }

    pub type alias Prepared = {
        instanceId = String,
        repository = String,
        baseCommit = String,
        snapshot   = Repository.Nix.StorePath,
        issue      = Issue,
        world      = Repository.World,
        sources    = Vector[Repository.Source],
        documents  = Vector[Document]
    }

    pub type alias Acquisition = {
        observations = Vector[Observation],
        replayed     = Int32,
        live         = Int32,
        inputTokens  = Option[Int32],
        totalTokens  = Option[Int32]
    }

    type alias Stored = {
        observations = Map[RequestId, Observation],
        batches      = Int32
    }

    type alias NativeBatch = {
        observations = Vector[Observation],
        inputTokens  = Option[Int32],
        totalTokens  = Option[Int32]
    }

    type alias Acquired = {
        retained    = Map[RequestId, Observation],
        batches     = Int32,
        inputTokens = Option[Int32],
        totalTokens = Option[Int32]
    }

    pub enum Wire(String) with Eq

    pub enum Error with Eq, ToString {
        case Wire(String),
        case Native(String, String),
        case UnsupportedVersion(Int32),
        case UnexpectedProvider(String),
        case UnexpectedModel(String),
        case WrongVectorCount(Int32, Int32),
        case EmptyDimension,
        case UnexpectedDimension(Int32, Int32),
        case RaggedDimensions(Int32, Int32),
        case DuplicateObservation,
        case ReplayMiss,
        case MissingIssue(String),
        case AmbiguousIssue(String),
        case IssueRepositoryMismatch(String, String),
        case IssueCommitMismatch(String, String),
        case EmptyIssue(String),
        case MissingDocumentSource(String),
        case InvalidDocumentRange(String, Int32, Int32),
        case Nix(Repository.Nix.Error),
        case Repository(Repository.Error),
        case ObservationStore(String)
    }

    pub eff Embed {
        def acquire(requests: Vector[Request]): Result[Error, Vector[Observation]]
    }

    pub def provider(): String = "openrouter"

    pub def model(): String = "qwen/qwen3-embedding-8b"

    pub def instruction(): String =
        "Given a software bug report, retrieve the source-code function most relevant to fixing it."

    pub def textLimit(): Int32 = 48000

    pub def dimension(): Int32 = 4096

    pub def queryText(issue: String): String =
        clip("Instruct: ${instruction()}\nQuery:${issue}")

    pub def documentText(identity: String, code: String): String =
        clip("${identity}\n${code}")

    pub def queryRequest(issue: IssueText): Request = {
        let IssueText.IssueText(text) = issue;
        request(InputKind.Query, queryText(text))
    }

    pub def documentRequest(identity: String, code: String): Request =
        request(InputKind.Document, documentText(identity, code))

    /// Projects the historical `node_id\ncode` representation from the
    /// admitted AttuneFlix callable world. Semantic identity retains the exact
    /// byte range even where two callables share a source-visible name.
    pub def documents(
        repository: String,
        baseCommit: String,
        world: Repository.World,
        sources: Vector[Repository.Source]
    ): Result[Error, Vector[Document]] = {
        let byPath = Vector.map(source -> (source#path, source#content), sources) |> Vector.toMap;
        Vector.mapWithIndex((ordinal, symbol) -> (ordinal, symbol), world#symbols)
        |> Vector.traverse(match (ordinal, symbol) -> match Map.get(symbol#path, byPath) {
            case None => Err(Error.MissingDocumentSource(symbol#path))
            case Some(source) => {
                let bytes = String.toBytes(source);
                if (symbol#startByte < 0 or symbol#endByte < symbol#startByte or
                    symbol#endByte > Vector.length(bytes))
                    Err(Error.InvalidDocumentRange(symbol#path, symbol#startByte, symbol#endByte))
                else {
                    let code = String.fromBytes(Vector.slice(
                        start = symbol#startByte,
                        end = symbol#endByte,
                        bytes
                    ));
                    let nodeId = "${symbol#path}:${symbol#name}";
                    Ok({
                        semanticId = "${repository}@${baseCommit}:${symbol#path}:${symbol#startByte}:${symbol#endByte}:${symbol#name}",
                        nodeId = nodeId,
                        path = symbol#path,
                        name = symbol#name,
                        startByte = symbol#startByte,
                        endByte = symbol#endByte,
                        ordinal = ordinal,
                        text = documentText(nodeId, code),
                        request = documentRequest(nodeId, code)
                    })
                }
            }
        })
    }

    def request(kind: InputKind, text: String): Request = {
        let role = match kind {
            case InputKind.Query => "query"
            case InputKind.Document => "document"
        };
        // Length prefixes make this injective without depending on separators
        // being absent from source text. The API key is intentionally absent.
        let canonical = canonicalPart("attune-semantic-prior-v1") +
            canonicalPart(provider()) + canonicalPart(model()) +
            canonicalPart(role) + canonicalPart(instruction()) + canonicalPart(text);
        {id = RequestId.RequestId(canonical), kind = kind, text = text}
    }

    pub def acquire(requests: Vector[Request]): Result[Error, Vector[Observation]] \ Embed =
        Embed.acquire(requests)

    pub def prepare(caseIndex: Int32): Result[Error, Prepared] \ {Repository.Nix.Acquire, Repository.Grit.Eval} = forM (
        case_ <- Repository.Nix.localization(caseIndex) |> Result.mapErr(Error.Nix);
        issuePayload <- Repository.Nix.Acquire.readSource(Repository.Nix.path(case_#issueFixture))
            |> Result.mapErr(Error.Nix);
        issue <- decodeIssue(case_#instanceId, case_#repository, case_#baseCommit, issuePayload);
        world <- Repository.extract(case_#sources) |> Result.mapErr(Error.Repository);
        corpus <- documents(case_#repository, case_#baseCommit, world, case_#sources)
    ) yield {
        instanceId = case_#instanceId,
        repository = case_#repository,
        baseCommit = case_#baseCommit,
        snapshot = case_#snapshot,
        issue = issue,
        world = world,
        sources = case_#sources,
        documents = corpus
    }

    /// Scientific runs retain expensive repository observations once per Nix
    /// snapshot. Source loading and issue projection remain Nix-owned.
    pub def prepareRetained(
        root: String,
        caseIndex: Int32
    ): Result[Error, Prepared] \ {Fs.FileSystem, Repository.Nix.Acquire, Repository.Grit.Eval} = forM (
        case_ <- Repository.Nix.localization(caseIndex) |> Result.mapErr(Error.Nix);
        issuePayload <- Repository.Nix.Acquire.readSource(Repository.Nix.path(case_#issueFixture))
            |> Result.mapErr(Error.Nix);
        issue <- decodeIssue(case_#instanceId, case_#repository, case_#baseCommit, issuePayload);
        world <- Repository.extractRetained(
            root,
            case_#repository,
            case_#baseCommit,
            Repository.Nix.path(case_#snapshot),
            case_#sources
        ) |> Result.mapErr(Error.Repository);
        corpus <- documents(case_#repository, case_#baseCommit, world, case_#sources)
    ) yield {
        instanceId = case_#instanceId,
        repository = case_#repository,
        baseCommit = case_#baseCommit,
        snapshot = case_#snapshot,
        issue = issue,
        world = world,
        sources = case_#sources,
        documents = corpus
    }

    /// Scale-population preparation from independently acquired, gold-free
    /// source and issue projections. The caller controls manifest sharding.
    pub def prepareScaleRetained(
        root: String,
        case_: Repository.Nix.ScaleCase,
        issuePayload: String
    ): Result[Error, Prepared] \ {Fs.FileSystem, Repository.Grit.Eval} = forM (
        issue <- decodeIssue(
            case_#instanceId,
            case_#repository,
            case_#baseRevision,
            issuePayload
        );
        sources = Vector.map(source -> {path = source#path, content = source#content}, case_#sources);
        world <- Repository.extractRetained(
            root,
            case_#repository,
            case_#baseRevision,
            Repository.Nix.path(case_#snapshot),
            sources
        ) |> Result.mapErr(Error.Repository);
        corpus <- documents(case_#repository, case_#baseRevision, world, sources)
    ) yield {
        instanceId = case_#instanceId,
        repository = case_#repository,
        baseCommit = case_#baseRevision,
        snapshot = case_#snapshot,
        issue = issue,
        world = world,
        sources = sources,
        documents = corpus
    }

    pub def runWithNative(f: Unit -> a \ ef): a \ (ef - Embed) + IO =
        run { f() } with handler Embed {
            def acquire(requests, k) = k(acquireNative(requests))
        }

    pub def runWithReplay(
        retained: Map[RequestId, Observation],
        f: Unit -> a \ ef
    ): a \ (ef - Embed) =
        run { f() } with handler Embed {
            def acquire(requests, k) = k(replay(requests, retained))
        }

    pub def runWithFixture(
        retained: Map[RequestId, Observation],
        f: Unit -> a \ ef
    ): a \ (ef - Embed) = runWithReplay(retained, f)

    /// Replay from durable observations only. A miss is an explicit error and
    /// can never fall through to OpenRouter.
    pub def runWithStoreReplay(root: String, f: Unit -> a \ ef): a \ (ef - Embed) + FileSystem =
        run { f() } with handler Embed {
            def acquire(requests, k) = k(replayRetained(root, requests))
        }

    /// Acquire mode replays exact hits, sends only misses to OpenRouter, and
    /// atomically retains every admitted live observation.
    pub def runWithAcquire(root: String, f: Unit -> a \ ef): a \ (ef - Embed) + FileSystem + IO =
        run { f() } with handler Embed {
            def acquire(requests, k) = k(acquireRetained(root, requests) |> Result.map(value -> value#observations))
        }

    pub def acquireRetained(root: String, requests: Vector[Request]): Result[Error, Acquisition] \ {FileSystem, IO} =
        match readStore(root) {
            case Err(error) => Err(error)
            case Ok(stored) => {
                let unique = uniqueRequests(requests);
                let missing = Vector.filter(request ->
                    not Map.memberOf(request#id, stored#observations), unique);
                match acquireBatches(root, stored#batches, missing, stored#observations,
                    Some(0), Some(0)) {
                    case Err(error) => Err(error)
                    case Ok(acquired) => {
                        let observations = Vector.traverse(request ->
                            Map.get(request#id, acquired#retained)
                                |> Option.toOk(Error.ReplayMiss), requests);
                        Result.map(values -> {
                            observations = values,
                            replayed = Vector.length(unique) - Vector.length(missing),
                            live = Vector.length(missing),
                            inputTokens = acquired#inputTokens,
                            totalTokens = acquired#totalTokens
                        }, observations)
                    }
                }
            }
        }

    pub def replayRetained(root: String, requests: Vector[Request]): Result[Error, Vector[Observation]] \ FileSystem =
        readStore(root) |> Result.flatMap(stored -> Vector.traverse(request ->
            Map.get(request#id, stored#observations) |> Option.toOk(Error.ReplayMiss), requests))

    pub def retainAll(root: String, observations: Vector[Observation]): Result[Error, Unit] \ FileSystem =
        readStore(root) |> Result.flatMap(stored -> {
            let fresh = Vector.filter(observation ->
                not Map.memberOf(observation#id, stored#observations), observations);
            if (Vector.isEmpty(fresh)) Ok(())
            else writeRawBatch(
                root,
                stored#batches,
                Vector.map(observation -> observation#id, fresh),
                syntheticWire(fresh)
            )
        })

    pub def decode(requests: Vector[Request], wire: Wire): Result[Error, Vector[Observation]] = {
        let Wire.Wire(payload) = wire;
        match Json.parse(payload) {
            case Err(error) => Err(Error.Wire(ToString.toString(error)))
            case Ok(JObject(fields)) => match intField("version", fields) {
                case Err(error) => Err(error)
                case Ok(version) if version != 1 => Err(Error.UnsupportedVersion(version))
                case Ok(_) => match Map.get("error", fields) {
                    case Some(value) => nativeError(value)
                    case None => forM (
                        actualProvider <- stringField("provider", fields);
                        _ <- requireProvider(actualProvider);
                        actualModel <- stringField("model", fields);
                        _ <- requireModel(actualModel);
                        vectors <- vectorsField("vectors", fields);
                        observations <- admit(requests, vectors)
                    ) yield observations
                }
            }
            case Ok(_) => Err(Error.Wire("expected a JSON object"))
        }
    }

    /// Decodes the solver-only issue projection. The pinned fixture contains no
    /// patch, tests, changed-file gold, or evaluator fields.
    pub def decodeIssue(
        instanceId: String,
        repository: String,
        baseCommit: String,
        payload: String
    ): Result[Error, Issue] = match Json.parse(payload) {
        case Err(error) => Err(Error.Wire(ToString.toString(error)))
        case Ok(JObject(fields)) => match intField("version", fields) {
            case Err(error) => Err(error)
            case Ok(version) if version != 1 => Err(Error.UnsupportedVersion(version))
            case Ok(_) => match arrayField("issues", fields) {
                case Err(error) => Err(error)
                case Ok(values) => {
                    let matches = Vector.filter(value -> issueIdentity(value) == Some(instanceId), values);
                    if (Vector.isEmpty(matches)) Err(Error.MissingIssue(instanceId))
                    else if (Vector.length(matches) != 1) Err(Error.AmbiguousIssue(instanceId))
                    else decodeIssueRow(instanceId, repository, baseCommit, Vector.get(0, matches))
                }
            }
        }
        case Ok(_) => Err(Error.Wire("issue fixture must be a JSON object"))
    }

    pub def rank(queryVector: Vector[Float32], candidates: Vector[Candidate]): Vector[Ranked] =
        Vector.map(candidate -> {
            identity = candidate#identity,
            score = cosine(queryVector, candidate#vector),
            ordinal = candidate#ordinal
        }, candidates)
        |> Vector.sortBy(item -> (-item#score, item#ordinal))

    pub def cosine(left: Vector[Float32], right: Vector[Float32]): Float64 = {
        if (Vector.length(left) != Vector.length(right)) 0.0
        else {
            let pairs = Vector.zip(left, right);
            let dot = Vector.foldLeft((sum, pair) ->
                let (x, y) = pair;
                sum + Float32.toFloat64(x) * Float32.toFloat64(y), 0.0, pairs);
            let leftNorm = Float64.pow(base = Vector.foldLeft((sum, x) ->
                let value = Float32.toFloat64(x);
                sum + value * value, 0.0, left), 0.5);
            let rightNorm = Float64.pow(base = Vector.foldLeft((sum, x) ->
                let value = Float32.toFloat64(x);
                sum + value * value, 0.0, right), 0.5);
            if (leftNorm == 0.0 or rightNorm == 0.0) 0.0 else dot / (leftNorm * rightNorm)
        }
    }

    def clip(text: String): String = {
        let marker = "\n...[truncated for embedding]...\n";
        let limit = textLimit();
        if (codePointLength(text) <= limit) text
        else {
            let half = (limit - codePointLength(marker)) / 2;
            takeCodePointsLeft(half, text) + marker + takeCodePointsRight(half, text)
        }
    }

    /// Python's historical prior clipped by Unicode code points. Flix's
    /// ordinary String length/slice operations expose JVM UTF-16 units, so the
    /// prior boundary advances explicitly over surrogate pairs.
    pub def codePointLength(text: String): Int32 = codePointLengthFrom(0, 0, text)

    def codePointLengthFrom(offset: Int32, count: Int32, text: String): Int32 =
        if (offset >= String.length(text)) count
        else codePointLengthFrom(nextCodePoint(offset, text), count + 1, text)

    def takeCodePointsLeft(count: Int32, text: String): String =
        String.slice(start = 0, end = codeUnitOffset(count, text), text)

    def takeCodePointsRight(count: Int32, text: String): String = {
        let skip = codePointLength(text) - count;
        String.slice(start = codeUnitOffset(skip, text), end = String.length(text), text)
    }

    def codeUnitOffset(count: Int32, text: String): Int32 =
        codeUnitOffsetFrom(0, count, text)

    def codeUnitOffsetFrom(offset: Int32, remaining: Int32, text: String): Int32 =
        if (remaining <= 0 or offset >= String.length(text)) offset
        else codeUnitOffsetFrom(nextCodePoint(offset, text), remaining - 1, text)

    def nextCodePoint(offset: Int32, text: String): Int32 =
        offset + (if (String.codePointAt(offset, text) > 0xffff) 2 else 1)

    def canonicalPart(value: String): String = "${String.length(value)}:${value}"

    def replay(
        requests: Vector[Request],
        retained: Map[RequestId, Observation]
    ): Result[Error, Vector[Observation]] =
        Vector.traverse(request -> Map.get(request#id, retained) |> Option.toOk(Error.ReplayMiss), requests)

    def acquireNative(requests: Vector[Request]): Result[Error, Vector[Observation]] \ IO =
        acquireNativeBatches(requests, 0, Vector.empty())

    def acquireNativeBatches(
        requests: Vector[Request],
        start: Int32,
        accumulated: Vector[Observation]
    ): Result[Error, Vector[Observation]] \ IO =
        if (start >= Vector.length(requests)) Ok(accumulated)
        else {
            let finish = Int32.min(start + 64, Vector.length(requests));
            let batch = Vector.slice(start = start, end = finish, requests);
            let wire = acquireNativeWire(batch);
            match decodeNativeBatch(batch, wire) {
                case Err(error) => Err(error)
                case Ok(result) => acquireNativeBatches(
                    requests, finish, Vector.append(accumulated, result#observations))
            }
        }

    def acquireNativeWire(requests: Vector[Request]): Wire \ IO = {
        let texts = Vector.map(request -> JString(request#text), requests);
        let payload = Json.toCompactString(JArray(texts));
        Wire.Wire(AttuneEmbed.embed(model(), payload))
    }

    /// Every paid batch is written atomically before local admission. A future
    /// decoder can therefore re-admit the exact stable provider envelope
    /// without purchasing the observation again.
    def acquireBatches(
        root: String,
        batchIndex: Int32,
        pending: Vector[Request],
        retained: Map[RequestId, Observation],
        inputTokens: Option[Int32],
        totalTokens: Option[Int32]
    ): Result[Error, Acquired] \ {FileSystem, IO} =
        if (Vector.isEmpty(pending)) Ok({
            retained = retained,
            batches = batchIndex,
            inputTokens = inputTokens,
            totalTokens = totalTokens
        })
        else {
            let finish = Int32.min(64, Vector.length(pending));
            let batch = Vector.slice(start = 0, end = finish, pending);
            let rest = Vector.slice(start = finish, end = Vector.length(pending), pending);
            let wire = acquireNativeWire(batch);
            let ids = Vector.map(request -> request#id, batch);
            match writeRawBatch(root, batchIndex, ids, wire) {
                case Err(error) => Err(error)
                case Ok(()) => match decodeNativeBatch(batch, wire) {
                    case Err(error) => Err(error)
                    case Ok(result) => match mergeUnique(retained, result#observations) {
                        case Err(error) => Err(error)
                        case Ok(next) => acquireBatches(
                            root,
                            batchIndex + 1,
                            rest,
                            next,
                            addUsage(inputTokens, result#inputTokens),
                            addUsage(totalTokens, result#totalTokens)
                        )
                    }
                }
            }
        }

    def readStore(root: String): Result[Error, Stored] \ FileSystem =
        readBatches(root, 0, Map.empty())

    def readBatches(
        root: String,
        batchIndex: Int32,
        retained: Map[RequestId, Observation]
    ): Result[Error, Stored] \ FileSystem = {
        let file = rawBatchFile(root, batchIndex);
        match FileSystem.exists(file) |> Result.mapErr(storeError) {
            case Err(error) => Err(error)
            case Ok(false) => Ok({observations = retained, batches = batchIndex})
            case Ok(true) => match FileSystem.read(file) |> Result.mapErr(storeError) {
                case Err(error) => Err(error)
                case Ok(payload) => match decodeStoredBatch(payload) {
                    case Err(error) => Err(error)
                    case Ok(observations) => match mergeUnique(retained, observations) {
                        case Err(error) => Err(error)
                        case Ok(next) => readBatches(root, batchIndex + 1, next)
                    }
                }
            }
        }
    }

    def writeRawBatch(
        root: String,
        batchIndex: Int32,
        ids: Vector[RequestId],
        wire: Wire
    ): Result[Error, Unit] \ FileSystem = {
        let Wire.Wire(response) = wire;
        let requestIds = Vector.map(match RequestId.RequestId(canonical) ->
            JString(canonical), ids);
        let payload = Json.toCompactString(JObject(Map#{
            "version" => ToJson.toJson(1),
            "provider" => JString(provider()),
            "model" => JString(model()),
            "request_ids" => JArray(requestIds),
            "response" => JString(response)
        }));
        let written = run {
            FileSystem.write(str = payload, rawBatchFile(root, batchIndex))
        } with FileSystem.withMkParentDirs
          with FileSystem.withAtomicWrite;
        Result.mapErr(storeError, written)
    }

    def decodeStoredBatch(payload: String): Result[Error, Vector[Observation]] =
        match Json.parse(payload) {
            case Err(error) => Err(Error.Wire(ToString.toString(error)))
            case Ok(JObject(fields)) => forM (
                version <- intField("version", fields);
                _ <- if (version == 1) Ok(()) else Err(Error.UnsupportedVersion(version));
                actualProvider <- stringField("provider", fields);
                _ <- requireProvider(actualProvider);
                actualModel <- stringField("model", fields);
                _ <- requireModel(actualModel);
                values <- arrayField("request_ids", fields);
                ids <- Vector.traverse(decodeRequestId, values);
                response <- stringField("response", fields);
                observations <- decode(Vector.map(dummyRequest, ids), Wire.Wire(response))
            ) yield observations
            case Ok(_) => Err(Error.Wire("retained raw batch must be an object"))
        }

    def decodeNativeBatch(requests: Vector[Request], wire: Wire): Result[Error, NativeBatch] = forM (
        observations <- decode(requests, wire);
        usage <- decodeUsage(wire)
    ) yield {
        observations = observations,
        inputTokens = fst(usage),
        totalTokens = snd(usage)
    }

    def decodeUsage(wire: Wire): Result[Error, (Option[Int32], Option[Int32])] = {
        let Wire.Wire(payload) = wire;
        match Json.parse(payload) {
            case Err(error) => Err(Error.Wire(ToString.toString(error)))
            case Ok(JObject(fields)) => match Map.get("usage", fields) {
                case None => Ok((None, None))
                case Some(JNull) => Ok((None, None))
                case Some(JObject(usage)) => forM (
                    input <- optionalIntField("input_tokens", usage);
                    total <- optionalIntField("total_tokens", usage)
                ) yield (input, total)
                case Some(_) => Err(Error.Wire("usage: expected object or null"))
            }
            case Ok(_) => Err(Error.Wire("expected a JSON object"))
        }
    }

    def decodeRequestId(value: Json): Result[Error, RequestId] = match value {
        case JString(canonical) => Ok(RequestId.RequestId(canonical))
        case _ => Err(Error.Wire("stored request identity must be a string"))
    }

    def dummyRequest(id: RequestId): Request = {
        id = id,
        kind = InputKind.Document,
        text = ""
    }

    def syntheticWire(observations: Vector[Observation]): Wire = Wire.Wire(
        Json.toCompactString(JObject(Map#{
            "version" => ToJson.toJson(1),
            "provider" => JString(provider()),
            "model" => JString(model()),
            "vectors" => ToJson.toJson(Vector.map(observation -> observation#vector, observations))
        })))

    def uniqueRequests(requests: Vector[Request]): Vector[Request] =
        Vector.map(request -> (request#id, request), requests)
            |> Vector.toMap
            |> Map.toVector
            |> Vector.map(match (_, request) -> request)

    def addUsage(left: Option[Int32], right: Option[Int32]): Option[Int32] =
        match (left, right) {
            case (Some(x), Some(y)) => Some(x + y)
            case _ => None
        }

    def mergeUnique(
        retained: Map[RequestId, Observation],
        fresh: Vector[Observation]
    ): Result[Error, Map[RequestId, Observation]] = {
        let incoming = Vector.map(observation -> (observation#id, observation), fresh) |> Vector.toMap;
        if (Map.size(incoming) != Vector.length(fresh) or
            Vector.exists(observation -> Map.memberOf(observation#id, retained), fresh))
            Err(Error.DuplicateObservation)
        else Ok(Map.union(retained, incoming))
    }

    def rawBatchFile(root: String, batchIndex: Int32): String =
        "${root}/raw/batch-${batchIndex}.json"

    def storeError(error: IoError): Error =
        Error.ObservationStore(ToString.toString(error))

    def admit(
        requests: Vector[Request],
        vectors: Vector[Vector[Float32]]
    ): Result[Error, Vector[Observation]] = {
        let expected = Vector.length(requests);
        let actual = Vector.length(vectors);
        if (expected != actual) Err(Error.WrongVectorCount(expected, actual))
        else match Vector.head(vectors) {
            case None => Ok(Vector.empty())
            case Some(first) if Vector.isEmpty(first) => Err(Error.EmptyDimension)
            case Some(first) =>
                let dimension = Vector.length(first);
                if (dimension != Localization.dimension())
                    Err(Error.UnexpectedDimension(Localization.dimension(), dimension))
                else match Vector.find(vector -> Vector.length(vector) != dimension, vectors) {
                    case Some(vector) => Err(Error.RaggedDimensions(dimension, Vector.length(vector)))
                    case None => Ok(Vector.zip(requests, vectors)
                        |> Vector.map(match (request, vector) -> {id = request#id, vector = vector}))
                }
        }
    }

    def requireProvider(actual: String): Result[Error, Unit] =
        if (actual == provider()) Ok(()) else Err(Error.UnexpectedProvider(actual))

    def requireModel(actual: String): Result[Error, Unit] =
        if (actual == model()) Ok(()) else Err(Error.UnexpectedModel(actual))

    def nativeError(value: Json): Result[Error, Vector[Observation]] = match value {
        case JObject(fields) => match stringField("kind", fields) {
            case Err(error) => Err(error)
            case Ok(kind) => match stringField("message", fields) {
                case Err(error) => Err(error)
                case Ok(message) => Err(Error.Native(kind, message))
            }
        }
        case _ => Err(Error.Wire("error must be a JSON object"))
    }

    def field(name: String, fields: Map[String, Json]): Result[Error, Json] =
        Map.get(name, fields) |> Option.toOk(Error.Wire("missing JSON field: ${name}"))

    def intField(name: String, fields: Map[String, Json]): Result[Error, Int32] = match field(name, fields) {
        case Err(error) => Err(error)
        case Ok(value) => FromJson.fromJson(value)
            |> Result.mapErr(error -> Error.Wire("${name}: ${ToString.toString(error)}"))
    }

    def optionalIntField(name: String, fields: Map[String, Json]): Result[Error, Option[Int32]] =
        match Map.get(name, fields) {
            case None => Ok(None)
            case Some(JNull) => Ok(None)
            case Some(value) => FromJson.fromJson(value)
                |> Result.map(Some)
                |> Result.mapErr(error -> Error.Wire("${name}: ${ToString.toString(error)}"))
        }

    def stringField(name: String, fields: Map[String, Json]): Result[Error, String] = match field(name, fields) {
        case Err(error) => Err(error)
        case Ok(JString(value)) => Ok(value)
        case Ok(_) => Err(Error.Wire("${name}: expected string"))
    }

    def arrayField(name: String, fields: Map[String, Json]): Result[Error, Vector[Json]] = match field(name, fields) {
        case Err(error) => Err(error)
        case Ok(JArray(values)) => Ok(values)
        case Ok(_) => Err(Error.Wire("${name}: expected array"))
    }

    def issueIdentity(value: Json): Option[String] = match value {
        case JObject(fields) => match Map.get("instanceId", fields) {
            case Some(JString(identity)) => Some(identity)
            case _ => None
        }
        case _ => None
    }

    def decodeIssueRow(
        expectedId: String,
        expectedRepository: String,
        expectedCommit: String,
        value: Json
    ): Result[Error, Issue] = match value {
        case JObject(fields) => forM (
            instanceId <- stringField("instanceId", fields);
            repository <- stringField("repository", fields);
            _ <- if (repository == expectedRepository) Ok(())
                 else Err(Error.IssueRepositoryMismatch(expectedRepository, repository));
            baseCommit <- stringField("baseCommit", fields);
            _ <- if (baseCommit == expectedCommit) Ok(())
                 else Err(Error.IssueCommitMismatch(expectedCommit, baseCommit));
            text <- stringField("problemStatement", fields);
            _ <- if (String.isEmpty(text)) Err(Error.EmptyIssue(expectedId)) else Ok(())
        ) yield {
            instanceId = instanceId,
            repository = repository,
            baseCommit = baseCommit,
            text = IssueText.IssueText(text)
        }
        case _ => Err(Error.Wire("issue row must be an object"))
    }

    def vectorsField(name: String, fields: Map[String, Json]): Result[Error, Vector[Vector[Float32]]] =
        match field(name, fields) {
            case Err(error) => Err(error)
            case Ok(value) => FromJson.fromJson(value)
                |> Result.mapErr(error -> Error.Wire("${name}: ${ToString.toString(error)}"))
        }
}
