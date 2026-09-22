pub mod Repository.Nix {
    import attune.nix.AttuneNix
    import java.lang.System

    use Util.Json
    use Util.Json.Json.{JArray, JObject, JString}
    use Util.Json.FromJson

    pub enum StorePath(String) with Eq, Order, ToString, Hash
    pub enum Wire(String) with Eq, Order, ToString, Hash

    pub type alias Source = {
        path    = String,
        content = String
    }

    pub type alias ExploreCase = {
        instanceId        = String,
        repository        = String,
        baseCommit        = String,
        language          = String,
        benchmarkRevision = String,
        benchmark         = StorePath,
        snapshot          = StorePath,
        sources           = Vector[Source]
    }

    pub type alias LocalizationCase = {
        instanceId   = String,
        repository   = String,
        baseCommit   = String,
        issueRevision = String,
        issueFixture = StorePath,
        snapshot     = StorePath,
        sources      = Vector[Source]
    }

    /// Evaluator evidence is deliberately acquired through a separate value
    /// from `LocalizationCase`, so solver construction cannot receive gold.
    pub type alias EvaluationEvidence = {
        benchmarkRevision = String,
        evaluatorRevision = String,
        goldFixture = StorePath
    }

    /// Gold-free metadata projection used to materialize the scale manifest.
    pub type alias PopulationEvidence = {
        benchmarkRevision    = String,
        multilingualRevision = String,
        proRevision          = String,
        benchmark            = StorePath,
        multilingual         = StorePath,
        pro                  = StorePath,
        projection           = StorePath
    }

    pub enum Error with Eq, ToString {
        case Wire(String),
        case Native(String, String),
        case UnsupportedVersion(Int32),
        case IncompleteContext
    }

    /// Immutable scientific acquisition is narrower than arbitrary IO.
    pub eff Acquire {
        def sweExplore(): Wire
        def replication(caseIndex: Int32): Wire
        def localization(caseIndex: Int32): Wire
        def evaluation(): Wire
        def population(): Wire
        def readSource(file: String): Result[Error, String]
    }

    pub def sweExplore(): Result[Error, ExploreCase] \ Acquire =
        decode(Acquire.sweExplore())

    pub def replication(caseIndex: Int32): Result[Error, ExploreCase] \ Acquire =
        decode(Acquire.replication(caseIndex))

    pub def localization(caseIndex: Int32): Result[Error, LocalizationCase] \ Acquire =
        decodeLocalization(Acquire.localization(caseIndex))

    pub def evaluation(): Result[Error, EvaluationEvidence] \ Acquire =
        decodeEvaluation(Acquire.evaluation())

    pub def population(): Result[Error, PopulationEvidence] \ Acquire =
        decodePopulation(Acquire.population())

    pub def runWithNative(f: Unit -> a \ ef): a \ (ef - Acquire) + IO =
        run { f() } with handler Acquire {
            def sweExplore(k) = k(realiseNative())
            def replication(caseIndex, k) = k(realiseReplication(caseIndex))
            def localization(caseIndex, k) = k(realiseLocalization(caseIndex))
            def evaluation(k) = k(realiseEvaluation())
            def population(k) = k(realisePopulation())
            def readSource(file, k) = k(readNativeSource(file))
        }

    pub def runWithFixture(fixture: Wire, f: Unit -> a \ ef): a \ (ef - Acquire) =
        run { f() } with handler Acquire {
            def sweExplore(k) = k(fixture)
            def replication(_, k) = k(fixture)
            def localization(_, k) = k(fixture)
            def evaluation(k) = k(fixture)
            def population(k) = k(fixture)
            def readSource(file, k) = k(Err(Error.Native("fixture", "unexpected store source: ${file}")))
        }

    pub def path(value: StorePath): String = let StorePath.StorePath(result) = value; result

    pub def decode(wire: Wire): Result[Error, ExploreCase] \ Acquire = {
        let Wire.Wire(payload) = wire;
        match Json.parse(payload) {
            case Err(error) => Err(Error.Wire(ToString.toString(error)))
            case Ok(JObject(fields)) => match intField("version", fields) {
                case Err(error) => Err(error)
                case Ok(version) if version != 1 => Err(Error.UnsupportedVersion(version))
                case Ok(_) => match Map.get("error", fields) {
                    case Some(value) => nativeError(value)
                    case None => forM (
                        text <- stringField("text", fields);
                        paths <- stringVectorField("store_paths", fields);
                        result <- decodeCase(text, paths)
                    ) yield result
                }
            }
            case Ok(_) => Err(Error.Wire("expected a JSON object"))
        }
    }

    pub def decodeLocalization(wire: Wire): Result[Error, LocalizationCase] \ Acquire = {
        let Wire.Wire(payload) = wire;
        match Json.parse(payload) {
            case Err(error) => Err(Error.Wire(ToString.toString(error)))
            case Ok(JObject(fields)) => match intField("version", fields) {
                case Err(error) => Err(error)
                case Ok(version) if version != 1 => Err(Error.UnsupportedVersion(version))
                case Ok(_) => match Map.get("error", fields) {
                    case Some(value) => nativeLocalizationError(value)
                    case None => forM (
                        text <- stringField("text", fields);
                        paths <- stringVectorField("store_paths", fields);
                        result <- decodeLocalizationCase(text, paths)
                    ) yield result
                }
            }
            case Ok(_) => Err(Error.Wire("expected a JSON object"))
        }
    }

    pub def decodeEvaluation(wire: Wire): Result[Error, EvaluationEvidence] = {
        let Wire.Wire(payload) = wire;
        match Json.parse(payload) {
            case Err(error) => Err(Error.Wire(ToString.toString(error)))
            case Ok(JObject(fields)) => match intField("version", fields) {
                case Err(error) => Err(error)
                case Ok(version) if version != 1 => Err(Error.UnsupportedVersion(version))
                case Ok(_) => match Map.get("error", fields) {
                    case Some(value) => nativeEvaluationError(value)
                    case None => forM (
                        text <- stringField("text", fields);
                        paths <- stringVectorField("store_paths", fields);
                        result <- decodeEvaluationEvidence(text, paths)
                    ) yield result
                }
            }
            case Ok(_) => Err(Error.Wire("expected a JSON object"))
        }
    }

    pub def decodePopulation(wire: Wire): Result[Error, PopulationEvidence] = {
        let Wire.Wire(payload) = wire;
        match Json.parse(payload) {
            case Err(error) => Err(Error.Wire(ToString.toString(error)))
            case Ok(JObject(fields)) => match intField("version", fields) {
                case Err(error) => Err(error)
                case Ok(version) if version != 1 => Err(Error.UnsupportedVersion(version))
                case Ok(_) => match Map.get("error", fields) {
                    case Some(value) => nativePopulationError(value)
                    case None => forM (
                        text <- stringField("text", fields);
                        paths <- stringVectorField("store_paths", fields);
                        result <- decodePopulationEvidence(text, paths)
                    ) yield result
                }
            }
            case Ok(_) => Err(Error.Wire("expected a JSON object"))
        }
    }

    def decodeCase(text: String, paths: Vector[String]): Result[Error, ExploreCase] \ Acquire = match Json.parse(text) {
        case Err(error) => Err(Error.Wire("realised text: ${ToString.toString(error)}"))
        case Ok(JObject(fields)) => forM (
            instanceId <- stringField("instanceId", fields);
            repository <- stringField("repository", fields);
            baseCommit <- stringField("baseCommit", fields);
            language <- stringField("language", fields);
            benchmarkRevision <- stringField("benchmarkRevision", fields);
            benchmark <- stringField("benchmark", fields);
            snapshot <- stringField("snapshot", fields);
            sources <- sourceVectorField("sources", fields);
            _ <- completeContext(benchmark, snapshot, paths)
        ) yield {
            instanceId = instanceId,
            repository = repository,
            baseCommit = baseCommit,
            language = language,
            benchmarkRevision = benchmarkRevision,
            benchmark = StorePath.StorePath(benchmark),
            snapshot = StorePath.StorePath(snapshot),
            sources = sources
        }
        case Ok(_) => Err(Error.Wire("realised text must be a JSON object"))
    }

    def decodeLocalizationCase(text: String, paths: Vector[String]): Result[Error, LocalizationCase] \ Acquire =
        match Json.parse(text) {
            case Err(error) => Err(Error.Wire("realised text: ${ToString.toString(error)}"))
            case Ok(JObject(fields)) => forM (
                instanceId <- stringField("instanceId", fields);
                repository <- stringField("repository", fields);
                baseCommit <- stringField("baseCommit", fields);
                issueRevision <- stringField("issueRevision", fields);
                issueFixture <- stringField("issueFixture", fields);
                snapshot <- stringField("snapshot", fields);
                sources <- sourceVectorField("sources", fields);
                _ <- completeLocalizationContext(issueFixture, snapshot, paths)
            ) yield {
                instanceId = instanceId,
                repository = repository,
                baseCommit = baseCommit,
                issueRevision = issueRevision,
                issueFixture = StorePath.StorePath(issueFixture),
                snapshot = StorePath.StorePath(snapshot),
                sources = sources
            }
            case Ok(_) => Err(Error.Wire("realised localization text must be an object"))
        }

    def decodeEvaluationEvidence(text: String, paths: Vector[String]): Result[Error, EvaluationEvidence] =
        match Json.parse(text) {
            case Err(error) => Err(Error.Wire("realised evaluation text: ${ToString.toString(error)}"))
            case Ok(JObject(fields)) => forM (
                version <- intField("version", fields);
                _ <- if (version == 1) Ok(()) else Err(Error.UnsupportedVersion(version));
                benchmarkRevision <- stringField("benchmarkRevision", fields);
                evaluatorRevision <- stringField("evaluatorRevision", fields);
                goldFixture <- stringField("goldFixture", fields);
                _ <- if (Vector.toSet(paths) == Set#{goldFixture}) Ok(()) else Err(Error.IncompleteContext)
            ) yield {
                benchmarkRevision = benchmarkRevision,
                evaluatorRevision = evaluatorRevision,
                goldFixture = StorePath.StorePath(goldFixture)
            }
            case Ok(_) => Err(Error.Wire("realised evaluation text must be an object"))
        }

    def decodePopulationEvidence(text: String, paths: Vector[String]): Result[Error, PopulationEvidence] =
        match Json.parse(text) {
            case Err(error) => Err(Error.Wire("realised population text: ${ToString.toString(error)}"))
            case Ok(JObject(fields)) => forM (
                version <- intField("version", fields);
                _ <- if (version == 1) Ok(()) else Err(Error.UnsupportedVersion(version));
                benchmarkRevision <- stringField("benchmarkRevision", fields);
                multilingualRevision <- stringField("multilingualRevision", fields);
                proRevision <- stringField("proRevision", fields);
                benchmark <- stringField("benchmark", fields);
                multilingual <- stringField("multilingual", fields);
                pro <- stringField("pro", fields);
                projection <- stringField("projection", fields);
                _ <- if (Vector.toSet(paths) == Set#{benchmark, multilingual, pro, projection})
                    Ok(()) else Err(Error.IncompleteContext)
            ) yield {
                benchmarkRevision = benchmarkRevision,
                multilingualRevision = multilingualRevision,
                proRevision = proRevision,
                benchmark = StorePath.StorePath(benchmark),
                multilingual = StorePath.StorePath(multilingual),
                pro = StorePath.StorePath(pro),
                projection = StorePath.StorePath(projection)
            }
            case Ok(_) => Err(Error.Wire("realised population text must be an object"))
        }

    def completeContext(benchmark: String, snapshot: String, paths: Vector[String]): Result[Error, Unit] =
        if (Vector.toSet(paths) == Set#{benchmark, snapshot}) Ok(()) else Err(Error.IncompleteContext)

    def completeLocalizationContext(issueFixture: String, snapshot: String, paths: Vector[String]): Result[Error, Unit] =
        if (Vector.toSet(paths) == Set#{issueFixture, snapshot}) Ok(()) else Err(Error.IncompleteContext)

    def nativeError(value: Json): Result[Error, ExploreCase] = match value {
        case JObject(fields) => match stringField("kind", fields) {
            case Err(error) => Err(error)
            case Ok(kind) => match stringField("message", fields) {
                case Err(error) => Err(error)
                case Ok(message) => Err(Error.Native(kind, message))
            }
        }
        case _ => Err(Error.Wire("error must be a JSON object"))
    }

    def nativeLocalizationError(value: Json): Result[Error, LocalizationCase] = match value {
        case JObject(fields) => match stringField("kind", fields) {
            case Err(error) => Err(error)
            case Ok(kind) => match stringField("message", fields) {
                case Err(error) => Err(error)
                case Ok(message) => Err(Error.Native(kind, message))
            }
        }
        case _ => Err(Error.Wire("error must be an object"))
    }

    def nativeEvaluationError(value: Json): Result[Error, EvaluationEvidence] = match value {
        case JObject(fields) => match stringField("kind", fields) {
            case Err(error) => Err(error)
            case Ok(kind) => match stringField("message", fields) {
                case Err(error) => Err(error)
                case Ok(message) => Err(Error.Native(kind, message))
            }
        }
        case _ => Err(Error.Wire("error must be an object"))
    }

    def nativePopulationError(value: Json): Result[Error, PopulationEvidence] = match value {
        case JObject(fields) => match stringField("kind", fields) {
            case Err(error) => Err(error)
            case Ok(kind) => match stringField("message", fields) {
                case Err(error) => Err(error)
                case Ok(message) => Err(Error.Native(kind, message))
            }
        }
        case _ => Err(Error.Wire("error must be an object"))
    }

    def field(name: String, fields: Map[String, Json]): Result[Error, Json] =
        Map.get(name, fields) |> Option.toOk(Error.Wire("missing JSON field: ${name}"))

    def intField(name: String, fields: Map[String, Json]): Result[Error, Int32] = match field(name, fields) {
        case Err(error) => Err(error)
        case Ok(value) => FromJson.fromJson(value)
            |> Result.mapErr(error -> Error.Wire("${name}: ${ToString.toString(error)}"))
    }

    def stringField(name: String, fields: Map[String, Json]): Result[Error, String] = match field(name, fields) {
        case Err(error) => Err(error)
        case Ok(JString(value)) => Ok(value)
        case Ok(_) => Err(Error.Wire("${name}: expected string"))
    }

    def stringVectorField(name: String, fields: Map[String, Json]): Result[Error, Vector[String]] = match field(name, fields) {
        case Err(error) => Err(error)
        case Ok(JArray(values)) => FromJson.fromJson(JArray(values))
            |> Result.mapErr(error -> Error.Wire("${name}: ${ToString.toString(error)}"))
        case Ok(_) => Err(Error.Wire("${name}: expected array"))
    }

    def sourceVectorField(name: String, fields: Map[String, Json]): Result[Error, Vector[Source]] \ Acquire = match field(name, fields) {
        case Err(error) => Err(error)
        case Ok(JArray(values)) => Vector.traverse(decodeSource, values)
        case Ok(_) => Err(Error.Wire("${name}: expected array"))
    }

    def decodeSource(value: Json): Result[Error, Source] \ Acquire = match value {
        case JObject(fields) => match stringField("path", fields) {
            case Err(error) => Err(error)
            case Ok(path) => match Map.get("content", fields) {
                case Some(JString(content)) => Ok({path = path, content = content})
                case Some(_) => Err(Error.Wire("content: expected string"))
                case None => match stringField("file", fields) {
                    case Err(error) => Err(error)
                    case Ok(file) => Acquire.readSource(file)
                        |> Result.map(content -> {path = path, content = content})
                }
            }
        }
        case _ => Err(Error.Wire("source must be an object"))
    }

    def readNativeSource(file: String): Result[Error, String] \ IO =
        decodeNativeText(Wire.Wire(AttuneNix.readUtf8(file)))

    def decodeNativeText(wire: Wire): Result[Error, String] = {
        let Wire.Wire(payload) = wire;
        match Json.parse(payload) {
            case Err(error) => Err(Error.Wire(ToString.toString(error)))
            case Ok(JObject(fields)) => match intField("version", fields) {
                case Err(error) => Err(error)
                case Ok(version) if version != 1 => Err(Error.UnsupportedVersion(version))
                case Ok(_) => match Map.get("error", fields) {
                    case Some(value) => match nativeError(value) {
                        case Err(error) => Err(error)
                        case Ok(_) => Err(Error.Wire("native error unexpectedly decoded as a case"))
                    }
                    case None => stringField("text", fields)
                }
            }
            case Ok(_) => Err(Error.Wire("expected a JSON object"))
        }
    }

    def realiseNative(): Wire \ IO =
        Wire.Wire(AttuneNix.realise("import ./swe-explore.nix", System.getProperty("user.dir")))

    def realiseReplication(caseIndex: Int32): Wire \ IO =
        Wire.Wire(AttuneNix.realise(
            "import ./replication.nix { caseIndex = ${caseIndex}; }",
            System.getProperty("user.dir")
        ))

    def realiseLocalization(caseIndex: Int32): Wire \ IO =
        Wire.Wire(AttuneNix.realise(
            "import ./localization.nix { caseIndex = ${caseIndex}; }",
            System.getProperty("user.dir")
        ))

    def realiseEvaluation(): Wire \ IO =
        Wire.Wire(AttuneNix.realise(
            "import ./evaluation.nix",
            System.getProperty("user.dir")
        ))

    def realisePopulation(): Wire \ IO =
        Wire.Wire(AttuneNix.realise(
            "import ./scale-population.nix",
            System.getProperty("user.dir")
        ))
}
