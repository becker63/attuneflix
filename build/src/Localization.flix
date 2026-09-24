/// Replay-only Localization surface. The frozen policy consumes no source
/// checkout and no embedding transport: its declared inputs are the gold-free
/// issue row, typed admitted world, and retained prior ranking.
mod Localization {
    pub enum IssueText(String) with Eq

    pub type alias Ranked = {
        identity = String,
        score    = Float64,
        ordinal  = Int32
    }

    pub type alias Issue = {
        instanceId = String,
        repository = String,
        baseCommit = String,
        text = IssueText
    }

    pub type alias Prepared = {
        instanceId = String,
        repository = String,
        baseCommit = String,
        snapshotId = String,
        issue      = Issue,
        world      = Repository.World
    }

    pub def prepareWorld(
        instanceId: String,
        repository: String,
        baseCommit: String,
        snapshotId: String,
        issue: Issue,
        world: Repository.World
    ): Result[String, Prepared] = forM (
        _ <- if (issue#instanceId == instanceId) Ok(()) else Err("issue identity mismatch");
        _ <- if (issue#repository == repository) Ok(()) else Err("issue repository mismatch");
        _ <- if (issue#baseCommit == baseCommit) Ok(()) else Err("issue revision mismatch")
    ) yield {
        instanceId = instanceId,
        repository = repository,
        baseCommit = baseCommit,
        snapshotId = snapshotId,
        issue = issue,
        world = world
    }

}
