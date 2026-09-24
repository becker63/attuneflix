import attune.inference.AttuneDecision

@Test
def keylessNativeInferenceBoundaryReturnsConfigurationError(): Unit \ {Assert, IO} = {
    let actual = AttuneDecision.decide("{}");
    let expected =
        "{\"version\":1,\"error\":{\"kind\":\"configuration\"," +
        "\"message\":\"OPENROUTER_API_KEY is not set\"}}";
    Assert.assertEq(
        expected = expected,
        actual
    )
}
