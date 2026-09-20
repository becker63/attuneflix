def file(n: Int32): Structure.FileId = Structure.FileId.FileId(n)

def symbol(n: Int32): Structure.SymbolId = Structure.SymbolId.SymbolId(n)

def location(n: Int32): Structure.LocationId = Structure.LocationId.LocationId(n)

def relatedRules(): #{SameFile(Structure.SymbolId, Structure.SymbolId), Related(Structure.SymbolId) | r} = #{
    Related(x) :- SameFile(x, _).
}

@Test
def atlasGrammarCountsMatchFrozenOracle(): Unit \ Assert = {
    let counts = Atlas.counts(7);
    Assert.assertEq(expected = 3279, counts#logical);
    Assert.assertEq(expected = 1643, counts#complete)
}

@Test
def atlasAndSynthesisAreDifferentTypes(): Unit \ Assert = {
    let atlas = Atlas.Expr.Compose(Atlas.Expr.Atom(Atlas.Atom.Defines), Atlas.Atom.Calls);
    let synthesis = Policy.Expr.Compose(Policy.Expr.Atom(Policy.Atom.Defines), Policy.Expr.Atom(Policy.Atom.Calls));
    Assert.assertEq(expected = "Compose(Atom(Defines), Calls)", ToString.toString(atlas));
    Assert.assertEq(expected = 3, Policy.cost(synthesis))
}

@Test
def policyCostAndSortAreExplicit(): Unit \ Assert = {
    let defines = Policy.Expr.Atom(Policy.Atom.Defines);
    let calls = Policy.Expr.Atom(Policy.Atom.Calls);
    let imports = Policy.Expr.Atom(Policy.Atom.Imports);
    Assert.assertEq(expected = Some(Policy.Expr.Compose(defines, calls)), Policy.compose(defines, calls));
    Assert.assertEq(expected = None, Policy.compose(defines, imports));
    Assert.assertEq(expected = 3, Policy.cost(Policy.Expr.Compose(defines, calls)))
}

@Test
def normalizationKnowsPublicInversesAndAliases(): Unit \ Assert = {
    let calls = Policy.Expr.Atom(Policy.Atom.Calls);
    let callees = Policy.Expr.Atom(Policy.Atom.Callees);
    let callers = Policy.Expr.Atom(Policy.Atom.Callers);
    Assert.assertEq(expected = calls, Policy.normalize(callees));
    Assert.assertEq(expected = callers, Policy.reverse(calls));
    Assert.assertEq(expected = calls, Policy.reverse(callers));
    Assert.assertEq(expected = 11, Set.size(Policy.atoms()))
}

@Test
def nominalDatalogRulesExplainNamedConcepts(): Unit \ Assert = {
    let defines = Set#{(file(0), symbol(0)), (file(0), symbol(1)), (file(1), symbol(2)), (file(1), symbol(3))};
    let imports = Set#{(file(0), file(1))};
    let calls = Set#{(symbol(0), symbol(2)), (symbol(2), symbol(3))};
    let parents = Set#{(location(0), location(2)), (location(1), location(2))};
    Assert.assertEq(expected = Set#{
        (symbol(0), symbol(0)), (symbol(0), symbol(1)), (symbol(1), symbol(0)), (symbol(1), symbol(1)),
        (symbol(2), symbol(2)), (symbol(2), symbol(3)), (symbol(3), symbol(2)), (symbol(3), symbol(3))
    }, Structure.sameFile(defines));
    Assert.assertEq(expected = Set#{(symbol(2), symbol(0)), (symbol(3), symbol(2))}, Structure.callers(calls));
    Assert.assertEq(expected = Set#{
        (symbol(0), symbol(2)), (symbol(0), symbol(3)), (symbol(1), symbol(2)), (symbol(1), symbol(3))
    }, Structure.importNeighbors(defines, imports));
    Assert.assertEq(expected = Set#{
        (symbol(2), symbol(0)), (symbol(2), symbol(1)), (symbol(3), symbol(0)), (symbol(3), symbol(1))
    }, Structure.importerNeighbors(defines, imports));
    Assert.assertEq(expected = Set#{
        (location(0), location(2)), (location(1), location(2)), (location(2), location(0)), (location(2), location(1))
    }, Structure.repositoryAdjacent(parents))
}

