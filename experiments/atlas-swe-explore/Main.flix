def main(): Unit \ {Fs.FileSystem, IO} = {
    CensusMain.execute()
}

/// Temporary executable surface while snapshot inputs move into Bazel. The
/// command already compiles independently from tests; census work will extend
/// this entry point without turning `flix test` back into an experiment runner.
mod CensusMain {
    import java.lang.System
    import java.lang.Integer

    use Fs.FileSystem

    type alias Output = {
        observations = Vector[ScientificTable.Row],
        physical     = Vector[ScientificTable.Row]
    }

    pub def execute(): Unit \ {FileSystem, IO} = {
        let command = System.getProperty("attune.command");
        match command {
            case "protocol" => printProtocol()
            case "fixture" => writeFixture()
            case "signature" => writeSignature()
            case "signature-dynamic" => writeDynamicSignature()
            case _ => bug!("unknown Atlas census command: ${command}")
        }
    }

    /// Small remote-action fixture. The world and every identity are supplied
    /// by the Bazel rule; Flix still owns the typed scientific rows.
    def writeFixture(): Unit \ IO = {
        let file = Repository.Structure.FileId.FileId(0);
        let symbol = Repository.Structure.SymbolId.SymbolId(0);
        let world: Repository.World = {
            files = Vector#{"src/fixture.ts"},
            symbols = Vector#{{
                path = "src/fixture.ts", name = "fixture", startByte = 0, endByte = 7
            }},
            defines = Set#{(file, symbol)},
            imports = Set#{(file, file)},
            calls = Set#{(symbol, symbol)},
            parents = Set.empty(),
            unresolvedImports = 0,
            unresolvedCalls = 0
        };
        let identity: Repository.Table.Identity = {
            repository = property("attune.repository"),
            baseRevision = property("attune.base_revision"),
            sourceTreeIdentity = property("attune.source_tree_identity"),
            factIdentity = property("attune.fact_identity"),
            snapshotId = property("attune.snapshot_id")
        };
        let _ = Repository.Table.write(
            property("attune.world_metadata"),
            property("attune.world_entities"),
            property("attune.world_relations"),
            identity,
            world
        );
        println("ATLAS_FIXTURE snapshot=${identity#snapshotId}")
    }

    def printProtocol(): Unit \ IO = {
        let counts = Atlas.counts(7);
        println("atlas_protocol=atlas-composition-depth7-v1");
        println("signature_protocol=atlas-signature-swe-explore-v1");
        println("logical_programs=${counts#logical}");
        println("symbol_ending_programs=${counts#complete}")
    }

    def writeDynamicSignature(): Unit \ {FileSystem, IO} =
        match FileSystem.read(property("attune.world_identity")) |> Result.mapErr(ToString.toString) {
            case Err(error) => bug!(error)
            case Ok(payload) => match Repository.Identity.decode(payload) {
                case Err(error) => bug!(error)
                case Ok(identity) => writeSignatureFor(identity)
            }
        }

    def writeSignature(): Unit \ IO =
        writeSignatureFor({
            repository = property("attune.repository"),
            baseRevision = property("attune.base_revision"),
            sourceTreeIdentity = property("attune.source_tree_identity"),
            factIdentity = property("attune.fact_identity"),
            snapshotId = property("attune.snapshot_id")
        })

    def writeSignatureFor(worldIdentity: Repository.Table.Identity): Unit \ IO = {
        let snapshot: Atlas.Signature.Table.SnapshotIdentity = {
            signatureProtocol = "atlas-signature-swe-explore-v1",
            atlasProtocol = "atlas-composition-depth7-v1",
            repository = worldIdentity#repository,
            baseRevision = worldIdentity#baseRevision,
            sourceTreeIdentity = worldIdentity#sourceTreeIdentity,
            factIdentity = worldIdentity#factIdentity,
            snapshotId = worldIdentity#snapshotId
        };
        match Repository.Table.read(
            property("attune.world_metadata"),
            property("attune.world_entities"),
            property("attune.world_relations"),
            worldIdentity
        ) {
            case Err(error) => bug!(error)
            case Ok(world) => {
                let seeds = Atlas.Signature.seeds(world);
                match measure(snapshot, world, Vector.toList(seeds), {
                observations = Vector.empty(),
                physical = Vector.empty()
            }) {
                case Err(error) => bug!(error)
                case Ok(output) => {
                    let _ = ScientificTable.write(property("attune.output_observations"),
                        Atlas.Signature.Table.observations(), output#observations);
                    let _ = ScientificTable.write(property("attune.output_physical"),
                        Atlas.Signature.Table.physical(), output#physical);
                    let manifestCaseCount = Integer.parseInt(property("attune.manifest_case_count"));
                    let _ = ScientificTable.write(property("attune.output_snapshot"),
                        Atlas.Signature.Table.snapshots(), Vector#{
                            Atlas.Signature.Table.snapshotRow(snapshot, world, manifestCaseCount)
                        });
                    println("ATLAS_SIGNATURE snapshot=${worldIdentity#snapshotId}" +
                        " seeds=${Vector.length(seeds)}" +
                        " observations=${Vector.length(output#observations)}")
                }
            }
            }
        }
    }

    def measure(
        snapshot: Atlas.Signature.Table.SnapshotIdentity,
        world: Repository.World,
        seeds: List[Atlas.Signature.Seed],
        output: Output
    ): Result[String, Output] \ IO = match seeds {
        case Nil => Ok(output)
        case seed :: rest => forM (
            signature <- Atlas.signature(world, seed#state, 7);
            identity = {
                domain = seed#domain,
                identity = seed#identity,
                ordinal = seed#ordinal
            };
            observations = Atlas.Signature.Table.observationRows(snapshot, identity, signature);
            physical = Atlas.Signature.Table.physicalRow(snapshot, identity, signature);
            result <- measure(snapshot, world, rest, {
                observations = Vector.append(output#observations, observations),
                physical = Vector.append(output#physical, Vector#{physical})
            })
        ) yield result
    }

    def property(name: String): String \ IO = System.getProperty(name)
}
