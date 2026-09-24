/// Replay-only Localization surface. The frozen policy consumes no source
/// checkout and no embedding transport: its declared inputs are the gold-free
/// issue row, typed admitted world, and retained prior ranking.
mod Localization {
    use Util.Json
    use Util.Json.Json.{JArray, JObject, JString}
    use Util.Json.ToJson

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
        payload: String,
        world: Repository.World
    ): Result[String, Prepared] = forM (
        issue <- decodeIssue(instanceId, repository, baseCommit, payload)
    ) yield {
        instanceId = instanceId,
        repository = repository,
        baseCommit = baseCommit,
        snapshotId = snapshotId,
        issue = issue,
        world = world
    }

    def decodeIssue(
        instanceId: String,
        repository: String,
        baseCommit: String,
        payload: String
    ): Result[String, Issue] = match Json.parse(payload) {
        case Err(error) => Err(ToString.toString(error))
        case Ok(JObject(fields)) => forM (
            _ <- if (Map.get("version", fields) == Some(ToJson.toJson(1))) Ok(())
                else Err("unsupported issue fixture version");
            values <- array("issues", fields);
            matches = Vector.filter(value -> issueIdentity(value) == Some(instanceId), values);
            _ <- if (Vector.length(matches) == 1) Ok(())
                else Err("issue fixture requires exactly one ${instanceId} row");
            issue <- decodeIssueRow(instanceId, repository, baseCommit, Vector.get(0, matches))
        ) yield issue
        case Ok(_) => Err("issue fixture must be an object")
    }

    def decodeIssueRow(
        expectedId: String,
        expectedRepository: String,
        expectedCommit: String,
        value: Json
    ): Result[String, Issue] = match value {
        case JObject(fields) => forM (
            instanceId <- string("instanceId", fields);
            _ <- if (instanceId == expectedId) Ok(()) else Err("issue identity mismatch");
            repository <- string("repository", fields);
            _ <- if (repository == expectedRepository) Ok(()) else Err("issue repository mismatch");
            baseCommit <- string("baseCommit", fields);
            _ <- if (baseCommit == expectedCommit) Ok(()) else Err("issue revision mismatch");
            text <- string("problemStatement", fields);
            _ <- if (String.isEmpty(text)) Err("issue text is empty") else Ok(())
        ) yield {
            instanceId = instanceId,
            repository = repository,
            baseCommit = baseCommit,
            text = IssueText.IssueText(text)
        }
        case _ => Err("issue row must be an object")
    }

    def issueIdentity(value: Json): Option[String] = match value {
        case JObject(fields) => match Map.get("instanceId", fields) {
            case Some(JString(value0)) => Some(value0)
            case _ => None
        }
        case _ => None
    }

    def string(name: String, fields: Map[String, Json]): Result[String, String] =
        match Map.get(name, fields) {
            case Some(JString(value)) => Ok(value)
            case Some(_) => Err("${name} must be text")
            case None => Err("missing ${name}")
        }

    def array(name: String, fields: Map[String, Json]): Result[String, Vector[Json]] =
        match Map.get(name, fields) {
            case Some(JArray(values)) => Ok(values)
            case Some(_) => Err("${name} must be an array")
            case None => Err("missing ${name}")
        }
}
