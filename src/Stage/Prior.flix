/// Stage 3A — Prior scoring: `AdmittedWorld -> PriorScores`. The issue text and
/// each admitted symbol's canonical text are embedded through `eff Embedding`,
/// and every symbol is scored by the cosine similarity between its vector and
/// the issue vector. The stage reads only the admitted world and the issue, so
/// it shares no state with Stage 3B; the two are independent and may run
/// concurrently.
pub mod Stage.Prior {
    use Kernel.Contract.{AdmittedWorld, PriorScore, PriorScores, Symbol, SymbolId}
    use Kernel.Effect.{CapabilityError, Embedding}

    /// Score every admitted symbol against the issue, then sort into the
    /// ranking: descending score, ties broken by ascending symbol ordinal, so
    /// the result is deterministic for any embedding handler.
    pub def scorePrior(world: AdmittedWorld, issueText: String): Result[CapabilityError, PriorScores] \ Embedding =
        Embedding.embed(issueText) |> Result.flatMap(issue ->
            Vector.mapWithIndex((ordinal, symbol) -> scoreOf(issue, ordinal, symbol), world#symbols)
                |> Vector.sequence
                |> Result.map(rankScores))

    def scoreOf(issue: Vector[Float64], ordinal: Int32, symbol: Symbol): Result[CapabilityError, PriorScore] \ Embedding =
        Embedding.embed(symbolText(symbol))
            |> Result.map(vector -> {
                let score = cosine(issue, vector);
                { symbol = SymbolId.SymbolId(ordinal), score = score }
            })

    def rankScores(scores: Vector[PriorScore]): PriorScores = {
        { scores = Vector.sortBy(score -> (-(score#score), score#symbol), scores) }
    }

    /// Canonical symbol text: path then name, NUL-separated so distinct
    /// path/name pairs cannot collide.
    def symbolText(symbol: Symbol): String =
        "${symbol#path}\u0000${symbol#name}"

    /// Cosine similarity between the issue vector and a symbol vector; an empty
    /// or zero-magnitude vector scores 0.0 rather than dividing by zero.
    def cosine(left: Vector[Float64], right: Vector[Float64]): Float64 = {
        let dot = Vector.zip(left, right)
            |> Vector.foldLeft((total, pair) -> total + (fst(pair) * snd(pair)), 0.0);
        let scale = magnitude(left) * magnitude(right);
        if (scale == 0.0) 0.0 else dot / scale
    }

    def magnitude(values: Vector[Float64]): Float64 = {
        let squares = Vector.foldLeft((total, value) -> total + (value * value), 0.0, values);
        Float64.pow(base = squares, 0.5)
    }
}
