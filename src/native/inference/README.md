# Native inference transport

This directory is the small JVM seam between Flix and OpenRouter.

```text
Provider:       OpenRouter
Embeddings:     OpenAI-compatible embeddings endpoint
Decisions:      OpenRouter Decisions endpoint
Credential:     OPENROUTER_API_KEY
```

The credential is transport-only. It is read inside this boundary, is never a
scientific input, and must not enter request identities, retained artifacts,
Bazel actions, reports, or logs.

This seam owns:

- HTTP requests;
- retry and backoff;
- provider wire formats;
- transport failures;
- redaction of transport errors.

Flix owns:

- provider and model choice;
- prompts and instructions;
- exact model-visible payloads;
- semantic request and observation identities;
- response admission;
- replay and retention;
- embedding ranking;
- Atlas and Localization;
- experiment and evaluation semantics.

The current embedding transport still uses LangChain4j. It is migration debt,
not part of the scientific interface. Removing it in favor of JDK `HttpClient`
and Jackson requires a differential check of the exact request texts, model,
batch order, vector order, token usage, admitted errors, and retained replay.
Changing the Java package or HTTP client does not invalidate a semantically
identical retained observation.
