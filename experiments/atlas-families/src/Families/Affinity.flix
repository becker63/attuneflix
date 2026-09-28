/// The families affinity substrate: how strongly one admitted symbol belongs
/// with the other members of a candidate family.
///
/// Both sources are exact recorded evidence. The structural source reads only
/// the admitted six-atom basis (defining files, call edges, import edges) and
/// the admitted directory prefixes; the semantic source reads only the recorded
/// embedding vectors. Each component is a mean over the candidate's other
/// members, so candidates of different sizes compare on one scale, and every
/// sum runs in a fixed order so the result is bit-identical on every run.
pub mod Families.Affinity {
    import java.lang.Math

    use Repository.Structure.{FileId, SymbolId}

    /// Per-world indexes, all keyed by admitted ordinals. `vectors` holds one
    /// recorded vector per symbol, in symbol order, and `norms` its length.
    pub type alias Substrate = {
        fileOf      = Vector[Int32],
        directoryOf = Vector[String],
        calls       = Map[Int32, Set[Int32]],
        imports     = Map[Int32, Set[Int32]],
        vectors     = Vector[Vector[Float32]],
        norms       = Vector[Float64]
    }

    /// One candidate family as the substrate sees it: its members, their
    /// counts per file and per directory, and the sum of their unit vectors.
    pub type alias Profile = {
        members     = Set[Int32],
        size        = Int32,
        byFile      = Map[Int32, Int32],
        byDirectory = Map[String, Int32],
        centroid    = Vector[Float64]
    }

    /// The five per-pair indicators, each averaged over the other members.
    pub type alias Components = {
        sameFile  = Float64,
        calls     = Float64,
        imports   = Float64,
        directory = Float64,
        semantic  = Float64
    }

