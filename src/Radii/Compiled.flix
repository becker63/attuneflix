pub mod Radii.Compiled {
    /// Stable only within one compiled policy family.
    pub enum NodeId(Int32) with Eq, Order, ToString, Hash

    /// Stable only within one query-local state arena.
    pub enum ArenaStateId(Int32) with Eq, Order, ToString, Hash

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

    pub def nodeCount(program: Program): Int32 = Vector.length(program#nodes)

    pub def rootCount(program: Program): Int32 = Vector.length(program#roots)

    /// The state arena and dense memo are fresh for every call.
    pub def evaluate(
        world: Radii.Evaluate.World,
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

    /// Compatibility/debug projection. Production callers should consume the
    /// root-aligned compact outputs directly.
    pub def materializeLegacy(
        program: Program,
        evaluation: Evaluation
    ): Map[Radii.Expr, Radii.Evaluate.State] =
        materialize(program, evaluation, 0, Map.empty())

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
        world: Radii.Evaluate.World,
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
        world: Radii.Evaluate.World,
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
        world: Radii.Evaluate.World,
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

    def materialize(
        program: Program,
        evaluation: Evaluation,
        index: Int32,
        result: Map[Radii.Expr, Radii.Evaluate.State]
    ): Map[Radii.Expr, Radii.Evaluate.State] =
        if (index >= Vector.length(program#roots)) result
        else {
            let root = Vector.get(index, program#roots);
            let output = Vector.get(index, evaluation#outputs);
            materialize(program, evaluation, index + 1,
                Map.insert(root#expression, state(evaluation, output), result))
        }

    def unionStates(a: Radii.Evaluate.State, b: Radii.Evaluate.State): Result[String, Radii.Evaluate.State] =
        match (a, b) {
            case (Radii.Evaluate.State.Files(xs), Radii.Evaluate.State.Files(ys)) => Ok(Radii.Evaluate.State.Files(Set.union(xs, ys)))
            case (Radii.Evaluate.State.Symbols(xs), Radii.Evaluate.State.Symbols(ys)) => Ok(Radii.Evaluate.State.Symbols(Set.union(xs, ys)))
            case (Radii.Evaluate.State.Locations(xs), Radii.Evaluate.State.Locations(ys)) => Ok(Radii.Evaluate.State.Locations(Set.union(xs, ys)))
            case _ => Err("compiled union produced incompatible domains")
        }

}
