/// Flix owns the scientific representation; Java only moves these rows through
/// Arrow's Parquet implementation.
pub mod ScientificData {
    import attune.parquet.AttuneParquet

    use Util.Json
    use Util.Json.Json.{JArray, JBool, JNull, JNumber, JObject, JString}

    enum Node {
        case Array
        case Object
        case Value(Json)
    }

    type alias Row = {path = List[String], node = Node}

    pub def readObject(path: String): String \ IO =
        decodeRows(AttuneParquet.readRows(path)) |> require |> Json.toCompactString

    /// Returns admitted content so callers compare semantics, not bytes.
    pub def writeObject(path: String, payload: String): String \ IO =
        let rows = payload |> parseObject |> require |> encodeRows;
        decodeRows(AttuneParquet.writeRows(path, rows)) |> require |> Json.toCompactString

    pub def canonicalizeObject(payload: String): String \ IO =
        let rows = payload |> parseObject |> require |> encodeRows;
        decodeRows(AttuneParquet.canonicalizeRows(rows)) |> require |> Json.toCompactString

    def parseObject(payload: String): Result[String, Json] = match Json.parse(payload) {
        case Ok(value) => match value {
            case JObject(_) => Ok(value)
            case _ => Err("scientific Parquet payload must be an object")
        }
        case Err(error) => Err(ToString.toString(error))
    }

    def encodeRows(root: Json): String =
        flatten(root, Nil) |> List.toVector |> JArray |> Json.toCompactString

    def flatten(value: Json, path: List[String]): List[Json] =
        rowJson(path, value) :: match value {
            case JArray(values) => Vector.mapWithIndex((index, child) ->
                flatten(child, path ::: "i:${index}" :: Nil), values)
                |> Vector.toList |> List.flatten
            case JObject(fields) => Map.toList(fields)
                |> List.flatMap(match (name, child) -> flatten(child, path ::: "k:${name}" :: Nil))
            case _ => Nil
        }

    def rowJson(path: List[String], value: Json): Json = {
        let null0 = JNull;
        let path0 = JArray(List.map(JString, path) |> List.toVector);
        match value {
            case JNull => rowFields(path0, "null", null0, null0, null0, null0)
            case JBool(value0) => rowFields(path0, "boolean", null0, null0, null0, JBool(value0))
            case JString(value0) => rowFields(path0, "string", JString(value0), null0, null0, null0)
            case JNumber(value0) if BigDecimal.scale(value0) == 0 =>
                rowFields(path0, "integer", null0, JNumber(value0), null0, null0)
            case JNumber(value0) => rowFields(path0, "float", null0, null0, JNumber(value0), null0)
            case JArray(_) => rowFields(path0, "array", null0, null0, null0, null0)
            case JObject(_) => rowFields(path0, "object", null0, null0, null0, null0)
        }
    }

