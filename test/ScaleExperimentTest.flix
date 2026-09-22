mod ScaleExperimentTest {
    import java.lang.Integer

    use Fs.FileSystem
    use Sys.Env

    /// Explicit experiment gate. Ordinary verification never realizes new
    /// population artifacts. The manifest path contains no issue text or gold.
    @Test
    def scaleExperimentGate(): Unit \ {Assert, Env, FileSystem, IO} =
        match Env.getVar("ATTUNE_SCALE_MODE") {
            case None => ()
            case Some("manifest") => match Repository.Nix.runWithNative(() ->
                ScaleExperiment.materialize(
                    "experiments/swe-explore-js-ts-scale/MANIFEST.json")) {
                case Err(error) => Assert.fail(ToString.toString(error))
                case Ok(manifest) => println(
                    "SCALE_MANIFEST cases=${ScaleExperiment.count(manifest)}" +
                    " historical=${ScaleExperiment.historicalCount(manifest)}" +
                    " validation=${ScaleExperiment.validationCount(manifest)}")
            }
            case Some("parity") => match Repository.Grit.runWithNative(() ->
                Repository.Nix.runWithNative(() ->
                    ScaleExperiment.historicalParity(".attune/repository-facts-v1"))) {
                case Err(error) => Assert.fail(ToString.toString(error))
                case Ok(()) => println("SCALE_PARITY cases=15 exact=true")
            }
            case Some("facts") => match parseShard(Env.getVar("ATTUNE_CASE_SHARD")) {
                case Err(message) => Assert.fail(message)
                case Ok((shard, shards)) => match Repository.Grit.runWithNative(() ->
                    Repository.Nix.runWithNative(() ->
                        ScaleExperiment.acquireNewFacts(
                            ".attune/repository-facts-js-ts-scale-v1", shard, shards))) {
                    case Err(error) => Assert.fail(ToString.toString(error))
                    case Ok(()) => ()
                }
            }
            case Some("issues") => match Repository.Nix.runWithNative(ScaleExperiment.issueCensus) {
                case Err(error) => Assert.fail(ToString.toString(error))
                case Ok(census) => println("SCALE_ISSUES cases=${census#cases}" +
                    " bytes=${census#payloadBytes} store_path=${census#storePath}")
            }
            case Some("prior-acquire") => match Repository.Nix.runWithNative(() -> ScaleExperiment.semanticPriorRange(
                    ".attune/semantic-prior-js-ts-scale-v1",
                    ".attune/repository-facts-js-ts-scale-v1",
                    true,
                    priorStartIndex(),
                    priorEndIndex())) {
                case Err(error) => Assert.fail(ToString.toString(error))
                case Ok(()) => ()
            }
            case Some("prior-prepare") => match Repository.Nix.runWithNative(() ->
                ScaleExperiment.semanticPriorCensus(
                    ".attune/repository-facts-js-ts-scale-v1")) {
                case Err(error) => Assert.fail(ToString.toString(error))
                case Ok(()) => ()
            }
            case Some("prior-replay") => match Repository.Nix.runWithNative(() -> ScaleExperiment.semanticPriorRange(
                    ".attune/semantic-prior-js-ts-scale-v1",
                    ".attune/repository-facts-js-ts-scale-v1",
                    false,
                    priorStartIndex(),
                    priorEndIndex())) {
                case Err(error) => Assert.fail(ToString.toString(error))
                case Ok(()) => ()
            }
            case Some(mode) => Assert.fail("unknown ATTUNE_SCALE_MODE: ${mode}")
        }

    def parseShard(value: Option[String]): Result[String, (Int32, Int32)] = match value {
        case Some("0/4") => Ok((0, 4))
        case Some("1/4") => Ok((1, 4))
        case Some("2/4") => Ok((2, 4))
        case Some("3/4") => Ok((3, 4))
        case Some("0/2") => Ok((0, 2))
        case Some("1/2") => Ok((1, 2))
        case Some("0/78") => Ok((0, 78))
        case _ => Err("unsupported ATTUNE_CASE_SHARD")
    }

    def priorStartIndex(): Int32 \ Env = match Env.getVar("ATTUNE_SCALE_PRIOR_START") {
        case None => 0
        case Some(value) => Integer.parseInt(value)
    }

    def priorEndIndex(): Int32 \ Env = match Env.getVar("ATTUNE_SCALE_PRIOR_END") {
        case None => 78
        case Some(value) => Integer.parseInt(value)
    }
}
