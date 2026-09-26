/// The control specimen's Atlas depth-response curve (PREREGISTRATION.md §3).
///
/// The instrument re-admits the committed control evidence through ordinary
/// `Repository.admit`, evaluates the frozen composition-only Atlas family
/// (`atlas-composition-depth7-v1`) over the frozen `atlas-signature-seeds-v1`
/// panel at depth 7, and writes the two typed signature tables plus the logical
/// identity map of §9:
///
///   control.signatures.parquet  attune-atlas-signature-observations-v1
///   control.summaries.parquet   attune-atlas-signature-summary-v1
///                               (summary reductions + physical work + mixing
///                               landmarks)
///   control.identity_map.json   logical_id, control_path, current_path,
///                               control_region, ownership_cell
///
/// No grammar, atom or evaluator is added: every number comes from the frozen
/// `Atlas.evaluate` over the re-admitted world. `compute` writes the artifacts;
/// `verify` independently re-derives them from the committed evidence and fails
/// (non-zero exit) on any drift, so the identity map and the mixing landmarks
/// are exact rather than asserted.
mod ControlSignature {
    import java.nio.file.{Files, Paths}
    use ScientificTable.Value

    pub def signatureProtocol(): String = "atlas-signature-work-topology-v1"
    pub def atlasProtocol(): String = "atlas-composition-depth7-v1"
    pub def maxDepth(): Int32 = 7

    pub def execute(): Unit \ IO = match Experiment.property("attune.command") {
        case "compute" => compute()
        case "verify"  => verify()
        case command   => bug!("unknown control signature command: ${command}")
    }

    // ---- The control world ----

    /// Re-admit the committed control evidence as the canonical typed basis.
    /// Every fact must name an admitted source and lie inside it, so the
    /// signature is measured over the same world the acquisition froze.
    pub def world(sourcesPath: String, factsPath: String): Repository.World \ IO =
        Experiment.require(AcquisitionFacts.world(
            AcquisitionFacts.readSources(sourcesPath),
            AcquisitionFacts.readFacts(factsPath)))

    pub type alias WorldIdentity = {
        revision           = String,
        sourceTreeIdentity = String,
        factIdentity       = String,
        snapshotId         = String
    }

    /// The control world's content-addressed identity, derived exactly as the
    /// acquisition seam derives it for a Grit-acquired revision.
    pub def identityOf(revision: String, world: Repository.World): WorldIdentity \ IO = {
        let sourceTreeIdentity = "attuneflix-source-tree-v2:" + revision;
        let factIdentity = Repository.Table.factIdentity(sourceTreeIdentity, AcquisitionFacts.gritIdentity(), world);
        let snapshotId = Repository.Table.snapshotIdentity("attuneflix", revision, sourceTreeIdentity, factIdentity);
        {
            revision = revision,
            sourceTreeIdentity = sourceTreeIdentity,
            factIdentity = factIdentity,
            snapshotId = snapshotId
        }
    }

    pub def snapshotIdentity(identity: WorldIdentity): Atlas.Signature.Table.SnapshotIdentity = {
        signatureProtocol = signatureProtocol(),
        atlasProtocol = atlasProtocol(),
        repository = "attuneflix",
        baseRevision = identity#revision,
        sourceTreeIdentity = identity#sourceTreeIdentity,
        factIdentity = identity#factIdentity,
        snapshotId = identity#snapshotId
    }

    // ---- The depth-response curve ----

