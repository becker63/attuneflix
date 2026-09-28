/// The families clustering method (`atlas-families-v1`) over one admitted
/// world and its recorded, issue-blind evidence.
///
/// 1. Candidates (Jev-decided agglomeration). Every seed's recorded walk is
///    replayed through Atlas's own evaluator to its exact terminal frontier,
///    which must carry the recorded frontier identity, and is read at symbol
///    grain (a file frontier holds the callables its files define). Seeds whose
///    walks converge on the same members are one candidate; its representative
///    is the least seed, whose recorded name the candidate carries.
/// 2. Assignment (affinity). Each symbol joins, among the candidates whose
///    frontier holds it, the one with the greatest mean affinity
///    (`Families.Affinity` under `Families.Method.weights`), the least
///    candidate on a tie. A symbol no frontier holds joins the candidate of
///    its own defining file's seed.
/// 3. Families. The candidates that keep at least one member, in candidate
///    order, each with a content-derived identity over its exact members.
///
/// Every step is a pure function of the world and the recorded evidence; no
/// provider, key, issue, or gold exists here.
pub mod Families.Cluster {
    use Atlas.{Atom, State}
    use Repository.Structure.{FileId, SymbolId}

    /// The recorded evidence the method reads for one world: the typed family
    /// outcomes and decisions, and one recorded vector per symbol.
    pub type alias Evidence = {
        outcomes  = Vector[Families.Decision.Table.Family],
        decisions = Vector[Families.Decision.Table.Entry],
        vectors   = Vector[Vector[Float32]]
    }

    /// One candidate family: the recorded outcomes of every seed that reached
    /// its members (the representative `outcome` first). `nameDecision` is the identity of the recorded
    /// naming decision, or `None` when the protocol named the frontier because
    /// a single location held it.
    pub type alias Candidate = {
        ordinal      = Int32,
        outcomes     = Vector[Families.Decision.Table.Family],
        outcome      = Families.Decision.Table.Family,
        nameDecision = Option[String],
        members      = Vector[Int32]
    }

    /// Where one symbol went: the chosen candidate, how many recorded
    /// frontiers held the symbol (zero for the seed fallback), and the
    /// affinity components against the chosen candidate.
    pub type alias Assignment = {
        symbol     = Int32,
        candidate  = Int32,
        candidates = Int32,
        components = Families.Affinity.Components
    }

    pub type alias Family = {
        family       = Int32,
        familyId     = String,
        name         = String,
        nameKind     = String,
        named        = Bool,
        seed         = Int32,
        nameDecision = Option[String],
        seedFiles    = Vector[String],
        route        = Vector[String],
        stateId      = String,
        members      = Int32,
        files        = Int32
    }

    /// One family member: the exact admitted symbol row it is, and the
    /// affinity that placed it.
    pub type alias Member = {
        family     = Int32,
        familyId   = String,
        entityId   = Int32,
        path       = String,
        name       = String,
        startByte  = Int32,
        endByte    = Int32,
        candidates = Int32,
        affinity   = Float64,
        structural = Float64,
        semantic   = Float64
    }

    pub type alias Clustering = {
        snapshotId = String,
        families   = Vector[Family],
        members    = Vector[Member],
        rollups    = Vector[Families.Rollup.Rollup]
    }

