// Stage 6 law (VAL-STAGE-005): projection is a pure transformation from the
// selection outcome and admitted world into a budgeted, rendered context.
use Kernel.Contract.{CandidateId, Selection, SelectionOutcome}

def projectionSelection(): SelectionOutcome = {
    issue = "a",
    selection = Selection.Prior,
    ranking = Vector#{CandidateId.CandidateId(0), CandidateId.CandidateId(1)}
}

@Test
def projectionRendersBudgetedSpansInSelectionOrder(): Unit \ Assert = {
    let context = Stage.Projection.projectContext(TestWorlds.abWorld(), projectionSelection(), 10);
    Assert.assertEq(expected = Selection.Prior, context#selection);
    Assert.assertEq(expected = 2, Vector.length(context#spans));
    Assert.assertEq(
        expected = Vector#{"a.js", "b.js"},
        Vector.map(span -> span#path, context#spans));
    Assert.assertEq(expected = 2, context#estimatedTokens);
    Assert.assertEq(
        expected = "a.js:0-1\u0000a\nb.js:0-1\u0000b",
        context#rendered)
}

@Test
def projectionStopsAtTheDeclaredTokenBudget(): Unit \ Assert = {
    let tight = Stage.Projection.projectContext(TestWorlds.abWorld(), projectionSelection(), 1);
    Assert.assertEq(expected = 1, Vector.length(tight#spans));
    Assert.assertEq(expected = "a.js:0-1\u0000a", tight#rendered);
    let empty = Stage.Projection.projectContext(TestWorlds.abWorld(), projectionSelection(), 0);
    Assert.assertEq(expected = 0, Vector.length(empty#spans));
    Assert.assertEq(expected = "", empty#rendered)
}

@Test
def projectionDropsUnknownCandidateIdentities(): Unit \ Assert = {
    let selection: SelectionOutcome = {
        issue = "a",
        selection = Selection.Atlas(CandidateId.CandidateId(7)),
        ranking = Vector#{CandidateId.CandidateId(7)}
    };
    let context = Stage.Projection.projectContext(TestWorlds.abWorld(), selection, 10);
    Assert.assertEq(expected = 0, Vector.length(context#spans));
    Assert.assertEq(expected = 0, context#estimatedTokens)
}
