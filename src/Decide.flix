mod Decide {
    import attune.embed.AttuneDecision

    use Fs.FileSystem
    use Util.Json
    use Util.Json.Json.{JNull, JObject, JString}
    use Util.Json.FromJson
    use Util.Json.ToJson

    pub enum Action with Eq, Order, ToString, Hash {
        case Stop,
        case Follow(Radii.Atom),
        /// Experiment policies may choose a typed continuation atomically.
        /// The ordinary v1 path never constructs this case.
        case FollowPath(Vector[Radii.Atom])
    }

    pub type alias Config = {
        protocol = String,
        question = String
    }

    pub type alias Alternative = {
        action = Action,
        expression = Option[Radii.Evaluate.ExprId],
        state = Radii.Evaluate.StateId,
        criterion = String
    }

    pub type alias Request = {
        decision = Radii.Evaluate.DecisionId,
        current = Radii.Evaluate.StateId,
        alternatives = Vector[Alternative],
        payload = String
    }

    pub type alias Usage = {
        cost = Option[Float64],
        inputTokens = Option[Int32],
        outputTokens = Option[Int32]
    }

    pub type alias Observation = {
        decision = Radii.Evaluate.DecisionId,
        choice = Action,
        choiceIndex = Int32,
        probabilities = Map[Action, Float64],
        confidence = Float64,
        provider = String,
        actualModel = String,
        responseId = String,
        usage = Usage
    }

    pub enum Wire(String) with Eq

    pub enum Error with Eq, ToString {
        case NoAlternatives,
        case MissingReplay(Radii.Evaluate.DecisionId),
        case InvalidChoice(Int32),
        case DuplicateAction(String),
        case Wire(String),
        case Native(String, String),
        case UnexpectedAnswerType(String),
        case UnexpectedModel(String),
        case UnknownAction(String),
        case MissingProbability(String),
        case ObservationStore(String)
    }

    pub eff Choice {
        def policy(request: Request): Result[Error, Observation]
    }

    pub def provider(): String = "openrouter"
    pub def endpoint(): String = "https://openrouter.ai/api/alpha/decisions"
    pub def model(): String = "typesafe/jev-1.13"
    pub def protocol(): String = "attune-jev-localization-v1"

    pub def question(): String =
        "Choose the next typed repository-structure action most likely to improve localization of the reported issue. " +
        "Choose stop only when the current symbol preview is at least as useful as every available structural child."

    /// The exact model-visible state and ordered alternatives determine both
    /// request identity and transport payload. No evaluator gold is accepted.
    pub def request(
        current: Radii.Evaluate.StateId,
        state: String,
        alternatives: Vector[Alternative]
    ): Result[Error, Request] = requestWith(
        {protocol = protocol(), question = question()}, current, state, alternatives)

    /// A policy experiment owns its model-visible protocol and question while
    /// sharing the exact retained-observation boundary. The v1 wrapper above
    /// preserves its byte-identical payload and identity.
    pub def requestWith(
        config: Config,
        current: Radii.Evaluate.StateId,
        state: String,
        alternatives: Vector[Alternative]
    ): Result[Error, Request] = {
        let keys = Vector.map(alternative -> actionKey(alternative#action), alternatives);
        if (Vector.isEmpty(alternatives)) Err(Error.NoAlternatives)
        else if (Set.size(Vector.toSet(keys)) != Vector.length(keys))
            Err(Error.DuplicateAction(Vector.join(",", keys)))
        else {
            let criteria = Vector.map(alternative ->
                (actionKey(alternative#action), JString(alternative#criterion)), alternatives)
                |> Vector.toMap;
            let payload = Json.toCompactString(JObject(Map#{
                "model" => JString(model()),
                "state" => JString(state),
                "questions" => JObject(Map#{
                    "next_action" => JObject(Map#{
                        "type" => JString("choice"),
                        "instructions" => JString(config#question),
                        "criteria" => JObject(criteria)
                    })
                })
            }));
            let canonical = canonicalPart(config#protocol) + canonicalPart(provider()) +
                canonicalPart(endpoint()) + canonicalPart(model()) + canonicalPart(payload) +
                canonicalPart(ToString.toString(current)) +
                Vector.foldLeft((text, alternative) -> text + canonicalAlternative(alternative), "", alternatives);
            Ok({
                decision = Radii.Evaluate.DecisionId.DecisionId(canonical),
                current = current,
                alternatives = alternatives,
                payload = payload
            })
        }
    }

    pub def policy(request0: Request): Result[Error, Observation] \ Choice =
        if (Vector.isEmpty(request0#alternatives)) Err(Error.NoAlternatives)
        else Choice.policy(request0)

    pub def runWithFake(index: Int32, f: Unit -> a \ ef): a \ (ef - Choice) =
        run { f() } with handler Choice {
            def policy(request0, k) = k(fake(index, request0))
        }

    pub def runWithReplay(
        observations: Map[Radii.Evaluate.DecisionId, Observation],
        f: Unit -> a \ ef
    ): a \ (ef - Choice) =
        run { f() } with handler Choice {
            def policy(request0, k) = match Map.get(request0#decision, observations) {
                case None => k(Err(Error.MissingReplay(request0#decision)))
                case Some(observation) => k(validateObservation(request0, observation))
            }
        }

    pub def runWithFixture(
        observations: Map[Radii.Evaluate.DecisionId, Observation],
        f: Unit -> a \ ef
    ): a \ (ef - Choice) = runWithReplay(observations, f)

    pub def runWithNative(f: Unit -> a \ ef): a \ (ef - Choice) + IO =
        run { f() } with handler Choice {
            def policy(request0, k) = k(decideNative(request0))
        }

    pub def runWithStoreReplay(root: String, f: Unit -> a \ ef): a \ (ef - Choice) + FileSystem = {
        let stored = readStore(root);
        run { f() } with handler Choice {
            def policy(request0, k) = k(replayStored(stored, request0))
        }
    }

    /// Acquire replays exact hits. A miss is retained as raw provider data
    /// before local admission so decoder changes never purchase it again.
    pub def runWithAcquire(root: String, f: Unit -> a \ ef): a \ (ef - Choice) + FileSystem + IO =
        run { f() } with handler Choice {
            def policy(request0, k) = k(acquireRetained(root, request0))
        }

    pub def decode(request0: Request, wire: Wire): Result[Error, Observation] = {
        let Wire.Wire(payload) = wire;
        match Json.parse(payload) {
            case Err(error) => Err(Error.Wire(ToString.toString(error)))
            case Ok(JObject(fields)) => match Map.get("error", fields) {
                case Some(value) => nativeError(value)
                case None => decodeAnswer(request0, fields)
            }
            case Ok(_) => Err(Error.Wire("expected a JSON object"))
        }
    }

    pub def actionKey(action: Action): String = match action {
        case Action.Stop => "stop"
        case Action.Follow(atom) => atomName(atom)
        case Action.FollowPath(atoms) => Vector.map(atomName, atoms)
            |> Vector.toList |> List.intersperse(">>") |> List.fold
    }

    def fake(index: Int32, request0: Request): Result[Error, Observation] =
        if (index < 0 or index >= Vector.length(request0#alternatives)) Err(Error.InvalidChoice(index))
        else {
            let choice = Vector.get(index, request0#alternatives)#action;
            Ok({
                decision = request0#decision,
                choice = choice,
                choiceIndex = index,
                probabilities = Map#{choice => 1.0},
                confidence = 1.0,
                provider = "fixture",
                actualModel = model(),
                responseId = "fixture",
                usage = {cost = None, inputTokens = None, outputTokens = None}
            })
        }

    def decideNative(request0: Request): Result[Error, Observation] \ IO =
        decode(request0, Wire.Wire(AttuneDecision.decide(request0#payload)))

    def replayStored(stored: Result[Error, Stored], request0: Request): Result[Error, Observation] =
        stored |> Result.flatMap(view ->
            Map.get(request0#decision, view#wires)
                |> Option.toOk(Error.MissingReplay(request0#decision))
                |> Result.flatMap(wire -> decode(request0, wire)))

    def acquireRetained(root: String, request0: Request): Result[Error, Observation] \ {FileSystem, IO} =
        match readStore(root) {
            case Err(error) => Err(error)
            case Ok(stored) => match Map.get(request0#decision, stored#wires) {
                case Some(wire) => decode(request0, wire)
                case None => {
                    let wire = Wire.Wire(AttuneDecision.decide(request0#payload));
                    // Java-generated transport failures are not provider
                    // observations. They remain explicit errors and never
                    // poison exact replay. Real provider envelopes are
                    // retained before local semantic admission.
                    if (nativeFailure(wire)) decode(request0, wire)
                    else match writeRaw(root, stored#count, request0#decision, wire) {
                        case Err(error) => Err(error)
                        case Ok(()) => decode(request0, wire)
                    }
                }
            }
        }

    def nativeFailure(wire: Wire): Bool = {
        let Wire.Wire(payload) = wire;
        match Json.parse(payload) {
            case Ok(JObject(fields)) => Map.memberOf("error", fields)
            case _ => false
        }
    }

    type alias Stored = {
        wires = Map[Radii.Evaluate.DecisionId, Wire],
        count = Int32
    }

    def readStore(root: String): Result[Error, Stored] \ FileSystem =
        readFiles(root, 0, Map.empty())

    def readFiles(root: String, index: Int32, wires: Map[Radii.Evaluate.DecisionId, Wire]): Result[Error, Stored] \ FileSystem = {
        let path = rawFile(root, index);
        match FileSystem.exists(path) |> Result.mapErr(storeError) {
            case Err(error) => Err(error)
            case Ok(false) => Ok({wires = wires, count = index})
            case Ok(true) => FileSystem.read(path)
                |> Result.mapErr(storeError)
                |> Result.flatMap(decodeStored)
                |> Result.flatMap(match (decision, wire) ->
                    if (Map.memberOf(decision, wires)) Err(Error.ObservationStore("duplicate retained decision"))
                    else readFiles(root, index + 1, Map.insert(decision, wire, wires)))
        }
    }

    def writeRaw(root: String, index: Int32, decision: Radii.Evaluate.DecisionId, wire: Wire): Result[Error, Unit] \ FileSystem = {
        let Radii.Evaluate.DecisionId.DecisionId(identity) = decision;
        let Wire.Wire(response) = wire;
        let payload = Json.toCompactString(JObject(Map#{
            "version" => ToJson.toJson(1),
            "provider" => JString(provider()),
            "model" => JString(model()),
            "decision_id" => JString(identity),
            "response" => JString(response)
        }));
        let written = run { FileSystem.write(str = payload, rawFile(root, index)) }
            with FileSystem.withMkParentDirs
            with FileSystem.withAtomicWrite;
        Result.mapErr(storeError, written)
    }

    def decodeStored(payload: String): Result[Error, (Radii.Evaluate.DecisionId, Wire)] =
        match Json.parse(payload) {
            case Err(error) => Err(Error.Wire(ToString.toString(error)))
            case Ok(JObject(fields)) => forM (
                version <- intField("version", fields);
                _ <- if (version == 1) Ok(()) else Err(Error.Wire("unsupported retained version"));
                actualProvider <- stringField("provider", fields);
                _ <- if (actualProvider == provider()) Ok(()) else Err(Error.Wire("retained provider mismatch"));
                actualModel <- stringField("model", fields);
                _ <- if (actualModel == model()) Ok(()) else Err(Error.Wire("retained model mismatch"));
                identity <- stringField("decision_id", fields);
                response <- stringField("response", fields)
            ) yield (Radii.Evaluate.DecisionId.DecisionId(identity), Wire.Wire(response))
            case Ok(_) => Err(Error.Wire("retained decision must be an object"))
        }

    def decodeAnswer(request0: Request, fields: Map[String, Json]): Result[Error, Observation] = forM (
        answers <- objectField("answers", fields);
        answer <- objectField("next_action", answers);
        answerType <- stringField("type", answer);
        _ <- if (answerType == "choice") Ok(()) else Err(Error.UnexpectedAnswerType(answerType));
        key <- stringField("choice", answer);
        index <- actionIndex(key, request0#alternatives);
        confidence <- floatField("confidence", answer);
        probabilities0 <- objectField("probabilities", answer);
        probabilities <- decodeProbabilities(request0#alternatives, probabilities0);
        actualModel <- stringField("model", fields);
        _ <- requireModel(actualModel);
        provider0 <- stringField("provider", fields);
        responseId <- stringField("id", fields);
        usage <- decodeUsage(fields)
    ) yield {
        decision = request0#decision,
        choice = Vector.get(index, request0#alternatives)#action,
        choiceIndex = index,
        probabilities = probabilities,
        confidence = confidence,
        provider = provider0,
        actualModel = actualModel,
        responseId = responseId,
        usage = usage
    }

    def validateObservation(request0: Request, observation: Observation): Result[Error, Observation] =
        if (request0#decision != observation#decision) Err(Error.MissingReplay(request0#decision))
        else match actionIndex(actionKey(observation#choice), request0#alternatives) {
            case Err(error) => Err(error)
            case Ok(index) if index != observation#choiceIndex => Err(Error.InvalidChoice(observation#choiceIndex))
            case Ok(_) => Ok(observation)
        }

    def actionIndex(key: String, alternatives: Vector[Alternative]): Result[Error, Int32] =
        Vector.mapWithIndex((index, alternative) -> (index, actionKey(alternative#action)), alternatives)
        |> Vector.find(match (_, candidate) -> candidate == key)
        |> Option.map(fst)
        |> Option.toOk(Error.UnknownAction(key))

    def decodeProbabilities(alternatives: Vector[Alternative], fields: Map[String, Json]): Result[Error, Map[Action, Float64]] =
        Vector.traverse(alternative -> {
            let key = actionKey(alternative#action);
            match Map.get(key, fields) {
                case None => Err(Error.MissingProbability(key))
                case Some(value) => FromJson.fromJson(value)
                    |> Result.map(probability -> (alternative#action, probability))
                    |> Result.mapErr(error -> Error.Wire("probability ${key}: ${ToString.toString(error)}"))
            }
        }, alternatives) |> Result.map(Vector.toMap)

    def decodeUsage(fields: Map[String, Json]): Result[Error, Usage] =
        match Map.get("usage", fields) {
            case None => Ok({cost = None, inputTokens = None, outputTokens = None})
            case Some(JNull) => Ok({cost = None, inputTokens = None, outputTokens = None})
            case Some(JObject(usage)) => forM (
                cost <- optionalFloatField("cost", usage);
                input <- optionalIntField("input_tokens", usage);
                output <- optionalIntField("output_tokens", usage)
            ) yield {cost = cost, inputTokens = input, outputTokens = output}
            case Some(_) => Err(Error.Wire("usage: expected object or null"))
        }

    def nativeError(value: Json): Result[Error, Observation] = match value {
        case JObject(fields) => match stringField("kind", fields) {
            case Err(error) => Err(error)
            case Ok(kind) => match stringField("message", fields) {
                case Err(error) => Err(error)
                case Ok(message) => Err(Error.Native(kind, message))
            }
        }
        case _ => Err(Error.Wire("error must be an object"))
    }

    def requireModel(actual: String): Result[Error, Unit] =
        if (actual == model() or String.startsWith(prefix = model() + "-", actual)) Ok(())
        else Err(Error.UnexpectedModel(actual))

    def atomName(atom: Radii.Atom): String = match atom {
        case Radii.Atom.Defines => "defines"
        case Radii.Atom.DefinedIn => "defined_in"
        case Radii.Atom.Imports => "imports"
        case Radii.Atom.ImportedBy => "imported_by"
        case Radii.Atom.Calls => "calls"
        case Radii.Atom.Callers => "callers"
        case Radii.Atom.Callees => "callees"
        case Radii.Atom.SameFile => "same_file"
        case Radii.Atom.ImportNeighbors => "import_neighbors"
        case Radii.Atom.ImporterNeighbors => "importer_neighbors"
        case Radii.Atom.Parent => "parent"
        case Radii.Atom.RepositoryAdjacent => "repository_adjacent"
    }

    def canonicalAlternative(alternative: Alternative): String =
        canonicalPart(actionKey(alternative#action)) +
        canonicalPart(ToString.toString(alternative#expression)) +
        canonicalPart(ToString.toString(alternative#state)) +
        canonicalPart(alternative#criterion)

    def canonicalPart(value: String): String = "${String.length(value)}:${value}"
    def rawFile(root: String, index: Int32): String = "${root}/raw/decision-${index}.json"
    def storeError(error: IoError): Error = Error.ObservationStore(ToString.toString(error))

    def field(name: String, fields: Map[String, Json]): Result[Error, Json] =
        Map.get(name, fields) |> Option.toOk(Error.Wire("missing JSON field: ${name}"))

    def objectField(name: String, fields: Map[String, Json]): Result[Error, Map[String, Json]] =
        match field(name, fields) {
            case Err(error) => Err(error)
            case Ok(JObject(value)) => Ok(value)
            case Ok(_) => Err(Error.Wire("${name}: expected object"))
        }

    def stringField(name: String, fields: Map[String, Json]): Result[Error, String] = match field(name, fields) {
        case Err(error) => Err(error)
        case Ok(JString(value)) => Ok(value)
        case Ok(_) => Err(Error.Wire("${name}: expected string"))
    }

    def intField(name: String, fields: Map[String, Json]): Result[Error, Int32] =
        field(name, fields) |> Result.flatMap(value -> FromJson.fromJson(value)
            |> Result.mapErr(error -> Error.Wire("${name}: ${ToString.toString(error)}")))

    def floatField(name: String, fields: Map[String, Json]): Result[Error, Float64] =
        field(name, fields) |> Result.flatMap(value -> FromJson.fromJson(value)
            |> Result.mapErr(error -> Error.Wire("${name}: ${ToString.toString(error)}")))

    def optionalIntField(name: String, fields: Map[String, Json]): Result[Error, Option[Int32]] = match Map.get(name, fields) {
        case None => Ok(None)
        case Some(JNull) => Ok(None)
        case Some(value) => FromJson.fromJson(value) |> Result.map(Some)
            |> Result.mapErr(error -> Error.Wire("${name}: ${ToString.toString(error)}"))
    }

    def optionalFloatField(name: String, fields: Map[String, Json]): Result[Error, Option[Float64]] = match Map.get(name, fields) {
        case None => Ok(None)
        case Some(JNull) => Ok(None)
        case Some(value) => FromJson.fromJson(value) |> Result.map(Some)
            |> Result.mapErr(error -> Error.Wire("${name}: ${ToString.toString(error)}"))
    }
}
