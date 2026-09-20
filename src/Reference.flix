mod Reference {
    /// Level 2 is built only for verification, research, and selected debug runs.
    pub def fromBasis(
        defines: Structure.Defines,
        imports: Structure.Imports,
        calls: Structure.Calls,
        parents: Structure.Parents
    ): Structure.Repository =
        solve Structure.repositoryFacts(defines, imports, calls, parents), Structure.structuralRules()

    /// Interprets raw syntax directly. In particular, this does not call the
    /// normalizer, so it can independently check normalization laws.
    pub def evaluate(
        repository: Structure.Repository,
        expr: Policy.Expr,
        input: Semantics.State
    ): Result[String, Semantics.State] = evaluateForward(repository, expr, input)

    def evaluateForward(
        repository: Structure.Repository,
        expr: Policy.Expr,
        input: Semantics.State
    ): Result[String, Semantics.State] = match expr {
        case Policy.Expr.Atom(atom) => applyForward(repository, atom, input)
        case Policy.Expr.Reverse(inner) => evaluateBackward(repository, inner, input)
        case Policy.Expr.Compose(left, right) => match evaluateForward(repository, left, input) {
            case Err(error) => Err(error)
            case Ok(middle) => evaluateForward(repository, right, middle)
        }
        case Policy.Expr.Union(left, right) => match evaluateForward(repository, left, input) {
            case Err(error) => Err(error)
            case Ok(a) => match evaluateForward(repository, right, input) {
                case Err(error) => Err(error)
                case Ok(b) => unionStates(a, b)
            }
        }
    }

    def evaluateBackward(
        repository: Structure.Repository,
        expr: Policy.Expr,
        input: Semantics.State
    ): Result[String, Semantics.State] = match expr {
        case Policy.Expr.Atom(atom) => applyBackward(repository, atom, input)
        case Policy.Expr.Reverse(inner) => evaluateForward(repository, inner, input)
        case Policy.Expr.Compose(left, right) => match evaluateBackward(repository, right, input) {
            case Err(error) => Err(error)
            case Ok(middle) => evaluateBackward(repository, left, middle)
        }
        case Policy.Expr.Union(left, right) => match evaluateBackward(repository, left, input) {
            case Err(error) => Err(error)
            case Ok(a) => match evaluateBackward(repository, right, input) {
                case Err(error) => Err(error)
                case Ok(b) => unionStates(a, b)
            }
        }
    }

    def applyForward(repository: Structure.Repository, atom: Policy.Atom, input: Semantics.State): Result[String, Semantics.State] = match (atom, input) {
        case (Policy.Atom.Defines, Semantics.State.Files(xs)) =>
            Ok(Semantics.State.Symbols(apply(query repository select (x, y) from Defines(x, y) |> Vector.toSet, xs)))
        case (Policy.Atom.DefinedIn, Semantics.State.Symbols(xs)) =>
            Ok(Semantics.State.Files(apply(query repository select (x, y) from DefinedIn(x, y) |> Vector.toSet, xs)))
        case (Policy.Atom.Imports, Semantics.State.Files(xs)) =>
            Ok(Semantics.State.Files(apply(query repository select (x, y) from Imports(x, y) |> Vector.toSet, xs)))
        case (Policy.Atom.ImportedBy, Semantics.State.Files(xs)) =>
            Ok(Semantics.State.Files(apply(query repository select (x, y) from ImportedBy(x, y) |> Vector.toSet, xs)))
        case (Policy.Atom.Calls, Semantics.State.Symbols(xs)) =>
            Ok(Semantics.State.Symbols(apply(query repository select (x, y) from Calls(x, y) |> Vector.toSet, xs)))
        case (Policy.Atom.Callees, Semantics.State.Symbols(xs)) =>
            Ok(Semantics.State.Symbols(apply(query repository select (x, y) from Calls(x, y) |> Vector.toSet, xs)))
        case (Policy.Atom.Callers, Semantics.State.Symbols(xs)) =>
            Ok(Semantics.State.Symbols(apply(query repository select (x, y) from Caller(x, y) |> Vector.toSet, xs)))
        case (Policy.Atom.SameFile, Semantics.State.Symbols(xs)) =>
            Ok(Semantics.State.Symbols(apply(query repository select (x, y) from SameFile(x, y) |> Vector.toSet, xs)))
        case (Policy.Atom.ImportNeighbors, Semantics.State.Symbols(xs)) =>
            Ok(Semantics.State.Symbols(apply(query repository select (x, y) from ImportNeighbor(x, y) |> Vector.toSet, xs)))
        case (Policy.Atom.ImporterNeighbors, Semantics.State.Symbols(xs)) =>
            Ok(Semantics.State.Symbols(apply(query repository select (x, y) from ImporterNeighbor(x, y) |> Vector.toSet, xs)))
        case (Policy.Atom.Parent, Semantics.State.Locations(xs)) =>
            Ok(Semantics.State.Locations(apply(query repository select (x, y) from Parent(x, y) |> Vector.toSet, xs)))
        case (Policy.Atom.RepositoryAdjacent, Semantics.State.Locations(xs)) =>
            Ok(Semantics.State.Locations(apply(query repository select (x, y) from RepositoryAdjacent(x, y) |> Vector.toSet, xs)))
        case _ => Err("reference policy/input domain mismatch")
    }

    def applyBackward(repository: Structure.Repository, atom: Policy.Atom, input: Semantics.State): Result[String, Semantics.State] = match (atom, input) {
        case (Policy.Atom.Defines, Semantics.State.Symbols(xs)) =>
            Ok(Semantics.State.Files(apply(reverse(query repository select (x, y) from Defines(x, y) |> Vector.toSet), xs)))
        case (Policy.Atom.DefinedIn, Semantics.State.Files(xs)) =>
            Ok(Semantics.State.Symbols(apply(reverse(query repository select (x, y) from DefinedIn(x, y) |> Vector.toSet), xs)))
        case (Policy.Atom.Imports, Semantics.State.Files(xs)) =>
            Ok(Semantics.State.Files(apply(reverse(query repository select (x, y) from Imports(x, y) |> Vector.toSet), xs)))
        case (Policy.Atom.ImportedBy, Semantics.State.Files(xs)) =>
            Ok(Semantics.State.Files(apply(reverse(query repository select (x, y) from ImportedBy(x, y) |> Vector.toSet), xs)))
        case (Policy.Atom.Calls, Semantics.State.Symbols(xs)) =>
            Ok(Semantics.State.Symbols(apply(reverse(query repository select (x, y) from Calls(x, y) |> Vector.toSet), xs)))
        case (Policy.Atom.Callees, Semantics.State.Symbols(xs)) =>
            Ok(Semantics.State.Symbols(apply(reverse(query repository select (x, y) from Calls(x, y) |> Vector.toSet), xs)))
        case (Policy.Atom.Callers, Semantics.State.Symbols(xs)) =>
            Ok(Semantics.State.Symbols(apply(reverse(query repository select (x, y) from Caller(x, y) |> Vector.toSet), xs)))
        case (Policy.Atom.SameFile, Semantics.State.Symbols(xs)) =>
            Ok(Semantics.State.Symbols(apply(reverse(query repository select (x, y) from SameFile(x, y) |> Vector.toSet), xs)))
        case (Policy.Atom.ImportNeighbors, Semantics.State.Symbols(xs)) =>
            Ok(Semantics.State.Symbols(apply(reverse(query repository select (x, y) from ImportNeighbor(x, y) |> Vector.toSet), xs)))
        case (Policy.Atom.ImporterNeighbors, Semantics.State.Symbols(xs)) =>
            Ok(Semantics.State.Symbols(apply(reverse(query repository select (x, y) from ImporterNeighbor(x, y) |> Vector.toSet), xs)))
        case (Policy.Atom.Parent, Semantics.State.Locations(xs)) =>
            Ok(Semantics.State.Locations(apply(reverse(query repository select (x, y) from Parent(x, y) |> Vector.toSet), xs)))
        case (Policy.Atom.RepositoryAdjacent, Semantics.State.Locations(xs)) =>
            Ok(Semantics.State.Locations(apply(reverse(query repository select (x, y) from RepositoryAdjacent(x, y) |> Vector.toSet), xs)))
        case _ => Err("reversed reference policy/input domain mismatch")
    }

    def reverse(edges: Structure.Relation[a, b]): Structure.Relation[b, a] with Order[a], Order[b] =
        Set.map(match (source, target) -> (target, source), edges)

    def apply(edges: Structure.Relation[a, b], input: Set[a]): Set[b] with Order[a], Order[b] =
        Set.foldLeft((output, edge) -> {
            let (source, target) = edge;
            if (Set.memberOf(source, input)) Set.insert(target, output) else output
        }, Set.empty(), edges)

    def unionStates(a: Semantics.State, b: Semantics.State): Result[String, Semantics.State] = match (a, b) {
        case (Semantics.State.Files(xs), Semantics.State.Files(ys)) => Ok(Semantics.State.Files(Set.union(xs, ys)))
        case (Semantics.State.Symbols(xs), Semantics.State.Symbols(ys)) => Ok(Semantics.State.Symbols(Set.union(xs, ys)))
        case (Semantics.State.Locations(xs), Semantics.State.Locations(ys)) => Ok(Semantics.State.Locations(Set.union(xs, ys)))
        case _ => Err("reference union produced incompatible domains")
    }
}
