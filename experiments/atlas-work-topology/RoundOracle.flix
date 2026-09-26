/// The signature-preservation oracle over a candidate revision
/// (PREREGISTRATION.md §10 O1-O4, O6; VAL-HC1-002).
///
/// The candidate's admitted basis is the frozen control evidence re-expressed
/// at candidate paths (`RoundIdentity.mapping`), never a re-acquisition (§11,
/// S1). The depth-response curve is then re-derived independently over that
/// candidate basis by the frozen `Atlas.Signature` machinery, so a wrong or
/// non-bijective identity translation changes the world and fails the oracle;
/// the comparison itself is on the §9 logical-identity layer.
mod RoundOracle {
    pub def protocol(): String = "attuneflix-round-oracle-v1"

    /// The frozen grammar's cumulative route count per domain at depth 7.
    pub def grammarRoutes(): Vector[(String, Int32)] =
        Vector#{
            ("file", Vector.length(Atlas.programsFrom(Radii.Domain.File, 7))),
            ("symbol", Vector.length(Atlas.programsFrom(Radii.Domain.Symbol, 7)))
        }

    /// The per-depth grammar level sizes (3, 9, 27, ... through depth 7).
    pub def grammarDepths(): Vector[(Int32, Int32)] =
        Vector.map(depth -> (depth, Vector.length(Atlas.programsFrom(Radii.Domain.File, depth))), Vector.range(1, 8))

    pub type alias Comparison = {
        metric    = String,
        control   = Float64,
        candidate = Float64,
        delta     = Float64,
        threshold = Float64,
        ok        = Bool
    }

    /// The candidate's admitted basis: the frozen evidence at candidate paths.
    /// Every basis source and fact must carry a surviving logical identity; an
    /// unmapped row is a construction failure, never a silent drop.
    pub def candidateWorld(
        round0: RoundIdentity.Round,
        controlSources: Vector[AcquisitionFacts.Source],
        controlFacts: Vector[AcquisitionFacts.FactRow]
    ): Repository.World = {
        let mapping = RoundIdentity.mapping(round0);
        let sources = Experiment.require(Vector.traverse(source -> match Map.get(source#path, mapping) {
            case None => Err("round basis source has no logical identity: ${source#path}")
            case Some(path) => Ok({path = path, sha256 = source#sha256, bytes = source#bytes, language = source#language})
        }, controlSources)) |> Vector.sortBy(source -> source#path);
        let facts = Experiment.require(Vector.traverse(fact -> match Map.get(fact#path, mapping) {
            case None => Err("round basis fact has no logical identity: ${fact#path}")
            case Some(path) => Ok({
                path = path, sourceSha256 = fact#sourceSha256, language = fact#language, program = fact#program,
                kind = fact#kind, startByte = fact#startByte, endByte = fact#endByte, value = fact#value
            })
        }, controlFacts));
        Experiment.require(AcquisitionFacts.world(sources, facts))
    }

    pub def landmarks(world: Repository.World): ControlSignature.Landmarks \ IO =
        ControlSignature.landmarks(world, ControlSignature.signatures(world))

    /// The same landmark definition over an explicit (already translated) seed
    /// panel, so a candidate is measured on the §9 logical-identity seeds
    /// rather than on a path-hashed panel a file move would perturb.
    pub def landmarksWith(world: Repository.World, seeds: Vector[Atlas.Signature.Seed]): ControlSignature.Landmarks =
        ControlSignature.landmarks(world, Vector.map(seed ->
            (seed, Experiment.require(Atlas.Signature.compute(world, seed#state, ControlSignature.maxDepth()))), seeds))

    /// The frozen control seed panel carried into the candidate world by the
    /// logical-identity translation. Every control seed has a candidate
    /// successor (drops are reported by the identity map), so the candidate
    /// panel is the same set of logical entities as control's.
    pub def translatedSeeds(
        world: Repository.World,
        candidate: Repository.World,
        mapping: Map[String, String]
    ): Vector[Atlas.Signature.Seed] \ IO = {
        let seeds = Atlas.Signature.seeds(world);
        let files = indexOfPaths(candidate#files);
        let symbols = indexOfSymbols(candidate#symbols);
        Vector.filterMap(seed -> translate(seed, world, mapping, files, symbols), seeds)
    }

    def indexOfPaths(paths: Vector[String]): Map[String, Int32] =
        Vector.mapWithIndex((index, path) -> (path, index), paths) |> Vector.toMap

    def indexOfSymbols(symbols: Vector[Repository.Symbol]): Map[String, Int32] =
        Vector.mapWithIndex((index, symbol) -> (symbolKey(symbol), index), symbols) |> Vector.toMap

    def symbolKey(symbol: Repository.Symbol): String =
        "${symbol#path}\u0000${symbol#name}\u0000${symbol#startByte}\u0000${symbol#endByte}"

    def translate(
        seed: Atlas.Signature.Seed,
        world: Repository.World,
        mapping: Map[String, String],
        files: Map[String, Int32],
        symbols: Map[String, Int32]
    ): Option[Atlas.Signature.Seed] = match seed#state {
        case Atlas.State.Files(ids) => {
            let paths = Vector.map(id -> {
                let Repository.Structure.FileId.FileId(index) = id;
                RoundTopology.current(mapping, Vector.get(index, world#files))
            }, Set.toVector(ids));
            match collect(paths, files) {
                case None => None
                case Some(indices) => Some({domain = seed#domain, identity = seed#identity, ordinal = seed#ordinal,
                    state = Atlas.State.Files(Set.map(index -> Repository.Structure.FileId.FileId(index),
                        Vector.toSet(indices)))})
            }
        }
        case Atlas.State.Symbols(ids) => {
            let keys = Vector.map(id -> {
                let Repository.Structure.SymbolId.SymbolId(index) = id;
                let symbol = Vector.get(index, world#symbols);
                symbolKey({path = RoundTopology.current(mapping, symbol#path), name = symbol#name,
                    startByte = symbol#startByte, endByte = symbol#endByte})
            }, Set.toVector(ids));
            match collect(keys, symbols) {
                case None => None
                case Some(indices) => Some({domain = seed#domain, identity = seed#identity, ordinal = seed#ordinal,
                    state = Atlas.State.Symbols(Set.map(index -> Repository.Structure.SymbolId.SymbolId(index),
                        Vector.toSet(indices)))})
            }
        }
    }

    /// Every key must have a unique target; a missing key makes the seed
    /// untranslatable and is reported by omission, never invented.
    def collect(keys: Vector[String], table: Map[String, Int32]): Option[Vector[Int32]] =
        Vector.foldLeft((state, key) -> match state {
            case None => None
            case Some(acc) => match Map.get(key, table) {
                case None => None
                case Some(found) => Some(Vector.append(acc, Vector#{found}))
            }
        }, Some(Vector.empty()), keys)

    /// O2: mixing landmarks. `none` (depth 8) must match `none`; otherwise the
    /// drift must be at most one depth.
    pub def landmarkComparisons(
        control: ControlSignature.Landmarks,
        candidate: ControlSignature.Landmarks
    ): Vector[Comparison] =
        Vector#{
            landmark("D50", Int32.toFloat64(control#d50), Int32.toFloat64(candidate#d50)),
            landmark("D80", Int32.toFloat64(control#d80), Int32.toFloat64(candidate#d80)),
            landmark("D90", Int32.toFloat64(control#d90), Int32.toFloat64(candidate#d90)),
            landmark("D95", Int32.toFloat64(control#d95), Int32.toFloat64(candidate#d95))
        }

    /// O3: depth-7 reach may not fall by more than 5 percentage points.
    pub def reachComparison(control: ControlSignature.Landmarks, candidate: ControlSignature.Landmarks): Comparison = {
        let drop = control#depth7Reach - candidate#depth7Reach;
        {
            metric = "depth7_reach",
            control = control#depth7Reach,
            candidate = candidate#depth7Reach,
            delta = candidate#depth7Reach - control#depth7Reach,
            threshold = 0.05,
            ok = drop <= 0.05
        }
    }

    /// The seven mean-coverage depths for control and candidate.
    pub def reachCurve(
        control: ControlSignature.Landmarks,
        candidate: ControlSignature.Landmarks
    ): Vector[(Int32, Float64, Float64)] =
        Vector.mapWithIndex((index, value) -> (index + 1, value, Vector.get(index, candidate#meanCoverage)),
            control#meanCoverage)

    /// O6: identity continuity and the O4 semantic-source check.
    pub def identityVerdicts(round0: RoundIdentity.Round): Vector[(String, Bool)] =
        Vector#{
            ("O6a: every control identity maps to at most one current path", Vector.isEmpty(round0#collisions)),
            ("O6b: no control identity was silently dropped", Vector.isEmpty(round0#dropped)),
            ("O6c: control logical ids are unique",
                (Vector.toSet(Vector.map(entry -> entry#logicalId, round0#entries)) |> Set.size)
                    == Vector.length(round0#entries)),
            ("O4: no admitted production source (`src/`) changed content",
                Vector.isEmpty(productionDrift(round0)))
        }

    /// O4 evidence: a `src/` basis file whose bytes changed at the same path.
    pub def productionDrift(round0: RoundIdentity.Round): Vector[String] =
        Vector.filterMap(entry ->
            if (entry#movement == "modified" and String.startsWith(prefix = "src/", entry#controlPath))
                Some(entry#controlPath)
            else None, round0#entries)

    /// Every basis file whose bytes changed at a surviving path (reported, not
    /// hidden; law/build wiring changes are the round's own intervention).
    pub def modifiedPaths(round0: RoundIdentity.Round): Vector[String] =
        Vector.filterMap(entry ->
            if (entry#movement == "modified") Some(entry#controlPath) else None, round0#entries)

    /// The frozen basis edges carried into the candidate world by the §9
    /// logical-identity translation (no re-admission). This is the comparison
    /// basis §6.2 binds: identity, not path, so a move cannot perturb it.
    pub def translatedEdgePaths(world: Repository.World, mapping: Map[String, String]): Set[(String, String)] =
        Vector.toSet(Vector.filterMap(match (source, target) ->
            match (Map.get(source, mapping), Map.get(target, mapping)) {
                case (Some(currentSource), Some(currentTarget)) => Some((currentSource, currentTarget))
                case _ => None
            }, ControlTopology.edgePaths(world)))

    /// The frozen basis edges that re-admission at the candidate paths does not
    /// reproduce, and the candidate edges it predicts instead. Reported
    /// evidence, never a silent difference: Flix module imports resolve by path
    /// suffix, so a move can change which declaration an unchanged import fact
    /// reaches. Sorted for byte-stable rendering.
    pub def basisEdgeDrift(
        candidate: Repository.World,
        translated: Set[(String, String)]
    ): (Vector[(String, String)], Vector[(String, String)]) = {
        let admitted = Vector.toSet(ControlTopology.edgePaths(candidate));
        let lost = Vector.filter(match (source, target) -> not Set.memberOf((source, target), admitted), Set.toVector(translated));
        let gained = Vector.filter(match (source, target) -> not Set.memberOf((source, target), translated), Set.toVector(admitted));
        (sortPairs(lost), sortPairs(gained))
    }

    def sortPairs(pairs: Vector[(String, String)]): Vector[(String, String)] =
        Vector.sortBy(match (source, target) -> "${source}\u0000${target}", pairs)

    /// The number of frozen basis edges incident to a set of control paths.
    pub def incidentEdges(world: Repository.World, paths: Vector[String]): Int32 = {
        let set = Vector.toSet(paths);
        Vector.count(match (source, target) -> Set.memberOf(source, set) or Set.memberOf(target, set),
            ControlTopology.edgePaths(world))
    }

    def landmark(metric: String, control: Float64, candidate: Float64): Comparison = {
        let noneDepth = 8.0;
        let difference = candidate - control;
        let bothValue = control != noneDepth and candidate != noneDepth;
        let ok = (control == noneDepth and candidate == noneDepth)
            or (bothValue and difference <= 1.0 and (0.0 - difference) <= 1.0);
        {metric = metric, control = control, candidate = candidate, delta = difference, threshold = 1.0, ok = ok}
    }
}
