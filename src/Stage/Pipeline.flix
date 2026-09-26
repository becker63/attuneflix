/// The composed Stage 3-6 pipeline: `AdmittedWorld -> ProjectedContext`.
/// Stage 3A Prior and Stage 3B Atlas both consume the same admitted world and
/// are independent, so they can run concurrently; CandidateSet assembly, Judge
/// selection, and Projection then run in order. The two capabilities are
/// supplied by handlers, so the whole pipeline runs keyless under replay.
pub mod Stage.Pipeline {
    use Kernel.Contract.{AdmittedWorld, ProjectedContext, State}
    use Kernel.Effect.{Embedding, JudgeModel}

    pub def localize(
        world: AdmittedWorld,
        issueText: String,
        seed: State,
        depth: Int32,
        tokenBudget: Int32
    ): Result[String, ProjectedContext] \ {Embedding, JudgeModel} =
        forM (
            prior <- Stage.Prior.scorePrior(world, issueText)
                |> Result.mapErr(error -> ToString.toString(error));
            atlas <- Stage.Atlas.explore(world, seed, depth);
            selection <- Stage.Judge.judge(issueText, Stage.CandidateSet.assemble(prior, atlas))
                |> Result.mapErr(error -> ToString.toString(error))
        ) yield Stage.Projection.projectContext(world, selection, tokenBudget)
}
