// Stage 3 laws (VAL-STAGE-003): `Stage.Prior` runs under an in-memory
// `eff Embedding` handler and `Stage.Atlas` runs through the memoized physical
// evaluator, both keyless. Prior and Atlas share only the admitted world.
use Kernel.Contract.{Atom, FileId, State, SymbolId}
use Kernel.Effect.CapabilityError

def containsA(text: String): Bool =
    String.contains(substr = "a", text)

@Test
def priorScoresSymbolsByCosineSimilarityAndPropagatesFailure(): Unit \ Assert = {
    let ranked = run {
        Stage.Prior.scorePrior(TestWorlds.abWorld(), "a")
    } with handler Kernel.Effect.Embedding {
        def embed(text, resume) =
            resume(Ok(if (containsA(text)) Vector#{1.0, 0.0} else Vector#{0.0, 1.0}))
    };
    match ranked {
        case Err(error) => Assert.fail(ToString.toString(error))
        case Ok(scores) => Assert.assertEq(
            expected = Vector#{(SymbolId.SymbolId(0), 1.0), (SymbolId.SymbolId(1), 0.0)},
            Vector.map(score -> (score#symbol, score#score), scores#scores))
    };
    let failed = run {
        Stage.Prior.scorePrior(TestWorlds.abWorld(), "a")
    } with handler Kernel.Effect.Embedding {
        def embed(_text, resume) = resume(Err(CapabilityError.Unavailable("no embedding provider")))
    };
    match failed {
        case Ok(_) => Assert.fail("expected the embedding failure to propagate")
        case Err(error) =>
            Assert.assertEq(expected = CapabilityError.Unavailable("no embedding provider"), error)
    }
}

@Test
def atlasExploresExactStatesAndRejectsNonPositiveDepth(): Unit \ Assert = {
    let f0 = FileId.FileId(0);
    let s0 = SymbolId.SymbolId(0);
    match Stage.Atlas.explore(TestWorlds.abWorld(), State.Symbols(Set#{s0}), 2) {
        case Err(error) => Assert.fail(error)
        case Ok(outcomes) => {
            Assert.assertEq(expected = 12, Vector.length(outcomes#outcomes));
            let first = Vector.get(0, outcomes#outcomes);
            Assert.assertEq(expected = Vector#{Atom.DefinedIn}, first#program#steps);
            Assert.assertEq(expected = State.Files(Set#{f0}), first#state);
            Assert.assertEq(expected = (1, 0.5), (first#depth, first#reach));
            Assert.assertEq(
                expected = State.Symbols(Set#{SymbolId.SymbolId(1)}),
                Vector.get(1, outcomes#outcomes)#state);
            Assert.assertEq(expected = State.Symbols(Set.empty()), Vector.get(2, outcomes#outcomes)#state)
        }
    };
    match Stage.Atlas.explore(TestWorlds.abWorld(), State.Symbols(Set#{s0}), 0) {
        case Ok(_) => Assert.fail("expected a non-positive depth to be rejected")
        case Err(error) =>
            Assert.assertEq(expected = "Atlas exploration depth must be at least one", error)
    }
}
