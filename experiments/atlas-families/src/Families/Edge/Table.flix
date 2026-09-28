/// Typed projections of the family-edge tables of one world (space
/// `atlas-families-v1`): the family edges with their multiplicity, and one
/// contribution row per exact world edge. A contribution row carries the
/// exact world relation row it is (snapshot, relation, domains, ids), so it
/// joins the frozen world relations table without any key of its own.
pub mod Families.Edge.Table {
    use ScientificTable.Value
    use ScientificTable.Columns.{int32, optionalInt32, text}

    pub def edges(): ScientificTable.Schema = {
        format = "attune-atlas-family-edges-v1",
        columns = Vector#{
            text("protocol"), text("snapshot_id"), text("relation"), text("grain"), int32("edge"),
            int32("source_family"), text("source_family_id"), int32("target_family"), text("target_family_id"),
            int32("multiplicity")
        }
    }

    pub def contributions(): ScientificTable.Schema = {
        format = "attune-atlas-family-edge-contributions-v1",
        columns = Vector#{
            text("protocol"), text("snapshot_id"), text("relation"), text("source_domain"), int32("source_id"),
            text("target_domain"), int32("target_id"), optionalInt32("source_family"), optionalInt32("target_family"),
            optionalInt32("edge")
        }
    }

    /// Both tables of one aggregation: its name, file name, schema, and rows.
    pub def layout(value: Families.Edge.Aggregation): Vector[(String, String, ScientificTable.Schema, Vector[ScientificTable.Row])] = {
        let s = value#snapshotId;
        Vector#{
            ("edges", "edges.parquet", edges(), Vector.map(edgeRow(s), value#edges)),
            ("contributions", "contributions.parquet", contributions(), Vector.map(contributionRow(s), value#contributions))
        }
    }

    /// The layout of an empty aggregation: every table's name, file, and schema.
    pub def schemas(snapshotId: String): Vector[(String, String, ScientificTable.Schema, Vector[ScientificTable.Row])] =
        layout({snapshotId = snapshotId, edges = Vector.empty(), contributions = Vector.empty()})

    def grainOf(relation: String): String = Families.Edge.domain(relation) |> Option.getWithDefault("")

    pub def edgeRow(snapshotId: String, value: Families.Edge.Edge): ScientificTable.Row =
        Map.union(Families.Rows.header(edges(), snapshotId), Map#{
            "relation" => Value.Text(value#relation),
            "grain" => Value.Text(grainOf(value#relation)),
            "edge" => Value.Int32(value#edge),
            "source_family" => Value.Int32(value#sourceFamily),
            "source_family_id" => Value.Text(value#sourceFamilyId),
            "target_family" => Value.Int32(value#targetFamily),
            "target_family_id" => Value.Text(value#targetFamilyId),
            "multiplicity" => Value.Int32(value#multiplicity)
        })

    pub def contributionRow(snapshotId: String, value: Families.Edge.Contribution): ScientificTable.Row =
        Map.union(Families.Rows.header(contributions(), snapshotId), Map#{
            "relation" => Value.Text(value#relation),
            "source_domain" => Value.Text(grainOf(value#relation)),
            "source_id" => Value.Int32(value#sourceId),
            "target_domain" => Value.Text(grainOf(value#relation)),
            "target_id" => Value.Int32(value#targetId),
            "source_family" => ScientificTable.optionalInt32Value(value#sourceFamily),
            "target_family" => ScientificTable.optionalInt32Value(value#targetFamily),
            "edge" => ScientificTable.optionalInt32Value(value#edge)
        })

    /// The aggregation stored in `files` (table name -> path).
    pub def read(snapshotId: String, files: Map[String, String]): Result[String, Families.Edge.Aggregation] \ IO = forM (
        tables <- Families.Rows.readLayout(schemas(snapshotId), files);
        rows = Families.Rows.rowsOf(tables);
        aggregation <- decode(snapshotId, rows("edges"), rows("contributions"))
    ) yield aggregation

    /// The typed aggregation of one world, from its two tables' rows.
    pub def decode(
        snapshotId: String,
        edgeRows: Vector[ScientificTable.Row],
        contributionRows: Vector[ScientificTable.Row]
    ): Result[String, Families.Edge.Aggregation] = forM (
        edges0 <- Vector.traverse(decodeEdge(snapshotId), edgeRows);
        _ <- if (Vector.map(value -> value#edge, edges0) == Vector.range(0, Vector.length(edges0))) Ok(())
             else Err("family edges must be contiguous from edge zero");
        contributions0 <- Vector.traverse(decodeContribution(snapshotId), contributionRows)
    ) yield {snapshotId = snapshotId, edges = edges0, contributions = contributions0}

    /// The relation of a row, which must be aggregated at the declared grain.
    def relationOf(row: ScientificTable.Row, grainColumns: Vector[String]): Result[String, String] = forM (
        relation <- ScientificTable.text(row, "relation");
        grain <- Families.Edge.domain(relation) |> Option.toOk("unknown family edge relation ${relation}");
        _ <- Vector.traverse(column -> ScientificTable.requireText(column, grain, row, "family edge ${relation}"), grainColumns)
    ) yield relation

    def decodeEdge(snapshotId: String, row: ScientificTable.Row): Result[String, Families.Edge.Edge] = forM (
        _ <- Families.Rows.require(edges(), snapshotId, row);
        relation <- relationOf(row, Vector#{"grain"});
        edge <- ScientificTable.int32(row, "edge");
        sourceFamily <- ScientificTable.int32(row, "source_family");
        sourceFamilyId <- ScientificTable.text(row, "source_family_id");
        targetFamily <- ScientificTable.int32(row, "target_family");
        targetFamilyId <- ScientificTable.text(row, "target_family_id");
        multiplicity <- ScientificTable.int32(row, "multiplicity")
    ) yield {
        relation = relation, edge = edge, sourceFamily = sourceFamily, sourceFamilyId = sourceFamilyId,
        targetFamily = targetFamily, targetFamilyId = targetFamilyId, multiplicity = multiplicity
    }

    def decodeContribution(snapshotId: String, row: ScientificTable.Row): Result[String, Families.Edge.Contribution] = forM (
        _ <- Families.Rows.require(contributions(), snapshotId, row);
        relation <- relationOf(row, Vector#{"source_domain", "target_domain"});
        sourceId <- ScientificTable.int32(row, "source_id");
        targetId <- ScientificTable.int32(row, "target_id");
        sourceFamily <- ScientificTable.optionalInt32(row, "source_family");
        targetFamily <- ScientificTable.optionalInt32(row, "target_family");
        edge <- ScientificTable.optionalInt32(row, "edge")
    ) yield {
        relation = relation, sourceId = sourceId, targetId = targetId,
        sourceFamily = sourceFamily, targetFamily = targetFamily, edge = edge
    }
}