    /// The substrate of one world. Every symbol must have exactly one
    /// defining file and exactly one recorded vector.
    pub def substrate(world: Repository.World, vectors: Vector[Vector[Float32]]): Result[String, Substrate] \ IO = {
        let defining = Set.toVector(world#defines) |> Vector.foldLeft((known, pair) -> {
            let (FileId.FileId(file), SymbolId.SymbolId(symbol)) = pair;
            Map.insertWith(Set.union, symbol, Set#{file}, known)
        }, Map.empty());
        let symbols = Vector.length(world#symbols);
        let fileOf = Vector.traverse(symbol -> match Map.get(symbol, defining) {
            case Some(files) if Set.size(files) == 1 => Ok(Set.toVector(files) |> Vector.get(0))
            case _ => Err("symbol ${symbol} does not have exactly one defining file")
        }, Vector.range(0, symbols));
        if (Vector.length(vectors) != symbols) Err("the world has ${symbols} symbols but ${Vector.length(vectors)} recorded vectors")
        else fileOf |> Result.map(files -> {
            fileOf = files,
            directoryOf = Vector.map(Repository.Location.directory, world#files),
            calls = adjacency(Set.toVector(world#calls) |> Vector.map(match (SymbolId.SymbolId(a), SymbolId.SymbolId(b)) -> (a, b))),
            imports = adjacency(Set.toVector(world#imports) |> Vector.map(match (FileId.FileId(a), FileId.FileId(b)) -> (a, b))),
            vectors = vectors,
            norms = Vector.map(vector -> Math.sqrt(dot32(vector, vector)), vectors)
        })
    }

    /// Undirected adjacency without self loops: an edge in either direction
    /// makes two distinct endpoints adjacent.
    def adjacency(edges: Vector[(Int32, Int32)]): Map[Int32, Set[Int32]] =
        Vector.foldLeft((known, edge) -> {
            let (a, b) = edge;
            if (a == b) known
            else Map.insertWith(Set.union, a, Set#{b}, Map.insertWith(Set.union, b, Set#{a}, known))
        }, Map.empty(), edges)

    /// The profile of a candidate given its members in ascending order.
    pub def profile(substrate: Substrate, members: Vector[Int32]): Profile = {
        let byFile = Vector.foldLeft((known, symbol) ->
            Map.insertWith((a, b) -> a + b, Vector.get(symbol, substrate#fileOf), 1, known), Map.empty(), members);
        let byDirectory = Map.foldLeftWithKey((known, file, count) ->
            Map.insertWith((a, b) -> a + b, Vector.get(file, substrate#directoryOf), count, known), Map.empty(), byFile);
        {
            members = Vector.toSet(members),
            size = Vector.length(members),
            byFile = byFile,
            byDirectory = byDirectory,
            centroid = centroid(substrate, members)
        }
    }

    /// The sum of the members' unit vectors, accumulated in member order.
    def centroid(substrate: Substrate, members: Vector[Int32]): Vector[Float64] = region rc {
        let dimension = Vector.head(substrate#vectors) |> Option.map(Vector.length) |> Option.getWithDefault(0);
        let sum = Array.repeat(rc, dimension, 0.0);
        Vector.forEach(symbol -> {
            let vector = Vector.get(symbol, substrate#vectors);
            let norm = Vector.get(symbol, substrate#norms);
            if (norm > 0.0 and Vector.length(vector) == dimension)
                Vector.forEachWithIndex((index, value) ->
                    Array.put(Array.get(index, sum) + Float32.toFloat64(value) / norm, index, sum), vector)
            else ()
        }, members);
        Array.toVector(sum)
    }

    /// The components of one symbol against one candidate. A symbol that is
    /// itself a member is compared with the other members only; a candidate
    /// with no other member contributes nothing.
    pub def components(substrate: Substrate, profile: Profile, symbol: Int32): Components = {
        let inside = if (Set.memberOf(symbol, profile#members)) 1 else 0;
        let others = profile#size - inside;
        if (others <= 0) zero()
        else {
            let file = Vector.get(symbol, substrate#fileOf);
            let inFile = key -> Map.getWithDefault(key, 0, profile#byFile);
            let neighbours = (index, key) -> Map.getWithDefault(key, Set.empty(), index);
            let mean = n -> Int32.toFloat64(n) / Int32.toFloat64(others);
            {
                sameFile = mean(inFile(file) - inside),
                calls = mean(Set.count(member -> Set.memberOf(member, profile#members), neighbours(substrate#calls, symbol))),
                imports = mean(Set.foldLeft((sum, other) -> sum + inFile(other), 0, neighbours(substrate#imports, file))),
                directory = mean(Map.getWithDefault(Vector.get(file, substrate#directoryOf), 0, profile#byDirectory) - inside),
                semantic = semantic(substrate, profile, symbol, inside) / Int32.toFloat64(others)
            }
        }
    }

    /// The summed cosine similarity to the other members: the unit vector's
    /// dot product with the candidate's centroid, less its own contribution.
    def semantic(substrate: Substrate, profile: Profile, symbol: Int32, inside: Int32): Float64 = {
        let vector = Vector.get(symbol, substrate#vectors);
        let norm = Vector.get(symbol, substrate#norms);
        if (norm <= 0.0 or Vector.length(vector) != Vector.length(profile#centroid)) 0.0
        else {
            let unit = Vector.map(value -> Float32.toFloat64(value) / norm, vector);
            let total = dot64(unit, profile#centroid);
            if (inside == 1) total - dot64(unit, unit) else total
        }
    }

    pub def zero(): Components = {sameFile = 0.0, calls = 0.0, imports = 0.0, directory = 0.0, semantic = 0.0}

    pub def structural(weights: Families.Method.Weights, value: Components): Float64 =
        weights#sameFile * value#sameFile + weights#calls * value#calls +
        weights#imports * value#imports + weights#directory * value#directory

    pub def weightedSemantic(weights: Families.Method.Weights, value: Components): Float64 =
        weights#semantic * value#semantic

    pub def affinity(weights: Families.Method.Weights, value: Components): Float64 =
        structural(weights, value) + weightedSemantic(weights, value)

    def dot32(a: Vector[Float32], b: Vector[Float32]): Float64 =
        Vector.foldLeft2((sum, x, y) -> sum + Float32.toFloat64(x) * Float32.toFloat64(y), 0.0, a, b)

    def dot64(a: Vector[Float64], b: Vector[Float64]): Float64 =
        Vector.foldLeft2((sum, x, y) -> sum + x * y, 0.0, a, b)
}
