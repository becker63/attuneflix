pub mod Repository.Grit {
    import attune.grit.AttuneGrit

    use Util.Json
    use Util.Json.Json.{JArray, JBool, JObject, JString}
    use Util.Json.FromJson

    pub enum Language with Eq, Order, ToString, Hash {
        case JavaScript,
        case Jsx,
        case TypeScript,
        case Tsx
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

    /// Exact source identity for retained observations. Timing and resource
    /// telemetry are deliberately absent from semantic identity.
    pub def observationIdentity(): String =
        "marzano-c80b3026471b229f41b279c3eb0c162dcdacfdb1" +
        ":defines-js-f900274ac3946ac34f6b45f6b0d563fac419c3a18469bd10eebc10b4544ca3ae" +
        ":defines-jsx-381f8ff92982d131e59429dd3ea480ac2b9de89125e09604421b4dd86627edf4" +
        ":defines-ts-90694687a51de99b715fb55e59c53072bdad9cdced9b3b7c76a83b6c19fa576c" +
        ":defines-tsx-eb560f45914c3cbd7e3d3e58cc2051c55995cb38e32724e37c31e86dbf2dec14" +
        ":imports-js-2d8ae48d4ec92f03994ac31f78a14cfce6061adb196bb3226601243211c0f1ed" +
        ":imports-jsx-bd7d241bd0b8f009455bac08705bf8cef5e94b1985d217709e5c03627b17cb82" +
        ":imports-ts-681edf9ffc137fe14b67a4ffc1d582a26557508799924ced210cfd973606e218" +
        ":imports-tsx-d29a731ca5a02bdb948db211376bfbdacb60bb07e27a6fd6b33b3e1b1e7b0671" +
        ":calls-js-4d77d225337651fb9d6b479d04589e64bc0b679c73ece4892d5ae8a678b71a30" +
        ":calls-jsx-6778315ccb4fab253c0eab6602079078da3407552f6bd26cc101453267d9f4c6" +
        ":calls-ts-e84e1c3a5779bae714684dd7a1586fc59235f0aeb411c35fba8f84a385316a5a" +
        ":calls-tsx-b8974c7b3b098df429db0cb9f34e50c1ac8d70b2b2dfe8fbdb1a5d70b3587723"

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
        let name = match language {
            case Language.JavaScript => "javascript"
            case Language.Jsx        => "jsx"
            case Language.TypeScript => "typescript"
            case Language.Tsx        => "tsx"
        };
        let programName = match program {
            case Program.Defines => "defines"
            case Program.Imports => "imports"
            case Program.Calls   => "calls"
        };
        Wire.Wire(AttuneGrit.evaluate(name, AttuneGrit.program(name, programName), path, source))
}
