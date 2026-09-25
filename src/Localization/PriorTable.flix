/// Typed semantic-prior data used by Localization.
///
/// The provider observations remain immutable paid evidence. These tables are
/// their deterministic, reusable projection: one protocol row, the exact
/// document corpus, and the exact ranked field consumed by Atlas.
pub mod Localization.PriorTable {
    use ScientificTable.Columns.{text, int32, optionalInt32, float64}

    pub def metadata(): ScientificTable.Schema = {
        format = "attune-semantic-prior-metadata-v1",
        columns = Vector#{
            text("protocol"), text("instance_id"), text("repository"),
            text("base_revision"), text("provider"), text("model"),
            text("instruction"), int32("text_limit"), int32("dimension"),
            text("issue_revision"), int32("replayed"), int32("live"),
            optionalInt32("input_tokens"), optionalInt32("total_tokens")
        }
    }

    pub def documents(): ScientificTable.Schema = {
        format = "attune-semantic-prior-documents-v1",
        columns = Vector#{
            text("protocol"), text("instance_id"), int32("ordinal"),
            text("semantic_id"), text("node_id"), text("path"), text("name"),
            int32("start_byte"), int32("end_byte")
        }
    }

    pub def ranking(): ScientificTable.Schema = {
        format = "attune-semantic-prior-ranking-v1",
        columns = Vector#{
            text("protocol"), text("instance_id"), int32("rank"),
            text("semantic_id"), float64("score"), int32("document_ordinal")
        }
    }
}
