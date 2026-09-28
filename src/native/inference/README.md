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

The transport is the pinned LangChain4j 1.18.1 OpenAI-compatible client.
`OpenRouter` is the one shared transport: the only reader of the key, retry on
408, 429, and 5xx, and redacted failure descriptions. `AttuneEmbed` and
`AttuneDecision` keep their frozen forms: embedding requests retain the frozen
64-text batch boundary, input and vector order, retry count, and token usage
projection, and decision requests return the provider body unchanged.
`AttuneOpenRouter` hands the SDK's own types to Flix: a live `OpenAiClient`,
or a replay client that serves one recorded provider body through the same SDK
decoder with no key and no network, and `embed`, which returns the parsed
response beside the raw provider body (`executeRaw`). Java does not interpret
either result beyond the provider wire envelope; Flix admits it or rejects it.

The transport was previously plain JDK `HttpClient` and was returned to
LangChain4j by user steering (2026-09-28) for the Atlas Families acquisition
zone. Changing the HTTP implementation does not invalidate a semantically
identical retained observation, and it does not authorize a new provider call
outside that zone.
