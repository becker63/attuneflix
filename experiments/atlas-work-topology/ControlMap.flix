/// The work-topology experiment's frozen path protocols: the 10-region
/// conceptual partition (PREREGISTRATION.md §4, `attuneflix-regions-v1`), the
/// K4 ownership-cell partition (§5, `attuneflix-cells-v1`), the move-stable
/// surface class and the declared-identity rule of §9.
///
/// These are pure functions of an admitted path (plus its declared definitions
/// for one case) and are protocol constants: they are fixed before any control
/// or candidate number is seen and are never re-tuned afterwards. A region is
/// a semantic subsystem; a cell is an ownership unit; they are reported
/// separately and never conflated.
pub mod ControlMap {
    /// §4 `attuneflix-regions-v1`: first matching rule wins. The residual
    /// `other` bucket is reported, never dropped.
    pub def regionOf(path: String): String =
        if (path == "src/Repository.flix" or String.startsWith(prefix = "src/Repository/", path)) "repository"
        else if (path == "src/Radii.flix" or String.startsWith(prefix = "src/Radii/", path)) "radii"
        else if (path == "src/Atlas.flix" or String.startsWith(prefix = "src/Atlas/", path)) "atlas"
        else if (path == "src/Localization.flix" or String.startsWith(prefix = "src/Localization/", path)) "localization"
        else if (path == "src/ScientificTable.flix" or String.startsWith(prefix = "src/ScientificTable/", path)) "tables"
        else if (path == "src/Population.flix" or String.startsWith(prefix = "src/Population/", path)) "population"
        else if (String.startsWith(prefix = "src/", path)) "src-root"
        else if (String.startsWith(prefix = "test/", path)) "tests"
        else if (String.startsWith(prefix = "build/src/", path)) "build-src"
        else if (String.startsWith(prefix = "experiments/", path)) "experiments"
        else "other"

