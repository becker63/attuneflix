package attune.inference;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

/** Small shared HTTP seam. Request construction and response meaning stay outside it. */
final class OpenRouter {
    private static final long INITIAL_BACKOFF_MILLIS = 250L;
    private static final HttpClient HTTP = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(30))
            .build();

    private OpenRouter() {}

    static String post(String endpoint, String payload, String apiKey, int maxAttempts)
            throws IOException, InterruptedException {
        long backoff = INITIAL_BACKOFF_MILLIS;
        for (int attempt = 1; attempt <= maxAttempts; attempt++) {
            try {
                HttpRequest request = HttpRequest.newBuilder(URI.create(endpoint))
                        .timeout(Duration.ofMinutes(3))
                        .header("Authorization", "Bearer " + apiKey)
                        .header("Content-Type", "application/json")
                        .POST(HttpRequest.BodyPublishers.ofString(payload))
                        .build();
                HttpResponse<String> response = HTTP.send(request, HttpResponse.BodyHandlers.ofString());
                if (response.statusCode() >= 200 && response.statusCode() < 300) {
                    return response.body();
                }
                if (!retryable(response.statusCode()) || attempt == maxAttempts) {
                    throw new HttpFailure(response.statusCode(), response.body());
                }
            } catch (HttpFailure error) {
                throw error;
            } catch (IOException error) {
                if (attempt == maxAttempts) throw error;
            }
            Thread.sleep(backoff);
            backoff *= 2;
        }
        throw new IllegalStateException("unreachable retry state");
    }

    private static boolean retryable(int statusCode) {
        return statusCode == 408 || statusCode == 429 || statusCode >= 500;
    }

    static final class HttpFailure extends IOException {
        private final int statusCode;

        HttpFailure(int statusCode, String body) {
            super("HTTP " + statusCode + ": " + body);
            this.statusCode = statusCode;
        }

        int statusCode() {
            return statusCode;
        }
    }
}
