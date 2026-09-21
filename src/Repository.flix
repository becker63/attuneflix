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
        defines           = Structure.Defines,
        imports           = Structure.Imports,
        calls             = Structure.Calls,
        parents           = Structure.Parents,
        unresolvedImports = Int32,
        unresolvedCalls   = Int32
    }

    pub enum Error with Eq, ToString {
        case Grit(Grit.Error),
        case DuplicatePath(String),
        case UnexpectedFact(String, String),
        case UnknownFactPath(String)
    }

    type alias Identity = (Grit.Fact, Structure.SymbolId)

    type alias Resolution[a, b] = {
        edges    = Structure.Relation[a, b],
        rejected = Int32
    }

    /// Execute the three fixed source observations, then admit repository facts.
    pub def extract(sources0: Vector[Source]): Result[Error, World] \ Grit.Eval = {
        let sources = Vector.sortBy(source -> source#path, sources0);
        match duplicatePath(sources) {
            case Some(path) => Err(Error.DuplicatePath(path))
            case None => forM (
                definitions <- observe(Grit.Program.Defines, "definition", sources);
                imports <- observe(Grit.Program.Imports, "import", sources);
                calls <- observe(Grit.Program.Calls, "call", sources);
                world <- admit(sources, definitions, imports, calls)
            ) yield world
        }
    }

    /// Pure admission is independently testable from the native acquisition effect.
    pub def admit(
        sources: Vector[Source],
        definitions0: Vector[Grit.Fact],
        importFacts: Vector[Grit.Fact],
        callFacts: Vector[Grit.Fact]
    ): Result[Error, World] = {
        let definitions = Vector.sortBy(
            fact -> (fact#path, fact#startByte, fact#endByte, fact#value),
            definitions0
        );
        let paths = Vector.map(source -> source#path, sources);
        let fileIds = Vector.mapWithIndex((index, path) -> (path, Structure.FileId.FileId(index)), paths)
            |> Vector.toMap;
        let identities = Vector.mapWithIndex(
            (index, fact) -> (fact, Structure.SymbolId.SymbolId(index)),
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

    pub def allSymbols(world: World): Set[Structure.SymbolId] =
        Vector.range(0, Vector.length(world#symbols))
            |> Vector.map(Structure.SymbolId.SymbolId)
            |> Vector.toSet

    def observe(program: Grit.Program, kind: String, sources: Vector[Source]): Result[Error, Vector[Grit.Fact]] \ Grit.Eval =
        Vector.traverse(source -> {
            let wire = Grit.evaluate(Grit.Language.TypeScript, program, source#path, source#content);
            Grit.facts(source#path, source#content, wire)
                |> Result.mapErr(Error.Grit)
                |> Result.flatMap(facts -> requireKind(kind, facts))
        }, sources)
            |> Result.map(Vector.flatten)

    def requireKind(expected: String, facts: Vector[Grit.Fact]): Result[Error, Vector[Grit.Fact]] =
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

    def definitionEdges(files: Map[String, Structure.FileId], identities: Vector[Identity]): Result[Error, Structure.Defines] =
        Vector.traverse(match (fact, symbol) ->
            Map.get(fact#path, files)
                |> Option.toOk(Error.UnknownFactPath(fact#path))
                |> Result.map(file -> (file, symbol)),
            identities)
        |> Result.map(Vector.toSet)

    def resolveImports(files: Map[String, Structure.FileId], facts: Vector[Grit.Fact]): Result[Error, Resolution[Structure.FileId, Structure.FileId]] =
        resolveImportsList(files, Vector.toList(facts), Set.empty(), 0)

    def resolveImportsList(
        files: Map[String, Structure.FileId],
        facts: List[Grit.Fact],
        edges: Structure.Imports,
        rejected: Int32
    ): Result[Error, Resolution[Structure.FileId, Structure.FileId]] = match facts {
        case Nil => Ok({edges = edges, rejected = rejected})
        case fact :: rest => match Map.get(fact#path, files) {
            case None => Err(Error.UnknownFactPath(fact#path))
            case Some(source) => match importTarget(fact, files) {
                case None => resolveImportsList(files, rest, edges, rejected + 1)
                case Some(target) => resolveImportsList(files, rest, Set.insert((source, target), edges), rejected)
            }
        }
    }

    def importTarget(fact: Grit.Fact, files: Map[String, Structure.FileId]): Option[Structure.FileId] = {
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

    def resolveCalls(identities: Vector[Identity], facts: Vector[Grit.Fact]): Resolution[Structure.SymbolId, Structure.SymbolId] =
        Vector.foldLeft((result, fact) -> match callEdge(identities, fact) {
            case None => {edges = result#edges, rejected = result#rejected + 1}
            case Some(edge) => {edges = Set.insert(edge, result#edges), rejected = result#rejected}
        }, {edges = Set.empty(), rejected = 0}, facts)

    def callEdge(identities: Vector[Identity], call: Grit.Fact): Option[(Structure.SymbolId, Structure.SymbolId)] =
        match owner(identities, call) {
            case None => None
            case Some(caller) =>
                let callee = String.replace(src = "?.", dst = ".", call#value);
                if (dynamic(callee)) None
                else target(identities, call#path, simpleName(callee))
                    |> Option.map(found -> (caller, found))
        }

    def owner(identities: Vector[Identity], call: Grit.Fact): Option[Structure.SymbolId] =
        Vector.foldLeft((best, identity) -> match identity {
            case (definition, symbol) =>
                if (definition#path == call#path and definition#startByte <= call#startByte and call#endByte <= definition#endByte)
                    narrowerOwner(best, definition#endByte - definition#startByte, symbol)
                else
                    best
        }, None, identities)
        |> Option.map(match (_, symbol) -> symbol)

    def narrowerOwner(
        best: Option[(Int32, Structure.SymbolId)],
        width: Int32,
        symbol: Structure.SymbolId
    ): Option[(Int32, Structure.SymbolId)] = match best {
        case None => Some((width, symbol))
        case Some((current, _)) if width < current => Some((width, symbol))
        case _ => best
    }

    def target(identities: Vector[Identity], path: String, name: String): Option[Structure.SymbolId] = {
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

    def identitySymbol(identity: Identity): Structure.SymbolId = match identity {
        case (_, symbol) => symbol
    }

    def dynamic(callee: String): Bool =
        List.exists(marker -> String.contains(substr = marker, callee),
            "(" :: "[" :: "{" :: "'" :: "\"" :: "`" :: "\n" :: Nil)

    def simpleName(callee: String): String = match String.indexOfRight(substr = ".", callee) {
        case None => callee
        case Some(index) => String.sliceRight(start = index + 1, callee)
    }

    def parentEdges(paths: Vector[String]): Structure.Parents = {
        let directories = Vector.foldLeft(
            (known, path) -> Set.union(known, directoryPrefixes(directory(path))),
            Set.singleton(""),
            paths
        ) |> Set.toVector |> Vector.sort;
        let offset = Vector.length(paths);
        let identities = Vector.mapWithIndex(
            (index, path) -> (path, Structure.LocationId.LocationId(offset + index)),
            directories
        ) |> Vector.toMap;
        let fileParents = Vector.mapWithIndex((index, path) ->
            (Structure.LocationId.LocationId(index), Option.getWithDefault(
                Structure.LocationId.LocationId(0),
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
