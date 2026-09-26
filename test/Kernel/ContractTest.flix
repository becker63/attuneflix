// Kernel contract laws (VAL-KERN-001/002/003).
//
// Every law is pure `\ Assert`: the kernel's nominal identities, pure
// relations, six-atom Atlas grammar, scientific schema, and stage ADTs
// instantiate and compose with no native seam, no `IO`, and no resolver. The
// schema law decodes a payload through pure Flix, so the zero-dependency
// boundary is proven by typechecking, not by inspection.
use Kernel.Contract.{AdmittedWorld, AtlasCandidateOutcomes, Atom, CandidateId, CandidateSet,
    ColumnType, ContextSpan, FactKind, FileId, PriorScores, Program, ProjectedContext,
    RawFact, RawFactManifest, Schema, Selection, SelectionOutcome, SourceFile, SourceManifest,
    State, Symbol, SymbolId, Value}
use Kernel.Contract.FileId.FileId
use Kernel.Contract.SymbolId.SymbolId
use Kernel.Contract.CandidateId.CandidateId

@Test
def nominalIdentitiesAreDistinctDomains(): Unit \ Assert = {
    Assert.assertEq(expected = "FileId(3)", ToString.toString(FileId(3)));
    Assert.assertEq(expected = "SymbolId(3)", ToString.toString(SymbolId(3)));
    Assert.assertEq(expected = "LocationId(3)",
        ToString.toString(Kernel.Contract.LocationId.LocationId(3)));
    Assert.assertTrue(Order.lessEqual(FileId(1), FileId(2)))
}

@Test
def pureRelationsCompose(): Unit \ Assert = {
    let defines: Kernel.Contract.Defines = Set#{
        (FileId(0), SymbolId(0)),
        (FileId(1), SymbolId(1))
    };
    let calls: Kernel.Contract.Calls = Set.singleton((SymbolId(0), SymbolId(1)));
    Assert.assertTrue(Set.memberOf((FileId(0), SymbolId(0)), defines));
    Assert.assertEq(expected = 2, Set.size(defines));
    Assert.assertEq(expected = 1, Set.size(calls))
}

@Test
def atlasGrammarIsSixDirectedAtoms(): Unit \ Assert = {
    Assert.assertEq(
        expected = Vector#{Atom.Defines, Atom.DefinedIn, Atom.Imports,
            Atom.ImportedBy, Atom.Calls, Atom.Callers},
        Kernel.Contract.atoms());
    let program: Program = {steps = Vector#{Atom.Defines, Atom.Calls}};
    Assert.assertEq(expected = 2, Vector.length(program#steps));
    match State.Files(Set.singleton(FileId(0))) {
        case State.Files(frontier) => Assert.assertEq(expected = 1, Set.size(frontier))
        case State.Symbols(_) => Assert.fail("expected a file frontier")
    }
}

@Test
def scientificSchemaDecodesPurely(): Unit \ Assert = {
    let schema: Schema = {
        format = "kernel-contract-probe-v1",
        columns = Vector#{
            {name = "symbol", kind = ColumnType.Text, nullable = false},
            {name = "depth", kind = ColumnType.Int32, nullable = false},
            {name = "reach", kind = ColumnType.Float64, nullable = true}
        }
    };
    Assert.assertEq(
        expected = "{\"columns\":[{\"name\":\"symbol\",\"nullable\":false,\"type\":\"string\"},{\"name\":\"depth\",\"nullable\":false,\"type\":\"int32\"},{\"name\":\"reach\",\"nullable\":true,\"type\":\"float64\"}],\"format\":\"kernel-contract-probe-v1\"}",
        Kernel.Contract.schemaPayload(schema));
    let payload = "[{\"symbol\":\"calls\",\"depth\":7,\"reach\":0.6636},{\"symbol\":\"defines\",\"depth\":1,\"reach\":null}]";
    match Kernel.Contract.decodeRows(schema, payload) {
        case Err(error) => Assert.fail(error)
        case Ok(rows) => {
            Assert.assertEq(expected = 2, Vector.length(rows));
            Assert.assertEq(expected = Ok("calls"),
                Kernel.Contract.text(Vector.get(0, rows), "symbol"));
            Assert.assertEq(expected = Ok(7.0),
                Kernel.Contract.number(Vector.get(0, rows), "depth"));
            Assert.assertEq(expected = Some(Value.Null), Map.get("reach", Vector.get(1, rows)))
        }
    }
}

@Test
def stagePipelineContractsCompose(): Unit \ Assert = {
    let source: SourceFile = {path = "a.flix", content = "main"};
    let manifest: SourceManifest = {
        repository = "attuneflix", revision = "probe", files = Vector#{source}
    };
    let fact: RawFact = {
        kind = FactKind.Defines, path = "a.flix", startByte = 0, endByte = 4, value = "main"
    };
    let facts: RawFactManifest = {
        repository = manifest#repository, revision = manifest#revision,
        files = manifest#files, facts = Vector#{fact}
    };
    let symbol: Symbol = {path = "a.flix", name = "main", startByte = 0, endByte = 4};
    let world: AdmittedWorld = {
        files = Vector#{"a.flix"}, symbols = Vector#{symbol},
        defines = Set.singleton((FileId(0), SymbolId(0))),
        imports = Set.empty(), calls = Set.empty(), parents = Set.empty(),
        unresolvedImports = 0, unresolvedCalls = 0
    };
    let prior: PriorScores = {scores = Vector#{{symbol = SymbolId(0), score = 1.0}}};
    let atlas: AtlasCandidateOutcomes = {outcomes = Vector#{{
        program = {steps = Vector#{Atom.Defines}},
        state = State.Symbols(Set.singleton(SymbolId(0))), depth = 1, reach = 1.0
    }}};
    let candidates: CandidateSet = {candidates = Vector#{{
        id = CandidateId(0), symbol = SymbolId(0), priorRank = Some(0), atlasReach = Some(1.0)
    }}};
    let outcome: SelectionOutcome = {
        issue = "probe", selection = Selection.Atlas(CandidateId(0)),
        ranking = Vector#{CandidateId(0)}
    };
    let span: ContextSpan = {
        path = "a.flix", symbol = SymbolId(0), startByte = 0, endByte = 4, text = "main"
    };
    let context: ProjectedContext = {
        selection = outcome#selection, spans = Vector#{span},
        tokenBudget = 8, estimatedTokens = 1, rendered = "a.flix:main"
    };
    Assert.assertEq(expected = 1, Vector.length(facts#facts));
    Assert.assertEq(expected = 1, Set.size(world#defines));
    Assert.assertEq(expected = 1, Vector.length(prior#scores));
    Assert.assertEq(expected = 1, Vector.length(atlas#outcomes));
    Assert.assertEq(expected = 1, Vector.length(candidates#candidates));
    Assert.assertEq(expected = Selection.Atlas(CandidateId(0)), outcome#selection);
    Assert.assertEq(expected = 1, Vector.length(context#spans))
}
