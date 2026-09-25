/// Canonical admitted issue text used by localization.
/// External benchmark JSON is converted once; replay sees only this table.
pub mod Localization.IssueTable {
    use ScientificTable.Value
    use ScientificTable.Columns.text

    pub def schema(): ScientificTable.Schema = {
        format = "attune-localization-issue-v1",
        columns = Vector#{
            text("protocol"), text("instance_id"), text("repository"),
            text("base_revision"), text("problem_statement")
        }
    }

    pub def protocol(): String = "attune-localization-issue-v1"

    pub def row(instanceId: String, repository: String, baseRevision: String,
                problemStatement: String): ScientificTable.Row = Map#{
        "protocol" => Value.Text(protocol()),
        "instance_id" => Value.Text(instanceId),
        "repository" => Value.Text(repository),
        "base_revision" => Value.Text(baseRevision),
        "problem_statement" => Value.Text(problemStatement)
    }

    pub def write(path: String, row0: ScientificTable.Row): ScientificTable.Row \ IO = {
        let rows = ScientificTable.write(path, schema(), Vector#{row0});
        if (Vector.length(rows) == 1) Vector.get(0, rows)
        else bug!("issue table must contain exactly one row")
    }

    pub def read(path: String, expectedInstance: String): Result[String, Localization.Issue] \ IO = {
        let rows = ScientificTable.read(path, schema());
        if (Vector.length(rows) != 1) Err("issue table must contain exactly one row")
        else decode(Vector.get(0, rows), expectedInstance)
    }

    def decode(row0: ScientificTable.Row, expectedInstance: String): Result[String, Localization.Issue] = forM (
        protocol0 <- ScientificTable.text(row0, "protocol");
        _ <- equal("issue protocol", protocol(), protocol0);
        instanceId <- ScientificTable.text(row0, "instance_id");
        _ <- equal("issue instance", expectedInstance, instanceId);
        repository <- ScientificTable.text(row0, "repository");
        baseRevision <- ScientificTable.text(row0, "base_revision");
        problemStatement <- ScientificTable.text(row0, "problem_statement");
        _ <- if (String.isEmpty(problemStatement)) Err("issue text is empty") else Ok(())
    ) yield {
        instanceId = instanceId,
        repository = repository,
        baseCommit = baseRevision,
        text = Localization.IssueText.IssueText(problemStatement)
    }

    def equal(name: String, expected: String, actual: String): Result[String, Unit] =
        if (expected == actual) Ok(()) else Err("${name} mismatch")
}
