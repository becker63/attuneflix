mod Repository {

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
        let definitions = canonicalDefinitions(definitions0);
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

    /// Grit emits definitions in canonical source/byte order. Retained worlds
    /// therefore normally arrive sorted already. Detect that linear case
    /// before calling the standard-library quicksort: on very large snapshots
    /// its recursive partitioning otherwise takes the worst-case path for an
    /// already-sorted vector. Unordered API callers retain the exact previous
    /// sorting rule.
    def canonicalDefinitions(definitions: Vector[Repository.Grit.Fact]): Vector[Repository.Grit.Fact] =
        if (definitionsOrdered(definitions, 1)) definitions
        else Vector.sortBy(factKey, definitions)

    def definitionsOrdered(
        definitions: Vector[Repository.Grit.Fact],
        index: Int32
    ): Bool =
        if (index >= Vector.length(definitions)) true
        else if (Order.lessEqual(
            factKey(Vector.get(index - 1, definitions)),
            factKey(Vector.get(index, definitions))))
            definitionsOrdered(definitions, index + 1)
        else false

    def factKey(fact: Repository.Grit.Fact): (String, Int32, Int32, String) =
        (fact#path, fact#startByte, fact#endByte, fact#value)

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

    /// Physical lookup plan for call admission. The semantic rule is still:
    /// choose the narrowest enclosing definition as caller, then admit a
    /// uniquely named local target or, when no local definition exists, a
    /// uniquely named repository target. Indexing only removes the old full
    /// definition-vector scans from every observed call.
    type alias CallIndex = {
        byPath        = Map[String, Vector[Identity]],
        localTargets  = Map[(String, String), Set[Repository.Structure.SymbolId]],
        globalTargets = Map[String, Set[Repository.Structure.SymbolId]]
    }

    def resolveCalls(identities: Vector[Identity], facts: Vector[Repository.Grit.Fact]): Resolution[Repository.Structure.SymbolId, Repository.Structure.SymbolId] = {
        let index = callIndex(identities);
        Vector.foldLeft((result, fact) -> match callEdge(index, fact) {
            case None => {edges = result#edges, rejected = result#rejected + 1}
            case Some(edge) => {edges = Set.insert(edge, result#edges), rejected = result#rejected}
        }, {edges = Set.empty(), rejected = 0}, facts)
    }

    def callEdge(index: CallIndex, call: Repository.Grit.Fact): Option[(Repository.Structure.SymbolId, Repository.Structure.SymbolId)] =
        match owner(index, call) {
            case None => None
            case Some(caller) =>
                let callee = String.replace(src = "?.", dst = ".", call#value);
                if (dynamic(callee)) None
                else target(index, call#path, simpleName(callee))
                    |> Option.map(found -> (caller, found))
        }

    def owner(index: CallIndex, call: Repository.Grit.Fact): Option[Repository.Structure.SymbolId] =
        Vector.foldLeft((best, identity) -> match identity {
            case (definition, symbol) =>
                if (definition#startByte <= call#startByte and call#endByte <= definition#endByte)
                    narrowerOwner(best, definition#endByte - definition#startByte, symbol)
                else
                    best
        }, None, Map.getWithDefault(call#path, Vector.empty(), index#byPath))
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

    def target(index: CallIndex, path: String, name: String): Option[Repository.Structure.SymbolId] = {
        let local = Map.getWithDefault((path, name), Set.empty(), index#localTargets);
        if (Set.size(local) == 1)
            Some(Vector.get(0, Set.toVector(local)))
        else if (Set.size(local) > 0)
            None
        else {
            let global = Map.getWithDefault(name, Set.empty(), index#globalTargets);
            if (Set.size(global) == 1) Some(Vector.get(0, Set.toVector(global))) else None
        }
    }

    def callIndex(identities: Vector[Identity]): CallIndex =
        Vector.foldLeft((index, identity) -> {
            let (fact, symbol) = identity;
            {
                byPath = Map.insert(fact#path,
                    Vector.append(Map.getWithDefault(fact#path, Vector.empty(), index#byPath),
                        Vector#{identity}), index#byPath),
                localTargets = Map.insert((fact#path, fact#value),
                    Set.insert(symbol, Map.getWithDefault((fact#path, fact#value), Set.empty(),
                        index#localTargets)), index#localTargets),
                globalTargets = Map.insert(fact#value,
                    Set.insert(symbol, Map.getWithDefault(fact#value, Set.empty(), index#globalTargets)),
                    index#globalTargets)
            }
        }, {
            byPath = Map.empty(),
            localTargets = Map.empty(),
            globalTargets = Map.empty()
        }, identities)

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
