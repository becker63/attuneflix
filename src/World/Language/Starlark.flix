/// Starlark label resolution: a repository-relative label names a source file
/// (`//tools:defs.bzl` -> `tools/defs.bzl`). External and target-only labels
/// are conservatively rejected: they do not name an admitted file.
pub mod World.Language.Starlark {
    pub def starlarkImport(value: String, files: Map[String, Kernel.Contract.FileId]): Option[Kernel.Contract.FileId] =
        match labelPath(String.trim(value)) {
            case None       => None
            case Some(path) => World.Language.uniqueSuffix(files, path)
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
                    case None => None
                    case Some(index) =>
                        let package = String.sliceLeft(end = index, body);
                        let target = String.sliceRight(start = index + 1, body);
                        if (String.contains(substr = ".", target))
                            if (package == "") Some(target) else Some(package + "/" + target)
                        else None
                }
            }
        }
}
