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

The seam uses only JDK `HttpClient` and Jackson. Embedding requests retain the
frozen 64-text batch boundary, input and vector order, retry count, and token
usage projection. Decision requests return the provider body unchanged. Java
does not interpret either result beyond the provider wire envelope; Flix
admits it or rejects it.

LangChain4j was removed after exact keyless replay had sealed every retained
observation. Changing this HTTP implementation does not invalidate a
semantically identical retained observation, and it does not authorize a new
provider call.
