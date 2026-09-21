import java.lang.System

def file(n: Int32): Repository.Structure.FileId = Repository.Structure.FileId.FileId(n)

def symbol(n: Int32): Repository.Structure.SymbolId = Repository.Structure.SymbolId.SymbolId(n)

def location(n: Int32): Repository.Structure.LocationId = Repository.Structure.LocationId.LocationId(n)

def compiledFileCandidates(maxCost: Int32): List[Radii.Expr] =
    Radii.Synthesize.enumerate(maxCost)
    |> Set.toList
    |> List.filter(expr -> let (source, _) = Radii.endpoints(expr); source == Radii.Domain.File)

def compiledStateWeight(state0: Radii.Evaluate.State): Int32 = match state0 {
    case Radii.Evaluate.State.Files(values) => Set.size(values)
    case Radii.Evaluate.State.Symbols(values) => Set.size(values)
    case Radii.Evaluate.State.Locations(values) => Set.size(values)
}

def compiledEvaluationWeight(evaluation: Radii.Compiled.Evaluation): Int32 =
    Vector.foldLeft((weight, id) -> weight + compiledStateWeight(Radii.Compiled.state(evaluation, id)), 0, evaluation#outputs) +
    Vector.foldLeft((weight, state0) -> weight + compiledStateWeight(state0), 0, evaluation#arena) +
    evaluation#metrics#statesInterned + evaluation#metrics#memoEntries + evaluation#metrics#memoSlots

def legacyEvaluationWeight(evaluation: Radii.Evaluate.Evaluation): Int32 =
    Map.foldLeftWithKey((weight, expression, state0) ->
        weight + Radii.cost(expression) + compiledStateWeight(state0), 0, evaluation#results)

def compiledTime(world: Radii.Evaluate.World, input: Radii.Evaluate.State, program: Radii.Compiled.Program): Int64 \ {Assert, IO} = {
    let started = System.nanoTime();
    match Radii.Compiled.evaluate(world, input, program) {
        case Err(error) => { Assert.fail(error); 0i64 }
        case Ok(evaluation) => {
            let weight = compiledEvaluationWeight(evaluation);
            let _ = System.identityHashCode(weight);
            System.nanoTime() - started
        }
    }
}

def legacyTime(world: Radii.Evaluate.World, input: Radii.Evaluate.State, candidates: List[Radii.Expr]): Int64 \ {Assert, IO} = {
    let started = System.nanoTime();
    match Radii.Evaluate.evaluateAll(world, input, candidates) {
        case Err(error) => { Assert.fail(error); 0i64 }
        case Ok(evaluation) => {
            let weight = legacyEvaluationWeight(evaluation);
            let _ = System.identityHashCode(weight);
            System.nanoTime() - started
        }
    }
}

def warmCompiled(world: Radii.Evaluate.World, input: Radii.Evaluate.State, candidates: List[Radii.Expr], program: Radii.Compiled.Program, remaining: Int32): Unit \ {Assert, IO} =
    if (remaining <= 0) ()
    else {
        let _ = legacyTime(world, input, candidates);
        let _ = compiledTime(world, input, program);
        warmCompiled(world, input, candidates, program, remaining - 1)
    }

def sampleCompiled(world: Radii.Evaluate.World, input: Radii.Evaluate.State, candidates: List[Radii.Expr], program: Radii.Compiled.Program, remaining: Int32, legacy: List[Int64], compiled: List[Int64]): (List[Int64], List[Int64]) \ {Assert, IO} =
    if (remaining <= 0) (List.sort(legacy), List.sort(compiled))
    else sampleCompiled(world, input, candidates, program, remaining - 1,
        legacyTime(world, input, candidates) :: legacy,
        compiledTime(world, input, program) :: compiled)

def percentile(samples: List[Int64], percent: Int32): Float64 = {
    let index = Int32.min(List.length(samples) - 1, Int32.max(0, (List.length(samples) * percent) / 100 - 1));
    Int64.toFloat64(Option.getWithDefault(0i64, List.nth(index, samples))) / 1000000.0
}

def relatedRules(): #{SameFile(Repository.Structure.SymbolId, Repository.Structure.SymbolId), Related(Repository.Structure.SymbolId) | r} = #{
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
    let synthesis = Radii.Expr.Compose(Radii.Expr.Atom(Radii.Atom.Defines), Radii.Expr.Atom(Radii.Atom.Calls));
    Assert.assertEq(expected = "Compose(Atom(Defines), Calls)", ToString.toString(atlas));
    Assert.assertEq(expected = 3, Radii.cost(synthesis))
}

@Test
def policyCostAndSortAreExplicit(): Unit \ Assert = {
    let defines = Radii.Expr.Atom(Radii.Atom.Defines);
    let calls = Radii.Expr.Atom(Radii.Atom.Calls);
    let imports = Radii.Expr.Atom(Radii.Atom.Imports);
    Assert.assertEq(expected = Some(Radii.Expr.Compose(defines, calls)), Radii.compose(defines, calls));
    Assert.assertEq(expected = None, Radii.compose(defines, imports));
    Assert.assertEq(expected = 3, Radii.cost(Radii.Expr.Compose(defines, calls)))
}

@Test
def normalizationKnowsPublicInversesAndAliases(): Unit \ Assert = {
    let calls = Radii.Expr.Atom(Radii.Atom.Calls);
    let callees = Radii.Expr.Atom(Radii.Atom.Callees);
    let callers = Radii.Expr.Atom(Radii.Atom.Callers);
    Assert.assertEq(expected = calls, Radii.normalize(callees));
    Assert.assertEq(expected = callers, Radii.reverse(calls));
    Assert.assertEq(expected = calls, Radii.reverse(callers));
    Assert.assertEq(expected = 11, Set.size(Radii.atoms()))
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
    }, Repository.Structure.sameFile(defines));
    Assert.assertEq(expected = Set#{(symbol(2), symbol(0)), (symbol(3), symbol(2))}, Repository.Structure.callers(calls));
    Assert.assertEq(expected = Set#{
        (symbol(0), symbol(2)), (symbol(0), symbol(3)), (symbol(1), symbol(2)), (symbol(1), symbol(3))
    }, Repository.Structure.importNeighbors(defines, imports));
    Assert.assertEq(expected = Set#{
        (symbol(2), symbol(0)), (symbol(2), symbol(1)), (symbol(3), symbol(0)), (symbol(3), symbol(1))
    }, Repository.Structure.importerNeighbors(defines, imports));
    Assert.assertEq(expected = Set#{
        (location(0), location(2)), (location(1), location(2)), (location(2), location(0)), (location(2), location(1))
    }, Repository.Structure.repositoryAdjacent(parents))
}

