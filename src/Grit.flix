mod Grit {
    import attune.grit.AttuneGrit

    use Util.Json
    use Util.Json.Json.{JArray, JBool, JObject, JString}
    use Util.Json.FromJson

    pub enum Language with Eq, Order, ToString, Hash {
        case TypeScript
    }

    /// The admitted source-syntax vocabulary is closed and Nix-packaged.
    pub enum Program with Eq, Order, ToString, Hash {
        case Defines,
        case Imports,
        case Calls
    }

    /// Stable wire observation. Pure decoding/normalization belongs above the handler.
    pub enum Wire(String) with Eq, Order, ToString, Hash

    pub type alias Span = {
        path      = String,
        startByte = Int32,
        endByte   = Int32
    }

    pub type alias Log = {
        message   = String,
        startByte = Int32,
        endByte   = Int32
    }

    pub type alias Evaluation = {
        matched    = Bool,
        matches    = Vector[Span],
        logs       = Vector[Log],
        diagnostics = Vector[String]
    }

    /// Stable source observation after byte-range projection.
    pub type alias Fact = {
        kind      = String,
        path      = String,
        startByte = Int32,
        endByte   = Int32,
        value     = String
    }

    pub enum Error with Eq, ToString {
        case Wire(String),
        case Native(String, String),
        case UnsupportedVersion(Int32),
        case UnexpectedPath(String, String),
        case InvalidRange(Int32, Int32),
        case LogOutsideMatch(Int32, Int32)
    }

    /// Source extraction is a narrow capability, not permission for arbitrary IO.
    pub eff Eval {
        def evaluate(language: Language, program: Program, path: String, source: String): Wire
    }

    pub def evaluate(language: Language, program: Program, path: String, source: String): Wire \ Eval =
        Eval.evaluate(language, program, path, source)

    pub def runWithNative(f: Unit -> a \ ef): a \ (ef - Eval) + IO =
        run { f() } with handler Eval {
            def evaluate(language, program, path, source, k) =
                k(evaluateNative(language, program, path, source))
        }

    pub def runWithFixture(fixture: Wire, f: Unit -> a \ ef): a \ (ef - Eval) =
        run { f() } with handler Eval {
            def evaluate(_language, _program, _path, _source, k) = k(fixture)
        }

    pub def json(wire: Wire): String = let Wire.Wire(value) = wire; value

    /// Decode the stable native envelope without trusting its external data.
    pub def decode(wire: Wire): Result[Error, Evaluation] =
        let Wire.Wire(payload) = wire;
        match Json.parse(payload) {
            case Err(error) => Err(Error.Wire(ToString.toString(error)))
            case Ok(JObject(fields)) => match intField("version", fields) {
                case Err(error) => Err(error)
                case Ok(version) if version != 1 => Err(Error.UnsupportedVersion(version))
                case Ok(_) => match Map.get("error", fields) {
                    case Some(value) => decodeNativeError(value)
                    case None        => decodeEvaluation(fields)
                }
            }
            case Ok(_) => Err(Error.Wire("expected a JSON object"))
        }

    /// Bind each logged byte range to its smallest enclosing syntax match.
    pub def facts(path: String, source: String, wire: Wire): Result[Error, Vector[Fact]] = match decode(wire) {
        case Err(error) => Err(error)
        case Ok(evaluation) => match validateMatches(path, source, evaluation#matches) {
            case Err(error) => Err(error)
            case Ok(()) =>
                Vector.traverse(log -> fact(path, source, evaluation#matches, log), evaluation#logs)
                    |> Result.map(Vector.sortBy(item -> (item#startByte, item#endByte)))
        }
    }

    def decodeNativeError(value: Json): Result[Error, Evaluation] = match value {
        case JObject(fields) => match stringField("kind", fields) {
            case Err(error) => Err(error)
            case Ok(kind) => match stringField("message", fields) {
                case Err(error)    => Err(error)
                case Ok(message) => Err(Error.Native(kind, message))
            }
        }
        case _ => Err(Error.Wire("error must be a JSON object"))
    }

    def decodeEvaluation(fields: Map[String, Json]): Result[Error, Evaluation] = forM (
        matched <- boolField("matched", fields);
        matchesJson <- arrayField("matches", fields);
        logsJson <- arrayField("logs", fields);
        diagnostics <- vectorField("diagnostics", fields);
        matches <- Vector.traverse(decodeSpan, matchesJson);
        logs <- Vector.traverse(decodeLog, logsJson)
    ) yield {
        matched = matched,
        matches = matches,
        logs = logs,
        diagnostics = diagnostics
    }

    def decodeSpan(value: Json): Result[Error, Span] = match value {
        case JObject(fields) => forM (
            path <- stringField("path", fields);
            start <- intField("start_byte", fields);
            end <- intField("end_byte", fields)
        ) yield {path = path, startByte = start, endByte = end}
        case _ => Err(Error.Wire("match must be a JSON object"))
    }

    def decodeLog(value: Json): Result[Error, Log] = match value {
        case JObject(fields) => forM (
            message <- stringField("message", fields);
            start <- intField("start_byte", fields);
            end <- intField("end_byte", fields)
        ) yield {message = message, startByte = start, endByte = end}
        case _ => Err(Error.Wire("log must be a JSON object"))
    }

    def fact(path: String, source: String, matches: Vector[Span], log: Log): Result[Error, Fact] = {
        let bytes = String.toBytes(source);
        let start = log#startByte;
        let end = log#endByte;
        if (start < 0 or end < start or end > Vector.length(bytes))
            Err(Error.InvalidRange(start, end))
        else match smallestEnclosing(matches, start, end) {
            case None => Err(Error.LogOutsideMatch(start, end))
            case Some(span) => Ok({
                kind = String.trimRight(log#message),
                path = path,
                startByte = span#startByte,
                endByte = span#endByte,
                value = String.fromBytes(Vector.slice(start = start, end = end, bytes))
            })
        }
    }

    def validateMatches(path: String, source: String, matches: Vector[Span]): Result[Error, Unit] = {
        let length = Vector.length(String.toBytes(source));
        Vector.foldLeft((result, span) -> match result {
            case Err(error) => Err(error)
            case Ok(()) if span#path != path => Err(Error.UnexpectedPath(path, span#path))
            case Ok(()) if span#startByte < 0 or span#endByte < span#startByte or span#endByte > length =>
                Err(Error.InvalidRange(span#startByte, span#endByte))
            case Ok(()) => Ok(())
        }, Ok(()), matches)
    }

    def smallestEnclosing(matches: Vector[Span], start: Int32, end: Int32): Option[Span] =
        Vector.foldLeft((best, span) ->
            if (span#startByte <= start and end <= span#endByte) chooseNarrower(best, span) else best,
            None,
            matches)

    def chooseNarrower(best: Option[Span], candidate: Span): Option[Span] = match best {
        case None => Some(candidate)
        case Some(current) =>
            if (candidate#endByte - candidate#startByte < current#endByte - current#startByte)
                Some(candidate)
            else
                best
    }

    def field(name: String, fields: Map[String, Json]): Result[Error, Json] =
        Map.get(name, fields) |> Option.toOk(Error.Wire("missing JSON field: ${name}"))

    def intField(name: String, fields: Map[String, Json]): Result[Error, Int32] =
        match field(name, fields) {
            case Err(error) => Err(error)
            case Ok(value) => FromJson.fromJson(value)
                |> Result.mapErr(error -> Error.Wire("${name}: ${ToString.toString(error)}"))
        }

    def stringField(name: String, fields: Map[String, Json]): Result[Error, String] =
        match field(name, fields) {
            case Err(error) => Err(error)
            case Ok(JString(value)) => Ok(value)
            case Ok(_) => Err(Error.Wire("${name}: expected string"))
        }

    def boolField(name: String, fields: Map[String, Json]): Result[Error, Bool] =
        match field(name, fields) {
            case Err(error) => Err(error)
            case Ok(JBool(value)) => Ok(value)
            case Ok(_) => Err(Error.Wire("${name}: expected boolean"))
        }

    def arrayField(name: String, fields: Map[String, Json]): Result[Error, Vector[Json]] =
        match field(name, fields) {
            case Err(error) => Err(error)
            case Ok(JArray(value)) => Ok(value)
            case Ok(_) => Err(Error.Wire("${name}: expected array"))
        }

    def vectorField(name: String, fields: Map[String, Json]): Result[Error, Vector[String]] =
        match field(name, fields) {
            case Err(error) => Err(error)
            case Ok(value) => FromJson.fromJson(value)
                |> Result.mapErr(error -> Error.Wire("${name}: ${ToString.toString(error)}"))
        }

    def evaluateNative(language: Language, program: Program, path: String, source: String): Wire \ IO =
        let name = match language { case Language.TypeScript => "typescript" };
        let programName = match program {
            case Program.Defines => "defines"
            case Program.Imports => "imports"
            case Program.Calls   => "calls"
        };
        Wire.Wire(AttuneGrit.evaluate(name, AttuneGrit.program(programName), path, source))
}
