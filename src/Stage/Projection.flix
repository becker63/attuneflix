/// Stage 6 — Context projection: `SelectionOutcome -> ProjectedContext`. It
/// resolves the selected ranking to admitted symbols, emits one code span per
/// symbol (path, symbol identity, exact byte range, and the admitted symbol
/// token), and renders the formatted context under the declared token budget.
/// Pure: the admitted world already carries the span coordinates, so no source
/// read is needed.
pub mod Stage.Projection {
    use Kernel.Contract.{AdmittedWorld, CandidateId, ContextSpan, ProjectedContext, SelectionOutcome, SymbolId}

    /// Flix reserves `project`, so the stage verb is `projectContext`.
    pub def projectContext(world: AdmittedWorld, selection: SelectionOutcome, tokenBudget: Int32): ProjectedContext = {
        let spans = takeWithinBudget(
            Vector.filterMap(id -> spanFor(world, id), selection#ranking), tokenBudget);
        {
            selection = selection#selection,
            spans = spans,
            tokenBudget = tokenBudget,
            estimatedTokens = Vector.foldLeft((total, span) -> total + spanTokens(span), 0, spans),
            rendered = render(spans)
        }
    }

    /// Resolve one candidate identity to its admitted symbol span. Candidate
    /// identities are symbol ordinals, so an out-of-range identity is dropped.
    def spanFor(world: AdmittedWorld, id: CandidateId): Option[ContextSpan] = match id {
        case CandidateId.CandidateId(ordinal) =>
            if (ordinal < 0 or ordinal >= Vector.length(world#symbols)) None
            else {
                let symbol = Vector.get(ordinal, world#symbols);
                Some({
                    path = symbol#path,
                    symbol = SymbolId.SymbolId(ordinal),
                    startByte = symbol#startByte,
                    endByte = symbol#endByte,
                    text = symbol#name
                })
            }
    }

    /// Keep the leading spans whose cumulative cost still fits the budget.
    def takeWithinBudget(spans: Vector[ContextSpan], tokenBudget: Int32): Vector[ContextSpan] =
        Vector.foldLeft((chosen, span) ->
            if (totalTokens(chosen) + spanTokens(span) > tokenBudget) chosen
            else Vector.append(chosen, Vector#{span}), Vector.empty(), spans)

    def totalTokens(spans: Vector[ContextSpan]): Int32 =
        Vector.foldLeft((total, span) -> total + spanTokens(span), 0, spans)

    /// Deterministic token estimate: one token per four characters, at least
    /// one token per span.
    def spanTokens(span: ContextSpan): Int32 =
        Int32.max(1, (String.length(span#text) + 3) / 4)

    def render(spans: Vector[ContextSpan]): String =
        Vector.joinWith(span ->
            "${span#path}:${span#startByte}-${span#endByte}\u0000${span#text}", "\n", spans)
}
