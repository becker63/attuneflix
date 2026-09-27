/// The single owner of directory-prefix derivation.
///
/// Repository admission builds the `parent` relation through these functions and
/// the location export reads the same functions; no other module reconstructs a
/// directory path or re-derives a parent edge. Location ids are nominal:
/// file locations `0 .. F-1` share the file id, and the sorted directory
/// prefixes `F .. F+D-1` follow, starting with the repository root `""`.
pub mod Repository.Location {
    /// Whether an admitted location is a file location or a directory prefix.
    pub enum LocationKind with Eq, ToString {
        case File
        case Directory
    }

    pub type alias Location = (Repository.Structure.LocationId, String, LocationKind)

    /// Every admitted location of a world, dense by id: the file locations in
    /// file order, then the sorted directory prefixes, root first.
    pub def locations(world: Repository.World): Vector[Location] = {
        let files = Vector.mapWithIndex((index, path) ->
            (Repository.Structure.LocationId.LocationId(index), path, LocationKind.File),
            world#files);
        let offset = Vector.length(world#files);
        let dirs = Vector.mapWithIndex((index, path) ->
            (Repository.Structure.LocationId.LocationId(offset + index), path, LocationKind.Directory),
            directories(world));
        Vector.append(files, dirs)
    }

    /// The sorted directory prefixes of the admitted file paths, root first.
    pub def directories(world: Repository.World): Vector[String] = directoryPrefixes(world#files)

    /// The `parent` relation admitted for a file path list: every file to its
    /// directory and every non-root directory to its parent directory.
    pub def parentEdges(paths: Vector[String]): Repository.Structure.Parents = {
        let directories0 = directoryPrefixes(paths);
        let offset = Vector.length(paths);
        let identities = Vector.mapWithIndex(
            (index, path) -> (path, Repository.Structure.LocationId.LocationId(offset + index)),
            directories0
        ) |> Vector.toMap;
        let fileParents = Vector.mapWithIndex((index, path) ->
            (Repository.Structure.LocationId.LocationId(index), Option.getWithDefault(
                Repository.Structure.LocationId.LocationId(0),
                Map.get(directory(path), identities)
            )), paths);
        let directoryParents = Vector.filterMap(path ->
            if (path == "") None
            else forM (
                child <- Map.get(path, identities);
                parent <- Map.get(directory(path), identities)
            ) yield (child, parent),
            directories0);
        Vector.append(fileParents, directoryParents) |> Vector.toSet
    }

    def directoryPrefixes(paths: Vector[String]): Vector[String] =
        Vector.foldLeft((known, path) -> Set.union(known, prefixesOf(directory(path))),
            Set.singleton(""), paths)
            |> Set.toVector
            |> Vector.sort

    def prefixesOf(path: String): Set[String] =
        prefixes(String.splitOn(substr = "/", path), "", Set.singleton(""))

    def prefixes(parts: List[String], current: String, result: Set[String]): Set[String] = match parts {
        case Nil => result
        case "" :: rest => prefixes(rest, current, result)
        case part :: rest =>
            let next = if (current == "") part else current + "/" + part;
            prefixes(rest, next, Set.insert(next, result))
    }

    /// The containing directory of an admitted path ("" for a top-level path).
    pub def directory(path: String): String = match String.indexOfRight(substr = "/", path) {
        case None => ""
        case Some(index) => String.sliceLeft(end = index, path)
    }
}
