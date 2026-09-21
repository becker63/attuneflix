mod JevOracleTest {
    use Fs.FileSystem
    use Sys.Env
    use Util.Json
    use Util.Json.Json.{JArray, JNull, JObject, JString}
    use Util.Json.FromJson
    use Util.Json.ToJson

    pub enum Error with ToString {
        case File(String),
        case Nix(Repository.Nix.Error),
        case Prepare(Localization.Error),
        case Tree(Localization.Tree.Error),
        case Wire(String),
        case MissingGold(String),
        case MissingOutcome(String),
        case MissingDocument(String),
        case OfficialParity(String),
        case Diagnosis(String)
    }

    type alias SourceRegion = {
        path = String,
        start = Int32,
        end = Int32
    }

    type alias Gold = {
        instanceId = String,
        coreFiles = Set[String],
        coreRegions = Vector[SourceRegion],
        optionalFiles = Set[String],
        optionalRegions = Vector[SourceRegion],
        mainFiles = Set[String]
    }

    type alias Score = {
        precision = Float64,
        recall = Float64,
        f1 = Float64,
        hitFile = Float64,
        noiseFile = Float64,
        hitRegion = Float64,
        noiseRegion = Float64,
        weightedCoreCoverage = Float64,
        contextEfficiency = Float64,
        ndcg100 = Float64,
        ndcg300 = Float64,
        ndcg500 = Float64,
        recall100 = Float64,
        recall300 = Float64,
        recall500 = Float64,
        firstUsefulHit = Float64
    }

    type alias DecisionFixture = {
        choice = String,
        probabilities = Map[String, Float64],
        confidence = Float64
    }

    type alias OutcomeFixture = {
        path = Vector[String],
        ranking = Vector[String],
        decisions = Vector[DecisionFixture]
    }

    type alias Best = {
        path = String,
        score = Score,
        regions = Vector[SourceRegion]
    }

    type alias CandidateBest = {
        path = String,
        f1 = Float64,
        regions = Vector[SourceRegion]
    }

    type alias Row = {
        instanceId = String,
        repository = String,
        prior = Score,
        jev = Score,
        oracle = Score,
        oraclePath = String,
        priorRegions = Vector[SourceRegion],
        jevRegions = Vector[SourceRegion],
        oracleRegions = Vector[SourceRegion]
    }

    type alias FrozenReference = {
        prior = Score,
        oracle = Score,
        oraclePath = String,
        priorRegions = Vector[SourceRegion],
        oracleRegions = Vector[SourceRegion]
    }

    type alias BudgetCoverage = {
        covered = Set[(String, Int32)],
        consumed = Int32
    }

    type alias Gain = {
        gain = Float64,
        lines = Int32,
        ordinal = Int32
    }

    type alias RouteDatum = {
        path = Vector[Radii.Atom],
        ordinal = Int32,
        state = Radii.Evaluate.State,
        preview = String,
        terminal = Bool,
        score = Score
    }

    type alias DiagnosticScoreContext = {
        counts = Map[String, Int32],
        coreLines = Set[(String, Int32)],
        usefulLines = Set[(String, Int32)]
    }

    type alias ActionDatum = {
        action = String,
        path = Vector[Radii.Atom],
        immediate = Score,
        best = Score,
        bestPath = String,
        cardinality = Int32,
        cardinalityDelta = Int32,
        overlap = Option[Float64],
        newMembers = Int32,
        removedMembers = Int32,
        minPriorRank = Option[Int32],
        meanPriorRank = Option[Float64],
        revisits = Bool,
        preview = String,
        probability = Option[Float64]
    }

    type alias DecisionDatum = {
        depth = Int32,
        path = String,
        choice = String,
        confidence = Float64,
        current = Score,
        value = Score,
        chosenValue = Score,
        regret = Float64,
        alternatives = Vector[ActionDatum],
        previewAliases = Int32,
        previewAliasMaxF1Spread = Float64
    }

    type alias Distribution = {
        median = Float64,
        p75 = Float64,
        p90 = Float64,
        p95 = Float64,
        p99 = Float64,
        betterThanPrior = Int32,
        atLeastPrior = Int32,
        substantiallyBetter = Int32,
        within1 = Int32,
        within5 = Int32,
        within10 = Int32,
        terminalRoutes = Int32,
        topDecileFirstActions = Map[String, Int32]
    }

    type alias PreviewStats = {
        nodes = Int32,
        uniqueStates = Int32,
        uniquePreviews = Int32,
        collidingPreviews = Int32,
        maxMultiplicity = Int32,
        valueDivergentPreviews = Int32,
        maxF1Spread = Float64
    }

    type alias MotifDatum = {
        depth = Int32,
        beforeCardinality = Int32,
        afterCardinality = Int32,
        jaccard = Float64,
        newSymbols = Int32,
        removedSymbols = Int32,
        previewChanged = Bool,
        valueBefore = Float64,
        valueAfter = Float64
    }

    type alias CaseDiagnosis = {
        instanceId = String,
        repository = String,
        prior = Score,
        jev = Score,
        oracle = Score,
        jevPath = String,
        oraclePath = String,
        firstDivergenceDepth = Int32,
        firstValueLossDepth = Option[Int32],
        largestDecisionRegret = Float64,
        distribution = Distribution,
        preview = PreviewStats,
        decisions = Vector[DecisionDatum],
        motifs = Vector[MotifDatum],
        greedy1 = Score,
        greedy2 = Score,
        greedy3 = Score,
        greedyFull = Score
    }

    /// Explicit heavyweight evaluator mode. Gold is acquired only here, after
    /// the solver outcomes have already been frozen.
    @Test
    def frozenStructuralOracle(): Unit \ {Assert, Env, FileSystem, IO} =
        match Env.getVar("ATTUNE_JEV_EVALUATE") {
            case None => ()
            case Some("oracle") => match execute() {
                case Ok(()) => ()
                case Err(error) => Assert.fail(ToString.toString(error))
            }
            case Some("candidate") => match executeCandidate() {
                case Ok(()) => ()
                case Err(error) => Assert.fail(ToString.toString(error))
            }
            case Some(value) => Assert.fail("unknown ATTUNE_JEV_EVALUATE: ${value}")
        }

    /// Post-hoc only: reads the frozen solver/evaluator evidence and writes a
    /// separate diagnostic artifact. It never invokes Embed or Decide and it
    /// never mutates the v1 evidence.
    @Test
    def frozenSelectionDiagnosis(): Unit \ {Assert, Env, FileSystem, IO} =
        match Env.getVar("ATTUNE_JEV_DIAGNOSE") {
            case None => ()
            case Some("selection") => match executeDiagnosis() {
                case Ok(()) => ()
                case Err(error) => Assert.fail(ToString.toString(error))
            }
            case Some(value) => Assert.fail("unknown ATTUNE_JEV_DIAGNOSE: ${value}")
        }

    def executeDiagnosis(): Result[Error, Unit] \ {FileSystem, IO} = forM (
        priorPayload <- read(".attune/semantic-prior-v1/rankings.json");
        outcomePayload <- read(".attune/jev-localization-v1/outcomes.json");
        goldPayload <- Repository.Nix.runWithNative(() -> forM (
            evidence <- Repository.Nix.evaluation() |> Result.mapErr(Error.Nix);
            payload <- Repository.Nix.Acquire.readSource(Repository.Nix.path(evidence#goldFixture))
                |> Result.mapErr(Error.Nix)
        ) yield payload);
        gold <- decodeGold(goldPayload);
        tree = Localization.Tree.compile();
        cases <- diagnoseCases(0, priorPayload, outcomePayload, gold, tree, Vector.empty());
        _ <- writeDiagnosis(cases)
    ) yield printDiagnosisSummary(cases)

    def diagnoseCases(
        index: Int32,
        priorPayload: String,
        outcomePayload: String,
        gold: Vector[Gold],
        tree: Localization.Tree.Tree,
        cases: Vector[CaseDiagnosis]
    ): Result[Error, Vector[CaseDiagnosis]] \ {FileSystem, IO} =
        if (index >= 15) Ok(cases)
        else match Repository.Grit.runWithNative(() -> Repository.Nix.runWithNative(() -> Localization.prepareRetained(
            ".attune/repository-facts-v1", index))) {
            case Err(error) => Err(Error.Prepare(error))
            case Ok(prepared) => {
                let result = forM (
                    prior <- Localization.Tree.decodePrior(prepared#instanceId, priorPayload)
                        |> Result.mapErr(Error.Tree);
                    fixture <- decodeOutcome(prepared#instanceId, outcomePayload);
                    expected <- Vector.find(item -> item#instanceId == prepared#instanceId, gold)
                        |> Option.toOk(Error.MissingGold(prepared#instanceId));
                    actualPath <- Vector.traverse(decodeAtom, fixture#path);
                    computed <- Localization.Tree.compute(prepared, prior, tree)
                        |> Result.mapErr(Error.Tree);
                    routes = routeData(prepared, prior, computed, expected);
                    diagnosis <- diagnoseCase(prepared, prior, fixture, actualPath, routes)
                ) yield diagnosis;
                match result {
                    case Err(error) => Err(error)
                    case Ok(diagnosis) => {
                        println("JEV_DIAGNOSIS_CASE ${diagnosis#instanceId} divergence=${diagnosis#firstDivergenceDepth} largest_regret=${diagnosis#largestDecisionRegret} preview_states=${diagnosis#preview#uniqueStates} previews=${diagnosis#preview#uniquePreviews}");
                        diagnoseCases(index + 1, priorPayload, outcomePayload, gold, tree,
                            Vector.append(cases, Vector#{diagnosis}))
                    }
                }
            }
        }

    def routeData(
        prepared: Localization.Prepared,
        prior: Localization.Tree.Prior,
        computed: Localization.Tree.Computed,
        gold: Gold
    ): Vector[RouteDatum] = {
        let context = diagnosticScoreContext(prepared#sources, gold);
        let rootRanking = prior#ranking;
        let root = {
            path = Vector.empty(),
            ordinal = -1,
            state = computed#input,
            preview = diagnosticPreview(prepared#world, prior, computed#input),
            terminal = true,
            score = diagnosticScore(regionsFor(prepared, rootRanking), gold, context)
        };
        routeDataFrom(prepared, prior, computed, gold, context, 0, Vector#{root})
    }

    def routeDataFrom(
        prepared: Localization.Prepared,
        prior: Localization.Tree.Prior,
        computed: Localization.Tree.Computed,
        gold: Gold,
        context: DiagnosticScoreContext,
        index: Int32,
        result: Vector[RouteDatum]
    ): Vector[RouteDatum] =
        if (index >= Vector.length(computed#tree#routes)) result
        else {
            let route = Vector.get(index, computed#tree#routes);
            let id = Vector.get(index, computed#evaluation#outputs);
            let state = Radii.Compiled.state(computed#evaluation, id);
            let terminal = snd(Radii.endpoints(route#expression)) == Radii.Domain.Symbol;
            let ranking = Localization.Tree.promote(prior#ranking, state);
            let datum = {
                path = route#steps,
                ordinal = index,
                state = state,
                preview = diagnosticPreview(prepared#world, prior, state),
                terminal = terminal,
                score = if (terminal) diagnosticScore(regionsFor(prepared, ranking), gold, context)
                    else Vector.get(0, result)#score
            };
            routeDataFrom(prepared, prior, computed, gold, context, index + 1,
                Vector.append(result, Vector#{datum}))
        }

    def diagnosticScoreContext(sources: Vector[Repository.Source], gold: Gold): DiagnosticScoreContext = {
        let counts = lineCounts(sources, gold);
        let core = lines(gold#coreRegions, counts);
        let optional = lines(gold#optionalRegions, counts);
        {counts = counts, coreLines = core, usefulLines = Set.union(core, optional)}
    }

    /// Only the five metrics used by this selection diagnosis. The formulas
    /// are the same official formulas; expensive unrelated NDCG/budget work is
    /// deliberately not repeated for each of the 1,644 stopping routes.
    def diagnosticScore(
        predictions: Vector[SourceRegion],
        gold: Gold,
        context: DiagnosticScoreContext
    ): Score = {
        let predicted = lines(predictions, context#counts);
        let overlap = Set.size(Set.intersection(predicted, context#coreLines));
        let precision = ratio(overlap, Set.size(predicted));
        let recall = ratio(overlap, Set.size(context#coreLines));
        let f1 = if (precision + recall == 0.0) 0.0
            else 2.0 * precision * recall / (precision + recall);
        let visited = Vector.map(span -> span#path, predictions) |> Vector.toSet;
        {
            precision = precision,
            recall = recall,
            f1 = f1,
            hitFile = ratio(Set.size(Set.intersection(visited, gold#coreFiles)), Set.size(gold#coreFiles)),
            noiseFile = 0.0,
            hitRegion = 0.0,
            noiseRegion = 0.0,
            weightedCoreCoverage = 0.0,
            contextEfficiency = ratio(Set.size(Set.intersection(predicted, context#usefulLines)), Set.size(predicted)),
            ndcg100 = 0.0,
            ndcg300 = 0.0,
            ndcg500 = 0.0,
            recall100 = 0.0,
            recall300 = 0.0,
            recall500 = 0.0,
            firstUsefulHit = 0.0
        }
    }

    def diagnoseCase(
        prepared: Localization.Prepared,
        prior: Localization.Tree.Prior,
        fixture: OutcomeFixture,
        actualPath: Vector[Radii.Atom],
        routes: Vector[RouteDatum]
    ): Result[Error, CaseDiagnosis] = forM (
        jev <- exactRoute(actualPath, routes);
        oracle <- bestTerminal(Vector.empty(), None, routes)
            |> Option.toOk(Error.Diagnosis("no terminal route for ${prepared#instanceId}"));
        decisions <- decisionData(prepared, prior, fixture#decisions, actualPath, routes, 0,
            Vector.empty(), Vector.empty());
        greedy1 <- greedyRoute(Vector.empty(), 1, routes);
        greedy2 <- greedyRoute(Vector.empty(), 2, routes);
        greedy3 <- greedyRoute(Vector.empty(), 3, routes);
        greedyFull <- greedyRoute(Vector.empty(), Localization.Tree.maxDepth(), routes)
    ) yield {
        instanceId = prepared#instanceId,
        repository = prepared#repository,
        prior = Vector.get(0, routes)#score,
        jev = jev#score,
        oracle = oracle#score,
        jevPath = pathText(actualPath),
        oraclePath = pathText(oracle#path),
        firstDivergenceDepth = commonPrefix(actualPath, oracle#path, 0),
        firstValueLossDepth = firstRegretDepth(decisions, 0),
        largestDecisionRegret = maxRegret(decisions),
        distribution = pathDistribution(Vector.get(0, routes)#score#f1, oracle#score#f1, routes),
        preview = previewStats(routes, valueMap(routes)),
        decisions = decisions,
        motifs = motifData(actualPath, routes, 0, Vector.empty()),
        greedy1 = greedy1#score,
        greedy2 = greedy2#score,
        greedy3 = greedy3#score,
        greedyFull = greedyFull#score
    }

    def exactRoute(path: Vector[Radii.Atom], routes: Vector[RouteDatum]): Result[Error, RouteDatum] =
        Vector.find(route -> route#path == path, routes)
        |> Option.toOk(Error.Diagnosis("missing route: ${pathText(path)}"))

    def bestTerminal(
        prefix: Vector[Radii.Atom],
        maximumDepth: Option[Int32],
        routes: Vector[RouteDatum]
    ): Option[RouteDatum] =
        Vector.filter(route -> route#terminal and isPrefix(prefix, route#path) and
            match maximumDepth {
                case None => true
                case Some(depth) => Vector.length(route#path) <= depth
            }, routes)
        |> Vector.foldLeft((best, candidate) -> match best {
            case None => Some(candidate)
            case Some(current) => if (candidate#score#f1 > current#score#f1) Some(candidate) else best
        }, None)

    def isPrefix(prefix: Vector[Radii.Atom], path: Vector[Radii.Atom]): Bool =
        Vector.length(prefix) <= Vector.length(path) and prefixAt(prefix, path, 0)

    def prefixAt(prefix: Vector[Radii.Atom], path: Vector[Radii.Atom], index: Int32): Bool =
        if (index >= Vector.length(prefix)) true
        else Vector.get(index, prefix) == Vector.get(index, path) and prefixAt(prefix, path, index + 1)

    def commonPrefix(left: Vector[Radii.Atom], right: Vector[Radii.Atom], index: Int32): Int32 =
        if (index >= Vector.length(left) or index >= Vector.length(right)) index
        else if (Vector.get(index, left) == Vector.get(index, right)) commonPrefix(left, right, index + 1)
        else index

    def firstRegretDepth(decisions: Vector[DecisionDatum], index: Int32): Option[Int32] =
        if (index >= Vector.length(decisions)) None
        else if (Vector.get(index, decisions)#regret > 0.0000000001) Some(Vector.get(index, decisions)#depth)
        else firstRegretDepth(decisions, index + 1)

    def maxRegret(decisions: Vector[DecisionDatum]): Float64 =
        Vector.foldLeft((largest, decision) -> Float64.max(largest, decision#regret), 0.0, decisions)

    def decisionData(
        prepared: Localization.Prepared,
        prior: Localization.Tree.Prior,
        fixtures: Vector[DecisionFixture],
        actualPath: Vector[Radii.Atom],
        routes: Vector[RouteDatum],
        index: Int32,
        prefix: Vector[Radii.Atom],
        result: Vector[DecisionDatum]
    ): Result[Error, Vector[DecisionDatum]] =
        if (index >= Vector.length(fixtures)) Ok(result)
        else forM (
            current <- exactRoute(prefix, routes);
            fixture = Vector.get(index, fixtures);
            alternatives <- actionData(prepared, prior, fixture, prefix, current, routes);
            chosen <- Vector.find(action -> action#action == fixture#choice, alternatives)
                |> Option.toOk(Error.Diagnosis("choice ${fixture#choice} unavailable at ${pathText(prefix)}"));
            value <- bestTerminal(prefix, None, routes)
                |> Option.toOk(Error.Diagnosis("no value below ${pathText(prefix)}"));
            aliasStats = alternativePreviewAliases(alternatives);
            datum = {
                depth = Vector.length(prefix),
                path = pathText(prefix),
                choice = fixture#choice,
                confidence = fixture#confidence,
                current = current#score,
                value = value#score,
                chosenValue = chosen#best,
                regret = value#score#f1 - chosen#best#f1,
                alternatives = alternatives,
                previewAliases = fst(aliasStats),
                previewAliasMaxF1Spread = snd(aliasStats)
            };
            nextPrefix <- if (fixture#choice == "stop") Ok(prefix)
                else decodeAtom(fixture#choice)
                    |> Result.map(atom -> Vector.append(prefix, Vector#{atom}));
            tail <- decisionData(prepared, prior, fixtures, actualPath, routes, index + 1,
                nextPrefix, Vector.append(result, Vector#{datum}))
        ) yield tail

    def actionData(
        prepared: Localization.Prepared,
        prior: Localization.Tree.Prior,
        fixture: DecisionFixture,
        prefix: Vector[Radii.Atom],
        current: RouteDatum,
        routes: Vector[RouteDatum]
    ): Result[Error, Vector[ActionDatum]] = {
        let stop = match current#state {
            case Radii.Evaluate.State.Symbols(_) => Vector#{actionDatum(
                prepared, prior, fixture, "stop", prefix, current, current, current, routes)}
            case _ => Vector.empty()
        };
        let remaining = Localization.Tree.maxDepth() - Vector.length(prefix);
        let atoms0 = compatibleAtoms(current#state);
        let atoms = if (remaining == 1)
            Vector.filter(atom -> Radii.target(atom) == Radii.Domain.Symbol, atoms0)
            else atoms0;
        Vector.traverse(atom -> {
            let childPath = Vector.append(prefix, Vector#{atom});
            forM (
                child <- exactRoute(childPath, routes);
                best <- bestTerminal(childPath, None, routes)
                    |> Option.toOk(Error.Diagnosis("no terminal below ${pathText(childPath)}"))
            ) yield actionDatum(prepared, prior, fixture,
                Decide.actionKey(Decide.Action.Follow(atom)), childPath, current, child, best, routes)
        }, atoms)
        |> Result.map(follow -> Vector.append(stop, follow))
    }

    def actionDatum(
        prepared: Localization.Prepared,
        prior: Localization.Tree.Prior,
        fixture: DecisionFixture,
        action: String,
        path: Vector[Radii.Atom],
        current: RouteDatum,
        child: RouteDatum,
        best: RouteDatum,
        routes: Vector[RouteDatum]
    ): ActionDatum = {
        let currentMembers = priorMembers(prepared, prior, current#state);
        let childMembers = priorMembers(prepared, prior, child#state);
        let comparable = stateDomain(current#state) == stateDomain(child#state);
        let intersection = Set.intersection(currentMembers, childMembers);
        let union0 = Set.union(currentMembers, childMembers);
        {
            action = action,
            path = path,
            immediate = child#score,
            best = best#score,
            bestPath = pathText(best#path),
            cardinality = stateCardinality(child#state),
            cardinalityDelta = stateCardinality(child#state) - stateCardinality(current#state),
            overlap = if (comparable) Some(if (Set.isEmpty(union0)) 1.0 else ratio(Set.size(intersection), Set.size(union0))) else None,
            newMembers = if (comparable) Set.size(Set.difference(childMembers, currentMembers)) else Set.size(childMembers),
            removedMembers = if (comparable) Set.size(Set.difference(currentMembers, childMembers)) else Set.size(currentMembers),
            minPriorRank = minimum(Set.toVector(childMembers)),
            meanPriorRank = meanInts(Set.toVector(childMembers)),
            revisits = revisitsEarlier(child#state, path, routes),
            preview = child#preview,
            probability = Map.get(action, fixture#probabilities)
        }
    }

    def alternativePreviewAliases(alternatives: Vector[ActionDatum]): (Int32, Float64) = {
        let groups = Vector.foldLeft((acc, action) ->
            Map.insertWith((old, next) -> Vector.append(old, next), action#preview,
                Vector#{action#best#f1}, acc), Map.empty(), alternatives);
        Map.toVector(groups) |> Vector.foldLeft((acc, entry) -> {
            let values = snd(entry);
            let aliases = if (Vector.length(values) > 1) fst(acc) + 1 else fst(acc);
            let spread = if (Vector.isEmpty(values)) 0.0
                else maximumFloat(values) - minimumFloat(values);
            (aliases, Float64.max(snd(acc), spread))
        }, (0, 0.0))
    }

    def compatibleAtoms(state: Radii.Evaluate.State): Vector[Radii.Atom] = match state {
        case Radii.Evaluate.State.Symbols(_) => Vector#{Radii.Atom.DefinedIn, Radii.Atom.Calls, Radii.Atom.Callers}
        case Radii.Evaluate.State.Files(_) => Vector#{Radii.Atom.Defines, Radii.Atom.Imports, Radii.Atom.ImportedBy}
        case Radii.Evaluate.State.Locations(_) => Vector.empty()
    }

    def stateDomain(state: Radii.Evaluate.State): Radii.Domain = match state {
        case Radii.Evaluate.State.Files(_) => Radii.Domain.File
        case Radii.Evaluate.State.Symbols(_) => Radii.Domain.Symbol
        case Radii.Evaluate.State.Locations(_) => Radii.Domain.Location
    }

    def stateCardinality(state: Radii.Evaluate.State): Int32 = match state {
        case Radii.Evaluate.State.Files(values) => Set.size(values)
        case Radii.Evaluate.State.Symbols(values) => Set.size(values)
        case Radii.Evaluate.State.Locations(values) => Set.size(values)
    }

    def priorMembers(
        prepared: Localization.Prepared,
        prior: Localization.Tree.Prior,
        state: Radii.Evaluate.State
    ): Set[Int32] =
        Vector.mapWithIndex((rank, item) -> match state {
            case Radii.Evaluate.State.Symbols(symbols) =>
                if (Set.memberOf(Repository.Structure.SymbolId.SymbolId(item#ordinal), symbols)) Some(rank) else None
            case Radii.Evaluate.State.Files(files) =>
                fileForSymbolDiagnostic(Repository.Structure.SymbolId.SymbolId(item#ordinal), prepared#world#defines)
                |> Option.flatMap(file -> if (Set.memberOf(file, files)) Some(rank) else None)
            case Radii.Evaluate.State.Locations(_) => None
        }, prior#ranking)
        |> Vector.filterMap(identity)
        |> Vector.toSet

    def fileForSymbolDiagnostic(
        symbol: Repository.Structure.SymbolId,
        defines: Repository.Structure.Defines
    ): Option[Repository.Structure.FileId] =
        Set.find(match (_, target) -> target == symbol, defines) |> Option.map(fst)

    def revisitsEarlier(
        state: Radii.Evaluate.State,
        path: Vector[Radii.Atom],
        routes: Vector[RouteDatum]
    ): Bool =
        Vector.exists(route -> Vector.length(route#path) < Vector.length(path) and
            isPrefix(route#path, path) and route#state == state, routes)

    def diagnosticPreview(
        world: Repository.World,
        prior: Localization.Tree.Prior,
        state: Radii.Evaluate.State
    ): String = match state {
        case Radii.Evaluate.State.Symbols(symbols) => {
            let members = take(8, Vector.filter(item ->
                Set.memberOf(Repository.Structure.SymbolId.SymbolId(item#ordinal), symbols), prior#ranking));
            let lines = Vector.map(item -> {
                let symbol = Vector.get(item#ordinal, world#symbols);
                "${symbol#path} :: ${symbol#name}"
            }, members);
            "domain=symbol cardinality=${Set.size(symbols)} top=[${join(lines)}]"
        }
        case Radii.Evaluate.State.Files(files) => {
            let ranked = Vector.filterMap(item ->
                fileForSymbolDiagnostic(Repository.Structure.SymbolId.SymbolId(item#ordinal), world#defines)
                |> Option.flatMap(file -> if (Set.memberOf(file, files)) Some(file) else None), prior#ranking);
            let unique = uniqueDiagnosticFiles(ranked, Set.empty(), Vector.empty());
            let paths = take(8, unique) |> Vector.map(file -> {
                let Repository.Structure.FileId.FileId(index) = file;
                Vector.get(index, world#files)
            });
            "domain=file cardinality=${Set.size(files)} top=[${join(paths)}]"
        }
        case Radii.Evaluate.State.Locations(locations) =>
            "domain=location cardinality=${Set.size(locations)} top=[]"
    }

    def uniqueDiagnosticFiles(
        files: Vector[Repository.Structure.FileId],
        seen: Set[Repository.Structure.FileId],
        result: Vector[Repository.Structure.FileId]
    ): Vector[Repository.Structure.FileId] = match Vector.head(files) {
        case None => result
        case Some(file) => {
            let rest = Vector.slice(start = 1, end = Vector.length(files), files);
            if (Set.memberOf(file, seen)) uniqueDiagnosticFiles(rest, seen, result)
            else uniqueDiagnosticFiles(rest, Set.insert(file, seen), Vector.append(result, Vector#{file}))
        }
    }

    def take(count: Int32, values: Vector[a]): Vector[a] =
        Vector.slice(start = 0, end = Int32.min(count, Vector.length(values)), values)

    def join(values: Vector[String]): String =
        Vector.toList(values) |> List.intersperse("; ") |> List.fold

    def pathDistribution(prior: Float64, oracle: Float64, routes: Vector[RouteDatum]): Distribution = {
        let terminal = Vector.filter(route -> route#terminal, routes);
        let values = Vector.map(route -> route#score#f1, terminal) |> Vector.sort;
        let topThreshold = quantile(values, 90, 100);
        let top = Vector.filter(route -> route#score#f1 >= topThreshold and not Vector.isEmpty(route#path), terminal);
        let prefixes = Vector.foldLeft((counts, route) -> {
            let key = Decide.actionKey(Decide.Action.Follow(Vector.get(0, route#path)));
            Map.insertWith((left, right) -> left + right, key, 1, counts)
        }, Map.empty(), top);
        {
            median = quantile(values, 50, 100),
            p75 = quantile(values, 75, 100),
            p90 = topThreshold,
            p95 = quantile(values, 95, 100),
            p99 = quantile(values, 99, 100),
            betterThanPrior = Vector.count(value -> value > prior, values),
            atLeastPrior = Vector.count(value -> value >= prior, values),
            substantiallyBetter = Vector.count(value -> value >= prior + 0.05, values),
            within1 = Vector.count(value -> nearOracle(value, oracle, 0.01), values),
            within5 = Vector.count(value -> nearOracle(value, oracle, 0.05), values),
            within10 = Vector.count(value -> nearOracle(value, oracle, 0.10), values),
            terminalRoutes = Vector.length(values),
            topDecileFirstActions = prefixes
        }
    }

    def nearOracle(value: Float64, oracle: Float64, fraction: Float64): Bool =
        if (oracle == 0.0) value == 0.0 else oracle - value <= oracle * fraction

    def quantile(sorted: Vector[Float64], numerator: Int32, denominator: Int32): Float64 = {
        let length = Vector.length(sorted);
        if (length == 0) 0.0
        else {
            let index = (length - 1) * numerator / denominator;
            Vector.get(index, sorted)
        }
    }

    def valueMap(routes: Vector[RouteDatum]): Map[String, Float64] =
        valueMapFrom(routes, Vector.length(routes) - 1, Map.empty())

    def valueMapFrom(
        routes: Vector[RouteDatum],
        index: Int32,
        values: Map[String, Float64]
    ): Map[String, Float64] =
        if (index < 0) values
        else {
            let route = Vector.get(index, routes);
            let own = if (route#terminal) route#score#f1 else -1.0;
            let child = Vector.foldLeft((best, atom) -> {
                let key = pathText(Vector.append(route#path, Vector#{atom}));
                match Map.get(key, values) {
                    case None => best
                    case Some(value) => Float64.max(best, value)
                }
            }, -1.0, compatibleAtoms(route#state));
            valueMapFrom(routes, index - 1,
                Map.insert(pathText(route#path), Float64.max(own, child), values))
        }

    def previewStats(routes: Vector[RouteDatum], values: Map[String, Float64]): PreviewStats = {
        // Depth-seven File states are Atlas measurement prefixes but cannot be
        // offered by the frozen localization protocol. Exclude nodes with no
        // valid Symbol stopping descendant from model-visible diagnostics.
        let visibleRoutes = Vector.filter(route ->
            Map.get(pathText(route#path), values) |> Option.exists(value -> value >= 0.0), routes);
        let states = Vector.map(route -> route#state, visibleRoutes) |> Vector.toSet;
        let groups = Vector.foldLeft((acc, route) -> {
            let entries = Map.get(route#preview, acc) |> Option.getWithDefault(Map.empty());
            let value = Map.get(pathText(route#path), values) |> Option.getWithDefault(-1.0);
            Map.insert(route#preview, Map.insert(route#state, value, entries), acc)
        }, Map.empty(), visibleRoutes);
        let groupValues = Map.toVector(groups) |> Vector.map(entry -> snd(entry));
        {
            nodes = Vector.length(visibleRoutes),
            uniqueStates = Set.size(states),
            uniquePreviews = Map.size(groups),
            collidingPreviews = Vector.count(group -> Map.size(group) > 1, groupValues),
            maxMultiplicity = Vector.foldLeft((largest, group) -> Int32.max(largest, Map.size(group)), 0, groupValues),
            valueDivergentPreviews = Vector.count(group -> previewSpread(group) > 0.05, groupValues),
            maxF1Spread = Vector.foldLeft((largest, group) -> Float64.max(largest, previewSpread(group)), 0.0, groupValues)
        }
    }

    def previewSpread(group: Map[Radii.Evaluate.State, Float64]): Float64 = {
        let values = Map.toVector(group) |> Vector.map(snd);
        if (Vector.isEmpty(values)) 0.0 else maximumFloat(values) - minimumFloat(values)
    }

    def motifData(
        path: Vector[Radii.Atom],
        routes: Vector[RouteDatum],
        index: Int32,
        result: Vector[MotifDatum]
    ): Vector[MotifDatum] =
        if (index + 1 >= Vector.length(path)) result
        else if (Vector.get(index, path) == Radii.Atom.DefinedIn and
                 Vector.get(index + 1, path) == Radii.Atom.Defines) {
            let beforePath = Vector.slice(start = 0, end = index, path);
            let afterPath = Vector.slice(start = 0, end = index + 2, path);
            let before = Vector.find(route -> route#path == beforePath, routes);
            let after = Vector.find(route -> route#path == afterPath, routes);
            let next = match (before, after, bestTerminal(beforePath, None, routes), bestTerminal(afterPath, None, routes)) {
                case (Some(a), Some(b), Some(av), Some(bv)) => match (a#state, b#state) {
                    case (Radii.Evaluate.State.Symbols(xs), Radii.Evaluate.State.Symbols(ys)) => {
                        let union0 = Set.union(xs, ys);
                        let datum = {
                            depth = index,
                            beforeCardinality = Set.size(xs),
                            afterCardinality = Set.size(ys),
                            jaccard = if (Set.isEmpty(union0)) 1.0 else ratio(Set.size(Set.intersection(xs, ys)), Set.size(union0)),
                            newSymbols = Set.size(Set.difference(ys, xs)),
                            removedSymbols = Set.size(Set.difference(xs, ys)),
                            previewChanged = a#preview != b#preview,
                            valueBefore = av#score#f1,
                            valueAfter = bv#score#f1
                        };
                        Vector.append(result, Vector#{datum})
                    }
                    case _ => result
                }
                case _ => result
            };
            motifData(path, routes, index + 1, next)
        } else motifData(path, routes, index + 1, result)

    /// Receding-horizon oracle. At every state it chooses the stable first
    /// action with the best terminal F1 visible within `horizon` actions.
    def greedyRoute(
        prefix: Vector[Radii.Atom],
        horizon: Int32,
        routes: Vector[RouteDatum]
    ): Result[Error, RouteDatum] = forM (
        current <- exactRoute(prefix, routes);
        result <- if (Vector.length(prefix) >= Localization.Tree.maxDepth()) Ok(current)
            else {
                let limit = Int32.min(Localization.Tree.maxDepth(), Vector.length(prefix) + horizon);
                let visible = bestTerminal(prefix, Some(limit), routes);
                match visible {
                    case None => Err(Error.Diagnosis("no horizon-${horizon} terminal below ${pathText(prefix)}"))
                    case Some(best) => if (best#path == prefix) Ok(current)
                        else {
                            let atom = Vector.get(Vector.length(prefix), best#path);
                            greedyRoute(Vector.append(prefix, Vector#{atom}), horizon, routes)
                        }
                }
            }
    ) yield result

    def decodeAtom(value: String): Result[Error, Radii.Atom] = match value {
        case "defines" => Ok(Radii.Atom.Defines)
        case "defined_in" => Ok(Radii.Atom.DefinedIn)
        case "imports" => Ok(Radii.Atom.Imports)
        case "imported_by" => Ok(Radii.Atom.ImportedBy)
        case "calls" => Ok(Radii.Atom.Calls)
        case "callers" => Ok(Radii.Atom.Callers)
        case _ => Err(Error.Diagnosis("unknown frozen action: ${value}"))
    }

    def minimum(values: Vector[Int32]): Option[Int32] =
        if (Vector.isEmpty(values)) None else Some(Vector.foldLeft(Int32.min, Vector.get(0, values), values))

    def meanInts(values: Vector[Int32]): Option[Float64] =
        if (Vector.isEmpty(values)) None else Some(
            Int32.toFloat64(Vector.foldLeft((sum0, value) -> sum0 + value, 0, values)) /
            Int32.toFloat64(Vector.length(values)))

    def minimumFloat(values: Vector[Float64]): Float64 =
        Vector.foldLeft(Float64.min, Vector.get(0, values), values)

    def maximumFloat(values: Vector[Float64]): Float64 =
        Vector.foldLeft(Float64.max, Vector.get(0, values), values)

    def writeDiagnosis(cases: Vector[CaseDiagnosis]): Result[Error, Unit] \ FileSystem = {
        let decisions = Vector.flatMap(case0 -> case0#decisions, cases);
        let motifs = Vector.flatMap(case0 -> case0#motifs, cases);
        let payload = Json.toCompactString(JObject(Map#{
            "version" => ToJson.toJson(1),
            "kind" => JString("post-hoc-selection-diagnosis"),
            "frozen_protocol" => JString(Decide.protocol()),
            "frozen_model" => JString(Decide.model()),
            "frozen_outcomes_sha256" => JString("0901bf208bcf98ccdfce0c6281e9990f90b4823d8fd68ea0780e484cceb7636c"),
            "frozen_evaluation_sha256" => JString("70cedc1753711ec4acba7f547c4a4ad2f623a2ca48b98aea5d97c8c8d62dd541"),
            "frozen_prior_sha256" => JString("73efdb1159aeb0be552ae16bf53f52ca85755c29d2ea35f478fc5469f521c914"),
            "substantial_f1_delta" => ToJson.toJson(0.05),
            "preview_value_divergence_delta" => ToJson.toJson(0.05),
            "summary" => summaryJson(cases, decisions, motifs),
            "cases" => JArray(Vector.map(caseDiagnosisJson, cases))
        }));
        let written = run {
            FileSystem.write(str = payload, ".attune/jev-selection-diagnosis-v1/diagnosis.json")
        } with FileSystem.withMkParentDirs
          with FileSystem.withAtomicWrite;
        Result.mapErr(error -> Error.File(ToString.toString(error)), written)
    }

    def summaryJson(
        cases: Vector[CaseDiagnosis],
        decisions: Vector[DecisionDatum],
        motifs: Vector[MotifDatum]
    ): Json = {
        let regrets = Vector.map(decision -> decision#regret, decisions);
        let confidences = Vector.map(decision -> decision#confidence, decisions);
        JObject(Map#{
            "cases" => ToJson.toJson(Vector.length(cases)),
            "decisions" => ToJson.toJson(Vector.length(decisions)),
            "mean_regret" => ToJson.toJson(meanFloat(regrets)),
            "median_regret" => ToJson.toJson(median(regrets)),
            "max_regret" => ToJson.toJson(if (Vector.isEmpty(regrets)) 0.0 else maximumFloat(regrets)),
            "confidence_regret_pearson" => ToJson.toJson(pearson(confidences, regrets)),
            "regret_by_depth" => groupedDecisionJson(decisions, decision -> ToString.toString(decision#depth)),
            "regret_by_choice" => groupedDecisionJson(decisions, decision -> decision#choice),
            "stopping" => stoppingJson(cases),
            "defined_in_defines" => motifSummaryJson(motifs),
            "lookahead" => JObject(Map#{
                "prior_f1" => ToJson.toJson(meanCase(cases, case0 -> case0#prior#f1)),
                "jev_f1" => ToJson.toJson(meanCase(cases, case0 -> case0#jev#f1)),
                "horizon_1_f1" => ToJson.toJson(meanCase(cases, case0 -> case0#greedy1#f1)),
                "horizon_2_f1" => ToJson.toJson(meanCase(cases, case0 -> case0#greedy2#f1)),
                "horizon_3_f1" => ToJson.toJson(meanCase(cases, case0 -> case0#greedy3#f1)),
                "full_f1" => ToJson.toJson(meanCase(cases, case0 -> case0#greedyFull#f1)),
                "structural_oracle_f1" => ToJson.toJson(meanCase(cases, case0 -> case0#oracle#f1))
            })
        })
    }

    def groupedDecisionJson(
        decisions: Vector[DecisionDatum],
        key: DecisionDatum -> String
    ): Json = {
        let groups = Vector.foldLeft((acc, decision) ->
            Map.insertWith((old, next) -> Vector.append(old, next), key(decision),
                Vector#{decision#regret}, acc), Map.empty(), decisions);
        JObject(Map.toVector(groups) |> Vector.map(match (name, values) -> (name, JObject(Map#{
            "n" => ToJson.toJson(Vector.length(values)),
            "mean" => ToJson.toJson(meanFloat(values)),
            "median" => ToJson.toJson(median(values)),
            "max" => ToJson.toJson(if (Vector.isEmpty(values)) 0.0 else maximumFloat(values))
        }))) |> Vector.toMap)
    }

    def stoppingJson(cases: Vector[CaseDiagnosis]): Json = {
        let counts = Vector.foldLeft((acc, case0) -> Vector.foldLeft((inner, decision) -> {
            let label = if (decision#choice == "stop")
                (if (decision#regret <= 0.0000000001) "correct_stop" else "premature_stop")
                else if (decision#current#f1 > case0#jev#f1) "failure_to_stop"
                else if (decision#current#f1 == case0#jev#f1) "harmless_continuation"
                else "useful_continuation";
            Map.insertWith((left, right) -> left + right, label, 1, inner)
        }, acc, case0#decisions), Map.empty(), cases);
        JObject(Map.toVector(counts) |> Vector.map(match (name, count) -> (name, ToJson.toJson(count))) |> Vector.toMap)
    }

    def motifSummaryJson(motifs: Vector[MotifDatum]): Json = JObject(Map#{
        "n" => ToJson.toJson(Vector.length(motifs)),
        "mean_jaccard" => ToJson.toJson(meanFloat(Vector.map(item -> item#jaccard, motifs))),
        "exactly_idempotent" => ToJson.toJson(Vector.count(item -> item#jaccard == 1.0, motifs)),
        "mean_new_symbols" => ToJson.toJson(meanFloat(Vector.map(item -> Int32.toFloat64(item#newSymbols), motifs))),
        "mean_removed_symbols" => ToJson.toJson(meanFloat(Vector.map(item -> Int32.toFloat64(item#removedSymbols), motifs))),
        "mean_value_change" => ToJson.toJson(meanFloat(Vector.map(item -> item#valueAfter - item#valueBefore, motifs)))
    })

    def caseDiagnosisJson(case0: CaseDiagnosis): Json = JObject(Map#{
        "instance_id" => JString(case0#instanceId),
        "repository" => JString(case0#repository),
        "prior" => diagnosticScoreJson(case0#prior),
        "jev" => diagnosticScoreJson(case0#jev),
        "oracle" => diagnosticScoreJson(case0#oracle),
        "jev_path" => JString(case0#jevPath),
        "oracle_path" => JString(case0#oraclePath),
        "first_divergence_depth" => ToJson.toJson(case0#firstDivergenceDepth),
        "first_value_loss_depth" => optionIntJson(case0#firstValueLossDepth),
        "largest_decision_regret" => ToJson.toJson(case0#largestDecisionRegret),
        "distribution" => distributionJson(case0#distribution),
        "preview" => previewStatsJson(case0#preview),
        "decisions" => JArray(Vector.map(decisionDatumJson, case0#decisions)),
        "defined_in_defines" => JArray(Vector.map(motifDatumJson, case0#motifs)),
        "lookahead" => JObject(Map#{
            "horizon_1" => diagnosticScoreJson(case0#greedy1),
            "horizon_2" => diagnosticScoreJson(case0#greedy2),
            "horizon_3" => diagnosticScoreJson(case0#greedy3),
            "full" => diagnosticScoreJson(case0#greedyFull)
        })
    })

    def diagnosticScoreJson(value: Score): Json = JObject(Map#{
        "precision" => ToJson.toJson(value#precision),
        "recall" => ToJson.toJson(value#recall),
        "f1" => ToJson.toJson(value#f1),
        "hit_file" => ToJson.toJson(value#hitFile),
        "context_efficiency" => ToJson.toJson(value#contextEfficiency)
    })

    def distributionJson(value: Distribution): Json = JObject(Map#{
        "terminal_routes" => ToJson.toJson(value#terminalRoutes),
        "median" => ToJson.toJson(value#median),
        "p75" => ToJson.toJson(value#p75),
        "p90" => ToJson.toJson(value#p90),
        "p95" => ToJson.toJson(value#p95),
        "p99" => ToJson.toJson(value#p99),
        "better_than_prior" => ToJson.toJson(value#betterThanPrior),
        "at_least_prior" => ToJson.toJson(value#atLeastPrior),
        "substantially_better" => ToJson.toJson(value#substantiallyBetter),
        "within_1_percent_of_oracle" => ToJson.toJson(value#within1),
        "within_5_percent_of_oracle" => ToJson.toJson(value#within5),
        "within_10_percent_of_oracle" => ToJson.toJson(value#within10),
        "top_decile_first_actions" => intMapJson(value#topDecileFirstActions)
    })

    def previewStatsJson(value: PreviewStats): Json = JObject(Map#{
        "nodes" => ToJson.toJson(value#nodes),
        "unique_states" => ToJson.toJson(value#uniqueStates),
        "unique_previews" => ToJson.toJson(value#uniquePreviews),
        "colliding_previews" => ToJson.toJson(value#collidingPreviews),
        "max_collision_multiplicity" => ToJson.toJson(value#maxMultiplicity),
        "value_divergent_previews" => ToJson.toJson(value#valueDivergentPreviews),
        "max_f1_spread" => ToJson.toJson(value#maxF1Spread)
    })

    def decisionDatumJson(value: DecisionDatum): Json = JObject(Map#{
        "depth" => ToJson.toJson(value#depth),
        "path" => JString(value#path),
        "choice" => JString(value#choice),
        "confidence" => ToJson.toJson(value#confidence),
        "current" => diagnosticScoreJson(value#current),
        "value_to_go" => diagnosticScoreJson(value#value),
        "chosen_value_to_go" => diagnosticScoreJson(value#chosenValue),
        "f1_regret" => ToJson.toJson(value#regret),
        "preview_aliases" => ToJson.toJson(value#previewAliases),
        "preview_alias_max_f1_spread" => ToJson.toJson(value#previewAliasMaxF1Spread),
        "alternatives" => JArray(Vector.map(actionDatumJson, value#alternatives))
    })

    def actionDatumJson(value: ActionDatum): Json = JObject(Map#{
        "action" => JString(value#action),
        "path" => JString(pathText(value#path)),
        "immediate" => diagnosticScoreJson(value#immediate),
        "value_to_go" => diagnosticScoreJson(value#best),
        "best_descendant_path" => JString(value#bestPath),
        "cardinality" => ToJson.toJson(value#cardinality),
        "cardinality_delta" => ToJson.toJson(value#cardinalityDelta),
        "jaccard_with_parent" => optionFloatJson(value#overlap),
        "new_prior_ranked_members" => ToJson.toJson(value#newMembers),
        "removed_prior_ranked_members" => ToJson.toJson(value#removedMembers),
        "min_prior_rank" => optionIntJson(value#minPriorRank),
        "mean_prior_rank" => optionFloatJson(value#meanPriorRank),
        "revisits_earlier_state" => ToJson.toJson(value#revisits),
        "preview" => JString(value#preview),
        "probability" => optionFloatJson(value#probability)
    })

    def motifDatumJson(value: MotifDatum): Json = JObject(Map#{
        "depth" => ToJson.toJson(value#depth),
        "before_cardinality" => ToJson.toJson(value#beforeCardinality),
        "after_cardinality" => ToJson.toJson(value#afterCardinality),
        "jaccard" => ToJson.toJson(value#jaccard),
        "new_symbols" => ToJson.toJson(value#newSymbols),
        "removed_symbols" => ToJson.toJson(value#removedSymbols),
        "preview_changed" => ToJson.toJson(value#previewChanged),
        "value_before" => ToJson.toJson(value#valueBefore),
        "value_after" => ToJson.toJson(value#valueAfter)
    })

    def optionIntJson(value: Option[Int32]): Json = match value {
        case None => JNull
        case Some(number) => ToJson.toJson(number)
    }

    def optionFloatJson(value: Option[Float64]): Json = match value {
        case None => JNull
        case Some(number) => ToJson.toJson(number)
    }

    def intMapJson(values: Map[String, Int32]): Json =
        JObject(Map.toVector(values) |> Vector.map(match (key, value) -> (key, ToJson.toJson(value))) |> Vector.toMap)

    def meanFloat(values: Vector[Float64]): Float64 =
        if (Vector.isEmpty(values)) 0.0
        else sumFloats(values) / Int32.toFloat64(Vector.length(values))

    def meanCase(cases: Vector[CaseDiagnosis], f: CaseDiagnosis -> Float64): Float64 =
        meanFloat(Vector.map(f, cases))

    def pearson(xs: Vector[Float64], ys: Vector[Float64]): Float64 = {
        let n = Int32.min(Vector.length(xs), Vector.length(ys));
        if (n < 2) 0.0
        else {
            let x = Vector.slice(start = 0, end = n, xs);
            let y = Vector.slice(start = 0, end = n, ys);
            let xm = meanFloat(x);
            let ym = meanFloat(y);
            let covariance = Vector.mapWithIndex((index, value) ->
                (value - xm) * (Vector.get(index, y) - ym), x) |> sumFloats;
            let x2 = Vector.map(value -> (value - xm) * (value - xm), x) |> sumFloats;
            let y2 = Vector.map(value -> (value - ym) * (value - ym), y) |> sumFloats;
            let denominator = squareRoot(x2 * y2);
            if (denominator == 0.0) 0.0 else covariance / denominator
        }
    }

    def squareRoot(value: Float64): Float64 =
        if (value <= 0.0) 0.0 else squareRootFrom(value, value, 0)

    def squareRootFrom(value: Float64, guess: Float64, iteration: Int32): Float64 =
        if (iteration >= 24) guess
        else squareRootFrom(value, (guess + value / guess) / 2.0, iteration + 1)

    def printDiagnosisSummary(cases: Vector[CaseDiagnosis]): Unit \ IO = {
        let decisions = Vector.flatMap(case0 -> case0#decisions, cases);
        let regrets = Vector.map(decision -> decision#regret, decisions);
        println("JEV_SELECTION_DIAGNOSIS cases=${Vector.length(cases)} decisions=${Vector.length(decisions)}" +
            " mean_regret=${meanFloat(regrets)} median_regret=${median(regrets)}" +
            " max_regret=${if (Vector.isEmpty(regrets)) 0.0 else maximumFloat(regrets)}" +
            " confidence_regret=${pearson(Vector.map(decision -> decision#confidence, decisions), regrets)}" +
            " horizon1=${meanCase(cases, case0 -> case0#greedy1#f1)}" +
            " horizon2=${meanCase(cases, case0 -> case0#greedy2#f1)}" +
            " horizon3=${meanCase(cases, case0 -> case0#greedy3#f1)}" +
            " full=${meanCase(cases, case0 -> case0#greedyFull#f1)}")
    }

    def execute(): Result[Error, Unit] \ {FileSystem, IO} = forM (
        priorPayload <- read(".attune/semantic-prior-v1/rankings.json");
        outcomePayload <- read(".attune/jev-localization-v1/outcomes.json");
        goldPayload <- Repository.Nix.runWithNative(() -> forM (
            evidence <- Repository.Nix.evaluation() |> Result.mapErr(Error.Nix);
            payload <- Repository.Nix.Acquire.readSource(Repository.Nix.path(evidence#goldFixture))
                |> Result.mapErr(Error.Nix)
        ) yield payload);
        gold <- decodeGold(goldPayload);
        tree = Localization.Tree.compile();
        rows <- evaluateCases(0, priorPayload, outcomePayload, gold, tree, Vector.empty());
        _ <- validateOfficialParity(rows);
        _ <- writeResults(rows)
    ) yield printAggregate(rows)

    /// Scores a frozen experiment outcome through the same official evaluator
    /// without changing or validating against the immutable v1 aggregate.
    /// Gold enters only this post-hoc process, never the candidate runner.
    def executeCandidate(): Result[Error, Unit] \ {Env, FileSystem, IO} = forM (
        outcomePath <- requiredEnv("ATTUNE_JEV_CANDIDATE_OUTCOMES");
        outputPath <- requiredEnv("ATTUNE_JEV_CANDIDATE_EVALUATION");
        candidateProtocol <- requiredEnv("ATTUNE_JEV_CANDIDATE_PROTOCOL");
        priorPayload <- read(".attune/semantic-prior-v1/rankings.json");
        outcomePayload <- read(outcomePath);
        frozenPayload <- read("JEV_LOCALIZATION_RESULTS.json");
        goldPayload <- Repository.Nix.runWithNative(() -> forM (
            evidence <- Repository.Nix.evaluation() |> Result.mapErr(Error.Nix);
            payload <- Repository.Nix.Acquire.readSource(Repository.Nix.path(evidence#goldFixture))
                |> Result.mapErr(Error.Nix)
        ) yield payload);
        gold <- decodeGold(goldPayload);
        rows <- evaluateCandidateCases(0, priorPayload, outcomePayload, frozenPayload,
            gold, Vector.empty());
        _ <- writeResultsAt(rows, outputPath, candidateProtocol)
    ) yield printAggregate(rows)

    def requiredEnv(name: String): Result[Error, String] \ Env =
        Env.getVar(name) |> Option.toOk(Error.Wire("missing environment variable: ${name}"))

    def evaluateCandidateCases(
        index: Int32,
        priorPayload: String,
        outcomePayload: String,
        frozenPayload: String,
        gold: Vector[Gold],
        rows: Vector[Row]
    ): Result[Error, Vector[Row]] \ {FileSystem, IO} =
        if (index >= 15) Ok(rows)
        else match Repository.Grit.runWithNative(() -> Repository.Nix.runWithNative(() ->
            Localization.prepareRetained(".attune/repository-facts-v1", index))) {
            case Err(error) => Err(Error.Prepare(error))
            case Ok(prepared) => {
                let result = forM (
                    prior <- Localization.Tree.decodePrior(prepared#instanceId, priorPayload)
                        |> Result.mapErr(Error.Tree);
                    fixture <- decodeOutcome(prepared#instanceId, outcomePayload);
                    ranking <- reorder(prior#ranking, fixture#ranking);
                    expected <- Vector.find(item -> item#instanceId == prepared#instanceId, gold)
                        |> Option.toOk(Error.MissingGold(prepared#instanceId));
                    frozen <- decodeFrozen(prepared#instanceId, frozenPayload);
                    candidateRegions = regionsFor(prepared, ranking);
                    candidateScore = score(candidateRegions, expected, prepared#sources)
                ) yield {
                    instanceId = prepared#instanceId,
                    repository = prepared#repository,
                    prior = frozen#prior,
                    jev = candidateScore,
                    oracle = frozen#oracle,
                    oraclePath = frozen#oraclePath,
                    priorRegions = frozen#priorRegions,
                    jevRegions = candidateRegions,
                    oracleRegions = frozen#oracleRegions
                };
                match result {
                    case Err(error) => Err(error)
                    case Ok(row) => {
                        printRow(row);
                        evaluateCandidateCases(index + 1, priorPayload, outcomePayload,
                            frozenPayload, gold, Vector.append(rows, Vector#{row}))
                    }
                }
            }
        }

    def evaluateCases(
        index: Int32,
        priorPayload: String,
        outcomePayload: String,
        gold: Vector[Gold],
        tree: Localization.Tree.Tree,
        rows: Vector[Row]
    ): Result[Error, Vector[Row]] \ {FileSystem, IO} =
        if (index >= 15) Ok(rows)
        else match Repository.Grit.runWithNative(() -> Repository.Nix.runWithNative(() -> Localization.prepareRetained(
            ".attune/repository-facts-v1", index))) {
            case Err(error) => Err(Error.Prepare(error))
            case Ok(prepared) => {
                let result = forM (
                    prior <- Localization.Tree.decodePrior(prepared#instanceId, priorPayload)
                        |> Result.mapErr(Error.Tree);
                    fixture <- decodeOutcome(prepared#instanceId, outcomePayload);
                    jevRanking <- reorder(prior#ranking, fixture#ranking);
                    expected <- Vector.find(item -> item#instanceId == prepared#instanceId, gold)
                        |> Option.toOk(Error.MissingGold(prepared#instanceId));
                    computed <- Localization.Tree.compute(prepared, prior, tree)
                        |> Result.mapErr(Error.Tree);
                    priorRegions = regionsFor(prepared, prior#ranking);
                    jevRegions = regionsFor(prepared, jevRanking);
                    priorScore = score(priorRegions, expected, prepared#sources);
                    jevScore = score(jevRegions, expected, prepared#sources);
                    oracle = structuralOracle(prepared, prior, computed, expected)
                ) yield {
                    instanceId = prepared#instanceId,
                    repository = prepared#repository,
                    prior = priorScore,
                    jev = jevScore,
                    oracle = oracle#score,
                    oraclePath = oracle#path,
                    priorRegions = priorRegions,
                    jevRegions = jevRegions,
                    oracleRegions = oracle#regions
                };
                match result {
                    case Err(error) => Err(error)
                    case Ok(row) => {
                        printRow(row);
                        evaluateCases(index + 1, priorPayload, outcomePayload, gold, tree,
                            Vector.append(rows, Vector#{row}))
                    }
                }
            }
        }

    /// Root is a legitimate stop state. Every Symbol-ending frozen Atlas path
    /// then competes by official line F1; stable route order breaks ties.
    def structuralOracle(
        prepared: Localization.Prepared,
        prior: Localization.Tree.Prior,
        computed: Localization.Tree.Computed,
        gold: Gold
    ): Best = {
        let rootRegions = regionsFor(prepared, prior#ranking);
        let root: CandidateBest = {
            path = "root",
            f1 = lineF1(rootRegions, gold, prepared#sources),
            regions = rootRegions
        };
        let winner = bestRoute(prepared, prior, computed, gold, 0, root);
        {
            path = winner#path,
            score = score(winner#regions, gold, prepared#sources),
            regions = winner#regions
        }
    }

    def bestRoute(
        prepared: Localization.Prepared,
        prior: Localization.Tree.Prior,
        computed: Localization.Tree.Computed,
        gold: Gold,
        index: Int32,
        best: CandidateBest
    ): CandidateBest =
        if (index >= Vector.length(computed#tree#routes)) best
        else {
            let route = Vector.get(index, computed#tree#routes);
            let next = if (snd(Radii.endpoints(route#expression)) != Radii.Domain.Symbol) best
                else {
                    let id = Vector.get(index, computed#evaluation#outputs);
                    let state = Radii.Compiled.state(computed#evaluation, id);
                    let ranking = Localization.Tree.promote(prior#ranking, state);
                    let spans = regionsFor(prepared, ranking);
                    let candidate = {
                        path = pathText(route#steps),
                        f1 = lineF1(spans, gold, prepared#sources),
                        regions = spans
                    };
                    if (candidate#f1 > best#f1) candidate else best
                };
            bestRoute(prepared, prior, computed, gold, index + 1, next)
        }

    def regionsFor(prepared: Localization.Prepared, ranking: Vector[Localization.Ranked]): Vector[SourceRegion] =
        regionsFrom(prepared, ranking, 0, Set.empty(), Vector.empty())

    def regionsFrom(
        prepared: Localization.Prepared,
        ranking: Vector[Localization.Ranked],
        index: Int32,
        seen: Set[(String, Int32, Int32)],
        result: Vector[SourceRegion]
    ): Vector[SourceRegion] =
        if (Vector.length(result) >= 5 or index >= Vector.length(ranking)) result
        else {
            let item = Vector.get(index, ranking);
            let document = Vector.get(item#ordinal, prepared#documents);
            let source = Vector.find(value -> value#path == document#path, preparedSources(prepared));
            match source {
            case None => regionsFrom(prepared, ranking, index + 1, seen, result)
                case Some(value) => {
                    let span = byteRegion(document, value#content);
                    let key = (span#path, span#start, span#end);
                    if (Set.memberOf(key, seen))
                        regionsFrom(prepared, ranking, index + 1, seen, result)
                    else
                        regionsFrom(prepared, ranking, index + 1, Set.insert(key, seen),
                            Vector.append(result, Vector#{span}))
                }
            }
        }

    /// Prepared documents retain paths but not their enclosing source text.
    /// Nix-owned source text is recovered from the snapshot identity without
    /// consulting evaluator gold.
    def preparedSources(prepared: Localization.Prepared): Vector[Repository.Source] =
        prepared#sources

    def byteRegion(document: Localization.Document, source: String): SourceRegion = {
        let bytes = String.toBytes(source);
        let final = if (document#endByte <= document#startByte)
            document#startByte else document#endByte - 1;
        {
            path = document#path,
            start = lineAt(document#startByte, bytes),
            end = lineAt(final, bytes)
        }
    }

    def lineAt(offset: Int32, bytes: Vector[Int8]): Int32 =
        countNewlines(bytes, 0, offset, 1)

    def countNewlines(bytes: Vector[Int8], index: Int32, end: Int32, line: Int32): Int32 =
        if (index >= end or index >= Vector.length(bytes)) line
        else countNewlines(bytes, index + 1, end,
            if (Int8.toInt32(Vector.get(index, bytes)) == 10) line + 1 else line)

    /// Literal Flix port of quality/bench_metrics.py at evaluator revision
    /// 5602f031f2d9562d0a805f83402b536e831a5a11.
    def score(
        predictions: Vector[SourceRegion],
        gold: Gold,
        sources: Vector[Repository.Source]
    ): Score = {
        let counts = lineCounts(sources, gold);
        let predictedLines = lines(predictions, counts);
        let coreLines = lines(gold#coreRegions, counts);
        let optionalLines = lines(gold#optionalRegions, counts);
        let overlap = Set.size(Set.intersection(predictedLines, coreLines));
        let precision = ratio(overlap, Set.size(predictedLines));
        let recall = ratio(overlap, Set.size(coreLines));
        let f1 = if (precision + recall == 0.0) 0.0
            else 2.0 * precision * recall / (precision + recall);
        let visited = Vector.map(span -> span#path, predictions) |> Vector.toSet;
        let usefulFiles = Set.union(gold#coreFiles, gold#optionalFiles);
        let noiseFiles = Set.difference(visited, usefulFiles);
        let hitRegions = Vector.count(core ->
            Vector.exists(predicted -> overlaps(core, predicted, counts), predictions),
            gold#coreRegions);
        let noiseRegions = Vector.count(predicted ->
            not Vector.exists(core -> overlaps(predicted, core, counts), gold#coreRegions) and
            not Vector.exists(optional -> overlaps(predicted, optional, counts), gold#optionalRegions),
            predictions);
        let weighted = weightedCoverage(gold#coreRegions, gold#mainFiles, predictedLines, counts);
        let usefulLines = Set.union(coreLines, optionalLines);
        let gains = Vector.mapWithIndex((index, span0) ->
            regionGain(index, span0, coreLines, gold#mainFiles, counts), predictions);
        {
            precision = precision,
            recall = recall,
            f1 = f1,
            hitFile = ratio(Set.size(Set.intersection(visited, gold#coreFiles)), Set.size(gold#coreFiles)),
            noiseFile = ratio(Set.size(noiseFiles), Set.size(visited)),
            hitRegion = ratio(hitRegions, Vector.length(gold#coreRegions)),
            noiseRegion = ratio(noiseRegions, Vector.length(predictions)),
            weightedCoreCoverage = weighted,
            contextEfficiency = ratio(Set.size(Set.intersection(predictedLines, usefulLines)), Set.size(predictedLines)),
            ndcg100 = ndcg(gains, 100),
            ndcg300 = ndcg(gains, 300),
            ndcg500 = ndcg(gains, 500),
            recall100 = recallAt(predictions, coreLines, counts, 100),
            recall300 = recallAt(predictions, coreLines, counts, 300),
            recall500 = recallAt(predictions, coreLines, counts, 500),
            firstUsefulHit = firstUseful(predictions, coreLines, counts)
        }
    }

    def lineF1(
        predictions: Vector[SourceRegion],
        gold: Gold,
        sources: Vector[Repository.Source]
    ): Float64 = {
        let counts = lineCounts(sources, gold);
        let predictedLines = lines(predictions, counts);
        let coreLines = lines(gold#coreRegions, counts);
        let overlap = Set.size(Set.intersection(predictedLines, coreLines));
        let precision = ratio(overlap, Set.size(predictedLines));
        let recall = ratio(overlap, Set.size(coreLines));
        if (precision + recall == 0.0) 0.0
        else 2.0 * precision * recall / (precision + recall)
    }

    def lineCounts(sources: Vector[Repository.Source], gold: Gold): Map[String, Int32] = {
        let sourceCounts = Vector.map(source -> (source#path, sourceLineCount(source#content)), sources)
            |> Vector.toMap;
        Vector.foldLeft((counts, span0) ->
            Map.insertWith(Int32.max, span0#path, Int32.max(1, span0#end), counts),
            sourceCounts,
            gold#coreRegions ++ gold#optionalRegions)
    }

    def sourceLineCount(source: String): Int32 = {
        let bytes = String.toBytes(source);
        let length = Vector.length(bytes);
        if (length == 0) 0
        else countLineBreaks(bytes, 0, 0) +
            (if (Int8.toInt32(Vector.get(length - 1, bytes)) == 10) 0 else 1)
    }

    def countLineBreaks(bytes: Vector[Int8], index: Int32, count: Int32): Int32 =
        if (index >= Vector.length(bytes)) count
        else countLineBreaks(bytes, index + 1,
            if (Int8.toInt32(Vector.get(index, bytes)) == 10) count + 1 else count)

    def resolve(span: SourceRegion, counts: Map[String, Int32]): Option[(Int32, Int32)] =
        match Map.get(span#path, counts) {
            case None => None
            case Some(total) => {
                let needsTotal = span#end == -1 or span#start < 0;
                if (needsTotal and total < 1) None
                else if (needsTotal) {
                    let end = if (span#end == -1) total else span#end;
                    let start = if (span#start < 0) total + span#start + 1 else span#start;
                    Some((Int32.max(1, Int32.min(start, total)), Int32.max(1, Int32.min(end, total))))
                } else if (span#end < 1) None
                else Some((Int32.max(1, span#start), span#end))
            }
        }

    def lines(
        regions: Vector[SourceRegion],
        counts: Map[String, Int32]
    ): Set[(String, Int32)] =
        Vector.foldLeft((result, span) -> match resolve(span, counts) {
            case None => result
            case Some((start, end)) => addLines(span#path, start, end, result)
        }, Set.empty(), regions)

    def addLines(path: String, current: Int32, end: Int32, result: Set[(String, Int32)]): Set[(String, Int32)] =
        if (current > end) result
        else addLines(path, current + 1, end, Set.insert((path, current), result))

    def overlaps(
        left: SourceRegion,
        right: SourceRegion,
        counts: Map[String, Int32]
    ): Bool =
        if (left#path != right#path) false
        else match (resolve(left, counts), resolve(right, counts)) {
            case (Some((ls, le)), Some((rs, re))) => ls <= re and rs <= le
            case _ => false
        }

    def weightedCoverage(
        regions: Vector[SourceRegion],
        mainFiles: Set[String],
        predictedLines: Set[(String, Int32)],
        counts: Map[String, Int32]
    ): Float64 = {
        let (weighted, total) = Vector.foldLeft((acc, span0) -> match (acc, resolve(span0, counts)) {
            case ((sum0, total0), None) => (sum0, total0)
            case ((sum0, total0), Some((start, end))) => {
                let truth = addLines(span0#path, start, end, Set.empty());
                let coverage = ratio(Set.size(Set.intersection(predictedLines, truth)), Set.size(truth));
                let weight = if (Set.memberOf(span0#path, mainFiles)) 3.0 else 2.0;
                (sum0 + weight * coverage, total0 + weight)
            }
        }, (0.0, 0.0), regions);
        if (total == 0.0) 0.0 else weighted / total
    }

    def regionGain(
        ordinal: Int32,
        span0: SourceRegion,
        coreLines: Set[(String, Int32)],
        mainFiles: Set[String],
        counts: Map[String, Int32]
    ): Gain = match resolve(span0, counts) {
        case None => {gain = 0.0, lines = 0, ordinal = ordinal}
        case Some((start, end)) => {
            let weight = if (Set.memberOf(span0#path, mainFiles)) 1.5 else 1.0;
            let covered = Set.size(Set.intersection(
                addLines(span0#path, start, end, Set.empty()), coreLines));
            {gain = Int32.toFloat64(covered) * weight, lines = end - start + 1, ordinal = ordinal}
        }
    }

    def ndcg(gains: Vector[Gain], budget: Int32): Float64 = {
        let actual = dcg(gains, budget, 0, 0, 0.0);
        let ideal = Vector.sortBy(item ->
            (-(item#gain / Int32.toFloat64(Int32.max(item#lines, 1))), item#ordinal), gains);
        let best = dcg(ideal, budget, 0, 0, 0.0);
        if (best <= 0.0) 0.0 else Float64.min(actual / best, 1.0)
    }

    def dcg(
        gains: Vector[Gain],
        budget: Int32,
        index: Int32,
        cumulative: Int32,
        total: Float64
    ): Float64 =
        if (index >= Vector.length(gains)) total
        else {
            let item = Vector.get(index, gains);
            let next = cumulative + item#lines;
            if (next > budget and index > 0) total
            else dcg(gains, budget, index + 1, next,
                total + item#gain / discount(index))
        }

    /// Predictions contain at most five regions, so the official log2 rank
    /// discounts are kept exact without adding an effectful JVM Math call.
    def discount(index: Int32): Float64 = match index {
        case 0 => 1.0
        case 1 => 1.584962500721156
        case 2 => 2.0
        case 3 => 2.321928094887362
        case _ => 2.584962500721156
    }

    def recallAt(
        predictions: Vector[SourceRegion],
        coreLines: Set[(String, Int32)],
        counts: Map[String, Int32],
        budget: Int32
    ): Float64 = {
        let result = budgetRegions(predictions, coreLines, counts, budget, 0,
            {covered = Set.empty(), consumed = 0});
        ratio(Set.size(result#covered), Set.size(coreLines))
    }

    def budgetRegions(
        predictions: Vector[SourceRegion],
        coreLines: Set[(String, Int32)],
        counts: Map[String, Int32],
        budget: Int32,
        index: Int32,
        result: BudgetCoverage
    ): BudgetCoverage =
        if (index >= Vector.length(predictions) or result#consumed >= budget) result
        else match resolve(Vector.get(index, predictions), counts) {
            case None => budgetRegions(predictions, coreLines, counts, budget, index + 1, result)
            case Some((start, end)) => {
                let next = budgetRange(Vector.get(index, predictions)#path, start, end,
                    coreLines, budget, result);
                budgetRegions(predictions, coreLines, counts, budget, index + 1, next)
            }
        }

    def budgetRange(
        path: String,
        current: Int32,
        end: Int32,
        coreLines: Set[(String, Int32)],
        budget: Int32,
        result: BudgetCoverage
    ): BudgetCoverage =
        if (current > end or result#consumed >= budget) result
        else {
            let key = (path, current);
            budgetRange(path, current + 1, end, coreLines, budget, {
                covered = if (Set.memberOf(key, coreLines)) Set.insert(key, result#covered) else result#covered,
                consumed = result#consumed + 1
            })
        }

    def firstUseful(
        predictions: Vector[SourceRegion],
        coreLines: Set[(String, Int32)],
        counts: Map[String, Int32]
    ): Float64 = firstUsefulFrom(predictions, coreLines, counts, 0)

    def firstUsefulFrom(
        predictions: Vector[SourceRegion],
        coreLines: Set[(String, Int32)],
        counts: Map[String, Int32],
        index: Int32
    ): Float64 =
        if (index >= Vector.length(predictions) or Set.isEmpty(coreLines)) 0.0
        else match resolve(Vector.get(index, predictions), counts) {
            case None => firstUsefulFrom(predictions, coreLines, counts, index + 1)
            case Some((start, end)) => {
                let span0 = Vector.get(index, predictions);
                if (Set.exists(match (path, line) ->
                    path == span0#path and start <= line and line <= end, coreLines))
                    1.0 - Int32.toFloat64(index) / Int32.toFloat64(Vector.length(predictions))
                else firstUsefulFrom(predictions, coreLines, counts, index + 1)
            }
        }

    def ratio(numerator: Int32, denominator: Int32): Float64 =
        if (denominator == 0) 0.0 else Int32.toFloat64(numerator) / Int32.toFloat64(denominator)

    def reorder(
        prior: Vector[Localization.Ranked],
        identities: Vector[String]
    ): Result[Error, Vector[Localization.Ranked]] = {
        let byIdentity = Vector.map(item -> (item#identity, item), prior) |> Vector.toMap;
        Vector.traverse(identity -> Map.get(identity, byIdentity)
            |> Option.toOk(Error.MissingDocument(identity)), identities)
    }

    def decodeGold(payload: String): Result[Error, Vector[Gold]] = match Json.parse(payload) {
        case Err(error) => Err(Error.Wire(ToString.toString(error)))
        case Ok(JObject(fields)) => forM (
            version <- intField("version", fields);
            _ <- if (version == 1) Ok(()) else Err(Error.Wire("unsupported gold version"));
            values <- arrayField("cases", fields);
            cases <- Vector.traverse(decodeGoldRow, values)
        ) yield cases
        case Ok(_) => Err(Error.Wire("gold fixture must be an object"))
    }

    def decodeGoldRow(value: Json): Result[Error, Gold] = match value {
        case JObject(fields) => forM (
            instanceId <- stringField("instance_id", fields);
            coreFiles <- stringVectorField("core_files", fields);
            values <- arrayField("core_regions", fields);
            coreRegions <- Vector.traverse(decodeRegion, values);
            optionalFiles <- stringVectorField("optional_files", fields);
            optionalValues <- arrayField("optional_regions", fields);
            optionalRegions <- Vector.traverse(decodeRegion, optionalValues);
            mainFiles <- stringVectorField("main_files", fields)
        ) yield {
            instanceId = instanceId,
            coreFiles = Vector.toSet(coreFiles),
            coreRegions = coreRegions,
            optionalFiles = Vector.toSet(optionalFiles),
            optionalRegions = optionalRegions,
            mainFiles = Vector.toSet(mainFiles)
        }
        case _ => Err(Error.Wire("gold case must be an object"))
    }

    def decodeRegion(value: Json): Result[Error, SourceRegion] = match value {
        case JObject(fields) => forM (
            path <- stringField("path", fields);
            start <- intField("start", fields);
            end <- intField("end", fields)
        ) yield {path = path, start = Int32.max(1, start), end = end}
        case _ => Err(Error.Wire("region must be an object"))
    }

    def decodeOutcome(instanceId: String, payload: String): Result[Error, OutcomeFixture] =
        match Json.parse(payload) {
            case Err(error) => Err(Error.Wire(ToString.toString(error)))
            case Ok(JObject(fields)) => forM (
                values <- arrayField("cases", fields);
                row <- Vector.find(value -> caseId(value) == Some(instanceId), values)
                    |> Option.toOk(Error.MissingOutcome(instanceId));
                result <- decodeOutcomeRow(row)
            ) yield result
            case Ok(_) => Err(Error.Wire("outcomes must be an object"))
        }

    def decodeFrozen(instanceId: String, payload: String): Result[Error, FrozenReference] =
        match Json.parse(payload) {
            case Err(error) => Err(Error.Wire(ToString.toString(error)))
            case Ok(JObject(fields)) => forM (
                values <- arrayField("cases", fields);
                row <- Vector.find(value -> caseId(value) == Some(instanceId), values)
                    |> Option.toOk(Error.MissingOutcome(instanceId));
                frozen <- decodeFrozenRow(row)
            ) yield frozen
            case Ok(_) => Err(Error.Wire("frozen evaluation must be an object"))
        }

    def decodeFrozenRow(value: Json): Result[Error, FrozenReference] = match value {
        case JObject(fields) => forM (
            oraclePath <- stringField("oracle_path", fields);
            priorValue <- field("prior", fields);
            prior <- decodeCondition(priorValue);
            oracleValue <- field("structural_oracle", fields);
            oracle <- decodeCondition(oracleValue)
        ) yield {
            prior = fst(prior),
            oracle = fst(oracle),
            oraclePath = oraclePath,
            priorRegions = snd(prior),
            oracleRegions = snd(oracle)
        }
        case _ => Err(Error.Wire("frozen evaluation case must be an object"))
    }

    def decodeCondition(value: Json): Result[Error, (Score, Vector[SourceRegion])] = match value {
        case JObject(fields) => forM (
            metricValue <- field("metrics", fields);
            metrics <- decodeScore(metricValue);
            regionValues <- arrayField("regions", fields);
            regions <- Vector.traverse(decodeRegion, regionValues)
        ) yield (metrics, regions)
        case _ => Err(Error.Wire("evaluation condition must be an object"))
    }

    def decodeScore(value: Json): Result[Error, Score] = match value {
        case JObject(fields) => forM (
            precision <- floatField("precision", fields);
            recall <- floatField("recall", fields);
            f1 <- floatField("f1_score", fields);
            hitFile <- floatField("hit_file_rate", fields);
            noiseFile <- floatField("noise_file_rate", fields);
            hitRegion <- floatField("hit_region_rate", fields);
            noiseRegion <- floatField("noise_region_rate", fields);
            weighted <- floatField("weighted_core_coverage", fields);
            context <- floatField("context_efficiency", fields);
            ndcg100 <- floatField("ndcg_at_100", fields);
            ndcg300 <- floatField("ndcg_at_300", fields);
            ndcg500 <- floatField("ndcg_at_500", fields);
            recall100 <- floatField("recall_at_100", fields);
            recall300 <- floatField("recall_at_300", fields);
            recall500 <- floatField("recall_at_500", fields);
            first <- floatField("first_useful_hit", fields)
        ) yield {
            precision = precision, recall = recall, f1 = f1,
            hitFile = hitFile, noiseFile = noiseFile,
            hitRegion = hitRegion, noiseRegion = noiseRegion,
            weightedCoreCoverage = weighted, contextEfficiency = context,
            ndcg100 = ndcg100, ndcg300 = ndcg300, ndcg500 = ndcg500,
            recall100 = recall100, recall300 = recall300, recall500 = recall500,
            firstUsefulHit = first
        }
        case _ => Err(Error.Wire("evaluation metrics must be an object"))
    }

    def decodeOutcomeRow(value: Json): Result[Error, OutcomeFixture] = match value {
        case JObject(fields) => forM (
            path <- stringVectorField("path", fields);
            ranking <- stringVectorField("ranking", fields);
            decisionValues <- arrayField("decisions", fields);
            decisions <- Vector.traverse(decodeDecisionFixture, decisionValues)
        ) yield {path = path, ranking = ranking, decisions = decisions}
        case _ => Err(Error.Wire("outcome case must be an object"))
    }

    def decodeDecisionFixture(value: Json): Result[Error, DecisionFixture] = match value {
        case JObject(fields) => forM (
            choice <- stringField("choice", fields);
            confidence <- floatField("confidence", fields);
            probabilitiesValue <- field("probabilities", fields);
            probabilities <- decodeProbabilityMap(probabilitiesValue)
        ) yield {choice = choice, probabilities = probabilities, confidence = confidence}
        case _ => Err(Error.Wire("decision fixture must be an object"))
    }

    def decodeProbabilityMap(value: Json): Result[Error, Map[String, Float64]] = match value {
        case JObject(fields) => Map.toVector(fields)
            |> Vector.traverse(match (key, raw) -> FromJson.fromJson(raw)
                |> Result.map(number -> (key, number))
                |> Result.mapErr(error -> Error.Wire("probability ${key}: ${ToString.toString(error)}")))
            |> Result.map(Vector.toMap)
        case _ => Err(Error.Wire("probabilities must be an object"))
    }

    def caseId(value: Json): Option[String] = match value {
        case JObject(fields) => match Map.get("instance_id", fields) {
            case Some(JString(value0)) => Some(value0)
            case _ => None
        }
        case _ => None
    }

    def read(path: String): Result[Error, String] \ FileSystem =
        FileSystem.read(path) |> Result.mapErr(error -> Error.File(ToString.toString(error)))

    def field(name: String, fields: Map[String, Json]): Result[Error, Json] =
        Map.get(name, fields) |> Option.toOk(Error.Wire("missing JSON field: ${name}"))

    def stringField(name: String, fields: Map[String, Json]): Result[Error, String] = match field(name, fields) {
        case Err(error) => Err(error)
        case Ok(JString(value)) => Ok(value)
        case Ok(_) => Err(Error.Wire("${name}: expected string"))
    }

    def intField(name: String, fields: Map[String, Json]): Result[Error, Int32] =
        field(name, fields) |> Result.flatMap(value -> FromJson.fromJson(value)
            |> Result.mapErr(error -> Error.Wire("${name}: ${ToString.toString(error)}")))

    def floatField(name: String, fields: Map[String, Json]): Result[Error, Float64] =
        field(name, fields) |> Result.flatMap(value -> FromJson.fromJson(value)
            |> Result.mapErr(error -> Error.Wire("${name}: ${ToString.toString(error)}")))

    def arrayField(name: String, fields: Map[String, Json]): Result[Error, Vector[Json]] = match field(name, fields) {
        case Err(error) => Err(error)
        case Ok(JArray(values)) => Ok(values)
        case Ok(_) => Err(Error.Wire("${name}: expected array"))
    }

    def stringVectorField(name: String, fields: Map[String, Json]): Result[Error, Vector[String]] =
        field(name, fields) |> Result.flatMap(value -> FromJson.fromJson(value)
            |> Result.mapErr(error -> Error.Wire("${name}: ${ToString.toString(error)}")))

    def pathText(path: Vector[Radii.Atom]): String =
        if (Vector.isEmpty(path)) "root"
        else Vector.map(atom -> Decide.actionKey(Decide.Action.Follow(atom)), path)
            |> Vector.toList |> List.intersperse(">>") |> List.fold

    def printRow(row: Row): Unit \ IO =
        println("JEV_SCORE\t${row#instanceId}" +
            "\tprior_f1=${row#prior#f1}\tjev_f1=${row#jev#f1}\toracle_f1=${row#oracle#f1}" +
            "\tprior_hit=${row#prior#hitFile}\tjev_hit=${row#jev#hitFile}\toracle_hit=${row#oracle#hitFile}" +
            "\toracle_path=${row#oraclePath}")

    def printAggregate(rows: Vector[Row]): Unit \ IO = {
        let count = Int32.toFloat64(Vector.length(rows));
        println("JEV_ORACLE_AGGREGATE\tcases=${Vector.length(rows)}" +
            "\tprior_f1=${sum(rows, row -> row#prior#f1) / count}" +
            "\tjev_f1=${sum(rows, row -> row#jev#f1) / count}" +
            "\toracle_f1=${sum(rows, row -> row#oracle#f1) / count}" +
            "\tprior_recall=${sum(rows, row -> row#prior#recall) / count}" +
            "\tjev_recall=${sum(rows, row -> row#jev#recall) / count}" +
            "\toracle_recall=${sum(rows, row -> row#oracle#recall) / count}" +
            "\tprior_hit=${sum(rows, row -> row#prior#hitFile) / count}" +
            "\tjev_hit=${sum(rows, row -> row#jev#hitFile) / count}" +
            "\toracle_hit=${sum(rows, row -> row#oracle#hitFile) / count}");
        printRepository("axios/axios", rows);
        printRepository("immutable-js/immutable-js", rows);
        printRepository("preactjs/preact", rows)
    }

    def printRepository(repository: String, rows: Vector[Row]): Unit \ IO = {
        let selected = Vector.filter(row -> row#repository == repository, rows);
        let count = Int32.toFloat64(Vector.length(selected));
        let deltas: Vector[Float64] = Vector.map(f1Delta, selected);
        println("JEV_REPOSITORY\t${repository}\tcases=${Vector.length(selected)}" +
            "\tprior_f1_mean=${sum(selected, row -> row#prior#f1) / count}" +
            "\tjev_f1_mean=${sum(selected, row -> row#jev#f1) / count}" +
            "\toracle_f1_mean=${sum(selected, row -> row#oracle#f1) / count}" +
            "\tdelta_mean=${sumFloats(deltas) / count}" +
            "\tdelta_median=${median(deltas)}" +
            "\timproved=${Vector.count(value -> value > 0.0, deltas)}" +
            "\ttied=${Vector.count(value -> value == 0.0, deltas)}" +
            "\tworsened=${Vector.count(value -> value < 0.0, deltas)}")
    }

    def f1Delta(row: Row): Float64 = row#jev#f1 - row#prior#f1

    def sumFloats(values: Vector[Float64]): Float64 =
        Vector.foldLeft((total, value) -> total + value, 0.0, values)

    def median(values: Vector[Float64]): Float64 = {
        let sorted = Vector.sort(values);
        let length = Vector.length(sorted);
        if (length == 0) 0.0
        else if (Int32.remainder(length, 2) == 1) Vector.get(length / 2, sorted)
        else (Vector.get(length / 2 - 1, sorted) + Vector.get(length / 2, sorted)) / 2.0
    }

    /// Differential gate against the pinned official Python evaluator over all
    /// 30 PRIOR/JEV rows. A formula drift aborts before oracle rows are frozen.
    def validateOfficialParity(rows: Vector[Row]): Result[Error, Unit] = {
        let checks = Vector#{
            ("prior.precision", mean(rows, row -> row#prior#precision), 0.2868616539847101),
            ("prior.recall", mean(rows, row -> row#prior#recall), 0.07518671479347003),
            ("prior.f1", mean(rows, row -> row#prior#f1), 0.05849332212092597),
            ("prior.hit_file", mean(rows, row -> row#prior#hitFile), 0.22777777777777777),
            ("prior.noise_file", mean(rows, row -> row#prior#noiseFile), 0.59),
            ("prior.hit_region", mean(rows, row -> row#prior#hitRegion), 0.1522222222222222),
            ("prior.noise_region", mean(rows, row -> row#prior#noiseRegion), 0.6266666666666667),
            ("prior.weighted", mean(rows, row -> row#prior#weightedCoreCoverage), 0.052783634822549656),
            ("prior.context", mean(rows, row -> row#prior#contextEfficiency), 0.4079900327894584),
            ("prior.ndcg100", mean(rows, row -> row#prior#ndcg100), 0.3503858635975746),
            ("prior.ndcg300", mean(rows, row -> row#prior#ndcg300), 0.38371919693090795),
            ("prior.ndcg500", mean(rows, row -> row#prior#ndcg500), 0.38371919693090795),
            ("prior.recall100", mean(rows, row -> row#prior#recall100), 0.02354352230520712),
            ("prior.recall300", mean(rows, row -> row#prior#recall300), 0.07518671479347003),
            ("prior.recall500", mean(rows, row -> row#prior#recall500), 0.07518671479347003),
            ("prior.first", mean(rows, row -> row#prior#firstUsefulHit), 0.41333333333333333),
            ("jev.precision", mean(rows, row -> row#jev#precision), 0.19619917112089083),
            ("jev.recall", mean(rows, row -> row#jev#recall), 0.09346561045752329),
            ("jev.f1", mean(rows, row -> row#jev#f1), 0.07888737803511471),
            ("jev.hit_file", mean(rows, row -> row#jev#hitFile), 0.20555555555555557),
            ("jev.noise_file", mean(rows, row -> row#jev#noiseFile), 0.6433333333333333),
            ("jev.hit_region", mean(rows, row -> row#jev#hitRegion), 0.18222222222222223),
            ("jev.noise_region", mean(rows, row -> row#jev#noiseRegion), 0.7466666666666666),
            ("jev.weighted", mean(rows, row -> row#jev#weightedCoreCoverage), 0.07348163629076296),
            ("jev.context", mean(rows, row -> row#jev#contextEfficiency), 0.2677421799475883),
            ("jev.ndcg100", mean(rows, row -> row#jev#ndcg100), 0.30687656583169043),
            ("jev.ndcg300", mean(rows, row -> row#jev#ndcg300), 0.34020989916502375),
            ("jev.ndcg500", mean(rows, row -> row#jev#ndcg500), 0.3822718827364542),
            ("jev.recall100", mean(rows, row -> row#jev#recall100), 0.02407092343205156),
            ("jev.recall300", mean(rows, row -> row#jev#recall300), 0.09280771572068118),
            ("jev.recall500", mean(rows, row -> row#jev#recall500), 0.09346561045752329),
            ("jev.first", mean(rows, row -> row#jev#firstUsefulHit), 0.41333333333333333)
        };
        match Vector.find(match (_, actual, expected) -> Float64.abs(actual - expected) > 0.0000000001, checks) {
            case None => Ok(())
            case Some((name, actual, expected)) =>
                Err(Error.OfficialParity("${name}: actual=${actual}, expected=${expected}"))
        }
    }

    def writeResults(rows: Vector[Row]): Result[Error, Unit] \ FileSystem = {
        writeResultsAt(rows, ".attune/jev-localization-v1/evaluation.json", Decide.protocol())
    }

    def writeResultsAt(
        rows: Vector[Row],
        outputPath: String,
        resultProtocol: String
    ): Result[Error, Unit] \ FileSystem = {
        let payload = Json.toCompactString(JObject(Map#{
            "version" => ToJson.toJson(1),
            "benchmark_revision" => JString("bdb0ae45d7c337d9e1dc3ebfe2a0af6bc7c1fbd9"),
            "evaluator_revision" => JString("5602f031f2d9562d0a805f83402b536e831a5a11"),
            "protocol" => JString(resultProtocol),
            "model" => JString(Decide.model()),
            "top_k" => ToJson.toJson(5),
            "cases" => JArray(Vector.map(rowJson, rows))
        }));
        let written = run {
            FileSystem.write(str = payload, outputPath)
        } with FileSystem.withMkParentDirs
          with FileSystem.withAtomicWrite;
        Result.mapErr(error -> Error.File(ToString.toString(error)), written)
    }

    def rowJson(row: Row): Json = JObject(Map#{
        "instance_id" => JString(row#instanceId),
        "repository" => JString(row#repository),
        "oracle_path" => JString(row#oraclePath),
        "prior" => conditionJson(row#prior, row#priorRegions),
        "jev" => conditionJson(row#jev, row#jevRegions),
        "structural_oracle" => conditionJson(row#oracle, row#oracleRegions)
    })

    def conditionJson(score0: Score, regions: Vector[SourceRegion]): Json = JObject(Map#{
        "metrics" => scoreJson(score0),
        "regions" => JArray(Vector.map(regionJson, regions))
    })

    def regionJson(span0: SourceRegion): Json = JObject(Map#{
        "path" => JString(span0#path),
        "start" => ToJson.toJson(span0#start),
        "end" => ToJson.toJson(span0#end)
    })

    def scoreJson(score0: Score): Json = JObject(Map#{
        "precision" => ToJson.toJson(score0#precision),
        "recall" => ToJson.toJson(score0#recall),
        "f1_score" => ToJson.toJson(score0#f1),
        "hit_file_rate" => ToJson.toJson(score0#hitFile),
        "noise_file_rate" => ToJson.toJson(score0#noiseFile),
        "hit_region_rate" => ToJson.toJson(score0#hitRegion),
        "noise_region_rate" => ToJson.toJson(score0#noiseRegion),
        "weighted_core_coverage" => ToJson.toJson(score0#weightedCoreCoverage),
        "context_efficiency" => ToJson.toJson(score0#contextEfficiency),
        "ndcg_at_100" => ToJson.toJson(score0#ndcg100),
        "ndcg_at_300" => ToJson.toJson(score0#ndcg300),
        "ndcg_at_500" => ToJson.toJson(score0#ndcg500),
        "recall_at_100" => ToJson.toJson(score0#recall100),
        "recall_at_300" => ToJson.toJson(score0#recall300),
        "recall_at_500" => ToJson.toJson(score0#recall500),
        "first_useful_hit" => ToJson.toJson(score0#firstUsefulHit)
    })

    def mean(rows: Vector[Row], f: Row -> Float64): Float64 =
        sum(rows, f) / Int32.toFloat64(Vector.length(rows))

    def sum(rows: Vector[Row], f: Row -> Float64): Float64 =
        Vector.foldLeft((total, row) -> total + f(row), 0.0, rows)
}
