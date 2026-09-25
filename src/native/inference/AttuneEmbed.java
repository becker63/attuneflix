package attune.inference;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

/** The entire JVM-visible OpenRouter embedding boundary. */
public final class AttuneEmbed {
    private static final String PROVIDER = "openrouter";
    private static final String ENDPOINT = "https://openrouter.ai/api/v1/embeddings";
    private static final int BATCH_SIZE = 64;
    private static final int MAX_ATTEMPTS = 3;
    private static final ObjectMapper JSON = new ObjectMapper();

    private AttuneEmbed() {}

    /**
     * Embeds a JSON array of strings and returns a stable JSON envelope.
     * The API key is read only here and is never accepted as an argument.
     */
    public static String embed(String model, String textsJson) {
        try {
            if (model == null || model.isBlank()) {
                throw new IllegalArgumentException("embedding model must not be empty");
            }
            List<String> texts = decodeTexts(textsJson);
            String apiKey = System.getenv("OPENROUTER_API_KEY");
            if (apiKey == null || apiKey.isBlank()) {
                throw new IllegalStateException("OPENROUTER_API_KEY is not set");
            }
            List<JsonNode> vectors = new ArrayList<>(texts.size());
            long inputTokens = 0;
            long totalTokens = 0;
            boolean hasUsage = false;
            for (int start = 0; start < texts.size(); start += BATCH_SIZE) {
                int end = Math.min(start + BATCH_SIZE, texts.size());
                JsonNode response = JSON.readTree(OpenRouter.post(
                        ENDPOINT,
                        request(model, texts.subList(start, end)),
                        apiKey,
                        MAX_ATTEMPTS));
                List<JsonNode> batch = decodeVectors(response, end - start);
                vectors.addAll(batch);
                JsonNode usage = response.path("usage");
                if (usage.isObject()) {
                    hasUsage = true;
                    inputTokens += usage.path("prompt_tokens").asLong(0);
                    totalTokens += usage.path("total_tokens").asLong(0);
                }
            }
            return success(model, vectors, hasUsage, inputTokens, totalTokens);
        } catch (JsonProcessingException error) {
            return failure("request", error.getOriginalMessage());
        } catch (IllegalArgumentException error) {
            return failure("request", error.getMessage());
        } catch (OpenRouter.HttpFailure error) {
            return failure("http-" + error.statusCode(), safeMessage(error));
        } catch (InterruptedException error) {
            Thread.currentThread().interrupt();
            return failure("interrupted", safeMessage(error));
        } catch (Throwable error) {
            return failure("provider", safeMessage(error));
        }
    }

    private static List<String> decodeTexts(String payload) throws JsonProcessingException {
        JsonNode root = JSON.readTree(payload);
        if (!root.isArray()) {
            throw new IllegalArgumentException("texts must be a JSON array");
        }
        List<String> result = new ArrayList<>(root.size());
        for (JsonNode value : root) {
            if (!value.isTextual()) {
                throw new IllegalArgumentException("every embedding input must be a string");
            }
            result.add(value.textValue());
        }
        return result;
    }

    private static String request(String model, List<String> texts) {
        ObjectNode root = JSON.createObjectNode();
        root.put("model", model);
        ArrayNode input = root.putArray("input");
        texts.forEach(input::add);
        return root.toString();
    }

    private static List<JsonNode> decodeVectors(JsonNode response, int expected) {
        List<JsonNode> data = new ArrayList<>();
        response.path("data").forEach(data::add);
        data.sort(Comparator.comparingInt(item -> item.path("index").asInt()));
        if (data.size() != expected) {
            throw new IllegalArgumentException("provider returned " + data.size() + " vectors for " + expected + " inputs");
        }
        List<JsonNode> vectors = new ArrayList<>(expected);
        for (JsonNode item : data) {
            JsonNode embedding = item.path("embedding");
            if (!embedding.isArray()) {
                throw new IllegalArgumentException("provider returned a non-vector embedding");
            }
            vectors.add(embedding);
        }
        return vectors;
    }

    private static String success(
            String model,
            List<JsonNode> embeddings,
            boolean hasUsage,
            long inputTokens,
            long totalTokens) {
        ObjectNode root = JSON.createObjectNode();
        root.put("version", 1);
        root.put("provider", PROVIDER);
        root.put("model", model);
        ArrayNode vectors = root.putArray("vectors");
        for (JsonNode embedding : embeddings) {
            ArrayNode vector = vectors.addArray();
            for (JsonNode coordinate : embedding) {
                vector.add(coordinate.floatValue());
            }
        }
        if (hasUsage) {
            ObjectNode usageJson = root.putObject("usage");
            usageJson.put("input_tokens", inputTokens);
            usageJson.put("total_tokens", totalTokens);
        }
        return root.toString();
    }

    private static String failure(String kind, String message) {
        ObjectNode root = JSON.createObjectNode();
        root.put("version", 1);
        ObjectNode error = root.putObject("error");
        error.put("kind", kind);
        error.put("message", message == null ? "unknown embedding failure" : message);
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
