def localizationPrepared(): Localization.Prepared = {
    let issue: Localization.Issue = {
        instanceId = "case", repository = "repo", baseCommit = "rev",
        text = Localization.IssueText.IssueText("fix b")
    };
    {
        instanceId = "case", repository = "repo", baseCommit = "rev",
        issue = issue, world = TestWorlds.abWorld()
    }
}

def localizationPrior(): Localization.Prior = {
    instanceId = "case", repository = "repo", baseCommit = "rev",
    ranking = Vector#{
        {identity = "a", score = 0.9, ordinal = 0},
        {identity = "b", score = 0.8, ordinal = 1}
    }
}

@Test
def localizationTablesHaveExplicitSchemas(): Unit \ Assert = {
    Assert.assertEq(expected = "attune-localization-issue-v1",
        Localization.IssueTable.schema()#format);
    Assert.assertEq(expected = "attune-semantic-prior-metadata-v1",
        Localization.PriorTable.metadata()#format);
    Assert.assertEq(expected = "attune-semantic-prior-documents-v1",
        Localization.PriorTable.documents()#format);
    Assert.assertEq(expected = "attune-semantic-prior-ranking-v1",
        Localization.PriorTable.ranking()#format);
    Assert.assertEq(expected = "attune-localization-prediction-summary-v2",
        Localization.PredictionTable.summary()#format);
    Assert.assertEq(expected = "attune-localization-prediction-ranking-v2",
        Localization.PredictionTable.ranking()#format)
}

@Test
def sandwichEnumeratesThenDeduplicatesTypedOutcomes(): Unit \ Assert = {
    let result = Localization.Sandwich.search(localizationPrepared(), localizationPrior(), 3);
    match result {
        case Err(error) => Assert.fail(error)
        case Ok(search) => {
            Assert.assertEq(expected = Atlas.counts(3)#complete, search#logicalRoutes);
            Assert.assertTrue(search#uniqueSemanticStates <= search#logicalRoutes);
            Assert.assertTrue(search#physicalTransitions > 0)
        }
    }
}

@Test
def judgeCanLeaveThePriorUntouched(): Unit \ Assert = {
    match Localization.Sandwich.search(localizationPrepared(), localizationPrior(), 2) {
        case Err(error) => Assert.fail(error)
        case Ok(search) => {
            let prediction = Localization.Sandwich.runWith(
                (_, _) -> Ok(Localization.Sandwich.Selection.Prior),
                () -> Localization.Sandwich.localize(localizationPrepared(), search));
            match prediction {
                case Err(error) => Assert.fail(error)
                case Ok(value) => {
                    Assert.assertEq(expected = Localization.Sandwich.Selection.Prior, value#selection);
                    Assert.assertEq(
                        expected = Vector.map(item -> item#identity, localizationPrior()#ranking),
                        Vector.map(item -> item#identity, value#ranking))
                }
            }
        }
    }
}
