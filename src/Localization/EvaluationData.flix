/// Typed, compact inputs for the frozen SWE-Explore evaluator.
///
/// Source text is used once to build Geometry. Normal evaluation reads only
/// line counts and Symbol-ordinal line spans. Gold is a separate table and is
/// never an input to localization or replay actions.
pub mod Localization.EvaluationData {
    use Util.Json
    use Util.Json.Json.{JArray, JNull, JNumber, JObject, JString}
    use Util.Json.FromJson
    use Util.Json.ToJson

    pub type alias SourceRegion = {
        path  = String,
        start = Int32,
        end   = Int32
    }

    pub type alias Gold = {
        instanceId     = String,
        coreFiles      = Set[String],
        coreRegions    = Vector[SourceRegion],
        optionalFiles  = Set[String],
        optionalRegions = Vector[SourceRegion],
        mainFiles      = Set[String]
    }

    pub type alias Geometry = {
        counts          = Map[String, Int32],
        documentRegions = Vector[Option[SourceRegion]]
    }

    pub type alias SourceText = {path = String, content = String}

    pub type alias DocumentBytes = {
        ordinal   = Int32,
        path      = String,
        startByte = Int32,
        endByte   = Int32
    }

    pub def geometrySchema(): ScientificTable.Schema = {
        format = "attune-localization-evaluation-geometry-v1",
        columns = Vector#{
            text("protocol"), text("instance_id"), text("row_kind"),
            optionalInt32("ordinal"), text("path"), optionalInt32("line_count"),
            optionalInt32("start_line"), optionalInt32("end_line")
        }
    }

    pub def goldSchema(): ScientificTable.Schema = {
        format = "attune-swe-explore-gold-v1",
        columns = Vector#{
            text("protocol"), text("instance_id"), text("row_kind"), text("path"),
            optionalInt32("start_line"), optionalInt32("end_line")
        }
    }

    pub def writeGeometry(
        output: String,
        instanceId: String,
        sources: Vector[SourceText],
        documents: Vector[DocumentBytes]
    ): Result[String, Geometry] \ IO = forM (
        rows <- geometryRows(instanceId, sources, documents);
        admitted = ScientificTable.write(output, geometrySchema(), rows);
        geometry <- decodeGeometry(instanceId, Vector.length(documents), admitted)
    ) yield geometry

    pub def readGeometry(
        path: String,
        instanceId: String,
        documentCount: Int32
    ): Result[String, Geometry] \ IO =
        decodeGeometry(instanceId, documentCount,
            ScientificTable.read(path, geometrySchema()))

    /// One-time conversion from the frozen evaluator-only JSON-tree artifact.
    pub def writeGold(output: String, legacyPayload: String): Result[String, Int32] \ IO = forM (
        cases <- decodeLegacyGold(legacyPayload);
        rows = Vector.flatMap(goldRows, cases);
        admitted = ScientificTable.write(output, goldSchema(), rows);
        _ <- Vector.traverse(gold -> readGoldRows(gold#instanceId, admitted), cases)
    ) yield Vector.length(cases)

    pub def readGold(path: String, instanceId: String): Result[String, Gold] \ IO =
        readGoldRows(instanceId, ScientificTable.read(path, goldSchema()))

    def geometryRows(
        instanceId: String,
        sources: Vector[SourceText],
        documents: Vector[DocumentBytes]
    ): Result[String, Vector[ScientificTable.Row]] = {
        let bytes = Vector.map(source -> (source#path, String.toBytes(source#content)), sources)
            |> Vector.toMap;
        let sourceRows = Vector.map(source -> Map#{
            "protocol" => JString("attune-localization-evaluation-geometry-v1"),
            "instance_id" => JString(instanceId), "row_kind" => JString("source"),
            "ordinal" => JNull, "path" => JString(source#path),
            "line_count" => ToJson.toJson(sourceLineCount(source#content)),
            "start_line" => JNull, "end_line" => JNull
        }, sources);
        Vector.traverse(document -> match Map.get(document#path, bytes) {
            case None => Err("missing document source: ${document#path}")
            case Some(content) => {
                if (document#startByte < 0 or document#endByte < document#startByte or
                    document#endByte > Vector.length(content))
                    Err("invalid document byte range: ${document#path}")
                else {
                    let final = if (document#endByte <= document#startByte)
                        document#startByte else document#endByte - 1;
                    Ok(Map#{
                        "protocol" => JString("attune-localization-evaluation-geometry-v1"),
                        "instance_id" => JString(instanceId), "row_kind" => JString("document"),
                        "ordinal" => ToJson.toJson(document#ordinal), "path" => JString(document#path),
                        "line_count" => JNull,
                        "start_line" => ToJson.toJson(lineAt(document#startByte, content)),
                        "end_line" => ToJson.toJson(lineAt(final, content))
                    })
                }
            }
        }, documents) |> Result.map(documentRows -> Vector.append(sourceRows, documentRows))
    }

    def decodeGeometry(
        instanceId: String,
        documentCount: Int32,
        rows: Vector[ScientificTable.Row]
    ): Result[String, Geometry] = forM (
        parts <- decodeGeometryRows(instanceId, rows, 0, Nil, Nil, false);
        documentPairs = Vector.sortBy(fst, parts#documents);
        _ <- requireOrdinals(documentCount, documentPairs, 0);
        documents <- documentOptions(documentPairs, 0, Nil)
    ) yield {
        counts = Vector.toMap(parts#sources),
        documentRegions = documents
    }

    type alias GeometryParts = {
        sources   = Vector[(String, Int32)],
        documents = Vector[(Int32, SourceRegion)]
    }

    /// One tail-recursive pass avoids the generic Vector filter/traverse stack
    /// depth on repositories with tens of thousands of Symbols.
    def decodeGeometryRows(
        instanceId: String,
        rows: Vector[ScientificTable.Row],
        index: Int32,
        reverseSources: List[(String, Int32)],
        reverseDocuments: List[(Int32, SourceRegion)],
        matched: Bool
    ): Result[String, GeometryParts] =
        if (index >= Vector.length(rows)) {
            if (not matched) Err("missing typed evaluation rows for ${instanceId}")
            else Ok({
                sources = List.reverse(reverseSources) |> List.toVector,
                documents = List.reverse(reverseDocuments) |> List.toVector
            })
        } else {
            let row = Vector.get(index, rows);
            if (stringValue("instance_id", row) != Some(instanceId))
                decodeGeometryRows(instanceId, rows, index + 1,
                    reverseSources, reverseDocuments, matched)
            else if (stringValue("protocol", row) != Some("attune-localization-evaluation-geometry-v1"))
                Err("invalid evaluation geometry protocol")
            else match stringValue("row_kind", row) {
                case Some("source") => match (string("path", row), int32("line_count", row)) {
                    case (Ok(path), Ok(count)) => decodeGeometryRows(instanceId, rows, index + 1,
                        (path, count) :: reverseSources, reverseDocuments, true)
                    case (Err(error), _) => Err(error)
                    case (_, Err(error)) => Err(error)
                }
                case Some("document") => match (int32("ordinal", row), string("path", row),
                    int32("start_line", row), int32("end_line", row)) {
                    case (Ok(ordinal), Ok(path), Ok(start), Ok(end)) =>
                        decodeGeometryRows(instanceId, rows, index + 1, reverseSources,
                            (ordinal, {path = path, start = start, end = end}) :: reverseDocuments, true)
                    case (Err(error), _, _, _) => Err(error)
                    case (_, Err(error), _, _) => Err(error)
                    case (_, _, Err(error), _) => Err(error)
                    case (_, _, _, Err(error)) => Err(error)
                }
                case _ => Err("invalid evaluation geometry row kind")
            }
        }

    def documentOptions(
        rows: Vector[(Int32, SourceRegion)],
        index: Int32,
        reverse: List[Option[SourceRegion]]
    ): Result[String, Vector[Option[SourceRegion]]] =
        if (index >= Vector.length(rows)) Ok(List.reverse(reverse) |> List.toVector)
        else documentOptions(rows, index + 1, Some(snd(Vector.get(index, rows))) :: reverse)

    def requireOrdinals(
        expectedCount: Int32,
        rows: Vector[(Int32, SourceRegion)],
        index: Int32
    ): Result[String, Unit] =
        if (Vector.length(rows) != expectedCount) Err("evaluation document count mismatch")
        else if (index >= expectedCount) Ok(())
        else if (fst(Vector.get(index, rows)) != index) Err("evaluation document ordinal mismatch")
        else requireOrdinals(expectedCount, rows, index + 1)

    def goldRows(gold: Gold): Vector[ScientificTable.Row] = Vector.flatten(Vector#{
        Set.toVector(gold#coreFiles) |> Vector.sort |> Vector.map(path -> goldFile(gold#instanceId, "core_file", path)),
        Set.toVector(gold#optionalFiles) |> Vector.sort |> Vector.map(path -> goldFile(gold#instanceId, "optional_file", path)),
        Set.toVector(gold#mainFiles) |> Vector.sort |> Vector.map(path -> goldFile(gold#instanceId, "main_file", path)),
        Vector.map(span0 -> goldRegion(gold#instanceId, "core_region", span0), gold#coreRegions),
        Vector.map(span0 -> goldRegion(gold#instanceId, "optional_region", span0), gold#optionalRegions)
    })

    def goldFile(instanceId: String, kind: String, path: String): ScientificTable.Row = Map#{
        "protocol" => JString("attune-swe-explore-gold-v1"),
        "instance_id" => JString(instanceId), "row_kind" => JString(kind),
        "path" => JString(path), "start_line" => JNull, "end_line" => JNull
    }

    def goldRegion(instanceId: String, kind: String, span0: SourceRegion): ScientificTable.Row = Map#{
        "protocol" => JString("attune-swe-explore-gold-v1"),
        "instance_id" => JString(instanceId), "row_kind" => JString(kind),
        "path" => JString(span0#path), "start_line" => ToJson.toJson(span0#start),
        "end_line" => ToJson.toJson(span0#end)
    }

    def readGoldRows(instanceId: String, rows: Vector[ScientificTable.Row]): Result[String, Gold] = forM (
        selected <- selectRows(instanceId, rows);
        coreFiles <- files("core_file", selected);
        optionalFiles <- files("optional_file", selected);
        mainFiles <- files("main_file", selected);
        coreRegions <- regions("core_region", selected);
        optionalRegions <- regions("optional_region", selected)
    ) yield {
        instanceId = instanceId, coreFiles = coreFiles, coreRegions = coreRegions,
        optionalFiles = optionalFiles, optionalRegions = optionalRegions, mainFiles = mainFiles
    }

    def selectRows(instanceId: String, rows: Vector[ScientificTable.Row]): Result[String, Vector[ScientificTable.Row]] = {
        let selected = Vector.filter(row -> stringValue("instance_id", row) == Some(instanceId), rows);
        if (Vector.isEmpty(selected)) Err("missing typed evaluation rows for ${instanceId}")
        else if (Vector.exists(row -> stringValue("protocol", row) == None, selected))
            Err("invalid evaluation protocol")
        else Ok(selected)
    }

    def files(kind: String, rows: Vector[ScientificTable.Row]): Result[String, Set[String]] =
        Vector.filter(row -> stringValue("row_kind", row) == Some(kind), rows)
            |> Vector.traverse(row -> string("path", row))
            |> Result.map(Vector.toSet)

    def regions(kind: String, rows: Vector[ScientificTable.Row]): Result[String, Vector[SourceRegion]] =
        Vector.filter(row -> stringValue("row_kind", row) == Some(kind), rows)
            |> Vector.traverse(row -> forM (
                path <- string("path", row);
                start <- int32("start_line", row);
                end <- int32("end_line", row)
            ) yield {path = path, start = Int32.max(1, start), end = end})

    def decodeLegacyGold(payload: String): Result[String, Vector[Gold]] = match Json.parse(payload) {
        case Err(error) => Err(ToString.toString(error))
        case Ok(JObject(fields)) => forM (
            version <- intField("version", fields);
            _ <- if (version == 1) Ok(()) else Err("unsupported gold version");
            values <- arrayField("cases", fields);
            cases <- Vector.traverse(decodeLegacyGoldRow, values)
        ) yield cases
        case Ok(_) => Err("gold fixture must be an object")
    }

    def decodeLegacyGoldRow(value: Json): Result[String, Gold] = match value {
        case JObject(fields) => forM (
            instanceId <- stringField("instance_id", fields);
            coreFiles <- stringVectorField("core_files", fields);
            coreValues <- arrayField("core_regions", fields);
            coreRegions <- Vector.traverse(decodeLegacyRegion, coreValues);
            optionalFiles <- stringVectorField("optional_files", fields);
            optionalValues <- arrayField("optional_regions", fields);
            optionalRegions <- Vector.traverse(decodeLegacyRegion, optionalValues);
            mainFiles <- stringVectorField("main_files", fields)
        ) yield {
            instanceId = instanceId, coreFiles = Vector.toSet(coreFiles), coreRegions = coreRegions,
            optionalFiles = Vector.toSet(optionalFiles), optionalRegions = optionalRegions,
            mainFiles = Vector.toSet(mainFiles)
        }
        case _ => Err("gold case must be an object")
    }

    def decodeLegacyRegion(value: Json): Result[String, SourceRegion] = match value {
        case JObject(fields) => forM (
            path <- stringField("path", fields);
            start <- intField("start", fields);
            end <- intField("end", fields)
        ) yield {path = path, start = Int32.max(1, start), end = end}
        case _ => Err("gold region must be an object")
    }

    def sourceLineCount(source: String): Int32 = {
        let bytes = String.toBytes(source);
        let length = Vector.length(bytes);
        if (length == 0) 0
        else countLineBreaks(bytes, 0, 0) +
            (if (Int8.toInt32(Vector.get(length - 1, bytes)) == 10) 0 else 1)
    }

    def lineAt(offset: Int32, bytes: Vector[Int8]): Int32 = countNewlines(bytes, 0, offset, 1)

    def countNewlines(bytes: Vector[Int8], index: Int32, end: Int32, line: Int32): Int32 =
        if (index >= end or index >= Vector.length(bytes)) line
        else countNewlines(bytes, index + 1, end,
            if (Int8.toInt32(Vector.get(index, bytes)) == 10) line + 1 else line)

    def countLineBreaks(bytes: Vector[Int8], index: Int32, count: Int32): Int32 =
        if (index >= Vector.length(bytes)) count
        else countLineBreaks(bytes, index + 1,
            if (Int8.toInt32(Vector.get(index, bytes)) == 10) count + 1 else count)

    def stringValue(name: String, row: ScientificTable.Row): Option[String] = match Map.get(name, row) {
        case Some(JString(value)) => Some(value)
        case _ => None
    }

    def string(name: String, row: ScientificTable.Row): Result[String, String] =
        stringValue(name, row) |> Option.toOk("${name}: expected text")

    def int32(name: String, row: ScientificTable.Row): Result[String, Int32] = match Map.get(name, row) {
        case Some(JNumber(value)) => FromJson.fromJson(JNumber(value)) |> Result.mapErr(ToString.toString)
        case _ => Err("${name}: expected int32")
    }

    def field(name: String, fields: Map[String, Json]): Result[String, Json] =
        Map.get(name, fields) |> Option.toOk("missing ${name}")

    def stringField(name: String, fields: Map[String, Json]): Result[String, String] = match field(name, fields) {
        case Ok(JString(value)) => Ok(value)
        case Ok(_) => Err("${name}: expected string")
        case Err(error) => Err(error)
    }

    def intField(name: String, fields: Map[String, Json]): Result[String, Int32] =
        field(name, fields) |> Result.flatMap(value -> FromJson.fromJson(value)
            |> Result.mapErr(ToString.toString))

    def arrayField(name: String, fields: Map[String, Json]): Result[String, Vector[Json]] = match field(name, fields) {
        case Ok(JArray(values)) => Ok(values)
        case Ok(_) => Err("${name}: expected array")
        case Err(error) => Err(error)
    }

    def stringVectorField(name: String, fields: Map[String, Json]): Result[String, Vector[String]] =
        field(name, fields) |> Result.flatMap(value -> FromJson.fromJson(value)
            |> Result.mapErr(ToString.toString))

    def text(name: String): ScientificTable.Column = {
        name = name, kind = ScientificTable.ColumnType.Text, nullable = false
    }

    def optionalInt32(name: String): ScientificTable.Column = {
        name = name, kind = ScientificTable.ColumnType.Int32, nullable = true
    }
}
