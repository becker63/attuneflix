pub mod Localization.Tree {
    use Util.Json
    use Util.Json.Json.{JArray, JObject, JString}
    use Util.Json.FromJson

    pub def centerCount(): Int32 = 8
    pub def maxDepth(): Int32 = 7

    pub type alias Prior = {
        instanceId = String,
        repository = String,
        baseCommit = String,
        ranking = Vector[Localization.Ranked]
    }

    pub type alias Route = {
        steps = Vector[Radii.Atom],
        expression = Radii.Expr
    }

    pub type alias Tree = {
        routes = Vector[Route],
        program = Radii.Compiled.Program
    }

    pub type alias Computed = {
        tree = Tree,
        input = Radii.Evaluate.State,
        evaluation = Radii.Compiled.Evaluation
    }

    pub type alias Outcome = {
        path = Vector[Radii.Atom],
        finalState = Radii.Evaluate.State,
        ranking = Vector[Localization.Ranked],
        decisions = Vector[Decide.Observation],
        metrics = Radii.Compiled.Metrics
    }

    pub enum Error with Eq, ToString {
        case Wire(String),
        case MissingPrior(String),
        case PriorRepositoryMismatch(String, String),
        case PriorCommitMismatch(String, String),
        case InvalidSymbolOrdinal(Int32),
        case Compile(String),
        case MissingRoute(String),
        case TerminalFile(Int32),
        case UnexpectedAction(Decide.Action),
        case Decide(Decide.Error)
    }

    /// Compile the complete frozen six-atom composition grammar once. This
    /// program is repository-independent and reusable across all 15 cases.
    pub def compile(): Tree = {
        let routes = enumerate(maxDepth());
        {
            routes = routes,
            program = Radii.Compiled.compile(
                Vector.map(route -> route#expression, routes) |> Vector.toList)
        }
    }

    pub def routeCount(tree: Tree): Int32 = Vector.length(tree#routes)

    pub def symbolRouteCount(tree: Tree): Int32 =
        Vector.filter(route -> snd(Radii.endpoints(route#expression)) == Radii.Domain.Symbol,
            tree#routes)
        |> Vector.length

    pub def decodePrior(instanceId: String, payload: String): Result[Error, Prior] =
        match Json.parse(payload) {
            case Err(error) => Err(Error.Wire(ToString.toString(error)))
            case Ok(JObject(fields)) => forM (
                cases <- arrayField("cases", fields);
                row <- Vector.find(value -> caseId(value) == Some(instanceId), cases)
                    |> Option.toOk(Error.MissingPrior(instanceId));
                prior <- decodePriorRow(row)
            ) yield prior
            case Ok(_) => Err(Error.Wire("prior artifact must be an object"))
        }

    pub def compute(
        prepared: Localization.Prepared,
        prior: Prior,
        tree: Tree
    ): Result[Error, Computed] = forM (
        _ <- if (prepared#repository == prior#repository) Ok(())
             else Err(Error.PriorRepositoryMismatch(prepared#repository, prior#repository));
        _ <- if (prepared#baseCommit == prior#baseCommit) Ok(())
             else Err(Error.PriorCommitMismatch(prepared#baseCommit, prior#baseCommit));
        centers <- centerState(prepared#world, prior#ranking);
        evaluation <- Radii.Compiled.evaluate(semanticWorld(prepared), centers, tree#program)
            |> Result.mapErr(Error.Compile)
    ) yield {tree = tree, input = centers, evaluation = evaluation}

    pub def localize(
        prepared: Localization.Prepared,
        prior: Prior,
        computed: Computed
    ): Result[Error, Outcome] \ Decide.Choice =
        navigate(prepared, prior, computed, Vector.empty(), computed#input, Vector.empty())

    /// Structural promotion is a stable partition of the untouched prior.
    pub def promote(prior: Vector[Localization.Ranked], state: Radii.Evaluate.State): Vector[Localization.Ranked] =
        match state {
            case Radii.Evaluate.State.Symbols(symbols) => {
                let selected = Vector.filter(item -> Set.memberOf(symbolId(item#ordinal), symbols), prior);
                let remaining = Vector.filter(item -> not Set.memberOf(symbolId(item#ordinal), symbols), prior);
                Vector.append(selected, remaining)
            }
            case _ => prior
        }

    def navigate(
        prepared: Localization.Prepared,
        prior: Prior,
        computed: Computed,
        path: Vector[Radii.Atom],
        current: Radii.Evaluate.State,
        decisions: Vector[Decide.Observation]
    ): Result[Error, Outcome] \ Decide.Choice = {
        let depth = Vector.length(path);
        if (depth == maxDepth()) match current {
            case Radii.Evaluate.State.Symbols(_) => Ok(finish(prior, computed, path, current, decisions))
            case Radii.Evaluate.State.Files(_) => Err(Error.TerminalFile(depth))
            case Radii.Evaluate.State.Locations(_) => Err(Error.TerminalFile(depth))
        }
        else forM (
            children <- childAlternatives(computed, path, current);
            alternatives <- decisionAlternatives(prepared#world, prior, current, children);
            request0 <- Decide.request(
                Radii.Evaluate.stateId(current),
                visibleState(prepared, prior, path, current),
                alternatives
            ) |> Result.mapErr(Error.Decide);
            observation <- Decide.policy(request0) |> Result.mapErr(Error.Decide);
            result <- match observation#choice {
                case Decide.Action.Stop => match current {
                    case Radii.Evaluate.State.Symbols(_) =>
                        Ok(finish(prior, computed, path, current, Vector.append(decisions, Vector#{observation})))
                    case _ => Err(Error.UnexpectedAction(Decide.Action.Stop))
                }
                case Decide.Action.Follow(atom) => match Vector.find(child -> child#atom == atom, children) {
                    case None => Err(Error.UnexpectedAction(observation#choice))
                    case Some(child) => navigate(
                        prepared,
                        prior,
                        computed,
                        Vector.append(path, Vector#{atom}),
                        child#state,
                        Vector.append(decisions, Vector#{observation})
                    )
                }
                case Decide.Action.FollowPath(_) => Err(Error.UnexpectedAction(observation#choice))
            }
        ) yield result
    }

    type alias Child = {
        atom = Radii.Atom,
        route = Route,
        state = Radii.Evaluate.State
    }

    def childAlternatives(
        computed: Computed,
        path: Vector[Radii.Atom],
        current: Radii.Evaluate.State
    ): Result[Error, Vector[Child]] = {
        let remaining = maxDepth() - Vector.length(path);
        let atoms0 = compatibleAtoms(current);
        // A depth-seven result must be a Symbol state. No hidden Defines step.
        let atoms = if (remaining == 1) Vector.filter(atom -> Radii.target(atom) == Radii.Domain.Symbol, atoms0) else atoms0;
        Vector.traverse(atom -> {
            let childPath = Vector.append(path, Vector#{atom});
            routeAt(childPath, computed#tree)
                |> Result.map(route -> {
                    let index = routeIndex(childPath, computed#tree);
                    let id = Vector.get(index, computed#evaluation#outputs);
                    {atom = atom, route = route, state = Radii.Compiled.state(computed#evaluation, id)}
                })
        }, atoms)
    }

    def decisionAlternatives(
        world: Repository.World,
        prior: Prior,
        current: Radii.Evaluate.State,
        children: Vector[Child]
    ): Result[Error, Vector[Decide.Alternative]] = {
        let stop = match current {
            case Radii.Evaluate.State.Symbols(_) => Vector#{
                {
                    action = Decide.Action.Stop,
                    expression = None,
                    state = Radii.Evaluate.stateId(current),
                    criterion = "Stop and retain the current symbol frontier. " + preview(world, prior, current)
                }
            }
            case _ => Vector.empty()
        };
        let follow = Vector.map(child -> {
            action = Decide.Action.Follow(child#atom),
            expression = Some(Radii.Evaluate.exprId(child#route#expression)),
            state = Radii.Evaluate.stateId(child#state),
            criterion = "Take ${Decide.actionKey(Decide.Action.Follow(child#atom))}. " + preview(world, prior, child#state)
        }, children);
        Ok(Vector.append(stop, follow))
    }

    def finish(
        prior: Prior,
        computed: Computed,
        path: Vector[Radii.Atom],
        state: Radii.Evaluate.State,
        decisions: Vector[Decide.Observation]
    ): Outcome = {
        path = path,
        finalState = state,
        ranking = promote(prior#ranking, state),
        decisions = decisions,
        metrics = computed#evaluation#metrics
    }

    def visibleState(
        prepared: Localization.Prepared,
        prior: Prior,
        path: Vector[Radii.Atom],
        current: Radii.Evaluate.State
    ): String = {
        let Localization.IssueText.IssueText(issue) = prepared#issue#text;
        "ATTUNE_LOCALIZATION_STATE_V1\n" +
        "repository: ${prepared#repository}\n" +
        "base_commit: ${prepared#baseCommit}\n" +
        "issue:\n${issue}\n" +
        "depth: ${Vector.length(path)}/${maxDepth()}\n" +
        "path: ${pathText(path)}\n" +
        "current: ${preview(prepared#world, prior, current)}"
    }

    pub def preview(world: Repository.World, prior: Prior, state: Radii.Evaluate.State): String = match state {
        case Radii.Evaluate.State.Symbols(symbols) => {
            let members = take(centerCount(), Vector.filter(item ->
                Set.memberOf(symbolId(item#ordinal), symbols), prior#ranking));
            let lines = Vector.map(item -> {
                let symbol = Vector.get(item#ordinal, world#symbols);
                "${symbol#path} :: ${symbol#name}"
            }, members);
            "domain=symbol cardinality=${Set.size(symbols)} top=[${join(lines)}]"
        }
        case Radii.Evaluate.State.Files(files) => {
            let paths = topFiles(world, prior, files);
            "domain=file cardinality=${Set.size(files)} top=[${join(paths)}]"
        }
        case Radii.Evaluate.State.Locations(locations) =>
            "domain=location cardinality=${Set.size(locations)} top=[]"
    }

    def topFiles(world: Repository.World, prior: Prior, files: Set[Repository.Structure.FileId]): Vector[String] = {
        let ranked = Vector.filterMap(item -> {
            let symbol = symbolId(item#ordinal);
            fileForSymbol(symbol, world#defines) |> Option.flatMap(file ->
                if (Set.memberOf(file, files)) Some(file) else None)
        }, prior#ranking);
        uniqueFiles(ranked, Set.empty(), Vector.empty())
        |> take(centerCount())
        |> Vector.map(file -> let Repository.Structure.FileId.FileId(index) = file; Vector.get(index, world#files))
    }

    def uniqueFiles(
        files: Vector[Repository.Structure.FileId],
        seen: Set[Repository.Structure.FileId],
        result: Vector[Repository.Structure.FileId]
    ): Vector[Repository.Structure.FileId] = match Vector.head(files) {
        case None => result
        case Some(file) => {
            let rest = Vector.slice(start = 1, end = Vector.length(files), files);
            if (Set.memberOf(file, seen)) uniqueFiles(rest, seen, result)
            else uniqueFiles(rest, Set.insert(file, seen), Vector.append(result, Vector#{file}))
        }
    }

    def fileForSymbol(symbol: Repository.Structure.SymbolId, defines: Repository.Structure.Defines): Option[Repository.Structure.FileId] =
        Set.find(match (_, target) -> target == symbol, defines) |> Option.map(fst)

    def centerState(world: Repository.World, ranking: Vector[Localization.Ranked]): Result[Error, Radii.Evaluate.State] = {
        let centers = take(centerCount(), ranking);
        match Vector.find(item -> item#ordinal < 0 or item#ordinal >= Vector.length(world#symbols), centers) {
            case Some(item) => Err(Error.InvalidSymbolOrdinal(item#ordinal))
            case None => Ok(Radii.Evaluate.State.Symbols(
                Vector.map(item -> symbolId(item#ordinal), centers) |> Vector.toSet))
        }
    }

    def semanticWorld(prepared: Localization.Prepared): Radii.Evaluate.World =
        Radii.Evaluate.fromBasis(
            Radii.Evaluate.WorldId.WorldId("${prepared#repository}@${prepared#baseCommit}"),
            prepared#world#defines,
            prepared#world#imports,
            prepared#world#calls,
            prepared#world#parents
        )

    def enumerate(depth: Int32): Vector[Route] =
        enumerateLevels(1, depth, Vector#{}, Vector.empty())

    def enumerateLevels(
        current: Int32,
        depth: Int32,
        previous: Vector[Route],
        all: Vector[Route]
    ): Vector[Route] =
        if (current > depth) all
        else {
            let exact = if (current == 1)
                Vector.map(atom -> {steps = Vector#{atom}, expression = Radii.Expr.Atom(atom)},
                    compatibleFor(Radii.Domain.Symbol))
            else Vector.flatMap(route -> Vector.map(atom -> {
                    steps = Vector.append(route#steps, Vector#{atom}),
                    expression = Radii.Expr.Compose(route#expression, Radii.Expr.Atom(atom))
                }, compatibleFor(snd(Radii.endpoints(route#expression)))), previous);
            enumerateLevels(current + 1, depth, exact, Vector.append(all, exact))
        }

    def compatibleAtoms(state: Radii.Evaluate.State): Vector[Radii.Atom] = match state {
        case Radii.Evaluate.State.Symbols(_) => compatibleFor(Radii.Domain.Symbol)
        case Radii.Evaluate.State.Files(_) => compatibleFor(Radii.Domain.File)
        case Radii.Evaluate.State.Locations(_) => Vector.empty()
    }

    def compatibleFor(domain: Radii.Domain): Vector[Radii.Atom] = match domain {
        case Radii.Domain.Symbol => Vector#{Radii.Atom.DefinedIn, Radii.Atom.Calls, Radii.Atom.Callers}
        case Radii.Domain.File => Vector#{Radii.Atom.Defines, Radii.Atom.Imports, Radii.Atom.ImportedBy}
        case Radii.Domain.Location => Vector.empty()
    }

    pub def routeAt(path: Vector[Radii.Atom], tree: Tree): Result[Error, Route] =
        Vector.find(route -> route#steps == path, tree#routes)
        |> Option.toOk(Error.MissingRoute(pathText(path)))

    /// Read one already-computed route result. This performs no repository
    /// work and is the narrow query seam used by policy experiments.
    pub def stateAt(path: Vector[Radii.Atom], computed: Computed): Result[Error, Radii.Evaluate.State] =
        routeAt(path, computed#tree)
        |> Result.map(_ -> {
            let index = routeIndex(path, computed#tree);
            let id = Vector.get(index, computed#evaluation#outputs);
            Radii.Compiled.state(computed#evaluation, id)
        })

    def routeIndex(path: Vector[Radii.Atom], tree: Tree): Int32 =
        routeIndexFrom(path, tree#routes, 0)

    def routeIndexFrom(path: Vector[Radii.Atom], routes: Vector[Route], index: Int32): Int32 =
        if (Vector.get(index, routes)#steps == path) index
        else routeIndexFrom(path, routes, index + 1)

    def pathText(path: Vector[Radii.Atom]): String =
        if (Vector.isEmpty(path)) "root"
        else Vector.map(atom -> Decide.actionKey(Decide.Action.Follow(atom)), path)
            |> Vector.toList |> List.intersperse(" >> ") |> List.fold

    def take(count: Int32, values: Vector[a]): Vector[a] =
        Vector.slice(start = 0, end = Int32.min(count, Vector.length(values)), values)

    def join(values: Vector[String]): String =
        Vector.toList(values) |> List.intersperse("; ") |> List.fold

    def symbolId(ordinal: Int32): Repository.Structure.SymbolId = Repository.Structure.SymbolId.SymbolId(ordinal)

    def caseId(value: Json): Option[String] = match value {
        case JObject(fields) => match Map.get("instance_id", fields) {
            case Some(JString(value0)) => Some(value0)
            case _ => None
        }
        case _ => None
    }

    def decodePriorRow(value: Json): Result[Error, Prior] = match value {
        case JObject(fields) => forM (
            instanceId <- stringField("instance_id", fields);
            repository <- stringField("repository", fields);
            baseCommit <- stringField("base_commit", fields);
            values <- arrayField("ranking", fields);
            ranking <- Vector.traverse(decodeRanked, values)
        ) yield {
            instanceId = instanceId,
            repository = repository,
            baseCommit = baseCommit,
            ranking = ranking
        }
        case _ => Err(Error.Wire("prior case must be an object"))
    }

    def decodeRanked(value: Json): Result[Error, Localization.Ranked] = match value {
        case JObject(fields) => forM (
            identity <- stringField("semantic_id", fields);
            score <- floatField("score", fields);
            ordinal <- intField("ordinal", fields)
        ) yield {identity = identity, score = score, ordinal = ordinal}
        case _ => Err(Error.Wire("ranking row must be an object"))
    }

    def field(name: String, fields: Map[String, Json]): Result[Error, Json] =
        Map.get(name, fields) |> Option.toOk(Error.Wire("missing JSON field: ${name}"))

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

    def intField(name: String, fields: Map[String, Json]): Result[Error, Int32] =
        field(name, fields) |> Result.flatMap(value -> FromJson.fromJson(value)
            |> Result.mapErr(error -> Error.Wire("${name}: ${ToString.toString(error)}")))

    def floatField(name: String, fields: Map[String, Json]): Result[Error, Float64] =
        field(name, fields) |> Result.flatMap(value -> FromJson.fromJson(value)
            |> Result.mapErr(error -> Error.Wire("${name}: ${ToString.toString(error)}")))
}
