/// The Stable Semantic / Contract Kernel (Candidate A): the leaf of the
/// architecture. It declares the nominal identities, the pure relational
/// contract, the frozen six-atom Atlas grammar, the pure scientific schema,
/// and the typed input/output contracts of the six-stage pipeline. Nothing
/// here performs I/O, calls a native seam, or names a language resolver, so
/// any cell may depend on it without inheriting an effect. The World, Engine,
/// and Applications cells converge on this contract as the Candidate C/D
/// decomposition lands; the Arrow/Parquet transport that realizes the schema
/// stays in `ScientificTable` until Candidate C splits it out.
pub mod Kernel.Contract {
    use Util.Json
    use Util.Json.Json.{JArray, JBool, JNull, JNumber, JObject, JString}
    use Util.Json.FromJson
    use Util.Json.ToJson

    // Nominal identities: the compiler rejects mixing the domains, so a
    // `FileId` can never be used where a `SymbolId` is expected.
    pub enum FileId(Int32) with Eq, Order, ToString, Hash
    pub enum SymbolId(Int32) with Eq, Order, ToString, Hash
    pub enum LocationId(Int32) with Eq, Order, ToString, Hash
    pub enum CandidateId(Int32) with Eq, Order, ToString, Hash

    // Pure Datalog relation types: a relation is a physical shape, not a
    // semantic name; the four basis relations carry the repository's meaning.
    pub type alias Relation[a, b] = Set[(a, b)]
    pub type alias Defines = Relation[FileId, SymbolId]
    pub type alias Imports = Relation[FileId, FileId]
    pub type alias Calls = Relation[SymbolId, SymbolId]
    pub type alias Parents = Relation[LocationId, LocationId]

    // Atlas six-atom grammar. Atlas admits exactly six directed relations and
    // composition; an atom is the smallest deterministic execution unit, one
    // atom mapping one exact typed frontier to the next. Reverse and Union stay
    // Radii operations and are intentionally not constructors here.
    pub enum Atom with Eq, Order, ToString, Hash {
        case Defines,
        case DefinedIn,
        case Imports,
        case ImportedBy,
        case Calls,
        case Callers
    }

    /// One member of the finite Atlas language: an ordered list of atoms.
    pub type alias Program = { steps = Vector[Atom] }

    /// The typed frontier an Atlas atom consumes and produces.
    pub enum State with Eq, Order, ToString, Hash {
        case Files(Set[FileId]),
        case Symbols(Set[SymbolId])
    }

