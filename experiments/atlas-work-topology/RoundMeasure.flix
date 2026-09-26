/// Command surface for the Round 1 candidate measurement
/// (PREREGISTRATION.md §9, §10, §11; VAL-HC1-002, VAL-HC1-003).
///
/// `candidate_manifest` derives the candidate revision's admitted path list
/// with the one §2 admission rule; `candidate_sources` reads that revision's
/// worktree bytes and writes the (path, sha256, bytes, language) manifest.
/// Neither runs Grit and neither re-acquires a fact: the hill-climb keeps the
/// frozen semantic basis (§11, S1) and only classifies candidate paths by
/// content identity. `measure` then writes the round's identity map, static
/// work-topology and signature-preservation oracle; `verify` re-derives all
/// three from the committed evidence and fails on any drift.
mod RoundMeasure {
    import java.nio.file.{Files, Paths}

    pub def execute(): Unit \ IO = match Experiment.property("attune.command") {
        case "candidate_manifest" => manifest()
        case "candidate_sources"  => sources()
        case "measure"            => measure()
        case "verify"             => verify()
        case command              => bug!("unknown round measurement command: ${command}")
    }

    // ---- candidate admitted manifest and source hashes ----

    def manifest(): Unit \ IO = {
        let admitted = ControlMap.admittedManifest(lines(Experiment.property("attune.list")));
        let _ = Files.writeString(Paths.get(Experiment.property("attune.files")), joinLines(admitted));
        println("ROUND_MANIFEST files=${Vector.length(admitted)}")
    }

    def sources(): Unit \ IO = {
        let root = Experiment.property("attune.root");
        let paths = lines(Experiment.property("attune.manifest"));
        let rows = Vector.map(path -> sourceRow(root, path), paths);
        let _ = Files.writeString(Paths.get(Experiment.property("attune.sources")), joinLines(rows));
        println("ROUND_SOURCES root=${root} files=${Vector.length(rows)}")
    }

    def sourceRow(root: String, path: String): String \ IO = {
        let content = Files.readString(Paths.get(root + "/" + path));
        let hash = ScientificIdentity.sha256(content);
        let bytes = Vector.length(String.toBytes(content));
        "${path}\t${hash}\t${bytes}\t${languageOf(path)}"
    }

    def languageOf(path: String): String = match Repository.Grit.language(path) {
        case None => "none"
        case Some(language) => Repository.Grit.name(language)
    }

    // ---- the three round documents ----

    pub type alias Documents = {
        identity  = String,
        topology  = String,
        oracle    = String,
        round0    = RoundIdentity.Round,
        control   = ControlSignature.Landmarks,
        candidate = ControlSignature.Landmarks
    }

    /// Re-derive every round document from the committed evidence. The
    /// candidate basis is the frozen control evidence at candidate paths, so
    /// the whole derivation is pure over committed artifacts.
    def documents(): Documents \ IO = {
        let controlRevision = String.trim(Files.readString(Paths.get(Experiment.property("attune.control_revision"))));
        let revision = String.trim(Files.readString(Paths.get(Experiment.property("attune.revision"))));
        let controlSources = AcquisitionFacts.readSources(Experiment.property("attune.control_sources"));
        let controlFacts = AcquisitionFacts.readFacts(Experiment.property("attune.control_facts"));
        let world = ControlSignature.world(Experiment.property("attune.control_sources"), Experiment.property("attune.control_facts"));
        let roundPaths = lines(Experiment.property("attune.files"));
        let roundHashes = hashesOf(lines(Experiment.property("attune.sources")));
        let round0 = RoundIdentity.round(controlSources, controlFacts, roundPaths, roundHashes);
        let mapping = RoundIdentity.mapping(round0);
        let candidateWorld = RoundOracle.candidateWorld(round0, controlSources, controlFacts);
        let control = RoundOracle.landmarks(world);
        let candidate = RoundOracle.landmarksWith(candidateWorld,
            RoundOracle.translatedSeeds(world, candidateWorld, mapping));
        {
            identity = RoundJson.identityJson(revision, controlRevision, Vector.length(roundPaths), round0),
            topology = RoundJson.topologyJson(revision, controlRevision, Vector.length(roundPaths), round0, world, mapping),
            oracle = RoundJson.oracleJson(revision, controlRevision, controlSources, controlFacts, world, candidateWorld, round0, control, candidate),
            round0 = round0,
            control = control,
            candidate = candidate
        }
    }

