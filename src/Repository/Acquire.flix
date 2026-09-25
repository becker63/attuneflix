pub mod Repository.Acquire {
    import attune.grit.AttuneGrit

    use Repository.Grit.{Fact, Language, Program, Wire}

    /// Run one relation program against one source through the real native Grit
    /// engine. This is the whole program dispatch/native boundary: the language
    /// and the relation select one packaged `.grit` entry point, and the frozen
    /// ABI executes it. Language-specific syntax never leaves this seam.
    pub def evaluate(language: Language, program: Program, path: String, source: String): Wire \ IO = {
        let name = Repository.Grit.name(language);
        Wire.Wire(AttuneGrit.evaluate(
            name,
            AttuneGrit.program(name, Repository.Grit.programName(program)),
            path,
            source))
    }

    /// Stable, honest classification of an acquisition failure.
    pub enum AcquisitionError with Eq, ToString {
        case Grit(Repository.Grit.Error),
        case Admission(Repository.Error)
    }

    type alias Facts = {
        definitions = Vector[Fact],
        imports     = Vector[Fact],
        calls       = Vector[Fact]
    }

    /// Acquire every admitted source file into one canonical Repository world:
    /// detect the language from the path, run the three relation programs, parse
    /// the facts, and admit them through ordinary Repository admission. Every
    /// language emits the same `Repository.Grit.Fact`; there are no per-language
    /// facts or worlds.
    pub def acquire(sources: Vector[Repository.Source]): Result[AcquisitionError, Repository.World] \ IO =
        Vector.traverse(source -> sourceFacts(source), sources)
            |> Result.flatMap(all -> acquireWorld(sources, all))

    def acquireWorld(sources: Vector[Repository.Source], all: Vector[Facts]): Result[AcquisitionError, Repository.World] =
        Repository.admit(
            sources,
            Vector.flatten(Vector.map(facts -> facts#definitions, all)),
            Vector.flatten(Vector.map(facts -> facts#imports, all)),
            Vector.flatten(Vector.map(facts -> facts#calls, all))
        ) |> Result.mapErr(AcquisitionError.Admission)

    def sourceFacts(source: Repository.Source): Result[AcquisitionError, Facts] \ IO =
        match Repository.Grit.language(source#path) {
            case None => Ok(emptyFacts())
            case Some(language) => forM (
                definitions <- facts(language, Program.Defines, source);
                imports <- facts(language, Program.Imports, source);
                calls <- facts(language, Program.Calls, source)
            ) yield {definitions = definitions, imports = imports, calls = calls}
        }

    def facts(language: Language, program: Program, source: Repository.Source): Result[AcquisitionError, Vector[Fact]] \ IO =
        Repository.Grit.facts(
            source#path,
            source#content,
            evaluate(language, program, source#path, source#content))
            |> Result.mapErr(AcquisitionError.Grit)

    def emptyFacts(): Facts = {
        definitions = Vector.empty(),
        imports = Vector.empty(),
        calls = Vector.empty()
    }
}
