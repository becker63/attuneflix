/// The permanent localization program: broad typed prior, exhaustive Atlas,
/// then one bounded learned choice. Gold and provider transport are absent.
pub mod Localization.Sandwich {
    pub enum CandidateId(Int32) with Eq, Order, Hash, ToString

    pub enum Selection with Eq, ToString {
        case Prior
        case Atlas(CandidateId)
    }

    pub type alias Candidate = {
        id      = CandidateId,
        program = Atlas.Program,
        state   = Atlas.State,
        ranking = Vector[Localization.Ranked]
    }

    pub type alias Search = {
        prior               = Localization.Prior,
        candidates           = Vector[Candidate],
        logicalRoutes        = Int32,
        uniqueSemanticStates = Int32,
        physicalTransitions  = Int32,
        transitionReuses     = Int32
    }

    pub type alias Prediction = {
        instanceId = String,
        selection  = Selection,
        ranking    = Vector[Localization.Ranked]
    }

    /// The learned tail receives only the issue and Atlas's unique outcomes.
    /// Acquisition/replay handlers may implement this effect; Atlas cannot.
    pub eff Judge {
        def decide(issue: Localization.Issue, search: Search): Result[String, Selection]
    }

    pub def search(
        prepared: Localization.Prepared,
        prior: Localization.Prior,
        depth: Int32
    ): Result[String, Search] = forM (
        _ <- requireIdentity(prepared, prior);
        input <- seed(prepared#world, prior#ranking);
        family = Atlas.programsFrom(Radii.Domain.Symbol, depth);
        evaluation <- Atlas.evaluate(prepared#world, input, family);
        pairs = Vector.zip(family, evaluation#outputs);
        symbolPairs = Vector.filter(match (_, state) -> match state {
            case Atlas.State.Symbols(_) => true
            case Atlas.State.Files(_) => false
        }, pairs);
        unique = uniqueStates(symbolPairs, Set.empty(), Vector.empty());
        candidates = Vector.mapWithIndex((index, pair) -> {
            id = CandidateId.CandidateId(index),
            program = fst(pair),
            state = snd(pair),
            ranking = promote(prior#ranking, snd(pair))
        }, unique)
    ) yield {
        prior = prior,
        candidates = candidates,
        logicalRoutes = Vector.length(symbolPairs),
        uniqueSemanticStates = Vector.length(candidates),
        physicalTransitions = evaluation#physicalTransitions,
        transitionReuses = evaluation#transitionReuses
    }

    pub def localize(prepared: Localization.Prepared, search0: Search): Result[String, Prediction] \ Judge =
        Judge.decide(prepared#issue, search0) |> Result.flatMap(selection ->
            rankingFor(selection, search0) |> Result.map(ranking -> {
                instanceId = prepared#instanceId,
                selection = selection,
                ranking = ranking
            }))

    pub def runWith(
        judge: (Localization.Issue, Search) -> Result[String, Selection],
        computation: Unit -> a \ ef
    ): a \ (ef - Judge) = run { computation() } with handler Judge {
        def decide(issue, search0, resume) = resume(judge(issue, search0))
    }

    pub def rankingFor(selection: Selection, search0: Search): Result[String, Vector[Localization.Ranked]] =
        match selection {
            case Selection.Prior => Ok(search0#prior#ranking)
            case Selection.Atlas(id) => Vector.find(candidate -> candidate#id == id, search0#candidates)
                |> Option.map(candidate -> candidate#ranking)
                |> Option.toOk("judge selected an unknown Atlas candidate")
        }

    /// Stable partition: Atlas moves selected symbols forward without
    /// inventing scores or disturbing order within either partition.
    pub def promote(ranking: Vector[Localization.Ranked], state: Atlas.State): Vector[Localization.Ranked] =
        match state {
            case Atlas.State.Symbols(symbols) => {
                let selected = Vector.filter(item -> Set.memberOf(symbol(item#ordinal), symbols), ranking);
                let remaining = Vector.filter(item -> not Set.memberOf(symbol(item#ordinal), symbols), ranking);
                Vector.append(selected, remaining)
            }
            case Atlas.State.Files(_) => ranking
        }

    def requireIdentity(prepared: Localization.Prepared, prior: Localization.Prior): Result[String, Unit] =
        if (prepared#instanceId != prior#instanceId) Err("prior instance mismatch")
        else if (prepared#repository != prior#repository) Err("prior repository mismatch")
        else if (prepared#baseCommit != prior#baseCommit) Err("prior revision mismatch")
        else Ok(())

    def seed(world: Repository.World, ranking: Vector[Localization.Ranked]): Result[String, Atlas.State] = {
        let centers = Vector.slice(start = 0, end = Int32.min(8, Vector.length(ranking)), ranking);
        match Vector.find(item -> item#ordinal < 0 or item#ordinal >= Vector.length(world#symbols), centers) {
            case Some(_) => Err("semantic prior contains an invalid symbol ordinal")
            case None => Ok(Atlas.State.Symbols(Vector.map(item -> symbol(item#ordinal), centers) |> Vector.toSet))
        }
    }

    def uniqueStates(
        pairs: Vector[(Atlas.Program, Atlas.State)],
        seen: Set[Atlas.State],
        result: Vector[(Atlas.Program, Atlas.State)]
    ): Vector[(Atlas.Program, Atlas.State)] = match Vector.head(pairs) {
        case None => result
        case Some(pair) => {
            let rest = Vector.slice(start = 1, end = Vector.length(pairs), pairs);
            if (Set.memberOf(snd(pair), seen)) uniqueStates(rest, seen, result)
            else uniqueStates(rest, Set.insert(snd(pair), seen), Vector.append(result, Vector#{pair}))
        }
    }

    def symbol(ordinal: Int32): Repository.Structure.SymbolId =
        Repository.Structure.SymbolId.SymbolId(ordinal)
}
