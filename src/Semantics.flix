mod Semantics {
    pub enum WorldId(String) with Eq, Order, ToString, Hash
    pub enum ExprId(Policy.Expr) with Eq, Order, ToString, Hash
    pub enum StateId(State) with Eq, Order, ToString, Hash
    pub enum DecisionId(String) with Eq, Order, ToString, Hash

    /// A state cannot pair a domain tag with members from another domain.
    pub enum State with Eq, Order, ToString, Hash {
        case Files(Set[Structure.FileId])
        case Symbols(Set[Structure.SymbolId])
        case Locations(Set[Structure.LocationId])
    }

    /// Production evaluation keeps immutable identity beside the physical world.
    /// It never solves or queries the Level-2 Datalog specification.
    pub enum World {
        case World(WorldId, Physical.World)
    }

    enum Step with Eq, Hash {
        case Forward(Policy.Atom)
        case Backward(Policy.Atom)
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
        results = Map[Policy.Expr, State],
        metrics = Metrics
    }

    type alias Memos[r: Region] = {
        expressions = MutHashMap[(Policy.Expr, State), State, r],
        transitions = MutHashMap[(Step, State), State, r],
        exprIds      = MutHashSet[Policy.Expr, r],
        stateIds     = MutHashSet[State, r],
        transitionReuses = Ref[Int32, r],
        subtreeReuses    = Ref[Int32, r],
        physicalTransitions = Ref[Int32, r]
    }

    pub def fromBasis(
        id: WorldId,
        defines: Structure.Defines,
        imports: Structure.Imports,
        calls: Structure.Calls,
        parents: Structure.Parents
    ): World = {
        World.World(id, Physical.fromBasis(defines, imports, calls, parents))
    }

    pub def worldId(world: World): WorldId = let World.World(id, _) = world; id

    pub def exprId(expr: Policy.Expr): ExprId = ExprId.ExprId(Policy.normalize(expr))

    pub def stateId(state: State): StateId = StateId.StateId(state)

    /// Mutable hash tables are scoped to `rc`; the public evaluator is pure.
    pub def evaluateAll(world: World, input: State, candidates: List[Policy.Expr]): Result[String, Evaluation] = region rc {
        let memos: Memos[rc] = {
            expressions = MutHashMap.empty(rc),
            transitions = MutHashMap.empty(rc),
            exprIds = MutHashSet.empty(rc),
            stateIds = MutHashSet.singleton(rc, input),
            transitionReuses = Ref.fresh(rc, 0),
            subtreeReuses = Ref.fresh(rc, 0),
            physicalTransitions = Ref.fresh(rc, 0)
        };
        let compatible = List.filter(expr -> accepts(Policy.normalize(expr), input), candidates);
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
        candidates: List[Policy.Expr],
        results: Map[Policy.Expr, State],
        memos: Memos[r]
    ): Result[String, Map[Policy.Expr, State]] \ r = match candidates {
        case Nil => Ok(results)
        case raw :: rest => {
            let expr = Policy.normalize(raw);
            match evaluate(world, expr, input, memos) {
                case Err(error) => Err(error)
                case Ok(output) => evaluateCandidates(world, input, rest, Map.insert(expr, output, results), memos)
            }
        }
    }

    def evaluate(world: World, expr0: Policy.Expr, input: State, memos: Memos[r]): Result[String, State] \ r = {
        let expr = Policy.normalize(expr0);
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

    def evaluateFresh(world: World, expr: Policy.Expr, input: State, memos: Memos[r]): Result[String, State] \ r = match expr {
        case Policy.Expr.Atom(atom) => evaluateStep(world, Step.Forward(atom), input, memos)
        case Policy.Expr.Reverse(Policy.Expr.Atom(atom)) => evaluateStep(world, Step.Backward(atom), input, memos)
        case Policy.Expr.Reverse(_) => Err("normalization left a compound reverse")
        case Policy.Expr.Compose(left, right) => match evaluate(world, left, input, memos) {
            case Err(error) => Err(error)
            case Ok(middle) => evaluate(world, right, middle, memos)
        }
        case Policy.Expr.Union(left, right) => match evaluate(world, left, input, memos) {
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
        let World.World(_, physical) = world;
        match step {
            case Step.Forward(atom) => applyForward(physical, atom, input)
            case Step.Backward(atom) => applyBackward(physical, atom, input)
        }

    def applyForward(world: Physical.World, atom: Policy.Atom, input: State): Result[String, State] = match (atom, input) {
        case (Policy.Atom.Defines, State.Files(xs)) =>
            Ok(State.Symbols(Physical.defines(world, xs)))
        case (Policy.Atom.DefinedIn, State.Symbols(xs)) =>
            Ok(State.Files(Physical.definedIn(world, xs)))
        case (Policy.Atom.Imports, State.Files(xs)) =>
            Ok(State.Files(Physical.imports(world, xs)))
        case (Policy.Atom.ImportedBy, State.Files(xs)) =>
            Ok(State.Files(Physical.importedBy(world, xs)))
        case (Policy.Atom.Calls, State.Symbols(xs)) =>
            Ok(State.Symbols(Physical.calls(world, xs)))
        case (Policy.Atom.Callees, State.Symbols(xs)) =>
            Ok(State.Symbols(Physical.calls(world, xs)))
        case (Policy.Atom.Callers, State.Symbols(xs)) =>
            Ok(State.Symbols(Physical.callers(world, xs)))
        case (Policy.Atom.SameFile, State.Symbols(xs)) =>
            Ok(State.Symbols(Physical.sameFile(world, xs)))
        case (Policy.Atom.ImportNeighbors, State.Symbols(xs)) =>
            Ok(State.Symbols(Physical.importNeighbors(world, xs)))
        case (Policy.Atom.ImporterNeighbors, State.Symbols(xs)) =>
            Ok(State.Symbols(Physical.importerNeighbors(world, xs)))
        case (Policy.Atom.Parent, State.Locations(xs)) =>
            Ok(State.Locations(Physical.parents(world, xs)))
        case (Policy.Atom.RepositoryAdjacent, State.Locations(xs)) =>
            Ok(State.Locations(Physical.repositoryAdjacent(world, xs)))
        case _ => Err("policy/input domain mismatch")
    }

    def applyBackward(world: Physical.World, atom: Policy.Atom, input: State): Result[String, State] = match (atom, input) {
        case (Policy.Atom.Defines, State.Symbols(xs)) =>
            Ok(State.Files(Physical.definedIn(world, xs)))
        case (Policy.Atom.DefinedIn, State.Files(xs)) =>
            Ok(State.Symbols(Physical.defines(world, xs)))
        case (Policy.Atom.Imports, State.Files(xs)) =>
            Ok(State.Files(Physical.importedBy(world, xs)))
        case (Policy.Atom.ImportedBy, State.Files(xs)) =>
            Ok(State.Files(Physical.imports(world, xs)))
        case (Policy.Atom.Calls, State.Symbols(xs)) =>
            Ok(State.Symbols(Physical.callers(world, xs)))
        case (Policy.Atom.Callees, State.Symbols(xs)) =>
            Ok(State.Symbols(Physical.callers(world, xs)))
        case (Policy.Atom.Callers, State.Symbols(xs)) =>
            Ok(State.Symbols(Physical.calls(world, xs)))
        case (Policy.Atom.SameFile, State.Symbols(xs)) =>
            Ok(State.Symbols(Physical.sameFile(world, xs)))
        case (Policy.Atom.ImportNeighbors, State.Symbols(xs)) =>
            Ok(State.Symbols(Physical.importerNeighbors(world, xs)))
        case (Policy.Atom.ImporterNeighbors, State.Symbols(xs)) =>
            Ok(State.Symbols(Physical.importNeighbors(world, xs)))
        case (Policy.Atom.Parent, State.Locations(xs)) =>
            Ok(State.Locations(Physical.children(world, xs)))
        case (Policy.Atom.RepositoryAdjacent, State.Locations(xs)) =>
            Ok(State.Locations(Physical.repositoryAdjacent(world, xs)))
        case _ => Err("reversed policy/input domain mismatch")
    }

    def unionStates(a: State, b: State): Result[String, State] = match (a, b) {
        case (State.Files(xs), State.Files(ys)) => Ok(State.Files(Set.union(xs, ys)))
        case (State.Symbols(xs), State.Symbols(ys)) => Ok(State.Symbols(Set.union(xs, ys)))
        case (State.Locations(xs), State.Locations(ys)) => Ok(State.Locations(Set.union(xs, ys)))
        case _ => Err("union produced incompatible domains")
    }

    def accepts(expr: Policy.Expr, state: State): Bool =
        let (source, _) = Policy.endpoints(expr);
        match (source, state) {
            case (Policy.Domain.File, State.Files(_)) => true
            case (Policy.Domain.Symbol, State.Symbols(_)) => true
            case (Policy.Domain.Location, State.Locations(_)) => true
            case _ => false
        }
}
