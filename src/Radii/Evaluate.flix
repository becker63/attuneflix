pub mod Radii.Evaluate {
    /// A state cannot pair a domain tag with members from another domain.
    pub enum State with Eq, Order, ToString, Hash {
        case Files(Set[Repository.Structure.FileId])
        case Symbols(Set[Repository.Structure.SymbolId])
        case Locations(Set[Repository.Structure.LocationId])
    }

    /// Stable only within one compiled policy family.
    pub enum NodeId(Int32) with Eq, Order, ToString, Hash

    /// Stable only within one query-local state arena.
    pub enum ArenaStateId(Int32) with Eq, Order, ToString, Hash

    /// Static syntax sharing. Equal normalized subexpressions receive one
    /// NodeId even when many logical roots contain them. This is distinct from
    /// Atlas's runtime fact that different syntax can converge to one state.
    pub enum Node with Eq, Order, ToString, Hash {
        case Forward(Radii.Atom),
        case Backward(Radii.Atom),
        case Compose(NodeId, NodeId),
        case Union(NodeId, NodeId)
    }

    pub type alias Root = {
        expression = Radii.Expr,
        node = NodeId
    }

    pub type alias Program = {
        nodes = Vector[Node],
        roots = Vector[Root]
    }

    pub type alias Metrics = {
        statesInterned = Int32,
        memoEntries = Int32,
        memoSlots = Int32
    }

    /// Outputs are positionally aligned with `Program.roots`.
    pub type alias Evaluation = {
        outputs = Vector[ArenaStateId],
        arena = Vector[Radii.Evaluate.State],
        metrics = Metrics
    }

    type alias CompileBuild = {
        ids = Map[Radii.Expr, NodeId],
        nodes = Vector[Node],
        roots = List[Root]
    }

    type alias DenseMemo[r: Region] = {
        rc = Region[r],
        rows = Array[Option[MutList[Int32, r]], r],
        entries = Ref[Int32, r],
        slots = Ref[Int32, r]
    }

    type alias Memos[r: Region] = {
        values = DenseMemo[r],
        states = MutList[Radii.Evaluate.State, r],
        stateIds = MutHashMap[Radii.Evaluate.State, Int32, r]
    }

    /// Normalization and structural-expression hashing occur only here.
    pub def compile(candidates: List[Radii.Expr]): Program = {
        let initial = {ids = Map.empty(), nodes = Vector.empty(), roots = Nil};
        let build = compileRoots(candidates, initial);
        {nodes = build#nodes, roots = List.reverse(build#roots) |> List.toVector}
    }

    /// The state arena and dense memo are fresh for every call. `NodeId` shares
    /// repeated syntax; `ArenaStateId` interns equal typed frontiers; the dense
    /// `(NodeId, ArenaStateId)` table can skip a cached multi-node subtree in
    /// one lookup. None of these private IDs changes Radii or Atlas meaning.
    /// This is the coarse physical shortcut that can coexist with a stable
    /// Atom-level scientific model.
    pub def evaluate(
        world: Repository.Physical.World,
        input: Radii.Evaluate.State,
        program: Program
    ): Result[String, Evaluation] = region rc {
        let states = MutList.emptyWithCapacity(rc, 64);
        let table = denseMemo(rc, Vector.length(program#nodes));
        let memos = {
            values = table,
            states = states,
            stateIds = MutHashMap.emptyWithCapacity(rc, 64)
        };
        let outputs = MutList.emptyWithCapacity(rc, Vector.length(program#roots));
        let inputId = internState(input, memos);
        match evaluateRoots(world, inputId, program, 0, outputs, memos) {
            case Err(error) => Err(error)
            case Ok(_) => Ok({
                outputs = MutList.toVector(outputs),
                arena = MutList.toVector(states),
                metrics = {
                    statesInterned = MutList.length(states),
                    memoEntries = Ref.get(table#entries),
                    memoSlots = Ref.get(table#slots)
                }
            })
        }
    }

    pub def state(evaluation: Evaluation, id: ArenaStateId): Radii.Evaluate.State = {
        let ArenaStateId.ArenaStateId(index) = id;
        Vector.get(index, evaluation#arena)
    }

    def compileRoots(candidates: List[Radii.Expr], build: CompileBuild): CompileBuild =
        match candidates {
            case Nil => build
            case raw :: rest => {
                let expression = Radii.normalize(raw);
                let (id, next) = compileExpression(expression, build);
                compileRoots(rest, {
                    ids = next#ids,
                    nodes = next#nodes,
                    roots = {expression = expression, node = id} :: next#roots
                })
            }
        }

    def compileExpression(expression: Radii.Expr, build: CompileBuild): (NodeId, CompileBuild) =
        match Map.get(expression, build#ids) {
            case Some(id) => (id, build)
            case None => match expression {
                case Radii.Expr.Atom(atom) => addNode(expression, Node.Forward(atom), build)
                case Radii.Expr.Reverse(Radii.Expr.Atom(atom)) =>
                    addNode(expression, Node.Backward(atom), build)
                case Radii.Expr.Reverse(_) => unreachable!()
                case Radii.Expr.Compose(left, right) => {
                    let (leftId, afterLeft) = compileExpression(left, build);
                    let (rightId, afterRight) = compileExpression(right, afterLeft);
                    addNode(expression, Node.Compose(leftId, rightId), afterRight)
                }
                case Radii.Expr.Union(left, right) => {
                    let (leftId, afterLeft) = compileExpression(left, build);
                    let (rightId, afterRight) = compileExpression(right, afterLeft);
                    addNode(expression, Node.Union(leftId, rightId), afterRight)
                }
            }
        }

    def addNode(expression: Radii.Expr, node: Node, build: CompileBuild): (NodeId, CompileBuild) = {
        let id = NodeId.NodeId(Vector.length(build#nodes));
        (id, {
            ids = Map.insert(expression, id, build#ids),
            nodes = Vector.append(build#nodes, Vector#{node}),
            roots = build#roots
        })
    }

    def evaluateRoots(
        world: Repository.Physical.World,
        inputId: Int32,
        program: Program,
        index: Int32,
        outputs: MutList[ArenaStateId, r],
        memos: Memos[r]
    ): Result[String, Unit] \ r =
        if (index >= Vector.length(program#roots)) Ok(())
        else {
            let root = Vector.get(index, program#roots);
            match evaluateNode(world, root#node, inputId, program, memos) {
                case Err(error) => Err(error)
                case Ok(outputId) => {
                    MutList.push(ArenaStateId.ArenaStateId(outputId), outputs);
                    evaluateRoots(world, inputId, program, index + 1, outputs, memos)
                }
            }
        }

    def evaluateNode(
        world: Repository.Physical.World,
        nodeId: NodeId,
        inputId: Int32,
        program: Program,
        memos: Memos[r]
    ): Result[String, Int32] \ r = {
        let NodeId.NodeId(index) = nodeId;
        let cached = denseGet(index, inputId, memos#values);
        if (cached >= 0) Ok(cached)
        else match evaluateFresh(world, Vector.get(index, program#nodes), inputId, program, memos) {
            case Err(error) => Err(error)
            case Ok(outputId) => {
                densePut(index, inputId, outputId, memos#values);
                Ok(outputId)
            }
        }
    }

    def evaluateFresh(
        world: Repository.Physical.World,
        node: Node,
        inputId: Int32,
        program: Program,
        memos: Memos[r]
    ): Result[String, Int32] \ r = match node {
        case Node.Forward(atom) =>
            Radii.Evaluate.applyForward(world, atom, MutList.get(inputId, memos#states))
            |> Result.map(output -> internState(output, memos))
        case Node.Backward(atom) =>
            Radii.Evaluate.applyBackward(world, atom, MutList.get(inputId, memos#states))
            |> Result.map(output -> internState(output, memos))
        case Node.Compose(left, right) =>
            evaluateNode(world, left, inputId, program, memos)
            |> Result.flatMap(middleId -> evaluateNode(world, right, middleId, program, memos))
        case Node.Union(left, right) => forM (
            aId <- evaluateNode(world, left, inputId, program, memos);
            bId <- evaluateNode(world, right, inputId, program, memos);
            output <- unionStates(MutList.get(aId, memos#states), MutList.get(bId, memos#states))
        ) yield internState(output, memos)
    }

    def internState(state0: Radii.Evaluate.State, memos: Memos[r]): Int32 \ r =
        match MutHashMap.get(state0, memos#stateIds) {
            case Some(id) => id
            case None => {
                let id = MutList.length(memos#states);
                MutHashMap.put(state0, id, memos#stateIds);
                MutList.push(state0, memos#states);
                id
            }
        }

    def denseMemo(rc: Region[r], nodeCount: Int32): DenseMemo[r] \ r = {
        rc = rc,
        rows = Array.repeat(rc, nodeCount, None),
        entries = Ref.fresh(rc, 0),
        slots = Ref.fresh(rc, 0)
    }

    def denseGet(nodeId: Int32, stateId: Int32, memo: DenseMemo[r]): Int32 \ r =
        match Array.get(nodeId, memo#rows) {
            case None => -1
            case Some(row) => if (stateId < MutList.length(row)) MutList.get(stateId, row) else -1
        }

    def densePut(nodeId: Int32, stateId: Int32, outputId: Int32, memo: DenseMemo[r]): Unit \ r = {
        let row = match Array.get(nodeId, memo#rows) {
            case Some(existing) => existing
            case None => {
                let fresh = MutList.empty(memo#rc);
                Array.put(Some(fresh), nodeId, memo#rows);
                fresh
            }
        };
        let before = MutList.length(row);
        extendDenseRow(row, stateId);
        let previous = MutList.get(stateId, row);
        if (previous < 0) Ref.transform(n -> n + 1, memo#entries) else ();
        if (before <= stateId) Ref.transform(n -> n + stateId + 1 - before, memo#slots) else ();
        MutList.put(outputId, stateId, row)
    }

    def extendDenseRow(row: MutList[Int32, r], stateId: Int32): Unit \ r =
        if (MutList.length(row) > stateId) ()
        else {
            MutList.push(-1, row);
            extendDenseRow(row, stateId)
        }

    /// Shared primitive physical semantics. Datalog remains the independent
    /// Level-2 oracle for these operations.
    pub def applyForward(world: Repository.Physical.World, atom: Radii.Atom, input: State): Result[String, State] = {
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
    }

    pub def applyBackward(world: Repository.Physical.World, atom: Radii.Atom, input: State): Result[String, State] = {
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
    }

    def unionStates(a: Radii.Evaluate.State, b: Radii.Evaluate.State): Result[String, Radii.Evaluate.State] =
        match (a, b) {
            case (Radii.Evaluate.State.Files(xs), Radii.Evaluate.State.Files(ys)) => Ok(Radii.Evaluate.State.Files(Set.union(xs, ys)))
            case (Radii.Evaluate.State.Symbols(xs), Radii.Evaluate.State.Symbols(ys)) => Ok(Radii.Evaluate.State.Symbols(Set.union(xs, ys)))
            case (Radii.Evaluate.State.Locations(xs), Radii.Evaluate.State.Locations(ys)) => Ok(Radii.Evaluate.State.Locations(Set.union(xs, ys)))
            case _ => Err("compiled union produced incompatible domains")
        }

}
