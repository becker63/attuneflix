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
        case "project"   => projection()
        case "acquire"   => acquire()
        case "replay"    => replay()
        case "acquisition-report" => acquisitionReport()
        case "protocol"  => write(Families.Report.protocol())
        case command     => bug!("unknown families command: ${command}")
    }

    def subject(): Families.Pass.Subject \ IO = {
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
        {identity = identity, world = world}
    }

    def inventory(): Unit \ IO = {
        let value = subject();
        let written = Experiment.require(Families.Inventory.Table.write(
            Experiment.property("attune.output_inventory"), Families.Inventory.of(value#identity, value#world)));
        println("ATLAS_FAMILIES_INVENTORY snapshot=${written#snapshotId} callables=${written#callables}")
    }

    def roots(): Families.Pass.Roots \ IO = {
        embeddings = Experiment.property("attune.embeddings_root"),
        decisions = Experiment.property("attune.decisions_root")
    }

    /// The pre-acquisition bound for one world; it reaches no provider.
    def projection(): Unit \ IO = {
        let value = subject();
        let documents = Experiment.require(Families.Embedding.documents(value#world, Experiment.property("attune.source_root")));
        println("ATLAS_FAMILIES_PROJECTION snapshot=${value#identity#snapshotId} documents=${Vector.length(documents)} " +
            "document_bytes=${Families.Ledger.documentBytes(documents)} seeds=${Vector.length(Families.Navigation.seeds(value#world))} " +
            "truncated=${Vector.count(document -> document#truncated, documents)} " +
            "projected_usd=${Families.Pass.projectedUsd(value#world, documents)} envelope_usd=${Families.Protocol.envelopeUsd()}")
    }

    /// The live pass: the only command that can reach a provider.
    def acquire(): Unit \ IO = {
        let value = subject();
        let passed = Experiment.require(Families.Pass.acquire(
            value, Experiment.property("attune.source_root"), roots(), Families.Provider.Transport.Live));
        let describe = (name, stats: Families.Provider.Stats) ->
            "${name} acquired=${stats#acquired} recorded=${stats#recorded} spent_usd=${stats#spentUsd}";
        println("ATLAS_FAMILIES_ACQUIRE snapshot=${value#identity#snapshotId} " +
            describe("embeddings", passed#embedding) + " " + describe("decisions", passed#decision))
    }

    /// Keyless replay: fails unless every recorded table is reproduced exactly.
    def replay(): Unit \ IO = {
        let value = subject();
        let proof = Experiment.require(Families.Pass.replay(value, roots()));
        let rows = ScientificTable.write(Experiment.property("attune.output_proof"), Families.Replay.schema(), Families.Replay.rows(proof));
        let _ = Experiment.require(Families.Replay.decode(proof#snapshotId, rows));
        if (Families.Replay.exact(proof))
            println("ATLAS_FAMILIES_REPLAY snapshot=${proof#snapshotId} exact=true provider_calls=${proof#providerCalls}")
        else bug!("keyless replay of ${proof#snapshotId} is not exact")
    }

    def acquisitionReport(): Unit \ IO = {
        let count = Experiment.count("attune.acquisition");
        let values = Vector.map(index -> {
            let property = name -> Experiment.property("attune.acquisition.${index}.${name}");
            let snapshotId = property("snapshot_id");
            let ledger = name -> Experiment.require(Families.Ledger.decode(snapshotId,
                ScientificTable.read(property(name), Families.Ledger.schema())));
            {
                repository = property("repository"),
                ledgers = Vector#{ledger("embedding_ledger"), ledger("decision_ledger")},
                proof = Experiment.require(Families.Replay.decode(snapshotId,
                    ScientificTable.read(property("proof"), Families.Replay.schema())))
            }
        }, Vector.range(0, count));
        write(Families.Report.acquisition(values))
    }

    def write(text: String): Unit \ IO = {
        let _ = Files.writeString(Paths.get(Experiment.property("attune.output_report")), text);
        ()
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
