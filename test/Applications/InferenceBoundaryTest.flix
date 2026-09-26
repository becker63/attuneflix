import attune.inference.AttuneDecision
import attune.inference.AttuneEmbed

@Test
def keylessNativeInferenceBoundaryReturnsConfigurationError(): Unit \ {Assert, IO} = {
    let expected =
        "{\"version\":1,\"error\":{\"kind\":\"configuration\"," +
        "\"message\":\"OPENROUTER_API_KEY is not set\"}}";
    Assert.assertEq(expected = expected, AttuneDecision.decide("{}"))
}

@Test
def embedRejectsBlankModelBeforeAnyTransportUse(): Unit \ {Assert, IO} = {
    let expected =
        "{\"version\":1,\"error\":{\"kind\":\"request\"," +
        "\"message\":\"embedding model must not be empty\"}}";
    Assert.assertEq(expected = expected, AttuneEmbed.embed("", "[]"))
}
