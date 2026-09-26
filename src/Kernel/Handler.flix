/// The effectful shell: the one place the world enters. `runProduction` bridges
/// the six capabilities to the native seams (AttuneIdentity, AttuneGrit,
/// `java.nio.file.Files`); `readTable` delegates to the one Parquet/Arrow
/// transport seam (`Scientific.Parquet`); `runReplay` supplies deterministic
/// in-memory fixtures so every law runs keyless. The pure `Kernel.Contract` and
/// the declared `Kernel.Effect` capabilities stay untouched by this module.
pub mod Kernel.Handler {
    import attune.grit.AttuneGrit
    import java.io.IOException
    import java.nio.file.{Files, Paths}

    use Kernel.Contract.{CandidateSet, FactKind, RawFact, Row, Schema, Selection}
    use Kernel.Effect.CapabilityError

    /// Production handlers: digest -> AttuneIdentity, source/artifact text ->
    /// `java.nio.file.Files`, native Grit facts -> AttuneGrit. Embedding and the
    /// judge model stay unconfigured because production never reaches a live
    /// provider; a replay fixture supplies them instead.
    pub def runProduction(computation: Unit -> a \ ef): a \ ((ef - {Kernel.Effect.Digest, Kernel.Effect.SourceRead, Kernel.Effect.Grit, Kernel.Effect.ArtifactStore, Kernel.Effect.Embedding, Kernel.Effect.JudgeModel}) + IO) =
        run {
            computation()
        } with handler Kernel.Effect.Digest {
            def digest(payload, resume) = resume(Kernel.DigestHandler.hash(payload))
        } with handler Kernel.Effect.SourceRead {
            def readText(path, resume) = resume(readFile(path))
        } with handler Kernel.Effect.Grit {
            def extract(language, relation, path, source, resume) = resume(extractFacts(language, relation, path, source))
        } with handler Kernel.Effect.ArtifactStore {
            def read(path, resume) = resume(readFile(path))
        } with handler Kernel.Effect.Embedding {
            def embed(_text, resume) = resume(Err(CapabilityError.Unavailable("embedding provider is not configured in production")))
        } with handler Kernel.Effect.JudgeModel {
            def decide(_issue, _candidates, resume) = resume(Err(CapabilityError.Rejected("judge model is not configured in production")))
        }

    /// Production typed-table bridge: read one Parquet table through the
    /// isolated transport seam and report the failure as a capability error.
    pub def readTable(path: String, schema: Schema): Result[CapabilityError, Vector[Row]] \ IO =
        Scientific.Parquet.readResult(path, schema)
            |> Result.mapErr(match error -> match error {
                case Scientific.Parquet.TableError.Unavailable(path0) => CapabilityError.Unavailable(path0)
                case Scientific.Parquet.TableError.Malformed(message) => CapabilityError.Malformed(message)
            })

    /// Keyless deterministic replay: every capability is supplied by a pure
    /// in-memory fixture, so stage transformations run with no disk, network,
    /// or external process.
    pub def runReplay(
        readSource: String -> Result[CapabilityError, String],
        readArtifact: String -> Result[CapabilityError, String],
        digestOf: String -> String,
        extractFacts: (String, FactKind, String, String) -> Result[CapabilityError, Vector[RawFact]],
        embedText: String -> Result[CapabilityError, Vector[Float64]],
        decideModel: (String, CandidateSet) -> Result[CapabilityError, Selection],
        computation: Unit -> a \ ef
    ): a \ (ef - {Kernel.Effect.Digest, Kernel.Effect.SourceRead, Kernel.Effect.Grit, Kernel.Effect.ArtifactStore, Kernel.Effect.Embedding, Kernel.Effect.JudgeModel}) =
        run {
            computation()
        } with handler Kernel.Effect.Digest {
            def digest(payload, resume) = resume(digestOf(payload))
        } with handler Kernel.Effect.SourceRead {
            def readText(path, resume) = resume(readSource(path))
        } with handler Kernel.Effect.Grit {
            def extract(language, relation, path, source, resume) = resume(extractFacts(language, relation, path, source))
        } with handler Kernel.Effect.ArtifactStore {
            def read(path, resume) = resume(readArtifact(path))
        } with handler Kernel.Effect.Embedding {
            def embed(text, resume) = resume(embedText(text))
        } with handler Kernel.Effect.JudgeModel {
            def decide(issue, candidates, resume) = resume(decideModel(issue, candidates))
        }

    def readFile(path: String): Result[CapabilityError, String] \ IO =
        try {
            Ok(Files.readString(Paths.get(path)))
        } catch {
            case _: IOException => Err(CapabilityError.Unavailable(path))
        }

    def extractFacts(language: String, relation: FactKind, path: String, source: String): Result[CapabilityError, Vector[RawFact]] \ IO = {
        let wire = AttuneGrit.evaluate(
            language,
            AttuneGrit.program(language, programName(relation)),
            path,
            source);
        match Repository.Grit.facts(path, source, Repository.Grit.Wire.Wire(wire)) {
            case Ok(facts) => Ok(Vector.map(fact -> rawFact(relation, fact), facts))
            case Err(error) => Err(CapabilityError.Malformed(ToString.toString(error)))
        }
    }

    def programName(relation: FactKind): String = match relation {
        case FactKind.Defines => "defines"
        case FactKind.Imports => "imports"
        case FactKind.Calls   => "calls"
    }

    def rawFact(relation: FactKind, fact: Repository.Grit.Fact): RawFact = {
        kind = relation,
        path = fact#path,
        startByte = fact#startByte,
        endByte = fact#endByte,
        value = fact#value
    }
}
