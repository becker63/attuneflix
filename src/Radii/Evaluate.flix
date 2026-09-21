pub mod Radii.Evaluate {
    pub enum WorldId(String) with Eq, Order, ToString, Hash
    pub enum ExprId(Radii.Expr) with Eq, Order, ToString, Hash
    pub enum StateId(State) with Eq, Order, ToString, Hash
    pub enum DecisionId(String) with Eq, Order, ToString, Hash

    /// A state cannot pair a domain tag with members from another domain.
    pub enum State with Eq, Order, ToString, Hash {
        case Files(Set[Repository.Structure.FileId])
        case Symbols(Set[Repository.Structure.SymbolId])
        case Locations(Set[Repository.Structure.LocationId])
    }

    /// Production evaluation keeps immutable identity beside the physical world.
    /// It never solves or queries the Level-2 Datalog specification.
    pub enum World {
        case World(WorldId, Repository.Physical.World)
    }

    enum Step with Eq, Hash {
        case Forward(Radii.Atom)
        case Backward(Radii.Atom)
    }

    pub type alias Metrics = {
        logicalExpressions  = Int32,
        normalizedExpressions = Int32,
        uniqueStates        = Int32,
        physicalExpressions = Int32,
        physicalTransitions = Int32,
        transitionReuses    = Int32,
        subtreeReuses       = Int32
    }

    pub type alias Evaluation = {
        results = Map[Radii.Expr, State],
        metrics = Metrics
    }

    type alias Memos[r: Region] = {
        expressions = MutHashMap[(Radii.Expr, State), State, r],
        transitions = MutHashMap[(Step, State), State, r],
        exprIds      = MutHashSet[Radii.Expr, r],
        stateIds     = MutHashSet[State, r],
        transitionReuses = Ref[Int32, r],
        subtreeReuses    = Ref[Int32, r],
        physicalTransitions = Ref[Int32, r]
    }

    pub def fromBasis(
        id: WorldId,
        defines: Repository.Structure.Defines,
        imports: Repository.Structure.Imports,
        calls: Repository.Structure.Calls,
        parents: Repository.Structure.Parents
    ): World = {
        World.World(id, Repository.Physical.fromBasis(defines, imports, calls, parents))
    }

    pub def worldId(world: World): WorldId = let World.World(id, _) = world; id

    pub def exprId(expr: Radii.Expr): ExprId = ExprId.ExprId(Radii.normalize(expr))

    pub def stateId(state: State): StateId = StateId.StateId(state)

    /// Mutable hash tables are scoped to `rc`; the public evaluator is pure.
    pub def evaluateAll(world: World, input: State, candidates: List[Radii.Expr]): Result[String, Evaluation] = region rc {
        let memos: Memos[rc] = {
            expressions = MutHashMap.empty(rc),
            transitions = MutHashMap.empty(rc),
            exprIds = MutHashSet.empty(rc),
            stateIds = MutHashSet.singleton(rc, input),
            transitionReuses = Ref.fresh(rc, 0),
            subtreeReuses = Ref.fresh(rc, 0),
            physicalTransitions = Ref.fresh(rc, 0)
        };
        let compatible = List.filter(expr -> accepts(Radii.normalize(expr), input), candidates);
        match evaluateCandidates(world, input, compatible, Map.empty(), memos) {
            case Err(error) => Err(error)
            case Ok(results) => Ok({
                results = results,
                metrics = {
                    logicalExpressions = List.length(compatible),
                    normalizedExpressions = MutHashSet.size(memos#exprIds),
                    uniqueStates = MutHashSet.size(memos#stateIds),
                    physicalExpressions = MutHashMap.size(memos#expressions),
                    physicalTransitions = Ref.get(memos#physicalTransitions),
                    transitionReuses = Ref.get(memos#transitionReuses),
                    subtreeReuses = Ref.get(memos#subtreeReuses)
                }
            })
        }
    }

    def evaluateCandidates(
        world: World,
        input: State,
        candidates: List[Radii.Expr],
        results: Map[Radii.Expr, State],
        memos: Memos[r]
    ): Result[String, Map[Radii.Expr, State]] \ r = match candidates {
        case Nil => Ok(results)
        case raw :: rest => {
            let expr = Radii.normalize(raw);
            match evaluate(world, expr, input, memos) {
                case Err(error) => Err(error)
                case Ok(output) => evaluateCandidates(world, input, rest, Map.insert(expr, output, results), memos)
            }
        }
    }

    def evaluate(world: World, expr0: Radii.Expr, input: State, memos: Memos[r]): Result[String, State] \ r = {
        let expr = Radii.normalize(expr0);
        MutHashSet.add(expr, memos#exprIds);
        MutHashSet.add(input, memos#stateIds);
        match MutHashMap.get((expr, input), memos#expressions) {
            case Some(output) => {
                Ref.transform(x -> x + 1, memos#subtreeReuses);
                Ok(output)
            }
            case None => match evaluateFresh(world, expr, input, memos) {
                case Err(error) => Err(error)
                case Ok(output) => {
                    MutHashSet.add(output, memos#stateIds);
                    MutHashMap.put((expr, input), output, memos#expressions);
                    Ok(output)
                }
            }
        }
    }

    def evaluateFresh(world: World, expr: Radii.Expr, input: State, memos: Memos[r]): Result[String, State] \ r = match expr {
        case Radii.Expr.Atom(atom) => evaluateStep(world, Step.Forward(atom), input, memos)
        case Radii.Expr.Reverse(Radii.Expr.Atom(atom)) => evaluateStep(world, Step.Backward(atom), input, memos)
        case Radii.Expr.Reverse(_) => Err("normalization left a compound reverse")
        case Radii.Expr.Compose(left, right) => match evaluate(world, left, input, memos) {
            case Err(error) => Err(error)
            case Ok(middle) => evaluate(world, right, middle, memos)
        }
        case Radii.Expr.Union(left, right) => match evaluate(world, left, input, memos) {
            case Err(error) => Err(error)
            case Ok(a) => match evaluate(world, right, input, memos) {
                case Err(error) => Err(error)
                case Ok(b) => unionStates(a, b)
            }
        }
    }

    def evaluateStep(world: World, step: Step, input: State, memos: Memos[r]): Result[String, State] \ r =
        match MutHashMap.get((step, input), memos#transitions) {
            case Some(output) => {
                Ref.transform(x -> x + 1, memos#transitionReuses);
                Ok(output)
            }
            case None => match applyStep(world, step, input) {
                case Err(error) => Err(error)
                case Ok(output) => {
                    MutHashMap.put((step, input), output, memos#transitions);
                    Ref.transform(x -> x + 1, memos#physicalTransitions);
                    Ok(output)
                }
            }
        }

    def applyStep(world: World, step: Step, input: State): Result[String, State] =
        match step {
            case Step.Forward(atom) => applyForward(world, atom, input)
            case Step.Backward(atom) => applyBackward(world, atom, input)
        }

    /// Shared primitive physical semantics. Datalog remains the independent
    /// Level-2 oracle for these operations.
    pub def applyForward(world0: World, atom: Radii.Atom, input: State): Result[String, State] =
        let World.World(_, world) = world0;
        match (atom, input) {
        case (Radii.Atom.Defines, State.Files(xs)) =>
            Ok(State.Symbols(Repository.Physical.defines(world, xs)))
        case (Radii.Atom.DefinedIn, State.Symbols(xs)) =>
            Ok(State.Files(Repository.Physical.definedIn(world, xs)))
        case (Radii.Atom.Imports, State.Files(xs)) =>
            Ok(State.Files(Repository.Physical.imports(world, xs)))
        case (Radii.Atom.ImportedBy, State.Files(xs)) =>
            Ok(State.Files(Repository.Physical.importedBy(world, xs)))
        case (Radii.Atom.Calls, State.Symbols(xs)) =>
            Ok(State.Symbols(Repository.Physical.calls(world, xs)))
        case (Radii.Atom.Callees, State.Symbols(xs)) =>
            Ok(State.Symbols(Repository.Physical.calls(world, xs)))
        case (Radii.Atom.Callers, State.Symbols(xs)) =>
            Ok(State.Symbols(Repository.Physical.callers(world, xs)))
        case (Radii.Atom.SameFile, State.Symbols(xs)) =>
            Ok(State.Symbols(Repository.Physical.sameFile(world, xs)))
        case (Radii.Atom.ImportNeighbors, State.Symbols(xs)) =>
            Ok(State.Symbols(Repository.Physical.importNeighbors(world, xs)))
        case (Radii.Atom.ImporterNeighbors, State.Symbols(xs)) =>
            Ok(State.Symbols(Repository.Physical.importerNeighbors(world, xs)))
        case (Radii.Atom.Parent, State.Locations(xs)) =>
            Ok(State.Locations(Repository.Physical.parents(world, xs)))
        case (Radii.Atom.RepositoryAdjacent, State.Locations(xs)) =>
            Ok(State.Locations(Repository.Physical.repositoryAdjacent(world, xs)))
        case _ => Err("policy/input domain mismatch")
        }

    pub def applyBackward(world0: World, atom: Radii.Atom, input: State): Result[String, State] =
        let World.World(_, world) = world0;
        match (atom, input) {
        case (Radii.Atom.Defines, State.Symbols(xs)) =>
            Ok(State.Files(Repository.Physical.definedIn(world, xs)))
        case (Radii.Atom.DefinedIn, State.Files(xs)) =>
            Ok(State.Symbols(Repository.Physical.defines(world, xs)))
        case (Radii.Atom.Imports, State.Files(xs)) =>
            Ok(State.Files(Repository.Physical.importedBy(world, xs)))
        case (Radii.Atom.ImportedBy, State.Files(xs)) =>
            Ok(State.Files(Repository.Physical.imports(world, xs)))
        case (Radii.Atom.Calls, State.Symbols(xs)) =>
            Ok(State.Symbols(Repository.Physical.callers(world, xs)))
        case (Radii.Atom.Callees, State.Symbols(xs)) =>
            Ok(State.Symbols(Repository.Physical.callers(world, xs)))
        case (Radii.Atom.Callers, State.Symbols(xs)) =>
            Ok(State.Symbols(Repository.Physical.calls(world, xs)))
        case (Radii.Atom.SameFile, State.Symbols(xs)) =>
            Ok(State.Symbols(Repository.Physical.sameFile(world, xs)))
        case (Radii.Atom.ImportNeighbors, State.Symbols(xs)) =>
            Ok(State.Symbols(Repository.Physical.importerNeighbors(world, xs)))
        case (Radii.Atom.ImporterNeighbors, State.Symbols(xs)) =>
            Ok(State.Symbols(Repository.Physical.importNeighbors(world, xs)))
        case (Radii.Atom.Parent, State.Locations(xs)) =>
            Ok(State.Locations(Repository.Physical.children(world, xs)))
        case (Radii.Atom.RepositoryAdjacent, State.Locations(xs)) =>
            Ok(State.Locations(Repository.Physical.repositoryAdjacent(world, xs)))
        case _ => Err("reversed policy/input domain mismatch")
        }

    def unionStates(a: State, b: State): Result[String, State] = match (a, b) {
        case (State.Files(xs), State.Files(ys)) => Ok(State.Files(Set.union(xs, ys)))
        case (State.Symbols(xs), State.Symbols(ys)) => Ok(State.Symbols(Set.union(xs, ys)))
        case (State.Locations(xs), State.Locations(ys)) => Ok(State.Locations(Set.union(xs, ys)))
        case _ => Err("union produced incompatible domains")
    }

    def accepts(expr: Radii.Expr, state: State): Bool =
        let (source, _) = Radii.endpoints(expr);
        match (source, state) {
            case (Radii.Domain.File, State.Files(_)) => true
            case (Radii.Domain.Symbol, State.Symbols(_)) => true
            case (Radii.Domain.Location, State.Locations(_)) => true
            case _ => false
        }
}
