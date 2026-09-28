package attune.inference;

import dev.langchain4j.http.client.HttpClient;
import dev.langchain4j.http.client.HttpMethod;
import dev.langchain4j.http.client.HttpRequest;

/** Raw OpenRouter Decisions transport; request identity and admission are Flix. */
public final class AttuneDecision {
    private static final String ENDPOINT = "https://openrouter.ai/api/alpha/decisions";
    private static final int MAX_ATTEMPTS = 5;
    private static final HttpClient HTTP = OpenRouter.http().build();

    private AttuneDecision() {}

    /** Returns the provider body unchanged, or a redacted transport-failure envelope. */
    public static String decide(String payload) {
        try {
            String apiKey = OpenRouter.apiKey();
            HttpRequest request = HttpRequest.builder()
                    .method(HttpMethod.POST)
                    .url(ENDPOINT)
                    .addHeader("Authorization", "Bearer " + apiKey)
                    .addHeader("Content-Type", "application/json")
                    .body(payload)
                    .build();
            return OpenRouter.withRetry(() -> HTTP.execute(request).body(), MAX_ATTEMPTS);
        } catch (InterruptedException error) {
            Thread.currentThread().interrupt();
            return OpenRouter.failure("interrupted", OpenRouter.safeMessage(error));
        } catch (Throwable error) {
            return OpenRouter.failure(OpenRouter.kind(error), OpenRouter.safeMessage(error));
        }
    }
}
