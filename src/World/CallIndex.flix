/// Call admission's physical lookup plan. The semantic rule is unchanged:
/// choose the narrowest enclosing definition as caller, then admit a uniquely
/// named local target or, when no local definition exists, a uniquely named
/// repository target. Indexing only removes the old full definition-vector
/// scans from every observed call.
pub mod World.CallIndex {
    type alias CallIndex = {
        byPath        = Map[String, Vector[World.Identity]],
        localTargets  = Map[(String, String), Set[Kernel.Contract.SymbolId]],
        globalTargets = Map[String, Set[Kernel.Contract.SymbolId]]
    }

    pub def resolveCalls(
        identities: Vector[World.Identity],
        facts: Vector[Repository.Grit.Fact]
    ): World.Resolution[Kernel.Contract.SymbolId, Kernel.Contract.SymbolId] = {
        let index = callIndex(identities);
        Vector.foldLeft((result, fact) -> match callEdge(index, fact) {
            case None => {edges = result#edges, rejected = result#rejected + 1}
            case Some(edge) => {edges = Set.insert(edge, result#edges), rejected = result#rejected}
        }, {edges = Set.empty(), rejected = 0}, facts)
    }

    def callEdge(index: CallIndex, call: Repository.Grit.Fact): Option[(Kernel.Contract.SymbolId, Kernel.Contract.SymbolId)] =
        match owner(index, call) {
            case None => None
            case Some(caller) =>
                let callee = String.replace(src = "?.", dst = ".", call#value);
                if (dynamic(callee)) None
                else target(index, call#path, simpleName(callee))
                    |> Option.map(found -> (caller, found))
        }

    def owner(index: CallIndex, call: Repository.Grit.Fact): Option[Kernel.Contract.SymbolId] =
        Vector.foldLeft((best, identity) -> match identity {
            case (definition, symbol) =>
                if (definition#startByte <= call#startByte and call#endByte <= definition#endByte)
                    narrowerOwner(best, definition#endByte - definition#startByte, symbol)
                else
                    best
        }, None, Map.getWithDefault(call#path, Vector.empty(), index#byPath))
        |> Option.map(match (_, symbol) -> symbol)

    def narrowerOwner(
        best: Option[(Int32, Kernel.Contract.SymbolId)],
        width: Int32,
        symbol: Kernel.Contract.SymbolId
    ): Option[(Int32, Kernel.Contract.SymbolId)] = match best {
        case None => Some((width, symbol))
        case Some((current, _)) if width < current => Some((width, symbol))
        case _ => best
    }

    def target(index: CallIndex, path: String, name: String): Option[Kernel.Contract.SymbolId] = {
        let local = Map.getWithDefault((path, name), Set.empty(), index#localTargets);
        if (Set.size(local) == 1)
            Some(Vector.get(0, Set.toVector(local)))
        else if (Set.size(local) > 0)
            None
        else {
            let global = Map.getWithDefault(name, Set.empty(), index#globalTargets);
            if (Set.size(global) == 1) Some(Vector.get(0, Set.toVector(global))) else None
        }
    }

    def callIndex(identities: Vector[World.Identity]): CallIndex =
        Vector.foldLeft((index, identity) -> {
            let (fact, symbol) = identity;
            {
                byPath = Map.insert(fact#path,
                    Vector.append(Map.getWithDefault(fact#path, Vector.empty(), index#byPath),
                        Vector#{identity}), index#byPath),
                localTargets = Map.insert((fact#path, fact#value),
                    Set.insert(symbol, Map.getWithDefault((fact#path, fact#value), Set.empty(),
                        index#localTargets)), index#localTargets),
                globalTargets = Map.insert(fact#value,
                    Set.insert(symbol, Map.getWithDefault(fact#value, Set.empty(), index#globalTargets)),
                    index#globalTargets)
            }
        }, {
            byPath = Map.empty(),
            localTargets = Map.empty(),
            globalTargets = Map.empty()
        }, identities)

    /// A call whose callee text still carries syntax (a call, index, literal,
    /// or template marker) is not a static reference and is never admitted.
    def dynamic(callee: String): Bool =
        List.exists(marker -> String.contains(substr = marker, callee),
            "(" :: "[" :: "{" :: "'" :: "\"" :: "`" :: "\n" :: Nil)

    def simpleName(callee: String): String = match String.indexOfRight(substr = ".", callee) {
        case None => callee
        case Some(index) => String.sliceRight(start = index + 1, callee)
    }
}
