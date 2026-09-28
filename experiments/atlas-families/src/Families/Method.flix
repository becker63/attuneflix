/// The versioned families clustering method (`atlas-families-v1`). Every
/// constant the clustering depends on has exactly one owner here, and
/// `PROTOCOL.md` embeds the rendered constants (pinned by `report_test`).
///
/// The method is a pure function of one admitted world and its recorded
/// families evidence: Jev's recorded walks propose the candidate families and
/// their names, and the affinity substrate (six-atom structure plus recorded
/// embedding similarity, combined with the weights below) decides which
/// candidate each symbol joins. Changing any weight is a new method version.
pub mod Families.Method {
    /// The method, its output space, and the family identity protocol.
    pub def protocol(): String = "atlas-families-v1"
    pub def space(): String = "atlas-families-v1"

    /// The mean affinity of one symbol to the other members of a candidate is
    /// the weighted sum of five per-pair indicators averaged over those
    /// members: sharing a defining file (`Defines`/`DefinedIn`), a call edge
    /// in either direction (`Calls`/`Callers`), an import edge between their
    /// files in either direction (`Imports`/`ImportedBy`), sharing a
    /// directory (the admitted `parent` prefixes), and the cosine similarity
    /// of their recorded embedding vectors.
    pub type alias Weights = {
        sameFile  = Float64,
        calls     = Float64,
        imports   = Float64,
        directory = Float64,
        semantic  = Float64
    }

    /// Structure carries three quarters of the weight: the admitted relations
    /// are exact, while embedding similarity is a recorded model judgement,
    /// so it refines assignments within the structure rather than overriding it.
    pub def weights(): Weights = {
        sameFile = 0.30,
        calls = 0.20,
        imports = 0.15,
        directory = 0.10,
        semantic = 0.25
    }

    /// The single-source ablations the report measures against `weights()`.
    pub def structuralOnly(): Weights = {semantic = 0.0 | weights()}

    pub def semanticOnly(): Weights = {sameFile = 0.0, calls = 0.0, imports = 0.0, directory = 0.0, semantic = weights()#semantic}

    /// The named rows of a weight set, in the order the protocol renders them.
    pub def weightRows(value: Weights): Vector[(String, Float64)] = Vector#{
        ("same file", value#sameFile),
        ("calls", value#calls),
        ("imports", value#imports),
        ("directory", value#directory),
        ("semantic", value#semantic)
    }
}
