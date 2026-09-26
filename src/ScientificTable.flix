/// Typed scientific tables. Flix declares the schema and owns row meaning in
/// the Stable Contract Kernel; Java only transfers those primitive columns
/// through Arrow and Parquet. This module is the sole table transport seam.
pub mod ScientificTable {
    import attune.parquet.AttuneParquet

    use Kernel.Contract.{Row, Schema, Value, decodeRows, schemaPayload}
    use Util.Json
    use Util.Json.Json.{JArray, JBool, JNull, JNumber, JObject, JString}
    use Util.Json.ToJson

    pub def read(path: String, schema: Schema): Vector[Row] \ IO =
        AttuneParquet.readTable(path, schemaPayload(schema))
            |> decodeRows(schema)
            |> require

    /// Returns the admitted rows read back from the completed atomic write.
    pub def write(path: String, schema: Schema, rows: Vector[Row]): Vector[Row] \ IO =
        AttuneParquet.writeTable(path, schemaPayload(schema), canonicalRows(rows))
            |> decodeRows(schema)
            |> require

    pub def boolean(row: Row, name: String): Result[String, Bool] = match Map.get(name, row) {
        case Some(Value.Boolean(value)) => Ok(value)
        case Some(_) => Err("${name} must be boolean")
        case None => Err("missing ${name}")
    }

    pub def optionalInt32(row: Row, name: String): Result[String, Option[Int32]] = match Map.get(name, row) {
        case Some(Value.Int32(value)) => Ok(Some(value))
        case Some(Value.Null) => Ok(None)
        case Some(_) => Err("${name} must be nullable int32")
        case None => Err("missing ${name}")
    }

    pub def optionalFloat64(row: Row, name: String): Result[String, Option[Float64]] = match Map.get(name, row) {
        case Some(Value.Float64(value)) => Ok(Some(value))
        case Some(Value.Null) => Ok(None)
        case Some(_) => Err("${name} must be nullable float64")
        case None => Err("missing ${name}")
    }

    pub def optionalText(row: Row, name: String): Result[String, Option[String]] = match Map.get(name, row) {
        case Some(Value.Text(value)) => Ok(Some(value))
        case Some(Value.Null) => Ok(None)
        case Some(_) => Err("${name} must be nullable text")
        case None => Err("missing ${name}")
    }

    /// Shared null-preserving lifts from optional decoded values to row values.
    pub def optionalInt32Value(value: Option[Int32]): Value = match value {
        case None => Value.Null
        case Some(number) => Value.Int32(number)
    }

    pub def optionalFloat64Value(value: Option[Float64]): Value = match value {
        case None => Value.Null
        case Some(number) => Value.Float64(number)
    }

    pub def optionalTextValue(value: Option[String]): Value = match value {
        case None => Value.Null
        case Some(text0) => Value.Text(text0)
    }

    /// Shared guarded ratio: a zero denominator yields 0.0, never an error.
    pub def ratio(numerator: Int32, denominator: Int32): Float64 =
        if (denominator == 0) 0.0 else Int32.toFloat64(numerator) / Int32.toFloat64(denominator)

    /// Shared maximum over scientific measures; 0.0 for an empty vector.
    pub def maximum(values: Vector[Float64]): Float64 =
        Vector.foldLeft((largest, value) -> if (value > largest) value else largest, 0.0, values)

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

    /// Stable wire encoding for identities which cover typed table rows.
    /// Domain modules receive a string, never JSON values.
    pub def canonicalRows(rows: Vector[Row]): String =
        JArray(Vector.map(row -> JObject(Map.toVector(row)
            |> Vector.map(match (name, value) -> (name, valueJson(value)))
            |> Vector.toMap), rows)) |> Json.toCompactString

    def valueJson(value: Value): Json = match value {
        case Value.Text(value0) => JString(value0)
        case Value.Int32(value0) => ToJson.toJson(value0)
        case Value.Int64(value0) => ToJson.toJson(value0)
        case Value.Float64(value0) => ToJson.toJson(value0)
        case Value.Boolean(value0) => JBool(value0)
        case Value.TextList(values) => JArray(Vector.map(JString, values))
        case Value.Null => JNull
    }

    def require(result: Result[String, a]): a = match result {
        case Ok(value) => value
        case Err(message) => bug!(message)
    }
}
