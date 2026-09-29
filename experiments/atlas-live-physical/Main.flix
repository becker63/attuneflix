def main(): Unit \ IO = AtlasLivePhysical.execute()

/// A new view measurement over every admitted Preact file and symbol. The
/// frozen signature seed panel and evaluator remain untouched.
mod AtlasLivePhysical {
    import java.lang.Integer

    pub def execute(): Unit \ IO = match Experiment.property("attune.command") {
        case "measure" => measureShard()
        case "merge" => mergeShards()
        case command => bug!("unknown physical command: ${command}")
    }

    def measureShard(): Unit \ IO = {
        let identity: Repository.Table.Identity = {
            repository = Experiment.property("attune.repository"),
            baseRevision = Experiment.property("attune.base_revision"),
            sourceTreeIdentity = Experiment.property("attune.source_tree_identity"),
            factIdentity = Experiment.property("attune.fact_identity"),
            snapshotId = Experiment.property("attune.snapshot_id")
        };
        match Repository.Table.read(
            Experiment.property("attune.world_metadata"),
            Experiment.property("attune.world_entities"),
            Experiment.property("attune.world_relations"),
            identity
        ) {
            case Err(error) => bug!(error)
            case Ok(world) => {
                let snapshot: Atlas.Signature.Table.SnapshotIdentity = {
                    signatureProtocol = "atlas-live-physical-all-seeds-v1",
                    atlasProtocol = "atlas-composition-depth7-v1",
                    repository = identity#repository,
                    baseRevision = identity#baseRevision,
                    sourceTreeIdentity = identity#sourceTreeIdentity,
                    factIdentity = identity#factIdentity,
                    snapshotId = identity#snapshotId
                };
                let files = Vector.mapWithIndex((ordinal, path) -> {
                    domain = Radii.Domain.File,
                    identity = path,
                    ordinal = ordinal,
                    state = Atlas.State.Files(Set.singleton(Repository.Structure.FileId.FileId(ordinal)))
                }, world#files);
                let symbols = Vector.mapWithIndex((ordinal, symbol) -> {
                    domain = Radii.Domain.Symbol,
                    identity = "${symbol#path}\u0000${symbol#name}\u0000${symbol#startByte}\u0000${symbol#endByte}",
                    ordinal = ordinal,
                    state = Atlas.State.Symbols(Set.singleton(Repository.Structure.SymbolId.SymbolId(ordinal)))
                }, world#symbols);
                let seeds = Vector.append(files, symbols);
                let expected = Integer.parseInt(Experiment.property("attune.expected_seeds"));
                let start = Integer.parseInt(Experiment.property("attune.seed_start"));
                let end = Integer.parseInt(Experiment.property("attune.seed_end"));
                if (Vector.length(seeds) != expected or start < 0 or end < start or end > expected)
                    bug!("physical shard bounds disagree with admitted world")
                else {
                    let selected = Vector.slice(start = start, end = end, seeds);
                    let physical = Atlas.physical(world);
                    match measure(snapshot, physical, Vector.toList(selected), Nil) {
                        case Err(error) => bug!(error)
                        case Ok(rows) => {
                            let _ = ScientificTable.write(
                                Experiment.property("attune.output_physical"),
                                Atlas.Signature.Table.physical(),
                                List.reverse(rows) |> List.toVector
                            );
                            println("ATLAS_LIVE_PHYSICAL snapshot=${identity#snapshotId} seeds=${Vector.length(selected)}")
                        }
                    }
                }
            }
        }
    }

    /// Ordered shards retain the same exact per-seed evaluator and counters.
    def mergeShards(): Unit \ IO = {
        let rows = Experiment.paths("attune.shard")
            |> Vector.map(path -> ScientificTable.read(path, Atlas.Signature.Table.physical()))
            |> Vector.flatten;
        let expected = Integer.parseInt(Experiment.property("attune.expected_seeds"));
        if (Vector.length(rows) != expected)
            bug!("physical shards contain ${Vector.length(rows)} seeds, expected ${expected}")
        else {
            let written = ScientificTable.write(
                Experiment.property("attune.output_physical"),
                Atlas.Signature.Table.physical(),
                rows
            );
            if (written == rows)
                println("ATLAS_LIVE_PHYSICAL_MERGE seeds=${expected}")
            else bug!("physical merged table did not round-trip exactly")
        }
    }

    def measure(
        snapshot: Atlas.Signature.Table.SnapshotIdentity,
        physical: Repository.Physical.World,
        seeds: List[Atlas.Signature.Seed],
        rows: List[ScientificTable.Row]
    ): Result[String, List[ScientificTable.Row]] \ IO = match seeds {
        case Nil => Ok(rows)
        case seed :: rest =>
            match Atlas.Signature.physicalMetricsComplete(physical, seed#state, 7) {
                case Err(error) => Err(error)
                case Ok(metrics) => measure(snapshot, physical, rest,
                    Atlas.Signature.Table.physicalRowFromMetrics(snapshot, seed, metrics) :: rows)
            }
    }
}
