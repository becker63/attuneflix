def main(): Unit \ {Fs.FileSystem, IO} = {
    match WorldMigration.migrate() {
        case Err(message) => bug!(message)
        case Ok(identity) => println(
            "WORLD_MIGRATION repository=${identity#repository}" +
            " revision=${identity#baseRevision}" +
            " source_tree=${identity#sourceTreeIdentity}" +
            " fact_identity=${identity#factIdentity}" +
            " snapshot_id=${identity#snapshotId}" +
            " exact=true")
    }
}

/// One-time semantic migration from the frozen generic retained-observation
/// envelope to Repository.World's typed Parquet tables. The action has no Nix
/// capability: its Nix-produced oracle is an ordinary declared JSON input.
/// Grit is not executed and provider acquisition is impossible.
mod WorldMigration {
    import java.lang.System

    use Fs.FileSystem
    use Util.Json
    use Util.Json.Json.{JArray, JObject, JString}
    use Util.Json.FromJson
    use Util.Json.ToJson

    type alias Oracle = {
        repository         = String,
        baseRevision       = String,
        population         = String,
        sourceTreeIdentity = String,
        legacySnapshot     = String,
        sourcePaths        = Vector[String]
    }

    pub def migrate(): Result[String, Repository.Table.Identity] \ {FileSystem, IO} = forM (
        oraclePayload <- FileSystem.read(property("attune.oracle"))
            |> Result.mapErr(ToString.toString);
        oracle <- decodeOracle(oraclePayload);
        retained = property("attune.retained_observations");
        sources = Vector.map(path -> {path = path, content = ""}, oracle#sourcePaths);
        gritIdentity = if (oracle#population == "historical-development")
            legacyGritIdentity()
            else Repository.Grit.observationIdentity();
        observations <- Repository.decodeObservationsAtIdentity(
            oracle#repository,
            oracle#baseRevision,
            oracle#legacySnapshot,
            sources,
            gritIdentity,
            ScientificData.readObject(retained)
        ) |> Result.mapErr(ToString.toString);
        world <- Repository.admitObserved(observations) |> Result.mapErr(ToString.toString);
        factIdentity = Repository.Table.factIdentity(
            oracle#sourceTreeIdentity, gritIdentity, world);
        snapshotId = Repository.Table.snapshotIdentity(
            oracle#repository, oracle#baseRevision,
            oracle#sourceTreeIdentity, factIdentity);
        identity = {
            repository = oracle#repository,
            baseRevision = oracle#baseRevision,
            sourceTreeIdentity = oracle#sourceTreeIdentity,
            factIdentity = factIdentity,
            snapshotId = snapshotId
        };
        _ = Repository.Table.write(
            property("attune.world_metadata"),
            property("attune.world_entities"),
            property("attune.world_relations"),
            identity,
            world
        );
        replayed <- Repository.Table.read(
            property("attune.world_metadata"),
            property("attune.world_entities"),
            property("attune.world_relations"),
            identity
        );
        _ <- if (sameWorld(world, replayed)) Ok(())
            else Err("typed Repository.World round-trip changed the admitted facts");
        _ <- FileSystem.write(
            str = identityJson(identity),
            property("attune.world_identity")
        ) |> Result.mapErr(ToString.toString)
    ) yield identity

    def decodeOracle(payload: String): Result[String, Oracle] = match Json.parse(payload) {
        case Err(error) => Err(ToString.toString(error))
        case Ok(JObject(fields)) => forM (
            version <- intField("version", fields);
            _ <- if (version == 1) Ok(()) else Err("unsupported world migration oracle");
            repository <- stringField("repository", fields);
            baseRevision <- stringField("base_revision", fields);
            population <- stringField("population", fields);
            sourceTreeIdentity <- stringField("source_tree_identity", fields);
            legacySnapshot <- stringField("legacy_snapshot", fields);
            sourcePaths <- stringVectorField("source_paths", fields)
        ) yield {
            repository = repository,
            baseRevision = baseRevision,
            population = population,
            sourceTreeIdentity = sourceTreeIdentity,
            legacySnapshot = legacySnapshot,
            sourcePaths = sourcePaths
        }
        case Ok(_) => Err("world migration oracle must be an object")
    }

    def identityJson(identity: Repository.Table.Identity): String =
        Json.toCompactString(JObject(Map#{
            "version" => ToJson.toJson(1),
            "repository" => JString(identity#repository),
            "base_revision" => JString(identity#baseRevision),
            "source_tree_identity" => JString(identity#sourceTreeIdentity),
            "fact_identity" => JString(identity#factIdentity),
            "snapshot_id" => JString(identity#snapshotId)
        }))

    def stringField(name: String, fields: Map[String, Json]): Result[String, String] =
        match Map.get(name, fields) {
            case Some(JString(value)) => Ok(value)
            case Some(_) => Err("${name}: expected string")
            case None => Err("missing oracle field: ${name}")
        }

    def intField(name: String, fields: Map[String, Json]): Result[String, Int32] =
        match Map.get(name, fields) {
            case Some(value) => FromJson.fromJson(value) |> Result.mapErr(ToString.toString)
            case None => Err("missing oracle field: ${name}")
        }

    def stringVectorField(name: String, fields: Map[String, Json]): Result[String, Vector[String]] =
        match Map.get(name, fields) {
            case Some(JArray(values)) => Vector.traverse(match value -> match value {
                case JString(text) => Ok(text)
                case _ => Err("${name}: expected string elements")
            }, values)
            case Some(_) => Err("${name}: expected array")
            case None => Err("missing oracle field: ${name}")
        }

    def sameWorld(left: Repository.World, right: Repository.World): Bool =
        left#files == right#files and
        Vector.map(symbol -> (symbol#path, symbol#name, symbol#startByte, symbol#endByte), left#symbols) ==
            Vector.map(symbol -> (symbol#path, symbol#name, symbol#startByte, symbol#endByte), right#symbols) and
        left#defines == right#defines and
        left#imports == right#imports and
        left#calls == right#calls and
        left#parents == right#parents and
        left#unresolvedImports == right#unresolvedImports and
        left#unresolvedCalls == right#unresolvedCalls

    def legacyGritIdentity(): String =
        "marzano-c80b3026471b229f41b279c3eb0c162dcdacfdb1" +
        ":defines-bba7b2aa5d958d3ea2369fae0b7025718d68fcd1ea10bdfc1351c676899552cb" +
        ":imports-368c1c09ed1ba38437ddab45d1084710cb717adc8dc0c831e3b2e8c49f3ad14d" +
        ":calls-de0e5436777fc93f96a517298386e5e728cd77fe5e46a027a5ae942287212147"

    def property(name: String): String \ IO = System.getProperty(name)
}