    /// One full depth-7 signature per frozen seed (8 File seeds and 8 Symbol
    /// seeds through `Atlas.Signature.seeds`, fewer only if a domain is small).
    pub def signatures(world: Repository.World): Vector[(Atlas.Signature.Seed, Atlas.Signature.Signature)] \ IO =
        Vector.map(seed -> (seed, Experiment.require(
            Atlas.Signature.compute(world, seed#state, maxDepth()))),
            Atlas.Signature.seeds(world))

    /// One observation row per seed × logical route, in the frozen schema.
    pub def observationRows(
        snapshot: Atlas.Signature.Table.SnapshotIdentity,
        computed: Vector[(Atlas.Signature.Seed, Atlas.Signature.Signature)]
    ): Vector[ScientificTable.Row] \ IO =
        Vector.flatMap(match (seed, signature) ->
            Atlas.Signature.Table.observationRows(snapshot, seed, signature), computed)

    // ---- Mixing landmarks D50 / D80 / D90 / D95 ----

    pub type alias Landmarks = {
        meanCoverage = Vector[Float64],
        depth7Reach  = Float64,
        d50          = Int32,
        d80          = Int32,
        d90          = Int32,
        d95          = Int32
    }

    /// `mean_coverage(d)` over the File seed panel and the first depth reaching
    /// 50%, 80%, 90% and 95%. `reach_d(f)` is cumulative (every route of length
    /// ≤ d) and `members` sends a symbol state to its declaring file, exactly as
    /// §3 defines it. `none` (the curve never reaches the threshold) is encoded
    /// as `maxDepth + 1` so drift is always an integer comparison.
    pub def landmarks(
        world: Repository.World,
        computed: Vector[(Atlas.Signature.Seed, Atlas.Signature.Signature)]
    ): Landmarks = {
        let fileCount = Vector.length(world#files);
        let reaches = Vector.filterMap(match (seed, signature) ->
            if (seed#domain == Radii.Domain.File) Some(cumulativeReach(world, signature)) else None,
            computed);
        let panel = Vector.length(reaches);
        let meanCoverage = if (panel == 0)
            Vector.map(_ -> 0.0, Vector.range(1, 8))
        else
            Vector.map(depth -> Vector.foldLeft((total, perSeed) ->
                total + ScientificTable.ratio(Set.size(Vector.get(depth - 1, perSeed)), fileCount),
                0.0, reaches) / Int32.toFloat64(panel),
                Vector.range(1, 8));
        {
            meanCoverage = meanCoverage,
            depth7Reach = Vector.get(6, meanCoverage),
            d50 = landmark(meanCoverage, 0.50),
            d80 = landmark(meanCoverage, 0.80),
            d90 = landmark(meanCoverage, 0.90),
            d95 = landmark(meanCoverage, 0.95)
        }
    }

    def landmark(meanCoverage: Vector[Float64], threshold: Float64): Int32 = {
        let found = Vector.foldLeft((state, depth) ->
            if (state == 0 and Vector.get(depth - 1, meanCoverage) >= threshold) depth else state,
            0, Vector.range(1, 8));
        if (found == 0) maxDepth() + 1 else found
    }

    /// The cumulative file reach of one File seed, indexed by depth 1..7.
    def cumulativeReach(world: Repository.World, signature: Atlas.Signature.Signature): Vector[Set[String]] = {
        let zero: Vector[Set[String]] = Vector.empty();
        Vector.foldLeft((acc, depth) -> {
            let added = Vector.filter(observation -> observation#depth == depth, signature#observations)
                |> Vector.foldLeft((union0, observation) ->
                    Set.union(union0, stateMembers(world, observation#output)), Set.empty());
            let previous = if (Vector.isEmpty(acc)) Set.empty() else Vector.get(Vector.length(acc) - 1, acc);
            Vector.append(acc, Vector#{Set.union(previous, added)})
        }, zero, Vector.range(1, 8))
    }

    /// File members of a state; symbol members project to the declaring file.
    def stateMembers(world: Repository.World, state: Atlas.State): Set[String] = match state {
        case Atlas.State.Files(ids) => Set.map(id -> fileIdentity(world, id), ids)
        case Atlas.State.Symbols(ids) => Set.map(id -> symbolFile(world, id), ids)
    }

    def fileIdentity(world: Repository.World, id: Repository.Structure.FileId): String =
        let Repository.Structure.FileId.FileId(index) = id;
        Vector.get(index, world#files)

    def symbolFile(world: Repository.World, id: Repository.Structure.SymbolId): String =
        let Repository.Structure.SymbolId.SymbolId(index) = id;
        Vector.get(index, world#symbols)#path

    // ---- Summary rows: reductions, physical work, landmarks ----

    /// The frozen summary reductions plus the physical-work and mixing-landmark
    /// rows, all in the one declared summary schema. A physical row carries the
    /// logical/physical work totals and a landmark row the reach curve and the
    /// four named depths, so the whole depth-response curve is readable from a
    /// single typed table.
    pub def summaryRows(
        snapshot: Atlas.Signature.Table.SnapshotIdentity,
        computed: Vector[(Atlas.Signature.Seed, Atlas.Signature.Signature)],
        observations: Vector[ScientificTable.Row],
        landmarks0: Landmarks
    ): Vector[ScientificTable.Row] =
        Vector.append(Experiment.require(Atlas.Signature.Summary.summarize(observations)),
            Vector.append(physicalRows(snapshot, computed), landmarkRows(snapshot, landmarks0)))

    pub def physicalRows(
        snapshot: Atlas.Signature.Table.SnapshotIdentity,
        computed: Vector[(Atlas.Signature.Seed, Atlas.Signature.Signature)]
    ): Vector[ScientificTable.Row] =
        Vector.flatMap(domain -> physicalRowsFor(snapshot, computed, domain), Vector#{"file", "symbol"})

    def physicalRowsFor(
        snapshot: Atlas.Signature.Table.SnapshotIdentity,
        computed: Vector[(Atlas.Signature.Seed, Atlas.Signature.Signature)],
        domain: String
    ): Vector[ScientificTable.Row] = {
        let selected = Vector.map(match (_, signature) -> signature,
            Vector.filter(match (seed, _) -> Atlas.Signature.domainName(seed#domain) == domain, computed));
        let logical = Vector.foldLeft((total, signature) -> total + signature#logicalPrograms, 0, selected);
        let unique = Vector.foldLeft((total, signature) -> total + signature#uniqueStates, 0, selected);
        let evaluations = Vector.foldLeft((total, signature) -> total + signature#physicalTransitions, 0, selected);
        let reuses = Vector.foldLeft((total, signature) -> total + signature#transitionReuses, 0, selected);
        Vector.map(match (metric, value) -> metricRow(snapshot, "physical_work", domain, None, None, metric,
            value, Vector.length(selected)), Vector#{
            ("logical_routes", Int32.toFloat64(logical)),
            ("unique_semantic_states", Int32.toFloat64(unique)),
            ("physical_transition_requests", Int32.toFloat64(evaluations + reuses)),
            ("physical_transition_evaluations", Int32.toFloat64(evaluations)),
            ("physical_transition_reuses", Int32.toFloat64(reuses)),
            ("memo_cells", Int32.toFloat64(evaluations)),
            ("logical_per_unique_state", ScientificTable.ratio(logical, unique)),
            ("logical_per_physical_evaluation", ScientificTable.ratio(logical, evaluations))
        })
    }

    pub def landmarkRows(
        snapshot: Atlas.Signature.Table.SnapshotIdentity,
        landmarks0: Landmarks
    ): Vector[ScientificTable.Row] = {
        let coverageRows = Vector.mapWithIndex((index, value) ->
            metricRow(snapshot, "mixing_landmark", "file", None, None,
                "mean_coverage_d${index + 1}", value, 8),
            landmarks0#meanCoverage);
        let namedRows = Vector.map(match (metric, value) ->
            metricRow(snapshot, "mixing_landmark", "file", None, None, metric, value, 8), Vector#{
            ("D50", Int32.toFloat64(landmarks0#d50)),
            ("D80", Int32.toFloat64(landmarks0#d80)),
            ("D90", Int32.toFloat64(landmarks0#d90)),
            ("D95", Int32.toFloat64(landmarks0#d95)),
            ("depth7_reach", landmarks0#depth7Reach)
        });
        Vector.append(coverageRows, namedRows)
    }

    def metricRow(
        snapshot: Atlas.Signature.Table.SnapshotIdentity,
        scope: String,
        domain: String,
        depth: Option[Int32],
        lastAtom: Option[String],
        metric: String,
        value: Float64,
        sampleCount: Int32
    ): ScientificTable.Row = Map#{
        "signature_protocol" => Value.Text(snapshot#signatureProtocol),
        "atlas_protocol" => Value.Text(snapshot#atlasProtocol),
        "repository" => Value.Text(snapshot#repository),
        "base_revision" => Value.Text(snapshot#baseRevision),
        "source_tree_identity" => Value.Text(snapshot#sourceTreeIdentity),
        "fact_identity" => Value.Text(snapshot#factIdentity),
        "snapshot_id" => Value.Text(snapshot#snapshotId),
        "scope" => Value.Text(scope),
        "seed_domain" => Value.Text(domain),
        "depth" => ScientificTable.optionalInt32Value(depth),
        "last_atom" => ScientificTable.optionalTextValue(lastAtom),
        "metric" => Value.Text(metric),
        "value" => Value.Float64(value),
        "sample_count" => Value.Int64(Int32.toInt64(sampleCount))
    }

    // ---- Commands ----

    /// `compute`: write the two typed signature tables and the identity map into
    /// the source tree (a `bazel run` command of record).
    def compute(): Unit \ IO = {
        let sources = AcquisitionFacts.readSources(Experiment.property("attune.sources"));
        let facts = AcquisitionFacts.readFacts(Experiment.property("attune.facts"));
        let world0 = Experiment.require(AcquisitionFacts.world(sources, facts));
        let revision = String.trim(Files.readString(Paths.get(Experiment.property("attune.revision"))));
        let snapshot = snapshotIdentity(identityOf(revision, world0));
        let computed = signatures(world0);
        let observations = observationRows(snapshot, computed);
        let landmarks0 = landmarks(world0, computed);
        let summaries = summaryRows(snapshot, computed, observations, landmarks0);
        let entries = ControlIdentity.entries(sources, facts);
        let _ = ScientificTable.write(Experiment.property("attune.output_signatures"),
            Atlas.Signature.Table.observations(), observations);
        let _ = ScientificTable.write(Experiment.property("attune.output_summaries"),
            Atlas.Signature.Summary.schema(), summaries);
        let _ = Files.writeString(Paths.get(Experiment.property("attune.output_identity")),
            ControlIdentity.json(entries));
        Vector.foldLeft((_, entry) -> match entry {
            case (key, value) => println("SUMMARY_METRIC ${key} ${value}")
        }, (), Vector#{
            ("seeds", Int32.toFloat64(Vector.length(computed))),
            ("observations", Int32.toFloat64(Vector.length(observations))),
            ("summaries", Int32.toFloat64(Vector.length(summaries))),
            ("identities", Int32.toFloat64(Vector.length(entries))),
            ("D50", Int32.toFloat64(landmarks0#d50)),
            ("D80", Int32.toFloat64(landmarks0#d80)),
            ("D90", Int32.toFloat64(landmarks0#d90)),
            ("D95", Int32.toFloat64(landmarks0#d95)),
            ("depth7_reach", landmarks0#depth7Reach)
        });
        println("CONTROL_SIGNATURE revision=${revision} files=${Vector.length(world0#files)} " +
            "logical_ids=${ControlIdentity.distinctIdentities(entries)}")
    }

    /// `verify`: independently re-derive the landmarks and the identity map from
    /// the committed evidence, compare them with the committed artifacts, and
    /// fail (non-zero exit) on any drift. Read-only.
    def verify(): Unit \ IO = {
        let sources = AcquisitionFacts.readSources(Experiment.property("attune.sources"));
        let facts = AcquisitionFacts.readFacts(Experiment.property("attune.facts"));
        let world0 = Experiment.require(AcquisitionFacts.world(sources, facts));
        let revision = String.trim(Files.readString(Paths.get(Experiment.property("attune.revision"))));
        let snapshot = snapshotIdentity(identityOf(revision, world0));
        let computed = signatures(world0);
        let observations = observationRows(snapshot, computed);
        let landmarks0 = landmarks(world0, computed);
        let entries = ControlIdentity.entries(sources, facts);
        let committedIdentity = Files.readString(Paths.get(Experiment.property("attune.identity")));
        let committedSignatures = ScientificTable.read(Experiment.property("attune.signatures"),
            Atlas.Signature.Table.observations());
        let committedSummaries = ScientificTable.read(Experiment.property("attune.summaries"),
            Atlas.Signature.Summary.schema());
        let dMetrics = Vector#{("D50", landmarks0#d50), ("D80", landmarks0#d80),
            ("D90", landmarks0#d90), ("D95", landmarks0#d95)};
        let verdicts = Vector#{
            ("identity: re-derived equals committed",
                ControlIdentity.json(entries) == committedIdentity),
            ("identity: logical ids are unique",
                ControlIdentity.distinctIdentities(entries) == Vector.length(entries)),
            ("identity: every file has a region and a cell",
                Vector.forAll(entry -> String.length(entry#controlRegion) > 0 and String.length(entry#ownershipCell) > 0,
                    entries)),
            ("signature: observation row count",
                Vector.length(committedSignatures) == Vector.length(observations)),
            ("signature: full depth 1..7 histogram",
                depthHistogram(committedSignatures) == Vector.map(level -> 16 * level,
                    Vector#{3, 9, 27, 81, 243, 729, 2187})),
            ("summary: all seven mean-coverage depths",
                Vector.forAll(depth -> metricValue(committedSummaries, "mixing_landmark", "file",
                    "mean_coverage_d${depth}") == Some(Vector.get(depth - 1, landmarks0#meanCoverage)),
                    Vector.range(1, 8))),
            ("summary: D50/D80/D90/D95 match the re-derived landmarks",
                Vector.forAll(match (metric, value) ->
                    metricValue(committedSummaries, "mixing_landmark", "file", metric) == Some(Int32.toFloat64(value)),
                    dMetrics)),
            ("summary: depth-7 reach matches",
                metricValue(committedSummaries, "mixing_landmark", "file", "depth7_reach") == Some(landmarks0#depth7Reach)),
            ("summary: physical work recorded for both seed domains",
                Vector.forAll(domain -> Vector.forAll(metric ->
                    positive(metricValue(committedSummaries, "physical_work", domain, metric)),
                    Vector#{"logical_routes", "unique_semantic_states",
                        "physical_transition_evaluations", "physical_transition_reuses"}),
                    Vector#{"file", "symbol"}))
        };
        Vector.foldLeft((_, verdict) -> match verdict {
            case (label, ok) => if (ok) println("OK   ${label}") else println("FAIL ${label}")
        }, (), verdicts);
        if (Vector.forAll(match (_, ok) -> ok, verdicts))
            println("PASS: control signature, landmarks and identity map re-derive exactly")
        else
            bug!("FAIL: control signature verification")
    }

    /// Observation counts by depth 1..7 for the committed signature table.
    def depthHistogram(rows: Vector[ScientificTable.Row]): Vector[Int32] =
        Vector.map(depth -> Vector.count(row -> int32Of(row, "depth") == Some(depth), rows), Vector.range(1, 8))

    def metricValue(rows: Vector[ScientificTable.Row], scope: String, domain: String, metric: String): Option[Float64] =
        Vector.foldLeft((found, row) -> match found {
            case Some(_) => found
            case None =>
                if (textOf(row, "scope") == Some(scope) and textOf(row, "seed_domain") == Some(domain)
                    and textOf(row, "metric") == Some(metric))
                    floatOf(row, "value")
                else None
        }, None, rows)

    def positive(value: Option[Float64]): Bool = match value {
        case Some(number) => number > 0.0
        case None => false
    }

    def textOf(row: ScientificTable.Row, name: String): Option[String] = match Map.get(name, row) {
        case Some(Value.Text(value)) => Some(value)
        case _ => None
    }

    def floatOf(row: ScientificTable.Row, name: String): Option[Float64] = match Map.get(name, row) {
        case Some(Value.Float64(value)) => Some(value)
        case _ => None
    }

    def int32Of(row: ScientificTable.Row, name: String): Option[Int32] = match Map.get(name, row) {
        case Some(Value.Int32(value)) => Some(value)
        case _ => None
    }
}
