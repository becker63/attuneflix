// World production-handler law (VAL-EFF-002): the production SourceRead and
// Digest capabilities bridge to the real native seams (JDK filesystem and
// AttuneIdentity). The Rust Grit engine and the Arrow/Parquet transport need
// JVM library flags the plain Flix law runner cannot set; this suite exercises
// those seams through `//src/native/grit:attune_grit_test` and
// `//src/native/parquet:attune_parquet_test`.
import java.nio.file.{Files, Paths}

@Test
def productionDigestBridgesToTheNativeIdentity(): Unit \ {Assert, IO} = {
    Assert.assertEq(
        expected = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
        Kernel.Handler.runProduction(() -> Kernel.Effect.Digest.digest("abc")))
}

@Test
def productionSourceReadBridgesToTheFilesystem(): Unit \ {Assert, IO} = {
    let path = Files.createTempFile("attune-handler-", ".txt").toString();
    let _ = Files.writeString(Paths.get(path), "mod Demo");
    Assert.assertEq(expected = Ok("mod Demo"),
        Kernel.Handler.runProduction(() -> Kernel.Effect.SourceRead.readText(path)))
}

@Test
def productionSourceReadReportsMissingFiles(): Unit \ {Assert, IO} = {
    match Kernel.Handler.runProduction(() ->
        Kernel.Effect.SourceRead.readText("/nonexistent/attune/handler/probe.txt")) {
        case Ok(value) => Assert.fail("expected an unavailable-file error, got ${value}")
        case Err(error) => Assert.assertTrue(ToString.toString(error) != "")
    }
}
