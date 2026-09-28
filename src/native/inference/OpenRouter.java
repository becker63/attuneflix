package attune.inference;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import dev.langchain4j.exception.HttpException;
import dev.langchain4j.http.client.HttpClientBuilder;
import dev.langchain4j.http.client.jdk.JdkHttpClient;
import java.time.Duration;
import java.util.concurrent.Callable;

/** Shared LangChain4j transport for OpenRouter. Request construction and response meaning stay outside it. */
final class OpenRouter {
    static final String BASE_URL = "https://openrouter.ai/api/v1";
    private static final String KEY = "OPENROUTER_API_KEY";
    private static final long INITIAL_BACKOFF_MILLIS = 250L;
    private static final ObjectMapper JSON = new ObjectMapper();

    private OpenRouter() {}

    /** The credential is read only inside this package and never enters a request identity. */
    static String apiKey() {
        String apiKey = System.getenv(KEY);
        if (apiKey == null || apiKey.isBlank()) {
            throw new MissingKey();
        }
        return apiKey;
    }

    static HttpClientBuilder http() {
        return JdkHttpClient.builder()
                .connectTimeout(Duration.ofSeconds(30))
                .readTimeout(Duration.ofMinutes(3));
    }

    /** Retries only transient provider statuses; every other failure surfaces at once. */
    static <T> T withRetry(Callable<T> call, int maxAttempts) throws Exception {
        long backoff = INITIAL_BACKOFF_MILLIS;
        for (int attempt = 1; ; attempt++) {
            try {
                return call.call();
            } catch (HttpException error) {
                if (!retryable(error.statusCode()) || attempt >= maxAttempts) {
                    throw error;
                }
            }
            Thread.sleep(backoff);
            backoff *= 2;
        }
    }

    private static boolean retryable(int statusCode) {
        return statusCode == 408 || statusCode == 429 || statusCode >= 500;
    }

    static String failure(String kind, String message) {
        ObjectNode root = JSON.createObjectNode();
        root.put("version", 1);
        ObjectNode error = root.putObject("error");
        error.put("kind", kind);
        error.put("message", message);
        return root.toString();
    }

    /** The failure kind of a transport error, in the retained envelope vocabulary. */
    static String kind(Throwable error) {
        if (error instanceof MissingKey) return "configuration";
        if (error instanceof HttpException http) return "http-" + http.statusCode();
        if (error instanceof InterruptedException) return "interrupted";
        return "provider";
    }

    static String safeMessage(Throwable error) {
        if (error instanceof MissingKey) return KEY + " is not set";
        String message = error.getMessage();
        String apiKey = System.getenv(KEY);
        if (message != null && apiKey != null && !apiKey.isEmpty()) {
            message = message.replace(apiKey, "[redacted]");
        }
        return error.getClass().getSimpleName() + (message == null ? "" : ": " + message);
    }

    static final class MissingKey extends IllegalStateException {
        MissingKey() {
            super(KEY + " is not set");
        }
    }
}
