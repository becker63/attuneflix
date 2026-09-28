/// Law tests for the family-edge aggregation and export over the nested
/// three-file world, extended with one file that defines no callable: every
/// exact edge is one contribution, attributed edges aggregate per family pair
/// with their count as multiplicity, an import touching a file without a
/// family stays unattributed, the edge laws accept the aggregation and reject
/// invented or miscounted edges, and the tables round-trip exactly.
mod EdgeTest {
    use FamiliesTest.{file, fullCalls, identity, nestedWorld}
    use ScientificTable.Value

    /// The nested world plus `docs/notes.ts`, which defines nothing and imports `index.ts`.
    def world(): Repository.World = {
        let base = nestedWorld(fullCalls());
        let files = Vector.append(base#files, Vector#{"docs/notes.ts"});
        {files = files, imports = Set.insert((file(3), file(0)), base#imports),
         parents = Repository.Location.parentEdges(files) | base}
    }

    /// Family 0 holds `main`; family 1 holds `alpha` and `beta`.
    def clustering(): Families.Cluster.Clustering = {
        let family = (index, id, name, members) -> {
            family = index, familyId = id, name = name, nameKind = "file", named = false, seed = index,
            nameDecision = None, seedFiles = Vector#{name}, route = Vector.empty(), stateId = "state",
            members = members, files = members
        };
        let member = (index, id, symbol) -> {
            let value = Vector.get(symbol, world()#symbols);
            {
                family = index, familyId = id, entityId = symbol, path = value#path, name = value#name,
                startByte = value#startByte, endByte = value#endByte, candidates = 1,
                affinity = 1.0, structural = 1.0, semantic = 0.0
            }
        };
        let assignments = Vector#{(0, 0, "f0"), (1, 1, "f1"), (2, 1, "f1")};
        {
            snapshotId = "snapshot",
            families = Vector#{family(0, "f0", "index.ts", 1), family(1, "f1", "src/a.ts", 2)},
            members = Vector.map(match (symbol, index, id) -> member(index, id, symbol), assignments),
            rollups = Families.Rollup.rollups(world(), assignments)
        }
    }

    def aggregation(): Families.Edge.Aggregation = Families.Edge.aggregate(world(), clustering())

    def subject(recorded: Families.Edge.Aggregation): Families.Edge.Law.Subject = {
        world = world(),
        relations = Repository.Table.rows(identity("snapshot", "owner/nested"), world())#relations,
        clustering = clustering(),
        recorded = recorded
    }

    def failing(recorded: Families.Edge.Aggregation): Vector[String] =
        Families.Edge.Law.laws(subject(recorded)) |> Vector.filterMap(match (name, result) ->
            if (Result.isErr(result)) Some(name) else None)

    @Test
    def everyExactEdgeIsOneContributionAggregatedPerFamilyPair(): Unit \ Assert = {
        let value = aggregation();
        Assert.assertEq(expected = Vector#{
            ("imports", 0, 0, 1, 1), ("imports", 1, 1, 1, 1), ("calls", 2, 0, 1, 1), ("calls", 3, 1, 1, 2)
        }, Vector.map(edge -> (edge#relation, edge#edge, edge#sourceFamily, edge#targetFamily, edge#multiplicity), value#edges));
        Assert.assertEq(expected = Vector#{
            ("imports", 0, 1, Some(0)), ("imports", 1, 2, Some(1)), ("imports", 3, 0, None),
            ("calls", 0, 1, Some(2)), ("calls", 1, 2, Some(3)), ("calls", 2, 2, Some(3))
        }, Vector.map(c -> (c#relation, c#sourceId, c#targetId, c#edge), value#contributions));
        Assert.assertEq(expected = Vector#{"f0", "f1", "f0", "f1"}, Vector.map(edge -> edge#sourceFamilyId, value#edges))
    }

    @Test
    def anImportTouchingAFileWithoutFamilyStaysUnattributed(): Unit \ Assert = {
        let unattributed = Vector.filter(c -> Option.isEmpty(c#edge), aggregation()#contributions);
        Assert.assertEq(expected = Vector#{(3, 0, None, Some(0))},
            Vector.map(c -> (c#sourceId, c#targetId, c#sourceFamily, c#targetFamily), unattributed))
    }

    @Test
    def theEdgeLawsHoldForTheAggregation(): Unit \ Assert =
        Assert.assertEq(expected = Vector.empty(), failing(aggregation()))

    @Test
    def theEdgeLawsRejectInventedAndMiscountedEdges(): Unit \ Assert = {
        let value = aggregation();
        let invented = {contributions = Vector.append(value#contributions, Vector#{{
            relation = "calls", sourceId = 2, targetId = 0, sourceFamily = Some(1), targetFamily = Some(0), edge = Some(3)
        }}) | value};
        Assert.assertTrue(Vector.memberOf("no-invention", failing(invented)));
        Assert.assertTrue(Vector.memberOf("provenance", failing(invented)));
        let miscounted = {edges = Vector.map(edge -> if (edge#edge == 3) {multiplicity = 3 | edge} else edge, value#edges) | value};
        Assert.assertTrue(Vector.memberOf("multiplicity", failing(miscounted)));
        let misattributed = {contributions = Vector.map(c ->
            if (c#sourceId == 3) {sourceFamily = Some(1) | c} else c, value#contributions) | value};
        Assert.assertTrue(Vector.memberOf("attribution", failing(misattributed)));
        let dropped = {contributions = Vector.filter(c -> c#sourceId != 3, value#contributions) | value};
        Assert.assertTrue(Vector.memberOf("no-invention", failing(dropped)))
    }

    def rowsOf(value: Families.Edge.Aggregation): Vector[Vector[ScientificTable.Row]] =
        Vector.map(match (_, _, _, rows) -> rows, Families.Edge.Table.layout(value))

    def decoded(rows: Vector[Vector[ScientificTable.Row]]): Result[String, Families.Edge.Aggregation] =
        Families.Edge.Table.decode("snapshot", Vector.get(0, rows), Vector.get(1, rows))

    @Test
    def edgeTablesRoundTripAndRejectForeignOrMalformedRows(): Unit \ Assert = {
        let rows = rowsOf(aggregation());
        Assert.assertEq(expected = Ok(rows), decoded(rows) |> Result.map(rowsOf));
        Assert.assertEq(expected = Vector#{"attune-atlas-family-edges-v1", "attune-atlas-family-edge-contributions-v1"},
            Vector.map(match (_, _, schema, _) -> schema#format, Families.Edge.Table.layout(aggregation())));
        let edit = (table, column, value) -> Vector.update(table,
            Vector.map(Map.insert(column, value), Vector.get(table, rows)), rows);
        Assert.assertTrue(Result.isErr(decoded(edit(0, "protocol", Value.Text("attune-atlas-family-edges-v0")))));
        Assert.assertTrue(Result.isErr(decoded(edit(0, "grain", Value.Text("directory")))));
        Assert.assertTrue(Result.isErr(decoded(edit(0, "edge", Value.Int32(7)))));
        Assert.assertTrue(Result.isErr(decoded(edit(1, "relation", Value.Text("parent")))));
        Assert.assertTrue(Result.isErr(decoded(edit(1, "snapshot_id", Value.Text("other")))))
    }

    @Test
    def theExportShipsEveryTableUnderItsDataTreeName(): Unit \ Assert =
        Assert.assertEq(expected = Vector#{
            ("families", "families.parquet"), ("members", "family_members.parquet"), ("rollups", "family_rollups.parquet"),
            ("edges", "family_edges.parquet"), ("contributions", "family_contributions.parquet")
        }, Vector.map(match (table, file, _, _) -> (table, file), Families.Export.layout(clustering(), aggregation())))
}
