use ScientificTable.Value

def names(schema: ScientificTable.Schema): Vector[String] =
    Vector.map(column -> column#name, schema#columns)

@Test
def atlasCensusSchemasAreExplicitAndStable(): Unit \ Assert = {
    let observations = Atlas.Signature.Table.observations();
    Assert.assertEq(expected = "attune-atlas-signature-observations-v1", observations#format);
    Assert.assertEq(expected = Vector#{
        "signature_protocol", "atlas_protocol", "repository", "base_revision",
        "source_tree_identity", "fact_identity", "snapshot_id", "seed_domain",
        "seed_identity", "seed_ordinal", "route_id", "route_atoms", "depth",
        "first_atom", "last_atom", "terminal_domain", "input_cardinality",
        "output_cardinality", "domain_cardinality", "expansion_ratio",
        "reach_fraction", "extinct", "first_extinction_depth", "semantic_state_id",
        "same_as_input"
    }, names(observations));
    Assert.assertEq(expected = 2,
        Vector.count(column -> column#nullable, observations#columns));
    Assert.assertEq(expected = 14, Vector.length(Atlas.Signature.Table.snapshots()#columns));
    Assert.assertEq(expected = 19, Vector.length(Atlas.Signature.Table.physical()#columns));
    Assert.assertEq(expected = 1,
        Vector.count(column -> column#nullable, Atlas.Signature.Table.physical()#columns));
    Assert.assertEq(expected = 10, Vector.length(Atlas.Signature.Table.caseSnapshots()#columns))
}

@Test
def atlasCensusRowsCarryExactRouteStateAndWorkIdentities(): Unit \ {Assert, IO} = {
    let s0 = Repository.Structure.SymbolId.SymbolId(0);
    let s1 = Repository.Structure.SymbolId.SymbolId(1);
    let program = Vector.get(1, Atlas.programs(1));
    let observation: Atlas.Signature.Observation = {
        program = program,
        input = Atlas.State.Symbols(Set.singleton(s0)),
        output = Atlas.State.Symbols(Set.singleton(s1)),
        depth = 1,
        inputCardinality = 1,
        outputCardinality = 1,
        domainCardinality = 2,
        expansionRatio = Some(1.0),
        reachFraction = 0.5,
        extinct = false,
        firstExtinctionDepth = None,
        sameAsInput = false
    };
    let signature: Atlas.Signature.Signature = {
        depth = 1,
        observations = Vector#{observation},
        logicalPrograms = 3,
        uniqueStates = 2,
        physicalTransitions = 4,
        transitionReuses = 5
    };
    let snapshot: Atlas.Signature.Table.SnapshotIdentity = {
        signatureProtocol = "atlas-signature-swe-explore-v1",
        atlasProtocol = "atlas-composition-depth7-v1",
        repository = "owner/repo",
        baseRevision = "abc123",
        sourceTreeIdentity = "source-tree-v1:source",
        factIdentity = "repository-facts-v2:facts",
        snapshotId = "atlas-snapshot-v1:snapshot"
    };
    let seed: Atlas.Signature.Table.SeedIdentity = {
        domain = Radii.Domain.Symbol,
        identity = "symbol-seed-v1:seed",
        ordinal = 0
    };

    let row = Vector.get(0,
        Atlas.Signature.Table.observationRows(snapshot, seed, signature));
    Assert.assertEq(expected = Some(Value.Text("calls")), Map.get("first_atom", row));
    Assert.assertEq(
        expected = Some(Value.Text("atlas-route-v1:f46f5990ebfadcab199107258b9dadd8711bd7946d8d00091a1073effcf2a843")),
        Map.get("route_id", row)
    );
    Assert.assertEq(
        expected = Some(Value.Text("atlas-state-v1:66e0d95773bf3d8a754abbc13eae77b72ab23e7eb15eca9f92b1d2b644bcdde7")),
        Map.get("semantic_state_id", row)
    );
    Assert.assertEq(expected = Some(Value.Null), Map.get("first_extinction_depth", row));

    let physical = Atlas.Signature.Table.physicalRow(snapshot, seed, signature);
    Assert.assertEq(expected = Some(Value.Int64(9i64)),
        Map.get("physical_transition_requests", physical));
    Assert.assertEq(expected = Some(Value.Int64(4i64)), Map.get("memo_cells", physical));
    Assert.assertEq(expected = Some(Value.Null), Map.get("compiled_dag_nodes", physical))
}

@Test
def atlasCensusUsesTypedFileAndSymbolSeedFamilies(): Unit \ {Assert, IO} = {
    let f0 = Repository.Structure.FileId.FileId(0);
    let s0 = Repository.Structure.SymbolId.SymbolId(0);
    let world: Repository.World = {
        files = Vector#{"src/a.ts"},
        symbols = Vector#{{path = "src/a.ts", name = "a", startByte = 0, endByte = 1}},
        defines = Set#{(f0, s0)}, imports = Set.empty(), calls = Set.empty(),
        parents = Set.empty(), unresolvedImports = 0, unresolvedCalls = 0
    };
    let seeds = Atlas.Signature.seeds(world);
    Assert.assertEq(expected = Vector#{Radii.Domain.File, Radii.Domain.Symbol},
        Vector.map(seed -> seed#domain, seeds));
    Assert.assertEq(expected = 3279, Vector.length(Atlas.programsFrom(Radii.Domain.File, 7)));
    match Atlas.signature(world, Vector.get(0, seeds)#state, 1) {
        case Err(error) => Assert.fail(error)
        case Ok(signature) => Assert.assertEq(expected = 3, signature#logicalPrograms)
    }
}
