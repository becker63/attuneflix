mod Decide {
    pub type alias Alternative = {
        expression = Semantics.ExprId,
        state = Semantics.StateId
    }

    pub enum Error with Eq, Order, ToString {
        case NoAlternatives,
        case MissingReplay(Semantics.DecisionId),
        case InvalidChoice(Int32)
    }

    pub eff Choice {
        def policy(
            decision: Semantics.DecisionId,
            state: Semantics.StateId,
            alternatives: Vector[Alternative]
        ): Result[Error, Int32]
    }

    pub def policy(
        decision: Semantics.DecisionId,
        state: Semantics.StateId,
        alternatives: Vector[Alternative]
    ): Result[Error, Int32] \ Choice =
        if (Vector.isEmpty(alternatives)) Err(Error.NoAlternatives)
        else Choice.policy(decision, state, alternatives)

    /// Deterministic tests choose a fixed alternative without dependency injection.
    pub def runWithFake(index: Int32, f: Unit -> a \ ef): a \ (ef - Choice) =
        run { f() } with handler Choice {
            def policy(_decision, _state, alternatives, k) =
                k(validate(index, Vector.length(alternatives)))
        }

    /// Replay is exact: the identified decision must be present and in bounds.
    pub def runWithReplay(
        observations: Map[Semantics.DecisionId, Int32],
        f: Unit -> a \ ef
    ): a \ (ef - Choice) =
        run { f() } with handler Choice {
            def policy(decision, _state, alternatives, k) = match Map.get(decision, observations) {
                case None => k(Err(Error.MissingReplay(decision)))
                case Some(index) => k(validate(index, Vector.length(alternatives)))
            }
        }

    def validate(index: Int32, count: Int32): Result[Error, Int32] =
        if (index >= 0 and index < count) Ok(index)
        else Err(Error.InvalidChoice(index))
}
