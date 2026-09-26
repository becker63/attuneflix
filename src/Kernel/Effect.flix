/// Capability effects: the single door for the outside world (digest, source
/// text, native Grit facts, stored artifact payloads, semantic embeddings, the
/// learned judge). Pure declarations only: no FFI import, no file, no provider.
pub mod Kernel.Effect {
    use Kernel.Contract.{CandidateSet, FactKind, RawFact, Selection}

    /// One structured failure vocabulary: `Unavailable`, `Malformed`, `Rejected`.
    pub enum CapabilityError with Eq, ToString {
        case Unavailable(String),
        case Malformed(String),
        case Rejected(String)
    }

    /// Content addressing is total: a digest is a pure function of its payload,
    /// and an absent provider is a construction failure of the shell, not a
    /// data-dependent outcome. So `Digest` alone carries no `Result`, which is
    /// what lets the analytical identity functions be `\ Digest` rather than
    /// fallible. The remaining five capabilities keep `CapabilityError` because
    /// their providers can genuinely refuse, fail, or be unavailable.
    pub eff Digest { def digest(payload: String): String }
    pub eff SourceRead { def readText(path: String): Result[CapabilityError, String] }
    pub eff Grit { def extract(language: String, relation: FactKind, path: String, source: String): Result[CapabilityError, Vector[RawFact]] }
    pub eff ArtifactStore { def read(path: String): Result[CapabilityError, String] }
    pub eff Embedding { def embed(text: String): Result[CapabilityError, Vector[Float64]] }
    pub eff JudgeModel { def decide(issue: String, candidates: CandidateSet): Result[CapabilityError, Selection] }
}
