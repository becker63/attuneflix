/// Stage 4 — Candidate-set assembly: merge the issue-conditioned prior ranking
/// with the reachable Atlas states into one stably identified candidate set.
/// Pure and deterministic. Symbols keep their admitted ordinal as their
/// candidate identity, prior symbols come first in rank order, and Atlas-only
/// symbols follow in ascending ordinal order; a symbol's best Atlas reach is
/// the maximum reach among the outcomes that contain it.
pub mod Stage.CandidateSet {
    // `CandidateSet` is not imported unqualified: its name is the module's own
    // last component, so the output type is named by its full path instead.
    use Kernel.Contract.{AtlasCandidateOutcomes, Candidate, CandidateId, PriorScores, State, SymbolId}

    pub def assemble(prior: PriorScores, atlas: AtlasCandidateOutcomes): Kernel.Contract.CandidateSet = {
        let reaches = reachBySymbol(atlas);
        let ranks = priorRanks(prior);
        {
            candidates = Vector.mapWithIndex((_, symbol) -> {
                id = CandidateId.CandidateId(ordinal(symbol)),
                symbol = symbol,
                priorRank = Map.get(symbol, ranks),
                atlasReach = Map.get(symbol, reaches)
            }, orderedSymbols(prior, reaches))
        }
    }

    /// Best reach per symbol over every Atlas outcome whose state is a symbol
    /// frontier. File frontiers name no symbol and contribute nothing.
    def reachBySymbol(atlas: AtlasCandidateOutcomes): Map[SymbolId, Float64] =
        Vector.foldLeft((reaches, outcome) -> match outcome#state {
            case State.Symbols(symbols) =>
                Vector.foldLeft((inner, symbol) -> match Map.get(symbol, inner) {
                    case Some(existing) if existing >= outcome#reach => inner
                    case _ => Map.insert(symbol, outcome#reach, inner)
                }, reaches, Set.toVector(symbols))
            case State.Files(_) => reaches
        }, Map.empty(), atlas#outcomes)

    /// The first (best) prior rank of each symbol; later duplicates are ignored.
    def priorRanks(prior: PriorScores): Map[SymbolId, Int32] =
        Vector.mapWithIndex((index, score) -> (score#symbol, index), prior#scores)
            |> Vector.foldLeft((ranks, pair) -> match Map.get(fst(pair), ranks) {
                case Some(_) => ranks
                case None => Map.insert(fst(pair), snd(pair), ranks)
            }, Map.empty())

    /// Stable promotion: prior symbols in rank order, then Atlas-only symbols
    /// in ascending ordinal order.
    def orderedSymbols(prior: PriorScores, reaches: Map[SymbolId, Float64]): Vector[SymbolId] = {
        let priorSymbols = Vector.map(score -> score#symbol, prior#scores);
        let priorSet = Vector.toSet(priorSymbols);
        let atlasOnly = Set.toVector(Map.keysOf(reaches))
            |> Vector.filter(symbol -> not Set.memberOf(symbol, priorSet))
            |> Vector.sort;
        Vector.append(priorSymbols, atlasOnly)
    }

    def ordinal(symbol: SymbolId): Int32 = match symbol {
        case SymbolId.SymbolId(value) => value
    }
}
