pub mod Repository.Reference {
    /// Level 2 is built only for verification, research, and selected debug runs.
    pub def fromBasis(
        defines: Repository.Structure.Defines,
        imports: Repository.Structure.Imports,
        calls: Repository.Structure.Calls,
        parents: Repository.Structure.Parents
    ): Repository.Structure.Repository =
        solve Repository.Structure.repositoryFacts(defines, imports, calls, parents), Repository.Structure.structuralRules()

    /// Interprets raw syntax directly. In particular, this does not call the
    /// normalizer, so it can independently check normalization laws.
    pub def evaluate(
        repository: Repository.Structure.Repository,
        expr: Radii.Expr,
        input: Radii.Evaluate.State
    ): Result[String, Radii.Evaluate.State] = evaluateForward(repository, expr, input)

    def evaluateForward(
        repository: Repository.Structure.Repository,
        expr: Radii.Expr,
        input: Radii.Evaluate.State
    ): Result[String, Radii.Evaluate.State] = match expr {
        case Radii.Expr.Atom(atom) => applyForward(repository, atom, input)
        case Radii.Expr.Reverse(inner) => evaluateBackward(repository, inner, input)
        case Radii.Expr.Compose(left, right) => match evaluateForward(repository, left, input) {
            case Err(error) => Err(error)
            case Ok(middle) => evaluateForward(repository, right, middle)
        }
        case Radii.Expr.Union(left, right) => match evaluateForward(repository, left, input) {
            case Err(error) => Err(error)
            case Ok(a) => match evaluateForward(repository, right, input) {
                case Err(error) => Err(error)
                case Ok(b) => unionStates(a, b)
            }
        }
    }

    def evaluateBackward(
        repository: Repository.Structure.Repository,
        expr: Radii.Expr,
        input: Radii.Evaluate.State
    ): Result[String, Radii.Evaluate.State] = match expr {
        case Radii.Expr.Atom(atom) => applyBackward(repository, atom, input)
        case Radii.Expr.Reverse(inner) => evaluateForward(repository, inner, input)
        case Radii.Expr.Compose(left, right) => match evaluateBackward(repository, right, input) {
            case Err(error) => Err(error)
            case Ok(middle) => evaluateBackward(repository, left, middle)
        }
        case Radii.Expr.Union(left, right) => match evaluateBackward(repository, left, input) {
            case Err(error) => Err(error)
            case Ok(a) => match evaluateBackward(repository, right, input) {
                case Err(error) => Err(error)
                case Ok(b) => unionStates(a, b)
            }
        }
    }

    def applyForward(repository: Repository.Structure.Repository, atom: Radii.Atom, input: Radii.Evaluate.State): Result[String, Radii.Evaluate.State] = match (atom, input) {
        case (Radii.Atom.Defines, Radii.Evaluate.State.Files(xs)) =>
            Ok(Radii.Evaluate.State.Symbols(apply(query repository select (x, y) from Defines(x, y) |> Vector.toSet, xs)))
        case (Radii.Atom.DefinedIn, Radii.Evaluate.State.Symbols(xs)) =>
            Ok(Radii.Evaluate.State.Files(apply(query repository select (x, y) from DefinedIn(x, y) |> Vector.toSet, xs)))
        case (Radii.Atom.Imports, Radii.Evaluate.State.Files(xs)) =>
            Ok(Radii.Evaluate.State.Files(apply(query repository select (x, y) from Imports(x, y) |> Vector.toSet, xs)))
        case (Radii.Atom.ImportedBy, Radii.Evaluate.State.Files(xs)) =>
            Ok(Radii.Evaluate.State.Files(apply(query repository select (x, y) from ImportedBy(x, y) |> Vector.toSet, xs)))
        case (Radii.Atom.Calls, Radii.Evaluate.State.Symbols(xs)) =>
            Ok(Radii.Evaluate.State.Symbols(apply(query repository select (x, y) from Calls(x, y) |> Vector.toSet, xs)))
        case (Radii.Atom.Callees, Radii.Evaluate.State.Symbols(xs)) =>
            Ok(Radii.Evaluate.State.Symbols(apply(query repository select (x, y) from Calls(x, y) |> Vector.toSet, xs)))
        case (Radii.Atom.Callers, Radii.Evaluate.State.Symbols(xs)) =>
            Ok(Radii.Evaluate.State.Symbols(apply(query repository select (x, y) from Caller(x, y) |> Vector.toSet, xs)))
        case (Radii.Atom.SameFile, Radii.Evaluate.State.Symbols(xs)) =>
            Ok(Radii.Evaluate.State.Symbols(apply(query repository select (x, y) from SameFile(x, y) |> Vector.toSet, xs)))
        case (Radii.Atom.ImportNeighbors, Radii.Evaluate.State.Symbols(xs)) =>
            Ok(Radii.Evaluate.State.Symbols(apply(query repository select (x, y) from ImportNeighbor(x, y) |> Vector.toSet, xs)))
        case (Radii.Atom.ImporterNeighbors, Radii.Evaluate.State.Symbols(xs)) =>
            Ok(Radii.Evaluate.State.Symbols(apply(query repository select (x, y) from ImporterNeighbor(x, y) |> Vector.toSet, xs)))
        case (Radii.Atom.Parent, Radii.Evaluate.State.Locations(xs)) =>
            Ok(Radii.Evaluate.State.Locations(apply(query repository select (x, y) from Parent(x, y) |> Vector.toSet, xs)))
        case (Radii.Atom.RepositoryAdjacent, Radii.Evaluate.State.Locations(xs)) =>
            Ok(Radii.Evaluate.State.Locations(apply(query repository select (x, y) from RepositoryAdjacent(x, y) |> Vector.toSet, xs)))
        case _ => Err("reference policy/input domain mismatch")
    }

