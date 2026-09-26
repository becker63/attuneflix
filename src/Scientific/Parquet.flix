/// The Parquet/Arrow transport seam: the single module that talks to the native
/// `attune.parquet.AttuneParquet` engine. It moves the canonical payload Flix
/// composes; the schema and the row meaning stay in the pure kernel and
/// `Scientific.Schema`/`Scientific.Value`/`Scientific.Row`.
pub mod Scientific.Parquet {
    import attune.parquet.AttuneParquet
    import java.lang.Exception
    use Kernel.Contract.{Row, Schema, decodeRows, schemaPayload}
    use Scientific.Row.canonicalRows

    /// A typed-table transport failure, so a capability bridge can keep the
    /// distinction between an unreachable table and a malformed payload.
    pub enum TableError with ToString {
        case Unavailable(String),
        case Malformed(String)
    }

    /// Read one typed table through the native Arrow seam and decode it against
    /// the pure schema; a transport or decode failure aborts the caller.
    pub def read(path: String, schema: Schema): Vector[Row] \ IO =
        match readResult(path, schema) {
            case Ok(rows) => rows
            case Err(error) => bug!(ToString.toString(error))
        }

    /// Returns the admitted rows read back from the completed atomic write.
    pub def write(path: String, schema: Schema, rows: Vector[Row]): Vector[Row] \ IO =
        AttuneParquet.writeTable(path, schemaPayload(schema), canonicalRows(rows))
            |> decodeRows(schema)
            |> require

    /// Structured read for capabilities that report errors instead of aborting:
    /// `Unavailable` for a failed native read, `Malformed` for a payload that
    /// does not match its declared schema.
    pub def readResult(path: String, schema: Schema): Result[TableError, Vector[Row]] \ IO =
        try {
            AttuneParquet.readTable(path, schemaPayload(schema))
                |> decodeRows(schema)
                |> Result.mapErr(TableError.Malformed)
        } catch {
            case _: Exception => Err(TableError.Unavailable(path))
        }

    def require(result: Result[String, a]): a = match result {
        case Ok(value) => value
        case Err(message) => bug!(message)
    }
}
