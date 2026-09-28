/// The keyless replay proof (`attune-families-replay-proof-v1`), after the
/// `replay-proof.parquet` precedent: for every recorded table of one world,
/// the identity of the recorded rows beside the identity of the rows the
/// pipeline derives again from retained raw evidence alone, plus the count
/// of provider calls the replay made and whether a provider key was visible.
pub mod Families.Replay {
    use ScientificTable.Value
    use ScientificTable.Columns.{boolean, int32, text}

    pub type alias Check = {
        table    = String,
        rows     = Int32,
        recorded = String,
        replayed = String
    }

    pub type alias Proof = {
        snapshotId    = String,
        checks        = Vector[Check],
        retained      = Int32,
        served        = Int32,
        providerCalls = Int32,
        keyAbsent     = Bool
    }

    pub def schema(): ScientificTable.Schema = {
        format = "attune-families-replay-proof-v1",
        columns = Vector#{
            text("protocol"), text("snapshot_id"), text("table"), int32("rows"),
            text("recorded_identity"), text("replayed_identity"), boolean("equal"),
            int32("retained_exchanges"), int32("served_exchanges"), int32("provider_calls"), boolean("key_absent")
        }
    }

    pub def check(table: String, schema0: ScientificTable.Schema, recorded: Vector[ScientificTable.Row], replayed: Vector[ScientificTable.Row]): Check \ IO = {
        table = table,
        rows = Vector.length(replayed),
        recorded = Families.Rows.identity(schema0, recorded),
        replayed = Families.Rows.identity(schema0, replayed)
    }

    /// Exact replay: every table bit-identical, every retained exchange served
    /// and none missing, no provider call, and no key in the environment.
    pub def exact(proof: Proof): Bool =
        not Vector.isEmpty(proof#checks) and
        Vector.forAll(check -> check#recorded == check#replayed, proof#checks) and
        proof#retained == proof#served and proof#providerCalls == 0 and proof#keyAbsent

    pub def rows(proof: Proof): Vector[ScientificTable.Row] =
        Vector.map(check -> Map.union(Families.Rows.header(schema(), proof#snapshotId), Map#{
            "table" => Value.Text(check#table),
            "rows" => Value.Int32(check#rows),
            "recorded_identity" => Value.Text(check#recorded),
            "replayed_identity" => Value.Text(check#replayed),
            "equal" => Value.Boolean(check#recorded == check#replayed),
            "retained_exchanges" => Value.Int32(proof#retained),
            "served_exchanges" => Value.Int32(proof#served),
            "provider_calls" => Value.Int32(proof#providerCalls),
            "key_absent" => Value.Boolean(proof#keyAbsent)
        }), proof#checks)

    pub def decode(snapshotId: String, rows0: Vector[ScientificTable.Row]): Result[String, Proof] = forM (
        checks <- Vector.traverse(row -> forM (
            _ <- Families.Rows.require(schema(), snapshotId, row);
            table <- ScientificTable.text(row, "table");
            count <- ScientificTable.int32(row, "rows");
            recorded <- ScientificTable.text(row, "recorded_identity");
            replayed <- ScientificTable.text(row, "replayed_identity");
            equal <- ScientificTable.boolean(row, "equal");
            _ <- if (equal == (recorded == replayed)) Ok(()) else Err("replay proof equality column disagrees with its identities")
        ) yield {table = table, rows = count, recorded = recorded, replayed = replayed}, rows0);
        first <- Vector.head(rows0) |> Option.toOk("a replay proof holds at least one table");
        retained <- ScientificTable.int32(first, "retained_exchanges");
        served <- ScientificTable.int32(first, "served_exchanges");
        providerCalls <- ScientificTable.int32(first, "provider_calls");
        keyAbsent <- ScientificTable.boolean(first, "key_absent");
        proof = {snapshotId = snapshotId, checks = checks, retained = retained, served = served, providerCalls = providerCalls, keyAbsent = keyAbsent};
        _ <- if (rows(proof) == rows0) Ok(()) else Err("replay proof rows disagree on the pass-level columns")
    ) yield proof
}