    def rowFields(path: Json, kind: String, string0: Json, integer0: Json,
                  floating0: Json, bool0: Json): Json = JObject(Map#{
        "path" => path, "type" => JString(kind), "string" => string0,
        "integer" => integer0, "floating" => floating0, "bool" => bool0
    })

    def decodeRows(payload: String): Result[String, Json] = match Json.parse(payload) {
        case Err(error) => Err(ToString.toString(error))
        case Ok(JArray(values)) => forM (
            rows <- Vector.traverse(decodeRow, values);
            indexed <- indexRows(Vector.toList(rows), Map.empty(), Map.empty());
            result <- build(Nil, indexed#nodes, indexed#children);
            _ <- if (Map.isEmpty(result#nodes)) Ok(()) else Err("orphan Parquet tree rows")
        ) yield result#value
        case Ok(_) => Err("Parquet row seam returned a non-array")
    }

    def decodeRow(value: Json): Result[String, Row] = match value {
        case JObject(fields) => forM (
            path <- pathField(fields);
            kind <- stringField("type", fields);
            node <- nodeField(kind, fields)
        ) yield {path = path, node = node}
        case _ => Err("Parquet tree row must be an object")
    }

    def pathField(fields: Map[String, Json]): Result[String, List[String]] =
        field("path", fields) |> Result.flatMap(match value -> match value {
            case JArray(parts) => Vector.traverse(match part -> match part {
                case JString(text) => Ok(text)
                case _ => Err("Parquet tree path component must be a string")
            }, parts) |> Result.map(Vector.toList)
            case _ => Err("Parquet tree path must be an array")
        })

    def nodeField(kind: String, fields: Map[String, Json]): Result[String, Node] = match kind {
        case "null" => Ok(Node.Value(JNull))
        case "array" => Ok(Node.Array)
        case "object" => Ok(Node.Object)
        case "boolean" => field("bool", fields) |> Result.flatMap(match value -> match value {
            case JBool(value0) => Ok(Node.Value(JBool(value0)))
            case _ => Err("boolean row has no boolean value")
        })
        case "string" => field("string", fields) |> Result.flatMap(match value -> match value {
            case JString(value0) => Ok(Node.Value(JString(value0)))
            case _ => Err("string row has no string value")
        })
        case "integer" => numberNode("integer", fields)
        case "float" => numberNode("floating", fields)
        case _ => Err("unknown Parquet tree node type: ${kind}")
    }

    def numberNode(name: String, fields: Map[String, Json]): Result[String, Node] =
        field(name, fields) |> Result.flatMap(match value -> match value {
            case JNumber(value0) => Ok(Node.Value(JNumber(value0)))
            case _ => Err("${name} row has no numeric value")
        })

    def field(name: String, fields: Map[String, Json]): Result[String, Json] =
        Map.get(name, fields) |> Option.toOk("missing Parquet tree row field: ${name}")

    def stringField(name: String, fields: Map[String, Json]): Result[String, String] =
        field(name, fields) |> Result.flatMap(match value -> match value {
            case JString(text) => Ok(text)
            case _ => Err("Parquet tree row field is not a string: ${name}")
        })

    def indexRows(
        rows: List[Row], nodes: Map[List[String], Node],
        children: Map[List[String], Vector[String]]
    ): Result[String, {nodes = Map[List[String], Node], children = Map[List[String], Vector[String]]}] =
        match rows {
            case Nil => Ok({nodes = nodes, children = children})
            case row :: _ if Map.memberOf(row#path, nodes) => Err("duplicate Parquet tree path")
            case row :: rest => {
                let nodes0 = Map.insert(row#path, row#node, nodes);
                match List.reverse(row#path) {
                    case Nil => indexRows(rest, nodes0, children)
                    case part :: reverseParent => {
                        let parent = List.reverse(reverseParent);
                        let siblings = Map.get(parent, children) |> Option.getWithDefault(Vector.empty());
                        indexRows(rest, nodes0, Map.insert(parent, Vector.append(siblings, Vector#{part}), children))
                    }
                }
            }
        }

    def build(path: List[String], nodes: Map[List[String], Node],
              children: Map[List[String], Vector[String]]): Result[String, {value = Json, nodes = Map[List[String], Node]}] =
        Map.get(path, nodes) |> Option.toOk("missing Parquet tree node") |> Result.flatMap(node -> {
            let remaining = Map.remove(path, nodes);
            match node {
                case Node.Value(value) => Ok({value = value, nodes = remaining})
                case Node.Object => buildObject(
                    Map.get(path, children) |> Option.getWithDefault(Vector.empty()),
                    0, path, remaining, children, Map.empty())
                case Node.Array => arrayParts(
                    Map.get(path, children) |> Option.getWithDefault(Vector.empty()))
                    |> Result.flatMap(parts -> buildArray(parts, 0, path, remaining, children, Vector.empty()))
            }
        })

    def buildObject(parts: Vector[String], offset: Int32, path: List[String],
                    nodes: Map[List[String], Node], children: Map[List[String], Vector[String]],
                    fields: Map[String, Json]
    ): Result[String, {value = Json, nodes = Map[List[String], Node]}] =
        if (offset >= Vector.length(parts)) Ok({value = JObject(fields), nodes = nodes})
        else {
            let part = Vector.get(offset, parts);
            if (not String.startsWith(prefix = "k:", part)) Err("object row has a non-key child")
            else
            match build(path ::: part :: Nil, nodes, children) {
                case Err(error) => Err(error)
                case Ok(child) => buildObject(parts, offset + 1, path, child#nodes, children,
                    Map.insert(String.slice(start = 2, end = String.length(part), part),
                        child#value, fields))
            }
        }

    def arrayParts(parts: Vector[String]): Result[String, Vector[(Int32, String)]] =
        arrayPartsLoop(parts, 0, Vector.empty())

    def arrayPartsLoop(parts: Vector[String], offset: Int32, values: Vector[(Int32, String)]
    ): Result[String, Vector[(Int32, String)]] =
        if (offset >= Vector.length(parts)) Ok(values)
        else {
            let part = Vector.get(offset, parts);
            if (not String.startsWith(prefix = "i:", part)) Err("array row has a non-index child")
            else
            match Int32.parse(10, String.slice(start = 2, end = String.length(part), part)) {
                case Err(_) => Err("invalid array index")
                case Ok(index) if index != offset => Err("non-contiguous Parquet tree array")
                case Ok(index) => arrayPartsLoop(parts, offset + 1,
                    Vector.append(values, Vector#{(index, part)}))
            }
        }

    def buildArray(parts: Vector[(Int32, String)], expected: Int32, path: List[String],
                   nodes: Map[List[String], Node], children: Map[List[String], Vector[String]],
                   values: Vector[Json]
    ): Result[String, {value = Json, nodes = Map[List[String], Node]}] =
        if (expected >= Vector.length(parts)) Ok({value = JArray(values), nodes = nodes})
        else {
            let (index, part) = Vector.get(expected, parts);
            if (index != expected) Err("non-contiguous Parquet tree array")
            else match build(path ::: part :: Nil, nodes, children) {
                case Err(error) => Err(error)
                case Ok(child) => buildArray(parts, expected + 1, path, child#nodes,
                    children, Vector.append(values, Vector#{child#value}))
            }
        }

    def require(result: Result[String, a]): a = match result {
        case Ok(value) => value
        case Err(message) => bug!(message)
    }
}
