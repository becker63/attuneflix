/// Command surface for the control work-topology measurement
/// (PREREGISTRATION.md §6, §7, §8; VAL-TOPOLOGY-001/-002/-004).
///
/// `measure` re-admits the committed control evidence, computes the static
/// work-topology (BASIS cuts and cells, ATLAS overlap and blast) and the
/// co-change work graph, and writes `control.topology.json` and
/// `control.cochange.json` into the source tree.
///
/// `verify` independently re-derives both documents from the committed evidence
/// and fails (non-zero exit) on any drift, so the frozen numbers are exact
/// rather than asserted.
mod ControlMeasure {
    import java.nio.file.{Files, Paths}

    pub def execute(): Unit \ IO = match Experiment.property("attune.command") {
        case "measure" => measure()
        case "verify"  => verify()
        case command   => bug!("unknown control measurement command: ${command}")
    }

    def readText(path: String): String \ IO = Files.readString(Paths.get(path))

    def readTrimmed(path: String): String \ IO = String.trim(Files.readString(Paths.get(path)))

    /// The admitted control file set, one sorted path per line.
    def admittedPaths(path: String): Set[String] \ IO =
        String.lines(readText(path))
            |> List.map(String.trim)
            |> List.filter(line -> String.length(line) > 0)
            |> List.toVector
            |> Vector.toSet

    def world(): Repository.World \ IO =
        ControlSignature.world(Experiment.property("attune.sources"), Experiment.property("attune.facts"))

    def commits(): Vector[ControlCoChange.Commit] \ IO =
        ControlCoChange.parseHistory(readText(Experiment.property("attune.cochange_history")))

    // ---- measure ----

    def measure(): Unit \ IO = {
        let world0 = world();
        let sources = AcquisitionFacts.readSources(Experiment.property("attune.sources"));
        let admitted = admittedPaths(Experiment.property("attune.files"));
        let revision = readTrimmed(Experiment.property("attune.revision"));
        let history = commits();
        let topology = ControlTopologyJson.json(revision, sources, world0);
        let cochange = ControlCoChange.json(revision, history, admitted, world0);
        let _ = Files.writeString(Paths.get(Experiment.property("attune.output_topology")), topology);
        let _ = Files.writeString(Paths.get(Experiment.property("attune.output_cochange")), cochange);
        report(world0);
        reportCoChange(history, admitted);
        println("CONTROL_TOPOLOGY revision=${revision} files=${Vector.length(world0#files)} " +
            "topology_bytes=${String.length(topology)} cochange_bytes=${String.length(cochange)}")
    }

    def report(world0: Repository.World): Unit \ IO = {
        let edges = ControlTopology.regionEdges(world0);
        let useEdges = Vector.length(edges);
        let cut = ControlTopology.cellCut(ControlTopology.cellEdges(world0));
        Vector.foldLeft((_, entry) -> match entry {
            case (k, cross) =>
                println("CUT k=${k} cross=${cross} fraction=${ScientificTable.ratio(cross, useEdges)}")
        }, (), ControlTopology.cutCounts(world0));
        println("TOPOLOGY use_edges=${useEdges} non_empty_regions=${Vector.length(ControlTopology.nonEmptyRegions(world0))} " +
            "cell_cut_4=${cut#fraction} shared_hotspots=${Vector.length(ControlTopology.hotspotFiles(world0))} " +
            "max_hotspot_pressure=${ControlTopology.maxHotspotPressure(world0)} " +
            "median_file_blast=${ControlTopology.percentile(ControlTopology.fileBlasts(world0), 50)} " +
            "p90_file_blast=${ControlTopology.percentile(ControlTopology.fileBlasts(world0), 90)}")
    }

    def reportCoChange(history: Vector[ControlCoChange.Commit], admitted: Set[String]): Unit \ IO = {
        let entries = Map.toVector(ControlCoChange.graph(history, admitted));
        let total = ControlCoChange.totalRaw(entries);
        let cross = Vector.foldLeft((acc, entry) -> match entry {
            case ((a, b), weight) =>
                if (ControlMap.regionOf(a) != ControlMap.regionOf(b)) acc + weight#raw else acc
        }, 0, entries);
        println("COCHANGE commits=${Vector.length(history)} " +
            "commits_touching_admitted=${ControlCoChange.commitsTouchingAdmitted(history, admitted)} " +
            "pairs=${Vector.length(entries)} total_raw=${total} cross_region_raw_ratio=${ScientificTable.ratio(cross, total)} " +
            "total_line_weighted=${ControlCoChange.totalLineWeighted(entries)}")
    }

    // ---- verify ----

    def verify(): Unit \ IO = {
        let world0 = world();
        let sources = AcquisitionFacts.readSources(Experiment.property("attune.sources"));
        let admitted = admittedPaths(Experiment.property("attune.files"));
        let revision = readTrimmed(Experiment.property("attune.revision"));
        let history = commits();
        let topology = ControlTopologyJson.json(revision, sources, world0);
        let cochange = ControlCoChange.json(revision, history, admitted, world0);
        let committedTopology = readText(Experiment.property("attune.topology"));
        let committedCochange = readText(Experiment.property("attune.cochange"));
        let edges = ControlTopology.regionEdges(world0);
        let entries = Map.toVector(ControlCoChange.graph(history, admitted));
        let cuts = ControlTopology.cutCounts(world0);
        let verdicts = Vector#{
            ("topology: re-derived document equals the committed artifact", topology == committedTopology),
            ("cochange: re-derived document equals the committed artifact", cochange == committedCochange),
            ("cuts: nine k values covering 2..10",
                Vector.length(cuts) == 9 and Vector.forAll(match (k, _) -> k >= 2 and k <= 10, cuts)),
            ("cuts: every fraction is bounded by the use-edge count",
                Vector.forAll(match (_, cross) -> cross >= 0 and cross <= Vector.length(edges), cuts)),
            ("regions: every admitted file has a region and a cell",
                Vector.forAll(path -> String.length(ControlMap.regionOf(path)) > 0
                    and String.length(ControlMap.cellOf(path)) > 0, world0#files)),
            ("basis: the control world admits use edges", Vector.length(edges) > 0),
            ("cochange: the committed history yields co-change pairs", Vector.length(entries) > 0),
            ("cochange: raw, normalized and line-weighted masses are all positive",
                ControlCoChange.totalRaw(entries) > 0 and ControlCoChange.totalNormalized(entries) > 0.0
                    and ControlCoChange.totalLineWeighted(entries) > 0)
        };
        Vector.foldLeft((_, verdict) -> match verdict {
            case (label, ok) => if (ok) println("OK   ${label}") else println("FAIL ${label}")
        }, (), verdicts);
        if (Vector.forAll(match (_, ok) -> ok, verdicts))
            println("PASS: control topology and co-change re-derive exactly")
        else
            bug!("FAIL: control topology verification")
    }
}
