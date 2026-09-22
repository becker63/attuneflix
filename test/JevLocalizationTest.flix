mod JevLocalizationTest {
    import java.lang.Integer
    import java.lang.System

    use Fs.FileSystem
    use Sys.Env
    use Util.Json
    use Util.Json.Json.{JArray, JObject, JString}
    use Util.Json.ToJson

    pub enum Error with ToString {
        case File(String),
        case Prepare(Localization.Error),
        case Tree(Localization.Tree.Error),
        case ReplayMismatch(String)
    }

    type alias CaseResult = {
        instanceId = String,
        repository = String,
        baseCommit = String,
        precomputeNanos = Int64,
        outcome = Localization.Tree.Outcome
    }

    /// Explicit scientific mode. Ordinary tests never access the network.
    /// ATTUNE_JEV_MODE=smoke validates live transport with synthetic text.
    /// acquire/replay execute the frozen 15-case solver path without gold.
    @Test
    def jevLocalizationGate(): Unit \ {Assert, Env, FileSystem, IO} =
        match Env.getVar("ATTUNE_JEV_MODE") {
            case None => ()
            case Some("smoke") => require(smoke())
            case Some("prepare") => require(runCases(startIndex(), false, false))
            case Some("acquire") => require(runCases(startIndex(), true, true))
            case Some("replay") => require(runCases(startIndex(), true, false))
            case Some(mode) => Assert.fail("unknown ATTUNE_JEV_MODE: ${mode}")
        }

    def smoke(): Result[Error, Unit] \ {FileSystem, IO} = {
        let state = Radii.Evaluate.State.Symbols(Set#{Repository.Structure.SymbolId.SymbolId(0)});
        let alternatives = Vector#{
            {
                action = Decide.Action.Stop,
                expression = None,
                state = Radii.Evaluate.stateId(state),
                criterion = "Keep the current synthetic symbol."
            },
            {
                action = Decide.Action.Follow(Radii.Atom.Calls),
                expression = Some(Radii.Evaluate.exprId(Radii.Expr.Atom(Radii.Atom.Calls))),
                state = Radii.Evaluate.stateId(state),
                criterion = "Follow the synthetic outgoing call."
            }
        };
        match Decide.request(Radii.Evaluate.stateId(state),
            "ATTUNE_LOCALIZATION_STATE_V1\nrepository: synthetic/fixture\nissue:\nLocate the synthetic failure.",
            alternatives) {
            case Err(error) => Err(Error.Tree(Localization.Tree.Error.Decide(error)))
            case Ok(request0) => match Decide.runWithAcquire(
                ".attune/jev-localization-smoke-v1", () -> Decide.policy(request0)) {
                case Err(error) => Err(Error.Tree(Localization.Tree.Error.Decide(error)))
                case Ok(first) => match Decide.runWithStoreReplay(
                    ".attune/jev-localization-smoke-v1", () -> Decide.policy(request0)) {
                    case Err(error) => Err(Error.Tree(Localization.Tree.Error.Decide(error)))
                    case Ok(second) =>
                        if (sameObservation(first, second)) {
                            println("JEV_SMOKE replay=exact network_calls_second_run=0 choice=${Decide.actionKey(first#choice)} model=${first#actualModel}");
                            Ok(())
                        } else Err(Error.ReplayMismatch("synthetic Jev observation changed on replay"))
                }
            }
        }
    }

    def runCases(start: Int32, execute: Bool, acquire: Bool): Result[Error, Unit] \ {FileSystem, IO} =
        match FileSystem.exists(".attune/semantic-prior-v1/rankings.parquet") {
            case Err(error) => Err(Error.File(ToString.toString(error)))
            case Ok(false) => Err(Error.File("missing retained Parquet prior"))
            case Ok(true) => {
                let payload = ScientificData.readObject(".attune/semantic-prior-v1/rankings.parquet");
                let tree = Localization.Tree.compile();
                println("JEV_TREE routes=${Localization.Tree.routeCount(tree)} symbol_routes=${Localization.Tree.symbolRouteCount(tree)} nodes=${Radii.Compiled.nodeCount(tree#program)}");
                match prepareCases(start, payload, tree, execute, acquire, Vector.empty()) {
                    case Err(error) => Err(error)
                    case Ok(results) => match writeResults(results) {
                        case Err(error) => Err(error)
                        case Ok(()) => {
                            println("JEV_LOCALIZATION mode=${if (execute) (if (acquire) "acquire" else "replay") else "prepare"} cases=${Vector.length(results)}");
                            Ok(())
                        }
                    }
                }
            }
        }

    def prepareCases(
        index: Int32,
        payload: String,
        tree: Localization.Tree.Tree,
        execute: Bool,
        acquire: Bool,
        results: Vector[CaseResult]
    ): Result[Error, Vector[CaseResult]] \ {FileSystem, IO} =
        if (index >= 15) Ok(results)
        else match Repository.Grit.runWithNative(() -> Repository.Nix.runWithNative(() -> Localization.prepareRetained(
            ".attune/repository-facts-v1", index))) {
            case Err(error) => Err(Error.Prepare(error))
            case Ok(prepared) => match Localization.Tree.decodePrior(prepared#instanceId, payload) {
                case Err(error) => Err(Error.Tree(error))
                case Ok(prior) => {
                    let precomputeStarted = System.nanoTime();
                    match Localization.Tree.compute(prepared, prior, tree) {
                    case Err(error) => Err(Error.Tree(error))
                    case Ok(computed) => {
                        let precomputeNanos = System.nanoTime() - precomputeStarted;
                        println("JEV_CASE_PREPARED ${prepared#instanceId} symbols=${Vector.length(prepared#world#symbols)} states=${computed#evaluation#metrics#statesInterned} memo_entries=${computed#evaluation#metrics#memoEntries}");
                        if (not execute) prepareCases(index + 1, payload, tree, execute, acquire, results)
                        else match decideCase(prepared, prior, computed, acquire) {
                            case Err(error) => Err(error)
                            case Ok(outcome) => {
                                println("JEV_CASE_DECIDED ${prepared#instanceId} depth=${Vector.length(outcome#path)} path=${pathText(outcome#path)} decisions=${Vector.length(outcome#decisions)}");
                                prepareCases(index + 1, payload, tree, execute, acquire,
                                    Vector.append(results, Vector#{{
                                        instanceId = prepared#instanceId,
                                        repository = prepared#repository,
                                        baseCommit = prepared#baseCommit,
                                        precomputeNanos = precomputeNanos,
                                        outcome = outcome
                                    }}))
                            }
                        }
                    }
                }
                }
            }
        }

    def decideCase(
        prepared: Localization.Prepared,
        prior: Localization.Tree.Prior,
        computed: Localization.Tree.Computed,
        acquire: Bool
    ): Result[Error, Localization.Tree.Outcome] \ {FileSystem, IO} = {
        let root = ".attune/jev-localization-v1";
        let result = if (acquire)
            Decide.runWithAcquire(root, () -> Localization.Tree.localize(prepared, prior, computed))
        else
            Decide.runWithStoreReplay(root, () -> Localization.Tree.localize(prepared, prior, computed));
        Result.mapErr(Error.Tree, result)
    }

    def writeResults(results: Vector[CaseResult]): Result[Error, Unit] \ IO = {
        let cases = Vector.map(result -> JObject(Map#{
            "instance_id" => JString(result#instanceId),
            "repository" => JString(result#repository),
            "base_commit" => JString(result#baseCommit),
            "path" => JArray(Vector.map(atom -> JString(Decide.actionKey(Decide.Action.Follow(atom))), result#outcome#path)),
            "decision_count" => ToJson.toJson(Vector.length(result#outcome#decisions)),
            "decisions" => JArray(Vector.map(decisionJson, result#outcome#decisions)),
            "structural_work" => JObject(Map#{
                "logical_paths" => ToJson.toJson(3279),
                "compiled_nodes" => ToJson.toJson(Radii.Compiled.nodeCount(Localization.Tree.compile()#program)),
                "states_interned" => ToJson.toJson(result#outcome#metrics#statesInterned),
                "memo_entries" => ToJson.toJson(result#outcome#metrics#memoEntries),
                "memo_slots" => ToJson.toJson(result#outcome#metrics#memoSlots),
                "precompute_nanos" => ToJson.toJson(result#precomputeNanos)
            }),
            "ranking" => JArray(Vector.map(item -> JString(item#identity), result#outcome#ranking))
        }), results);
        let payload = Json.toCompactString(JObject(Map#{
            "version" => ToJson.toJson(1),
            "protocol" => JString(Decide.protocol()),
            "model" => JString(Decide.model()),
            "center_count" => ToJson.toJson(Localization.Tree.centerCount()),
            "max_depth" => ToJson.toJson(Localization.Tree.maxDepth()),
            "cases" => JArray(cases)
        }));
        let _ = ScientificData.writeObject(".attune/jev-localization-v1/outcomes.parquet", payload);
        Ok(())
    }

    def decisionJson(observation: Decide.Observation): Json = JObject(Map#{
        "choice" => JString(Decide.actionKey(observation#choice)),
        "choice_index" => ToJson.toJson(observation#choiceIndex),
        "choice_probability" => ToJson.toJson(Map.get(observation#choice, observation#probabilities)),
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

    def sameObservation(left: Decide.Observation, right: Decide.Observation): Bool =
        left#decision == right#decision and left#choice == right#choice and
        left#choiceIndex == right#choiceIndex and left#probabilities == right#probabilities and
        left#confidence == right#confidence and left#provider == right#provider and
        left#actualModel == right#actualModel and left#responseId == right#responseId

    def startIndex(): Int32 \ Env = match Env.getVar("ATTUNE_JEV_START") {
        case None => 0
        case Some(value) => Integer.parseInt(value)
    }

    def pathText(path: Vector[Radii.Atom]): String =
        if (Vector.isEmpty(path)) "stop"
        else Vector.map(atom -> Decide.actionKey(Decide.Action.Follow(atom)), path)
            |> Vector.toList |> List.intersperse(">>") |> List.fold

    def require(result: Result[Error, Unit]): Unit \ Assert = match result {
        case Ok(()) => ()
        case Err(error) => Assert.fail(ToString.toString(error))
    }
}
