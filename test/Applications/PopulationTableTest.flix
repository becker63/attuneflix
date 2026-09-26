def populationFixture(): Population.Frozen = {
    let cases = Vector.map(index -> {
        ordinal = index,
        instanceId = "case-${index}",
        repository = "owner/repo",
        baseRevision = "revision-${index}",
        datasetFamily = "pro",
        language = "typescript",
        population = "new",
        split = if (index < 42) "optimization-development" else "post-optimization-validation",
        sourceRouting = "extension-explicit-v1",
        sourceIdentity = "github:owner/repo@revision-${index}",
        outcome = if (index >= 76) Population.Outcome.Censored("frozen provider limit")
                  else Population.Outcome.Completed
    }, Vector.range(0, 78));
    {
        protocol = {
            benchmarkRevision = "benchmark", multilingualRevision = "multilingual",
            proRevision = "pro", sourceRouting = "extension-explicit-v1",
            atlasProtocol = "atlas-composition-depth7-v1", maxDepth = 7,
            centerCount = 8, logicalRoutes = 3279, symbolRoutes = 1643
        },
        cases = cases
    }
}

@Test
def populationTablesRoundTripTypedMeaning(): Unit \ Assert = {
    let expected = populationFixture();
    let tables = Population.Table.rows(expected);
    Assert.assertEq(expected = "attune-population-metadata-v1", Population.Table.metadata()#format);
    Assert.assertEq(expected = "attune-population-cases-v1", Population.Table.cases()#format);
    match Population.Table.frozen(tables) {
        case Err(error) => Assert.fail(error)
        case Ok(actual) => {
            let actualTables = Population.Table.rows(actual);
            Assert.assertTrue(actualTables#metadata == tables#metadata);
            Assert.assertTrue(actualTables#cases == tables#cases)
        }
    }
}
