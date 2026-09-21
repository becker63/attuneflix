use Fs.FileSystem

@Test
def semanticPriorRecipeIsPinned(): Unit \ Assert = {
    Assert.assertEq(expected = "openrouter", Localization.provider());
    Assert.assertEq(expected = "qwen/qwen3-embedding-8b", Localization.model());
    Assert.assertEq(expected = 48000, Localization.textLimit());
    Assert.assertEq(expected = 4096, Localization.dimension());
    Assert.assertEq(
        expected = "Instruct: Given a software bug report, retrieve the source-code function most relevant to fixing it.\nQuery:fix headers",
        Localization.queryText("fix headers")
    )
}

@Test
def semanticPriorClippingCountsUnicodeCodePointsLikePython(): Unit \ Assert = {
    let actual = Localization.queryText(String.repeat(48000, "😀"));
    // The historical `half = (limit - marker.length) // 2` leaves one unused
    // code point when the marker length has odd parity.
    Assert.assertEq(expected = 47999, Localization.codePointLength(actual));
    Assert.assertFalse(String.isSubmatch(regex = "�", actual));
    Assert.assertTrue(String.isSubmatch(regex = "\\.\\.\\.\\[truncated for embedding\\]\\.\\.\\.", actual))
}

@Test
def exactEmbeddingRequestHasExactCanonicalIdentity(): Unit \ Assert = {
    let issue = Localization.IssueText.IssueText("fix headers");
    let left = Localization.queryRequest(issue);
    let right = Localization.queryRequest(issue);
    let document = Localization.documentRequest("src/a.ts:f", "function f() {} ");
    Assert.assertTrue(left#id == right#id);
    Assert.assertTrue(left#id != document#id)
}

@Test
def embeddingIdentityCannotContainTransportSecret(): Unit \ Assert = {
    let sentinel = "definitely-not-a-real-openrouter-key";
    let request = Localization.queryRequest(Localization.IssueText.IssueText("issue"));
    let Localization.RequestId.RequestId(material) = request#id;
    Assert.assertFalse(String.isSubmatch(regex = "${sentinel}", material))
}

@Test
def embeddingReplayMissIsExplicitAndCannotReachNetwork(): Unit \ Assert = {
    let request = Localization.queryRequest(Localization.IssueText.IssueText("unseen"));
    let result = Localization.runWithReplay(Map.empty(), () -> Localization.acquire(Vector#{request}));
    match result {
        case Err(Localization.Error.ReplayMiss) => ()
        case _ => Assert.fail("replay miss did not remain explicit")
    }
}

@Test
def embeddingFixtureHandlerEliminatesCapability(): Unit \ Assert = {
    let request = Localization.documentRequest("src/a.ts:f", "function f() {}");
    let observation = {id = request#id, vector = Vector#{1.0f32, 2.0f32}};
    let result = Localization.runWithFixture(
        Map#{request#id => observation},
        () -> Localization.acquire(Vector#{request})
    );
    match result {
        case Ok(actual) => {
            Assert.assertEq(expected = 1, Vector.length(actual));
            Assert.assertTrue(Vector.get(0, actual)#id == observation#id);
            Assert.assertEq(expected = Vector#{1.0f32, 2.0f32}, Vector.get(0, actual)#vector)
        }
        case Err(error) => Assert.fail(ToString.toString(error))
    }
}

@Test
def retainedEmbeddingRoundTripsThroughFlixFileSystem(): Unit \ {Assert, FileSystem} =
    run {
        let request = Localization.documentRequest("src/a.ts:f", "function f() {}");
        let vector = Vector.range(0, Localization.dimension()) |> Vector.map(_ -> 1.0f32);
        let observation = {id = request#id, vector = vector};
        match Localization.retainAll("/retained", Vector#{observation}) {
            case Err(error) => Assert.fail(ToString.toString(error))
            case Ok(()) => {
                match FileSystem.read("/retained/raw/batch-0.json") {
                    case Err(error) => Assert.fail(ToString.toString(error))
                    case Ok(payload) => {
                        Assert.assertTrue(String.isSubmatch(regex = "\\\"request_ids\\\"", payload));
                        Assert.assertTrue(String.isSubmatch(regex = "\\\"response\\\"", payload))
                    }
                };
                match Localization.replayRetained("/retained", Vector#{request}) {
                    case Err(error) => Assert.fail(ToString.toString(error))
                    case Ok(actual) => {
                        Assert.assertEq(expected = 1, Vector.length(actual));
                        Assert.assertTrue(Vector.get(0, actual)#id == observation#id);
                        Assert.assertEq(expected = observation#vector, Vector.get(0, actual)#vector)
                    }
                }
            }
        }
    } with FileSystem.withMemoryOverlay

@Test
def malformedEmbeddingEnvelopeStaysTyped(): Unit \ Assert = {
    let request = Localization.documentRequest("src/a.ts:f", "function f() {}");
    match Localization.decode(Vector#{request}, Localization.Wire.Wire("not json")) {
        case Err(Localization.Error.Wire(_)) => ()
        case _ => Assert.fail("malformed embedding response was admitted")
    }
}

@Test
def embeddingAdmissionChecksCountAndDimension(): Unit \ Assert = {
    let request = Localization.documentRequest("src/a.ts:f", "function f() {}");
    let wrongCount = Localization.Wire.Wire(
        "{\"version\":1,\"provider\":\"openrouter\",\"model\":\"qwen/qwen3-embedding-8b\",\"vectors\":[]}"
    );
    let emptyDimension = Localization.Wire.Wire(
        "{\"version\":1,\"provider\":\"openrouter\",\"model\":\"qwen/qwen3-embedding-8b\",\"vectors\":[[]]}"
    );
    let wrongDimension = Localization.Wire.Wire(
        "{\"version\":1,\"provider\":\"openrouter\",\"model\":\"qwen/qwen3-embedding-8b\",\"vectors\":[[1.0,2.0]]}"
    );
    match Localization.decode(Vector#{request}, wrongCount) {
        case Err(Localization.Error.WrongVectorCount(expected, actual)) =>
            Assert.assertEq(expected = (1, 0), (expected, actual))
        case _ => Assert.fail("wrong vector count was admitted")
    };
    match Localization.decode(Vector#{request}, emptyDimension) {
        case Err(Localization.Error.EmptyDimension) => ()
        case _ => Assert.fail("empty vector dimension was admitted")
    };
    match Localization.decode(Vector#{request}, wrongDimension) {
        case Err(Localization.Error.UnexpectedDimension(expected, actual)) =>
            Assert.assertEq(expected = (4096, 2), (expected, actual))
        case _ => Assert.fail("wrong vector dimension was admitted")
    }
}

@Test
def semanticRankingIsCosineThenStableOrdinal(): Unit \ Assert = {
    let candidates = Vector#{
        {identity = "later", ordinal = 2, vector = Vector#{1.0f32, 0.0f32}},
        {identity = "best", ordinal = 1, vector = Vector#{0.0f32, 1.0f32}},
        {identity = "earlier", ordinal = 0, vector = Vector#{1.0f32, 0.0f32}}
    };
    let actual = Localization.rank(Vector#{1.0f32, 0.0f32}, candidates)
        |> Vector.map(item -> item#identity);
    Assert.assertEq(expected = Vector#{"earlier", "later", "best"}, actual)
}

@Test
def solverIssueAndEvaluatorGoldRemainDistinctTypes(): Unit \ Assert = {
    let issue = Localization.IssueText.IssueText("same bytes");
    let gold = Localization.GoldFiles.GoldFiles(Set#{"same bytes"});
    let request = Localization.queryRequest(issue);
    Assert.assertTrue(request#kind == Localization.InputKind.Query);
    Assert.assertTrue(gold == Localization.GoldFiles.GoldFiles(Set#{"same bytes"}))
}

@Test
def solverIssueProjectionAdmitsNoGoldFields(): Unit \ Assert = {
    let payload =
        "{\"version\":1,\"revision\":\"pinned\",\"issues\":[{" +
        "\"instanceId\":\"case-1\",\"repository\":\"owner/repo\"," +
        "\"baseCommit\":\"abc\",\"problemStatement\":\"fix it\"}]}";
    match Localization.decodeIssue("case-1", "owner/repo", "abc", payload) {
        case Err(error) => Assert.fail(ToString.toString(error))
        case Ok(issue) => {
            let Localization.IssueText.IssueText(text) = issue#text;
            Assert.assertEq(expected = "fix it", text)
        }
    }
}
