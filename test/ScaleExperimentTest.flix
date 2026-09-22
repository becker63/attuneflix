mod ScaleExperimentTest {
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
            case Some(mode) => Assert.fail("unknown ATTUNE_SCALE_MODE: ${mode}")
        }

    def parseShard(value: Option[String]): Result[String, (Int32, Int32)] = match value {
        case Some("0/4") => Ok((0, 4))
        case Some("1/4") => Ok((1, 4))
        case Some("2/4") => Ok((2, 4))
        case Some("3/4") => Ok((3, 4))
        case Some("0/78") => Ok((0, 78))
        case _ => Err("ATTUNE_CASE_SHARD must be 0/4, 1/4, 2/4, or 3/4")
    }
}
