mod Policy {
    /// The three finite endpoint sorts admitted by the structural language.
    pub enum Domain with Eq, Order, ToString, Hash {
        case File,
        case Symbol,
        case Location
    }

    /// Named public concepts. Source facts remain only defines/imports/calls/parent.
    pub enum Atom with Eq, Order, ToString, Hash {
        case Defines,
        case DefinedIn,
        case Imports,
        case ImportedBy,
        case Calls,
        case Callers,
        case Callees,
        case SameFile,
        case ImportNeighbors,
        case ImporterNeighbors,
        case Parent,
        case RepositoryAdjacent
    }

    /// The complete finite policy search language.
    pub enum Expr with Eq, Order, ToString, Hash {
        case Atom(Atom),
        case Reverse(Expr),
        case Compose(Expr, Expr),
        case Union(Expr, Expr)
    }

    pub def source(a: Atom): Domain = match a {
        case Atom.Defines             => Domain.File
        case Atom.DefinedIn           => Domain.Symbol
        case Atom.Imports             => Domain.File
        case Atom.ImportedBy          => Domain.File
        case Atom.Calls               => Domain.Symbol
        case Atom.Callers             => Domain.Symbol
        case Atom.Callees             => Domain.Symbol
        case Atom.SameFile            => Domain.Symbol
        case Atom.ImportNeighbors     => Domain.Symbol
        case Atom.ImporterNeighbors   => Domain.Symbol
        case Atom.Parent              => Domain.Location
        case Atom.RepositoryAdjacent  => Domain.Location
    }

    pub def target(a: Atom): Domain = match a {
        case Atom.Defines             => Domain.Symbol
        case Atom.DefinedIn           => Domain.File
        case Atom.Imports             => Domain.File
        case Atom.ImportedBy          => Domain.File
        case Atom.Calls               => Domain.Symbol
        case Atom.Callers             => Domain.Symbol
        case Atom.Callees             => Domain.Symbol
        case Atom.SameFile            => Domain.Symbol
        case Atom.ImportNeighbors     => Domain.Symbol
        case Atom.ImporterNeighbors   => Domain.Symbol
        case Atom.Parent              => Domain.Location
        case Atom.RepositoryAdjacent  => Domain.Location
    }

    pub def endpoints(e: Expr): (Domain, Domain) = match e {
        case Expr.Atom(a)       => (source(a), target(a))
        case Expr.Reverse(x)    => let (s, t) = endpoints(x); (t, s)
        case Expr.Compose(x, y) => let (s, _) = endpoints(x); let (_, t) = endpoints(y); (s, t)
        case Expr.Union(x, _)   => endpoints(x)
    }

    pub def compose(x: Expr, y: Expr): Option[Expr] =
        let (_, xt) = endpoints(x);
        let (ys, _) = endpoints(y);
        if (xt == ys) Some(normalize(Expr.Compose(x, y))) else None

    pub def union(x: Expr, y: Expr): Option[Expr] =
        if (endpoints(x) == endpoints(y)) Some(normalize(Expr.Union(x, y))) else None

    pub def reverse(e: Expr): Expr = normalize(Expr.Reverse(e))

    /// Human-facing synthesis complexity; named concepts always cost one.
    pub def cost(e: Expr): Int32 = match e {
        case Expr.Atom(_)       => 1
        case Expr.Reverse(x)    => cost(x) + 1
        case Expr.Compose(x, y) => cost(x) + cost(y) + 1
        case Expr.Union(x, y)   => cost(x) + cost(y) + 1
    }

    def inverse(a: Atom): Option[Atom] = match a {
        case Atom.Defines             => Some(Atom.DefinedIn)
        case Atom.DefinedIn           => Some(Atom.Defines)
        case Atom.Imports             => Some(Atom.ImportedBy)
        case Atom.ImportedBy          => Some(Atom.Imports)
        case Atom.Calls               => Some(Atom.Callers)
        case Atom.Callees             => Some(Atom.Callers)
        case Atom.Callers             => Some(Atom.Calls)
        case Atom.SameFile            => Some(Atom.SameFile)
        case Atom.ImportNeighbors     => Some(Atom.ImporterNeighbors)
        case Atom.ImporterNeighbors   => Some(Atom.ImportNeighbors)
        case Atom.Parent              => None
        case Atom.RepositoryAdjacent  => Some(Atom.RepositoryAdjacent)
    }

    def canonicalAtom(a: Atom): Atom = match a {
        case Atom.Callees => Atom.Calls
        case _            => a
    }

    /// A deliberately tiny trusted normalizer, not a theorem prover.
    pub def normalize(e: Expr): Expr = match e {
        case Expr.Atom(a) => Expr.Atom(canonicalAtom(a))
        case Expr.Reverse(Expr.Reverse(x)) => normalize(x)
        case Expr.Reverse(Expr.Atom(a)) => match inverse(canonicalAtom(a)) {
            case Some(i) => Expr.Atom(i)
            case None    => Expr.Reverse(Expr.Atom(a))
        }
        case Expr.Reverse(Expr.Compose(x, y)) =>
            normalize(Expr.Compose(Expr.Reverse(y), Expr.Reverse(x)))
        case Expr.Reverse(Expr.Union(x, y)) =>
            normalize(Expr.Union(Expr.Reverse(x), Expr.Reverse(y)))
        case Expr.Compose(x, y) => Expr.Compose(normalize(x), normalize(y))
        case Expr.Union(x, y) =>
            let nx = normalize(x);
            let ny = normalize(y);
            if (nx == ny) nx
            else if (nx < ny) Expr.Union(nx, ny)
            else Expr.Union(ny, nx)
    }

    /// Canonical synthesis atoms: twelve public names, eleven identities.
    pub def atoms(): Set[Expr] = Set#{
        Expr.Atom(Atom.Defines),
        Expr.Atom(Atom.DefinedIn),
        Expr.Atom(Atom.Imports),
        Expr.Atom(Atom.ImportedBy),
        Expr.Atom(Atom.Calls),
        Expr.Atom(Atom.Callers),
        Expr.Atom(Atom.SameFile),
        Expr.Atom(Atom.ImportNeighbors),
        Expr.Atom(Atom.ImporterNeighbors),
        Expr.Atom(Atom.Parent),
        Expr.Atom(Atom.RepositoryAdjacent)
    }
}
