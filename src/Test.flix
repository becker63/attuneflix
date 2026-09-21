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
    let wire = Grit.runWithFixture(fixture, () -> Grit.evaluate(Grit.Language.TypeScript, Grit.Program.Calls, "example.ts", ""));
    Assert.assertEq(expected = Grit.json(fixture), Grit.json(wire))
}

@Test
def gritWireDecodingPreservesNestedUtf8ByteFacts(): Unit \ Assert = {
    let source = "const π = 'é';\nBoolean(verify(name));";
    let wire = Grit.Wire.Wire(
        "{\"version\":1,\"matched\":true,\"matches\":[" +
        "{\"path\":\"nested.ts\",\"start_byte\":17,\"end_byte\":38}," +
        "{\"path\":\"nested.ts\",\"start_byte\":25,\"end_byte\":37}]," +
        "\"logs\":[{\"message\":\"call\\n\",\"start_byte\":17,\"end_byte\":24}," +
        "{\"message\":\"call\\n\",\"start_byte\":25,\"end_byte\":31}]," +
        "\"diagnostics\":[]}"
    );
    match Grit.facts("nested.ts", source, wire) {
        case Err(error) => Assert.fail(ToString.toString(error))
        case Ok(facts) => {
            Assert.assertEq(expected = 2, Vector.length(facts));
            let outer = Vector.get(0, facts);
            let inner = Vector.get(1, facts);
            Assert.assertEq(expected = ("call", "nested.ts", 17, 38, "Boolean"),
                (outer#kind, outer#path, outer#startByte, outer#endByte, outer#value));
            Assert.assertEq(expected = ("call", "nested.ts", 25, 37, "verify"),
                (inner#kind, inner#path, inner#startByte, inner#endByte, inner#value))
        }
    }
}

@Test
def gritWireFailuresStayClassified(): Unit \ Assert = {
    let native = Grit.Wire.Wire("{\"version\":1,\"error\":{\"kind\":\"compile\",\"message\":\"bad program\"}}");
    let future = Grit.Wire.Wire("{\"version\":2,\"matched\":false,\"matches\":[],\"logs\":[],\"diagnostics\":[]}");
    let outside = Grit.Wire.Wire(
        "{\"version\":1,\"matched\":true,\"matches\":[]," +
        "\"logs\":[{\"message\":\"call\",\"start_byte\":0,\"end_byte\":1}],\"diagnostics\":[]}"
    );
    match Grit.decode(native) {
        case Err(Grit.Error.Native(kind, message)) =>
            Assert.assertEq(expected = ("compile", "bad program"), (kind, message))
        case _ => Assert.fail("native error lost its classification")
    };
    match Grit.decode(future) {
        case Err(Grit.Error.UnsupportedVersion(version)) => Assert.assertEq(expected = 2, version)
        case _ => Assert.fail("future wire version was accepted")
    };
    match Grit.facts("x.ts", "x", outside) {
        case Err(Grit.Error.LogOutsideMatch(start, end)) => Assert.assertEq(expected = (0, 1), (start, end))
        case _ => Assert.fail("orphan log was accepted")
    }
}

@Test
def gritNativeHandlerKeepsIoAtTheEdge(): Unit \ {Assert, IO} = {
    let wire = Grit.runWithNative(() -> Grit.evaluate(Grit.Language.TypeScript, Grit.Program.Calls, "example.ts", "verify(name);"));
    Assert.assertTrue(String.isSubmatch(regex = "\\\"matched\\\":true", Grit.json(wire)))
}

@Test
def nativeGritFactsAdmitTheFrozenAtlasWorld(): Unit \ {Assert, IO} = {
    let auth =
        "import { sign } from \"./tokens\";\n" +
        "import \"./missing\";\n\n" +
        "export function login(name: string): string {\n" +
        "  duplicate();\n" +
        "  return sign(name);\n" +
        "}\n\n" +
        "export function logout(): void {}\n";
    let tokens =
        "export function sign(value: string): string {\n" +
        "  return value;\n" +
        "}\n\n" +
        "export function duplicate(): void {}\n" +
        "export function duplicate(): void {}\n";
    let sources = Vector#{
        {path = "src/auth.ts", content = auth},
        {path = "src/tokens.ts", content = tokens}
    };
    match Grit.runWithNative(() -> Repository.extract(sources)) {
        case Err(error) => Assert.fail(ToString.toString(error))
        case Ok(world) => {
            Assert.assertEq(expected = Vector#{"src/auth.ts", "src/tokens.ts"}, world#files);
            Assert.assertEq(expected = Vector#{"login", "logout", "sign", "duplicate", "duplicate"},
                Vector.map(symbol -> symbol#name, world#symbols));
            Assert.assertEq(expected = Set#{
                (file(0), symbol(0)), (file(0), symbol(1)),
                (file(1), symbol(2)), (file(1), symbol(3)), (file(1), symbol(4))
            }, world#defines);
            Assert.assertEq(expected = Set#{(file(0), file(1))}, world#imports);
            Assert.assertEq(expected = Set#{(symbol(0), symbol(2))}, world#calls);
            Assert.assertEq(expected = Set#{
                (location(0), location(3)),
                (location(1), location(3)),
                (location(3), location(2))
            }, world#parents);
            Assert.assertEq(expected = (1, 1), (world#unresolvedImports, world#unresolvedCalls));

            // Five symbols is below the frozen issue-blind seed limit of eight,
            // so the Python policy and this complete seed set are identical.
            let seeds = Repository.allSymbols(world);
            let facts = Structure.repositoryFacts(world#defines, world#imports, world#calls, world#parents);
            let sameFile = query facts, Structure.sameFileRules() select (x, y) from SameFile(x, y);
            Assert.assertEq(expected = 13, Vector.length(sameFile));
            match Atlas.measure(world, seeds, 7) {
                case Err(error) => Assert.fail(error)
                case Ok(signature) => {
                    Assert.assertEq(expected =
                        (2, 5, 5, 1, 1, 3),
                        (signature#counts#files, signature#counts#symbols,
                         signature#counts#defines, signature#counts#imports,
                         signature#counts#calls, signature#counts#parent));
                    Assert.assertEq(expected = (7, 3279, 1643),
                        (signature#depth, signature#logicalPrograms, signature#symbolPrograms));
                    Assert.assertEq(expected = (30, 3249),
                        (signature#physicalTransitions, signature#transitionReuses));
                    Assert.assertTrue(signature#physicalTransitions < signature#logicalPrograms);
                    Assert.assertEq(expected = signature#logicalPrograms,
                        signature#physicalTransitions + signature#transitionReuses)
                }
            }
        }
    }
}
