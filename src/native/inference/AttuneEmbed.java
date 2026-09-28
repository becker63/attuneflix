package attune.inference;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import dev.langchain4j.data.embedding.Embedding;
import dev.langchain4j.data.segment.TextSegment;
import dev.langchain4j.model.embedding.EmbeddingModel;
import dev.langchain4j.model.openai.OpenAiEmbeddingModel;
import dev.langchain4j.model.output.Response;
import dev.langchain4j.model.output.TokenUsage;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/** The frozen-recipe embedding envelope: vectors and token usage for a JSON array of texts. */
public final class AttuneEmbed {
    private static final String PROVIDER = "openrouter";
    private static final int BATCH_SIZE = 64;
    private static final ObjectMapper JSON = new ObjectMapper();
    private static final Map<String, EmbeddingModel> MODELS = new ConcurrentHashMap<>();

    private AttuneEmbed() {}

    /**
     * Embeds a JSON array of strings and returns a stable JSON envelope.
     * The API key is read only inside this package and is never accepted as an argument.
     */
    public static String embed(String model, String textsJson) {
        try {
            List<TextSegment> texts = decodeTexts(textsJson);
            Response<List<Embedding>> response = model(model).embedAll(texts);
            return success(model, response);
        } catch (JsonProcessingException error) {
            return OpenRouter.failure("request", error.getOriginalMessage());
        } catch (IllegalArgumentException error) {
            return OpenRouter.failure("request", error.getMessage());
        } catch (Throwable error) {
            return OpenRouter.failure(OpenRouter.kind(error), OpenRouter.safeMessage(error));
        }
    }

    private static EmbeddingModel model(String model) {
        if (model == null || model.isBlank()) {
            throw new IllegalArgumentException("embedding model must not be empty");
        }
        return MODELS.computeIfAbsent(model, ignored -> OpenAiEmbeddingModel.builder()
                .baseUrl(OpenRouter.BASE_URL)
                .apiKey(OpenRouter.apiKey())
                .httpClientBuilder(OpenRouter.http())
                .modelName(model)
                .maxSegmentsPerBatch(BATCH_SIZE)
                .maxRetries(2)
                .timeout(Duration.ofMinutes(3))
                .logRequests(false)
                .logResponses(false)
                .build());
    }

    private static List<TextSegment> decodeTexts(String payload) throws JsonProcessingException {
        JsonNode root = JSON.readTree(payload);
        if (!root.isArray()) {
            throw new IllegalArgumentException("texts must be a JSON array");
        }
        List<TextSegment> result = new ArrayList<>(root.size());
        for (JsonNode value : root) {
            if (!value.isTextual()) {
                throw new IllegalArgumentException("every embedding input must be a string");
            }
            result.add(TextSegment.from(value.textValue()));
        }
        return result;
    }

    private static String success(String model, Response<List<Embedding>> response) {
        ObjectNode root = JSON.createObjectNode();
        root.put("version", 1);
        root.put("provider", PROVIDER);
        root.put("model", model);
        ArrayNode vectors = root.putArray("vectors");
        for (Embedding embedding : response.content()) {
            ArrayNode vector = vectors.addArray();
            for (float coordinate : embedding.vector()) {
                vector.add(coordinate);
            }
        }
        TokenUsage usage = response.tokenUsage();
        if (usage != null) {
            ObjectNode usageJson = root.putObject("usage");
            putNullable(usageJson, "input_tokens", usage.inputTokenCount());
            putNullable(usageJson, "total_tokens", usage.totalTokenCount());
        }
        return root.toString();
    }

    private static void putNullable(ObjectNode node, String name, Integer value) {
        if (value == null) node.putNull(name); else node.put(name, value);
    }
}