    /// The complete grammar vocabulary, in the frozen directed atom order.
    pub def atoms(): Vector[Atom] = Vector#{
        Atom.Defines,
        Atom.DefinedIn,
        Atom.Imports,
        Atom.ImportedBy,
        Atom.Calls,
        Atom.Callers
    }

    // Pure scientific schema: Flix owns the schema and row meaning, and a
    // transport only moves these primitive columns. No native seam appears.
    pub enum ColumnType with Eq, ToString {
        case Text,
        case Int32,
        case Int64,
        case Float64,
        case Boolean,
        case TextList
    }

    pub type alias Column = {
        name     = String,
        kind     = ColumnType,
        nullable = Bool
    }

    /// `format` names the scientific schema; the columns declare its shape.
    pub type alias Schema = {
        format  = String,
        columns = Vector[Column]
    }

    /// The closed set of values admitted by the typed scientific tables.
    pub enum Value with Eq, ToString {
        case Text(String),
        case Int32(Int32),
        case Int64(Int64),
        case Float64(Float64),
        case Boolean(Bool),
        case TextList(Vector[String]),
        case Null
    }

    pub type alias Row = Map[String, Value]

    /// Canonical wire shape of a schema, shared by every transport.
    pub def schemaPayload(schema: Schema): String =
        JObject(Map#{
            "format" => JString(schema#format),
            "columns" => JArray(Vector.map(columnJson, schema#columns))
        }) |> Json.toCompactString

    /// Pure decoding of one transport payload into typed rows; transport never
    /// hands JSON values across the boundary, meaning is projected here.
    pub def decodeRows(schema: Schema, payload: String): Result[String, Vector[Row]] =
        match Json.parse(payload) {
            case Err(error) => Err(ToString.toString(error))
            case Ok(JArray(values)) => Vector.traverse(match value -> match value {
                case JObject(fields) => decodeRow(schema, fields)
                case _ => Err("typed row must be an object")
            }, values)
            case Ok(_) => Err("typed table decoder received a non-array")
        }

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

    /// Numeric projection for declared Float64 metrics backed by integer data.
    pub def number(row: Row, name: String): Result[String, Float64] = match Map.get(name, row) {
        case Some(Value.Int32(value)) => Ok(Int32.toFloat64(value))
        case Some(Value.Int64(value)) => Ok(Int64.toFloat64(value))
        case Some(Value.Float64(value)) => Ok(value)
        case Some(_) => Err("${name} must be numeric")
        case None => Err("missing ${name}")
    }

    def decodeRow(schema: Schema, fields: Map[String, Json]): Result[String, Row] =
        Vector.traverse(column -> match Map.get(column#name, fields) {
            case None => Err("typed row is missing ${column#name}")
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
        case _ => Err("${column#name} does not match its declared column")
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

    // Stage pipeline contracts: each stage consumes one declared input ADT and
    // produces one declared output ADT, Acquire -> World -> Prior || Atlas ->
    // CandidateSet -> Judge -> Projection.
    pub type alias SourceFile = { path = String, content = String }

    /// Stage 1 input: the declared acquisition request.
    pub type alias SourceManifest = {
        repository = String,
        revision   = String,
        files      = Vector[SourceFile]
    }

    /// One normalized raw syntax fact, identical in shape for every language.
    pub enum FactKind with Eq, Order, ToString, Hash {
        case Defines,
        case Imports,
        case Calls
    }

    pub type alias RawFact = {
        kind      = FactKind,
        path      = String,
        startByte = Int32,
        endByte   = Int32,
        value     = String
    }

    /// Stage 1 output: the normalized raw fact manifest.
    pub type alias RawFactManifest = {
        repository = String,
        revision   = String,
        files      = Vector[SourceFile],
        facts      = Vector[RawFact]
    }

    pub type alias Symbol = {
        path      = String,
        name      = String,
        startByte = Int32,
        endByte   = Int32
    }

    /// Stage 2 output: the admitted typed world.
    pub type alias AdmittedWorld = {
        files             = Vector[String],
        symbols           = Vector[Symbol],
        defines           = Defines,
        imports           = Imports,
        calls             = Calls,
        parents           = Parents,
        unresolvedImports = Int32,
        unresolvedCalls   = Int32
    }

    pub type alias PriorScore = { symbol = SymbolId, score = Float64 }

    /// Stage 3A output: issue-conditioned prior similarity.
    pub type alias PriorScores = { scores = Vector[PriorScore] }

    pub type alias AtlasOutcome = {
        program = Program,
        state   = State,
        depth   = Int32,
        reach   = Float64
    }

    /// Stage 3B output: exact reachable states per Atlas program.
    pub type alias AtlasCandidateOutcomes = { outcomes = Vector[AtlasOutcome] }

    pub type alias Candidate = {
        id         = CandidateId,
        symbol     = SymbolId,
        priorRank  = Option[Int32],
        atlasReach = Option[Float64]
    }

    /// Stage 4 output: the merged, stably identified candidate ranking.
    pub type alias CandidateSet = { candidates = Vector[Candidate] }

    /// Stage 5 output: the selected localization basis.
    pub enum Selection with Eq, Order, ToString, Hash {
        case Prior,
        case Atlas(CandidateId)
    }

    pub type alias SelectionOutcome = {
        issue     = String,
        selection = Selection,
        ranking   = Vector[CandidateId]
    }

    pub type alias ContextSpan = {
        path      = String,
        symbol    = SymbolId,
        startByte = Int32,
        endByte   = Int32,
        text      = String
    }

    /// Stage 6 output: rendered context under a declared token budget.
    pub type alias ProjectedContext = {
        selection       = Selection,
        spans           = Vector[ContextSpan],
        tokenBudget     = Int32,
        estimatedTokens = Int32,
        rendered        = String
    }
}