    def measure(): Unit \ IO = {
        let document = documents();
        let _ = Files.writeString(Paths.get(Experiment.property("attune.output_identity")), document#identity);
        let _ = Files.writeString(Paths.get(Experiment.property("attune.output_topology")), document#topology);
        let _ = Files.writeString(Paths.get(Experiment.property("attune.output_oracle")), document#oracle);
        report(document);
        let role = Experiment.property("attune.role");
        let revision = String.trim(Files.readString(Paths.get(Experiment.property("attune.revision"))));
        println("ROUND_MEASURE role=${role} revision=${revision} identity_bytes=${String.length(document#identity)} " +
            "topology_bytes=${String.length(document#topology)} oracle_bytes=${String.length(document#oracle)}")
    }

    /// Read-only: re-derive all three documents and fail on any drift.
    def verify(): Unit \ IO = {
        let document = documents();
        let committedIdentity = Files.readString(Paths.get(Experiment.property("attune.output_identity")));
        let committedTopology = Files.readString(Paths.get(Experiment.property("attune.output_topology")));
        let committedOracle = Files.readString(Paths.get(Experiment.property("attune.output_oracle")));
        let comparisons = allComparisons(document);
        let verdicts = Vector#{
            ("identity map: re-derived equals committed", document#identity == committedIdentity),
            ("topology: re-derived equals committed", document#topology == committedTopology),
            ("oracle: re-derived equals committed", document#oracle == committedOracle),
            ("oracle: every signature comparison passes",
                Vector.forAll(comparison -> comparison#ok, comparisons)),
            ("identity: every control identity survives or is reported",
                Vector.isEmpty(document#round0#collisions) and Vector.isEmpty(document#round0#dropped)),
            ("identity: no admitted production source changed content",
                Vector.isEmpty(RoundOracle.productionDrift(document#round0)))
        };
        Vector.foldLeft((_, verdict) -> match verdict {
            case (label, ok) => if (ok) println("OK   ${label}") else println("FAIL ${label}")
        }, (), verdicts);
        if (Vector.forAll(match (_, ok) -> ok, verdicts))
            println("PASS: round documents re-derive exactly and the signature oracle holds")
        else
            bug!("FAIL: round measurement verification")
    }

    def allComparisons(document: Documents): Vector[RoundOracle.Comparison] =
        Vector.append(RoundOracle.landmarkComparisons(document#control, document#candidate),
            Vector#{RoundOracle.reachComparison(document#control, document#candidate)})

    def report(document: Documents): Unit \ IO = {
        let stable = countOf(document, "stable");
        let modified = countOf(document, "modified");
        let moved = countOf(document, "moved");
        let dropped = countOf(document, "dropped");
        println("ROUND_IDENTITY control_basis=${Vector.length(document#round0#entries)} stable=${stable} " +
            "modified=${modified} moved=${moved} dropped=${dropped} new=${Vector.length(document#round0#newPaths)} " +
            "collisions=${Vector.length(document#round0#collisions)}");
        Vector.foldLeft((_, comparison) -> println("ROUND_COMPARISON ${comparison#metric} " +
            "control=${comparison#control} candidate=${comparison#candidate} delta=${comparison#delta} " +
            "threshold=${comparison#threshold} ok=${comparison#ok}"), (), allComparisons(document));
        println("ROUND_SIGNATURE_OK ${Vector.forAll(comparison -> comparison#ok, allComparisons(document))}")
    }

    def countOf(document: Documents, movement: String): Int32 =
        Vector.count(entry -> entry#movement == movement, document#round0#entries)

    // ---- text plumbing ----

    def lines(path: String): Vector[String] \ IO =
        String.lines(Files.readString(Paths.get(path))) |> List.toVector
            |> Vector.filter(line -> String.length(String.trim(line)) > 0)
            |> Vector.filter(line -> not String.startsWith(prefix = "#", line))

    def joinLines(values: Vector[String]): String =
        Vector.foldLeft((acc, value) -> "${acc}${value}\n", "", values)

    /// The candidate `path -> sha256` table from the `candidate_sources` TSV.
    def hashesOf(rows: Vector[String]): Map[String, String] =
        Vector.foldLeft((acc, row) -> match String.splitOn(substr = "\t", row) {
            case path :: hash :: _ :: _ :: Nil => Map.insert(path, hash, acc)
            case _ => acc
        }, Map.empty(), rows)
}
