/// The v2 acquisition seam (PREREGISTRATION.md "AMENDMENT — v2 acquisition"):
/// runs the repository's own acquisition path — the frozen native Grit engine,
/// the packaged `.grit` frontends, the one `Repository.Grit.Fact` protocol and
/// ordinary admission — over one frozen revision's isolated worktree, and
/// writes the typed artifacts the measurement graph consumes.
///
/// This is the only step that needs the native engine. Everything downstream
/// (re-admission -> Repository.World -> Atlas) is pure and hermetic over the
/// committed artifacts written here.
mod AcquisitionDriver {
    import java.nio.file.{Files, Paths}
    use Repository.Grit.Program

    pub def execute(): Unit \ IO = match Experiment.property("attune.command") {
        case "acquire" => acquire()
        case "summary" => summarize()
        case command => bug!("unknown acquisition command: ${command}")
    }

    /// Evidence report over one committed acquisition artifact pair: the
    /// admitted languages, the per-program fact counts, and the exact Grit fact
    /// kinds. Printed, never stored: the artifacts themselves are the evidence.
    def summarize(): Unit \ IO = {
        let sources = AcquisitionFacts.readSources(Experiment.property("attune.sources"));
        let facts = AcquisitionFacts.readFacts(Experiment.property("attune.facts"));
        let world = Experiment.require(AcquisitionFacts.world(sources, facts));
        println("SOURCES files=${Vector.length(sources)}");
        Vector.foldLeft((_, entry) -> match entry {
            case (language, count) => println("SOURCE_LANGUAGE ${language} files=${count}")
        }, (), histogram(Vector.map(source -> source#language, sources)));
        println("FACTS total=${Vector.length(facts)}");
        Vector.foldLeft((_, entry) -> match entry {
            case (program, count) => println("FACT_PROGRAM ${program} facts=${count} files=${Vector.length(distinctPaths(facts, program))}")
        }, (), histogram(Vector.map(fact -> fact#program, facts)));
        Vector.foldLeft((_, entry) -> match entry {
            case (key, count) => println("FACT_KIND ${key} facts=${count}")
        }, (), histogram(Vector.map(fact -> "${fact#language} ${fact#program} ${fact#kind}", facts)));
        println("WORLD files=${Vector.length(world#files)} symbols=${Vector.length(world#symbols)} " +
            "defines=${Set.size(world#defines)} imports=${Set.size(world#imports)} calls=${Set.size(world#calls)} " +
            "unresolved_imports=${world#unresolvedImports} unresolved_calls=${world#unresolvedCalls}")
    }

    def distinctPaths(facts: Vector[AcquisitionFacts.FactRow], program: String): Vector[String] =
        Vector.filter(fact -> fact#program == program, facts) |> Vector.map(fact -> fact#path)
            |> Vector.toSet |> Set.toVector

    def histogram(values: Vector[String]): Vector[(String, Int32)] =
        Map.toVector(Vector.foldLeft((counts, value) ->
            Map.insert(value, Map.getWithDefault(value, 0, counts) + 1, counts), Map.empty(), values))
            |> Vector.sortBy(match (key, _) -> key)

    /// `attune.root` (frozen worktree), `attune.manifest` (committed admitted
    /// file list), `attune.sources` and `attune.facts` (output Parquet).
    def acquire(): Unit \ IO = {
        let root = Experiment.property("attune.root");
        let paths = lines(Experiment.property("attune.manifest"));
        let acquired = Vector.map(path -> acquireSource(root, path), paths);
        let sources = Vector.map(match (source, _) -> source, acquired);
        let facts = Vector.flatten(Vector.map(match (_, rows) -> rows, acquired));
        let world = Experiment.require(AcquisitionFacts.world(sources, facts));
        AcquisitionFacts.writeSources(Experiment.property("attune.sources"), sources);
        AcquisitionFacts.writeFacts(Experiment.property("attune.facts"), facts);
        println("ATLAS_PARALLELISM_ACQUIRE files=${Vector.length(sources)} facts=${Vector.length(facts)} " +
            "symbols=${Vector.length(world#symbols)} defines=${Set.size(world#defines)} " +
            "imports=${Set.size(world#imports)} calls=${Set.size(world#calls)} " +
            "unresolved_imports=${world#unresolvedImports} unresolved_calls=${world#unresolvedCalls}")
    }

    def acquireSource(root: String, path: String): (AcquisitionFacts.Source, Vector[AcquisitionFacts.FactRow]) \ IO = {
        let content = Files.readString(Paths.get(root + "/" + path));
        let source = {
            path = path,
            sha256 = ScientificIdentity.sha256(content),
            bytes = Vector.length(String.toBytes(content)),
            language = languageName(path)
        };
        (source, Vector.flatMap(program -> factsOf(source, content, program), programs()))
    }

    def programs(): Vector[Program] = Vector#{Program.Defines, Program.Imports, Program.Calls}

    /// One relation program over one source, through the real engine and the
    /// one fact protocol. The engine's language string and the program resource
    /// name both come from `Repository.Grit`, never from a second table.
    def factsOf(source: AcquisitionFacts.Source, content: String, program: Program): Vector[AcquisitionFacts.FactRow] \ IO =
        match Repository.Grit.language(source#path) {
            case None => Vector.empty()
            case Some(language) =>
                let wire = Repository.Acquire.evaluate(language, program, source#path, content);
                Repository.Grit.facts(source#path, content, wire)
                    |> Result.mapErr(error -> ToString.toString(error))
                    |> Experiment.require
                    |> Vector.map(fact -> {
                        path = source#path, sourceSha256 = source#sha256, language = source#language,
                        program = Repository.Grit.programName(program), kind = fact#kind,
                        startByte = fact#startByte, endByte = fact#endByte, value = fact#value
                    })
        }

    def languageName(path: String): String = match Repository.Grit.language(path) {
        case None => "none"
        case Some(language) => Repository.Grit.name(language)
    }

    def lines(path: String): Vector[String] \ IO =
        String.lines(Files.readString(Paths.get(path))) |> List.toVector
            |> Vector.filter(line -> String.length(String.trim(line)) > 0)
}