@Test
def wholeConstraintCatalogComposesAtQuerySite(): Unit \ Assert = {
    let defines = Set#{(file(0), symbol(0)), (file(0), symbol(1)), (file(1), symbol(2))};
    let facts = Structure.repositoryFacts(defines, Set#{(file(0), file(1))}, Set#{(symbol(0), symbol(2))}, Set.empty());
    let actual = query facts, Structure.structuralRules() select (x, y) from SameFile(x, y);
    Assert.assertEq(expected = 5, Vector.length(actual))
}

@Test
def independentConstraintFragmentsComposeAtQuerySite(): Unit \ Assert = {
    let defines = Set#{(file(0), symbol(0)), (file(0), symbol(1)), (file(1), symbol(2))};
    let facts = Structure.repositoryFacts(defines, Set#{(file(0), file(1))}, Set.empty(), Set.empty());
    let actual = query facts, Structure.importRules(), Structure.sameFileRules()
        select (x, y) from ImportNeighbor(x, y);
    Assert.assertEq(expected = Vector#{(symbol(0), symbol(2)), (symbol(1), symbol(2))}, actual)
}

@Test
def solvedConstraintProjectionComposesAgain(): Unit \ Assert = {
    let defines = Set#{(file(0), symbol(0)), (file(0), symbol(1)), (file(1), symbol(2))};
    let facts = Structure.repositoryFacts(defines, Set.empty(), Set.empty(), Set.empty());
    let structural = solve facts, Structure.sameFileRules() project SameFile;
    let actual = query structural, relatedRules() select x from Related(x);
    Assert.assertEq(expected = Vector#{symbol(0), symbol(1), symbol(2)}, actual)
}

@Test
def regionMemoMakesSharedPrefixesPhysicalDags(): Unit \ Assert = {
    let world = Semantics.fromBasis(
        Semantics.WorldId.WorldId("fixture"),
        Set#{(file(0), symbol(0))},
        Set.empty(),
        Set#{(symbol(0), symbol(2)), (symbol(2), symbol(3))},
        Set.empty()
    );
    let defines = Policy.Expr.Atom(Policy.Atom.Defines);
    let calls = Policy.Expr.Atom(Policy.Atom.Calls);
    let callers = Policy.Expr.Atom(Policy.Atom.Callers);
    let prefix = Policy.Expr.Compose(defines, calls);
    let candidates = Policy.Expr.Compose(prefix, calls) :: Policy.Expr.Compose(prefix, callers) :: Nil;
    match Semantics.evaluateAll(world, Semantics.State.Files(Set#{file(0)}), candidates) {
        case Err(error) => Assert.fail(error)
        case Ok(evaluation) => {
            Assert.assertEq(expected = 2, evaluation#metrics#logicalExpressions);
            Assert.assertEq(expected = 4, evaluation#metrics#physicalTransitions);
            Assert.assertEq(expected = 1, evaluation#metrics#subtreeReuses);
            Assert.assertEq(expected = 4, evaluation#metrics#uniqueStates)
        }
    }
}

@Test
def decideHandlersAreTypedAndExact(): Unit \ Assert = {
    let state = Semantics.State.Symbols(Set#{symbol(0)});
    let decision = Semantics.DecisionId.DecisionId("fixture-choice");
    let alternatives = Vector#{
        {expression = Semantics.exprId(Policy.Expr.Atom(Policy.Atom.Calls)), state = Semantics.stateId(state)},
        {expression = Semantics.exprId(Policy.Expr.Atom(Policy.Atom.Callers)), state = Semantics.stateId(state)}
    };
    let fake = Decide.runWithFake(1, () -> Decide.policy(decision, Semantics.stateId(state), alternatives));
    let replay = Decide.runWithReplay(Map#{decision => 0}, () -> Decide.policy(decision, Semantics.stateId(state), alternatives));
    Assert.assertEq(expected = Ok(1), fake);
    Assert.assertEq(expected = Ok(0), replay)
}

@Test
def gritFixtureHandlerEliminatesCapability(): Unit \ Assert = {
    let fixture = Grit.Wire.Wire("{\"version\":1,\"matched\":false}");
    let wire = Grit.runWithFixture(fixture, () -> Grit.evaluate(Grit.Language.TypeScript, "", "example.ts", ""));
    Assert.assertEq(expected = Grit.json(fixture), Grit.json(wire))
}

@Test
def gritNativeHandlerKeepsIoAtTheEdge(): Unit \ {Assert, IO} = {
    let program = "engine marzano(0.1)\nlanguage js(typescript)\n`$callee($...)` as $call where { log(message=\"call\", variable=$callee) }";
    let wire = Grit.runWithNative(() -> Grit.evaluate(Grit.Language.TypeScript, program, "example.ts", "verify(name);"));
    Assert.assertTrue(String.isSubmatch(regex = "\\\"matched\\\":true", Grit.json(wire)))
}
