// Full Stage 3-6 pipeline law: Prior and Atlas consume the same admitted world,
// then CandidateSet assembly, Judge selection, and Projection run in order. Both
// capabilities are supplied by in-memory handlers, so the pipeline runs keyless
// end to end.
use Kernel.Contract.{CandidateId, Selection, State, SymbolId}

def pipelineContainsA(text: String): Bool =
    String.contains(substr = "a", text)

def pipelineEmbedding(): Vector[Float64] =
    Vector#{1.0, 0.0}

@Test
def pipelineRunsAcquireWorldPriorAtlasCandidateJudgeProjectionEndToEnd(): Unit \ Assert = {
    let world = TestWorlds.abWorld();
    let seed = State.Symbols(Set#{SymbolId.SymbolId(0)});
    let result = run {
        Stage.Pipeline.localize(world, "a", seed, 2, 16)
    } with handler Kernel.Effect.Embedding {
        def embed(text, resume) = resume(Ok(
            if (pipelineContainsA(text)) pipelineEmbedding() else Vector#{0.0, 1.0}))
    } with handler Kernel.Effect.JudgeModel {
        def decide(_issue, _candidates, resume) = resume(Ok(Selection.Prior))
    };
    match result {
        case Err(error) => Assert.fail(error)
        case Ok(context) => {
            Assert.assertEq(expected = Selection.Prior, context#selection);
            Assert.assertEq(
                expected = Vector#{"a.js", "b.js"},
                Vector.map(span -> span#path, context#spans));
            Assert.assertTrue(context#estimatedTokens > 0)
        }
    }
}

@Test
def pipelinePromotesTheJudgeSelectedAtlasCandidate(): Unit \ Assert = {
    let world = TestWorlds.abWorld();
    let seed = State.Symbols(Set#{SymbolId.SymbolId(0)});
    let result = run {
        Stage.Pipeline.localize(world, "a", seed, 2, 16)
    } with handler Kernel.Effect.Embedding {
        def embed(text, resume) = resume(Ok(
            if (pipelineContainsA(text)) pipelineEmbedding() else Vector#{0.0, 1.0}))
    } with handler Kernel.Effect.JudgeModel {
        def decide(_issue, _candidates, resume) =
            resume(Ok(Selection.Atlas(CandidateId.CandidateId(1))))
    };
    match result {
        case Err(error) => Assert.fail(error)
        case Ok(context) => Assert.assertEq(
            expected = Vector#{"b.js", "a.js"},
            Vector.map(span -> span#path, context#spans))
    }
}
