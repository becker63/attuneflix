/// Typed field access over provider and evidence JSON objects. JSON exists
/// only at this admission boundary; every admitted value leaves it typed.
pub mod Families.Wire {
    use Util.Json
    use Util.Json.Json.{JNull, JObject, JString}
    use Util.Json.FromJson

    pub type alias Fields = Map[String, Json]

    pub def field(name: String, fields: Fields): Result[String, Json] =
        Map.get(name, fields) |> Option.toOk("missing JSON field: ${name}")

    pub def object(name: String, fields: Fields): Result[String, Fields] = match field(name, fields) {
        case Ok(JObject(value)) => Ok(value)
        case Ok(_) => Err("${name}: expected object")
        case Err(error) => Err(error)
    }

    pub def text(name: String, fields: Fields): Result[String, String] = match field(name, fields) {
        case Ok(JString(value)) => Ok(value)
        case Ok(_) => Err("${name}: expected string")
        case Err(error) => Err(error)
    }

    pub def int32(name: String, fields: Fields): Result[String, Int32] =
        field(name, fields) |> Result.flatMap(value -> FromJson.fromJson(value)
            |> Result.mapErr(error -> "${name}: ${ToString.toString(error)}"))

    pub def float64(name: String, fields: Fields): Result[String, Float64] =
        field(name, fields) |> Result.flatMap(value -> FromJson.fromJson(value)
            |> Result.mapErr(error -> "${name}: ${ToString.toString(error)}"))

    pub def optionalText(name: String, fields: Fields): Result[String, Option[String]] = match Map.get(name, fields) {
        case None => Ok(None)
        case Some(JNull) => Ok(None)
        case Some(JString(value)) => Ok(Some(value))
        case Some(_) => Err("${name}: expected string or null")
    }

    pub def optionalInt32(name: String, fields: Fields): Result[String, Option[Int32]] = match Map.get(name, fields) {
        case None => Ok(None)
        case Some(JNull) => Ok(None)
        case Some(value) => FromJson.fromJson(value) |> Result.map(Some)
            |> Result.mapErr(error -> "${name}: ${ToString.toString(error)}")
    }

    pub def optionalFloat64(name: String, fields: Fields): Result[String, Option[Float64]] = match Map.get(name, fields) {
        case None => Ok(None)
        case Some(JNull) => Ok(None)
        case Some(value) => FromJson.fromJson(value) |> Result.map(Some)
            |> Result.mapErr(error -> "${name}: ${ToString.toString(error)}")
    }

    /// The top-level object of a provider body. A provider error object is an
    /// explicit failure, never an admissible observation.
    pub def body(payload: String): Result[String, Fields] = match Json.parse(payload) {
        case Err(error) => Err("provider body: ${ToString.toString(error)}")
        case Ok(JObject(fields)) => match Map.get("error", fields) {
            case Some(error) => Err("provider error: ${Json.toCompactString(error)}")
            case None => Ok(fields)
        }
        case Ok(_) => Err("provider body must be a JSON object")
    }

    /// The usage object, when the provider reported one.
    pub def usage(fields: Fields): Result[String, Fields] = match Map.get("usage", fields) {
        case None => Ok(Map.empty())
        case Some(JNull) => Ok(Map.empty())
        case Some(JObject(value)) => Ok(value)
        case Some(_) => Err("usage: expected object or null")
    }
}
