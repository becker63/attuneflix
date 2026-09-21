mod JevPolicyHillclimb {
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
        case Decide(Decide.Error),
        case UnexpectedAction(Decide.Action)
    }

    type alias Continuation = {
        suffix = Vector[Radii.Atom],
        route = Localization.Tree.Route,
        state = Radii.Evaluate.State
    }

    type alias CaseResult = {
        instanceId = String,
        repository = String,
        baseCommit = String,
        precomputeNanos = Int64,
        outcome = Localization.Tree.Outcome
    }

    def iteration(): String = "006-parent-delta"

    def protocol(): String = "attune-jev-policy-hillclimb-006-parent-delta-v1"

    def root(): String = ".attune/experiments/jev-policy-hillclimb/${iteration()}"

    def question(): String =
        "Choose the typed repository-structure continuation whose terminal symbol preview is most likely to localize the reported issue. " +
        "Each continuation contains one to three valid structural actions and is executed atomically. " +
        "Use the explicit parent-to-terminal delta to distinguish useful new evidence from no-op or destructive movement. " +
        "Prefer issue-relevant symbols over merely large frontiers. You are ranking continuations only; stopping is decided separately."

    def stopQuestion(): String =
        "Compare exactly two localization frontiers. Choose stop to retain the current frontier, or choose the proposed continuation only when its terminal preview is more likely to localize the reported issue."

    /// Ordinary test runs are pure and network-free. Explicit modes reuse the
    /// frozen facts/prior and acquire or replay only this iteration's decisions.
    @Test
    def gate(): Unit \ {Assert, Env, FileSystem, IO} =
        match Env.getVar("ATTUNE_HILLCLIMB_MODE") {
            case None => requestIdentityLaw()
            case Some("prepare") => require(runCases(false, false))
            case Some("acquire") => require(runCases(true, true))
            case Some("replay") => require(runCases(true, false))
            case Some(value) => Assert.fail("unknown ATTUNE_HILLCLIMB_MODE: ${value}")
        }

    /// Protocol identity is model-visible and changes the retained key without
    /// exposing transport secrets or evaluator gold.
    def requestIdentityLaw(): Unit \ Assert = {
        let state = Radii.Evaluate.State.Symbols(Set#{Repository.Structure.SymbolId.SymbolId(0)});
        let alternative = {
            action = Decide.Action.FollowPath(Vector#{Radii.Atom.Calls}),
            expression = Some(Radii.Evaluate.exprId(Radii.Expr.Atom(Radii.Atom.Calls))),
            state = Radii.Evaluate.stateId(state),
            criterion = "fixture"
        };
        let left = Decide.requestWith(
            {protocol = protocol(), question = question()},
            Radii.Evaluate.stateId(state), "fixture", Vector#{alternative});
        let right = Decide.requestWith(
            {protocol = protocol() + "-different", question = question()},
            Radii.Evaluate.stateId(state), "fixture", Vector#{alternative});
        match (left, right) {
            case (Ok(l), Ok(r)) => Assert.assertTrue(l#decision != r#decision)
            case _ => Assert.fail("fixture requests must be valid")
        }
    }

    def runCases(execute: Bool, acquire: Bool): Result[Error, Unit] \ {FileSystem, IO} =
        match FileSystem.read(".attune/semantic-prior-v1/rankings.json") {
            case Err(error) => Err(Error.File(ToString.toString(error)))
            case Ok(payload) => {
                let tree = Localization.Tree.compile();
                println("HILLCLIMB_TREE iteration=${iteration()} routes=${Localization.Tree.routeCount(tree)} nodes=${Radii.Compiled.nodeCount(tree#program)}");
                prepareCases(0, payload, tree, execute, acquire, Vector.empty())
                    |> Result.flatMap(writeResults)
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
        else match Repository.Grit.runWithNative(() -> Repository.Nix.runWithNative(() ->
            Localization.prepareRetained(".attune/repository-facts-v1", index))) {
            case Err(error) => Err(Error.Prepare(error))
            case Ok(prepared) => match Localization.Tree.decodePrior(prepared#instanceId, payload) {
                case Err(error) => Err(Error.Tree(error))
                case Ok(prior) => {
                    let started = System.nanoTime();
                    match Localization.Tree.compute(prepared, prior, tree) {
                        case Err(error) => Err(Error.Tree(error))
                        case Ok(computed) => {
                            let elapsed = System.nanoTime() - started;
                            println("HILLCLIMB_CASE_PREPARED ${prepared#instanceId} states=${computed#evaluation#metrics#statesInterned}");
                            if (not execute)
                                prepareCases(index + 1, payload, tree, execute, acquire, results)
                            else match decideCase(prepared, prior, computed, acquire) {
                                case Err(error) => Err(error)
                                case Ok(outcome) => {
                                    println("HILLCLIMB_CASE_DECIDED ${prepared#instanceId} depth=${Vector.length(outcome#path)} path=${pathText(outcome#path)} calls=${Vector.length(outcome#decisions)}");
                                    prepareCases(index + 1, payload, tree, execute, acquire,
                                        Vector.append(results, Vector#{{
                                            instanceId = prepared#instanceId,
                                            repository = prepared#repository,
                                            baseCommit = prepared#baseCommit,
                                            precomputeNanos = elapsed,
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
        let runPolicy = () -> navigate(prepared, prior, computed,
            Vector.empty(), computed#input, Vector.empty());
        if (acquire)
            Decide.runWithAcquire(root(), runPolicy)
        else
            Decide.runWithStoreReplay(root(), runPolicy)
    }

    def navigate(
        prepared: Localization.Prepared,
        prior: Localization.Tree.Prior,
        computed: Localization.Tree.Computed,
        path: Vector[Radii.Atom],
        current: Radii.Evaluate.State,
        decisions: Vector[Decide.Observation]
    ): Result[Error, Localization.Tree.Outcome] \ Decide.Choice = {
        let depth = Vector.length(path);
        if (depth == Localization.Tree.maxDepth())
            Ok(finish(prior, computed, path, current, decisions))
        else forM (
            continuations <- continuations(path, computed);
            outcome <- if (Vector.isEmpty(continuations))
                Ok(finish(prior, computed, path, current, decisions))
            else {
            let rankedAlternatives = continuationAlternatives(prepared#world, prior, current, continuations);
            forM (
            rankRequest <- Decide.requestWith(
                {protocol = protocol() + "-rank", question = question()},
                Radii.Evaluate.stateId(current),
                visibleState(prepared, prior, path, current),
                rankedAlternatives
            ) |> Result.mapErr(Error.Decide);
            rankObservation <- Decide.policy(rankRequest) |> Result.mapErr(Error.Decide);
            proposed <- match rankObservation#choice {
                case Decide.Action.FollowPath(suffix) => Vector.find(item -> item#suffix == suffix, continuations)
                    |> Option.toOk(Error.UnexpectedAction(rankObservation#choice))
                case _ => Err(Error.UnexpectedAction(rankObservation#choice))
            };
            outcome <- if (depth == 0)
                navigate(prepared, prior, computed,
                    Vector.append(path, proposed#suffix), proposed#state,
                    Vector.append(decisions, Vector#{rankObservation}))
            else {
                let comparison = comparisonAlternatives(prepared#world, prior, current, proposed);
                forM (
                stopRequest <- Decide.requestWith(
                    {protocol = protocol() + "-stop", question = stopQuestion()},
                    Radii.Evaluate.stateId(current),
                    visibleState(prepared, prior, path, current),
                    comparison
                ) |> Result.mapErr(Error.Decide);
                stopObservation <- Decide.policy(stopRequest) |> Result.mapErr(Error.Decide);
                nextDecisions = Vector.append(decisions, Vector#{rankObservation, stopObservation});
                next <- match stopObservation#choice {
                    case Decide.Action.Stop => Ok(finish(prior, computed, path, current, nextDecisions))
                    case Decide.Action.FollowPath(suffix) => match Vector.find(item -> item#suffix == suffix, continuations) {
                        case None => Err(Error.UnexpectedAction(stopObservation#choice))
                        case Some(item) => navigate(prepared, prior, computed,
                            Vector.append(path, suffix), item#state, nextDecisions)
                    }
                    case Decide.Action.Follow(_) => Err(Error.UnexpectedAction(stopObservation#choice))
                }
                ) yield next
            }
            ) yield outcome
            }
        ) yield outcome
    }

    def continuations(
        path: Vector[Radii.Atom],
        computed: Localization.Tree.Computed
    ): Result[Error, Vector[Continuation]] =
        Vector.filter(route -> {
            let extra = Vector.length(route#steps) - Vector.length(path);
            isPrefix(path, route#steps) and extra >= 1 and extra <= 3 and
                snd(Radii.endpoints(route#expression)) == Radii.Domain.Symbol
        }, computed#tree#routes)
        |> Vector.traverse(route -> Localization.Tree.stateAt(route#steps, computed)
            |> Result.mapErr(Error.Tree)
            |> Result.map(state -> {
                suffix = Vector.slice(start = Vector.length(path), end = Vector.length(route#steps), route#steps),
                route = route,
                state = state
            }))

    def continuationAlternatives(
        world: Repository.World,
        prior: Localization.Tree.Prior,
        current: Radii.Evaluate.State,
        continuations0: Vector[Continuation]
    ): Vector[Decide.Alternative] = {
        Vector.map(item -> {
            action = Decide.Action.FollowPath(item#suffix),
            expression = Some(Radii.Evaluate.exprId(item#route#expression)),
            state = Radii.Evaluate.stateId(item#state),
            criterion = "Take continuation ${pathText(item#suffix)} (${Vector.length(item#suffix)} actions). " +
                stateDelta(current, item#state) + ". Terminal " +
                Localization.Tree.preview(world, prior, item#state)
        }, continuations0)
    }

    def stateDelta(current: Radii.Evaluate.State, terminal: Radii.Evaluate.State): String =
        match (current, terminal) {
            case (Radii.Evaluate.State.Symbols(before), Radii.Evaluate.State.Symbols(after)) => {
                let union0 = Set.union(before, after);
                let overlap = if (Set.isEmpty(union0)) 1.0 else
                    ratio(Set.size(Set.intersection(before, after)), Set.size(union0));
                "Delta from current: added_symbols=${Set.size(Set.difference(after, before))} " +
                "removed_symbols=${Set.size(Set.difference(before, after))} " +
                "jaccard=${overlap} exact_revisit=${before == after}"
            }
            case _ => "Delta from current: different_domain=true exact_revisit=${current == terminal}"
        }

    def ratio(numerator: Int32, denominator: Int32): Float64 =
        if (denominator == 0) 0.0 else
            Int32.toFloat64(numerator) / Int32.toFloat64(denominator)

    def comparisonAlternatives(
        world: Repository.World,
        prior: Localization.Tree.Prior,
        current: Radii.Evaluate.State,
        proposed: Continuation
    ): Vector[Decide.Alternative] = Vector#{
        {
            action = Decide.Action.Stop,
            expression = None,
            state = Radii.Evaluate.stateId(current),
            criterion = "Stop and retain current. " + Localization.Tree.preview(world, prior, current)
        },
        {
            action = Decide.Action.FollowPath(proposed#suffix),
            expression = Some(Radii.Evaluate.exprId(proposed#route#expression)),
            state = Radii.Evaluate.stateId(proposed#state),
            criterion = "Take proposed continuation ${pathText(proposed#suffix)}. " +
                stateDelta(current, proposed#state) + ". Terminal " +
                Localization.Tree.preview(world, prior, proposed#state)
        }
    }

    def finish(
        prior: Localization.Tree.Prior,
        computed: Localization.Tree.Computed,
        path: Vector[Radii.Atom],
        state: Radii.Evaluate.State,
        decisions: Vector[Decide.Observation]
    ): Localization.Tree.Outcome = {
        path = path,
        finalState = state,
        ranking = Localization.Tree.promote(prior#ranking, state),
        decisions = decisions,
        metrics = computed#evaluation#metrics
    }

    def visibleState(
        prepared: Localization.Prepared,
        prior: Localization.Tree.Prior,
        path: Vector[Radii.Atom],
        current: Radii.Evaluate.State
    ): String = {
        let Localization.IssueText.IssueText(issue) = prepared#issue#text;
        "ATTUNE_LOCALIZATION_MACRO_STATE_V1\n" +
        "repository: ${prepared#repository}\n" +
        "base_commit: ${prepared#baseCommit}\n" +
        "issue:\n${issue}\n" +
        "depth: ${Vector.length(path)}/${Localization.Tree.maxDepth()}\n" +
        "path: ${pathText(path)}\n" +
        "current: ${Localization.Tree.preview(prepared#world, prior, current)}"
    }

    def isPrefix(prefix: Vector[a], values: Vector[a]): Bool with Eq[a] =
        Vector.length(prefix) <= Vector.length(values) and prefixAt(prefix, values, 0)

    def prefixAt(prefix: Vector[a], values: Vector[a], index: Int32): Bool with Eq[a] =
        if (index >= Vector.length(prefix)) true
        else Vector.get(index, prefix) == Vector.get(index, values) and
            prefixAt(prefix, values, index + 1)

    def writeResults(results: Vector[CaseResult]): Result[Error, Unit] \ FileSystem = {
        let cases = Vector.map(result -> JObject(Map#{
            "instance_id" => JString(result#instanceId),
            "repository" => JString(result#repository),
            "base_commit" => JString(result#baseCommit),
            "path" => JArray(Vector.map(atom -> JString(atomName(atom)), result#outcome#path)),
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
            "iteration" => JString(iteration()),
            "protocol" => JString(protocol()),
            "model" => JString(Decide.model()),
            "center_count" => ToJson.toJson(Localization.Tree.centerCount()),
            "max_depth" => ToJson.toJson(Localization.Tree.maxDepth()),
            "cases" => JArray(cases)
        }));
        let written = run {
            FileSystem.write(str = payload, "${root()}/outcomes.json")
        } with FileSystem.withMkParentDirs
          with FileSystem.withAtomicWrite;
        Result.mapErr(error -> Error.File(ToString.toString(error)), written)
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

    def pathText(path: Vector[Radii.Atom]): String =
        if (Vector.isEmpty(path)) "root"
        else Vector.map(atomName, path) |> Vector.toList |> List.intersperse(">>") |> List.fold

    def atomName(atom: Radii.Atom): String = Decide.actionKey(Decide.Action.Follow(atom))

    def require(result: Result[Error, Unit]): Unit \ Assert = match result {
        case Ok(()) => ()
        case Err(error) => Assert.fail(ToString.toString(error))
    }
}
