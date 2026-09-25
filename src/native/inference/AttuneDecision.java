package attune.inference;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

/** Raw OpenRouter Decisions transport; request identity and admission are Flix. */
public final class AttuneDecision {
    private static final String ENDPOINT = "https://openrouter.ai/api/alpha/decisions";
    private static final int MAX_ATTEMPTS = 5;
    private static final ObjectMapper JSON = new ObjectMapper();

    private AttuneDecision() {}

    public static String decide(String payload) {
        String apiKey = System.getenv("OPENROUTER_API_KEY");
        if (apiKey == null || apiKey.isBlank()) {
            return failure("configuration", "OPENROUTER_API_KEY is not set");
        }
        try {
            return OpenRouter.post(ENDPOINT, payload, apiKey, MAX_ATTEMPTS);
        } catch (OpenRouter.HttpFailure error) {
            return failure("http-" + error.statusCode(), safeMessage(error));
        } catch (InterruptedException error) {
            Thread.currentThread().interrupt();
            return failure("interrupted", safeMessage(error));
        } catch (Throwable error) {
            return failure("provider", safeMessage(error));
        }
    }

    private static String failure(String kind, String message) {
        ObjectNode root = JSON.createObjectNode();
        root.put("version", 1);
        ObjectNode error = root.putObject("error");
        error.put("kind", kind);
        error.put("message", message == null ? "unknown Decisions failure" : message);
        return root.toString();
    }

    private static String safeMessage(Throwable error) {
        String message = error.getMessage();
        String apiKey = System.getenv("OPENROUTER_API_KEY");
        if (message != null && apiKey != null && !apiKey.isEmpty()) {
            message = message.replace(apiKey, "[redacted]");
        }
        return error.getClass().getSimpleName() + (message == null ? "" : ": " + message);
    }
}
