/// Typed scientific tables. Flix declares the schema and owns row meaning;
/// Java only transfers these primitive columns through Arrow and Parquet.
pub mod ScientificTable {
    import attune.parquet.AttuneParquet

    use Util.Json
    use Util.Json.Json.{JArray, JBool, JNull, JNumber, JObject, JString}
    use Util.Json.FromJson
    use Util.Json.ToJson

    pub enum ColumnType with Eq, ToString {
        case Text
        case Int32
        case Int64
        case Float64
        case Boolean
        case TextList
    }

    pub type alias Column = {
        name     = String,
        kind     = ColumnType,
        nullable = Bool
    }

    /// `format` names the scientific schema. Canonical tables also carry that
    /// identity in an ordinary typed protocol column so it remains queryable.
    pub type alias Schema = {
        format  = String,
        columns = Vector[Column]
    }

    /// The closed set of values admitted by Attune's typed scientific tables.
    /// JSON exists only below this enum as the Java FFI wire envelope.
    pub enum Value with Eq, ToString {
        case Text(String)
        case Int32(Int32)
        case Int64(Int64)
        case Float64(Float64)
        case Boolean(Bool)
        case TextList(Vector[String])
        case Null
    }

    pub type alias Row = Map[String, Value]

    pub def read(path: String, schema: Schema): Vector[Row] \ IO =
        AttuneParquet.readTable(path, schemaPayload(schema))
            |> decodeRows(schema)
            |> require

    /// Returns the admitted rows read back from the completed atomic write.
    pub def write(path: String, schema: Schema, rows: Vector[Row]): Vector[Row] \ IO =
        AttuneParquet.writeTable(path, schemaPayload(schema), canonicalRows(rows))
            |> decodeRows(schema)
            |> require

    pub def text(row: Row, name: String): Result[String, String] = match Map.get(name, row) {
        case Some(Value.Text(value)) => Ok(value)
        case Some(_) => Err("${name} must be text")
        case None => Err("missing ${name}")
    }

    pub def int32(row: Row, name: String): Result[String, Int32] = match Map.get(name, row) {
        case Some(Value.Int32(value)) => Ok(value)
        case Some(_) => Err("${name} must be int32")
        case None => Err("missing ${name}")
    }

    pub def float64(row: Row, name: String): Result[String, Float64] = match Map.get(name, row) {
        case Some(Value.Float64(value)) => Ok(value)
        case Some(_) => Err("${name} must be float64")
        case None => Err("missing ${name}")
    }

    /// Numeric projection used only by analyses whose declared metric is a
    /// Float64 but whose source count is an integer column.
    pub def number(row: Row, name: String): Result[String, Float64] = match Map.get(name, row) {
        case Some(Value.Int32(value)) => Ok(Int32.toFloat64(value))
        case Some(Value.Int64(value)) => Ok(Int64.toFloat64(value))
        case Some(Value.Float64(value)) => Ok(value)
        case Some(_) => Err("${name} must be numeric")
        case None => Err("missing ${name}")
    }

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
        text(row, name) |> Result.flatMap(actual ->
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

    pub def schemaPayload(schema: Schema): String =
        JObject(Map#{
            "format" => JString(schema#format),
            "columns" => JArray(Vector.map(columnJson, schema#columns))
        }) |> Json.toCompactString

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

    def columnJson(column: Column): Json = JObject(Map#{
        "name" => JString(column#name),
        "type" => JString(typeName(column#kind)),
        "nullable" => JBool(column#nullable)
    })

    def typeName(type0: ColumnType): String = match type0 {
        case ColumnType.Text     => "string"
        case ColumnType.Int32    => "int32"
        case ColumnType.Int64    => "int64"
        case ColumnType.Float64  => "float64"
        case ColumnType.Boolean  => "boolean"
        case ColumnType.TextList => "list<string>"
    }

    def decodeRows(schema: Schema, payload: String): Result[String, Vector[Row]] = match Json.parse(payload) {
        case Err(error) => Err(ToString.toString(error))
        case Ok(JArray(values)) => Vector.traverse(match value -> match value {
            case JObject(fields) => decodeRow(schema, fields)
            case _ => Err("typed Parquet row must be an object")
        }, values)
        case Ok(_) => Err("typed Parquet seam returned a non-array")
    }

    def decodeRow(schema: Schema, fields: Map[String, Json]): Result[String, Row] =
        Vector.traverse(column -> match Map.get(column#name, fields) {
            case None => Err("typed Parquet row is missing ${column#name}")
            case Some(value) => decodeValue(column, value)
                |> Result.map(decoded -> (column#name, decoded))
        }, schema#columns)
        |> Result.map(Vector.toMap)

    def decodeValue(column: Column, value: Json): Result[String, Value] = match value {
        case JNull if column#nullable => Ok(Value.Null)
        case JString(value0) if column#kind == ColumnType.Text => Ok(Value.Text(value0))
        case JNumber(_) if column#kind == ColumnType.Int32 =>
            FromJson.fromJson(value) |> Result.map(Value.Int32) |> Result.mapErr(ToString.toString)
        case JNumber(_) if column#kind == ColumnType.Int64 =>
            FromJson.fromJson(value) |> Result.map(Value.Int64) |> Result.mapErr(ToString.toString)
        case JNumber(_) if column#kind == ColumnType.Float64 =>
            FromJson.fromJson(value) |> Result.map(Value.Float64) |> Result.mapErr(ToString.toString)
        case JBool(value0) if column#kind == ColumnType.Boolean => Ok(Value.Boolean(value0))
        case JArray(values) if column#kind == ColumnType.TextList =>
            Vector.traverse(match item -> match item {
                case JString(value0) => Ok(value0)
                case _ => Err("${column#name} contains a non-text value")
            }, values) |> Result.map(Value.TextList)
        case _ => Err("${column#name} does not match its declared typed Parquet column")
    }

    def require(result: Result[String, a]): a = match result {
        case Ok(value) => value
        case Err(message) => bug!(message)
    }
}
