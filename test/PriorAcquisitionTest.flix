mod PriorAcquisitionTest {
    use Fs.FileSystem
    use Sys.Env
    use Util.Json
    use Util.Json.Json.{JArray, JObject, JString}
    use Util.Json.ToJson

    type alias Corpus = {
        instanceId = String,
        repository = String,
        baseCommit = String,
        issue      = Localization.Issue,
        documents  = Vector[Localization.Document]
    }

    /// This is an explicit scientific test mode, not a second CLI. Ordinary
    /// `flix test` performs no network acquisition. Set ATTUNE_PRIOR_MODE to
    /// `prepare` for the corpus census or `acquire` for the paid, retained run.
    @Test
    def semanticPriorGate(): Unit \ {Assert, Env, FileSystem, IO} =
        match Env.getVar("ATTUNE_PRIOR_MODE") {
            case None => ()
            case Some("prepare") => require(prepareOnly())
            case Some("acquire") => require(acquireAndReplay())
            case Some(mode) => Assert.fail("unknown ATTUNE_PRIOR_MODE: ${mode}")
        }

    def prepareOnly(): Result[Localization.Error, Unit] \ {FileSystem, IO} =
        prepareAll() |> Result.map(corpora -> {
            let requests = uniqueRequests(corpora);
            println("SEMANTIC_PRIOR_PREPARED cases=${Vector.length(corpora)} documents=${documentCount(corpora)} unique_requests=${Vector.length(requests)}");
            Vector.forEach(corpus ->
                println("SEMANTIC_PRIOR_CASE ${corpus#instanceId} documents=${Vector.length(corpus#documents)}"),
                corpora)
        })

    def acquireAndReplay(): Result[Localization.Error, Unit] \ {FileSystem, IO} =
        match prepareAll() {
            case Err(error) => Err(error)
            case Ok(corpora) => {
                let requests = uniqueRequests(corpora);
                let root = ".attune/semantic-prior-v1";
                match Localization.acquireRetained(root, requests) {
                    case Err(error) => Err(error)
                    case Ok(acquisition) => {
                        let first = observationMap(acquisition#observations);
                        match Vector.traverse(corpus -> rankCorpus(corpus, first), corpora) {
                            case Err(error) => Err(error)
                            case Ok(firstRankings) => match Localization.replayRetained(root, requests) {
                                case Err(error) => Err(error)
                                case Ok(replayed) => {
                                    let second = observationMap(replayed);
                                    match Vector.traverse(corpus -> rankCorpus(corpus, second), corpora) {
                                        case Err(error) => Err(error)
                                        case Ok(secondRankings) => {
                                            if (not sameObservations(first, second))
                                                Err(Localization.Error.ObservationStore("replay observations differ"))
                                            else if (not sameRankings(firstRankings, secondRankings))
                                                Err(Localization.Error.ObservationStore("replay rankings differ"))
                                            else match writeRankings(root, corpora, firstRankings, acquisition) {
                                                case Err(message) => Err(Localization.Error.ObservationStore(message))
                                                case Ok(()) => {
                                                    println("SEMANTIC_PRIOR_ACQUIRED cases=${Vector.length(corpora)} documents=${documentCount(corpora)} unique_requests=${Vector.length(requests)} replayed=${acquisition#replayed} live=${acquisition#live} input_tokens=${ToString.toString(acquisition#inputTokens)} total_tokens=${ToString.toString(acquisition#totalTokens)}");
                                                    println("SEMANTIC_PRIOR_REPLAY network_calls=0 ranking_equality=exact");
                                                    Ok(())
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

    def prepareAll(): Result[Localization.Error, Vector[Corpus]] \ {FileSystem, IO} =
        Repository.Grit.runWithNative(() -> Repository.Nix.runWithNative(() ->
            Vector.range(0, 15)
                |> Vector.traverse(index -> Localization.prepareRetained(
                    ".attune/repository-facts-v1", index))
                |> Result.map(Vector.map(prepared -> {
                    instanceId = prepared#instanceId,
                    repository = prepared#repository,
                    baseCommit = prepared#baseCommit,
                    issue = prepared#issue,
                    documents = prepared#documents
                }))))

    def requests(corpus: Corpus): Vector[Localization.Request] =
        Vector#{Localization.queryRequest(corpus#issue#text)} ++
            Vector.map(document -> document#request, corpus#documents)

    def uniqueRequests(corpora: Vector[Corpus]): Vector[Localization.Request] =
        Vector.flatMap(requests, corpora)
            |> Vector.map(request -> (request#id, request))
            |> Vector.toMap
            |> Map.toVector
            |> Vector.map(match (_, request) -> request)

    def documentCount(corpora: Vector[Corpus]): Int32 =
        Vector.foldLeft((count, corpus) -> count + Vector.length(corpus#documents), 0, corpora)

    def observationMap(observations: Vector[Localization.Observation]): Map[Localization.RequestId, Localization.Observation] =
        Vector.map(observation -> (observation#id, observation), observations) |> Vector.toMap

    def rankCorpus(
        corpus: Corpus,
        observations: Map[Localization.RequestId, Localization.Observation]
    ): Result[Localization.Error, Vector[Localization.Ranked]] = forM (
        queryObservation <- Map.get(Localization.queryRequest(corpus#issue#text)#id, observations)
            |> Option.toOk(Localization.Error.ReplayMiss);
        candidates <- Vector.traverse(document ->
            Map.get(document#request#id, observations)
                |> Option.toOk(Localization.Error.ReplayMiss)
                |> Result.map(observation -> {
                    identity = document#semanticId,
                    ordinal = document#ordinal,
                    vector = observation#vector
                }), corpus#documents)
    ) yield Localization.rank(queryObservation#vector, candidates)

    def sameObservations(
        left: Map[Localization.RequestId, Localization.Observation],
        right: Map[Localization.RequestId, Localization.Observation]
    ): Bool =
        Map.size(left) == Map.size(right) and Map.toVector(left) |> Vector.forAll(match (id, observation) ->
            match Map.get(id, right) {
                case None => false
                case Some(other) => observation#vector == other#vector
            })

    def sameRankings(
        left: Vector[Vector[Localization.Ranked]],
        right: Vector[Vector[Localization.Ranked]]
    ): Bool =
        Vector.map(rankingTuples, left) == Vector.map(rankingTuples, right)

    def rankingTuples(ranking: Vector[Localization.Ranked]): Vector[(String, Float64, Int32)] =
        Vector.map(item -> (item#identity, item#score, item#ordinal), ranking)

    def writeRankings(
        root: String,
        corpora: Vector[Corpus],
        rankings: Vector[Vector[Localization.Ranked]],
        acquisition: Localization.Acquisition
    ): Result[String, Unit] \ FileSystem = {
        let cases = Vector.zip(corpora, rankings) |> Vector.map(match (corpus, ranking) -> JObject(Map#{
            "instance_id" => JString(corpus#instanceId),
            "repository" => JString(corpus#repository),
            "base_commit" => JString(corpus#baseCommit),
            "documents" => JArray(Vector.map(documentJson, corpus#documents)),
            "ranking" => JArray(Vector.map(rankingJson, ranking))
        }));
        let payload = Json.toCompactString(JObject(Map#{
            "version" => ToJson.toJson(1),
            "provider" => JString(Localization.provider()),
            "model" => JString(Localization.model()),
            "instruction" => JString(Localization.instruction()),
            "text_limit" => ToJson.toJson(Localization.textLimit()),
            "dimension" => ToJson.toJson(Localization.dimension()),
            "issue_revision" => JString("7566cd247075886ef34453ff5582908c0255f5e6"),
            "replayed" => ToJson.toJson(acquisition#replayed),
            "live" => ToJson.toJson(acquisition#live),
            "input_tokens" => ToJson.toJson(acquisition#inputTokens),
            "total_tokens" => ToJson.toJson(acquisition#totalTokens),
            "cases" => JArray(cases)
        }));
        let written = run {
            FileSystem.write(str = payload, "${root}/rankings.json")
        } with FileSystem.withMkParentDirs
          with FileSystem.withAtomicWrite;
        Result.mapErr(ToString.toString, written)
    }

    def documentJson(document: Localization.Document): Json = JObject(Map#{
        "semantic_id" => JString(document#semanticId),
        "node_id" => JString(document#nodeId),
        "path" => JString(document#path),
        "name" => JString(document#name),
        "start_byte" => ToJson.toJson(document#startByte),
        "end_byte" => ToJson.toJson(document#endByte),
        "ordinal" => ToJson.toJson(document#ordinal)
    })

    def rankingJson(item: Localization.Ranked): Json = JObject(Map#{
        "semantic_id" => JString(item#identity),
        "score" => ToJson.toJson(item#score),
        "ordinal" => ToJson.toJson(item#ordinal)
    })

    def require(result: Result[Localization.Error, Unit]): Unit \ Assert = match result {
        case Ok(()) => ()
        case Err(error) => Assert.fail(ToString.toString(error))
    }
}
