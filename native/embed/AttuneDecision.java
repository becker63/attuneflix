package attune.embed;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import dev.langchain4j.exception.HttpException;
import dev.langchain4j.http.client.HttpClient;
import dev.langchain4j.http.client.HttpMethod;
import dev.langchain4j.http.client.HttpRequest;
import dev.langchain4j.http.client.jdk.JdkHttpClient;

import java.time.Duration;

/** Raw OpenRouter Decisions transport; request identity and admission are Flix. */
public final class AttuneDecision {
    private static final String ENDPOINT = "https://openrouter.ai/api/alpha/decisions";
    private static final int MAX_ATTEMPTS = 5;
    private static final long INITIAL_BACKOFF_MILLIS = 250L;
    private static final ObjectMapper JSON = new ObjectMapper();
    private static final HttpClient HTTP = JdkHttpClient.builder()
            .connectTimeout(Duration.ofSeconds(30))
            .readTimeout(Duration.ofMinutes(3))
            .build();

    private AttuneDecision() {}

    public static String decide(String payload) {
        String apiKey = System.getenv("OPENROUTER_API_KEY");
        if (apiKey == null || apiKey.isBlank()) {
            return failure("configuration", "OPENROUTER_API_KEY is not set");
        }
        long backoff = INITIAL_BACKOFF_MILLIS;
        for (int attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
            try {
                return execute(payload, apiKey);
            } catch (HttpException error) {
                if (!retryable(error.statusCode()) || attempt == MAX_ATTEMPTS) {
                    return failure("http-" + error.statusCode(), safeMessage(error));
                }
            } catch (Throwable error) {
                return failure("provider", safeMessage(error));
            }
            try {
                Thread.sleep(backoff);
            } catch (InterruptedException error) {
                Thread.currentThread().interrupt();
                return failure("interrupted", safeMessage(error));
            }
            backoff *= 2;
        }
        return failure("provider", "unreachable retry state");
    }

    private static String execute(String payload, String apiKey) {
        try {
            HttpRequest request = HttpRequest.builder()
                    .method(HttpMethod.POST)
                    .url(ENDPOINT)
                    .addHeader("Authorization", "Bearer " + apiKey)
                    .addHeader("Content-Type", "application/json")
                    .body(payload)
                    .build();
            return HTTP.execute(request).body();
        } catch (HttpException error) {
            throw error;
        }
    }

    private static boolean retryable(int statusCode) {
        return statusCode == 408 || statusCode == 429 || statusCode >= 500;
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
