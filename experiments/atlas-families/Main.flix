def main(): Unit \ IO = {
    FamiliesMain.execute()
}

/// Command surface of the families experiment tool. The Bazel rules supply the
/// world tables, identities, and output paths as action transport properties;
/// Flix owns every derivation and every typed table.
mod FamiliesMain {
    import java.nio.file.{Files, Paths}

    pub def execute(): Unit \ IO = match Experiment.property("attune.command") {
        case "inventory" => inventory()
        case "report"    => report()
        case command     => bug!("unknown families command: ${command}")
    }

    def inventory(): Unit \ IO = {
        let identity: Repository.Table.Identity = {
            repository = Experiment.property("attune.repository"),
            baseRevision = Experiment.property("attune.base_revision"),
            sourceTreeIdentity = Experiment.property("attune.source_tree_identity"),
            factIdentity = Experiment.property("attune.fact_identity"),
            snapshotId = Experiment.property("attune.snapshot_id")
        };
        let world = Experiment.require(Repository.Table.read(
            Experiment.property("attune.world_metadata"),
            Experiment.property("attune.world_entities"),
            Experiment.property("attune.world_relations"),
            identity
        ));
        let written = Experiment.require(Families.Inventory.Table.write(
            Experiment.property("attune.output_inventory"), Families.Inventory.of(identity, world)));
        println("ATLAS_FAMILIES_INVENTORY snapshot=${written#snapshotId} callables=${written#callables}")
    }

    def report(): Unit \ IO = {
        let inventories = Vector.map(
            path -> Experiment.require(Families.Inventory.Table.read(path)),
            Experiment.paths("attune.inventory"));
        let _ = Files.writeString(
            Paths.get(Experiment.property("attune.output_report")),
            Families.Report.inventory(inventories));
        ()
    }
}
