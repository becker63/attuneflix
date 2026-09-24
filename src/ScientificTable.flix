/// Typed scientific tables. Flix declares the schema and owns row meaning;
/// Java only transfers these primitive columns through Arrow and Parquet.
pub mod ScientificTable {
    import attune.parquet.AttuneParquet

    use Util.Json
    use Util.Json.Json.{JArray, JBool, JObject, JString}

    pub enum ColumnType with Eq, ToString {
        case Text
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

    /// JSON is only the in-memory FFI envelope. The durable representation is
    /// the exact primitive/list columns declared by `Schema`.
    pub type alias Row = Map[String, Json]

    pub def read(path: String, schema: Schema): Vector[Row] \ IO =
        AttuneParquet.readTable(path, schemaPayload(schema))
            |> decodeRows
            |> require

    /// Returns the admitted rows read back from the completed atomic write.
    pub def write(path: String, schema: Schema, rows: Vector[Row]): Vector[Row] \ IO =
        AttuneParquet.writeTable(path, schemaPayload(schema), rowsPayload(rows))
            |> decodeRows
            |> require

    pub def schemaPayload(schema: Schema): String =
        JObject(Map#{
            "format" => JString(schema#format),
            "columns" => JArray(Vector.map(columnJson, schema#columns))
        }) |> Json.toCompactString

    def rowsPayload(rows: Vector[Row]): String =
        JArray(Vector.map(JObject, rows)) |> Json.toCompactString

    def columnJson(column: Column): Json = JObject(Map#{
        "name" => JString(column#name),
        "type" => JString(typeName(column#kind)),
        "nullable" => JBool(column#nullable)
    })

    def typeName(type0: ColumnType): String = match type0 {
        case ColumnType.Text     => "string"
        case ColumnType.Int64    => "int64"
        case ColumnType.Float64  => "float64"
        case ColumnType.Boolean  => "boolean"
        case ColumnType.TextList => "list<string>"
    }

    def decodeRows(payload: String): Result[String, Vector[Row]] = match Json.parse(payload) {
        case Err(error) => Err(ToString.toString(error))
        case Ok(JArray(values)) => Vector.traverse(match value -> match value {
            case JObject(fields) => Ok(fields)
            case _ => Err("typed Parquet row must be an object")
        }, values)
        case Ok(_) => Err("typed Parquet seam returned a non-array")
    }

    def require(result: Result[String, a]): a = match result {
        case Ok(value) => value
        case Err(message) => bug!(message)
    }
}
