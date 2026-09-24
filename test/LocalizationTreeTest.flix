mod LocalizationTreeTest {
    @Test
    def frozenTreeCountsAndStableRootProjection(): Unit \ Assert = {
        let tree = Localization.Tree.compile();
        Assert.assertEq(expected = 3279, Localization.Tree.routeCount(tree));
        Assert.assertEq(expected = 1643, Localization.Tree.symbolRouteCount(tree));
        let prior = Vector#{
            {identity = "s1", score = 0.9, ordinal = 1},
            {identity = "s0", score = 0.8, ordinal = 0},
            {identity = "s2", score = 0.7, ordinal = 2}
        };
        let root = Radii.Evaluate.State.Symbols(Set#{symbol(1), symbol(0)});
        Assert.assertEq(
            expected = Vector#{"s1", "s0", "s2"},
            Localization.Tree.promote(prior, root) |> Vector.map(item -> item#identity)
        );
        let selected = Radii.Evaluate.State.Symbols(Set#{symbol(2)});
        Assert.assertEq(
            expected = Vector#{"s2", "s1", "s0"},
            Localization.Tree.promote(prior, selected) |> Vector.map(item -> item#identity)
        )
    }

    @Test
    def compiledTreeDrivesTypedDecisionPathWithoutGold(): Unit \ Assert = {
        let repository = tinyRepository();
        let prepared: Localization.Prepared = {
            instanceId = "fixture",
            repository = "attune/fixture",
            baseCommit = "abc",
            snapshotId = "repository-snapshot-v1:fixture",
            issue = {
                instanceId = "fixture",
                repository = "attune/fixture",
                baseCommit = "abc",
                text = Localization.IssueText.IssueText("Locate the failing symbol.")
            },
            world = repository,
            sources = Vector.empty(),
            documents = Vector.empty()
        };
        let prior: Localization.Tree.Prior = {
            instanceId = "fixture",
            repository = "attune/fixture",
            baseCommit = "abc",
            ranking = Vector#{{identity = "symbol", score = 1.0, ordinal = 0}}
        };
        let tree = Localization.Tree.compile();
        match Localization.Tree.compute(prepared, prior, tree) {
            case Err(error) => Assert.fail(ToString.toString(error))
            case Ok(computed) => {
                let result = run { Localization.Tree.localize(prepared, prior, computed) }
                    with handler Decide.Choice {
                        def policy(request, k) = {
                            let index = match Vector.get(0, request#alternatives)#action {
                                case Decide.Action.Stop => 1
                                case _ => 0
                            };
                            k(Decide.runWithFake(index, () -> Decide.policy(request)))
                        }
                    };
                match result {
                    case Err(error) => Assert.fail(ToString.toString(error))
                    case Ok(outcome) => {
                        Assert.assertEq(expected = 7, Vector.length(outcome#path));
                        Assert.assertEq(expected = 7, Vector.length(outcome#decisions));
                        match outcome#finalState {
                            case Radii.Evaluate.State.Symbols(_) => ()
                            case _ => Assert.fail("depth-seven decision path ended outside Symbol")
                        }
                    }
                }
            }
        }
    }

    def tinyRepository(): Repository.World = {
        files = Vector#{"src/a.ts"},
        symbols = Vector#{{path = "src/a.ts", name = "a", startByte = 0, endByte = 1}},
        defines = Set#{(file(0), symbol(0))},
        imports = Set#{(file(0), file(0))},
        calls = Set#{(symbol(0), symbol(0))},
        parents = Set.empty(),
        unresolvedImports = 0,
        unresolvedCalls = 0
    }

    def file(index: Int32): Repository.Structure.FileId = Repository.Structure.FileId.FileId(index)
    def symbol(index: Int32): Repository.Structure.SymbolId = Repository.Structure.SymbolId.SymbolId(index)
}
