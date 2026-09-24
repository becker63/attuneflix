/// Atlas is the deliberately small repository ruler built on top of Radii.
///
/// Radii may describe general relational expressions. Atlas admits only six
/// directed relations and composition, so one program is just a well-typed
/// sequence of Atoms. Keeping that restriction in the type means the census
/// can exhaust the complete language through a fixed depth without hidden
/// beam choices, normalization choices, or a recursive Union explosion.
///
/// An Atom is also the smallest meaningful deterministic execution unit:
///
///     (exact typed frontier, one Atom) -> exact next typed frontier
///
/// For example, applying Calls once to a set of 100 Symbols is one transition,
/// even if it follows 10,000 admitted call edges. The result depends only on
/// the frozen repository world, the complete input set, and the Atom. It does
/// not depend on the route that reached the set or the route that follows it.
///
/// This cleanly separates two kinds of reuse. A compiled program DAG may share
/// common syntax/prefixes. The Atom memo below shares runtime semantic work
/// when different routes converge on the same exact set. The older evaluator
/// could also jump across a cached multi-Atom subtree in one lookup; atomic
/// reuse may walk several cached intermediate states instead, but it still
/// performs no repeated repository relation applications. A compiled-node
/// memo can recover that coarse shortcut later without enlarging Atlas's
/// public language or changing its answers.
///
/// The small reuse unit buys several concrete properties:
///
///   * Stable identity. In this file the live Flix key is exactly
///     `(Atlas.Atom, Atlas.State)` because one `Repository.World` is fixed by
///     the enclosing `evaluate` call. The persisted equivalent is
///     `(snapshot_id, canonical state_id, atom)`. No surrounding route,
///     policy, or learned-model choice is required to interpret that work.
///   * Route independence. Calls reached through an import route and Calls
///     reached through a caller route reuse the same answer when their exact
///     Symbol frontiers are equal. How the frontier was found is irrelevant.
///   * Syntax independence. Reassociating or renormalizing a larger Radii AST
///     cannot change what `(state, Calls)` means. Cache identity does not depend
///     on a particular expression-tree spelling.
///   * A fixed measuring unit. One reported physical transition always means
///     one of the six relations was actually applied to one complete frontier.
///     A memo hit always means that relation application was avoided.
///   * Separate explanations. Equal prefixes are a property of program syntax;
///     equal frontiers are a property of repository behavior. A program DAG
///     handles the former and state/Atom recurrence handles the latter, so the
///     repository signature can report them independently.
///
/// The trade is narrow and explicit. If four cached Atoms remain, atomic
/// execution performs four cheap memo lookups where a whole-subtree memo could
/// perform one. It does not repeat the four repository traversals. Profiling
/// may justify a private `(compiled node, state)` shortcut, but that remains a
/// physical optimization underneath this six-Atom scientific language.
mod Atlas {
    /// One directed primitive relation. This is both the smallest public
    /// symbol in the Atlas grammar and the smallest counted repository
    /// operation. Reverse and Union remain Radii operations; they are
    /// intentionally not constructors in Atlas.
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

    /// One member of the finite Atlas measurement language: an ordered list
    /// of Atoms plus the equivalent closed expression used for type checking.
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

    /// Query-local semantic recurrence. This table does not cache arbitrary
    /// expression syntax: its key asks only what one Atom does to one exact
    /// typed state. The repository world is fixed for the enclosing call.
    ///
    /// A later route can therefore reuse an answer even when its prefix has no
    /// syntax in common with the first route. Conversely, common syntax alone
    /// does not create a hit when it arrives with a different frontier. These
    /// are repository facts, not parser or model heuristics.
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
        programsFrom(Radii.Domain.Symbol, maxDepth)

    /// Enumerate the complete family compatible with one declared seed
    /// domain. The grammar is unchanged; only the three legal first atoms are
    /// selected from the seed type. Census File and Symbol panels therefore
    /// use the same rule rather than coercing one domain into the other.
    pub def programsFrom(domain: Radii.Domain, maxDepth: Int32): Vector[Program] =
        enumerateLevels(domain, 1, maxDepth, Vector.empty(), Vector.empty())

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
        start: Radii.Domain,
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
                }, compatible(start))
            else
                Vector.flatMap(program -> Vector.map(atom -> {
                    steps = Vector.append(program#steps, Vector#{atom}),
                    expression = Expr.Compose(program#expression, atom)
                }, compatible(target(program#expression))), previous);
            enumerateLevels(
                start,
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

    /// Apply one directed relation to the whole typed frontier. A cache miss is
    /// one physical transition; a hit is one transition reuse. Neither counter
    /// counts individual source edges, complete programs, or elapsed-time units.
    /// The cache hit still advances through the exact saved intermediate state;
    /// it merely avoids applying the repository relation again.
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
