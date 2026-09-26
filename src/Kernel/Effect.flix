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

    pub eff Digest { def digest(payload: String): Result[CapabilityError, String] }
    pub eff SourceRead { def readText(path: String): Result[CapabilityError, String] }
    pub eff Grit { def extract(language: String, relation: FactKind, path: String, source: String): Result[CapabilityError, Vector[RawFact]] }
    pub eff ArtifactStore { def read(path: String): Result[CapabilityError, String] }
    pub eff Embedding { def embed(text: String): Result[CapabilityError, Vector[Float64]] }
    pub eff JudgeModel { def decide(issue: String, candidates: CandidateSet): Result[CapabilityError, Selection] }
}
