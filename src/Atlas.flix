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

    pub type alias Counts = {
        logical = Int32,
        complete = Int32
    }

    enum State with Eq, Hash {
        case Files(Set[Structure.FileId])
        case Symbols(Set[Structure.SymbolId])
    }

    pub type alias RepositoryCounts = {
        files   = Int32,
        symbols = Int32,
        defines = Int32,
        imports = Int32,
        calls   = Int32,
        parent  = Int32
    }

    pub type alias Signature = {
        depth               = Int32,
        counts              = RepositoryCounts,
        logicalPrograms     = Int32,
        symbolPrograms      = Int32,
        physicalTransitions = Int32,
        transitionReuses    = Int32
    }

    type alias Memos[r: Region] = {
        transitions        = MutHashMap[(Atom, State), State, r],
        physicalTransitions = Ref[Int32, r],
        transitionReuses    = Ref[Int32, r]
    }

    /// Count the fixed composition-only grammar without allocating 3,279 paths.
    pub def counts(depth: Int32): Counts = loop(depth, 1, 0, 0, 0)

    /// Execute the complete typed composition tree through one depth.
    /// The mutable transition table is region-local, so measurement is pure.
    pub def measure(repository: Repository.World, seeds: Set[Structure.SymbolId], depth: Int32): Result[String, Signature] =
        if (depth < 1)
            Err("Atlas depth must be positive")
        else region rc {
            let physical = Physical.fromBasis(
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

    def search(
        world: Physical.World,
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

    def expand(world: Physical.World, state: State, memos: Memos[r]): Vector[State] \ r = match state {
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

    def transition(world: Physical.World, atom: Atom, state: State, memos: Memos[r]): State \ r =
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

    def apply(world: Physical.World, atom: Atom, state: State): State = match (atom, state) {
        case (Atom.Defines, State.Files(frontier)) =>
            State.Symbols(Physical.defines(world, frontier))
        case (Atom.DefinedIn, State.Symbols(frontier)) =>
            State.Files(Physical.definedIn(world, frontier))
        case (Atom.Imports, State.Files(frontier)) =>
            State.Files(Physical.imports(world, frontier))
        case (Atom.ImportedBy, State.Files(frontier)) =>
            State.Files(Physical.importedBy(world, frontier))
        case (Atom.Calls, State.Symbols(frontier)) =>
            State.Symbols(Physical.calls(world, frontier))
        case (Atom.Callers, State.Symbols(frontier)) =>
            State.Symbols(Physical.callers(world, frontier))
        case _ => state
    }
}
