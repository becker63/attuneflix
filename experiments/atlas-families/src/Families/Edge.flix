/// Family-level edges of one clustered world (`atlas-families-v1`): every
/// exact `imports` edge (file grain) and `calls` edge (symbol grain) of the
/// admitted world is one contribution, attributed to the families of its two
/// endpoints, and the attributed contributions aggregate into one family edge
/// per relation and ordered family pair, with their count as multiplicity.
///
/// A symbol's family is its member row. A file's family is its dominant file
/// rollup; a file that defines no callable has no family, so an import that
/// touches one stays an unattributed contribution and no edge is invented for
/// it. Intra-family edges (source family = target family) are family edges
/// like any other.
pub mod Families.Edge {
    use Repository.Structure.{FileId, SymbolId}

    pub type alias Edge = {
        relation       = String,
        edge           = Int32,
        sourceFamily   = Int32,
        sourceFamilyId = String,
        targetFamily   = Int32,
        targetFamilyId = String,
        multiplicity   = Int32
    }

    /// One exact world edge and the family edge it contributes to, if both
    /// endpoints have a family.
    pub type alias Contribution = {
        relation     = String,
        sourceId     = Int32,
        targetId     = Int32,
        sourceFamily = Option[Int32],
        targetFamily = Option[Int32],
        edge         = Option[Int32]
    }

    pub type alias Aggregation = {
        snapshotId    = String,
        edges         = Vector[Edge],
        contributions = Vector[Contribution]
    }

    pub def imports(): String = "imports"

    pub def calls(): String = "calls"

    /// The aggregated relations in table order, each with its endpoint domain
    /// (the grain it is aggregated at).
    pub def relations(): Vector[(String, String)] = Vector#{(imports(), "file"), (calls(), "symbol")}

    pub def domain(relation: String): Option[String] =
        Vector.find(match (name, _) -> name == relation, relations()) |> Option.map(snd)

    def rank(relation: String): Int32 =
        Vector.findIndexOf(match (name, _) -> name == relation, relations()) |> Option.getWithDefault(-1)

    /// The exact edges of one relation as `(source, target)` ids, ascending.
    pub def exact(world: Repository.World, relation: String): Vector[(Int32, Int32)] =
        if (relation == imports())
            Set.toVector(world#imports) |> Vector.map(match (FileId.FileId(s), FileId.FileId(t)) -> (s, t))
        else if (relation == calls())
            Set.toVector(world#calls) |> Vector.map(match (SymbolId.SymbolId(s), SymbolId.SymbolId(t)) -> (s, t))
        else Vector.empty()

    /// The family of every entity of one domain that has one: members at
    /// symbol grain, dominant file rollups at file grain.
    pub def endpointFamilies(clustering: Families.Cluster.Clustering, domain0: String): Map[Int32, Int32] =
        if (domain0 == Families.Cluster.Table.memberDomain())
            Vector.map(member -> (member#entityId, member#family), clustering#members) |> Vector.toMap
        else
            Vector.filter(rollup -> rollup#level == Families.Rollup.fileLevel() and rollup#dominant, clustering#rollups)
                |> Vector.map(rollup -> (rollup#locationId, rollup#family)) |> Vector.toMap

    /// The aggregation of one world under its clustering: family edges ordered
    /// by relation, source family, and target family, and one contribution per
    /// exact edge in relation and edge order.
    pub def aggregate(world: Repository.World, clustering: Families.Cluster.Clustering): Aggregation = {
        let familyIds = Vector.map(family -> (family#family, family#familyId), clustering#families) |> Vector.toMap;
        let attributed = Vector.flatMap(match (relation, domain0) -> {
            let families = endpointFamilies(clustering, domain0);
            Vector.map(match (source, target) ->
                (relation, source, target, Map.get(source, families), Map.get(target, families)), exact(world, relation))
        }, relations());
        let pairOf = entry -> match entry {
            case (relation, _, _, Some(s), Some(t)) => Some((rank(relation), s, t))
            case _ => None
        };
        let counts = Vector.filterMap(pairOf, attributed)
            |> Vector.foldLeft((known, pair) -> Map.insertWith((a, b) -> a + b, pair, 1, known), Map.empty());
        let ordinals = Map.toVector(counts) |> Vector.mapWithIndex((index, entry) -> (fst(entry), index)) |> Vector.toMap;
        let edges = Map.toVector(counts) |> Vector.mapWithIndex((index, entry) -> {
            let ((r, s, t), multiplicity) = entry;
            {
                relation = Vector.get(r, relations()) |> fst, edge = index,
                sourceFamily = s, sourceFamilyId = Map.getWithDefault(s, "", familyIds),
                targetFamily = t, targetFamilyId = Map.getWithDefault(t, "", familyIds),
                multiplicity = multiplicity
            }
        });
        let contributions = Vector.map(entry -> {
            let (relation, source, target, s, t) = entry;
            {
                relation = relation, sourceId = source, targetId = target, sourceFamily = s, targetFamily = t,
                edge = pairOf(entry) |> Option.flatMap(pair -> Map.get(pair, ordinals))
            }
        }, attributed);
        {snapshotId = clustering#snapshotId, edges = edges, contributions = contributions}
    }
}