    def applyBackward(repository: Repository.Structure.Repository, atom: Radii.Atom, input: Radii.Evaluate.State): Result[String, Radii.Evaluate.State] = match (atom, input) {
        case (Radii.Atom.Defines, Radii.Evaluate.State.Symbols(xs)) =>
            Ok(Radii.Evaluate.State.Files(apply(reverse(query repository select (x, y) from Defines(x, y) |> Vector.toSet), xs)))
        case (Radii.Atom.DefinedIn, Radii.Evaluate.State.Files(xs)) =>
            Ok(Radii.Evaluate.State.Symbols(apply(reverse(query repository select (x, y) from DefinedIn(x, y) |> Vector.toSet), xs)))
        case (Radii.Atom.Imports, Radii.Evaluate.State.Files(xs)) =>
            Ok(Radii.Evaluate.State.Files(apply(reverse(query repository select (x, y) from Imports(x, y) |> Vector.toSet), xs)))
        case (Radii.Atom.ImportedBy, Radii.Evaluate.State.Files(xs)) =>
            Ok(Radii.Evaluate.State.Files(apply(reverse(query repository select (x, y) from ImportedBy(x, y) |> Vector.toSet), xs)))
        case (Radii.Atom.Calls, Radii.Evaluate.State.Symbols(xs)) =>
            Ok(Radii.Evaluate.State.Symbols(apply(reverse(query repository select (x, y) from Calls(x, y) |> Vector.toSet), xs)))
        case (Radii.Atom.Callees, Radii.Evaluate.State.Symbols(xs)) =>
            Ok(Radii.Evaluate.State.Symbols(apply(reverse(query repository select (x, y) from Calls(x, y) |> Vector.toSet), xs)))
        case (Radii.Atom.Callers, Radii.Evaluate.State.Symbols(xs)) =>
            Ok(Radii.Evaluate.State.Symbols(apply(reverse(query repository select (x, y) from Caller(x, y) |> Vector.toSet), xs)))
        case (Radii.Atom.SameFile, Radii.Evaluate.State.Symbols(xs)) =>
            Ok(Radii.Evaluate.State.Symbols(apply(reverse(query repository select (x, y) from SameFile(x, y) |> Vector.toSet), xs)))
        case (Radii.Atom.ImportNeighbors, Radii.Evaluate.State.Symbols(xs)) =>
            Ok(Radii.Evaluate.State.Symbols(apply(reverse(query repository select (x, y) from ImportNeighbor(x, y) |> Vector.toSet), xs)))
        case (Radii.Atom.ImporterNeighbors, Radii.Evaluate.State.Symbols(xs)) =>
            Ok(Radii.Evaluate.State.Symbols(apply(reverse(query repository select (x, y) from ImporterNeighbor(x, y) |> Vector.toSet), xs)))
        case (Radii.Atom.Parent, Radii.Evaluate.State.Locations(xs)) =>
            Ok(Radii.Evaluate.State.Locations(apply(reverse(query repository select (x, y) from Parent(x, y) |> Vector.toSet), xs)))
        case (Radii.Atom.RepositoryAdjacent, Radii.Evaluate.State.Locations(xs)) =>
            Ok(Radii.Evaluate.State.Locations(apply(reverse(query repository select (x, y) from RepositoryAdjacent(x, y) |> Vector.toSet), xs)))
        case _ => Err("reversed reference policy/input domain mismatch")
    }

    def reverse(edges: Repository.Structure.Relation[a, b]): Repository.Structure.Relation[b, a] with Order[a], Order[b] =
        Set.map(match (source, target) -> (target, source), edges)

    def apply(edges: Repository.Structure.Relation[a, b], input: Set[a]): Set[b] with Order[a], Order[b] =
        Set.foldLeft((output, edge) -> {
            let (source, target) = edge;
            if (Set.memberOf(source, input)) Set.insert(target, output) else output
        }, Set.empty(), edges)

    def unionStates(a: Radii.Evaluate.State, b: Radii.Evaluate.State): Result[String, Radii.Evaluate.State] = match (a, b) {
        case (Radii.Evaluate.State.Files(xs), Radii.Evaluate.State.Files(ys)) => Ok(Radii.Evaluate.State.Files(Set.union(xs, ys)))
        case (Radii.Evaluate.State.Symbols(xs), Radii.Evaluate.State.Symbols(ys)) => Ok(Radii.Evaluate.State.Symbols(Set.union(xs, ys)))
        case (Radii.Evaluate.State.Locations(xs), Radii.Evaluate.State.Locations(ys)) => Ok(Radii.Evaluate.State.Locations(Set.union(xs, ys)))
        case _ => Err("reference union produced incompatible domains")
    }
}
