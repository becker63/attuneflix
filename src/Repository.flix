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

    pub enum Error with Eq, ToString {
        case UnknownFactPath(String)
    }

    type alias Identity = (Repository.Grit.Fact, Repository.Structure.SymbolId)

    type alias Resolution[a, b] = {
        edges    = Repository.Structure.Relation[a, b],
        rejected = Int32
    }

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

    def definitionEdges(files: Map[String, Repository.Structure.FileId], identities: Vector[Identity]): Result[Error, Repository.Structure.Defines] =
        Vector.traverse(match (fact, symbol) ->
            Map.get(fact#path, files)
                |> Option.toOk(Error.UnknownFactPath(fact#path))
                |> Result.map(file -> (file, symbol)),
            identities)
        |> Result.map(Vector.toSet)

    def resolveImports(files: Map[String, Repository.Structure.FileId], facts: Vector[Repository.Grit.Fact]): Result[Error, Resolution[Repository.Structure.FileId, Repository.Structure.FileId]] =
        Vector.foldLeft((checked, fact) -> checked |> Result.flatMap(resolved ->
            match Map.get(fact#path, files) {
                case None => Err(Error.UnknownFactPath(fact#path))
                case Some(source) => match importTarget(fact, files) {
                    case None => Ok({edges = resolved#edges, rejected = resolved#rejected + 1})
                    case Some(target) => Ok({edges = Set.insert((source, target), resolved#edges), rejected = resolved#rejected})
                }
            }), Ok({edges = Set.empty(), rejected = 0}), facts)

    /// Language detection is the closure's admitted file-kind table, exposed so
    /// every caller and the admission policy agree on one route.
    pub def language(path: String): Option[Repository.Grit.Language] = Repository.Grit.language(path)

    /// Import/reference resolution is explicitly per-language behind ONE
    /// admission abstraction. The frontend hands over normalized source text;
    /// only the rule that turns it into an admitted file differs by language.
    def importTarget(fact: Repository.Grit.Fact, files: Map[String, Repository.Structure.FileId]): Option[Repository.Structure.FileId] =
        match Repository.Grit.language(fact#path) {
            case Some(Repository.Grit.Language.Java)     => dottedFile(fact#value, files, ".java")
            case Some(Repository.Grit.Language.Flix)     => flixImport(fact#value, files)
            case Some(Repository.Grit.Language.Starlark) => starlarkImport(fact#value, files)
            case Some(_)                                 => javascriptImport(fact, files)
            case None                                    => None
        }

    /// JavaScript/TypeScript relative module resolution.
    def javascriptImport(fact: Repository.Grit.Fact, files: Map[String, Repository.Structure.FileId]): Option[Repository.Structure.FileId] = {
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

    /// Flix resolves a qualified module reference to the admitted file whose
    /// module path it names. The longest dotted prefix that names an admitted
    /// file wins; only a unique file is admitted.
    def flixImport(value: String, files: Map[String, Repository.Structure.FileId]): Option[Repository.Structure.FileId] =
        match dottedName(value) {
            case None       => None
            case Some(name) => firstResolved(files, moduleCandidates(String.splitOn(substr = ".", name)))
        }

    def moduleCandidates(segments: List[String]): List[String] = match segments {
        case Nil => Nil
        case _ =>
            String.flatten(List.intersperse("/", segments)) + ".flix"
                :: moduleCandidates(List.take(List.length(segments) - 1, segments))
    }

    /// Java resolves a dotted type reference to its source file. The package
    /// path is tried first, then the bare type file as a conservative fallback.
    def dottedFile(value: String, files: Map[String, Repository.Structure.FileId], suffix: String): Option[Repository.Structure.FileId] =
        match dottedName(value) {
            case None       => None
            case Some(name) =>
                let segments = String.splitOn(substr = ".", name);
                let full = String.flatten(List.intersperse("/", segments)) + suffix;
                let last = match List.reverse(segments) {
                    case head :: _ => head + suffix
                    case Nil       => full
                };
                firstResolved(files, full :: last :: Nil)
        }

    /// Starlark resolves a repository-relative label that names a source file
    /// (`//tools:defs.bzl` -> `tools/defs.bzl`). External and target-only labels
    /// are conservatively rejected: they do not name an admitted file.
    def starlarkImport(value: String, files: Map[String, Repository.Structure.FileId]): Option[Repository.Structure.FileId] =
        match labelPath(String.trim(value)) {
            case None       => None
            case Some(path) => uniqueSuffix(files, path)
        }

    def labelPath(label: String): Option[String] =
        if (not String.startsWith(prefix = "\"", label) or not String.endsWith(suffix = "\"", label))
            None
        else {
            let unquoted = String.slice(start = 1, end = String.length(label) - 1, label);
            if (not String.startsWith(prefix = "//", unquoted))
                None
            else {
                let body = String.sliceRight(start = 2, unquoted);
                match String.indexOf(substr = ":", body) {
                    case None        => None
                    case Some(index) =>
                        let package = String.sliceLeft(end = index, body);
                        let target = String.sliceRight(start = index + 1, body);
                        if (String.contains(substr = ".", target))
                            if (package == "") Some(target) else Some(package + "/" + target)
                        else None
                }
            }
        }

    def firstResolved(files: Map[String, Repository.Structure.FileId], candidates: List[String]): Option[Repository.Structure.FileId] = match candidates {
        case Nil               => None
        case candidate :: rest => match uniqueSuffix(files, candidate) {
            case None       => firstResolved(files, rest)
            case Some(file) => Some(file)
        }
    }

    def uniqueSuffix(files: Map[String, Repository.Structure.FileId], candidate: String): Option[Repository.Structure.FileId] = {
        let matches = Vector.filterMap(entry -> {
            let (path, file) = entry;
            if (path == candidate or String.endsWith(suffix = "/" + candidate, path)) Some(file) else None
        }, Map.toVector(files));
        if (Vector.length(matches) == 1) Some(Vector.get(0, matches)) else None
    }

    /// The leading dotted name of a normalized reference value. A Flix
    /// `use`/`import` declaration carries its keyword and may end in a brace
    /// list; only the qualified name before it is the reference.
    def dottedName(value: String): Option[String] = {
        let trimmed = String.trim(value);
        let stripped =
            if (String.startsWith(prefix = "use ", trimmed)) String.sliceRight(start = 4, trimmed)
            else if (String.startsWith(prefix = "import ", trimmed)) String.sliceRight(start = 7, trimmed)
            else trimmed;
        let name = dropTrailingDots(String.trimRight(String.takeWhile(isNameChar, stripped)));
        if (name == "") None else Some(name)
    }

    def dropTrailingDots(name: String): String =
        if (String.endsWith(suffix = ".", name) and String.length(name) > 0)
            dropTrailingDots(String.sliceLeft(end = String.length(name) - 1, name))
        else name

    def isNameChar(character: Char): Bool =
        Char.isLetterOrDigit(character) or character == '.' or character == '_'

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
