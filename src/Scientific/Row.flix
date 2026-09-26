/// Pure row semantics: the canonical wire encoding of decoded rows, ordinal
/// canonicalization, and the identity/protocol checks the typed scientific
/// tables share. Meaning is projected here; a transport only moves the string
/// this module composes.
pub mod Scientific.Row {
    use Kernel.Contract.{Row, Value}
    use Util.Json
    use Util.Json.Json.{JArray, JBool, JNull, JObject, JString}
    use Util.Json.ToJson

    /// Stable wire encoding for identities which cover typed table rows.
    /// Domain modules receive a string, never JSON values.
    pub def canonicalRows(rows: Vector[Row]): String =
        JArray(Vector.map(row -> JObject(Map.toVector(row)
            |> Vector.map(match (name, value) -> (name, valueJson(value)))
            |> Vector.toMap), rows)) |> Json.toCompactString

    /// The named column must carry exactly the expected identity value; the
    /// context names the table in the mismatch diagnostic.
    pub def requireText(name: String, expected: String, row: Row, context: String): Result[String, Unit] =
        Kernel.Contract.text(row, name) |> Result.flatMap(actual ->
            if (actual == expected) Ok(()) else Err("${context} identity mismatch: ${name}"))

    /// A protocol table carries exactly one metadata row.
    pub def exactlyOne(name: String, rows: Vector[a]): Result[String, a] =
        if (Vector.length(rows) == 1) Ok(Vector.get(0, rows)) else Err("${name} requires exactly one row")

    /// Typed tables are written in ordinal order. Preserve that common path
    /// without feeding an already-sorted large vector to Flix's recursive
    /// quicksort. Noncanonical readers retain the same sorting semantics.
    pub def canonicalOrdinals(entries: Vector[(Int32, a)]): Vector[(Int32, a)] =
        if (ordinalsOrdered(entries)) entries
        else Vector.sortBy(match (ordinal, _) -> ordinal, entries)

    pub def ordinalsOrdered(entries: Vector[(Int32, a)]): Bool =
        Vector.forAll(match (index, entry) -> fst(entry) == index,
            Vector.mapWithIndex((index, entry) -> (index, entry), entries))

    /// After canonicalization the ordinals must run contiguously from zero.
    pub def requireContiguous(message: String, entries: Vector[(Int32, a)]): Result[String, Unit] =
        if (ordinalsOrdered(entries)) Ok(())
        else Err(message)

    def valueJson(value: Value): Json = match value {
        case Value.Text(value0) => JString(value0)
        case Value.Int32(value0) => ToJson.toJson(value0)
        case Value.Int64(value0) => ToJson.toJson(value0)
        case Value.Float64(value0) => ToJson.toJson(value0)
        case Value.Boolean(value0) => JBool(value0)
        case Value.TextList(values) => JArray(Vector.map(JString, values))
        case Value.Null => JNull
    }
}
