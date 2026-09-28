/// Law tests for the families clustering method over the nested three-file
/// world: the affinity components are the exact per-pair means of both
/// sources, the weights decide between them, recorded routes replay to exact
/// frontiers, unheld symbols fall back to their seed's candidate, the rollup
/// is exact at both levels, family identity is content-derived, and the
/// typed tables round-trip exactly.
mod ClusterTest {
    use Atlas.State
    use FamiliesTest.{file, fullCalls, nestedWorld, symbol}
    use ScientificTable.Value

    /// Symbols 0 and 1 point one way, symbol 2 the orthogonal way.
    def vectors(): Vector[Vector[Float32]] = Vector#{Vector#{1.0f32, 0.0f32}, Vector#{1.0f32, 0.0f32}, Vector#{0.0f32, 1.0f32}}

    def substrate(): Families.Affinity.Substrate \ IO =
match Families.Affinity.substrate(nestedWorld(fullCalls()), vectors()) {
            case Ok(value) => value
            case Err(error) => bug!(error)
        }

    def tuple(value: Families.Affinity.Components): (Float64, Float64, Float64, Float64, Float64) =
        (value#sameFile, value#calls, value#imports, value#directory, value#semantic)

    def outcome(seed: Int32, fileId: Int32, path: String, route: Vector[String]): Families.Decision.Table.Family = {
        seed = seed, file = fileId, path = path, route = route, domain = "symbol", cardinality = 0,
        stateId = "state", name = path, nameKind = "file", named = false, decisions = 0
    }

    def candidate(ordinal: Int32, seed: Families.Decision.Table.Family, members: Vector[Int32]): Families.Cluster.Candidate =
        {ordinal = ordinal, outcomes = Vector#{seed}, outcome = seed, nameDecision = None, members = members}

    @Test
    def componentsAreExactMeansOverTheOtherMembers(): Unit \ {Assert, IO} = {
        let s = substrate();
        // Symbol 1 against {0, 2}: calls and imports reach both, no shared
        // file or directory, and cosine 1 and 0 average to one half.
        Assert.assertEq(expected = (0.0, 1.0, 1.0, 0.0, 0.5),
            tuple(Families.Affinity.components(s, Families.Affinity.profile(s, Vector#{0, 2}), 1)));
        // A member is compared with the others only: symbol 0 against {0, 1}.
        Assert.assertEq(expected = (0.0, 1.0, 1.0, 0.0, 1.0),
            tuple(Families.Affinity.components(s, Families.Affinity.profile(s, Vector#{0, 1}), 0)));
        Assert.assertEq(expected = tuple(Families.Affinity.zero()),
            tuple(Families.Affinity.components(s, Families.Affinity.profile(s, Vector#{2}), 2)))
    }

    @Test
    def substrateRequiresOneVectorPerSymbol(): Unit \ {Assert, IO} =
        Assert.assertTrue(Result.isErr(Families.Affinity.substrate(nestedWorld(fullCalls()), Vector.take(2, vectors()))))

    @Test
    def weightsDecideBetweenTheSourcesAndTiesKeepTheLeastCandidate(): Unit \ Assert = {
        let zero = Families.Affinity.zero();
        let structural = {sameFile = 1.0 | zero};
        let semantic = {semantic = 1.0 | zero};
        let options = Vector#{(0, structural), (1, semantic)};
        let chosen = weights -> Families.Cluster.strongest(weights, options) |> Option.map(fst);
        Assert.assertEq(expected = Some(0), chosen(Families.Method.weights()));
        Assert.assertEq(expected = Some(0), chosen(Families.Method.structuralOnly()));
        Assert.assertEq(expected = Some(1), chosen(Families.Method.semanticOnly()));
        Assert.assertEq(expected = (0, 1), (Families.Cluster.moved(Vector#{(2, options)}, Families.Method.structuralOnly()),
            Families.Cluster.moved(Vector#{(2, options)}, Families.Method.semanticOnly())));
        Assert.assertEq(expected = Some(3), Families.Cluster.strongest(Families.Method.weights(),
            Vector#{(3, semantic), (4, semantic)}) |> Option.map(fst))
    }

    @Test
    def everyProtocolWeightIsPositiveAndTheySumToOne(): Unit \ Assert = {
        let rows = Families.Method.weightRows(Families.Method.weights());
        Assert.assertTrue(Vector.forAll(match (_, weight) -> weight > 0.0, rows));
        Assert.assertTrue(Float64.abs(Vector.foldLeft((sum, row) -> sum + snd(row), 0.0, rows) - 1.0) < 0.000000000001)
    }

    @Test
    def recordedRoutesReplayToTheirExactFrontier(): Unit \ Assert = {
        let world = nestedWorld(fullCalls());
        let frontier = route -> Families.Cluster.frontier(world, outcome(0, 0, "index.ts", route));
        Assert.assertEq(expected = Ok(State.Files(Set#{file(0)})), frontier(Vector.empty()));
        Assert.assertEq(expected = Ok(State.Symbols(Set#{symbol(0)})), frontier(Vector#{"defines"}));
        Assert.assertEq(expected = Ok(State.Symbols(Set#{symbol(1)})), frontier(Vector#{"defines", "calls"}));
        Assert.assertTrue(Result.isErr(frontier(Vector#{"sideways"})));
        Assert.assertEq(expected = Vector#{0, 1}, Families.Cluster.symbols(world, State.Files(Set#{file(0), file(1)})))
    }

    @Test
    def unheldSymbolsFallBackToTheirSeedCandidate(): Unit \ {Assert, IO} = {
        let candidates = Vector#{
            candidate(0, outcome(0, 0, "index.ts", Vector#{"defines", "calls"}), Vector#{0, 1}),
            candidate(1, outcome(2, 2, "src/lib/b.ts", Vector#{"imported_by"}), Vector.empty())
        };
        let placed = Families.Cluster.assign(substrate(), candidates, Families.Method.weights());
        Assert.assertEq(expected = Vector#{(0, 0, 1), (1, 0, 1), (2, 1, 0)},
            Vector.map(value -> (value#symbol, value#candidate, value#candidates), placed))
    }

    @Test
    def rollupCountsEveryLocationAndTheLeastFamilyDominatesATie(): Unit \ Assert = {
        let world = nestedWorld(fullCalls());
        let view = values -> Vector.map(value ->
            (value#level, value#location, value#family, value#members, value#locationMembers, value#dominant), values);
        Assert.assertEq(expected = Vector#{
            ("file", "index.ts", 0, 1, 1, true), ("file", "src/a.ts", 1, 1, 1, true), ("file", "src/lib/b.ts", 1, 1, 1, true),
            ("directory", "", 0, 1, 3, false), ("directory", "", 1, 2, 3, true),
            ("directory", "src", 1, 2, 2, true), ("directory", "src/lib", 1, 1, 1, true)
        } |> Vector.sort, view(Families.Rollup.rollups(world, Vector#{(0, 0, "a"), (1, 1, "b"), (2, 1, "b")})) |> Vector.sort);
        let tied = Families.Rollup.rollups(world, Vector#{(0, 1, "b"), (1, 0, "a")})
            |> Vector.filter(value -> value#location == "");
        Assert.assertEq(expected = Vector#{(0, true), (1, false)}, Vector.map(value -> (value#family, value#dominant), tied));
        Assert.assertEq(expected = Vector#{"src/lib", "src", ""}, Families.Rollup.ancestors("src/lib/b.ts"));
        Assert.assertEq(expected = Vector#{""}, Families.Rollup.ancestors("index.ts"))
    }

    @Test
    def familyIdentityIsDerivedFromTheExactMembersOnly(): Unit \ {Assert, IO} = {
        let id = Families.Cluster.identity;
        Assert.assertEq(expected = id("snapshot", Vector#{0, 1, 2}), id("snapshot", Vector#{2, 0, 1}));
        Assert.assertTrue(id("snapshot", Vector#{0, 1, 2}) != id("snapshot", Vector#{0, 1}));
        Assert.assertTrue(id("snapshot", Vector#{0, 1}) != id("other", Vector#{0, 1}));
        Assert.assertTrue(String.startsWith(prefix = "atlas-families-v1:", id("snapshot", Vector#{0})))
    }

    def clustering(): Families.Cluster.Clustering = {
        snapshotId = "snapshot",
        families = Vector#{{
            family = 0, familyId = "atlas-families-v1:f", name = "src", nameKind = "directory", named = true, seed = 1,
            nameDecision = Some("decision"), seedFiles = Vector#{"src/a.ts"}, route = Vector#{"imports"},
            stateId = "state", members = 1, files = 1
        }},
        members = Vector#{{
            family = 0, familyId = "atlas-families-v1:f", entityId = 1, path = "src/a.ts", name = "alpha",
            startByte = 0, endByte = 10, candidates = 2, affinity = 0.75, structural = 0.5, semantic = 0.25
        }},
        rollups = Vector#{{
            level = "file", locationId = 1, location = "src/a.ts", family = 0, familyId = "atlas-families-v1:f",
            members = 1, locationMembers = 1, dominant = true
        }}
    }

    def rowsOf(value: Families.Cluster.Clustering): Vector[Vector[ScientificTable.Row]] =
        Vector.map(match (_, _, _, rows) -> rows, Families.Cluster.Table.layout(value))

    def decoded(rows: Vector[Vector[ScientificTable.Row]]): Result[String, Families.Cluster.Clustering] =
        Families.Cluster.Table.decode("snapshot", Vector.get(0, rows), Vector.get(1, rows), Vector.get(2, rows))

    @Test
    def clusteringTablesRoundTripTheTypedRowsExactly(): Unit \ Assert = {
        let rows = rowsOf(clustering());
        Assert.assertEq(expected = Ok(rows), decoded(rows) |> Result.map(rowsOf));
        Assert.assertEq(expected = Vector#{"attune-atlas-families-v1", "attune-atlas-families-members-v1", "attune-atlas-families-rollups-v1"},
            Vector.map(match (_, _, schema, _) -> schema#format, Families.Cluster.Table.layout(clustering())));
        Assert.assertTrue(Vector.forAll(match (_, _, schema, table) -> Vector.forAll(row ->
            Map.keysOf(row) == Vector.toSet(Vector.map(column -> column#name, schema#columns)), table),
            Families.Cluster.Table.layout(clustering())))
    }

    @Test
    def clusteringTablesRejectForeignOrMalformedRows(): Unit \ Assert = {
        let rows = rowsOf(clustering());
        let edit = (table, column, value) -> Vector.update(table,
            Vector.map(Map.insert(column, value), Vector.get(table, rows)), rows);
        Assert.assertTrue(Result.isErr(decoded(edit(1, "protocol", Value.Text("attune-atlas-families-members-v0")))));
        Assert.assertTrue(Result.isErr(decoded(edit(1, "domain", Value.Text("file")))));
        Assert.assertTrue(Result.isErr(decoded(edit(0, "family", Value.Int32(1)))));
        Assert.assertTrue(Result.isErr(decoded(edit(2, "level", Value.Text("module")))));
        Assert.assertTrue(Result.isErr(decoded(edit(0, "snapshot_id", Value.Text("other")))))
    }
}
