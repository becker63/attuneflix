@Test
def depthSevenAtlasProgramsAreCompleteAndStable(): Unit \ Assert = {
    let programs = Atlas.programs(7);
    let symbolPrograms = Vector.filter(program -> match program#expression {
        case Atlas.Expr.Atom(Atlas.Atom.DefinedIn) => false
        case Atlas.Expr.Atom(_) => true
        case Atlas.Expr.Compose(_, Atlas.Atom.Defines) => true
        case Atlas.Expr.Compose(_, Atlas.Atom.DefinedIn) => false
        case Atlas.Expr.Compose(_, Atlas.Atom.Imports) => false
        case Atlas.Expr.Compose(_, Atlas.Atom.ImportedBy) => false
        case Atlas.Expr.Compose(_, Atlas.Atom.Calls) => true
        case Atlas.Expr.Compose(_, Atlas.Atom.Callers) => true
    }, programs);
    Assert.assertEq(expected = (3279, 1643),
        (Vector.length(programs), Vector.length(symbolPrograms)));
    Assert.assertEq(expected = Vector#{Atlas.Atom.DefinedIn},
        Vector.get(0, programs)#steps);
    Assert.assertEq(expected = Vector#{Atlas.Atom.Calls},
        Vector.get(1, programs)#steps);
    Assert.assertEq(expected = Vector#{Atlas.Atom.Callers},
        Vector.get(2, programs)#steps);
    Assert.assertEq(expected = Vector#{
        Atlas.Atom.DefinedIn,
        Atlas.Atom.Defines
    }, Vector.get(3, programs)#steps);
    Assert.assertEq(expected = 0, Vector.length(Atlas.programs(0)))
}

@Test
def atlasEvaluationReturnsExactTypedStatesAndReusesTransitions(): Unit \ Assert = {
    let f0 = Repository.Structure.FileId.FileId(0);
    let f1 = Repository.Structure.FileId.FileId(1);
    let s0 = Repository.Structure.SymbolId.SymbolId(0);
    let s1 = Repository.Structure.SymbolId.SymbolId(1);
    let world: Repository.World = {
        files = Vector#{"a.js", "b.js"},
        symbols = Vector#{
            {path = "a.js", name = "a", startByte = 0, endByte = 1},
            {path = "b.js", name = "b", startByte = 0, endByte = 1}
        },
        defines = Set#{(f0, s0), (f1, s1)},
        imports = Set#{(f0, f1)},
        calls = Set#{(s0, s1)},
        parents = Set.empty(),
        unresolvedImports = 0,
        unresolvedCalls = 0
    };
    match Atlas.evaluate(world, Atlas.State.Symbols(Set.singleton(s0)), Atlas.programs(2)) {
        case Err(error) => Assert.fail(error)
        case Ok(result) => {
            Assert.assertEq(expected = 12, Vector.length(result#outputs));
            Assert.assertEq(expected = Atlas.State.Files(Set.singleton(f0)),
                Vector.get(0, result#outputs));
            Assert.assertEq(expected = Atlas.State.Symbols(Set.singleton(s1)),
                Vector.get(1, result#outputs));
            Assert.assertEq(expected = Atlas.State.Symbols(Set.empty()),
                Vector.get(2, result#outputs));
            Assert.assertEq(expected = (12, 9),
                (result#physicalTransitions, result#transitionReuses));
            Assert.assertEq(expected = 21,
                result#physicalTransitions + result#transitionReuses)
        }
    }
}
