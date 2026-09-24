package attune.inference;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/** Keyless transport-boundary laws. Live provider behavior is tested by retained replay. */
public final class AttuneInferenceTest {
    private static final ObjectMapper JSON = new ObjectMapper();

    private AttuneInferenceTest() {}

    public static void main(String[] args) throws Exception {
        requireError(AttuneEmbed.embed("", "[]"), "request");
        requireError(AttuneEmbed.embed("model", "{}"), "request");
        requireError(AttuneDecision.decide("{}"), "configuration");
    }

    private static void requireError(String envelope, String kind) throws Exception {
        JsonNode error = JSON.readTree(envelope).path("error");
        if (!kind.equals(error.path("kind").textValue())) {
            throw new AssertionError("expected " + kind + " error, got: " + envelope);
        }
        if (envelope.contains("Bearer ") || envelope.contains("OPENROUTER_API_KEY=")) {
            throw new AssertionError("transport secret leaked into error envelope");
        }
    }
}
