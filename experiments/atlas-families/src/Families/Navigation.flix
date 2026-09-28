/// Issue-blind family-formation navigation over Atlas's six-atom typed tree.
///
/// Every file that defines a callable seeds one navigation. Each frontier is
/// expanded by Atlas's own evaluator over the three atoms its domain admits,
/// so every offered child is exactly the output of the Atlas program named by
/// the route so far plus one atom, never past depth seven. Jev chooses at each
/// frontier either to stop or to take one compatible atom (`Defines`, `Imports`, `ImportedBy`
/// from files; `DefinedIn`, `Calls`, `Callers` from symbols) toward the most
/// coherent family around the seed. The terminal frontier is then named by a
/// second choice among the repository locations holding its members. The
/// model sees repository structure only: typed previews with domain,
/// cardinality, and the first eight members in admitted order. No issue text,
/// gold, or source body exists in any state.
pub mod Families.Navigation {
    use Atlas.{Atom, State}
    use Families.Decision.Alternative
    use Repository.Structure.{FileId, SymbolId}

    pub type alias Context = {
        snapshotId = String,
        repository = String,
        world      = Repository.World
    }

    /// One recorded decision, in navigation order within its seed.
    pub type alias Record = {
        seed        = Int32,
        depth       = Int32,
        stateId     = String,
        route       = Vector[Atom],
        request     = Families.Decision.Request,
        observation = Families.Decision.Observation
    }

    /// One seed's family: the route Jev chose, the exact terminal frontier,
    /// and its name. `named` is false only when a single candidate location
    /// holds the family, so the protocol determines the name without a choice.
    pub type alias Outcome = {
        seed     = Int32,
        file     = Int32,
        route    = Vector[Atom],
        state    = State,
        stateId  = String,
        name     = String,
        nameKind = String,
        named    = Bool,
        records  = Vector[Record]
    }

