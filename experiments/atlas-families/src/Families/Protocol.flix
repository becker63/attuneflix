/// The versioned, issue-blind families acquisition protocols. Every pinned
/// model, endpoint, model-visible instruction, and budget bound has exactly
/// one owner here; `PROTOCOL.md` embeds the rendered constants and
/// `report_test` pins them, so the document cannot drift from the code.
///
/// Issue-blindness is structural: every provider payload is a pure function of
/// these constants and one admitted repository world. No issue text, evaluator
/// gold, localization population, or query side exists at this boundary.
pub mod Families.Protocol {
    pub def provider(): String = "openrouter"

    /// Jev family-formation decisions (space `jev-families-raw-v1`).
    pub def decisions(): String = "attune-jev-families-v1"
    pub def decisionSpace(): String = "jev-families-raw-v1"
    pub def decisionEndpoint(): String = "https://openrouter.ai/api/alpha/decisions"
    pub def decisionModel(): String = "typesafe/jev-1.13"
    pub def stateHeader(): String = "ATTUNE_FAMILIES_STATE_V1"
    /// Identity of one exact frontier (sorted member ids), never its preview.
    pub def stateProtocol(): String = "attune-families-state-v1"
    pub def objective(): String = "family-formation"

    /// Atlas's frozen depth bound; navigation never extends a route past it.
    pub def maxDepth(): Int32 = 7
    pub def previewSize(): Int32 = 8
    pub def nameCandidates(): Int32 = 6

    pub def navigationQuestion(): String = "next_action"

    pub def navigationInstructions(): String =
        "Choose the typed repository-structure action that grows the seed into the most coherent code family: " +
        "entities that serve one shared purpose and belong together as one unit of the repository. " +
        "Prefer an action whose result stays focused on the seed's purpose, and avoid an action that pulls in unrelated code. " +
        "Choose stop when the current frontier is already a more coherent family than every available structural child."

    pub def namingQuestion(): String = "family_name"

    pub def namingInstructions(): String =
        "Choose the repository location that best names the family grown from the seed: " +
        "the most specific location that still describes what the family's members have in common."

    /// Issue-blind callable embeddings (space `families-embeddings-v1`): the
    /// frozen document recipe with no query side.
    pub def embeddings(): String = "attune-families-embeddings-v1"
    pub def embeddingSpace(): String = "families-embeddings-v1"
    pub def embeddingEndpoint(): String = "https://openrouter.ai/api/v1/embeddings"
    pub def embeddingModel(): String = "qwen/qwen3-embedding-8b"
    pub def dimension(): Int32 = 4096
    /// The frozen per-document limit, in Unicode code points.
    pub def textLimit(): Int32 = 48000
    pub def batchSize(): Int32 = 64
    /// Little-endian float32 vectors, base64 encoded by the provider.
    pub def encodingFormat(): String = "base64"

    /// Budget accounting. The envelope bounds one acquisition pass; the unit
    /// bounds are deliberately pessimistic so the projection made before any
    /// provider call is an upper bound on the measured spend.
    pub def ledger(): String = "attune-families-ledger-v1"
    /// User-adjusted operational cap for every new live pass.
    pub def envelopeUsd(): Float64 = 5.0
    /// Preact was acquired before the M1 cap adjustment; its immutable typed
    /// ledger must continue to replay against the envelope it recorded.
    pub def legacyEnvelopeUsd(): Float64 = 50.0
    pub def legacySnapshotId(): String =
        "repository-snapshot-v1:6e2bef41bf19f638be084df8cb82127e4832d4abbafa8ca20ebd5db9be3ac8a9"
    /// Catalog price of the pinned embedding model, USD per input token.
    pub def embeddingUsdPerToken(): Float64 = 0.00000001
    /// Upper bound per decision (the frozen Jev mean was about 0.00005 USD).
    pub def decisionUsdBound(): Float64 = 0.0002

    /// Bounded live navigation preserves original seed ordinals across passes.
    /// 3,000 seeds x eight possible decisions x the per-decision bound = $4.80.
    pub def boundedSeedsPerPass(): Int32 = 3000

    /// A token covers at least one byte, so document bytes bound the tokens.
    pub def projectedEmbeddingUsd(documentBytes: Int64): Float64 =
        Int64.toFloat64(documentBytes) * embeddingUsdPerToken()

    /// Each seed makes at most `maxDepth` navigation decisions and one naming
    /// decision.
    pub def projectedDecisionUsd(seeds: Int32): Float64 =
        Int32.toFloat64(seeds * (maxDepth() + 1)) * decisionUsdBound()
}
