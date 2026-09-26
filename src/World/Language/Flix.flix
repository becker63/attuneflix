/// Flix module resolution: a qualified module reference resolves to the
/// admitted file whose module path it names. The longest dotted prefix that
/// names an admitted file wins; only a unique file is admitted.
pub mod World.Language.Flix {
    pub def flixImport(value: String, files: Map[String, Kernel.Contract.FileId]): Option[Kernel.Contract.FileId] =
        match World.Language.dottedName(value) {
            case None       => None
            case Some(name) => World.Language.firstResolved(files, moduleCandidates(String.splitOn(substr = ".", name)))
        }

    def moduleCandidates(segments: List[String]): List[String] = match segments {
        case Nil => Nil
        case _ =>
            String.flatten(List.intersperse("/", segments)) + ".flix"
                :: moduleCandidates(List.take(List.length(segments) - 1, segments))
    }
}
