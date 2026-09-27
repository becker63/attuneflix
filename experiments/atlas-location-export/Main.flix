def main(): Unit \ IO = {
    LocationExport.execute()
}

/// Exporter surface for the admitted location labels. The Bazel rule supplies
/// the world tables and the identity as action transport properties; Flix owns
/// the derivation and the typed table.
mod LocationExport {
    pub def execute(): Unit \ IO = match Experiment.property("attune.command") {
        case "locations" => exportLocations()
        case _ => bug!("unknown location export command: ${Experiment.property("attune.command")}")
    }

    def exportLocations(): Unit \ IO = {
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
                let locations = Repository.Location.locations(world);
                let _ = Repository.Location.Table.write(
                    Experiment.property("attune.output_locations"), identity#snapshotId, locations);
                println("ATLAS_LOCATIONS snapshot=${identity#snapshotId} rows=${Vector.length(locations)}")
            }
        }
    }
}