    /// The whole method under the versioned weights.
    pub def cluster(snapshotId: String, world: Repository.World, evidence: Evidence): Result[String, Clustering] \ IO = forM (
        substrate <- Families.Affinity.substrate(world, evidence#vectors);
        candidates0 <- candidates(world, evidence);
        placed = assign(substrate, candidates0, Families.Method.weights());
        families0 = families(snapshotId, world, substrate, candidates0, placed);
        (familyRows, memberRows) = families0
    ) yield {
        snapshotId = snapshotId,
        families = familyRows,
        members = memberRows,
        rollups = Families.Rollup.rollups(world, Vector.map(member -> (member#entityId, member#family, member#familyId), memberRows))
    }

    /// The exact terminal frontier of a recorded walk: its route replayed
    /// from the seed file through Atlas, never read from a preview.
    pub def frontier(world: Repository.World, outcome: Families.Decision.Table.Family): Result[String, State] = {
        let start = State.Files(Set#{FileId.FileId(outcome#file)});
        forM (
            atoms <- Vector.traverse(key -> atomOf(key) |> Option.toOk("unknown atom ${key} in seed ${outcome#seed}"), outcome#route);
            terminal <- if (Vector.isEmpty(atoms)) Ok(start)
                else Atlas.evaluate(world, start, Vector#{{steps = atoms}}) |> Result.flatMap(evaluation ->
                    Vector.head(evaluation#outputs) |> Option.toOk("seed ${outcome#seed} route has no output"))
        ) yield terminal
    }

    def atomOf(key: String): Option[Atom] =
        Vector.find(atom -> Families.Navigation.atomKey(atom) == key,
            Vector#{Atom.Defines, Atom.DefinedIn, Atom.Imports, Atom.ImportedBy, Atom.Calls, Atom.Callers})

    /// The admitted symbols of a frontier, ascending.
    pub def symbols(world: Repository.World, state: State): Vector[Int32] = match state {
        case State.Symbols(values) => Set.toVector(values) |> Vector.map(match SymbolId.SymbolId(id) -> id)
        case State.Files(files) => Set.toVector(world#defines)
            |> Vector.filterMap(match (file, SymbolId.SymbolId(id)) -> if (Set.memberOf(file, files)) Some(id) else None)
            |> Vector.toSet |> Set.toVector
    }

    /// The candidates of one world in least-seed order, each verified against
    /// the recorded outcome and naming evidence of every seed it holds.
    pub def candidates(world: Repository.World, evidence: Evidence): Result[String, Vector[Candidate]] \ IO = {
        let seeds = Families.Navigation.seeds(world);
        if (Vector.length(seeds) != Vector.length(evidence#outcomes))
            Err("the world has ${Vector.length(seeds)} seeds but ${Vector.length(evidence#outcomes)} recorded outcomes")
        else forM (
            verified <- Vector.traverse(outcome -> verify(world, evidence#decisions, seeds, outcome), evidence#outcomes)
        ) yield coalesce(verified)
    }

    def verify(
        world: Repository.World,
        decisions: Vector[Families.Decision.Table.Entry],
        seeds: Vector[FileId],
        outcome: Families.Decision.Table.Family
    ): Result[String, (Families.Decision.Table.Family, Option[String], Vector[Int32])] \ IO = forM (
        _ <- if (Vector.nth(outcome#seed, seeds) == Some(FileId.FileId(outcome#file))) Ok(())
             else Err("seed ${outcome#seed} is not the admitted seed file ${outcome#file}");
        _ <- if (Vector.nth(outcome#file, world#files) == Some(outcome#path)) Ok(())
             else Err("seed ${outcome#seed} path ${outcome#path} is not its admitted file");
        terminal <- frontier(world, outcome);
        _ <- if (Families.Navigation.stateIdentity(terminal) == outcome#stateId) Ok(())
             else Err("seed ${outcome#seed} route does not reach its recorded frontier");
        decision <- nameProvenance(world, decisions, outcome, terminal)
    ) yield (outcome, decision, symbols(world, terminal))

    /// A recorded name is admissible exactly when the protocol produces it: a
    /// named family's name is the location its recorded naming decision
    /// chose, and an unnamed family's name is its only candidate location.
    pub def nameProvenance(
        world: Repository.World,
        decisions: Vector[Families.Decision.Table.Entry],
        outcome: Families.Decision.Table.Family,
        terminal: State
    ): Result[String, Option[String]] = {
        let offered = Families.Navigation.nameCandidates(world, terminal)
            |> Vector.map(match (label, kind, _) -> (label, kind));
        let naming = Vector.filter(entry -> entry#seed == outcome#seed and entry#question == Families.Protocol.namingQuestion(), decisions);
        let target = "${outcome#nameKind}:${outcome#name}";
        match (outcome#named, Vector.head(naming)) {
            case (false, None) =>
                if (offered == Vector#{(outcome#name, outcome#nameKind)}) Ok(None)
                else Err("seed ${outcome#seed} is unnamed but its frontier has other candidate names")
            case (true, Some(entry)) =>
                if (Vector.length(naming) != 1) Err("seed ${outcome#seed} has more than one naming decision")
                else if (entry#stateId != outcome#stateId) Err("seed ${outcome#seed} naming decision names another frontier")
                else if (Vector.nth(entry#observation#choiceIndex, entry#targets) != Some(target) or
                    Vector.nth(entry#observation#choiceIndex, offered) != Some((outcome#name, outcome#nameKind)))
                    Err("seed ${outcome#seed} name ${outcome#name} is not the recorded naming choice")
                else Ok(Some(entry#observation#identity))
            case (true, None) => Err("seed ${outcome#seed} is named but has no recorded naming decision")
            case (false, Some(_)) => Err("seed ${outcome#seed} is unnamed but has a naming decision")
        }
    }

    /// Seeds whose frontiers hold the same nonempty members coalesce, in
    /// least-seed order; an empty frontier stays its own candidate so the
    /// seed fallback never pools unrelated files.
    def coalesce(verified: Vector[(Families.Decision.Table.Family, Option[String], Vector[Int32])]): Vector[Candidate] = {
        let step = (state, entry) -> {
            let (index, groups) = state;
            let (outcome, _, members) = entry;
            let key = if (Vector.isEmpty(members)) (members, outcome#seed) else (members, -1);
            match Map.get(key, index) {
                case Some(ordinal) =>
                    (index, Map.insertWith((later, earlier) -> Vector.append(earlier, later), ordinal, Vector#{entry}, groups))
                case None => {
                    let ordinal = Map.size(index);
                    (Map.insert(key, ordinal, index), Map.insert(ordinal, Vector#{entry}, groups))
                }
            }
        };
        let (_, groups) = Vector.foldLeft(step, (Map.empty(), Map.empty()), verified);
        Map.toVector(groups) |> Vector.map(match (ordinal, group) -> {
            let (outcome, decision, members) = Vector.get(0, group);
            {
                ordinal = ordinal,
                outcomes = Vector.map(match (value, _, _) -> value, group),
                outcome = outcome,
                nameDecision = decision,
                members = members
            }
        })
    }

    /// The candidates each symbol is compared against, with its components
    /// against each, in ascending candidate order, and how many recorded
    /// frontiers hold it.
    pub def options(substrate: Families.Affinity.Substrate, candidates0: Vector[Candidate]): Vector[(Int32, Vector[(Int32, Families.Affinity.Components)])] = {
        let profiles = Vector.map(candidate -> Families.Affinity.profile(substrate, candidate#members), candidates0);
        let holding = Vector.foldLeft((known, candidate) -> Vector.foldLeft((inner, symbol) ->
            Map.insertWith((later, earlier) -> Vector.append(earlier, later), symbol, Vector#{candidate#ordinal}, inner),
            known, candidate#members), Map.empty(), candidates0);
        let seedCandidate = Vector.foldLeft((known, candidate) -> Vector.foldLeft((inner, outcome) ->
            Map.insert(outcome#file, candidate#ordinal, inner), known, candidate#outcomes), Map.empty(), candidates0);
        Vector.range(0, Vector.length(substrate#fileOf)) |> Vector.map(symbol -> {
            let held = Map.getWithDefault(symbol, Vector.empty(), holding);
            let compared = if (Vector.isEmpty(held))
                Map.get(Vector.get(symbol, substrate#fileOf), seedCandidate) |> Option.toList |> List.toVector
                else held;
            (Vector.length(held), Vector.map(ordinal ->
                (ordinal, Families.Affinity.components(substrate, Vector.get(ordinal, profiles), symbol)), compared))
        })
    }

    /// The greatest-affinity option under `weights`, the least candidate on a tie.
    pub def strongest(weights: Families.Method.Weights, compared: Vector[(Int32, Families.Affinity.Components)]): Option[(Int32, Families.Affinity.Components)] =
        Vector.foldLeft((best, option) -> match best {
            case None => Some(option)
            case Some((_, kept)) =>
                if (Families.Affinity.affinity(weights, snd(option)) > Families.Affinity.affinity(weights, kept)) Some(option)
                else best
        }, None, compared)

    /// How many symbols join a different candidate under `weights` than under
    /// the protocol weights: the report's single-source ablation.
    pub def moved(compared: Vector[(Int32, Vector[(Int32, Families.Affinity.Components)])], weights: Families.Method.Weights): Int32 =
        Vector.count(match (_, options0) ->
            Option.map(fst, strongest(weights, options0)) != Option.map(fst, strongest(Families.Method.weights(), options0)), compared)

    pub def assign(substrate: Families.Affinity.Substrate, candidates0: Vector[Candidate], weights: Families.Method.Weights): Vector[Assignment] =
        placements(options(substrate, candidates0), weights)

    pub def placements(compared: Vector[(Int32, Vector[(Int32, Families.Affinity.Components)])], weights: Families.Method.Weights): Vector[Assignment] =
        compared |> Vector.mapWithIndex((symbol, entry) -> {
            let (held, options0) = entry;
            let (candidate, components) = strongest(weights, options0) |> Option.getWithDefault((-1, Families.Affinity.zero()));
            {symbol = symbol, candidate = candidate, candidates = held, components = components}
        })

    def families(
        snapshotId: String,
        world: Repository.World,
        substrate: Families.Affinity.Substrate,
        candidates0: Vector[Candidate],
        placed: Vector[Assignment]
    ): (Vector[Family], Vector[Member]) \ IO = {
        let weights = Families.Method.weights();
        let kept = Vector.filter(candidate -> Vector.exists(value -> value#candidate == candidate#ordinal, placed), candidates0);
        let built = Vector.mapWithIndex((family, candidate) -> {
            let joined = Vector.filter(value -> value#candidate == candidate#ordinal, placed);
            let ids = Vector.map(value -> value#symbol, joined);
            let familyId = identity(snapshotId, ids);
            let row = {
                family = family, familyId = familyId, name = candidate#outcome#name,
                nameKind = candidate#outcome#nameKind, named = candidate#outcome#named, seed = candidate#outcome#seed,
                nameDecision = candidate#nameDecision,
                seedFiles = Vector.map(outcome -> outcome#path, candidate#outcomes),
                route = candidate#outcome#route, stateId = candidate#outcome#stateId,
                members = Vector.length(ids),
                files = Vector.map(id -> Vector.get(id, substrate#fileOf), ids) |> Vector.toSet |> Set.size
            };
            let members = Vector.map(value -> {
                let symbol = Vector.get(value#symbol, world#symbols);
                {
                    family = family, familyId = familyId, entityId = value#symbol, path = symbol#path, name = symbol#name,
                    startByte = symbol#startByte, endByte = symbol#endByte, candidates = value#candidates,
                    affinity = Families.Affinity.affinity(weights, value#components),
                    structural = Families.Affinity.structural(weights, value#components),
                    semantic = Families.Affinity.weightedSemantic(weights, value#components)
                }
            }, joined);
            (row, members)
        }, kept);
        (Vector.map(fst, built), Vector.flatMap(snd, built))
    }

    /// The content-derived family identity: the method protocol over the
    /// world snapshot and the exact admitted member ids, ascending.
    pub def identity(snapshotId: String, members: Vector[Int32]): String \ IO =
        ScientificIdentity.versioned(Families.Method.protocol(),
            Vector.join("\n", Vector.append(Vector#{snapshotId}, Vector.map(id -> "symbol:${id}", Vector.sort(members)))))
}
