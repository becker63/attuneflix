// Kernel capability-handler laws (VAL-EFF-002/003).
//
// `runReplay` executes every capability purely from in-memory fixtures, so the
// law runs with no disk, network, or external process. `runProduction` bridges
// the digest capability to the native AttuneIdentity seam and source reads to
// the JDK filesystem.
import java.nio.file.{Files, Paths}

use Kernel.Contract.{CandidateSet, FactKind, RawFact, Selection}
use Kernel.Effect.CapabilityError

def replayProgram(): Result[CapabilityError, String] \ {Kernel.Effect.Digest, Kernel.Effect.SourceRead, Kernel.Effect.Grit, Kernel.Effect.ArtifactStore, Kernel.Effect.Embedding, Kernel.Effect.JudgeModel} = {
    let digest = Kernel.Effect.Digest.digest("payload");
    forM (
        source <- Kernel.Effect.SourceRead.readText("src/a.flix");
        facts <- Kernel.Effect.Grit.extract("flix", FactKind.Defines, "src/a.flix", source);
        artifact <- Kernel.Effect.ArtifactStore.read("blob");
        embedding <- Kernel.Effect.Embedding.embed("issue");
        selection <- Kernel.Effect.JudgeModel.decide("issue", {candidates = Vector.empty()})
    ) yield "${digest}|${source}|${Vector.length(facts)}|${artifact}|${Vector.length(embedding)}|${selection}"
}

@Test
def replayHandlersRunKeylessAndDeterministically(): Unit \ Assert = {
    let fact: RawFact = {
        kind = FactKind.Defines, path = "src/a.flix", startByte = 0, endByte = 5, value = "A"
    };
    let result = Kernel.Handler.runReplay(
        (_path: String) -> Ok("mod A"),
        (_path: String) -> Ok("blob"),
        (_payload: String) -> "sha:replay",
        (_language: String, _relation: FactKind, _path: String, _source: String) -> Ok(Vector#{fact}),
        (_text: String) -> Ok(Vector#{1.0, 2.0}),
        (_issue: String, _candidates: CandidateSet) -> Ok(Selection.Prior),
        () -> replayProgram()
    );
    Assert.assertEq(expected = Ok("sha:replay|mod A|1|blob|2|Prior"), result)
}

@Test
def replayHandlersPropagateFixtureFailures(): Unit \ Assert = {
    let result = Kernel.Handler.runReplay(
        (path: String) -> Err(CapabilityError.Unavailable(path)),
        (_path: String) -> Ok("blob"),
        (_payload: String) -> "sha:replay",
        (_language: String, _relation: FactKind, _path: String, _source: String) -> Ok(Vector.empty()),
        (_text: String) -> Ok(Vector.empty()),
        (_issue: String, _candidates: CandidateSet) -> Ok(Selection.Prior),
        () -> Kernel.Effect.SourceRead.readText("missing")
    );
    Assert.assertEq(expected = Err(CapabilityError.Unavailable("missing")), result)
}

@Test
def productionDigestBridgesToTheNativeIdentitySeam(): Unit \ {Assert, IO} = {
    Assert.assertEq(
        expected = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
        Kernel.Handler.runProduction(() -> Kernel.Effect.Digest.digest("abc")))
}

@Test
def productionSourceReadBridgesToTheFilesystem(): Unit \ {Assert, IO} = {
    let path = Files.createTempFile("attune-handler-", ".txt").toString();
    let _ = Files.writeString(Paths.get(path), "hello");
    Assert.assertEq(expected = Ok("hello"),
        Kernel.Handler.runProduction(() -> Kernel.Effect.SourceRead.readText(path)))
}
