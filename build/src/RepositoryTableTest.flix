use Util.Json.Json.JString

def repositoryTableFixture(): Repository.World = {
    let f0 = Repository.Structure.FileId.FileId(0);
    let f1 = Repository.Structure.FileId.FileId(1);
    let s0 = Repository.Structure.SymbolId.SymbolId(0);
    let s1 = Repository.Structure.SymbolId.SymbolId(1);
    {
        files = Vector#{"src/a.ts", "src/b.ts"},
        symbols = Vector#{
            {path = "src/a.ts", name = "a", startByte = 3, endByte = 8},
            {path = "src/b.ts", name = "b", startByte = 13, endByte = 21}
        },
        defines = Set#{(f0, s0), (f1, s1)},
        imports = Set#{(f0, f1)},
        calls = Set#{(s0, s1)},
        parents = Set#{
            (Repository.Structure.LocationId.LocationId(0), Repository.Structure.LocationId.LocationId(2)),
            (Repository.Structure.LocationId.LocationId(1), Repository.Structure.LocationId.LocationId(2))
        },
        unresolvedImports = 4,
        unresolvedCalls = 5
    }
}

def repositoryTableIdentity(): Repository.Table.Identity = {
    repository = "owner/repo",
    baseRevision = "abc123",
    sourceTreeIdentity = "source-tree-v1:tree",
    factIdentity = "repository-facts-v2:facts",
    snapshotId = "repository-snapshot-v1:snapshot"
}

@Test
def repositoryWorldTypedRowsRoundTripExactly(): Unit \ Assert = {
    let expected = repositoryTableFixture();
    let identity = repositoryTableIdentity();
    let encoded = Repository.Table.rows(identity, expected);
    Assert.assertEq(expected = (1, 4, 6), (
        Vector.length(encoded#metadata),
        Vector.length(encoded#entities),
        Vector.length(encoded#relations)
    ));
    match Repository.Table.world(identity, encoded) {
        case Err(error) => Assert.fail(error)
        case Ok(actual) => Assert.assertEq(expected = (
            expected#files, Vector.map(symbol -> (symbol#path, symbol#name, symbol#startByte, symbol#endByte), expected#symbols), expected#defines, expected#imports,
            expected#calls, expected#parents, expected#unresolvedImports,
            expected#unresolvedCalls
        ), (
            actual#files, Vector.map(symbol -> (symbol#path, symbol#name, symbol#startByte, symbol#endByte), actual#symbols), actual#defines, actual#imports,
            actual#calls, actual#parents, actual#unresolvedImports,
            actual#unresolvedCalls
        ))
    }
}

@Test
def repositoryWorldRejectsSnapshotIdentityDrift(): Unit \ Assert = {
    let identity = repositoryTableIdentity();
    let encoded = Repository.Table.rows(identity, repositoryTableFixture());
    let badMetadata = Map.insert("snapshot_id", JString("wrong"), Vector.get(0, encoded#metadata));
    match Repository.Table.world(identity, {
        metadata = Vector#{badMetadata},
        entities = encoded#entities,
        relations = encoded#relations
    }) {
        case Ok(_) => Assert.fail("repository world admitted mismatched identity")
        case Err(_) => ()
    }
}
