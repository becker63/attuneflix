/// Canonical admitted issue text used by localization.
/// External benchmark JSON is converted once; replay sees only this table.
pub mod Localization.IssueTable {
    use ScientificTable.Columns.text

    pub def schema(): ScientificTable.Schema = {
        format = "attune-localization-issue-v1",
        columns = Vector#{
            text("protocol"), text("instance_id"), text("repository"),
            text("base_revision"), text("problem_statement")
        }
    }
}
