/// The laws of one world's family-edge tables, checked against the frozen
/// world tables and the clustering they aggregate. Each law is a named result
/// so a failing run reports every broken law at once.
pub mod Families.Edge.Law {
    /// Everything the laws read for one world. `relations` are the frozen
    /// world relation rows as stored; `recorded` is the aggregation decoded
    /// from the tables under test.
    pub type alias Subject = {
        world      = Repository.World,
        relations  = Vector[ScientificTable.Row],
        clustering = Families.Cluster.Clustering,
        recorded   = Families.Edge.Aggregation
    }

    pub def laws(subject: Subject): Vector[(String, Result[String, Unit])] = Vector#{
        ("determinism", determinism(subject)),
        ("no-invention", noInvention(subject)),
        ("provenance", provenance(subject)),
        ("attribution", attribution(subject)),
        ("multiplicity", multiplicity(subject))
    }

    def check(condition: Bool, message: String): Result[String, Unit] = if (condition) Ok(()) else Err(message)

    def all(checks: Vector[Result[String, Unit]]): Result[String, Unit] =
        Vector.traverse(x -> x, checks) |> Result.map(_ -> ())

    def rowsOf(value: Families.Edge.Aggregation): Vector[Vector[ScientificTable.Row]] =
        Vector.map(match (_, _, _, rows) -> rows, Families.Edge.Table.layout(value))

    def ofRelation(relation: String, values: Vector[Families.Edge.Contribution]): Vector[Families.Edge.Contribution] =
        Vector.filter(value -> value#relation == relation, values)

    /// A fresh aggregation of the world under the clustering equals the
    /// recorded tables row for row.
    def determinism(subject: Subject): Result[String, Unit] =
        check(rowsOf(Families.Edge.aggregate(subject#world, subject#clustering)) == rowsOf(subject#recorded),
            "the aggregation of the world under its clustering differs from the recorded tables")

    /// The contributions of each relation are exactly the world's exact
    /// edges, each once and in edge order, and nothing else; every family
    /// pair has at most one edge per relation.
    def noInvention(subject: Subject): Result[String, Unit] = {
        let recorded = subject#recorded;
        all(Vector.append(Vector#{
            check(Vector.forAll(value -> not Option.isEmpty(Families.Edge.domain(value#relation)), recorded#contributions),
                "a contribution names a relation that is not aggregated"),
            check(Vector.map(edge -> (edge#relation, edge#sourceFamily, edge#targetFamily), recorded#edges) |> Vector.toSet |> Set.size
                == Vector.length(recorded#edges), "a family pair has more than one edge of the same relation")
        }, Vector.map(match (relation, _) -> check(
            Vector.map(value -> (value#sourceId, value#targetId), ofRelation(relation, recorded#contributions))
                == Families.Edge.exact(subject#world, relation),
            "the ${relation} contributions are not exactly the world's ${relation} edges"), Families.Edge.relations())))
    }

    /// Every contribution joins exactly one row of the frozen world relations
    /// table on snapshot, relation, both domains, and both ids.
    def provenance(subject: Subject): Result[String, Unit] = {
        let text = (row, name) -> Result.toOption(ScientificTable.text(row, name));
        let id = (row, name) -> Result.toOption(ScientificTable.int32(row, name));
        let key = row -> (text(row, "snapshot_id"), text(row, "relation"), text(row, "source_domain"),
            id(row, "source_id"), text(row, "target_domain"), id(row, "target_id"));
        let index = Vector.foldLeft((known, row) -> Map.insertWith((a, b) -> a + b, key(row), 1, known),
            Map.empty(), subject#relations);
        let snapshot = subject#recorded#snapshotId;
        all(Vector.map(value -> {
            let domain0 = Families.Edge.domain(value#relation);
            check(Map.get((Some(snapshot), Some(value#relation), domain0, Some(value#sourceId), domain0, Some(value#targetId)), index) == Some(1),
                "${value#relation} contribution ${value#sourceId} -> ${value#targetId} is not exactly one world relation row")
        }, subject#recorded#contributions))
    }

    /// Every endpoint carries the family the clustering gives it; only a file
    /// that defines no callable lacks one; a contribution names an edge
    /// exactly when both endpoints have a family, and that edge is the one of
    /// its relation and family pair; every edge carries its families' ids.
    def attribution(subject: Subject): Result[String, Unit] = {
        let recorded = subject#recorded;
        let defining = Set.map(match (Repository.Structure.FileId.FileId(file), _) -> file, subject#world#defines);
        let familyIds = Vector.map(family -> (family#family, family#familyId), subject#clustering#families) |> Vector.toMap;
        let families = Vector.map(match (relation, domain0) ->
            (relation, Families.Edge.endpointFamilies(subject#clustering, domain0)), Families.Edge.relations()) |> Vector.toMap;
        let familyOf = (relation, id) -> Map.get(relation, families) |> Option.flatMap(Map.get(id));
        let unfamilied = (relation, id, family) -> not Option.isEmpty(family) or
            (relation == Families.Edge.imports() and not Set.memberOf(id, defining));
        all(Vector.append(Vector.map(value -> all(Vector#{
            check(value#sourceFamily == familyOf(value#relation, value#sourceId) and
                value#targetFamily == familyOf(value#relation, value#targetId),
                "${value#relation} contribution ${value#sourceId} -> ${value#targetId} does not carry its endpoints' families"),
            check(unfamilied(value#relation, value#sourceId, value#sourceFamily) and
                unfamilied(value#relation, value#targetId, value#targetFamily),
                "${value#relation} contribution ${value#sourceId} -> ${value#targetId} has an endpoint without a family that defines callables"),
            match (value#sourceFamily, value#targetFamily, value#edge) {
                case (Some(s), Some(t), Some(e)) => check(Vector.nth(e, recorded#edges) |> Option.exists(edge ->
                    edge#relation == value#relation and edge#sourceFamily == s and edge#targetFamily == t),
                    "${value#relation} contribution ${value#sourceId} -> ${value#targetId} names another family edge")
                case (Some(_), Some(_), None) => Err("an attributed contribution names no family edge")
                case (_, _, Some(_)) => Err("an unattributed contribution names a family edge")
                case _ => Ok(())
            }
        }), recorded#contributions), Vector.map(edge -> check(
            Map.get(edge#sourceFamily, familyIds) == Some(edge#sourceFamilyId) and
            Map.get(edge#targetFamily, familyIds) == Some(edge#targetFamilyId),
            "family edge ${edge#edge} does not carry its families' identities"), recorded#edges)))
    }

    /// Every family edge's multiplicity is the count of the contributions
    /// that name it and is positive, and per relation the multiplicities plus
    /// the unattributed contributions sum to the world's exact edge count.
    def multiplicity(subject: Subject): Result[String, Unit] = {
        let recorded = subject#recorded;
        let named = Vector.filterMap(value -> value#edge, recorded#contributions)
            |> Vector.foldLeft((known, edge) -> Map.insertWith((a, b) -> a + b, edge, 1, known), Map.empty());
        all(Vector.append(Vector.map(edge -> check(
            edge#multiplicity > 0 and Map.get(edge#edge, named) == Some(edge#multiplicity),
            "family edge ${edge#edge} multiplicity ${edge#multiplicity} is not the count of its contributions"), recorded#edges),
            Vector.map(match (relation, _) -> {
                let total = Vector.sumWith(edge -> if (edge#relation == relation) edge#multiplicity else 0, recorded#edges);
                let unattributed = Vector.count(value -> Option.isEmpty(value#edge), ofRelation(relation, recorded#contributions));
                check(total + unattributed == Vector.length(Families.Edge.exact(subject#world, relation)),
                    "${relation}: multiplicities ${total} plus ${unattributed} unattributed differ from the world's edge count")
            }, Families.Edge.relations())))
    }
}
