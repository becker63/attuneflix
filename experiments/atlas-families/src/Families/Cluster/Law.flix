/// The laws of one clustered world, checked over the built `atlas-families-v1`
/// tables, the frozen world tables, and the recorded evidence. Each law is a
/// named result so a failing run reports every broken law at once.
pub mod Families.Cluster.Law {
    use ScientificTable.Value

    /// Everything the laws read for one world. `recorded` is the clustering
    /// decoded from the built tables and `rerun` from the independently built
    /// second run; `entities` are the frozen world entity rows as stored.
    pub type alias Subject = {
        world     = Repository.World,
        entities  = Vector[ScientificTable.Row],
        evidence  = Families.Cluster.Evidence,
        recorded  = Families.Cluster.Clustering,
        rerun     = Families.Cluster.Clustering,
        recomputed = Families.Cluster.Clustering
    }

    pub def laws(subject: Subject): Vector[(String, Result[String, Unit])] \ IO = Vector#{
        ("determinism", determinism(subject)),
        ("no-invention", noInvention(subject)),
        ("provenance", provenance(subject)),
        ("identity", identity(subject)),
        ("naming", naming(subject)),
        ("rollup", rollup(subject)),
        ("both-sources", bothSources(subject))
    }

    def rowsOf(value: Families.Cluster.Clustering): Vector[Vector[ScientificTable.Row]] =
        Vector.map(match (_, _, _, rows) -> rows, Families.Cluster.Table.layout(value))

    def check(condition: Bool, message: String): Result[String, Unit] = if (condition) Ok(()) else Err(message)

    def all(checks: Vector[Result[String, Unit]]): Result[String, Unit] =
        Vector.traverse(x -> x, checks) |> Result.map(_ -> ())

    /// The independently built rerun and a fresh in-process recomputation from
    /// the recorded evidence both equal the recorded tables row for row.
    def determinism(subject: Subject): Result[String, Unit] = all(Vector#{
        check(rowsOf(subject#rerun) == rowsOf(subject#recorded), "the rerun tables differ from the recorded tables"),
        check(rowsOf(subject#recomputed) == rowsOf(subject#recorded), "recomputation differs from the recorded tables")
    })

    /// Every member is an exact admitted symbol, every symbol is a member of
    /// exactly one family, and every member names an existing family.
    def noInvention(subject: Subject): Result[String, Unit] = {
        let symbols = subject#world#symbols;
        let families = subject#recorded#families;
        let members = subject#recorded#members;
        all(Vector.append(Vector#{
            check(Vector.map(member -> member#entityId, members) |> Vector.sort == Vector.range(0, Vector.length(symbols)),
                "members are not exactly the world's symbols, each once"),
            check(Vector.forAll(family -> family#members == Vector.count(member -> member#family == family#family, members), families),
                "a family's member count differs from its member rows")
        }, Vector.map(member -> match (Vector.nth(member#entityId, symbols), Vector.nth(member#family, families)) {
            case (Some(symbol), Some(family)) => check(
                symbol#path == member#path and symbol#name == member#name and
                symbol#startByte == member#startByte and symbol#endByte == member#endByte and family#familyId == member#familyId,
                "member ${member#entityId} is not its admitted symbol or family")
            case _ => Err("member ${member#entityId} names no admitted symbol or family")
        }, members)))
    }

    /// Every member row joins exactly one row of the frozen world entities
    /// table on snapshot, domain, id, path, name, and span; every family's
    /// seed files are admitted file rows.
    def provenance(subject: Subject): Result[String, Unit] = {
        let snapshot = subject#recorded#snapshotId;
        let entityKey = row -> (Result.toOption(ScientificTable.text(row, "snapshot_id")),
            Result.toOption(ScientificTable.text(row, "domain")), Result.toOption(ScientificTable.int32(row, "entity_id")));
        let index = Vector.foldLeft((known, row) ->
            Map.insertWith((later, earlier) -> Vector.append(earlier, later), entityKey(row), Vector#{row}, known),
            Map.empty(), subject#entities);
        let files = Vector.filter(row -> ScientificTable.text(row, "domain") == Ok("file"), subject#entities)
            |> Vector.filterMap(row -> Result.toOption(ScientificTable.text(row, "path"))) |> Vector.toSet;
        all(Vector.append(Vector.map(member -> {
            let key = (Some(snapshot), Some(Families.Cluster.Table.memberDomain()), Some(member#entityId));
            match Map.getWithDefault(key, Vector.empty(), index) {
                case rows if Vector.length(rows) == 1 => {
                    let row = Vector.get(0, rows);
                    check(Map.get("path", row) == Some(Value.Text(member#path)) and Map.get("name", row) == Some(Value.Text(member#name)) and
                        Map.get("start_byte", row) == Some(Value.Int32(member#startByte)) and Map.get("end_byte", row) == Some(Value.Int32(member#endByte)),
                        "member ${member#entityId} differs from its world entity row")
                }
                case _ => Err("member ${member#entityId} does not resolve to exactly one world entity row")
            }
        }, subject#recorded#members), Vector.map(family ->
            check(Vector.forAll(path -> Set.memberOf(path, files), family#seedFiles),
                "family ${family#family} names a seed file that is not a world file row"),
            subject#recorded#families)))
    }

    /// Every family identity is the content-derived identity of its members.
    def identity(subject: Subject): Result[String, Unit] \ IO =
        all(Vector.map(family -> {
            let ids = Vector.filter(member -> member#family == family#family, subject#recorded#members) |> Vector.map(member -> member#entityId);
            check(Families.Cluster.identity(subject#recorded#snapshotId, ids) == family#familyId,
                "family ${family#family} identity is not derived from its members")
        }, subject#recorded#families))

    /// Every family's name is its seed's recorded name, admitted by the
    /// protocol: the recorded naming choice, or the only candidate location.
    def naming(subject: Subject): Result[String, Unit] =
        all(Vector.map(family -> match Vector.nth(family#seed, subject#evidence#outcomes) {
            case None => Err("family ${family#family} names no recorded seed")
            case Some(outcome) => forM (
                _ <- check(outcome#name == family#name and outcome#nameKind == family#nameKind and outcome#named == family#named and
                    outcome#stateId == family#stateId and outcome#route == family#route,
                    "family ${family#family} does not carry its seed's recorded outcome");
                terminal <- Families.Cluster.frontier(subject#world, outcome);
                decision <- Families.Cluster.nameProvenance(subject#world, subject#evidence#decisions, outcome, terminal);
                _ <- check(decision == family#nameDecision, "family ${family#family} name decision is not the recorded one");
                _ <- check(Option.forAll(id -> Vector.exists(entry -> entry#observation#identity == id and
                        entry#question == Families.Protocol.namingQuestion(), subject#evidence#decisions), family#nameDecision),
                    "family ${family#family} name decision is not a recorded naming decision")
            ) yield ()
        }, subject#recorded#families))

    /// The rollup is the pure recomputation from the member table and the
    /// world; each location's family counts sum to its members and exactly
    /// one family dominates it.
    def rollup(subject: Subject): Result[String, Unit] = {
        let recorded = subject#recorded;
        let recomputed = Families.Rollup.rollups(subject#world,
            Vector.map(member -> (member#entityId, member#family, member#familyId), recorded#members));
        let rows = Vector.map(Families.Cluster.Table.rollupRow(recorded#snapshotId));
        let byLocation = Vector.foldLeft((known, value) ->
            Map.insertWith((later, earlier) -> Vector.append(earlier, later), (value#level, value#locationId), Vector#{value}, known),
            Map.empty(), recorded#rollups);
        all(Vector.append(Vector#{
            check(rows(recomputed) == rows(recorded#rollups), "the rollup differs from its recomputation from the member table")
        }, Map.toVector(byLocation) |> Vector.map(match ((level, id), values) -> check(
            Vector.foldLeft((sum, value) -> sum + value#members, 0, values) ==
                (Vector.head(values) |> Option.map(value -> value#locationMembers) |> Option.getWithDefault(-1)) and
            Vector.count(value -> value#dominant, values) == 1,
            "${level} location ${id} rollup does not sum to its members with one dominant family"))))
    }

    /// Both sources carry positive protocol weight and both contribute to the
    /// recorded affinities.
    def bothSources(subject: Subject): Result[String, Unit] = {
        let weights = Families.Method.weights();
        let members = subject#recorded#members;
        all(Vector#{
            check(Vector.forAll(match (_, weight) -> weight > 0.0, Families.Method.weightRows(weights)),
                "a protocol affinity weight is not positive"),
            check(Vector.exists(member -> member#structural > 0.0, members), "no member has a structural affinity"),
            check(Vector.exists(member -> member#semantic != 0.0, members), "no member has a semantic affinity"),
            check(Vector.map(member -> member#semantic, members) |> Vector.toSet |> Set.size > 1,
                "the semantic affinity is constant, so the recorded vectors carry no signal"),
            check(Vector.forAll(member -> member#affinity == member#structural + member#semantic, members),
                "a member affinity is not the sum of its two sources")
        })
    }
}
