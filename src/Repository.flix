mod Repository {
    use Fs.FileSystem
    use Util.Json
    use Util.Json.Json.{JArray, JObject, JString}
    use Util.Json.FromJson
    use Util.Json.ToJson

    pub type alias Source = {
        path    = String,
        content = String
    }

    pub type alias Symbol = {
        path      = String,
        name      = String,
        startByte = Int32,
        endByte   = Int32
    }

    pub type alias World = {
        files             = Vector[String],
        symbols           = Vector[Symbol],
        defines           = Repository.Structure.Defines,
        imports           = Repository.Structure.Imports,
        calls             = Repository.Structure.Calls,
        parents           = Repository.Structure.Parents,
        unresolvedImports = Int32,
        unresolvedCalls   = Int32
    }

    pub type alias Observations = {
        sources     = Vector[Source],
        definitions = Vector[Repository.Grit.Fact],
        imports     = Vector[Repository.Grit.Fact],
        calls       = Vector[Repository.Grit.Fact]
    }

    pub enum Error with Eq, ToString {
        case Grit(Repository.Grit.Error),
        case Store(String),
        case Wire(String),
        case DuplicatePath(String),
        case UnsupportedSourceDialect(String),
        case UnexpectedFact(String, String),
        case UnknownFactPath(String)
    }

    type alias Identity = (Repository.Grit.Fact, Repository.Structure.SymbolId)

    type alias Resolution[a, b] = {
        edges    = Repository.Structure.Relation[a, b],
        rejected = Int32
    }

    /// Execute the three fixed source observations, then admit repository facts.
    pub def extract(sources0: Vector[Source]): Result[Error, World] \ Repository.Grit.Eval = {
        forM (
            observations <- observeAll(sources0);
            world <- admitObserved(observations)
        ) yield world
    }

    /// Replays immutable Grit facts when available and otherwise retains them
    /// atomically before pure repository admission. The artifact is keyed by
    /// the Nix snapshot and exact Grit/Marzano observation identity; resolver
    /// changes therefore re-admit the same source evidence instead of buying
    /// native extraction again.
    pub def extractRetained(
        root: String,
        repository: String,
        baseCommit: String,
        snapshot: String,
        sources0: Vector[Source]
    ): Result[Error, World] \ {FileSystem, Repository.Grit.Eval} = {
        let file = "${root}/${baseCommit}.json";
        match FileSystem.exists(file) |> Result.mapErr(storeError) {
            case Err(error) => Err(error)
            case Ok(true) => FileSystem.read(file)
                |> Result.mapErr(storeError)
                |> Result.flatMap(payload -> decodeObservationsAtIdentity(
                    repository, baseCommit, snapshot, sources0,
                    Repository.Grit.observationIdentity(), payload))
                |> Result.flatMap(admitObserved)
            case Ok(false) => match observeAll(sources0) {
                case Err(error) => Err(error)
                case Ok(observations) => {
                    let payload = encodeObservations(
                        repository, baseCommit, snapshot, observations);
                    let written = run { FileSystem.write(str = payload, file) }
                        with FileSystem.withMkParentDirs
                        with FileSystem.withAtomicWrite;
                    match Result.mapErr(storeError, written) {
                        case Err(error) => Err(error)
                        case Ok(()) => admitObserved(observations)
                    }
                }
            }
        }
    }

    /// Strict deterministic replay. Downstream scientific phases must never
    /// turn a missing fact artifact into an unreported live extraction.
    pub def replayRetained(
        root: String,
        repository: String,
        baseCommit: String,
        snapshot: String,
        sources0: Vector[Source]
    ): Result[Error, World] \ FileSystem = {
        let file = "${root}/${baseCommit}.json";
        match FileSystem.exists(file) |> Result.mapErr(storeError) {
            case Err(error) => Err(error)
            case Ok(false) => Err(Error.Store("retained repository observation missing: ${file}"))
            case Ok(true) => FileSystem.read(file)
                |> Result.mapErr(storeError)
                |> Result.flatMap(payload -> decodeObservationsAtIdentity(
                    repository, baseCommit, snapshot, sources0,
                    Repository.Grit.observationIdentity(), payload))
                |> Result.flatMap(admitObserved)
        }
    }

    def encodeObservations(
        repository: String,
        baseCommit: String,
        snapshot: String,
        observations: Observations
    ): String = Json.toCompactString(JObject(Map#{
        "version" => ToJson.toJson(1),
        "repository" => JString(repository),
        "base_commit" => JString(baseCommit),
        "snapshot" => JString(snapshot),
        "grit_identity" => JString(Repository.Grit.observationIdentity()),
        "definitions" => factsJson(observations#definitions),
        "imports" => factsJson(observations#imports),
        "calls" => factsJson(observations#calls)
    }))

    /// Explicit identity parameter exists for the one-time extractor-layout
    /// parity audit. Normal replay always supplies the current identity above.
    pub def decodeObservationsAtIdentity(
        repository: String,
        baseCommit: String,
        snapshot: String,
        sources0: Vector[Source],
        expectedIdentity: String,
        payload: String
    ): Result[Error, Observations] = match Json.parse(payload) {
        case Err(error) => Err(Error.Wire(ToString.toString(error)))
        case Ok(JObject(fields)) => forM (
            version <- intField("version", fields);
            _ <- requireField("repository", repository, fields);
            _ <- requireField("base_commit", baseCommit, fields);
            _ <- requireField("snapshot", snapshot, fields);
            _ <- requireField("grit_identity", expectedIdentity, fields);
            definitions <- factVectorField("definitions", fields);
            imports <- factVectorField("imports", fields);
            calls <- factVectorField("calls", fields);
            _ <- if (version == 1) Ok(()) else Err(Error.Wire("unsupported retained fact version"))
        ) yield {
            sources = Vector.sortBy(source -> source#path, sources0),
            definitions = definitions,
            imports = imports,
            calls = calls
        }
        case Ok(_) => Err(Error.Wire("retained facts must be an object"))
    }

    def factsJson(facts: Vector[Repository.Grit.Fact]): Json =
        JArray(Vector.map(fact -> JObject(Map#{
            "kind" => JString(fact#kind),
            "path" => JString(fact#path),
            "start_byte" => ToJson.toJson(fact#startByte),
            "end_byte" => ToJson.toJson(fact#endByte),
            "value" => JString(fact#value)
        }), facts))

    def factVectorField(name: String, fields: Map[String, Json]): Result[Error, Vector[Repository.Grit.Fact]] =
        match Map.get(name, fields) {
            case None => Err(Error.Wire("missing JSON field: ${name}"))
            case Some(JArray(values)) => Vector.traverse(decodeFact, values)
            case Some(_) => Err(Error.Wire("${name}: expected array"))
        }

    def decodeFact(value: Json): Result[Error, Repository.Grit.Fact] = match value {
        case JObject(fields) => forM (
            kind <- stringField("kind", fields);
            path <- stringField("path", fields);
            startByte <- intField("start_byte", fields);
            endByte <- intField("end_byte", fields);
            text <- stringField("value", fields)
        ) yield {
            kind = kind,
            path = path,
            startByte = startByte,
            endByte = endByte,
            value = text
        }
        case _ => Err(Error.Wire("fact must be an object"))
    }

    def requireField(name: String, expected: String, fields: Map[String, Json]): Result[Error, Unit] =
        stringField(name, fields) |> Result.flatMap(actual ->
            if (actual == expected) Ok(())
            else Err(Error.Wire("retained ${name} mismatch")))

    def stringField(name: String, fields: Map[String, Json]): Result[Error, String] =
        match Map.get(name, fields) {
            case Some(JString(value)) => Ok(value)
            case Some(_) => Err(Error.Wire("${name}: expected string"))
            case None => Err(Error.Wire("missing JSON field: ${name}"))
        }

    def intField(name: String, fields: Map[String, Json]): Result[Error, Int32] =
        match Map.get(name, fields) {
            case Some(value) => FromJson.fromJson(value)
                |> Result.mapErr(error -> Error.Wire("${name}: ${ToString.toString(error)}"))
            case None => Err(Error.Wire("missing JSON field: ${name}"))
        }

    def storeError(error: a): Error with ToString[a] =
        Error.Store(ToString.toString(error))

    /// Effectful source observation is kept separate so experiments can time Grit honestly.
    pub def observeAll(sources0: Vector[Source]): Result[Error, Observations] \ Repository.Grit.Eval = {
        let sources = Vector.sortBy(source -> source#path, sources0);
        match duplicatePath(sources) {
            case Some(path) => Err(Error.DuplicatePath(path))
            case None => forM (
                definitions <- observe(Repository.Grit.Program.Defines, "definition", sources);
                imports <- observe(Repository.Grit.Program.Imports, "import", sources);
                calls <- observe(Repository.Grit.Program.Calls, "call", sources)
            ) yield {
                sources = sources,
                definitions = definitions,
                imports = imports,
                calls = calls
            }
        }
    }

    pub def admitObserved(observations: Observations): Result[Error, World] =
        admit(
            observations#sources,
            observations#definitions,
            observations#imports,
            observations#calls
        )

    /// Pure admission is independently testable from the native acquisition effect.
    pub def admit(
        sources: Vector[Source],
        definitions0: Vector[Repository.Grit.Fact],
        importFacts: Vector[Repository.Grit.Fact],
        callFacts: Vector[Repository.Grit.Fact]
    ): Result[Error, World] = {
        let definitions = Vector.sortBy(
            fact -> (fact#path, fact#startByte, fact#endByte, fact#value),
            definitions0
        );
        let paths = Vector.map(source -> source#path, sources);
        let fileIds = Vector.mapWithIndex((index, path) -> (path, Repository.Structure.FileId.FileId(index)), paths)
            |> Vector.toMap;
        let identities = Vector.mapWithIndex(
            (index, fact) -> (fact, Repository.Structure.SymbolId.SymbolId(index)),
            definitions
        );
        let called = resolveCalls(identities, callFacts);
        forM (
            defines <- definitionEdges(fileIds, identities);
            imported <- resolveImports(fileIds, importFacts)
        ) yield {
            files = paths,
            symbols = Vector.map(fact -> {
                path = fact#path,
                name = fact#value,
                startByte = fact#startByte,
                endByte = fact#endByte
            }, definitions),
            defines = defines,
            imports = imported#edges,
            calls = called#edges,
            parents = parentEdges(paths),
            unresolvedImports = imported#rejected,
            unresolvedCalls = called#rejected
        }
    }

    pub def allSymbols(world: World): Set[Repository.Structure.SymbolId] =
        Vector.range(0, Vector.length(world#symbols))
            |> Vector.map(Repository.Structure.SymbolId.SymbolId)
            |> Vector.toSet

    def observe(program: Repository.Grit.Program, kind: String, sources: Vector[Source]): Result[Error, Vector[Repository.Grit.Fact]] \ Repository.Grit.Eval =
        Vector.traverse(source -> match language(source#path) {
            case Err(error) => Err(error)
            case Ok(dialect) => {
                let wire = Repository.Grit.evaluate(dialect, program, source#path, source#content);
                Repository.Grit.facts(source#path, source#content, wire)
                    |> Result.mapErr(Error.Grit)
                    |> Result.flatMap(facts -> requireKind(kind, facts))
            }
        }, sources)
            |> Result.map(Vector.flatten)

    pub def language(path: String): Result[Error, Repository.Grit.Language] =
        if (String.endsWith(suffix = ".tsx", path)) Ok(Repository.Grit.Language.Tsx)
        else if (String.endsWith(suffix = ".jsx", path)) Ok(Repository.Grit.Language.Jsx)
        else if (List.exists(suffix -> String.endsWith(suffix = suffix, path),
            ".js" :: ".mjs" :: ".cjs" :: Nil)) Ok(Repository.Grit.Language.JavaScript)
        else if (List.exists(suffix -> String.endsWith(suffix = suffix, path),
            ".ts" :: ".mts" :: ".cts" :: Nil)) Ok(Repository.Grit.Language.TypeScript)
        else Err(Error.UnsupportedSourceDialect(path))

    def requireKind(expected: String, facts: Vector[Repository.Grit.Fact]): Result[Error, Vector[Repository.Grit.Fact]] =
        match Vector.find(fact -> fact#kind != expected, facts) {
            case None => Ok(facts)
            case Some(fact) => Err(Error.UnexpectedFact(expected, fact#kind))
        }

    def duplicatePath(sources: Vector[Source]): Option[String] =
        duplicatePathList(Vector.toList(sources), None)

    def duplicatePathList(sources: List[Source], previous: Option[String]): Option[String] = match sources {
        case Nil => None
        case source :: rest => match previous {
            case Some(path) if path == source#path => Some(path)
            case _ => duplicatePathList(rest, Some(source#path))
        }
    }

    def definitionEdges(files: Map[String, Repository.Structure.FileId], identities: Vector[Identity]): Result[Error, Repository.Structure.Defines] =
        Vector.traverse(match (fact, symbol) ->
            Map.get(fact#path, files)
                |> Option.toOk(Error.UnknownFactPath(fact#path))
                |> Result.map(file -> (file, symbol)),
            identities)
        |> Result.map(Vector.toSet)

    def resolveImports(files: Map[String, Repository.Structure.FileId], facts: Vector[Repository.Grit.Fact]): Result[Error, Resolution[Repository.Structure.FileId, Repository.Structure.FileId]] =
        resolveImportsList(files, Vector.toList(facts), Set.empty(), 0)

    def resolveImportsList(
        files: Map[String, Repository.Structure.FileId],
        facts: List[Repository.Grit.Fact],
        edges: Repository.Structure.Imports,
        rejected: Int32
    ): Result[Error, Resolution[Repository.Structure.FileId, Repository.Structure.FileId]] = match facts {
        case Nil => Ok({edges = edges, rejected = rejected})
        case fact :: rest => match Map.get(fact#path, files) {
            case None => Err(Error.UnknownFactPath(fact#path))
            case Some(source) => match importTarget(fact, files) {
                case None => resolveImportsList(files, rest, edges, rejected + 1)
                case Some(target) => resolveImportsList(files, rest, Set.insert((source, target), edges), rejected)
            }
        }
    }

    def importTarget(fact: Repository.Grit.Fact, files: Map[String, Repository.Structure.FileId]): Option[Repository.Structure.FileId] = {
        let value = String.trim(fact#value);
        let length = String.length(value);
        if (length < 2)
            None
        else {
            let first = String.charAt(0, value);
            let quoted = (first == '"' or first == '\'') and String.charAt(length - 1, value) == first;
            if (not quoted)
                None
            else {
                let specifier = String.slice(start = 1, end = length - 1, value);
                if (not String.startsWith(prefix = ".", specifier))
                    None
                else {
                    let base = normalizePath(joinPath(directory(fact#path), specifier));
                    Vector.findMap(candidate -> Map.get(candidate, files), importCandidates(base))
                }
            }
        }
    }

    def importCandidates(base: String): Vector[String] = {
        let suffixes = Vector#{".ts", ".tsx", ".js", ".jsx", ".mts", ".cts", ".mjs", ".cjs"};
        Vector#{base}
            |> Vector.append(Vector.map(suffix -> base + suffix, suffixes))
            |> Vector.append(Vector.map(suffix -> base + "/index" + suffix, suffixes))
    }

    def resolveCalls(identities: Vector[Identity], facts: Vector[Repository.Grit.Fact]): Resolution[Repository.Structure.SymbolId, Repository.Structure.SymbolId] =
        Vector.foldLeft((result, fact) -> match callEdge(identities, fact) {
            case None => {edges = result#edges, rejected = result#rejected + 1}
            case Some(edge) => {edges = Set.insert(edge, result#edges), rejected = result#rejected}
        }, {edges = Set.empty(), rejected = 0}, facts)

    def callEdge(identities: Vector[Identity], call: Repository.Grit.Fact): Option[(Repository.Structure.SymbolId, Repository.Structure.SymbolId)] =
        match owner(identities, call) {
            case None => None
            case Some(caller) =>
                let callee = String.replace(src = "?.", dst = ".", call#value);
                if (dynamic(callee)) None
                else target(identities, call#path, simpleName(callee))
                    |> Option.map(found -> (caller, found))
        }

    def owner(identities: Vector[Identity], call: Repository.Grit.Fact): Option[Repository.Structure.SymbolId] =
        Vector.foldLeft((best, identity) -> match identity {
            case (definition, symbol) =>
                if (definition#path == call#path and definition#startByte <= call#startByte and call#endByte <= definition#endByte)
                    narrowerOwner(best, definition#endByte - definition#startByte, symbol)
                else
                    best
        }, None, identities)
        |> Option.map(match (_, symbol) -> symbol)

    def narrowerOwner(
        best: Option[(Int32, Repository.Structure.SymbolId)],
        width: Int32,
        symbol: Repository.Structure.SymbolId
    ): Option[(Int32, Repository.Structure.SymbolId)] = match best {
        case None => Some((width, symbol))
        case Some((current, _)) if width < current => Some((width, symbol))
        case _ => best
    }

    def target(identities: Vector[Identity], path: String, name: String): Option[Repository.Structure.SymbolId] = {
        let local = Vector.filter(match (fact, _) -> fact#path == path and fact#value == name, identities);
        if (Vector.length(local) == 1)
            Some(identitySymbol(Vector.get(0, local)))
        else if (not Vector.isEmpty(local))
            None
        else {
            let global = Vector.filter(match (fact, _) -> fact#value == name, identities);
            if (Vector.length(global) == 1) Some(identitySymbol(Vector.get(0, global))) else None
        }
    }

    def identitySymbol(identity: Identity): Repository.Structure.SymbolId = match identity {
        case (_, symbol) => symbol
    }

    def dynamic(callee: String): Bool =
        List.exists(marker -> String.contains(substr = marker, callee),
            "(" :: "[" :: "{" :: "'" :: "\"" :: "`" :: "\n" :: Nil)

    def simpleName(callee: String): String = match String.indexOfRight(substr = ".", callee) {
        case None => callee
        case Some(index) => String.sliceRight(start = index + 1, callee)
    }

    def parentEdges(paths: Vector[String]): Repository.Structure.Parents = {
        let directories = Vector.foldLeft(
            (known, path) -> Set.union(known, directoryPrefixes(directory(path))),
            Set.singleton(""),
            paths
        ) |> Set.toVector |> Vector.sort;
        let offset = Vector.length(paths);
        let identities = Vector.mapWithIndex(
            (index, path) -> (path, Repository.Structure.LocationId.LocationId(offset + index)),
            directories
        ) |> Vector.toMap;
        let fileParents = Vector.mapWithIndex((index, path) ->
            (Repository.Structure.LocationId.LocationId(index), Option.getWithDefault(
                Repository.Structure.LocationId.LocationId(0),
                Map.get(directory(path), identities)
            )), paths);
        let directoryParents = Vector.filterMap(path ->
            if (path == "") None
            else forM (
                child <- Map.get(path, identities);
                parent <- Map.get(directory(path), identities)
            ) yield (child, parent),
            directories);
        Vector.append(fileParents, directoryParents) |> Vector.toSet
    }

    def directoryPrefixes(path: String): Set[String] =
        prefixes(String.splitOn(substr = "/", path), "", Set.singleton(""))

    def prefixes(parts: List[String], current: String, result: Set[String]): Set[String] = match parts {
        case Nil => result
        case "" :: rest => prefixes(rest, current, result)
        case part :: rest =>
            let next = if (current == "") part else current + "/" + part;
            prefixes(rest, next, Set.insert(next, result))
    }

    def directory(path: String): String = match String.indexOfRight(substr = "/", path) {
        case None => ""
        case Some(index) => String.sliceLeft(end = index, path)
    }

    def joinPath(left: String, right: String): String =
        if (left == "") right else left + "/" + right

    def normalizePath(path: String): String =
        normalizeParts(String.splitOn(substr = "/", path), Nil)
            |> List.reverse
            |> List.intersperse("/")
            |> List.fold

    def normalizeParts(parts: List[String], stack: List[String]): List[String] = match parts {
        case Nil => stack
        case "" :: rest => normalizeParts(rest, stack)
        case "." :: rest => normalizeParts(rest, stack)
        case ".." :: rest => match stack {
            case head :: tail if head != ".." => normalizeParts(rest, tail)
            case _ => normalizeParts(rest, ".." :: stack)
        }
        case part :: rest => normalizeParts(rest, part :: stack)
    }
}
