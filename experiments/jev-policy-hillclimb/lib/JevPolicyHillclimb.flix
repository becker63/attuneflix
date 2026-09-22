pub mod JevPolicyHillclimb {
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

    type alias PlanningResult = {
        winner = Continuation,
        observations = Vector[Decide.Observation]
    }

    type alias TemplateCandidate = {
        label = String,
        path = Vector[Radii.Atom],
        state = Radii.Evaluate.State
    }

    type alias TemplateTournament = {
        winner = TemplateCandidate,
        observations = Vector[Decide.Observation]
    }

    def iteration(): String = "016-template-tournament"

    def protocol(): String = "attune-jev-policy-hillclimb-016-template-tournament-v1"

    def bestProtocol(): String = "attune-jev-policy-hillclimb-012-pruned-planner-portfolio-v1"

    def bestRoot(): String =
        ".attune/experiments/jev-policy-hillclimb/012-pruned-planner-portfolio"

    def deepProtocol(): String = "attune-jev-policy-hillclimb-013-deep-planner-portfolio-v1"

    def deepRoot(): String =
        ".attune/experiments/jev-policy-hillclimb/013-deep-planner-portfolio"

    def scaleClassicRoot(): String =
        ".attune/experiments/swe-explore-js-ts-scale/003-force-first-macro"

    def scaleBestRoot(): String =
        ".attune/experiments/swe-explore-js-ts-scale/012-pruned-planner-portfolio"

    def scaleDeepRoot(): String =
        ".attune/experiments/swe-explore-js-ts-scale/013-deep-planner-portfolio"

    def classicProtocol(): String = "attune-jev-policy-hillclimb-003-force-first-macro-v1"

    def classicRoot(): String =
        ".attune/experiments/jev-policy-hillclimb/003-force-first-macro"

    def root(): String = ".attune/experiments/jev-policy-hillclimb/${iteration()}"

    def question(): String =
        "Choose the typed repository-structure continuation whose terminal symbol preview is most likely to localize the reported issue. " +
        "Each continuation contains one to three valid structural actions and is executed atomically. " +
        "Prefer issue-relevant symbols over merely large frontiers. You are ranking continuations only; stopping is decided separately."

    def stopQuestion(): String =
        "Compare exactly two localization frontiers. Choose stop to retain the current frontier, or choose the proposed continuation only when its terminal preview is more likely to localize the reported issue."

    def planQuestion(): String =
        "Choose the typed short-horizon plan whose final symbol preview is most likely to localize the reported issue. Each plan was constructed by first choosing a root continuation and then choosing its best available continuation. Prefer issue relevance over merely large frontiers."

    def expertQuestion(): String =
        "Choose between two independently generated structural localization frontiers. Prefer the final symbol preview most likely to localize the reported issue. The expert labels carry no quality ordering."

    def tournamentQuestion(): String =
        "Compare exactly two structural localization frontiers and choose the one most likely to localize the reported issue. Judge only the issue and visible terminal evidence; prefer relevance over frontier size."

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
        match FileSystem.exists(".attune/semantic-prior-v1/rankings.parquet") {
            case Err(error) => Err(Error.File(ToString.toString(error)))
            case Ok(false) => Err(Error.File("missing retained Parquet prior"))
            case Ok(true) => {
                let payload = ScientificData.readObject(".attune/semantic-prior-v1/rankings.parquet");
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
    ): Result[Error, Localization.Tree.Outcome] \ {FileSystem, IO} =
        match Decide.runWithStoreReplay(classicRoot(), () ->
            classicNavigate(classicProtocol(), prepared, prior, computed,
                Vector.empty(), computed#input, Vector.empty())) {
            case Err(error) => Err(error)
            case Ok(classic) => match Decide.runWithStoreReplay(bestRoot(), () ->
                portfolio(bestProtocol(), 1, prepared, prior, computed, classic)) {
                case Err(error) => Err(error)
                case Ok(best) => match Decide.runWithStoreReplay(deepRoot(), () -> forM (
                    deep <- planningExpert(deepProtocol(), 2, prepared, prior, computed);
                    selected <- selectExpert(deepProtocol(), prepared, prior, computed, best, deep)
                ) yield selected) {
                    case Err(error) => Err(error)
                    case Ok(best013) => {
                        let runCandidate = () -> selectTemplateTournament(
                            prepared, prior, computed, best013);
                        if (acquire) Decide.runWithAcquire(root(), runCandidate)
                        else Decide.runWithStoreReplay(root(), runCandidate)
                    }
                }
            }
        }

    /// Exact frozen iteration-013 policy for the scale generalization run.
    /// Store roots are operational only; all model-visible protocols, prompts,
    /// alternatives, tie-breaking, and structural semantics remain unchanged.
    pub def frozen013(
        prepared: Localization.Prepared,
        prior: Localization.Tree.Prior,
        computed: Localization.Tree.Computed,
        acquire: Bool
    ): Result[Error, Localization.Tree.Outcome] \ {FileSystem, IO} =
        runScalePolicy(scaleClassicRoot(), acquire, () ->
            classicNavigate(classicProtocol(), prepared, prior, computed,
                Vector.empty(), computed#input, Vector.empty()))
        |> Result.flatMap(classic -> runScalePolicy(scaleBestRoot(), acquire, () ->
            portfolio(bestProtocol(), 1, prepared, prior, computed, classic)))
        |> Result.flatMap(best -> runScalePolicy(scaleDeepRoot(), acquire, () -> forM (
            deep <- planningExpert(deepProtocol(), 2, prepared, prior, computed);
            selected <- selectExpert(deepProtocol(), prepared, prior, computed, best, deep)
        ) yield selected))

    def runScalePolicy(
        root0: String,
        acquire: Bool,
        f: Unit -> Result[Error, Localization.Tree.Outcome] \ ef
    ): Result[Error, Localization.Tree.Outcome] \ (ef - Decide.Choice) + {FileSystem, IO} =
        if (acquire) Decide.runWithAcquire(root0, f)
        else Decide.runWithStoreReplay(root0, f)

    def portfolio(
        policyProtocol: String,
        rolloutDepth: Int32,
        prepared: Localization.Prepared,
        prior: Localization.Tree.Prior,
        computed: Localization.Tree.Computed,
        classic: Localization.Tree.Outcome
    ): Result[Error, Localization.Tree.Outcome] \ Decide.Choice = forM (
        planned <- planningExpert(policyProtocol, rolloutDepth, prepared, prior, computed);
        selected <- selectExpert(policyProtocol, prepared, prior, computed, classic, planned)
    ) yield selected

    def planningExpert(
        policyProtocol: String,
        rolloutDepth: Int32,
        prepared: Localization.Prepared,
        prior: Localization.Tree.Prior,
        computed: Localization.Tree.Computed
    ): Result[Error, Localization.Tree.Outcome] \ Decide.Choice =
        match continuations(Vector.empty(), computed) {
            case Err(error) => Err(error)
            case Ok(roots) => forM (
                planning <- planRoot(policyProtocol, rolloutDepth,
                    prepared, prior, computed, computed#input,
                    Vector.sortBy(item -> pathText(item#suffix), roots));
                outcome <- classicNavigate(policyProtocol, prepared, prior, computed,
                    planning#winner#suffix, planning#winner#state, planning#observations)
            ) yield outcome
        }

    def selectExpert(
        policyProtocol: String,
        prepared: Localization.Prepared,
        prior: Localization.Tree.Prior,
        computed: Localization.Tree.Computed,
        classic: Localization.Tree.Outcome,
        planned: Localization.Tree.Outcome
    ): Result[Error, Localization.Tree.Outcome] \ Decide.Choice =
        if (classic#path == planned#path) Ok(classic)
        else forM (
        alternatives <- expertAlternatives(prepared#world, prior, computed, classic, planned);
        request0 <- Decide.requestWith(
            {protocol = policyProtocol, question = expertQuestion()},
            Radii.Evaluate.stateId(computed#input),
            visibleState(prepared, prior, Vector.empty(), computed#input),
            alternatives
        ) |> Result.mapErr(Error.Decide);
        observation <- Decide.policy(request0) |> Result.mapErr(Error.Decide);
        selected <- match observation#choice {
            case Decide.Action.FollowPath(path) if path == classic#path => Ok(classic)
            case Decide.Action.FollowPath(path) if path == planned#path => Ok(planned)
            case Decide.Action.Follow(_) => Err(Error.UnexpectedAction(observation#choice))
            case _ => Err(Error.UnexpectedAction(observation#choice))
        };
        allDecisions = Vector.append(classic#decisions,
            Vector.append(planned#decisions, Vector#{observation}))
    ) yield finish(prior, computed, selected#path, selected#finalState, allDecisions)

    def expertAlternatives(
        world: Repository.World,
        prior: Localization.Tree.Prior,
        computed: Localization.Tree.Computed,
        classic: Localization.Tree.Outcome,
        planned: Localization.Tree.Outcome
    ): Result[Error, Vector[Decide.Alternative]] =
        Vector#{("Expert A", classic), ("Expert B", planned)}
        |> Vector.traverse(match (label, outcome) ->
            Localization.Tree.routeAt(outcome#path, computed#tree)
            |> Result.mapErr(Error.Tree)
            |> Result.map(route -> {
                action = Decide.Action.FollowPath(outcome#path),
                expression = Some(Radii.Evaluate.exprId(route#expression)),
                state = Radii.Evaluate.stateId(outcome#finalState),
                criterion = "${label}, path ${pathText(outcome#path)}. Final " +
                    Localization.Tree.preview(world, prior, outcome#finalState)
            }))

    def selectTemplateTournament(
        prepared: Localization.Prepared,
        prior: Localization.Tree.Prior,
        computed: Localization.Tree.Computed,
        best: Localization.Tree.Outcome
    ): Result[Error, Localization.Tree.Outcome] \ Decide.Choice = forM (
            candidates <- templateCandidates(computed);
            tournament <- templateTournamentRound(prepared, prior, computed,
                candidates, 0, Vector.empty(), Vector.empty());
            selected <- compareTemplateWinner(prepared, prior, computed,
                best, tournament#winner, tournament#observations)
        ) yield selected

    def templateTournamentRound(
        prepared: Localization.Prepared,
        prior: Localization.Tree.Prior,
        computed: Localization.Tree.Computed,
        candidates: Vector[TemplateCandidate],
        index: Int32,
        next: Vector[TemplateCandidate],
        observations: Vector[Decide.Observation]
    ): Result[Error, TemplateTournament] \ Decide.Choice =
        if (Vector.length(candidates) == 1 and Vector.isEmpty(next))
            Ok({winner = Vector.get(0, candidates), observations = observations})
        else if (index >= Vector.length(candidates))
            templateTournamentRound(prepared, prior, computed,
                next, 0, Vector.empty(), observations)
        else if (index + 1 >= Vector.length(candidates))
            templateTournamentRound(prepared, prior, computed,
                candidates, index + 2,
                Vector.append(next, Vector#{Vector.get(index, candidates)}), observations)
        else {
            let left = Vector.get(index, candidates);
            let right = Vector.get(index + 1, candidates);
            let pair = Vector#{left, right};
            forM (
                alternatives <- templateAlternatives(prepared#world, prior, computed, pair);
                request0 <- Decide.requestWith(
                    {protocol = protocol() + "-template-pair", question = tournamentQuestion()},
                    Radii.Evaluate.stateId(computed#input),
                    visibleState(prepared, prior, Vector.empty(), computed#input),
                    alternatives
                ) |> Result.mapErr(Error.Decide);
                observation <- Decide.policy(request0) |> Result.mapErr(Error.Decide);
                winner <- candidateForChoice(observation#choice, pair);
                result <- templateTournamentRound(prepared, prior, computed,
                    candidates, index + 2, Vector.append(next, Vector#{winner}),
                    Vector.append(observations, Vector#{observation}))
            ) yield result
        }

    def compareTemplateWinner(
        prepared: Localization.Prepared,
        prior: Localization.Tree.Prior,
        computed: Localization.Tree.Computed,
        best: Localization.Tree.Outcome,
        learned: TemplateCandidate,
        tournamentObservations: Vector[Decide.Observation]
    ): Result[Error, Localization.Tree.Outcome] \ Decide.Choice = {
        let bestCandidate = {label = "Search expert", path = best#path, state = best#finalState};
        if (best#path == learned#path)
            Ok(finish(prior, computed, best#path, best#finalState,
                Vector.append(best#decisions, tournamentObservations)))
        else forM (
            alternatives <- templateAlternatives(prepared#world, prior, computed,
                Vector#{bestCandidate, learned});
            request0 <- Decide.requestWith(
                {protocol = protocol() + "-final", question = expertQuestion()},
                Radii.Evaluate.stateId(computed#input),
                visibleState(prepared, prior, Vector.empty(), computed#input),
                alternatives
            ) |> Result.mapErr(Error.Decide);
            observation <- Decide.policy(request0) |> Result.mapErr(Error.Decide);
            selected <- candidateForChoice(observation#choice, Vector#{bestCandidate, learned});
            allDecisions = Vector.append(best#decisions,
                Vector.append(tournamentObservations, Vector#{observation}))
        ) yield finish(prior, computed, selected#path, selected#state, allDecisions)
    }

    def candidateForChoice(
        choice: Decide.Action,
        candidates: Vector[TemplateCandidate]
    ): Result[Error, TemplateCandidate] = match choice {
        case Decide.Action.Stop => Vector.find(candidate -> Vector.isEmpty(candidate#path), candidates)
            |> Option.toOk(Error.UnexpectedAction(choice))
        case Decide.Action.FollowPath(path) => Vector.find(candidate -> candidate#path == path, candidates)
            |> Option.toOk(Error.UnexpectedAction(choice))
        case Decide.Action.Follow(_) => Err(Error.UnexpectedAction(choice))
    }

    def templateCandidates(
        computed: Localization.Tree.Computed
    ): Result[Error, Vector[TemplateCandidate]] =
        learnedTemplates()
        |> Vector.traverse(path -> Localization.Tree.stateAt(path, computed)
            |> Result.mapErr(Error.Tree)
            |> Result.map(state -> {label = "Learned route template", path = path, state = state}))
        |> Result.map(templates -> uniqueTemplateCandidates(Vector.append(Vector#{
            {label = "Semantic prior", path = Vector.empty(), state = computed#input}
        }, templates), 0, Set.empty(), Vector.empty()))

    def uniqueTemplateCandidates(
        candidates: Vector[TemplateCandidate],
        index: Int32,
        seen: Set[Vector[Radii.Atom]],
        result: Vector[TemplateCandidate]
    ): Vector[TemplateCandidate] =
        if (index >= Vector.length(candidates)) result
        else {
            let candidate = Vector.get(index, candidates);
            if (Set.memberOf(candidate#path, seen))
                uniqueTemplateCandidates(candidates, index + 1, seen, result)
            else uniqueTemplateCandidates(candidates, index + 1,
                Set.insert(candidate#path, seen), Vector.append(result, Vector#{candidate}))
        }

    def templateAlternatives(
        world: Repository.World,
        prior: Localization.Tree.Prior,
        computed: Localization.Tree.Computed,
        candidates: Vector[TemplateCandidate]
    ): Result[Error, Vector[Decide.Alternative]] =
        Vector.traverse(candidate -> if (Vector.isEmpty(candidate#path)) Ok({
            action = Decide.Action.Stop,
            expression = None,
            state = Radii.Evaluate.stateId(candidate#state),
            criterion = "${candidate#label}. " + Localization.Tree.preview(world, prior, candidate#state)
        }) else Localization.Tree.routeAt(candidate#path, computed#tree)
            |> Result.mapErr(Error.Tree)
            |> Result.map(route -> {
                action = Decide.Action.FollowPath(candidate#path),
                expression = Some(Radii.Evaluate.exprId(route#expression)),
                state = Radii.Evaluate.stateId(candidate#state),
                criterion = "${candidate#label}, path ${pathText(candidate#path)}. Final " +
                    Localization.Tree.preview(world, prior, candidate#state)
            }), candidates)

    /// Twelve unique non-root oracle paths learned from the frozen
    /// development set. They are global policy parameters: every route is
    /// evaluated for every issue, with no instance/repository lookup.
    def learnedTemplates(): Vector[Vector[Radii.Atom]] = Vector#{
        Vector#{Radii.Atom.Callers, Radii.Atom.DefinedIn, Radii.Atom.ImportedBy, Radii.Atom.ImportedBy, Radii.Atom.Defines, Radii.Atom.Callers, Radii.Atom.Calls},
        Vector#{Radii.Atom.Calls, Radii.Atom.Callers, Radii.Atom.Callers, Radii.Atom.Calls, Radii.Atom.Calls},
        Vector#{Radii.Atom.Calls, Radii.Atom.Callers, Radii.Atom.DefinedIn, Radii.Atom.ImportedBy, Radii.Atom.Defines, Radii.Atom.Calls, Radii.Atom.Calls},
        Vector#{Radii.Atom.Calls, Radii.Atom.DefinedIn, Radii.Atom.Imports, Radii.Atom.ImportedBy, Radii.Atom.Imports, Radii.Atom.Defines},
        Vector#{Radii.Atom.DefinedIn, Radii.Atom.Defines, Radii.Atom.Calls, Radii.Atom.Calls, Radii.Atom.DefinedIn, Radii.Atom.Defines, Radii.Atom.Calls},
        Vector#{Radii.Atom.DefinedIn, Radii.Atom.ImportedBy, Radii.Atom.Defines},
        Vector#{Radii.Atom.DefinedIn, Radii.Atom.ImportedBy, Radii.Atom.ImportedBy, Radii.Atom.ImportedBy, Radii.Atom.Imports, Radii.Atom.Defines},
        Vector#{Radii.Atom.DefinedIn, Radii.Atom.Imports, Radii.Atom.ImportedBy, Radii.Atom.Defines},
        Vector#{Radii.Atom.DefinedIn, Radii.Atom.Imports, Radii.Atom.ImportedBy, Radii.Atom.Defines, Radii.Atom.Callers, Radii.Atom.Callers, Radii.Atom.Calls},
        Vector#{Radii.Atom.DefinedIn, Radii.Atom.Imports, Radii.Atom.ImportedBy, Radii.Atom.Defines, Radii.Atom.Calls},
        Vector#{Radii.Atom.DefinedIn, Radii.Atom.Imports, Radii.Atom.ImportedBy, Radii.Atom.Imports, Radii.Atom.Imports, Radii.Atom.Defines, Radii.Atom.Calls},
        Vector#{Radii.Atom.DefinedIn, Radii.Atom.Imports, Radii.Atom.ImportedBy, Radii.Atom.Imports, Radii.Atom.Imports, Radii.Atom.Imports, Radii.Atom.Defines}
    }

    def classicNavigate(
        policyProtocol: String,
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
                forM (
                rankRequest <- Decide.requestWith(
                    {protocol = policyProtocol + "-rank", question = question()},
                    Radii.Evaluate.stateId(current),
                    visibleState(prepared, prior, path, current),
                    continuationAlternatives(prepared#world, prior, continuations)
                ) |> Result.mapErr(Error.Decide);
                rankObservation <- Decide.policy(rankRequest) |> Result.mapErr(Error.Decide);
                proposed <- match rankObservation#choice {
                    case Decide.Action.FollowPath(suffix) => Vector.find(item -> item#suffix == suffix, continuations)
                        |> Option.toOk(Error.UnexpectedAction(rankObservation#choice))
                    case _ => Err(Error.UnexpectedAction(rankObservation#choice))
                };
                next <- if (depth == 0)
                    classicNavigate(policyProtocol, prepared, prior, computed,
                        Vector.append(path, proposed#suffix), proposed#state,
                        Vector.append(decisions, Vector#{rankObservation}))
                else {
                    let comparison = comparisonAlternatives(prepared#world, prior, current, proposed);
                    forM (
                        stopRequest <- Decide.requestWith(
                            {protocol = policyProtocol + "-stop", question = stopQuestion()},
                            Radii.Evaluate.stateId(current),
                            visibleState(prepared, prior, path, current),
                            comparison
                        ) |> Result.mapErr(Error.Decide);
                        stopObservation <- Decide.policy(stopRequest) |> Result.mapErr(Error.Decide);
                        nextDecisions = Vector.append(decisions, Vector#{rankObservation, stopObservation});
                        result <- match stopObservation#choice {
                            case Decide.Action.Stop => Ok(finish(prior, computed, path, current, nextDecisions))
                            case Decide.Action.FollowPath(suffix) => match Vector.find(item -> item#suffix == suffix, continuations) {
                                case None => Err(Error.UnexpectedAction(stopObservation#choice))
                                case Some(item) => classicNavigate(policyProtocol, prepared, prior, computed,
                                    Vector.append(path, suffix), item#state, nextDecisions)
                            }
                            case Decide.Action.Follow(_) => Err(Error.UnexpectedAction(stopObservation#choice))
                        }
                    ) yield result
                }
                ) yield next
            }
        ) yield outcome
    }

    def planRoot(
        policyProtocol: String,
        rolloutDepth: Int32,
        prepared: Localization.Prepared,
        prior: Localization.Tree.Prior,
        computed: Localization.Tree.Computed,
        current: Radii.Evaluate.State,
        roots: Vector[Continuation]
    ): Result[Error, PlanningResult] \ Decide.Choice =
        proposePlans(policyProtocol, rolloutDepth, prepared, prior, computed, current, roots, 0,
            Vector.empty(), Vector.empty())

    def proposePlans(
        policyProtocol: String,
        rolloutDepth: Int32,
        prepared: Localization.Prepared,
        prior: Localization.Tree.Prior,
        computed: Localization.Tree.Computed,
        current: Radii.Evaluate.State,
        roots: Vector[Continuation],
        index: Int32,
        plans: Vector[Continuation],
        observations: Vector[Decide.Observation]
    ): Result[Error, PlanningResult] \ Decide.Choice =
        if (index >= Vector.length(roots)) {
            let unique = uniquePlans(plans, 0, Set.empty(), Vector.empty());
            forM (
                request0 <- Decide.requestWith(
                    {protocol = policyProtocol + "-root-plan", question = planQuestion()},
                    Radii.Evaluate.stateId(current),
                    visibleState(prepared, prior, Vector.empty(), current),
                    continuationAlternatives(prepared#world, prior, unique)
                ) |> Result.mapErr(Error.Decide);
                observation <- Decide.policy(request0) |> Result.mapErr(Error.Decide);
                winner <- match observation#choice {
                    case Decide.Action.FollowPath(path) => Vector.find(item -> item#suffix == path, unique)
                        |> Option.toOk(Error.UnexpectedAction(observation#choice))
                    case _ => Err(Error.UnexpectedAction(observation#choice))
                }
            ) yield {winner = winner,
                observations = Vector.append(observations, Vector#{observation})}
        } else {
            let root0 = Vector.get(index, roots);
            forM (
                deepened <- deepenPlan(policyProtocol, rolloutDepth, rolloutDepth,
                    prepared, prior, computed, root0, Vector.empty());
                result <- proposePlans(policyProtocol, rolloutDepth,
                    prepared, prior, computed, current, roots, index + 1,
                    Vector.append(plans, Vector#{deepened#winner}),
                    Vector.append(observations, deepened#observations))
            ) yield result
        }

    def deepenPlan(
        policyProtocol: String,
        totalRollouts: Int32,
        remainingRollouts: Int32,
        prepared: Localization.Prepared,
        prior: Localization.Tree.Prior,
        computed: Localization.Tree.Computed,
        plan: Continuation,
        observations: Vector[Decide.Observation]
    ): Result[Error, PlanningResult] \ Decide.Choice =
        if (remainingRollouts <= 0)
            Ok({winner = plan, observations = observations})
        else forM (
            children0 <- continuations(plan#route#steps, computed);
            children <- pruneExactAncestorRevisits(plan#route#steps, children0, computed);
            result <- if (Vector.isEmpty(children))
                Ok({winner = plan, observations = observations})
            else forM (
                request0 <- Decide.requestWith(
                    {protocol = rolloutProtocol(policyProtocol, totalRollouts, remainingRollouts), question = question()},
                    Radii.Evaluate.stateId(plan#state),
                    visibleState(prepared, prior, plan#route#steps, plan#state),
                    continuationAlternatives(prepared#world, prior, children)
                ) |> Result.mapErr(Error.Decide);
                observation <- Decide.policy(request0) |> Result.mapErr(Error.Decide);
                child <- match observation#choice {
                    case Decide.Action.FollowPath(suffix) => Vector.find(item -> item#suffix == suffix, children)
                        |> Option.toOk(Error.UnexpectedAction(observation#choice))
                    case _ => Err(Error.UnexpectedAction(observation#choice))
                };
                next = {suffix = child#route#steps, route = child#route, state = child#state};
                deepened <- deepenPlan(policyProtocol, totalRollouts, remainingRollouts - 1,
                    prepared, prior, computed, next,
                    Vector.append(observations, Vector#{observation}))
            ) yield deepened
        ) yield result

    def rolloutProtocol(policyProtocol: String, total: Int32, remaining: Int32): String =
        if (total == 1) policyProtocol + "-rollout"
        else policyProtocol + "-rollout-${total - remaining + 1}"

    def pruneExactAncestorRevisits(
        prefix: Vector[Radii.Atom],
        candidates: Vector[Continuation],
        computed: Localization.Tree.Computed
    ): Result[Error, Vector[Continuation]] =
        Vector.range(0, Vector.length(prefix) + 1)
        |> Vector.traverse(depth -> if (depth == 0) Ok(computed#input)
            else Localization.Tree.stateAt(Vector.slice(start = 0, end = depth, prefix), computed)
                |> Result.mapErr(Error.Tree))
        |> Result.map(ancestors -> Vector.filter(candidate ->
            not Vector.exists(state -> state == candidate#state, ancestors), candidates))

    def uniquePlans(
        plans: Vector[Continuation],
        index: Int32,
        seen: Set[Vector[Radii.Atom]],
        result: Vector[Continuation]
    ): Vector[Continuation] =
        if (index >= Vector.length(plans)) result
        else {
            let plan = Vector.get(index, plans);
            if (Set.memberOf(plan#suffix, seen))
                uniquePlans(plans, index + 1, seen, result)
            else uniquePlans(plans, index + 1, Set.insert(plan#suffix, seen),
                Vector.append(result, Vector#{plan}))
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
        continuations0: Vector[Continuation]
    ): Vector[Decide.Alternative] = {
        Vector.map(item -> {
            action = Decide.Action.FollowPath(item#suffix),
            expression = Some(Radii.Evaluate.exprId(item#route#expression)),
            state = Radii.Evaluate.stateId(item#state),
            criterion = "Take continuation ${pathText(item#suffix)} (${Vector.length(item#suffix)} actions). Terminal " +
                Localization.Tree.preview(world, prior, item#state)
        }, continuations0)
    }

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
            criterion = "Take proposed continuation ${pathText(proposed#suffix)}. Terminal " +
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

    def writeResults(results: Vector[CaseResult]): Result[Error, Unit] \ IO = {
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
        let _ = ScientificData.writeObject("${root()}/outcomes.parquet", payload);
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

    def pathText(path: Vector[Radii.Atom]): String =
        if (Vector.isEmpty(path)) "root"
        else Vector.map(atomName, path) |> Vector.toList |> List.intersperse(">>") |> List.fold

    def atomName(atom: Radii.Atom): String = Decide.actionKey(Decide.Action.Follow(atom))

    def require(result: Result[Error, Unit]): Unit \ Assert = match result {
        case Ok(()) => ()
        case Err(error) => Assert.fail(ToString.toString(error))
    }
}
