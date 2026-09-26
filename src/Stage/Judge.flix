/// Stage 5 — Judge selection: `CandidateSet -> SelectionOutcome`. The learned
/// judge capability supplies only the localization basis (`Prior`, or one Atlas
/// candidate by identity); the deterministic ranking that basis implies is
/// materialized here, keeping the model's choice separate from the ordering.
pub mod Stage.Judge {
    use Kernel.Contract.{Candidate, CandidateId, CandidateSet, Selection, SelectionOutcome}
    use Kernel.Effect.{CapabilityError, JudgeModel}

    pub def judge(issue: String, candidates: CandidateSet): Result[CapabilityError, SelectionOutcome] \ JudgeModel =
        JudgeModel.decide(issue, candidates)
            |> Result.flatMap(selection ->
                rankingFor(selection, candidates)
                    |> Result.map(ranking -> {
                        issue = issue,
                        selection = selection,
                        ranking = ranking
                    }))

    /// `Prior` keeps the whole prior ranking; an Atlas choice promotes exactly
    /// the selected candidate to the front. Naming an unknown candidate is a
    /// rejected decision, not a silent fallback.
    def rankingFor(selection: Selection, candidates: CandidateSet): Result[CapabilityError, Vector[CandidateId]] =
        match selection {
            case Selection.Prior => Ok(Vector.map(candidate -> candidate#id, priorOrder(candidates)))
            case Selection.Atlas(id) => match Vector.find(candidate -> candidate#id == id, candidates#candidates) {
                case None => Err(CapabilityError.Rejected("judge selected an unknown Atlas candidate"))
                case Some(_) => {
                    let rest = Vector.filter(candidate -> candidate#id != id, priorOrder(candidates));
                    Ok(Vector.append(Vector#{id}, Vector.map(candidate -> candidate#id, rest)))
                }
            }
        }

    /// Prior-ranked candidates in ascending rank, then unranked ones in their
    /// existing (ascending ordinal) order.
    def priorOrder(candidates: CandidateSet): Vector[Candidate] = {
        let ranked = Vector.filter(isRanked, candidates#candidates);
        let unranked = Vector.filter(candidate -> not isRanked(candidate), candidates#candidates);
        Vector.append(Vector.sortBy(rankOf, ranked), unranked)
    }

    def isRanked(candidate: Candidate): Bool = match candidate#priorRank {
        case Some(_) => true
        case None    => false
    }

    def rankOf(candidate: Candidate): Int32 = match candidate#priorRank {
        case Some(rank) => rank
        case None       => 0
    }
}
