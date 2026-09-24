/// Temporary executable surface while snapshot inputs move into Bazel. The
/// command already compiles independently from tests; census work will extend
/// this entry point without turning `flix test` back into an experiment runner.
def main(): Unit \ IO = {
    let counts = Atlas.counts(7);
    println("atlas_protocol=atlas-composition-depth7-v1");
    println("signature_protocol=atlas-signature-swe-explore-v1");
    println("logical_programs=${counts#logical}");
    println("symbol_ending_programs=${counts#complete}")
}
