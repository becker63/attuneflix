/// The World stage root: the admitted-world vocabulary shared by admission and
/// the per-language reference rules. The world, its symbols, and its sources
/// are the Stable Contract Kernel's stage types; this module owns the shared
/// resolution vocabulary and the pure path mechanics behind it.
pub mod World {
    /// Admission failures name the fact path that could not be admitted.
    pub enum Error with Eq, ToString {
        case UnknownFactPath(String)
    }

    /// One admitted definition paired with its nominal symbol identity.
    pub type alias Identity = (Repository.Grit.Fact, Kernel.Contract.SymbolId)

    /// One reference relation's admission outcome: the admitted edges plus the
    /// count of references the language rule conservatively rejected.
    pub type alias Resolution[a, b] = {
        edges    = Kernel.Contract.Relation[a, b],
        rejected = Int32
    }

    /// Language detection is the closure's admitted file-kind table, exposed so
    /// every caller and the admission policy agree on one route.
    pub def language(path: String): Option[Repository.Grit.Language] = Repository.Grit.language(path)

    /// The directory prefix of a repository-relative path (`""` at the root).
    pub def directory(path: String): String = match String.indexOfRight(substr = "/", path) {
        case None        => ""
        case Some(index) => String.sliceLeft(end = index, path)
    }

    pub def joinPath(left: String, right: String): String =
        if (left == "") right else left + "/" + right

    /// Collapse `.` and `..` segments in a joined path, keeping unresolved
    /// leading `..` segments verbatim.
    pub def normalizePath(path: String): String =
        normalizeParts(String.splitOn(substr = "/", path), Nil)
            |> List.reverse
            |> List.intersperse("/")
            |> List.fold

    /// Every directory prefix of a path, including the root and the full
    /// directory itself.
    pub def directoryPrefixes(path: String): Set[String] =
        prefixes(String.splitOn(substr = "/", path), "", Set.singleton(""))

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

    def prefixes(parts: List[String], current: String, result: Set[String]): Set[String] = match parts {
        case Nil => result
        case "" :: rest => prefixes(rest, current, result)
        case part :: rest =>
            let next = if (current == "") part else current + "/" + part;
            prefixes(rest, next, Set.insert(next, result))
    }
}
