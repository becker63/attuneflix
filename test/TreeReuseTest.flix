mod TreeReuseTest {
    type alias Independent = {
        results = Map[Radii.Expr, Radii.Evaluate.State],
        physicalTransitions = Int32
    }

    def file(n: Int32): Repository.Structure.FileId =
        Repository.Structure.FileId.FileId(n)

    def symbol(n: Int32): Repository.Structure.SymbolId =
        Repository.Structure.SymbolId.SymbolId(n)

    /// Permanent law distilled from the frozen 208-cell experiment: the
    /// exact same complete family and input must produce the same semantic
    /// map when evaluated together or in isolated regions, while the shared
    /// region performs fewer physical primitive transitions.
    @Test
    def completeFamilyCollapsesIntoSharedDag(): Unit \ Assert = {
        let world = Radii.Evaluate.fromBasis(
            Radii.Evaluate.WorldId.WorldId("tree-reuse-fixture"),
            Set#{
                (file(0), symbol(0)), (file(0), symbol(1)),
                (file(1), symbol(2)), (file(2), symbol(3))
            },
            Set#{(file(0), file(1)), (file(1), file(2)), (file(2), file(0))},
            Set#{
                (symbol(0), symbol(2)), (symbol(1), symbol(2)),
                (symbol(2), symbol(3)), (symbol(3), symbol(0))
            },
            Set.empty()
        );
        let candidates = Radii.Synthesize.enumerate(5)
            |> Set.filter(expr -> fst(Radii.endpoints(expr)) == Radii.Domain.File)
            |> Set.toList;
        let input = Radii.Evaluate.State.Files(Set.singleton(file(0)));
        match Radii.Evaluate.evaluateAll(world, input, candidates) {
            case Err(error) => Assert.fail(error)
            case Ok(shared) => match independently(world, input, candidates, {
                results = Map.empty(),
                physicalTransitions = 0
            }) {
                case Err(error) => Assert.fail(error)
                case Ok(isolated) => {
                    Assert.assertEq(expected = 164, List.length(candidates));
                    Assert.assertEq(expected = isolated#results, shared#results);
                    Assert.assertTrue(shared#metrics#physicalTransitions < isolated#physicalTransitions)
                }
            }
        }
    }

    def independently(
        world: Radii.Evaluate.World,
        input: Radii.Evaluate.State,
        candidates: List[Radii.Expr],
        aggregate: Independent
    ): Result[String, Independent] = match candidates {
        case Nil => Ok(aggregate)
        case expression :: rest => match Radii.Evaluate.evaluateAll(world, input, expression :: Nil) {
            case Err(error) => Err(error)
            case Ok(evaluation) => independently(world, input, rest, {
                results = Map.union(aggregate#results, evaluation#results),
                physicalTransitions = aggregate#physicalTransitions + evaluation#metrics#physicalTransitions
            })
        }
    }
}
