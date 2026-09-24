/// The frozen issue-conditioned selector used by localization iteration 013.
/// Historical search reports live under experiments/; this module contains
/// only the policy still needed for exact retained-evidence replay.
pub mod Localization.Policy {
    pub enum Error with ToString {
        case Tree(Localization.Tree.Error),
        case Decide(Decide.Error),
        case UnexpectedAction(Decide.Action)
    }

    type alias Continuation = {
        suffix = Vector[Radii.Atom],
        route = Localization.Tree.Route,
        state = Radii.Evaluate.State
    }

    type alias PlanningResult = {
        winner = Continuation,
        observations = Vector[Decide.Observation]
    }

    def bestProtocol(): String = "attune-jev-policy-hillclimb-012-pruned-planner-portfolio-v1"

    def deepProtocol(): String = "attune-jev-policy-hillclimb-013-deep-planner-portfolio-v1"

    def classicProtocol(): String = "attune-jev-policy-hillclimb-003-force-first-macro-v1"

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

    /// Keyless post-freeze replay. A per-case typed bundle is loaded once by
    /// the Bazel action and shared by all three frozen policy phases. A miss
    /// remains an explicit failure; this path has no native/network handler.
    pub def frozen013Replay(
        prepared: Localization.Prepared,
        prior: Localization.Tree.Prior,
        computed: Localization.Tree.Computed,
        wires: Map[Radii.Evaluate.DecisionId, Decide.Wire]
    ): Result[Error, Localization.Tree.Outcome] =
        Decide.runWithWireReplay(wires, () ->
            classicNavigate(classicProtocol(), prepared, prior, computed,
                Vector.empty(), computed#input, Vector.empty()))
        |> Result.flatMap(classic -> Decide.runWithWireReplay(wires, () ->
            portfolio(bestProtocol(), 1, prepared, prior, computed, classic)))
        |> Result.flatMap(best -> Decide.runWithWireReplay(wires, () -> forM (
            deep <- planningExpert(deepProtocol(), 2, prepared, prior, computed);
            selected <- selectExpert(deepProtocol(), prepared, prior, computed, best, deep)
        ) yield selected))

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

    def pathText(path: Vector[Radii.Atom]): String =
        if (Vector.isEmpty(path)) "root"
        else Vector.map(atomName, path) |> Vector.toList |> List.intersperse(">>") |> List.fold

    def atomName(atom: Radii.Atom): String = Decide.actionKey(Decide.Action.Follow(atom))

}
