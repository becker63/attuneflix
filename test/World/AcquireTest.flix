// Stage 1 acquisition laws (VAL-STAGE-001): `Stage.Acquire` is a pure typed
// transformation from `SourceManifest` to `RawFactManifest`. The `eff Grit`
// capability is supplied by an in-memory handler here, so the stage runs
// keyless and the law observes exactly how the stage routes each file.
use Kernel.Contract.{FactKind, RawFact, SourceManifest}
use Kernel.Effect.CapabilityError

def relationName(relation: FactKind): String = match relation {
    case FactKind.Defines => "defines"
    case FactKind.Imports => "imports"
    case FactKind.Calls   => "calls"
}

/// The fact a real Grit frontend would log: the language name and relation are
/// encoded in the value so the law can prove which program ran for which file.
def fixtureFact(language: String, relation: FactKind, path: String): RawFact = {
    kind      = relation,
    path      = path,
    startByte = 0,
    endByte   = 1,
    value     = "${language}/${relationName(relation)}"
}

@Test
def acquireRoutesEachLanguageThroughGritInCanonicalOrder(): Unit \ Assert = {
    let manifest: SourceManifest = {
        repository = "demo",
        revision   = "rev-1",
        files      = Vector#{
            {path = "src/app.ts", content = "app"},
            {path = "README.md", content = "docs"},
            {path = "pkg/BUILD", content = "load()"}
        }
    };
    let result = run {
        Stage.Acquire.acquire(manifest)
    } with handler Kernel.Effect.Grit {
        def extract(language, relation, path, _source, resume) =
            resume(Ok(Vector#{fixtureFact(language, relation, path)}))
    };
    match result {
        case Err(error) => Assert.fail(ToString.toString(error))
        case Ok(raw) => {
            Assert.assertEq(expected = "demo", raw#repository);
            Assert.assertEq(expected = "rev-1", raw#revision);
            Assert.assertEq(expected = Vector.length(manifest#files), Vector.length(raw#files));
            // The unadmitted README contributes nothing; each language's three
            // relation programs run in the frozen Defines/Imports/Calls order.
            Assert.assertEq(
                expected = Vector#{
                    (FactKind.Defines, "src/app.ts", "typescript/defines"),
                    (FactKind.Imports, "src/app.ts", "typescript/imports"),
                    (FactKind.Calls,   "src/app.ts", "typescript/calls"),
                    (FactKind.Defines, "pkg/BUILD", "starlark/defines"),
                    (FactKind.Imports, "pkg/BUILD", "starlark/imports"),
                    (FactKind.Calls,   "pkg/BUILD", "starlark/calls")
                },
                Vector.map(fact -> (fact#kind, fact#path, fact#value), raw#facts))
        }
    }
}

@Test
def acquirePropagatesTheGritCapabilityFailure(): Unit \ Assert = {
    let manifest: SourceManifest = {
        repository = "demo",
        revision   = "rev-1",
        files      = Vector#{{path = "src/app.ts", content = "app"}}
    };
    let result = run {
        Stage.Acquire.acquire(manifest)
    } with handler Kernel.Effect.Grit {
        def extract(_language, _relation, _path, _source, resume) =
            resume(Err(CapabilityError.Unavailable("native engine unavailable")))
    };
    match result {
        case Ok(_) => Assert.fail("expected the grit failure to propagate")
        case Err(error) =>
            Assert.assertEq(expected = CapabilityError.Unavailable("native engine unavailable"), error)
    }
}