    /// The ten named regions in fixed order.
    pub def regions(): Vector[String] = Vector#{"repository", "radii", "atlas", "localization",
        "tables", "population", "src-root", "tests", "build-src", "experiments"}

    /// §5 `attuneflix-cells-v1`: first matching rule wins, reported separately
    /// from the region partition. The residual `other` bucket is reported.
    pub def cellOf(path: String): String =
        if (kernel(path)) "kernel"
        else if (world(path)) "world"
        else if (engine(path)) "engine"
        else if (applications(path)) "applications"
        else if (research(path)) "research"
        else if (law(path)) "law"
        else "other"

    /// The K4 cells in fixed order (kernel and law are the stable substrate and
    /// the unowned horizontal law surface, not the four cells).
    pub def cells(): Vector[String] = Vector#{"kernel", "world", "engine", "applications", "research",
        "law", "other"}

    /// §9 surface class: a coarse, move-stable prefix rule that keeps two files
    /// declaring the same module name distinct (`src/Repository.flix` as
    /// production versus `build/src/Repository.flix` as law).
    pub def surfaceClass(path: String): String =
        if (String.startsWith(prefix = "src/", path)) "production"
        else if (String.startsWith(prefix = "test/", path)) "law"
        else if (String.startsWith(prefix = "build/", path)) "law"
        else if (String.startsWith(prefix = "experiments/", path)) "instrument"
        else "law"

    /// §9 `declared_identity`, from the file's language and its admitted
    /// `defines` facts (value, startByte, endByte) in canonical byte order.
    /// Paths are deliberately not part of the payload; identity survives moves.
    pub def declaredIdentity(path: String, language: String,
                             definitions: Vector[(String, Int32, Int32)]): String =
        if (language == "flix") flixIdentity(path, definitions)
        else if (language == "java") javaIdentity(path)
        else if (language == "starlark") bazelIdentity(path)
        else if (String.endsWith(suffix = ".grit", path)) gritIdentity(path)
        else moduleStem(path, ".flix")

    /// A Flix file's declared identity is its module declaration when one is
    /// present, otherwise the basename without `.flix`.
    ///
    /// A module declaration is the unique admitted definition fact that
    /// encloses at least one other definition fact and is itself enclosed by
    /// none. Definitions legitimately nest (enum cases inside an enum, a local
    /// definition inside a definition), but a top-level `mod` is the only
    /// maximal enclosing declaration in a module-bearing file. When the fact
    /// stream cannot name a unique such declaration (a file with no module, or
    /// a module with an empty body) the basename is the stable fallback.
    def flixIdentity(path: String, definitions: Vector[(String, Int32, Int32)]): String =
        match moduleDeclaration(definitions) {
            case Some(name) => name
            case None => moduleStem(path, ".flix")
        }

    def moduleDeclaration(definitions: Vector[(String, Int32, Int32)]): Option[String] = {
        let candidates = Vector.filterMap(candidate -> match candidate {
            case (name, start, end) =>
                if (enclosesOther(definitions, start, end) and not enclosedByOther(definitions, start, end))
                    Some(name)
                else None
        }, definitions);
        if (Vector.length(candidates) == 1) Some(Vector.get(0, candidates)) else None
    }

    def enclosesOther(definitions: Vector[(String, Int32, Int32)], start: Int32, end: Int32): Bool =
        Vector.exists(match (_, otherStart, otherEnd) ->
            not (otherStart == start and otherEnd == end) and start <= otherStart and otherEnd <= end,
            definitions)

    def enclosedByOther(definitions: Vector[(String, Int32, Int32)], start: Int32, end: Int32): Bool =
        Vector.exists(match (_, otherStart, otherEnd) ->
            not (otherStart == start and otherEnd == end) and otherStart <= start and end <= otherEnd,
            definitions)

    /// A Java file's declared identity is its declared package plus its class
    /// name. Every admitted Java file lives on the canonical
    /// `src/native/<package>/Class.java` layout, so the package is
    /// `attune.<package>` and the class is the basename.
    def javaIdentity(path: String): String =
        javaPackage(path) + "." + moduleStem(path, ".java")

    def javaPackage(path: String): String = {
        let marker = "src/native/";
        let relative = if (String.startsWith(prefix = marker, path))
            String.sliceRight(start = String.length(marker), path)
        else path;
        let directory = directoryOf(relative);
        if (directory == "") "attune" else "attune." + String.replace(src = "/", dst = ".", directory)
    }

    /// A Bazel/Starlark file's declared identity is its Bazel package path plus
    /// basename (`root` names the repository root).
    def bazelIdentity(path: String): String = {
        let directory = directoryOf(path);
        let package0 = if (directory == "") "root" else directory;
        package0 + "/" + basename(path)
    }

    /// A Grit frontend's declared identity is `<relation>/<language>`. No
    /// `.grit` file is admitted at control (the Grit frontends are not one of
    /// the admitted source languages); the rule is retained for completeness.
    def gritIdentity(path: String): String =
        basename(directoryOf(path)) + "/" + moduleStem(path, ".grit")

    def moduleStem(path: String, suffix: String): String = {
        let file = basename(path);
        if (String.endsWith(suffix = suffix, file))
            String.sliceLeft(end = String.length(file) - String.length(suffix), file)
        else file
    }

    def basename(path: String): String = match String.indexOfRight(substr = "/", path) {
        case None => path
        case Some(index) => String.sliceRight(start = index + 1, path)
    }

    def directoryOf(path: String): String = match String.indexOfRight(substr = "/", path) {
        case None => ""
        case Some(index) => String.sliceLeft(end = index, path)
    }

    // §5 cell rules, in first-match-wins order.

    def kernel(path: String): Bool =
        path == "src/ScientificIdentity.flix" or path == "src/ScientificTable.flix"
            or String.startsWith(prefix = "src/ScientificTable/", path)
            or String.startsWith(prefix = "src/native/identity/", path)
            or String.startsWith(prefix = "src/native/parquet/", path)

    def world(path: String): Bool =
        path == "src/Repository.flix"
            or (String.startsWith(prefix = "src/Repository/", path) and path != "src/Repository/Physical.flix")
            or String.startsWith(prefix = "src/grit/", path)
            or String.startsWith(prefix = "src/native/grit/", path)

    def engine(path: String): Bool =
        path == "src/Repository/Physical.flix" or path == "src/Radii.flix"
            or String.startsWith(prefix = "src/Radii/", path)
            or path == "src/Atlas.flix" or String.startsWith(prefix = "src/Atlas/", path)

    def applications(path: String): Bool =
        path == "src/Localization.flix" or String.startsWith(prefix = "src/Localization/", path)
            or path == "src/Population.flix" or String.startsWith(prefix = "src/Population/", path)
            or String.startsWith(prefix = "src/native/inference/", path)

    def research(path: String): Bool =
        path == "src/Experiment.flix" or String.startsWith(prefix = "experiments/", path)

    def law(path: String): Bool =
        String.startsWith(prefix = "test/", path) or String.startsWith(prefix = "build/", path)
            or path == "BUILD.bazel" or path == "MODULE.bazel"
            or String.startsWith(prefix = "data/", path)
}
