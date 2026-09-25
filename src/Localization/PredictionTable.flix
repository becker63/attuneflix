/// Typed durable output of the current localization sandwich.
pub mod Localization.PredictionTable {
    use ScientificTable.Value
    use ScientificTable.Columns.{text, int32, optionalInt32, float64}

    pub type alias Tables = {
        summary = Vector[ScientificTable.Row],
        ranking = Vector[ScientificTable.Row]
    }

    pub def protocol(): String = "attune-localization-prediction-v2"

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

    pub def rows(
        prediction: Localization.Sandwich.Prediction,
        search: Localization.Sandwich.Search
    ): Tables = {
        summary = Vector#{Map#{
            "protocol" => Value.Text(protocol()),
            "instance_id" => Value.Text(prediction#instanceId),
            "selection" => Value.Text(selectionName(prediction#selection)),
            "candidate_id" => candidateValue(prediction#selection),
            "logical_routes" => Value.Int32(search#logicalRoutes),
            "unique_semantic_states" => Value.Int32(search#uniqueSemanticStates),
            "physical_transitions" => Value.Int32(search#physicalTransitions),
            "transition_reuses" => Value.Int32(search#transitionReuses)
        }},
        ranking = Vector.mapWithIndex((rank, item) -> Map#{
            "protocol" => Value.Text(protocol()),
            "instance_id" => Value.Text(prediction#instanceId),
            "rank" => Value.Int32(rank),
            "semantic_id" => Value.Text(item#identity),
            "prior_score" => Value.Float64(item#score),
            "document_ordinal" => Value.Int32(item#ordinal)
        }, prediction#ranking)
    }

    pub def write(summaryPath: String, rankingPath: String, tables: Tables): Tables \ IO = {
        summary = ScientificTable.write(summaryPath, summary(), tables#summary),
        ranking = ScientificTable.write(rankingPath, ranking(), tables#ranking)
    }

    pub def read(summaryPath: String, rankingPath: String): Tables \ IO = {
        summary = ScientificTable.read(summaryPath, summary()),
        ranking = ScientificTable.read(rankingPath, ranking())
    }

    def selectionName(selection: Localization.Sandwich.Selection): String = match selection {
        case Localization.Sandwich.Selection.Prior => "prior"
        case Localization.Sandwich.Selection.Atlas(_) => "atlas"
    }

    def candidateValue(selection: Localization.Sandwich.Selection): ScientificTable.Value = match selection {
        case Localization.Sandwich.Selection.Prior => Value.Null
        case Localization.Sandwich.Selection.Atlas(Localization.Sandwich.CandidateId.CandidateId(id)) => Value.Int32(id)
    }
}
