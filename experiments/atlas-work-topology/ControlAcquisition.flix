/// Work-topology control acquisition (§2) over the repository's frozen polyglot
/// acquisition seam. The only new logic here is the inclusion record, derived
/// with the closure's own language table (`Repository.Grit.language`) rather
/// than a parallel lexical rule; everything downstream is the unchanged
/// `AcquisitionDriver` (`source -> Grit -> Repository.Grit.Fact ->
/// Repository.admit -> Repository.World`).
mod ControlAcquisition {
    import java.nio.file.{Files, Paths}

    /// Dispatch on the declared command. `acquire`/`summary` are delegated
    /// unchanged to the frozen parallelism acquisition driver.
    pub def execute(): Unit \ IO = match Experiment.property("attune.command") {
        case "acquire"          => AcquisitionDriver.execute()
        case "summary"          => AcquisitionDriver.execute()
        case "control_manifest" => manifest()
        case "control_verify"   => verify()
        case command            => bug!("unknown work-topology acquisition command: ${command}")
    }

    /// The admitted inclusion record (§2): a tracked path is admitted iff the
    /// closure's own table admits it, and the frozen `.attune` data tree is
    /// excluded by protocol. Paths are ASCII, so ordinal string order is the
    /// `LC_ALL=C` byte order.
    def manifest(): Unit \ IO = {
        let admitted = Vector.filter(admittedPath, lines(Experiment.property("attune.list")))
            |> Vector.sort;
        let _ = Files.writeString(Paths.get(Experiment.property("attune.files")), joinLines(admitted));
        println("CONTROL_MANIFEST files=${Vector.length(admitted)}")
    }

    def admittedPath(path: String): Bool =
        not String.startsWith(prefix = ".attune/", path) and Repository.Grit.language(path) != None

    def lines(path: String): Vector[String] \ IO =
        String.lines(Files.readString(Paths.get(path))) |> List.toVector
            |> Vector.filter(line -> String.length(String.trim(line)) > 0)

    def joinLines(values: Vector[String]): String =
        Vector.foldLeft((acc, value) -> "${acc}${value}\n", "", values)

    /// Exact-determinism check (§2): two consecutive acquisitions of the same
    /// worktree must be identical byte-for-byte and to the committed evidence,
    /// and the inclusion record must re-derive exactly. Any difference is a
    /// hard failure; a non-zero exit is the test's only verdict channel.
    def verify(): Unit \ IO = {
        let revisionLines = lines(Experiment.property("attune.revision_file"));
        let revision = if (Vector.isEmpty(revisionLines)) "" else Vector.get(0, revisionLines);
        let manifests = lines(Experiment.property("attune.files_committed"));
        // Re-admit the committed evidence through the canonical admission path:
        // a typed-schema mismatch, a drifted source hash or a fact range outside
        // its source is a hard failure here, never a warning.
        let world = Experiment.require(AcquisitionFacts.world(
            AcquisitionFacts.readSources(Experiment.property("attune.committed_sources")),
            AcquisitionFacts.readFacts(Experiment.property("attune.committed_facts"))));
        println("ADMITTED files=${Vector.length(world#files)} symbols=${Vector.length(world#symbols)} " +
            "defines=${Set.size(world#defines)} imports=${Set.size(world#imports)} calls=${Set.size(world#calls)} " +
            "unresolved_imports=${world#unresolvedImports} unresolved_calls=${world#unresolvedCalls}");
        let verdicts = Vector#{
            ("sources: run_a vs run_b", identical("attune.a_sources", "attune.b_sources")),
            ("facts:   run_a vs run_b", identical("attune.a_facts", "attune.b_facts")),
            ("sources: run_a vs committed", identical("attune.a_sources", "attune.committed_sources")),
            ("facts:   run_a vs committed", identical("attune.a_facts", "attune.committed_facts")),
            ("facts:   run_b vs committed", identical("attune.b_facts", "attune.committed_facts")),
            ("manifest: re-derived vs committed", identical("attune.files_rederived", "attune.files_committed")),
            ("admission: admitted files equal inclusion record", Vector.length(world#files) == Vector.length(manifests)),
            ("revision: exact control hash", revision == Experiment.property("attune.revision_expected"))
        };
        Vector.foldLeft((_, verdict) -> match verdict {
            case (label, ok) => if (ok) println("OK   ${label}") else println("FAIL ${label}")
        }, (), verdicts);
        let ok = Vector.foldLeft((acc, verdict) -> acc and snd(verdict), true, verdicts);
        if (ok) println("PASS: control re-acquisition is byte-identical with zero variance")
        else bug!("FAIL: control re-acquisition is not deterministic")
    }

    /// Byte identity through the JDK: a negative first-mismatch position is
    /// exactly "the two files are equal", with no decoding of binary Parquet.
    def identical(left: String, right: String): Bool \ IO = {
        let zero: Int64 = 0i64;
        let position = Files.mismatch(
            Paths.get(Experiment.property(left)),
            Paths.get(Experiment.property(right)));
        position < zero
    }
}
