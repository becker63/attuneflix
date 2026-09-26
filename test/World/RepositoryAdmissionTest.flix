// Stage 2 world-admission laws (VAL-STAGE-002): the typed `Stage.World` boundary
// and the admission rule it drives. The world is a function of the raw fact
// manifest alone — dense ordinal IDs, resolved references, indexed calls.
use Kernel.Contract.{FactKind, RawFact, RawFactManifest}

def admissionFact(kind: String, path: String, start: Int32, end: Int32,
                  value: String): Repository.Grit.Fact = {
    kind = kind,
    path = path,
    startByte = start,
    endByte = end,
    value = value
}

@Test
def indexedCallAdmissionPreservesOwnerAndTargetRules(): Unit \ Assert = {
    let sources = Vector#{
        {path = "a.ts", content = ""},
        {path = "b.ts", content = ""},
        {path = "c.ts", content = ""}
    };
    let definitions = Vector#{
        admissionFact("definition", "a.ts", 0, 100, "outer"),
        admissionFact("definition", "a.ts", 10, 50, "inner"),
        admissionFact("definition", "a.ts", 110, 120, "hit"),
        admissionFact("definition", "b.ts", 0, 10, "globalOnly"),
        admissionFact("definition", "b.ts", 20, 30, "ambiguous"),
        admissionFact("definition", "c.ts", 20, 30, "ambiguous")
    };
    let calls = Vector#{
        // The narrowest enclosing definition owns this call; the local target
        // wins even though the index also contains repository-wide names.
        admissionFact("call", "a.ts", 20, 21, "hit"),
        // No local target exists, so the unique repository-wide target wins.
        admissionFact("call", "a.ts", 70, 71, "globalOnly"),
        // A repository-wide duplicate and a call without an owner are both
        // rejected exactly as in the reference scan.
        admissionFact("call", "a.ts", 20, 21, "ambiguous"),
        admissionFact("call", "a.ts", 130, 131, "hit")
    };
    match World.Admission.admit(sources, definitions, Vector.empty(), calls) {
        case Err(error) => Assert.fail(ToString.toString(error))
        case Ok(world) => {
            let symbol = Kernel.Contract.SymbolId.SymbolId;
            Assert.assertEq(expected = Set#{
                (symbol(1), symbol(2)),
                (symbol(0), symbol(3))
            }, world#calls);
            Assert.assertEq(expected = 2, world#unresolvedCalls)
        }
    }
}

def rawFact(kind: FactKind, path: String, start: Int32, end: Int32,
            value: String): RawFact = {
    kind      = kind,
    path      = path,
    startByte = start,
    endByte   = end,
    value     = value
}

/// The Stage 2 boundary: a `RawFactManifest` in, a dense-ordinal `AdmittedWorld`
/// out, with the same resolved references and parent locations as the rule.
@Test
def stageWorldAdmitsDenseIdsResolvedReferencesAndParentLocations(): Unit \ Assert = {
    let manifest: RawFactManifest = {
        repository = "demo",
        revision   = "rev-1",
        files      = Vector#{
            {path = "b.ts", content = ""},
            {path = "a.ts", content = ""}
        },
        facts      = Vector#{
            rawFact(FactKind.Defines, "a.ts", 0, 10, "helper"),
            rawFact(FactKind.Defines, "b.ts", 0, 20, "run"),
            rawFact(FactKind.Imports, "b.ts", 0, 5, "\"./a\""),
            rawFact(FactKind.Calls, "b.ts", 10, 15, "helper")
        }
    };
    match Stage.World.admit(manifest) {
        case Err(error) => Assert.fail(ToString.toString(error))
        case Ok(world) => {
            let file = Kernel.Contract.FileId.FileId;
            let symbol = Kernel.Contract.SymbolId.SymbolId;
            let location = Kernel.Contract.LocationId.LocationId;
            Assert.assertEq(expected = Vector#{"b.ts", "a.ts"}, world#files);
            Assert.assertEq(expected = Vector#{"helper", "run"},
                Vector.map(entry -> entry#name, world#symbols));
            Assert.assertEq(expected = Set#{(file(0), file(1))}, world#imports);
            Assert.assertEq(expected = Set#{(symbol(1), symbol(0))}, world#calls);
            Assert.assertEq(expected = Set#{
                (location(0), location(2)),
                (location(1), location(2))
            }, world#parents);
            Assert.assertEq(expected = 0, world#unresolvedImports);
            Assert.assertEq(expected = 0, world#unresolvedCalls)
        }
    }
}
