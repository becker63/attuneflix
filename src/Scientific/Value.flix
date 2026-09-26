/// Pure row-value semantics: the typed accessors, the null-preserving lifts, and
/// the numeric measures every scientific table projects out of one decoded
/// `Kernel.Contract.Row`. No I/O, no native seam, no transport.
pub mod Scientific.Value {
    use Kernel.Contract.{Row, Value}

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
        case Some(text) => Value.Text(text)
    }

    /// Shared guarded ratio: a zero denominator yields 0.0, never an error.
    pub def ratio(numerator: Int32, denominator: Int32): Float64 =
        if (denominator == 0) 0.0 else Int32.toFloat64(numerator) / Int32.toFloat64(denominator)

    /// Shared maximum over scientific measures; 0.0 for an empty vector.
    pub def maximum(values: Vector[Float64]): Float64 =
        Vector.foldLeft((largest, value) -> if (value > largest) value else largest, 0.0, values)
}
