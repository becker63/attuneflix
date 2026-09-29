def main(): Unit \ IO = AtlasLivePhysical.execute()

/// A new view measurement over every admitted Preact file and symbol. The
/// frozen signature seed panel and evaluator remain untouched.
mod AtlasLivePhysical {
    pub def execute(): Unit \ IO = {
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
                match measure(snapshot, world, Vector.toList(seeds), Nil) {
                    case Err(error) => bug!(error)
                    case Ok(rows) => {
                        let _ = ScientificTable.write(
                            Experiment.property("attune.output_physical"),
                            Atlas.Signature.Table.physical(),
                            List.reverse(rows) |> List.toVector
                        );
                        println("ATLAS_LIVE_PHYSICAL seeds=${Vector.length(seeds)}")
                    }
                }
            }
        }
    }

    def measure(
        snapshot: Atlas.Signature.Table.SnapshotIdentity,
        world: Repository.World,
        seeds: List[Atlas.Signature.Seed],
        rows: List[ScientificTable.Row]
    ): Result[String, List[ScientificTable.Row]] \ IO = match seeds {
        case Nil => Ok(rows)
        case seed :: rest => forM (
            signature <- Atlas.Signature.compute(world, seed#state, 7);
            result <- measure(snapshot, world, rest,
                Atlas.Signature.Table.physicalRow(snapshot, seed, signature) :: rows)
        ) yield result
    }
}
