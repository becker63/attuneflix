/// Canonical wire form for the semantic identity emitted beside a typed world.
/// Bazel orders the producer and consumer; Flix owns the meaning and validates
/// every field before Atlas sees the world.
pub mod Repository.Identity {
    use Util.Json
    use Util.Json.Json.{JObject, JString}
    use Util.Json.FromJson

    pub def decode(payload: String): Result[String, Repository.Table.Identity] =
        match Json.parse(payload) {
            case Err(error) => Err(ToString.toString(error))
            case Ok(JObject(fields)) => forM (
                version <- int("version", fields);
                _ <- if (version == 1) Ok(()) else Err("unsupported repository world identity");
                repository <- string("repository", fields);
                baseRevision <- string("base_revision", fields);
                sourceTreeIdentity <- string("source_tree_identity", fields);
                factIdentity <- string("fact_identity", fields);
                snapshotId <- string("snapshot_id", fields)
            ) yield {
                repository = repository,
                baseRevision = baseRevision,
                sourceTreeIdentity = sourceTreeIdentity,
                factIdentity = factIdentity,
                snapshotId = snapshotId
            }
            case Ok(_) => Err("repository world identity must be an object")
        }

    def string(name: String, row: Map[String, Json]): Result[String, String] =
        match Map.get(name, row) {
            case Some(JString(value)) => Ok(value)
            case Some(_) => Err("repository world identity ${name} is not text")
            case None => Err("repository world identity is missing ${name}")
        }

    def int(name: String, row: Map[String, Json]): Result[String, Int32] =
        match Map.get(name, row) {
            case Some(value) => FromJson.fromJson(value) |> Result.mapErr(ToString.toString)
            case None => Err("repository world identity is missing ${name}")
        }
}
