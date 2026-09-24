mod Atlas {
    /// The measurement grammar is a distinct type: Reverse and Union do not exist.
    pub enum Atom with Eq, Order, ToString, Hash {
        case Defines,
        case DefinedIn,
        case Imports,
        case ImportedBy,
        case Calls,
        case Callers
    }

    pub enum Expr with Eq, Order, ToString, Hash {
        case Atom(Atom),
        case Compose(Expr, Atom)
    }

    /// One member of the finite Atlas measurement language.
    ///
    /// The expression type has only Atom and Compose, so an Atlas Program
    /// cannot silently acquire Radii's Reverse or Union constructors.
    pub type alias Program = {
        steps      = Vector[Atom],
        expression = Expr
    }

    pub type alias Counts = {
        logical = Int32,
        complete = Int32
    }

    pub enum State with Eq, Order, Hash, ToString {
        case Files(Set[Repository.Structure.FileId])
        case Symbols(Set[Repository.Structure.SymbolId])
    }

    pub type alias Evaluation = {
        outputs             = Vector[State],
        physicalTransitions = Int32,
        transitionReuses    = Int32
    }

    pub type alias RepositoryCounts = {
        files   = Int32,
        symbols = Int32,
        defines = Int32,
        imports = Int32,
        calls   = Int32,
        parent  = Int32
    }

    pub type alias Summary = {
        depth               = Int32,
        counts              = RepositoryCounts,
        logicalPrograms     = Int32,
        symbolPrograms      = Int32,
        physicalTransitions = Int32,
        transitionReuses    = Int32
    }

    /// Experimental file projection of the fixed Atlas grammar.
    pub type alias FileEvidence = {
        file        = Repository.Structure.FileId,
        path        = String,
        minimumDepth = Int32,
        pathSupport = Int32
    }

    pub type alias FileRanking = {
        evidence             = Vector[FileEvidence],
        physicalTransitions  = Int32,
        transitionReuses     = Int32
    }

    pub type alias NamedFileRanking = {
        path    = String,
        ranking = FileRanking
    }

    type alias Memos[r: Region] = {
        transitions        = MutHashMap[(Atom, State), State, r],
        physicalTransitions = Ref[Int32, r],
        transitionReuses    = Ref[Int32, r]
    }

    /// Count the fixed composition-only grammar without allocating 3,279 paths.
    pub def counts(depth: Int32): Counts = loop(depth, 1, 0, 0, 0)

    /// Enumerate every well-typed Atlas program through `maxDepth`.
    ///
    /// Results are ordered first by depth, then by the stable atom order in
    /// `compatible`. A non-positive bound names the empty language.
    pub def programs(maxDepth: Int32): Vector[Program] =
        enumerateLevels(1, maxDepth, Vector.empty(), Vector.empty())

    /// Evaluate a declared Atlas family over one exact typed seed.
    ///
    /// Mutation and memo tables cannot escape the region. Outputs retain the
    /// same stable order as `programs`; repeated exact transitions execute
    /// only once.
    pub def evaluate(
        repository: Repository.World,
        input: State,
        family: Vector[Program]
    ): Result[String, Evaluation] = region rc {
        let physical = Repository.Physical.fromBasis(
            repository#defines,
            repository#imports,
            repository#calls,
            repository#parents
        );
        let memos: Memos[rc] = {
            transitions = MutHashMap.empty(rc),
            physicalTransitions = Ref.fresh(rc, 0),
            transitionReuses = Ref.fresh(rc, 0)
        };
        Vector.traverse(program -> evaluateProgram(physical, input, program, memos), family)
            |> Result.map(outputs -> {
                outputs = outputs,
                physicalTransitions = Ref.get(memos#physicalTransitions),
                transitionReuses = Ref.get(memos#transitionReuses)
            })
    }

    /// Execute the complete typed composition tree through one depth.
    /// The mutable transition table is region-local, so measurement is pure.
    pub def measure(repository: Repository.World, seeds: Set[Repository.Structure.SymbolId], depth: Int32): Result[String, Summary] =
        if (depth < 1)
            Err("Atlas depth must be positive")
        else region rc {
            let physical = Repository.Physical.fromBasis(
                repository#defines,
                repository#imports,
                repository#calls,
                repository#parents
            );
            let memos: Memos[rc] = {
                transitions = MutHashMap.empty(rc),
                physicalTransitions = Ref.fresh(rc, 0),
                transitionReuses = Ref.fresh(rc, 0)
            };
            let (logical, complete) = search(
                physical,
                depth,
                Vector#{State.Symbols(seeds)},
                0,
                0,
                memos
            );
            Ok({
                depth = depth,
                counts = {
                    files = Vector.length(repository#files),
                    symbols = Vector.length(repository#symbols),
                    defines = Set.size(repository#defines),
                    imports = Set.size(repository#imports),
                    calls = Set.size(repository#calls),
                    parent = Set.size(repository#parents)
                },
                logicalPrograms = logical,
                symbolPrograms = complete,
                physicalTransitions = Ref.get(memos#physicalTransitions),
                transitionReuses = Ref.get(memos#transitionReuses)
            })
        }

    /// Rank files reached from one file by the unchanged six-atom Atlas.
    /// Each syntactic typed path contributes at most one support count per file.
    pub def rankFiles(repository: Repository.World, seed: Repository.Structure.FileId, depth: Int32): Result[String, Vector[FileEvidence]] =
        rankFilesMeasured(repository, seed, depth)
            |> Result.map(result -> result#evidence)

    /// The same pure file ranking with physical-work telemetry exposed for science runs.
    pub def rankFilesMeasured(repository: Repository.World, seed: Repository.Structure.FileId, depth: Int32): Result[String, FileRanking] =
        if (depth < 1)
            Err("Atlas depth must be positive")
        else {
            let physical = Repository.Physical.fromBasis(
                repository#defines,
                repository#imports,
                repository#calls,
                repository#parents
            );
            rankFilesWith(repository, physical, seed, depth)
        }

    /// Rank every file while constructing the physical indexes only once.
    pub def rankAllFilesMeasured(repository: Repository.World, depth: Int32): Result[String, Vector[NamedFileRanking]] =
        if (depth < 1)
            Err("Atlas depth must be positive")
        else {
            let physical = Repository.Physical.fromBasis(
                repository#defines,
                repository#imports,
                repository#calls,
                repository#parents
            );
            let identities = Vector.mapWithIndex(
                (index, path) -> (path, Repository.Structure.FileId.FileId(index)), repository#files);
            rankFileBatches(repository, physical, identities, depth, 0, Vector.empty()) |> Ok
        }

    // Share semantic states across 64 seeds, then release the region. This keeps
    // cross-seed DAG reuse while bounding repository-scale memo retention.
    def rankFileBatches(
        repository: Repository.World,
        physical: Repository.Physical.World,
        identities: Vector[(String, Repository.Structure.FileId)],
        depth: Int32,
        start: Int32,
        accumulated: Vector[NamedFileRanking]
    ): Vector[NamedFileRanking] =
        if (start >= Vector.length(identities))
            accumulated
        else {
            let finish = Int32.min(start + 64, Vector.length(identities));
            let batch = rankFileBatch(
                repository,
                physical,
                Vector.slice(start = start, end = finish, identities),
                depth
            );
            rankFileBatches(repository, physical, identities, depth, finish,
                Vector.append(accumulated, batch))
        }

    def rankFileBatch(
        repository: Repository.World,
        physical: Repository.Physical.World,
        identities: Vector[(String, Repository.Structure.FileId)],
        depth: Int32
    ): Vector[NamedFileRanking] = region rc {
        let memos: Memos[rc] = {
            transitions = MutHashMap.empty(rc),
            physicalTransitions = Ref.fresh(rc, 0),
            transitionReuses = Ref.fresh(rc, 0)
        };
        Vector.map(match (path, file) -> {
            path = path,
            ranking = rankFileWithin(repository, physical, file, depth, memos)
        }, identities)
    }

    def rankFilesWith(
        repository: Repository.World,
        physical: Repository.Physical.World,
        seed: Repository.Structure.FileId,
        depth: Int32
    ): Result[String, FileRanking] = region rc {
            let memos: Memos[rc] = {
                transitions = MutHashMap.empty(rc),
                physicalTransitions = Ref.fresh(rc, 0),
                transitionReuses = Ref.fresh(rc, 0)
            };
            Ok(rankFileWithin(repository, physical, seed, depth, memos))
        }

    def rankFileWithin(
        repository: Repository.World,
        physical: Repository.Physical.World,
        seed: Repository.Structure.FileId,
        depth: Int32,
        memos: Memos[r]
    ): FileRanking \ r = {
            let transitionsBefore = Ref.get(memos#physicalTransitions);
            let reusesBefore = Ref.get(memos#transitionReuses);
            let evidence = collectFileEvidence(
                physical,
                seed,
                depth,
                1,
                Vector#{State.Files(Set.singleton(seed))},
                Map.empty(),
                memos
            );
            let projected = Vector.mapWithIndex((index, path) -> {
                let file = Repository.Structure.FileId.FileId(index);
                match Map.get(file, evidence) {
                    case None => None
                    case Some((minimumDepth, pathSupport)) => Some({
                        file = file,
                        path = path,
                        minimumDepth = minimumDepth,
                        pathSupport = pathSupport
                    })
                }
            }, repository#files);
            let ranked = Vector.filterMap(item -> item, projected)
                |> Vector.sortBy(item -> (item#minimumDepth, -item#pathSupport, item#path));
            {
                evidence = ranked,
                physicalTransitions = Ref.get(memos#physicalTransitions) - transitionsBefore,
                transitionReuses = Ref.get(memos#transitionReuses) - reusesBefore
            }
        }

    def loop(remaining: Int32, symbols: Int32, files: Int32, logical: Int32, complete: Int32): Counts =
        if (remaining <= 0) {
            logical = logical,
            complete = complete
        } else {
            // From either sort there are exactly three compatible directed atoms.
            let nextFiles = symbols + (2 * files);
            let nextSymbols = (2 * symbols) + files;
            loop(
                remaining - 1,
                nextSymbols,
                nextFiles,
                logical + nextFiles + nextSymbols,
                complete + nextSymbols
            )
        }

    def enumerateLevels(
        current: Int32,
        maxDepth: Int32,
        previous: Vector[Program],
        all: Vector[Program]
    ): Vector[Program] =
        if (current > maxDepth)
            all
        else {
            let exact = if (current == 1)
                Vector.map(atom -> {
                    steps = Vector#{atom},
                    expression = Expr.Atom(atom)
                }, compatible(Radii.Domain.Symbol))
            else
                Vector.flatMap(program -> Vector.map(atom -> {
                    steps = Vector.append(program#steps, Vector#{atom}),
                    expression = Expr.Compose(program#expression, atom)
                }, compatible(target(program#expression))), previous);
            enumerateLevels(
                current + 1,
                maxDepth,
                exact,
                Vector.append(all, exact)
            )
        }

    def compatible(domain: Radii.Domain): Vector[Atom] = match domain {
        case Radii.Domain.Symbol => Vector#{Atom.DefinedIn, Atom.Calls, Atom.Callers}
        case Radii.Domain.File   => Vector#{Atom.Defines, Atom.Imports, Atom.ImportedBy}
        case Radii.Domain.Location => Vector.empty()
    }

    pub def terminal(program: Program): Radii.Domain = target(program#expression)

    pub def stateDomain(state: State): Radii.Domain = match state {
        case State.Files(_)   => Radii.Domain.File
        case State.Symbols(_) => Radii.Domain.Symbol
    }

    pub def cardinality(state: State): Int32 = match state {
        case State.Files(values)   => Set.size(values)
        case State.Symbols(values) => Set.size(values)
    }

    /// Build the first-class repository signature from the fixed Atlas family.
    pub def signature(
        repository: Repository.World,
        input: State,
        depth: Int32
    ): Result[String, Atlas.Signature.Signature] =
        Atlas.Signature.compute(repository, input, depth)

    def target(expression: Expr): Radii.Domain = match expression {
        case Expr.Atom(atom) => targetAtom(atom)
        case Expr.Compose(_, atom) => targetAtom(atom)
    }

    def targetAtom(atom: Atom): Radii.Domain = match atom {
        case Atom.Defines    => Radii.Domain.Symbol
        case Atom.DefinedIn  => Radii.Domain.File
        case Atom.Imports    => Radii.Domain.File
        case Atom.ImportedBy => Radii.Domain.File
        case Atom.Calls      => Radii.Domain.Symbol
        case Atom.Callers    => Radii.Domain.Symbol
    }

    def sourceAtom(atom: Atom): Radii.Domain = match atom {
        case Atom.Defines    => Radii.Domain.File
        case Atom.DefinedIn  => Radii.Domain.Symbol
        case Atom.Imports    => Radii.Domain.File
        case Atom.ImportedBy => Radii.Domain.File
        case Atom.Calls      => Radii.Domain.Symbol
        case Atom.Callers    => Radii.Domain.Symbol
    }

    def evaluateProgram(
        world: Repository.Physical.World,
        input: State,
        program: Program,
        memos: Memos[r]
    ): Result[String, State] \ r =
        match expressionOf(program#steps) {
            case None => Err("Atlas program must contain at least one atom")
            case Some(expression) =>
                if (expression != program#expression)
                    Err("Atlas program steps and expression disagree")
                else evaluateSteps(world, input, program#steps, memos)
        }

    def evaluateSteps(
        world: Repository.Physical.World,
        input: State,
        steps: Vector[Atom],
        memos: Memos[r]
    ): Result[String, State] \ r = match Vector.head(steps) {
        case None => Ok(input)
        case Some(atom) =>
            if (stateDomain(input) != sourceAtom(atom))
                Err("ill-typed Atlas program")
            else {
                let output = transition(world, atom, input, memos);
                evaluateSteps(
                    world,
                    output,
                    Vector.slice(start = 1, end = Vector.length(steps), steps),
                    memos
                )
            }
    }

    def expressionOf(steps: Vector[Atom]): Option[Expr] = match Vector.head(steps) {
        case None => None
        case Some(atom) => Some(Vector.foldLeft(
            (expression, next) -> Expr.Compose(expression, next),
            Expr.Atom(atom),
            Vector.slice(start = 1, end = Vector.length(steps), steps)
        ))
    }

    def search(
        world: Repository.Physical.World,
        remaining: Int32,
        states: Vector[State],
        logical: Int32,
        complete: Int32,
        memos: Memos[r]
    ): (Int32, Int32) \ r =
        if (remaining == 0)
            (logical, complete)
        else {
            let next = Vector.flatMap(state -> expand(world, state, memos), states);
            let symbols = Vector.foldLeft((count, state) -> match state {
                case State.Symbols(_) => count + 1
                case State.Files(_)   => count
            }, 0, next);
            search(
                world,
                remaining - 1,
                next,
                logical + Vector.length(next),
                complete + symbols,
                memos
            )
        }

    def collectFileEvidence(
        world: Repository.Physical.World,
        seed: Repository.Structure.FileId,
        remaining: Int32,
        currentDepth: Int32,
        states: Vector[State],
        evidence: Map[Repository.Structure.FileId, (Int32, Int32)],
        memos: Memos[r]
    ): Map[Repository.Structure.FileId, (Int32, Int32)] \ r =
        if (remaining == 0)
            evidence
        else {
            let next = Vector.flatMap(state -> expand(world, state, memos), states);
            let updated = Vector.foldLeft((known, state) -> match state {
                case State.Symbols(_) => known
                case State.Files(files) => Set.foldLeft((result, file) ->
                    if (file == seed)
                        result
                    else match Map.get(file, result) {
                        case None => Map.insert(file, (currentDepth, 1), result)
                        case Some((minimumDepth, support)) =>
                            Map.insert(file, (minimumDepth, support + 1), result)
                    }, known, files)
            }, evidence, next);
            collectFileEvidence(
                world,
                seed,
                remaining - 1,
                currentDepth + 1,
                next,
                updated,
                memos
            )
        }

    def expand(world: Repository.Physical.World, state: State, memos: Memos[r]): Vector[State] \ r = match state {
        case State.Files(_) => Vector#{
            transition(world, Atom.Defines, state, memos),
            transition(world, Atom.Imports, state, memos),
            transition(world, Atom.ImportedBy, state, memos)
        }
        case State.Symbols(_) => Vector#{
            transition(world, Atom.DefinedIn, state, memos),
            transition(world, Atom.Calls, state, memos),
            transition(world, Atom.Callers, state, memos)
        }
    }

    def transition(world: Repository.Physical.World, atom: Atom, state: State, memos: Memos[r]): State \ r =
        match MutHashMap.get((atom, state), memos#transitions) {
            case Some(output) => {
                Ref.transform(value -> value + 1, memos#transitionReuses);
                output
            }
            case None => {
                let output = apply(world, atom, state);
                MutHashMap.put((atom, state), output, memos#transitions);
                Ref.transform(value -> value + 1, memos#physicalTransitions);
                output
            }
        }

    def apply(world: Repository.Physical.World, atom: Atom, state: State): State = match (atom, state) {
        case (Atom.Defines, State.Files(frontier)) =>
            State.Symbols(Repository.Physical.defines(world, frontier))
        case (Atom.DefinedIn, State.Symbols(frontier)) =>
            State.Files(Repository.Physical.definedIn(world, frontier))
        case (Atom.Imports, State.Files(frontier)) =>
            State.Files(Repository.Physical.imports(world, frontier))
        case (Atom.ImportedBy, State.Files(frontier)) =>
            State.Files(Repository.Physical.importedBy(world, frontier))
        case (Atom.Calls, State.Symbols(frontier)) =>
            State.Symbols(Repository.Physical.calls(world, frontier))
        case (Atom.Callers, State.Symbols(frontier)) =>
            State.Symbols(Repository.Physical.callers(world, frontier))
        case _ => state
    }
}
