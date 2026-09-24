/// Typed durable tables emitted by the official localization evaluator.
pub mod Localization.EvaluationTable {
    pub def metrics(): ScientificTable.Schema = {
        format = "attune-localization-evaluation-metrics-v1",
        columns = Vector#{
            text("protocol"), text("instance_id"), text("repository"),
            text("base_revision"), text("snapshot_id"), text("condition"),
            text("oracle_path"), float64("precision"), float64("recall"),
            float64("f1_score"), float64("hit_file_rate"), float64("noise_file_rate"),
            float64("hit_region_rate"), float64("noise_region_rate"),
            float64("weighted_core_coverage"), float64("context_efficiency"),
            float64("ndcg_at_100"), float64("ndcg_at_300"), float64("ndcg_at_500"),
            float64("recall_at_100"), float64("recall_at_300"), float64("recall_at_500"),
            float64("first_useful_hit")
        }
    }

    pub def regions(): ScientificTable.Schema = {
        format = "attune-localization-evaluation-regions-v1",
        columns = Vector#{
            text("protocol"), text("instance_id"), text("condition"), int32("ordinal"),
            text("path"), int32("start_line"), int32("end_line")
        }
    }

    pub def telemetry(): ScientificTable.Schema = {
        format = "attune-localization-oracle-telemetry-v1",
        columns = Vector#{
            text("protocol"), text("instance_id"), int32("logical_routes"),
            int32("unique_states"), int32("unique_projections"), int32("score_evaluations")
        }
    }

    pub def proof(): ScientificTable.Schema = {
        format = "attune-localization-evaluation-parity-v1",
        columns = Vector#{
            text("protocol"), text("instance_id"), boolean("exact_discrete"),
            boolean("metrics_within_tolerance"), float64("tolerance")
        }
    }

    def text(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Text, nullable = false}
    def int32(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Int32, nullable = false}
    def float64(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Float64, nullable = false}
    def boolean(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Boolean, nullable = false}
}
