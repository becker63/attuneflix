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
            case Some(mode) => Assert.fail("unknown ATTUNE_SCALE_MODE: ${mode}")
        }
}
