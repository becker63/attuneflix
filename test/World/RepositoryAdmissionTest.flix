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
    match Repository.admit(sources, definitions, Vector.empty(), calls) {
        case Err(error) => Assert.fail(ToString.toString(error))
        case Ok(world) => {
            let symbol = Repository.Structure.SymbolId.SymbolId;
            Assert.assertEq(expected = Set#{
                (symbol(1), symbol(2)),
                (symbol(0), symbol(3))
            }, world#calls);
            Assert.assertEq(expected = 2, world#unresolvedCalls)
        }
    }
}
