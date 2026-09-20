mod ParityTest {
    type alias Basis = {
        name    = String,
        defines = Structure.Defines,
        imports = Structure.Imports,
        calls   = Structure.Calls,
        parents = Structure.Parents
    }

    def file(n: Int32): Structure.FileId = Structure.FileId.FileId(n)
    def symbol(n: Int32): Structure.SymbolId = Structure.SymbolId.SymbolId(n)
    def location(n: Int32): Structure.LocationId = Structure.LocationId.LocationId(n)

    def publicAtoms(): List[Policy.Atom] =
        Policy.Atom.Defines ::
        Policy.Atom.DefinedIn ::
        Policy.Atom.Imports ::
        Policy.Atom.ImportedBy ::
        Policy.Atom.Calls ::
        Policy.Atom.Callers ::
        Policy.Atom.Callees ::
        Policy.Atom.SameFile ::
        Policy.Atom.ImportNeighbors ::
        Policy.Atom.ImporterNeighbors ::
        Policy.Atom.Parent ::
        Policy.Atom.RepositoryAdjacent :: Nil

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

    def inputs(domain: Policy.Domain): List[Semantics.State] = match domain {
        case Policy.Domain.File =>
            Semantics.State.Files(Set.empty()) ::
            Semantics.State.Files(Set#{file(0)}) ::
            Semantics.State.Files(Set#{file(0), file(1), file(2), file(3)}) :: Nil
        case Policy.Domain.Symbol =>
            Semantics.State.Symbols(Set.empty()) ::
            Semantics.State.Symbols(Set#{symbol(0)}) ::
            Semantics.State.Symbols(Set#{symbol(0), symbol(1), symbol(2), symbol(3)}) :: Nil
        case Policy.Domain.Location =>
            Semantics.State.Locations(Set.empty()) ::
            Semantics.State.Locations(Set#{location(0)}) ::
            Semantics.State.Locations(Set#{location(0), location(1), location(2), location(3)}) :: Nil
    }

    def physicalOne(world: Semantics.World, expr: Policy.Expr, input: Semantics.State): Result[String, Semantics.State] =
        match Semantics.evaluateAll(world, input, expr :: Nil) {
            case Err(error) => Err(error)
            case Ok(evaluation) => match Map.get(Policy.normalize(expr), evaluation#results) {
                case None => Err("physical evaluator omitted compatible expression")
                case Some(output) => Ok(output)
            }
        }

    def assertInputs(
        reference: Structure.Repository,
        physical: Semantics.World,
        expr: Policy.Expr,
        states: List[Semantics.State]
    ): Int32 \ Assert = match states {
        case Nil => 0
        case input :: rest => {
            Assert.assertEq(
                expected = Reference.evaluate(reference, expr, input),
                physicalOne(physical, expr, input)
            );
            1 + assertInputs(reference, physical, expr, rest)
        }
    }

    def assertExpressions(
        reference: Structure.Repository,
        physical: Semantics.World,
        expressions: List[Policy.Expr]
    ): Int32 \ Assert = match expressions {
        case Nil => 0
        case expr :: rest => {
            let (source, _) = Policy.endpoints(expr);
            assertInputs(reference, physical, expr, inputs(source)) +
                assertExpressions(reference, physical, rest)
        }
    }

    def assertAtomsOnWorlds(atoms: List[Policy.Atom], worlds: List[Basis]): Int32 \ Assert = match worlds {
        case Nil => 0
        case basis :: rest => {
            let reference = Reference.fromBasis(basis#defines, basis#imports, basis#calls, basis#parents);
            let physical = Semantics.fromBasis(
                Semantics.WorldId.WorldId(basis#name),
                basis#defines,
                basis#imports,
                basis#calls,
                basis#parents
            );
            assertExpressions(reference, physical, List.map(Policy.Expr.Atom, atoms)) +
                assertAtomsOnWorlds(atoms, rest)
        }
    }

    def assertExpressionsOnWorlds(expressions: List[Policy.Expr], worlds: List[Basis]): Int32 \ Assert = match worlds {
        case Nil => 0
        case basis :: rest => {
            let reference = Reference.fromBasis(basis#defines, basis#imports, basis#calls, basis#parents);
            let physical = Semantics.fromBasis(
                Semantics.WorldId.WorldId(basis#name),
                basis#defines,
                basis#imports,
                basis#calls,
                basis#parents
            );
            assertExpressions(reference, physical, expressions) +
                assertExpressionsOnWorlds(expressions, rest)
        }
    }

    @Test
    def everyPublicAtomMatchesDatalog(): Unit \ Assert = {
        let atoms = publicAtoms();
        let worlds = bases();
        let checked = assertAtomsOnWorlds(atoms, worlds);
        Assert.assertEq(expected = 12, List.length(atoms));
        Assert.assertEq(expected = 5, List.length(worlds));
        Assert.assertEq(expected = 180, checked)
    }

    @Test
    def allNormalizedExpressionsThroughCostFourMatchDatalog(): Unit \ Assert = {
        let expressions = Synthesis.enumerate(4);
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
        let reference = Reference.fromBasis(basis#defines, basis#imports, basis#calls, basis#parents);
        let parent = Policy.Expr.Atom(Policy.Atom.Parent);
        let defines = Policy.Expr.Atom(Policy.Atom.Defines);
        let calls = Policy.Expr.Atom(Policy.Atom.Calls);
        let callers = Policy.Expr.Atom(Policy.Atom.Callers);
        let composed = Policy.Expr.Compose(defines, calls);
        let unioned = Policy.Expr.Union(calls, callers);
        Assert.assertEq(
            expected = Reference.evaluate(reference, parent, Semantics.State.Locations(Set#{location(0)})),
            Reference.evaluate(reference, Policy.Expr.Reverse(Policy.Expr.Reverse(parent)), Semantics.State.Locations(Set#{location(0)}))
        );
        Assert.assertEq(
            expected = Reference.evaluate(reference, Policy.Expr.Reverse(composed), Semantics.State.Symbols(Set#{symbol(0)})),
            Reference.evaluate(reference, Policy.Expr.Compose(Policy.Expr.Reverse(calls), Policy.Expr.Reverse(defines)), Semantics.State.Symbols(Set#{symbol(0)}))
        );
        Assert.assertEq(
            expected = Reference.evaluate(reference, Policy.Expr.Reverse(unioned), Semantics.State.Symbols(Set#{symbol(0)})),
            Reference.evaluate(reference, Policy.Expr.Union(Policy.Expr.Reverse(calls), Policy.Expr.Reverse(callers)), Semantics.State.Symbols(Set#{symbol(0)}))
        );
        Assert.assertEq(
            expected = Reference.evaluate(reference, calls, Semantics.State.Symbols(Set#{symbol(0)})),
            Reference.evaluate(reference, Policy.Expr.Atom(Policy.Atom.Callees), Semantics.State.Symbols(Set#{symbol(0)}))
        )
    }
}
