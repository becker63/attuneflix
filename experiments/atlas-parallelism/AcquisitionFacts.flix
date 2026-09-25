/// The v2 acquisition artifacts (PREREGISTRATION.md "AMENDMENT — v2
/// acquisition"): the two typed tables that carry one frozen revision's
/// Grit-acquired observations into the measurement graph.
///
/// `sources` is the exact inclusion record of a revision (path, sha256, byte
/// length, language). `facts` is the Grit evidence (one row per emitted
/// `Repository.Grit.Fact`, per file and relation program). The measurement
/// graph re-admits those facts through ordinary `Repository.admit`, so what it
/// measures is the canonical admitted basis — never a second experiment graph.
mod AcquisitionFacts {
    use ScientificTable.Value
    use ScientificTable.Columns.{text, int32}

    /// One admitted source file of a frozen revision.
    pub type alias Source = {
        path     = String,
        sha256   = String,
        bytes    = Int32,
        language = String
    }

    /// One Grit fact, tied to the exact source bytes it was acquired from.
    pub type alias FactRow = {
        path         = String,
        sourceSha256 = String,
        language     = String,
        program      = String,
        kind         = String,
        startByte    = Int32,
        endByte      = Int32,
        value        = String
    }

    pub def sourcesSchema(): ScientificTable.Schema = {
        format = "attuneflix-grit-sources-v2",
        columns = Vector#{text("path"), text("sha256"), int32("byte_length"), text("language")}
    }

    pub def factsSchema(): ScientificTable.Schema = {
        format = "attuneflix-grit-facts-v2",
        columns = Vector#{
            text("path"), text("source_sha256"), text("language"), text("program"),
            text("kind"), int32("start_byte"), int32("end_byte"), text("value")
        }
    }

    pub def sourceRows(sources: Vector[Source]): Vector[ScientificTable.Row] =
        Vector.map(source -> Map#{
            "path" => Value.Text(source#path), "sha256" => Value.Text(source#sha256),
            "byte_length" => Value.Int32(source#bytes), "language" => Value.Text(source#language)
        }, sources)

    pub def factRows(facts: Vector[FactRow]): Vector[ScientificTable.Row] =
        Vector.map(fact -> Map#{
            "path" => Value.Text(fact#path), "source_sha256" => Value.Text(fact#sourceSha256),
            "language" => Value.Text(fact#language), "program" => Value.Text(fact#program),
            "kind" => Value.Text(fact#kind), "start_byte" => Value.Int32(fact#startByte),
            "end_byte" => Value.Int32(fact#endByte), "value" => Value.Text(fact#value)
        }, facts)

    pub def writeSources(path: String, sources: Vector[Source]): Unit \ IO = {
        let _ = ScientificTable.write(path, sourcesSchema(), sourceRows(sources));
        ()
    }

    pub def writeFacts(path: String, facts: Vector[FactRow]): Unit \ IO = {
        let _ = ScientificTable.write(path, factsSchema(), factRows(facts));
        ()
    }

    pub def readSources(path: String): Vector[Source] \ IO =
        Vector.traverse(sourceOf, ScientificTable.read(path, sourcesSchema())) |> Experiment.require

    pub def readFacts(path: String): Vector[FactRow] \ IO =
        Vector.traverse(factOf, ScientificTable.read(path, factsSchema())) |> Experiment.require

    def sourceOf(row: ScientificTable.Row): Result[String, Source] = forM (
        path <- ScientificTable.text(row, "path");
        sha256 <- ScientificTable.text(row, "sha256");
        bytes <- ScientificTable.int32(row, "byte_length");
        language <- ScientificTable.text(row, "language")
    ) yield {path = path, sha256 = sha256, bytes = bytes, language = language}

    def factOf(row: ScientificTable.Row): Result[String, FactRow] = forM (
        path <- ScientificTable.text(row, "path");
        sourceSha256 <- ScientificTable.text(row, "source_sha256");
        language <- ScientificTable.text(row, "language");
        program <- ScientificTable.text(row, "program");
        kind <- ScientificTable.text(row, "kind");
        startByte <- ScientificTable.int32(row, "start_byte");
        endByte <- ScientificTable.int32(row, "end_byte");
        value <- ScientificTable.text(row, "value")
    ) yield {
        path = path, sourceSha256 = sourceSha256, language = language, program = program,
        kind = kind, startByte = startByte, endByte = endByte, value = value
    }

    /// Re-admit one revision's Grit evidence as the canonical typed basis.
    /// Every fact must name an admitted source, carry that source's exact hash
    /// and language, and lie inside the source's byte range: the evidence and
    /// the inclusion record cannot drift apart silently.
    pub def world(sources: Vector[Source], facts: Vector[FactRow]): Result[String, Repository.World] = {
        let byPath = Vector.map(source -> (source#path, source), sources) |> Vector.toMap;
        forM (
            _ <- requireSorted(sources);
            _ <- Vector.traverse(row -> check(byPath, row), facts) |> Result.map(_ -> ());
            definitions <- factsFor(byPath, "defines", facts);
            imports <- factsFor(byPath, "imports", facts);
            calls <- factsFor(byPath, "calls", facts);
            world <- Repository.admit(
                Vector.map(source -> {path = source#path, content = ""}, sources),
                definitions, imports, calls) |> Result.mapErr(error -> ToString.toString(error))
        ) yield world
    }

    /// The admitted source paths are the nominal FileId order: strictly
    /// increasing, unique, and therefore stable across environments.
    def requireSorted(sources: Vector[Source]): Result[String, Unit] = {
        let start: (Option[String], Result[String, Unit]) = (None, Ok(()));
        let (_, checked) = Vector.foldLeft((state, source) -> {
            let (previous, result) = state;
            match result {
                case Err(error) => (previous, Err(error))
                case Ok(()) => match previous {
                    case None => (Some(source#path), Ok(()))
                    case Some(last) => if (last < source#path) (Some(source#path), Ok(()))
                        else (previous, Err("admitted sources must be sorted and unique: ${source#path}"))
                }
            }
        }, start, sources);
        checked
    }

    def check(byPath: Map[String, Source], row: FactRow): Result[String, Unit] =
        match Map.get(row#path, byPath) {
            case None => Err("Grit fact names an unadmitted path: ${row#path}")
            case Some(source) =>
                if (row#sourceSha256 != source#sha256) Err("source hash mismatch: ${row#path}")
                else if (row#language != source#language) Err("language mismatch: ${row#path}")
                else if (row#startByte < 0 or row#endByte < row#startByte or row#endByte > source#bytes)
                    Err("Grit fact range outside its source: ${row#path}")
                else Ok(())
        }

    def factsFor(byPath: Map[String, Source], program: String, facts: Vector[FactRow]): Result[String, Vector[Repository.Grit.Fact]] =
        Vector.traverse(row -> match Map.get(row#path, byPath) {
            case None => Err("Grit fact names an unadmitted path: ${row#path}")
            case Some(_) => Ok({
                kind = row#kind, path = row#path,
                startByte = row#startByte, endByte = row#endByte, value = row#value
            })
        }, Vector.filter(row -> row#program == program, facts))

    /// The Grit acquisition identity recorded in every v2 world.
    pub def gritIdentity(): String =
        "grit-acquisition-v2:getgrit/gritql@c80b3026471b229f41b279c3eb0c162dcdacfdb1:frontends-defines-imports-calls"
}