    /// Files that define at least one callable, in admitted file order.
    pub def seeds(world: Repository.World): Vector[FileId] = {
        let defining = Set.map(fst, world#defines);
        Vector.range(0, Vector.length(world#files))
            |> Vector.map(FileId.FileId)
            |> Vector.filter(file -> Set.memberOf(file, defining))
    }

    pub def navigateAll(context: Context): Result[String, Vector[Outcome]] \ {Families.Provider.Provider, IO} =
        Vector.mapWithIndex((seed, file) -> (seed, file), seeds(context#world))
            |> Vector.traverse(match (seed, file) -> navigate(context, seed, file))

    def navigate(context: Context, seed: Int32, file: FileId): Result[String, Outcome] \ {Families.Provider.Provider, IO} = {
        let start = State.Files(Set#{file});
        let FileId.FileId(fileId) = file;
        forM (
            walked <- walk(context, seed, start, Vector.empty(), start, Vector.empty());
            (route, terminal, navigated) = walked;
            named <- name(context, seed, start, route, terminal, navigated);
            (label, kind, chosen, records) = named
        ) yield {
            seed = seed, file = fileId, route = route, state = terminal, stateId = stateIdentity(terminal),
            name = label, nameKind = kind, named = chosen, records = records
        }
    }

    def walk(
        context: Context,
        seed: Int32,
        start: State,
        route: Vector[Atom],
        current: State,
        records: Vector[Record]
    ): Result[String, (Vector[Atom], State, Vector[Record])] \ {Families.Provider.Provider, IO} = {
        let depth = Vector.length(route);
        let expanded = if (depth >= Families.Protocol.maxDepth()) Ok(Vector.empty()) else children(context#world, current);
        match expanded {
            case Err(error) => Err(error)
            case Ok(offered) if Vector.isEmpty(offered) => Ok((route, current, records))
            case Ok(offered) => offer(context, seed, start, route, current, records, offered)
        }
    }

    /// The nonempty, changed children of a frontier, in Atlas's stable atom order.
    pub def children(world: Repository.World, current: State): Result[String, Vector[(Atom, State)]] = {
        let steps = Atlas.programsFrom(Atlas.stateDomain(current), 1);
        Atlas.evaluate(world, current, steps) |> Result.map(evaluation ->
            Vector.zip(Vector.flatMap(program -> program#steps, steps), evaluation#outputs)
                |> Vector.filter(match (_, child) -> Atlas.cardinality(child) > 0 and child != current))
    }

    def offer(
        context: Context,
        seed: Int32,
        start: State,
        route: Vector[Atom],
        current: State,
        records: Vector[Record],
        children: Vector[(Atom, State)]
    ): Result[String, (Vector[Atom], State, Vector[Record])] \ {Families.Provider.Provider, IO} = {
        let stop = {
            key = "stop",
            criterion = "Stop and keep the current frontier as the family. ${preview(context#world, current)}",
            target = stateIdentity(current)
        };
        let takes = Vector.map(match (atom, child) -> {
            key = atomKey(atom),
            criterion = "Take ${atomKey(atom)}. ${preview(context#world, child)}",
            target = stateIdentity(child)
        }, children);
        let decided = Families.Decision.request(
            context#snapshotId, stateIdentity(current), state(context, start, route, current),
            Families.Protocol.navigationQuestion(), Families.Protocol.navigationInstructions(),
            Vector.append(Vector#{stop}, takes)
        ) |> Result.flatMap(request -> Families.Decision.decide(request) |> Result.map(observation -> (request, observation)));
        match decided {
            case Err(error) => Err(error)
            case Ok((request, observation)) => {
                let record = {
                    seed = seed, depth = Vector.length(route), stateId = stateIdentity(current),
                    route = route, request = request, observation = observation
                };
                let recorded = Vector.append(records, Vector#{record});
                if (observation#choiceIndex == 0) Ok((route, current, recorded))
                else {
                    let (atom, child) = Vector.get(observation#choiceIndex - 1, children);
                    walk(context, seed, start, Vector.append(route, Vector#{atom}), child, recorded)
                }
            }
        }
    }

    def name(
        context: Context,
        seed: Int32,
        start: State,
        route: Vector[Atom],
        terminal: State,
        records: Vector[Record]
    ): Result[String, (String, String, Bool, Vector[Record])] \ {Families.Provider.Provider, IO} = {
        let candidates = nameCandidates(context#world, terminal);
        let total = Atlas.cardinality(terminal);
        match Vector.head(candidates) {
            case None => Err("seed ${seed} has an empty terminal frontier")
            case Some((label, kind, _)) if Vector.length(candidates) == 1 => Ok((label, kind, false, records))
            case Some(_) => {
                let alternatives = Vector.mapWithIndex((index, candidate) -> {
                    let (label, kind, covered) = candidate;
                    {
                        key = "name_${index}",
                        criterion = "Name the family `${label}`, a ${kind} holding ${covered} of ${total} members.",
                        target = "${kind}:${label}"
                    }
                }, candidates);
                Families.Decision.request(
                    context#snapshotId, stateIdentity(terminal), state(context, start, route, terminal),
                    Families.Protocol.namingQuestion(), Families.Protocol.namingInstructions(), alternatives
                ) |> Result.flatMap(request -> Families.Decision.decide(request) |> Result.map(observation -> {
                    let (label, kind, _) = Vector.get(observation#choiceIndex, candidates);
                    let record = {
                        seed = seed, depth = Vector.length(route), stateId = stateIdentity(terminal),
                        route = route, request = request, observation = observation
                    };
                    (label, kind, true, Vector.append(records, Vector#{record}))
                }))
            }
        }
    }

    /// The candidate names of a frontier: every file holding a member and
    /// every non-root directory above one, ranked by how many members they
    /// hold, then by specificity (longer path first), then by path.
    pub def nameCandidates(world: Repository.World, state: State): Vector[(String, String, Int32)] = {
        let counts = Vector.foldLeft((known, path) -> Vector.foldLeft(
            (inner, label) -> Map.insertWith((a, b) -> a + b, label, 1, inner),
            known, Vector.append(Vector#{(path, "file")}, Vector.map(directory -> (directory, "directory"), ancestors(path)))),
            Map.empty(), memberPaths(world, state));
        Map.toVector(counts)
            |> Vector.map(match ((label, kind), covered) -> (label, kind, covered))
            |> Vector.sortBy(match (label, _, covered) -> (0 - covered, 0 - String.length(label), label))
            |> Vector.take(Families.Protocol.nameCandidates())
    }

    def ancestors(path: String): Vector[String] = {
        let parent = Repository.Location.directory(path);
        if (parent == "") Vector.empty() else Vector.append(Vector#{parent}, ancestors(parent))
    }

    def memberPaths(world: Repository.World, state: State): Vector[String] = match state {
        case State.Files(files) => Set.toVector(files) |> Vector.map(match FileId.FileId(id) -> Vector.get(id, world#files))
        case State.Symbols(symbols) => Set.toVector(symbols) |> Vector.map(match SymbolId.SymbolId(id) -> Vector.get(id, world#symbols)#path)
    }

    /// The fixed model-visible state: header, objective, repository, seed,
    /// depth, route, and the current frontier preview. Nothing else.
    pub def state(context: Context, start: State, route: Vector[Atom], current: State): String = Vector.join("\n", Vector#{
        Families.Protocol.stateHeader(),
        "objective: ${Families.Protocol.objective()}",
        "repository: ${context#repository}",
        "seed: ${preview(context#world, start)}",
        "depth: ${Vector.length(route)}/${Families.Protocol.maxDepth()}",
        "path: ${if (Vector.isEmpty(route)) "(seed)" else Vector.join(" > ", Vector.map(atomKey, route))}",
        "current: ${preview(context#world, current)}"
    })

    /// Domain, cardinality, and the first members in admitted order.
    pub def preview(world: Repository.World, state: State): String = {
        let members = memberLabels(world, state);
        let top = Vector.take(Families.Protocol.previewSize(), members);
        "domain=${domainName(state)} cardinality=${Atlas.cardinality(state)} top=[${Vector.join("; ", top)}]"
    }

    def memberLabels(world: Repository.World, state: State): Vector[String] = match state {
        case State.Files(files) => Set.toVector(files) |> Vector.map(match FileId.FileId(id) -> Vector.get(id, world#files))
        case State.Symbols(symbols) => Set.toVector(symbols) |> Vector.map(match SymbolId.SymbolId(id) -> {
            let symbol = Vector.get(id, world#symbols);
            "${symbol#path} :: ${symbol#name}"
        })
    }

    /// The exact semantic frontier, independent of preview truncation.
    pub def stateIdentity(state: State): String \ IO = {
        let canonical = match state {
            case State.Files(files) => "file:" + Vector.join(",", Vector.map(match FileId.FileId(id) -> Int32.toString(id), Set.toVector(files)))
            case State.Symbols(symbols) => "symbol:" + Vector.join(",", Vector.map(match SymbolId.SymbolId(id) -> Int32.toString(id), Set.toVector(symbols)))
        };
        ScientificIdentity.versioned(Families.Protocol.stateProtocol(), canonical)
    }

    pub def domainName(state: State): String = match state {
        case State.Files(_) => "file"
        case State.Symbols(_) => "symbol"
    }

    /// The frozen Jev action vocabulary for the six atoms.
    pub def atomKey(atom: Atom): String = match atom {
        case Atom.Defines    => "defines"
        case Atom.DefinedIn  => "defined_in"
        case Atom.Imports    => "imports"
        case Atom.ImportedBy => "imported_by"
        case Atom.Calls      => "calls"
        case Atom.Callers    => "callers"
    }
}