@Test
def wholeConstraintCatalogComposesAtQuerySite(): Unit \ Assert = {
    let defines = Set#{(file(0), symbol(0)), (file(0), symbol(1)), (file(1), symbol(2))};
    let facts = Repository.Structure.repositoryFacts(defines, Set#{(file(0), file(1))}, Set#{(symbol(0), symbol(2))}, Set.empty());
    let actual = query facts, Repository.Structure.structuralRules() select (x, y) from SameFile(x, y);
    Assert.assertEq(expected = 5, Vector.length(actual))
}

@Test
def independentConstraintFragmentsComposeAtQuerySite(): Unit \ Assert = {
    let defines = Set#{(file(0), symbol(0)), (file(0), symbol(1)), (file(1), symbol(2))};
    let facts = Repository.Structure.repositoryFacts(defines, Set#{(file(0), file(1))}, Set.empty(), Set.empty());
    let actual = query facts, Repository.Structure.importRules(), Repository.Structure.sameFileRules()
        select (x, y) from ImportNeighbor(x, y);
    Assert.assertEq(expected = Vector#{(symbol(0), symbol(2)), (symbol(1), symbol(2))}, actual)
}

@Test
def solvedConstraintProjectionComposesAgain(): Unit \ Assert = {
    let defines = Set#{(file(0), symbol(0)), (file(0), symbol(1)), (file(1), symbol(2))};
    let facts = Repository.Structure.repositoryFacts(defines, Set.empty(), Set.empty(), Set.empty());
    let structural = solve facts, Repository.Structure.sameFileRules() project SameFile;
    let actual = query structural, relatedRules() select x from Related(x);
    Assert.assertEq(expected = Vector#{symbol(0), symbol(1), symbol(2)}, actual)
}

@Test
def regionMemoMakesSharedPrefixesPhysicalDags(): Unit \ Assert = {
    let world = Radii.Evaluate.fromBasis(
        Radii.Evaluate.WorldId.WorldId("fixture"),
        Set#{(file(0), symbol(0))},
        Set.empty(),
        Set#{(symbol(0), symbol(2)), (symbol(2), symbol(3))},
        Set.empty()
    );
    let defines = Radii.Expr.Atom(Radii.Atom.Defines);
    let calls = Radii.Expr.Atom(Radii.Atom.Calls);
    let callers = Radii.Expr.Atom(Radii.Atom.Callers);
    let prefix = Radii.Expr.Compose(defines, calls);
    let candidates = Radii.Expr.Compose(prefix, calls) :: Radii.Expr.Compose(prefix, callers) :: Nil;
    match Radii.Evaluate.evaluateAll(world, Radii.Evaluate.State.Files(Set#{file(0)}), candidates) {
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
def compiledProgramPreservesNormalizedRootOrder(): Unit \ Assert = {
    let raw = Radii.Expr.Atom(Radii.Atom.Callees) ::
        Radii.Expr.Reverse(Radii.Expr.Atom(Radii.Atom.Calls)) :: Nil;
    let program = Radii.Compiled.compile(raw);
    Assert.assertEq(expected = 2, Radii.Compiled.rootCount(program));
    Assert.assertEq(expected =
        Vector#{
            Radii.Expr.Atom(Radii.Atom.Calls),
            Radii.Expr.Atom(Radii.Atom.Callers)
        },
        Vector.map(root -> root#expression, program#roots))
}

@Test
def decideHandlersAreTypedAndExact(): Unit \ Assert = {
    let state = Radii.Evaluate.State.Symbols(Set#{symbol(0)});
    let alternatives = Vector#{
        {
            action = Decide.Action.Follow(Radii.Atom.Calls),
            expression = Some(Radii.Evaluate.exprId(Radii.Expr.Atom(Radii.Atom.Calls))),
            state = Radii.Evaluate.stateId(state),
            criterion = "Follow outgoing calls."
        },
        {
            action = Decide.Action.Follow(Radii.Atom.Callers),
            expression = Some(Radii.Evaluate.exprId(Radii.Expr.Atom(Radii.Atom.Callers))),
            state = Radii.Evaluate.stateId(state),
            criterion = "Follow incoming calls."
        }
    };
    match Decide.request(Radii.Evaluate.stateId(state), "fixture state", alternatives) {
        case Err(error) => Assert.fail(ToString.toString(error))
        case Ok(request) => {
            let fake = Decide.runWithFake(1, () -> Decide.policy(request));
            match fake {
                case Err(error) => Assert.fail(ToString.toString(error))
                case Ok(observation) => {
                    Assert.assertEq(expected = 1, observation#choiceIndex);
                    let replay = Decide.runWithReplay(
                        Map#{request#decision => observation},
                        () -> Decide.policy(request)
                    );
                    match replay {
                        case Err(error) => Assert.fail(ToString.toString(error))
                        case Ok(replayed) => {
                            Assert.assertEq(expected = observation#decision, replayed#decision);
                            Assert.assertEq(expected = observation#choice, replayed#choice);
                            Assert.assertEq(expected = observation#choiceIndex, replayed#choiceIndex)
                        }
                    }
                }
            }
        }
    }
}

@Test
def gritFixtureHandlerEliminatesCapability(): Unit \ Assert = {
    let fixture = Repository.Grit.Wire.Wire("{\"version\":1,\"matched\":false}");
    let wire = Repository.Grit.runWithFixture(fixture, () -> Repository.Grit.evaluate(Repository.Grit.Language.TypeScript, Repository.Grit.Program.Calls, "example.ts", ""));
    Assert.assertEq(expected = Repository.Grit.json(fixture), Repository.Grit.json(wire))
}

@Test
def gritWireDecodingPreservesNestedUtf8ByteFacts(): Unit \ Assert = {
    let source = "const π = 'é';\nBoolean(verify(name));";
    let wire = Repository.Grit.Wire.Wire(
        "{\"version\":1,\"matched\":true,\"matches\":[" +
        "{\"path\":\"nested.ts\",\"start_byte\":17,\"end_byte\":38}," +
        "{\"path\":\"nested.ts\",\"start_byte\":25,\"end_byte\":37}]," +
        "\"logs\":[{\"message\":\"call\\n\",\"start_byte\":17,\"end_byte\":24}," +
        "{\"message\":\"call\\n\",\"start_byte\":25,\"end_byte\":31}]," +
        "\"diagnostics\":[]}"
    );
    match Repository.Grit.facts("nested.ts", source, wire) {
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
    let native = Repository.Grit.Wire.Wire("{\"version\":1,\"error\":{\"kind\":\"compile\",\"message\":\"bad program\"}}");
    let future = Repository.Grit.Wire.Wire("{\"version\":2,\"matched\":false,\"matches\":[],\"logs\":[],\"diagnostics\":[]}");
    let outside = Repository.Grit.Wire.Wire(
        "{\"version\":1,\"matched\":true,\"matches\":[]," +
        "\"logs\":[{\"message\":\"call\",\"start_byte\":0,\"end_byte\":1}],\"diagnostics\":[]}"
    );
    match Repository.Grit.decode(native) {
        case Err(Repository.Grit.Error.Native(kind, message)) =>
            Assert.assertEq(expected = ("compile", "bad program"), (kind, message))
        case _ => Assert.fail("native error lost its classification")
    };
    match Repository.Grit.decode(future) {
        case Err(Repository.Grit.Error.UnsupportedVersion(version)) => Assert.assertEq(expected = 2, version)
        case _ => Assert.fail("future wire version was accepted")
    };
    match Repository.Grit.facts("x.ts", "x", outside) {
        case Err(Repository.Grit.Error.LogOutsideMatch(start, end)) => Assert.assertEq(expected = (0, 1), (start, end))
        case _ => Assert.fail("orphan log was accepted")
    }
}

@Test
def gritNativeHandlerKeepsIoAtTheEdge(): Unit \ {Assert, IO} = {
    let wire = Repository.Grit.runWithNative(() -> Repository.Grit.evaluate(Repository.Grit.Language.TypeScript, Repository.Grit.Program.Calls, "example.ts", "verify(name);"));
    Assert.assertTrue(String.isSubmatch(regex = "\\\"matched\\\":true", Repository.Grit.json(wire)))
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
    match Repository.Grit.runWithNative(() -> Repository.extract(sources)) {
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
            let facts = Repository.Structure.repositoryFacts(world#defines, world#imports, world#calls, world#parents);
            let sameFile = query facts, Repository.Structure.sameFileRules() select (x, y) from SameFile(x, y);
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

@Test
def nixFixtureHandlerRequiresCompleteStoreIdentity(): Unit \ Assert = {
    let wire = Repository.Nix.Wire.Wire(
        "{\"version\":1,\"text\":\"{" +
        "\\\"instanceId\\\":\\\"fixture\\\"," +
        "\\\"repository\\\":\\\"owner/repo\\\"," +
        "\\\"baseCommit\\\":\\\"abc\\\"," +
        "\\\"language\\\":\\\"javascript\\\"," +
        "\\\"benchmarkRevision\\\":\\\"def\\\"," +
        "\\\"benchmark\\\":\\\"/nix/store/benchmark\\\"," +
        "\\\"snapshot\\\":\\\"/nix/store/snapshot\\\"," +
        "\\\"sources\\\":[]}\"," +
        "\"store_paths\":[\"/nix/store/benchmark\",\"/nix/store/snapshot\"]}"
    );
    match Repository.Nix.runWithFixture(wire, () -> Repository.Nix.sweExplore()) {
        case Err(error) => Assert.fail(ToString.toString(error))
        case Ok(case_) => {
            Assert.assertEq(expected = ("fixture", "owner/repo", "abc", "javascript", "def"),
                (case_#instanceId, case_#repository, case_#baseCommit,
                 case_#language, case_#benchmarkRevision));
            Assert.assertEq(expected = ("/nix/store/benchmark", "/nix/store/snapshot"),
                (Repository.Nix.path(case_#benchmark), Repository.Nix.path(case_#snapshot)));
            Assert.assertEq(expected = 0, Vector.length(case_#sources))
        }
    };
    let incomplete = Repository.Nix.Wire.Wire(
        "{\"version\":1,\"text\":\"{" +
        "\\\"instanceId\\\":\\\"fixture\\\"," +
        "\\\"repository\\\":\\\"owner/repo\\\"," +
        "\\\"baseCommit\\\":\\\"abc\\\"," +
        "\\\"language\\\":\\\"javascript\\\"," +
        "\\\"benchmarkRevision\\\":\\\"def\\\"," +
        "\\\"benchmark\\\":\\\"/nix/store/benchmark\\\"," +
        "\\\"snapshot\\\":\\\"/nix/store/snapshot\\\"," +
        "\\\"sources\\\":[]}\"," +
        "\"store_paths\":[\"/nix/store/benchmark\"]}"
    );
    match Repository.Nix.runWithFixture(incomplete, () -> Repository.Nix.sweExplore()) {
        case Err(Repository.Nix.Error.IncompleteContext) => ()
        case Err(error) => Assert.fail("unexpected error: ${ToString.toString(error)}")
        case Ok(_) => Assert.fail("incomplete Nix store context was accepted")
    }
}

@Test
def nixNativeBoundaryRealisesThePinnedSweExploreIdentity(): Unit \ {Assert, IO} =
    match Repository.Nix.runWithNative(() -> Repository.Nix.sweExplore()) {
        case Err(error) => Assert.fail(ToString.toString(error))
        case Ok(case_) => {
            Assert.assertEq(expected =
                ("axios__axios-4731", "axios/axios",
                 "c30252f685e8f4326722de84923fcbc8cf557f06", "javascript",
                 "bdb0ae45d7c337d9e1dc3ebfe2a0af6bc7c1fbd9"),
                (case_#instanceId, case_#repository, case_#baseCommit,
                 case_#language, case_#benchmarkRevision));
            Assert.assertTrue(String.startsWith(prefix = "/nix/store/", Repository.Nix.path(case_#benchmark)));
            Assert.assertTrue(String.startsWith(prefix = "/nix/store/", Repository.Nix.path(case_#snapshot)));
            Assert.assertEq(expected = 114, Vector.length(case_#sources))
        }
    }

@Test
def nixOwnedSweExploreSnapshotMatchesFrozenPythonOracle(): Unit \ {Assert, IO} =
    match Repository.Nix.runWithNative(() -> Repository.Nix.sweExplore()) {
        case Err(error) => Assert.fail(ToString.toString(error))
        case Ok(case_) => match Repository.Grit.runWithNative(() -> Repository.extract(case_#sources)) {
            case Err(error) => Assert.fail(ToString.toString(error))
            case Ok(world) => {
                // Current Python cold-facts oracle: .attune/atlas/swe-explore-tsjs-v1/cold/03.json.
                // Grit SHA-256: defines bba7b2aa..., imports 368c1c09..., calls de0e5436...
                // Marzano/Grit revision: c80b3026471b229f41b279c3eb0c162dcdacfdb1.
                Assert.assertEq(expected =
                    (114, 295, 295, 140, 220, 148, 56, 4925),
                    (Vector.length(world#files), Vector.length(world#symbols),
                     Set.size(world#defines), Set.size(world#imports),
                     Set.size(world#calls), Set.size(world#parents),
                     world#unresolvedImports, world#unresolvedCalls));
                match Atlas.measure(world, Repository.allSymbols(world), 7) {
                    case Err(error) => Assert.fail(error)
                    case Ok(signature) => Assert.assertEq(expected = (7, 3279, 1643),
                        (signature#depth, signature#logicalPrograms, signature#symbolPrograms))
                };

                let candidates = compiledFileCandidates(7);
                let input = Radii.Evaluate.State.Files(Set.singleton(file(37)));
                let physical = Radii.Evaluate.fromBasis(
                    Radii.Evaluate.WorldId.WorldId("axios/axios@c30252f685e8f4326722de84923fcbc8cf557f06"),
                    world#defines, world#imports, world#calls, world#parents
                );
                let program = Radii.Compiled.compile(candidates);
                Assert.assertEq(expected = "lib/helpers/isAxiosError.js", Vector.get(37, world#files));
                Assert.assertEq(expected = 2463, List.length(candidates));
                Assert.assertEq(expected = 3164, Radii.Compiled.nodeCount(program));
                match (Radii.Evaluate.evaluateAll(physical, input, candidates), Radii.Compiled.evaluate(physical, input, program)) {
                    case (Err(error), _) => Assert.fail(error)
                    case (_, Err(error)) => Assert.fail(error)
                    case (Ok(legacy), Ok(compact)) => {
                        Assert.assertEq(expected = legacy#results, Radii.Compiled.materializeLegacy(program, compact));
                        Assert.assertEq(expected = Vector.map(Radii.normalize, List.toVector(candidates)),
                            Vector.map(root -> root#expression, program#roots));
                        println("COMPILED_PARITY\taxios/axios\tFILE\t37\t${List.length(candidates)}\t${Radii.Compiled.nodeCount(program)}\t${compact#metrics#statesInterned}\t${compact#metrics#memoEntries}\t${compact#metrics#memoSlots}")
                    }
                };
                warmCompiled(physical, input, candidates, program, 20);
                let (legacySamples, compiledSamples) = sampleCompiled(physical, input, candidates, program, 100, Nil, Nil);
                println("COMPILED_TIMING_MS\tlegacy_p50=${percentile(legacySamples, 50)}\tcompiled_p50=${percentile(compiledSamples, 50)}\tcompiled_p90=${percentile(compiledSamples, 90)}\tcompiled_p95=${percentile(compiledSamples, 95)}\tspeedup=${percentile(legacySamples, 50) / percentile(compiledSamples, 50)}")
            }
        }
    }
