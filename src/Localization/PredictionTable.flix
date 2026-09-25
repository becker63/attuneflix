/// Typed durable output of the current localization sandwich.
pub mod Localization.PredictionTable {
    use ScientificTable.Columns.{text, int32, optionalInt32, float64}

    pub def summary(): ScientificTable.Schema = {
        format = "attune-localization-prediction-summary-v2",
        columns = Vector#{
            text("protocol"), text("instance_id"), text("selection"), optionalInt32("candidate_id"),
            int32("logical_routes"), int32("unique_semantic_states"),
            int32("physical_transitions"), int32("transition_reuses")
        }
    }

    pub def ranking(): ScientificTable.Schema = {
        format = "attune-localization-prediction-ranking-v2",
        columns = Vector#{
            text("protocol"), text("instance_id"), int32("rank"),
            text("semantic_id"), float64("prior_score"), int32("document_ordinal")
        }
    }
}
