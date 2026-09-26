/// JavaScript/TypeScript relative module resolution: a quoted relative
/// specifier names the admitted file behind one of the conventional source
/// suffixes, or the module `index` file inside the target directory.
pub mod World.Language.JavaScript {
    pub def javascriptImport(
        fact: Repository.Grit.Fact,
        files: Map[String, Kernel.Contract.FileId]
    ): Option[Kernel.Contract.FileId] = {
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
                    let base = World.normalizePath(World.joinPath(World.directory(fact#path), specifier));
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
}
