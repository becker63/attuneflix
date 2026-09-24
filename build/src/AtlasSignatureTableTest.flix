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
    Assert.assertEq(expected = 10, Vector.length(Atlas.Signature.Table.caseSnapshots()#columns))
}
