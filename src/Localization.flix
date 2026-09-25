/// Typed, gold-free values at the localization boundary.
mod Localization {
    pub enum IssueText(String) with Eq

    pub type alias Ranked = {
        identity = String,
        score    = Float64,
        ordinal  = Int32
    }

    pub type alias Prior = {
        instanceId = String,
        repository = String,
        baseCommit = String,
        ranking    = Vector[Ranked]
    }

    pub type alias Issue = {
        instanceId = String,
        repository = String,
        baseCommit = String,
        text       = IssueText
    }

    pub type alias Prepared = {
        instanceId = String,
        repository = String,
        baseCommit = String,
        issue      = Issue,
        world      = Repository.World
    }
}
