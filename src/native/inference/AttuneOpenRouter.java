package attune.inference;

import dev.langchain4j.http.client.HttpClient;
import dev.langchain4j.http.client.HttpClientBuilder;
import dev.langchain4j.http.client.HttpRequest;
import dev.langchain4j.http.client.SuccessfulHttpResponse;
import dev.langchain4j.http.client.sse.ServerSentEventListener;
import dev.langchain4j.http.client.sse.ServerSentEventParser;
import dev.langchain4j.model.openai.internal.OpenAiClient;
import dev.langchain4j.model.openai.internal.ParsedAndRawResponse;
import dev.langchain4j.model.openai.internal.embedding.EmbeddingRequest;
import dev.langchain4j.model.openai.internal.embedding.EmbeddingResponse;
import java.time.Duration;

/**
 * LangChain4j OpenAI-compatible clients for OpenRouter, handed to Flix as SDK
 * types. Flix builds the typed requests and admits the typed and raw responses;
 * this class only chooses the transport. A live client reads the key here; a
 * replay client serves one recorded provider body through the same SDK decoder
 * and has no key and no network.
 */
public final class AttuneOpenRouter {
    private static final int MAX_ATTEMPTS = 5;

    private AttuneOpenRouter() {}

    public static OpenAiClient live() {
        return client(OpenRouter.http(), OpenRouter.apiKey());
    }

    public static OpenAiClient replay(String recordedBody) {
        return client(new Recorded(recordedBody), null);
    }

    /** One provider exchange: the SDK-parsed response beside the raw provider body. */
    @SuppressWarnings("unchecked")
    public static ParsedAndRawResponse<EmbeddingResponse> embed(OpenAiClient client, EmbeddingRequest request)
            throws Exception {
        return OpenRouter.withRetry(() -> client.embedding(request).executeRaw(), MAX_ATTEMPTS);
    }

    /** A redacted, key-free description of a transport failure. */
    public static String describe(Throwable error) {
        return OpenRouter.kind(error) + ": " + OpenRouter.safeMessage(error);
    }

    @SuppressWarnings({"rawtypes", "unchecked"})
    private static OpenAiClient client(HttpClientBuilder http, String apiKey) {
        OpenAiClient.Builder builder = OpenAiClient.builder()
                .baseUrl(OpenRouter.BASE_URL)
                .httpClientBuilder(http)
                .connectTimeout(Duration.ofSeconds(30))
                .readTimeout(Duration.ofMinutes(3))
                .logRequests(false)
                .logResponses(false);
        if (apiKey != null) builder = builder.apiKey(apiKey);
        return (OpenAiClient) builder.build();
    }

    /** Serves exactly the recorded provider body; it never opens a connection. */
    private static final class Recorded implements HttpClientBuilder, HttpClient {
        private final String body;
        private Duration connectTimeout;
        private Duration readTimeout;

        Recorded(String body) {
            this.body = body;
        }

        @Override public Duration connectTimeout() { return connectTimeout; }
        @Override public HttpClientBuilder connectTimeout(Duration value) { connectTimeout = value; return this; }
        @Override public Duration readTimeout() { return readTimeout; }
        @Override public HttpClientBuilder readTimeout(Duration value) { readTimeout = value; return this; }
        @Override public HttpClient build() { return this; }

        @Override
        public SuccessfulHttpResponse execute(HttpRequest request) {
            return SuccessfulHttpResponse.builder().statusCode(200).body(body).build();
        }

        @Override
        public void execute(HttpRequest request, ServerSentEventParser parser, ServerSentEventListener listener) {
            throw new UnsupportedOperationException("recorded replay serves no streams");
        }
    }
}
