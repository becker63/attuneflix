/// Typed proof emitted by each independent keyless localization replay.
pub mod LocalizationReplay {
    pub def schema(): ScientificTable.Schema = {
        format = "attune-localization-replay-proof-v1",
        columns = Vector#{
            text("protocol"), text("instance_id"), text("repository"),
            text("base_revision"), text("snapshot_id"),
            text("expected_prediction_id"), text("replay_prediction_id"),
            boolean("exact_equal"), int32("decision_occurrences"),
            int32("unique_decisions"), int32("states_interned"),
            int32("memo_entries"), int32("memo_slots"), int64("replay_nanos")
        }
    }

    def text(name: String): ScientificTable.Column = {
        name = name, kind = ScientificTable.ColumnType.Text, nullable = false
    }

    def boolean(name: String): ScientificTable.Column = {
        name = name, kind = ScientificTable.ColumnType.Boolean, nullable = false
    }

    def int32(name: String): ScientificTable.Column = {
        name = name, kind = ScientificTable.ColumnType.Int32, nullable = false
    }

    def int64(name: String): ScientificTable.Column = {
        name = name, kind = ScientificTable.ColumnType.Int64, nullable = false
    }
}
