/// One-time converter from retained Nix-addressed observation envelopes to
/// implementation-independent typed repository worlds. Nix supplies the old
/// frozen source tree only as an identity oracle. Grit is never executed.
mod MigrateWorld {
    import java.lang.Integer
    import java.lang.System

    use Fs.FileSystem
    use Sys.Env

    def main(): Unit \ {Env, FileSystem, IO} = {
        let index = match Env.getVar("ATTUNE_SCALE_WORLD_INDEX") {
            case None => -1
            case Some(value) => Integer.parseInt(value)
        };
        let workspace = Env.getVar("ATTUNE_WORKSPACE")
            |> Option.getWithDefault(System.getProperty("user.dir"));
        let _ = System.setProperty("user.dir", workspace);
        match Repository.Nix.runWithNative(() -> migrate(
            workspace, "${workspace}/.attune/repository-world-v1", index)) {
            case Err(message) => bug!(message)
            case Ok(identity) => println(
                "WORLD_MIGRATION index=${index}" +
                " repository=${identity#repository}" +
                " revision=${identity#baseRevision}" +
                " source_tree=${identity#sourceTreeIdentity}" +
                " fact_identity=${identity#factIdentity}" +
                " snapshot_id=${identity#snapshotId}" +
                " artifact_key=${ScientificIdentity.sha256(identity#snapshotId)}" +
                " exact=true")
        }
    }

    def migrate(
        workspace: String,
        root: String,
        index: Int32
    ): Result[String, Repository.Table.Identity] \ {FileSystem, IO, Repository.Nix.Acquire} = forM (
        _ <- if (index >= 0 and index < 78) Ok(())
            else Err("manifest index out of range: ${index}");
        case0 <- Repository.Nix.scaleCaseProjection(index) |> Result.mapErr(ToString.toString);
        _ <- if (case0#manifestIndex == index) Ok(())
            else Err("scale case index mismatch");
        historical = case0#population == "historical-development";
        retainedRoot = if (historical)
            "${workspace}/.attune/repository-facts-v1"
            else "${workspace}/.attune/repository-facts-js-ts-scale-v1";
        retainedPath = "${retainedRoot}/${case0#baseRevision}.parquet";
        exists <- FileSystem.exists(retainedPath) |> Result.mapErr(ToString.toString);
        _ <- if (exists) Ok(())
            else Err("retained repository observations missing: ${retainedPath}");
        // Retained observation replay and admission use file membership only.
        // Exact source bytes are already committed by sourceTreeIdentity.
        sources = Vector.map(path -> {path = path, content = ""}, case0#sourcePaths);
        gritIdentity = if (historical) legacyGritIdentity()
            else Repository.Grit.observationIdentity();
        observations <- Repository.decodeObservationsAtIdentity(
            case0#repository,
            case0#baseRevision,
            Repository.Nix.path(case0#snapshot),
            sources,
            gritIdentity,
            ScientificData.readObject(retainedPath)
        ) |> Result.mapErr(ToString.toString);
        world <- Repository.admitObserved(observations) |> Result.mapErr(ToString.toString);
        factIdentity = Repository.Table.factIdentity(
            case0#sourceTreeIdentity, gritIdentity, world);
        snapshotId = Repository.Table.snapshotIdentity(
            case0#repository, case0#baseRevision,
            case0#sourceTreeIdentity, factIdentity);
        identity = {
            repository = case0#repository,
            baseRevision = case0#baseRevision,
            sourceTreeIdentity = case0#sourceTreeIdentity,
            factIdentity = factIdentity,
            snapshotId = snapshotId
        };
        directory = "${root}/${ScientificIdentity.sha256(snapshotId)}";
        _ = Repository.Table.write(
            "${directory}/metadata.parquet",
            "${directory}/entities.parquet",
            "${directory}/relations.parquet",
            identity,
            world
        );
        _ <- writeBuild(directory, identity);
        replayed <- Repository.Table.read(
            "${directory}/metadata.parquet",
            "${directory}/entities.parquet",
            "${directory}/relations.parquet",
            identity
        );
        _ <- if (sameWorld(world, replayed)) Ok(())
            else Err("typed world round-trip changed ${case0#instanceId}");
        _ <- writeMarker(workspace, index, identity)
    ) yield identity

    /// Operational recovery marker, written only after the scientific tables
    /// have passed exact typed replay. It is not part of any scientific ID.
    def writeMarker(
        workspace: String,
        index: Int32,
        identity: Repository.Table.Identity
    ): Result[String, Unit] \ {FileSystem, IO} = {
        let path = "${workspace}/.attune/repository-world-migration-v1/${index}.done";
        let payload = identity#snapshotId + "\n" + ScientificIdentity.sha256(identity#snapshotId) + "\n";
        let written = run {
            FileSystem.write(str = payload, path)
        } with FileSystem.withMkParentDirs
          with FileSystem.withAtomicWrite;
        Result.mapErr(ToString.toString, written)
    }

    /// Generated graph projection. The Parquet metadata remains authoritative;
    /// this file only makes the immutable tables directly addressable by Bazel.
    def writeBuild(
        directory: String,
        identity: Repository.Table.Identity
    ): Result[String, Unit] \ FileSystem = {
        let payload =
            "load(\"//build:attune.bzl\", \"attune_atlas_signature\", \"attune_world_files\")\n\n" +
            "attune_world_files(\n" +
            "    name = \"world\",\n" +
            "    base_revision = \"${identity#baseRevision}\",\n" +
            "    entities = \"entities.parquet\",\n" +
            "    fact_identity = \"${identity#factIdentity}\",\n" +
            "    metadata = \"metadata.parquet\",\n" +
            "    relations = \"relations.parquet\",\n" +
            "    repository = \"${identity#repository}\",\n" +
            "    snapshot_id = \"${identity#snapshotId}\",\n" +
            "    source_tree_identity = \"${identity#sourceTreeIdentity}\",\n" +
            ")\n\n" +
            "attune_atlas_signature(\n" +
            "    name = \"signature\",\n" +
            "    tool = \"//experiments/atlas-swe-explore:signature\",\n" +
            "    world = \":world\",\n" +
            ")\n";
        let written = run {
            FileSystem.write(str = payload, "${directory}/BUILD.bazel")
        } with FileSystem.withMkParentDirs
          with FileSystem.withAtomicWrite;
        Result.mapErr(ToString.toString, written)
    }

    def sameWorld(left: Repository.World, right: Repository.World): Bool =
        left#files == right#files and
        Vector.map(symbol -> (symbol#path, symbol#name, symbol#startByte, symbol#endByte), left#symbols) ==
            Vector.map(symbol -> (symbol#path, symbol#name, symbol#startByte, symbol#endByte), right#symbols) and
        left#defines == right#defines and
        left#imports == right#imports and
        left#calls == right#calls and
        left#parents == right#parents and
        left#unresolvedImports == right#unresolvedImports and
        left#unresolvedCalls == right#unresolvedCalls

    def legacyGritIdentity(): String =
        "marzano-c80b3026471b229f41b279c3eb0c162dcdacfdb1" +
        ":defines-bba7b2aa5d958d3ea2369fae0b7025718d68fcd1ea10bdfc1351c676899552cb" +
        ":imports-368c1c09ed1ba38437ddab45d1084710cb717adc8dc0c831e3b2e8c49f3ad14d" +
        ":calls-de0e5436777fc93f96a517298386e5e728cd77fe5e46a027a5ae942287212147"
}
