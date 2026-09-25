@Test
def depthSevenAtlasProgramsAreCompleteAndStable(): Unit \ Assert = {
    let programs = Atlas.programs(7);
    let symbolPrograms = Vector.filter(program -> match Vector.last(program#steps) {
        case Some(Atlas.Atom.Defines) => true
        case Some(Atlas.Atom.Calls) => true
        case Some(Atlas.Atom.Callers) => true
        case _ => false
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

@Test
def atlasSignatureExplainsExtinctionExpansionReachAndReuse(): Unit \ Assert = {
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
    match Atlas.Signature.compute(world, Atlas.State.Symbols(Set.singleton(s0)), 2) {
        case Err(error) => Assert.fail(error)
        case Ok(signature) => {
            Assert.assertEq(expected = (2, 12, 6, 12, 9), (
                signature#depth,
                signature#logicalPrograms,
                signature#uniqueStates,
                signature#physicalTransitions,
                signature#transitionReuses
            ));
            let calls = Vector.get(1, signature#observations);
            Assert.assertEq(expected = (1, 1, 2, Some(1.0), 0.5, false), (
                calls#inputCardinality,
                calls#outputCardinality,
                calls#domainCardinality,
                calls#expansionRatio,
                calls#reachFraction,
                calls#extinct
            ));
            let callers = Vector.get(2, signature#observations);
            Assert.assertEq(expected = (true, Some(1)),
                (callers#extinct, callers#firstExtinctionDepth));
            let callsCalls = Vector.get(7, signature#observations);
            Assert.assertEq(expected = (true, Some(2)),
                (callsCalls#extinct, callsCalls#firstExtinctionDepth))
        }
    }
}

@Test
def atlasRouteAndStateIdentitiesIgnoreEvaluationAllocation(): Unit \ {Assert, IO} = {
    let route = Vector.get(3, Atlas.programs(2));
    let s0 = Repository.Structure.SymbolId.SymbolId(0);
    let s1 = Repository.Structure.SymbolId.SymbolId(1);
    let state = Atlas.State.Symbols(Set#{s1, s0});

    Assert.assertEq(expected = "defined_in,defines",
        Atlas.Signature.routePayload(route));
    Assert.assertEq(
        expected = "atlas-route-v1:bae3224f1c73e0a46abcae0d3123388c1429bec99776fc0444bd02ec4d38130e",
        Atlas.Signature.routeId(route)
    );
    Assert.assertEq(expected = "symbol:0,1",
        Atlas.Signature.statePayload(state));
    Assert.assertEq(
        expected = "atlas-state-v1:0670ab158cc2dace3787caa847985116d1b5984c4de5dcff1ad0687800cc1c39",
        Atlas.Signature.stateId(state)
    )
}
