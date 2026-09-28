/// Law tests for the families experiment scaffold: the acquisition inventory is
/// an exact function of the admitted world, its typed table round-trips
/// exactly and rejects foreign or malformed tables, and the report projection
/// is deterministic in declared world order.
mod FamiliesTest {
    use ScientificTable.Value

    pub def identity(snapshot: String, repository: String): Repository.Table.Identity = {
        repository = repository,
        baseRevision = "base",
        sourceTreeIdentity = "source-tree",
        factIdentity = "facts",
        snapshotId = snapshot
    }

    /// index.ts -> src/a.ts -> src/lib/b.ts, one callable per file, three
    /// directories ("", "src", "src/lib") and the admitted parent relation.
    pub def file(id: Int32): Repository.Structure.FileId = Repository.Structure.FileId.FileId(id)

    pub def symbol(id: Int32): Repository.Structure.SymbolId = Repository.Structure.SymbolId.SymbolId(id)

    pub def nestedWorld(calls: Set[(Int32, Int32)]): Repository.World = {
        let files = Vector#{"index.ts", "src/a.ts", "src/lib/b.ts"};
        {
            files = files,
            symbols = Vector#{
                {path = "index.ts", name = "main", startByte = 0, endByte = 4},
                {path = "src/a.ts", name = "alpha", startByte = 0, endByte = 10},
                {path = "src/lib/b.ts", name = "beta", startByte = 5, endByte = 25}
            },
            defines = Set#{(file(0), symbol(0)), (file(1), symbol(1)), (file(2), symbol(2))},
            imports = Set#{(file(0), file(1)), (file(1), file(2))},
            calls = Set.map(match (caller, callee) -> (symbol(caller), symbol(callee)), calls),
            parents = Repository.Location.parentEdges(files),
            unresolvedImports = 0,
            unresolvedCalls = 0
        }
    }

    pub def fullCalls(): Set[(Int32, Int32)] = Set#{(0, 1), (1, 2), (2, 2)}

    def nestedInventory(): Families.Inventory.Inventory =
        Families.Inventory.of(identity("repository-snapshot-v1:abcdef0123456789", "owner/nested"), nestedWorld(fullCalls()))

    /// Records carry no Eq instance, so laws compare the typed row projection.
    def rowOf(value: Families.Inventory.Inventory): ScientificTable.Row = Families.Inventory.Table.row(value)

    @Test
    def inventoryCountsTheAdmittedWorldExactly(): Unit \ Assert =
        Assert.assertEq(expected = rowOf({
            snapshotId = "repository-snapshot-v1:abcdef0123456789",
            repository = "owner/nested",
            files = 3, callables = 3, directories = 3, imports = 2, calls = 3,
            parents = 5, callableSourceBytes = 34i64
        }), rowOf(nestedInventory()))

    @Test
    def inventoryFollowsTheAdmittedRelationsNotConstants(): Unit \ Assert = {
        let pruned = Families.Inventory.of(identity("s", "r"), nestedWorld(Set#{(0, 1)}));
        Assert.assertEq(expected = 1, pruned#calls);
        Assert.assertEq(expected = 3, nestedInventory()#calls)
    }

    @Test
    def inventoryOfTheSharedAbWorldHasNoDirectoriesBeyondTheRoot(): Unit \ Assert = {
        let value = Families.Inventory.of(identity("s", "r"), TestWorlds.abWorld());
        Assert.assertEq(expected = (2, 2, 1, 1, 1, 2i64),
            (value#files, value#callables, value#directories, value#imports, value#calls, value#callableSourceBytes))
    }

    @Test
    def inventoryTableSchemaIsPinned(): Unit \ Assert = {
        let schema = Families.Inventory.Table.inventory();
        Assert.assertEq(expected = "attune-families-inventory-v1", schema#format);
        Assert.assertEq(expected = Vector#{
            "protocol", "snapshot_id", "repository", "files", "callables", "directories",
            "imports", "calls", "parents", "callable_source_bytes"
        }, Vector.map(column -> column#name, schema#columns));
        Assert.assertTrue(Vector.forAll(column -> not column#nullable, schema#columns))
    }

    @Test
    def inventoryTableRoundTripsExactly(): Unit \ Assert = {
        let row = rowOf(nestedInventory());
        Assert.assertEq(expected = Ok(row), Families.Inventory.Table.decode(Vector#{row}) |> Result.map(rowOf));
        Assert.assertEq(
            expected = Vector.map(column -> column#name, Families.Inventory.Table.inventory()#columns) |> Vector.toSet,
            Map.keysOf(row))
    }

    @Test
    def inventoryTableRejectsAForeignProtocol(): Unit \ Assert = {
        let row = Map.insert("protocol", Value.Text("attune-families-inventory-v0"),
            Families.Inventory.Table.row(nestedInventory()));
        Assert.assertTrue(Result.isErr(Families.Inventory.Table.decode(Vector#{row})))
    }

    @Test
    def inventoryTableRejectsAMistypedColumn(): Unit \ Assert = {
        let row = Map.insert("callable_source_bytes", Value.Int32(34),
            Families.Inventory.Table.row(nestedInventory()));
        Assert.assertTrue(Result.isErr(Families.Inventory.Table.decode(Vector#{row})))
    }

    @Test
    def inventoryTableHoldsExactlyOneWorld(): Unit \ Assert = {
        let row = Families.Inventory.Table.row(nestedInventory());
        Assert.assertTrue(Result.isErr(Families.Inventory.Table.decode(Vector.empty())));
        Assert.assertTrue(Result.isErr(Families.Inventory.Table.decode(Vector#{row, row})))
    }

    @Test
    def reportRendersDeclaredOrderAndTotals(): Unit \ Assert = {
        let small = Families.Inventory.of(
            identity("repository-snapshot-v1:0123456789abcdef", "owner/small"), TestWorlds.abWorld());
        Assert.assertEq(expected = Vector.join("\n", Vector#{
            "| repository | snapshot | files | callables | directories | imports | calls | parents | callable source bytes |",
            "|---|---|---:|---:|---:|---:|---:|---:|---:|",
            "| owner/nested | `abcdef012345` | 3 | 3 | 3 | 2 | 3 | 5 | 34 |",
            "| owner/small | `0123456789ab` | 2 | 2 | 1 | 1 | 1 | 0 | 2 |",
            "| **total** | | 5 | 5 | 4 | 3 | 4 | 5 | 36 |"
        }) + "\n", Families.Report.inventory(Vector#{nestedInventory(), small}))
    }
}
