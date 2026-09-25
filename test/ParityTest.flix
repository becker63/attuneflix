mod ParityTest {
    type alias Basis = {
        name    = String,
        defines = Repository.Structure.Defines,
        imports = Repository.Structure.Imports,
        calls   = Repository.Structure.Calls,
        parents = Repository.Structure.Parents
    }

    def file(n: Int32): Repository.Structure.FileId = Repository.Structure.FileId.FileId(n)
    def symbol(n: Int32): Repository.Structure.SymbolId = Repository.Structure.SymbolId.SymbolId(n)
    def location(n: Int32): Repository.Structure.LocationId = Repository.Structure.LocationId.LocationId(n)

    def publicAtoms(): List[Radii.Atom] =
        Radii.Atom.Defines ::
        Radii.Atom.DefinedIn ::
        Radii.Atom.Imports ::
        Radii.Atom.ImportedBy ::
        Radii.Atom.Calls ::
        Radii.Atom.Callers ::
        Radii.Atom.Callees ::
        Radii.Atom.SameFile ::
        Radii.Atom.ImportNeighbors ::
        Radii.Atom.ImporterNeighbors ::
        Radii.Atom.Parent ::
        Radii.Atom.RepositoryAdjacent :: Nil

    /// Deterministic worlds cover emptiness, self edges, chains, cycles,
    /// fan-in/out, same-file cliques, disconnected components, and symbols
    /// admitted as definitions of more than one file.
    def bases(): List[Basis] =
        {
            name = "empty",
            defines = Set.empty(),
            imports = Set.empty(),
            calls = Set.empty(),
            parents = Set.empty()
        } :: {
            name = "self-and-clique",
            defines = Set#{
                (file(0), symbol(0)), (file(0), symbol(1)), (file(0), symbol(2)),
                (file(1), symbol(2))
            },
            imports = Set#{(file(0), file(0))},
            calls = Set#{(symbol(0), symbol(0))},
            parents = Set#{(location(0), location(0))}
        } :: {
            name = "chains",
            defines = Set#{
                (file(0), symbol(0)), (file(1), symbol(1)),
                (file(2), symbol(2)), (file(3), symbol(3))
            },
            imports = Set#{(file(0), file(1)), (file(1), file(2)), (file(2), file(3))},
            calls = Set#{(symbol(0), symbol(1)), (symbol(1), symbol(2)), (symbol(2), symbol(3))},
            parents = Set#{
                (location(0), location(1)), (location(1), location(2)),
                (location(2), location(3))
            }
        } :: {
            name = "cycles-and-fans",
            defines = Set#{
                (file(0), symbol(0)), (file(0), symbol(1)),
                (file(1), symbol(2)), (file(2), symbol(3))
            },
            imports = Set#{
                (file(0), file(1)), (file(1), file(2)), (file(2), file(0)),
                (file(3), file(0))
            },
            calls = Set#{
                (symbol(0), symbol(2)), (symbol(1), symbol(2)),
                (symbol(2), symbol(3)), (symbol(3), symbol(0))
            },
            parents = Set#{
                (location(0), location(2)), (location(1), location(2)),
                (location(2), location(3))
            }
        } :: {
            name = "disconnected",
            defines = Set#{
                (file(0), symbol(0)), (file(1), symbol(1)),
                (file(2), symbol(2)), (file(3), symbol(3))
            },
            imports = Set#{(file(0), file(1)), (file(2), file(3))},
            calls = Set#{(symbol(0), symbol(1)), (symbol(2), symbol(3))},
            parents = Set#{(location(0), location(1)), (location(2), location(3))}
        } :: Nil

    def inputs(domain: Radii.Domain): List[Radii.Evaluate.State] = match domain {
        case Radii.Domain.File =>
            Radii.Evaluate.State.Files(Set.empty()) ::
            Radii.Evaluate.State.Files(Set#{file(0)}) ::
            Radii.Evaluate.State.Files(Set#{file(0), file(1), file(2), file(3)}) :: Nil
        case Radii.Domain.Symbol =>
            Radii.Evaluate.State.Symbols(Set.empty()) ::
            Radii.Evaluate.State.Symbols(Set#{symbol(0)}) ::
            Radii.Evaluate.State.Symbols(Set#{symbol(0), symbol(1), symbol(2), symbol(3)}) :: Nil
        case Radii.Domain.Location =>
            Radii.Evaluate.State.Locations(Set.empty()) ::
            Radii.Evaluate.State.Locations(Set#{location(0)}) ::
            Radii.Evaluate.State.Locations(Set#{location(0), location(1), location(2), location(3)}) :: Nil
    }

    def physicalOne(world: Repository.Physical.World, expr: Radii.Expr, input: Radii.Evaluate.State): Result[String, Radii.Evaluate.State] = {
        let program = Radii.Evaluate.compile(expr :: Nil);
        match Radii.Evaluate.evaluate(world, input, program) {
            case Err(error) => Err(error)
            case Ok(evaluation) => Ok(Radii.Evaluate.state(evaluation, Vector.get(0, evaluation#outputs)))
        }
    }

    def assertInputs(
        reference: Repository.Structure.Repository,
        physical: Repository.Physical.World,
        expr: Radii.Expr,
        states: List[Radii.Evaluate.State]
    ): Int32 \ Assert = match states {
        case Nil => 0
        case input :: rest => {
            let expected = Repository.Reference.evaluate(reference, expr, input);
            Assert.assertEq(
                expected = expected,
                physicalOne(physical, expr, input)
            );
            1 + assertInputs(reference, physical, expr, rest)
        }
    }

    def assertExpressions(
        reference: Repository.Structure.Repository,
        physical: Repository.Physical.World,
        expressions: List[Radii.Expr]
    ): Int32 \ Assert = match expressions {
        case Nil => 0
        case expr :: rest => {
            let (source, _) = Radii.endpoints(expr);
            assertInputs(reference, physical, expr, inputs(source)) +
                assertExpressions(reference, physical, rest)
        }
    }

    def assertExpressionsOnWorlds(expressions: List[Radii.Expr], worlds: List[Basis]): Int32 \ Assert = match worlds {
        case Nil => 0
        case basis :: rest => {
            let reference = Repository.Reference.fromBasis(basis#defines, basis#imports, basis#calls, basis#parents);
            let physical = Repository.Physical.fromBasis(basis#defines, basis#imports, basis#calls, basis#parents);
            assertExpressions(reference, physical, expressions) +
                assertExpressionsOnWorlds(expressions, rest)
        }
    }

    @Test
    def everyPublicAtomMatchesDatalog(): Unit \ Assert = {
        let atoms = publicAtoms();
        let worlds = bases();
        let checked = assertExpressionsOnWorlds(List.map(Radii.Expr.Atom, atoms), worlds);
        Assert.assertEq(expected = 12, List.length(atoms));
        Assert.assertEq(expected = 5, List.length(worlds));
        Assert.assertEq(expected = 180, checked)
    }

    @Test
    def allNormalizedExpressionsThroughCostFourMatchDatalog(): Unit \ Assert = {
        let expressions = Radii.Synthesize.enumerate(4);
        let worlds = bases();
        let checked = assertExpressionsOnWorlds(Set.toList(expressions), worlds);
        Assert.assertEq(expected = 79, Set.size(expressions));
        Assert.assertEq(expected = 1185, checked)
    }

    @Test
    def trustedNormalizationLawsAreExtensionallyTrue(): Unit \ Assert = {
        let basis = match bases() {
            case _ :: _ :: _ :: rich :: _ => rich
            case _ => {
                name = "missing",
                defines = Set.empty(),
                imports = Set.empty(),
                calls = Set.empty(),
                parents = Set.empty()
            }
        };
        let reference = Repository.Reference.fromBasis(basis#defines, basis#imports, basis#calls, basis#parents);
        let parent = Radii.Expr.Atom(Radii.Atom.Parent);
        let defines = Radii.Expr.Atom(Radii.Atom.Defines);
        let calls = Radii.Expr.Atom(Radii.Atom.Calls);
        let callers = Radii.Expr.Atom(Radii.Atom.Callers);
        let composed = Radii.Expr.Compose(defines, calls);
        let unioned = Radii.Expr.Union(calls, callers);
        Assert.assertEq(
            expected = Repository.Reference.evaluate(reference, parent, Radii.Evaluate.State.Locations(Set#{location(0)})),
            Repository.Reference.evaluate(reference, Radii.Expr.Reverse(Radii.Expr.Reverse(parent)), Radii.Evaluate.State.Locations(Set#{location(0)}))
        );
        Assert.assertEq(
            expected = Repository.Reference.evaluate(reference, Radii.Expr.Reverse(composed), Radii.Evaluate.State.Symbols(Set#{symbol(0)})),
            Repository.Reference.evaluate(reference, Radii.Expr.Compose(Radii.Expr.Reverse(calls), Radii.Expr.Reverse(defines)), Radii.Evaluate.State.Symbols(Set#{symbol(0)}))
        );
        Assert.assertEq(
            expected = Repository.Reference.evaluate(reference, Radii.Expr.Reverse(unioned), Radii.Evaluate.State.Symbols(Set#{symbol(0)})),
            Repository.Reference.evaluate(reference, Radii.Expr.Union(Radii.Expr.Reverse(calls), Radii.Expr.Reverse(callers)), Radii.Evaluate.State.Symbols(Set#{symbol(0)}))
        );
        Assert.assertEq(
            expected = Repository.Reference.evaluate(reference, calls, Radii.Evaluate.State.Symbols(Set#{symbol(0)})),
            Repository.Reference.evaluate(reference, Radii.Expr.Atom(Radii.Atom.Callees), Radii.Evaluate.State.Symbols(Set#{symbol(0)}))
        )
    }
}
