/// Java type resolution: a dotted type reference names its source file. The
/// package path is tried first, then the bare type file as a conservative
/// fallback.
pub mod World.Language.Java {
    pub def dottedFile(
        value: String,
        files: Map[String, Kernel.Contract.FileId],
        suffix: String
    ): Option[Kernel.Contract.FileId] =
        match World.Language.dottedName(value) {
            case None       => None
            case Some(name) =>
                let segments = String.splitOn(substr = ".", name);
                let full = String.flatten(List.intersperse("/", segments)) + suffix;
                let last = match List.reverse(segments) {
                    case head :: _ => head + suffix
                    case Nil       => full
                };
                World.Language.firstResolved(files, full :: last :: Nil)
        }
}
