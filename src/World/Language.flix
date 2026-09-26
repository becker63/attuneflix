/// Language reference rules: the one admission abstraction. The frontend hands
/// over normalized reference text; only the rule that turns it into an admitted
/// file differs by language, so this module is the single dispatch point and
/// the shared reference-name mechanics behind every per-language rule.
pub mod World.Language {
    /// Import/reference resolution is explicitly per-language behind ONE
    /// admission abstraction.
    pub def importTarget(fact: Repository.Grit.Fact, files: Map[String, Kernel.Contract.FileId]): Option[Kernel.Contract.FileId] =
        match Repository.Grit.language(fact#path) {
            case Some(Repository.Grit.Language.Java)     => World.Language.Java.dottedFile(fact#value, files, ".java")
            case Some(Repository.Grit.Language.Flix)     => World.Language.Flix.flixImport(fact#value, files)
            case Some(Repository.Grit.Language.Starlark) => World.Language.Starlark.starlarkImport(fact#value, files)
            case Some(_)                                 => World.Language.JavaScript.javascriptImport(fact, files)
            case None                                    => None
        }

    /// The leading dotted name of a normalized reference value. A Flix
    /// `use`/`import` declaration carries its keyword and may end in a brace
    /// list; only the qualified name before it is the reference.
    pub def dottedName(value: String): Option[String] = {
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

    /// The first candidate that names exactly one admitted file.
    pub def firstResolved(
        files: Map[String, Kernel.Contract.FileId],
        candidates: List[String]
    ): Option[Kernel.Contract.FileId] = match candidates {
        case Nil               => None
        case candidate :: rest => match uniqueSuffix(files, candidate) {
            case None       => firstResolved(files, rest)
            case Some(file) => Some(file)
        }
    }

    /// The admitted file a candidate names: its exact path, or a unique path
    /// suffix. An ambiguous candidate is conservatively rejected, not guessed.
    pub def uniqueSuffix(
        files: Map[String, Kernel.Contract.FileId],
        candidate: String
    ): Option[Kernel.Contract.FileId] = {
        let matches = Vector.filterMap(entry -> {
            let (path, file) = entry;
            if (path == candidate or String.endsWith(suffix = "/" + candidate, path)) Some(file) else None
        }, Map.toVector(files));
        if (Vector.length(matches) == 1) Some(Vector.get(0, matches)) else None
    }
}
