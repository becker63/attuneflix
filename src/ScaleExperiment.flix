pub mod ScaleExperiment {
    use Fs.FileSystem
    use Util.Json
    use Util.Json.Json.{JArray, JObject, JString}
    use Util.Json.FromJson
    use Util.Json.ToJson

    type alias BenchmarkCase = {
        instanceId    = String,
        datasetFamily = String
    }

    type alias SourceCase = {
        instanceId    = String,
        datasetFamily = String,
        repository    = String,
        baseRevision  = String,
        sourceLanguage = String
    }

    type alias Projection = {
        benchmarkCases = Vector[BenchmarkCase],
        sourceCases    = Vector[SourceCase]
    }

    pub type alias Case = {
        instanceId       = String,
        datasetFamily    = String,
        repository       = String,
        baseRevision     = String,
        sourceIdentity   = String,
        declaredLanguage = String,
        dialectRouting   = String,
        population       = String,
        split            = String
    }

    pub type alias Manifest = {
        benchmarkRevision     = String,
        multilingualRevision  = String,
        proRevision           = String,
        benchmarkStorePath    = String,
        multilingualStorePath = String,
        proStorePath          = String,
        projectionStorePath   = String,
        cases                 = Vector[Case]
    }

    type alias SplitCandidate = {
        repositories = Set[String],
        cases        = Int32
    }

    pub enum Error with ToString {
        case Nix(Repository.Nix.Error),
        case File(String),
        case Wire(String),
        case UnsupportedVersion(Int32),
        case DuplicateSource(String, String),
        case MissingSource(String, String),
        case SourceIdentityMismatch(String),
        case UnsupportedEligibleRepository(String),
        case PopulationCount(String, Int32, Int32),
        case Repository(Repository.Error),
        case HistoricalParity(String),
        case MissingHistoricalFacts(String)
    }

    pub def materialize(path: String): Result[Error, Manifest] \ {FileSystem, Repository.Nix.Acquire} = forM (
        evidence <- Repository.Nix.population() |> Result.mapErr(Error.Nix);
        payload <- Repository.Nix.Acquire.readSource(Repository.Nix.path(evidence#projection))
            |> Result.mapErr(Error.Nix);
        projection <- decodeProjection(payload);
        manifest <- build(evidence, projection);
        _ <- writeManifest(path, encode(manifest))
    ) yield manifest

    def writeManifest(path: String, payload: String): Result[Error, Unit] \ FileSystem = {
        let written = run { FileSystem.write(str = payload, path) }
            with FileSystem.withMkParentDirs
            with FileSystem.withAtomicWrite;
        Result.mapErr(error -> Error.File(ToString.toString(error)), written)
    }

    pub def encode(manifest: Manifest): String =
        Json.toCompactString(manifestJson(manifest))

    pub def count(manifest: Manifest): Int32 = Vector.length(manifest#cases)

    pub def historicalCount(manifest: Manifest): Int32 =
        Vector.count(case0 -> case0#population == "historical-development", manifest#cases)

    pub def validationCount(manifest: Manifest): Int32 =
        Vector.count(case0 -> case0#split == "post-optimization-validation", manifest#cases)

    pub def historicalParity(root: String): Result[Error, Unit] \ {FileSystem, IO, Repository.Grit.Eval, Repository.Nix.Acquire} =
        historicalParityCase(root, 0)

    def historicalParityCase(
        root: String,
        index: Int32
    ): Result[Error, Unit] \ {FileSystem, IO, Repository.Grit.Eval, Repository.Nix.Acquire} =
        if (index >= 15) Ok(())
        else forM (
            case0 <- Repository.Nix.localization(index) |> Result.mapErr(Error.Nix);
            payload <- FileSystem.read("${root}/${case0#baseCommit}.json")
                |> Result.mapErr(_ -> Error.MissingHistoricalFacts(case0#instanceId));
            sources = Vector.map(source -> {path = source#path, content = source#content}, case0#sources);
            legacy <- Repository.decodeObservationsAtIdentity(
                case0#repository,
                case0#baseCommit,
                Repository.Nix.path(case0#snapshot),
                sources,
                legacyGritIdentity(),
                payload
            ) |> Result.mapErr(Error.Repository);
            current <- Repository.observeAll(sources) |> Result.mapErr(Error.Repository);
            _ <- if (sameObservations(legacy, current)) Ok(())
                else Err(Error.HistoricalParity(case0#instanceId));
            legacyWorld <- Repository.admitObserved(legacy) |> Result.mapErr(Error.Repository);
            currentWorld <- Repository.admitObserved(current) |> Result.mapErr(Error.Repository);
            _ <- if (sameWorld(legacyWorld, currentWorld)) Ok(())
                else Err(Error.HistoricalParity(case0#instanceId));
            _ = println("SCALE_PARITY ${case0#instanceId}" +
                " definitions=${Vector.length(current#definitions)}" +
                " imports=${Vector.length(current#imports)}" +
                " calls=${Vector.length(current#calls)}");
            _ <- historicalParityCase(root, index + 1)
        ) yield ()

    def sameObservations(left: Repository.Observations, right: Repository.Observations): Bool =
        Vector.map(source -> (source#path, source#content), left#sources) ==
            Vector.map(source -> (source#path, source#content), right#sources) and
        factTuples(left#definitions) == factTuples(right#definitions) and
        factTuples(left#imports) == factTuples(right#imports) and
        factTuples(left#calls) == factTuples(right#calls)

    def factTuples(facts: Vector[Repository.Grit.Fact]): Vector[(String, String, Int32, Int32, String)] =
        Vector.map(fact -> (fact#kind, fact#path, fact#startByte, fact#endByte, fact#value), facts)

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

    def build(
        evidence: Repository.Nix.PopulationEvidence,
        projection: Projection
    ): Result[Error, Manifest] = forM (
        sources <- sourceIndex(Vector.toList(projection#sourceCases), Map.empty());
        eligible <- eligibleCases(Vector.toList(projection#benchmarkCases), sources, Vector.empty());
        sorted = Vector.sortBy(case0 -> case0#instanceId, eligible);
        _ <- requireCount("eligible JS/TS cases", 78, Vector.length(sorted));
        _ <- requireCount("historical development cases", 15,
            Vector.count(case0 -> isHistorical(case0#instanceId), sorted));
        validationRepositories = chooseValidationRepositories(sorted);
        cases = Vector.map(case0 -> assignSplit(case0, validationRepositories), sorted);
        _ <- requireCount("new cases", 63,
            Vector.count(case0 -> case0#population == "new", cases));
        _ <- requireCount("JavaScript cases", 51,
            Vector.count(case0 -> case0#declaredLanguage == "javascript", cases));
        _ <- requireCount("TypeScript cases", 27,
            Vector.count(case0 -> case0#declaredLanguage == "typescript", cases))
    ) yield {
        benchmarkRevision = evidence#benchmarkRevision,
        multilingualRevision = evidence#multilingualRevision,
        proRevision = evidence#proRevision,
        benchmarkStorePath = Repository.Nix.path(evidence#benchmark),
        multilingualStorePath = Repository.Nix.path(evidence#multilingual),
        proStorePath = Repository.Nix.path(evidence#pro),
        projectionStorePath = Repository.Nix.path(evidence#projection),
        cases = cases
    }

    def sourceIndex(
        cases: List[SourceCase],
        result: Map[(String, String), SourceCase]
    ): Result[Error, Map[(String, String), SourceCase]] = match cases {
        case Nil => Ok(result)
        case case0 :: rest => {
            let key = (case0#datasetFamily, case0#instanceId);
            match Map.get(key, result) {
                case Some(_) => Err(Error.DuplicateSource(case0#datasetFamily, case0#instanceId))
                case None => sourceIndex(rest, Map.insert(key, case0, result))
            }
        }
    }

    def eligibleCases(
        benchmark: List[BenchmarkCase],
        sources: Map[(String, String), SourceCase],
        result: Vector[Case]
    ): Result[Error, Vector[Case]] = match benchmark {
        case Nil => Ok(result)
        case benchmarkCase :: rest => {
            let family = benchmarkCase#datasetFamily;
            if (family != "multilingual" and family != "pro")
                eligibleCases(rest, sources, result)
            else match Map.get((family, benchmarkCase#instanceId), sources) {
                case None => Err(Error.MissingSource(family, benchmarkCase#instanceId))
                case Some(source) => match declaredLanguage(source#repository) {
                    case None => eligibleCases(rest, sources, result)
                    case Some(language) => {
                        let eligible = family == "multilingual" or
                            source#sourceLanguage == "js" or source#sourceLanguage == "ts";
                        if (not eligible)
                            Err(Error.UnsupportedEligibleRepository(source#repository))
                        else if (source#instanceId != benchmarkCase#instanceId or
                            source#datasetFamily != benchmarkCase#datasetFamily)
                            Err(Error.SourceIdentityMismatch(benchmarkCase#instanceId))
                        else {
                            let case0 = {
                                instanceId = source#instanceId,
                                datasetFamily = source#datasetFamily,
                                repository = source#repository,
                                baseRevision = source#baseRevision,
                                sourceIdentity = "github:${source#repository}@${source#baseRevision}",
                                declaredLanguage = language,
                                dialectRouting = "extension-explicit-v1",
                                population = if (isHistorical(source#instanceId))
                                    "historical-development" else "new",
                                split = "unassigned"
                            };
                            eligibleCases(rest, sources, Vector.append(result, Vector#{case0}))
                        }
                    }
                }
            }
        }
    }

    /// The public SWE-Explore distribution fixes 51 JavaScript and 27
    /// TypeScript instances. Source datasets use coarser JS/TS family labels,
    /// so repository identity is the stable declaration boundary.
    def declaredLanguage(repository: String): Option[String] = match repository {
        case "NodeBB/NodeBB"          => Some("javascript")
        case "protonmail/webclients" => Some("javascript")
        case "axios/axios"           => Some("javascript")
        case "mrdoob/three.js"       => Some("javascript")
        case "preactjs/preact"       => Some("javascript")
        case "element-hq/element-web"   => Some("typescript")
        case "tutao/tutanota"           => Some("typescript")
        case "babel/babel"               => Some("typescript")
        case "facebook/docusaurus"       => Some("typescript")
        case "immutable-js/immutable-js" => Some("typescript")
        case "vuejs/core"                => Some("typescript")
        case _ => None
    }

    def historicalIds(): Set[String] = Set#{
        "axios__axios-4731",
        "axios__axios-5085",
        "immutable-js__immutable-js-2005",
        "immutable-js__immutable-js-2006",
        "preactjs__preact-2757",
        "preactjs__preact-2896",
        "preactjs__preact-3010",
        "preactjs__preact-3454",
        "preactjs__preact-3562",
        "preactjs__preact-3689",
        "preactjs__preact-3739",
        "preactjs__preact-3763",
        "preactjs__preact-4152",
        "preactjs__preact-4182",
        "preactjs__preact-4436"
    }

    def isHistorical(instanceId: String): Bool = Set.memberOf(instanceId, historicalIds())

    def chooseValidationRepositories(cases: Vector[Case]): Set[String] = {
        let counts = Vector.foldLeft((result, case0) ->
            if (case0#population == "new")
                Map.insertWith((old, next) -> old + next, case0#repository, 1, result)
            else result,
            Map.empty(), cases);
        let groups = Map.toVector(counts) |> Vector.sortBy(match (repository, _) -> repository) |> Vector.toList;
        let candidates = subsets(groups, {repositories = Set.empty(), cases = 0});
        let target = Vector.count(case0 -> case0#population == "new", cases) / 3;
        List.foldLeft((best, candidate) ->
            if (distance(candidate#cases, target) < distance(best#cases, target)) candidate else best,
            {repositories = Set.empty(), cases = 0}, candidates)#repositories
    }

    def subsets(
        groups: List[(String, Int32)],
        candidate: SplitCandidate
    ): List[SplitCandidate] = match groups {
        case Nil => candidate :: Nil
        case (repository, count0) :: rest =>
            subsets(rest, candidate) ::: subsets(rest, {
                repositories = Set.insert(repository, candidate#repositories),
                cases = candidate#cases + count0
            })
    }

    def distance(left: Int32, right: Int32): Int32 =
        if (left >= right) left - right else right - left

    def assignSplit(case0: Case, validation: Set[String]): Case =
        if (case0#population == "historical-development")
            { instanceId = case0#instanceId, datasetFamily = case0#datasetFamily,
              repository = case0#repository, baseRevision = case0#baseRevision,
              sourceIdentity = case0#sourceIdentity, declaredLanguage = case0#declaredLanguage,
              dialectRouting = case0#dialectRouting, population = case0#population,
              split = "historical-development" }
        else
            { instanceId = case0#instanceId, datasetFamily = case0#datasetFamily,
              repository = case0#repository, baseRevision = case0#baseRevision,
              sourceIdentity = case0#sourceIdentity, declaredLanguage = case0#declaredLanguage,
              dialectRouting = case0#dialectRouting, population = case0#population,
              split = if (Set.memberOf(case0#repository, validation))
                  "post-optimization-validation" else "optimization-development" }

    def requireCount(name: String, expected: Int32, actual: Int32): Result[Error, Unit] =
        if (expected == actual) Ok(()) else Err(Error.PopulationCount(name, expected, actual))

    def decodeProjection(payload: String): Result[Error, Projection] = match Json.parse(payload) {
        case Err(error) => Err(Error.Wire(ToString.toString(error)))
        case Ok(JObject(fields)) => forM (
            version <- intField("version", fields);
            _ <- if (version == 1) Ok(()) else Err(Error.UnsupportedVersion(version));
            benchmarkValues <- arrayField("benchmark_cases", fields);
            sourceValues <- arrayField("source_cases", fields);
            benchmarkCases <- Vector.traverse(decodeBenchmarkCase, benchmarkValues);
            sourceCases <- Vector.traverse(decodeSourceCase, sourceValues)
        ) yield {benchmarkCases = benchmarkCases, sourceCases = sourceCases}
        case Ok(_) => Err(Error.Wire("population projection must be an object"))
    }

    def decodeBenchmarkCase(value: Json): Result[Error, BenchmarkCase] = match value {
        case JObject(fields) => forM (
            instanceId <- stringField("instance_id", fields);
            datasetFamily <- stringField("dataset_family", fields)
        ) yield {instanceId = instanceId, datasetFamily = datasetFamily}
        case _ => Err(Error.Wire("benchmark case must be an object"))
    }

    def decodeSourceCase(value: Json): Result[Error, SourceCase] = match value {
        case JObject(fields) => forM (
            instanceId <- stringField("instance_id", fields);
            datasetFamily <- stringField("dataset_family", fields);
            repository <- stringField("repository", fields);
            baseRevision <- stringField("base_revision", fields);
            sourceLanguage <- stringField("source_language", fields)
        ) yield {
            instanceId = instanceId,
            datasetFamily = datasetFamily,
            repository = repository,
            baseRevision = baseRevision,
            sourceLanguage = sourceLanguage
        }
        case _ => Err(Error.Wire("source case must be an object"))
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

    def arrayField(name: String, fields: Map[String, Json]): Result[Error, Vector[Json]] = match field(name, fields) {
        case Err(error) => Err(error)
        case Ok(JArray(values)) => Ok(values)
        case Ok(_) => Err(Error.Wire("${name}: expected array"))
    }

    def manifestJson(manifest: Manifest): Json = {
        let counts = repositoryCounts(manifest#cases);
        let revisions = Vector.map(case0 -> case0#baseRevision, manifest#cases) |> Vector.toSet;
        let repositories = Vector.map(case0 -> case0#repository, manifest#cases) |> Vector.toSet;
        JObject(Map#{
            "version" => ToJson.toJson(1),
            "benchmark_revision" => JString(manifest#benchmarkRevision),
            "source_artifacts" => JObject(Map#{
                "swe_explore" => artifactJson(manifest#benchmarkRevision, manifest#benchmarkStorePath),
                "swe_bench_multilingual" => artifactJson(manifest#multilingualRevision, manifest#multilingualStorePath),
                "swe_bench_pro" => artifactJson(manifest#proRevision, manifest#proStorePath),
                "gold_free_projection" => JObject(Map#{"store_path" => JString(manifest#projectionStorePath)})
            }),
            "frozen_machine" => JObject(Map#{
                "atoms" => ToJson.toJson(Vector#{"defined_in", "defines", "calls", "callers", "imports", "imported_by"}),
                "max_depth" => ToJson.toJson(7),
                "center_count" => ToJson.toJson(8),
                "logical_non_root_routes" => ToJson.toJson(3279),
                "symbol_ending_routes" => ToJson.toJson(1643)
            }),
            "source_dialect_routing" => JObject(Map#{
                "identity" => JString("extension-explicit-v1"),
                "javascript" => ToJson.toJson(Vector#{".js", ".mjs", ".cjs"}),
                "jsx" => ToJson.toJson(Vector#{".jsx"}),
                "typescript" => ToJson.toJson(Vector#{".ts", ".mts", ".cts"}),
                "tsx" => ToJson.toJson(Vector#{".tsx"}),
                "unknown" => JString("reject")
            }),
            "summary" => JObject(Map#{
                "total_eligible_cases" => ToJson.toJson(Vector.length(manifest#cases)),
                "historical_development_cases" => ToJson.toJson(historicalCount(manifest)),
                "new_cases" => ToJson.toJson(Vector.count(case0 -> case0#population == "new", manifest#cases)),
                "distinct_repositories" => ToJson.toJson(Set.size(repositories)),
                "distinct_base_revisions" => ToJson.toJson(Set.size(revisions)),
                "javascript_cases" => ToJson.toJson(Vector.count(case0 -> case0#declaredLanguage == "javascript", manifest#cases)),
                "typescript_cases" => ToJson.toJson(Vector.count(case0 -> case0#declaredLanguage == "typescript", manifest#cases)),
                "optimization_development_cases" => ToJson.toJson(Vector.count(case0 -> case0#split == "optimization-development", manifest#cases)),
                "post_optimization_validation_cases" => ToJson.toJson(validationCount(manifest)),
                "cases_by_repository" => countsJson(counts)
            }),
            "cases" => JArray(Vector.map(caseJson, manifest#cases))
        })
    }

    def artifactJson(revision: String, storePath: String): Json = JObject(Map#{
        "revision" => JString(revision),
        "store_path" => JString(storePath)
    })

    def repositoryCounts(cases: Vector[Case]): Map[String, Int32] =
        Vector.foldLeft((counts, case0) ->
            Map.insertWith((old, next) -> old + next, case0#repository, 1, counts),
            Map.empty(), cases)

    def countsJson(counts: Map[String, Int32]): Json =
        JObject(Map.toVector(counts)
            |> Vector.map(match (name, count0) -> (name, ToJson.toJson(count0)))
            |> Vector.toMap)

    def caseJson(case0: Case): Json = JObject(Map#{
        "instance_id" => JString(case0#instanceId),
        "dataset_family" => JString(case0#datasetFamily),
        "repository" => JString(case0#repository),
        "base_revision" => JString(case0#baseRevision),
        "source_identity" => JString(case0#sourceIdentity),
        "declared_benchmark_language" => JString(case0#declaredLanguage),
        "source_dialect_routing" => JString(case0#dialectRouting),
        "population" => JString(case0#population),
        "repository_group_split" => JString(case0#split)
    })
}
