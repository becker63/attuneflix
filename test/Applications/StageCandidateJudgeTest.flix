// Stage 4/5 laws (VAL-STAGE-004): candidate assembly is a pure stable merge of
// the prior ranking and Atlas reach, and the judge stage runs under an
// in-memory `eff JudgeModel` handler, so both run keyless.
use Kernel.Contract.{Atom, AtlasCandidateOutcomes, CandidateId, FileId, PriorScores, Selection, State, SymbolId}
use Kernel.Effect.CapabilityError

def candidatePrior(): PriorScores = {
    scores = Vector#{
        {symbol = SymbolId.SymbolId(1), score = 0.9},
        {symbol = SymbolId.SymbolId(0), score = 0.5}
    }
}

def candidateAtlas(): AtlasCandidateOutcomes = {
    outcomes = Vector#{
        {program = {steps = Vector#{Atom.Calls}}, state = State.Symbols(Set#{SymbolId.SymbolId(0), SymbolId.SymbolId(2)}), depth = 1, reach = 0.25},
        {program = {steps = Vector#{Atom.Callers}}, state = State.Symbols(Set#{SymbolId.SymbolId(0)}), depth = 1, reach = 0.5},
        {program = {steps = Vector#{Atom.Defines}}, state = State.Files(Set#{FileId.FileId(0)}), depth = 1, reach = 0.5}
    }
}

@Test
def candidateSetStablyMergesPriorAndAtlas(): Unit \ Assert = {
    let candidates = Stage.CandidateSet.assemble(candidatePrior(), candidateAtlas());
    Assert.assertEq(
        expected = Vector#{CandidateId.CandidateId(1), CandidateId.CandidateId(0), CandidateId.CandidateId(2)},
        Vector.map(candidate -> candidate#id, candidates#candidates));
    Assert.assertEq(
        expected = Vector#{SymbolId.SymbolId(1), SymbolId.SymbolId(0), SymbolId.SymbolId(2)},
        Vector.map(candidate -> candidate#symbol, candidates#candidates));
    Assert.assertEq(
        expected = Vector#{Some(0), Some(1), None},
        Vector.map(candidate -> candidate#priorRank, candidates#candidates));
    Assert.assertEq(
        expected = Vector#{None, Some(0.5), Some(0.25)},
        Vector.map(candidate -> candidate#atlasReach, candidates#candidates))
}

@Test
def judgeMaterializesTheRankingEachSelectionImplies(): Unit \ Assert = {
    let candidates = Stage.CandidateSet.assemble(candidatePrior(), candidateAtlas());
    let priorChoice = run {
        Stage.Judge.judge("issue", candidates)
    } with handler Kernel.Effect.JudgeModel {
        def decide(_issue, _candidates, resume) = resume(Ok(Selection.Prior))
    };
    let atlasChoice = run {
        Stage.Judge.judge("issue", candidates)
    } with handler Kernel.Effect.JudgeModel {
        def decide(_issue, _candidates, resume) =
            resume(Ok(Selection.Atlas(CandidateId.CandidateId(2))))
    };
    match (priorChoice, atlasChoice) {
        case (Ok(prior), Ok(atlas)) => {
            Assert.assertEq(expected = Selection.Prior, prior#selection);
            Assert.assertEq(
                expected = Vector#{CandidateId.CandidateId(1), CandidateId.CandidateId(0), CandidateId.CandidateId(2)},
                prior#ranking);
            Assert.assertEq(
                expected = Vector#{CandidateId.CandidateId(2), CandidateId.CandidateId(1), CandidateId.CandidateId(0)},
                atlas#ranking)
        }
        case _ => Assert.fail("expected both judge decisions to succeed")
    }
}

@Test
def judgeRejectsAnUnknownAtlasCandidate(): Unit \ Assert = {
    let candidates = Stage.CandidateSet.assemble(candidatePrior(), candidateAtlas());
    let outcome = run {
        Stage.Judge.judge("issue", candidates)
    } with handler Kernel.Effect.JudgeModel {
        def decide(_issue, _candidates, resume) =
            resume(Ok(Selection.Atlas(CandidateId.CandidateId(9))))
    };
    match outcome {
        case Ok(_) => Assert.fail("expected the unknown Atlas candidate to be rejected")
        case Err(error) => Assert.assertEq(
            expected = CapabilityError.Rejected("judge selected an unknown Atlas candidate"), error)
    }
}
