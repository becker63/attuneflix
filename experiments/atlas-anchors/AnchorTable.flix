/// New typed outputs; frozen census tables and identities remain read-only.
pub mod AnchorTable {
    use ScientificTable.Value
    use ScientificTable.Columns.{text, int64, float64}

    pub def anchors(): ScientificTable.Schema = {
        format = "attune-atlas-anchor-concentration-v1",
        columns = Vector#{
            text("snapshot_id"), text("seed_domain"), text("anchor_path"),
            int64("rank"), int64("contained_files"), int64("crossing_edges"),
            int64("unique_containing_states"), int64("unique_live_states"),
            float64("unique_anchor_mass"), int64("weighted_containing_observations"),
            int64("live_observations"), float64("weighted_anchor_mass")
        }
    }

    pub def scenarios(): ScientificTable.Schema = {
        format = "attune-atlas-anchor-counterfactual-v1",
        columns = Vector#{
            text("snapshot_id"), text("intervention"), text("masked_anchor"),
            text("seed_domain"), int64("masked_imports"), int64("masked_calls"),
            int64("crossing_edges"), int64("observations"),
            int64("extinct_observations"), int64("live_observations"),
            int64("unique_states"), int64("unique_live_states"),
            float64("extinct_fraction"), float64("total_recurrence"),
            float64("live_recurrence"), float64("reach_p90"),
            float64("physical_compression"), float64("physical_reuse_fraction")
        }
    }

    pub def anchorRows(snapshotId: String, domain: String, world: Repository.World,
                       masses: Vector[Anchor.Mass]): Vector[ScientificTable.Row] =
        Vector.mapWithIndex((rank, mass) -> Map#{
            "snapshot_id" => Value.Text(snapshotId),
            "seed_domain" => Value.Text(domain),
            "anchor_path" => Value.Text(mass#anchorPath),
            "rank" => Value.Int64(Int32.toInt64(rank + 1)),
            "contained_files" => Value.Int64(Int32.toInt64(Vector.count(path ->
                Anchor.contains(path, mass#anchorPath), world#files))),
            "crossing_edges" => Value.Int64(Int32.toInt64(
                Anchor.crossingVolume(world, mass#anchorPath))),
            "unique_containing_states" => Value.Int64(Int32.toInt64(mass#uniqueContaining)),
            "unique_live_states" => Value.Int64(Int32.toInt64(mass#uniqueLiveStates)),
            "unique_anchor_mass" => Value.Float64(mass#uniqueFraction),
            "weighted_containing_observations" => Value.Int64(Int32.toInt64(mass#weightedContaining)),
            "live_observations" => Value.Int64(Int32.toInt64(mass#liveObservations)),
            "weighted_anchor_mass" => Value.Float64(mass#weightedFraction)
        }, masses)

    pub def scenarioRows(snapshotId: String, anchorPath: String,
                         result: AnchorAnalysis.Scenario): Vector[ScientificTable.Row] = Vector#{
        scenarioRow(snapshotId, anchorPath, "file", result, result#file),
        scenarioRow(snapshotId, anchorPath, "symbol", result, result#symbol)
    }

    def scenarioRow(snapshotId: String, anchorPath: String, domain: String,
                    scenario: AnchorAnalysis.Scenario,
                    values: AnchorAnalysis.Domain): ScientificTable.Row = {
        let data = values#decomposition;
        Map#{
            "snapshot_id" => Value.Text(snapshotId),
            "intervention" => Value.Text(scenario#intervention),
            "masked_anchor" => Value.Text(anchorPath),
            "seed_domain" => Value.Text(domain),
            "masked_imports" => Value.Int64(Int32.toInt64(scenario#maskedImports)),
            "masked_calls" => Value.Int64(Int32.toInt64(scenario#maskedCalls)),
            "crossing_edges" => Value.Int64(Int32.toInt64(scenario#crossingVolume)),
            "observations" => Value.Int64(Int32.toInt64(data#observations)),
            "extinct_observations" => Value.Int64(Int32.toInt64(data#extinctObservations)),
            "live_observations" => Value.Int64(Int32.toInt64(data#liveObservations)),
            "unique_states" => Value.Int64(Int32.toInt64(data#uniqueStates)),
            "unique_live_states" => Value.Int64(Int32.toInt64(data#uniqueLiveStates)),
            "extinct_fraction" => Value.Float64(ScientificTable.ratio(
                data#extinctObservations, data#observations)),
            "total_recurrence" => Value.Float64(data#totalRecurrence),
            "live_recurrence" => Value.Float64(data#liveRecurrence),
            "reach_p90" => Value.Float64(values#reachP90),
            "physical_compression" => Value.Float64(scenario#physicalCompression),
            "physical_reuse_fraction" => Value.Float64(scenario#physicalReuse)
        }
    }
}
