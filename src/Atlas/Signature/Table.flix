/// Canonical typed Parquet schemas for the Atlas census. These declarations
/// are the scientific data model; the Arrow boundary only realizes them.
pub mod Atlas.Signature.Table {
    pub def observations(): ScientificTable.Schema = {
        format = "attune-atlas-signature-observations-v1",
        columns = Vector#{
            text("signature_protocol"), text("atlas_protocol"), text("repository"),
            text("base_revision"), text("source_tree_identity"), text("fact_identity"),
            text("snapshot_id"), text("seed_domain"), text("seed_identity"),
            int32("seed_ordinal"), text("route_id"), textList("route_atoms"),
            int32("depth"), text("first_atom"), text("last_atom"),
            text("terminal_domain"), int64("input_cardinality"),
            int64("output_cardinality"), int64("domain_cardinality"),
            optionalFloat64("expansion_ratio"), float64("reach_fraction"),
            boolean("extinct"), optionalInt32("first_extinction_depth"),
            text("semantic_state_id"), boolean("same_as_input")
        }
    }

    pub def snapshots(): ScientificTable.Schema = {
        format = "attune-atlas-signature-snapshots-v1",
        columns = Vector.append(identityColumns(), Vector#{
            int64("file_count"), int64("symbol_count"), int64("defines_count"),
            int64("imports_count"), int64("calls_count"), int64("parent_count"),
            int64("manifest_case_count")
        })
    }

    pub def physical(): ScientificTable.Schema = {
        format = "attune-atlas-signature-physical-v1",
        columns = Vector.append(identityColumns(), Vector#{
            text("seed_domain"), text("seed_identity"), int32("seed_ordinal"),
            int64("logical_routes"), int64("unique_semantic_states"),
            int64("physical_transition_requests"),
            int64("physical_transition_evaluations"),
            int64("physical_transition_reuses"),
            float64("logical_per_unique_state"),
            float64("logical_per_physical_evaluation"),
            int64("memo_cells"), int64("compiled_dag_nodes")
        })
    }

    pub def caseSnapshots(): ScientificTable.Schema = {
        format = "attune-atlas-case-snapshots-v1",
        columns = Vector#{
            text("signature_protocol"), int32("manifest_position"), text("case_id"),
            text("population"), text("split"), text("repository"),
            text("base_revision"), text("source_tree_identity"), text("fact_identity"),
            text("snapshot_id")
        }
    }

    def identityColumns(): Vector[ScientificTable.Column] = Vector#{
        text("signature_protocol"), text("atlas_protocol"), text("repository"),
        text("base_revision"), text("source_tree_identity"), text("fact_identity"),
        text("snapshot_id")
    }

    def text(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Text, nullable = false}

    def textList(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.TextList, nullable = false}

    def int32(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Int32, nullable = false}

    def optionalInt32(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Int32, nullable = true}

    def int64(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Int64, nullable = false}

    def float64(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Float64, nullable = false}

    def optionalFloat64(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Float64, nullable = true}

    def boolean(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Boolean, nullable = false}
}
