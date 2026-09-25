pub mod Atlas.Signature {
    pub type alias Seed = {
        domain   = Radii.Domain,
        identity = String,
        ordinal  = Int32,
        state    = Atlas.State
    }

    pub def atomName(atom: Atlas.Atom): String = match atom {
        case Atlas.Atom.Defines    => "defines"
        case Atlas.Atom.DefinedIn  => "defined_in"
        case Atlas.Atom.Imports    => "imports"
        case Atlas.Atom.ImportedBy => "imported_by"
        case Atlas.Atom.Calls      => "calls"
        case Atlas.Atom.Callers    => "callers"
    }

    pub def domainName(domain: Radii.Domain): String = match domain {
        case Radii.Domain.File     => "file"
        case Radii.Domain.Symbol   => "symbol"
        case Radii.Domain.Location => "location"
    }

    /// Canonical scientific payload for one syntactic Atlas route. The
    /// protocol prefix stays outside this value so identity version changes
    /// are explicit rather than hidden inside the bytes.
    pub def routePayload(program: Atlas.Program): String =
        Vector.map(atomName, program#steps) |> Vector.join(",")

    pub def routeId(program: Atlas.Program): String \ IO =
        ScientificIdentity.versioned("atlas-route-v1", routePayload(program))

    /// Canonical scientific payload for one semantic result state. Nominal
    /// IDs are sorted explicitly; evaluator allocation order is irrelevant.
    pub def statePayload(state: Atlas.State): String = match state {
        case Atlas.State.Files(values) =>
            "file:${orderedFiles(values) |> Vector.join(",")}" 
        case Atlas.State.Symbols(values) =>
            "symbol:${orderedSymbols(values) |> Vector.join(",")}" 
    }

    pub def stateId(state: Atlas.State): String \ IO =
        ScientificIdentity.versioned("atlas-state-v1", statePayload(state))

    /// One exact observation from applying one Atlas program to one seed.
    pub type alias Observation = {
        program              = Atlas.Program,
        output               = Atlas.State,
        depth                = Int32,
        inputCardinality     = Int32,
        outputCardinality    = Int32,
        domainCardinality    = Int32,
        expansionRatio       = Option[Float64],
        reachFraction        = Float64,
        extinct              = Bool,
        firstExtinctionDepth = Option[Int32],
        sameAsInput          = Bool
    }

    /// The deterministic structural response of one seed in one repository.
    pub type alias Signature = {
        depth               = Int32,
        observations        = Vector[Observation],
        logicalPrograms     = Int32,
        uniqueStates        = Int32,
        physicalTransitions = Int32,
        transitionReuses    = Int32
    }

    pub def compute(
        repository: Repository.World,
        input: Atlas.State,
        depth: Int32
    ): Result[String, Signature] = {
        if (depth < 1)
            Err("Atlas signature depth must be positive")
        else {
            let family = Atlas.programsFrom(Atlas.stateDomain(input), depth);
            Atlas.evaluate(repository, input, family)
                |> Result.flatMap(evaluation -> {
                    let outputs = Vector.zip(family, evaluation#outputs)
                        |> Vector.map(match (program, output) -> (program#steps, output))
                        |> Vector.toMap;
                    Vector.mapWithIndex((index, program) -> observation(
                        repository,
                        input,
                        program,
                        Vector.get(index, evaluation#outputs),
                        outputs
                    ), family)
                    |> Vector.sequence
                    |> Result.map(observations -> {
                        depth = depth,
                        observations = observations,
                        logicalPrograms = Vector.length(family),
                        uniqueStates = Vector.map(row -> row#output, observations)
                            |> Vector.toSet
                            |> Set.size,
                        physicalTransitions = evaluation#physicalTransitions,
                        transitionReuses = evaluation#transitionReuses
                    })
                })
        }
    }

    /// The issue-blind seed panel declared by atlas-signature-seeds-v1.
    /// Selection hashes stable repository identities, never nominal ordinal
    /// order, issue text, embedding rank, or filesystem enumeration order.
    pub def seeds(repository: Repository.World): Vector[Seed] \ IO =
        Vector.append(fileSeeds(repository#files), symbolSeeds(repository#symbols))

    def fileSeeds(files: Vector[String]): Vector[Seed] \ IO =
        panel(Radii.Domain.File, files, ordinal ->
            Atlas.State.Files(Set.singleton(Repository.Structure.FileId.FileId(ordinal))))

    def symbolSeeds(symbols: Vector[Repository.Symbol]): Vector[Seed] \ IO =
        panel(Radii.Domain.Symbol, Vector.map(symbol ->
            "${symbol#path}\u0000${symbol#name}\u0000${symbol#startByte}\u0000${symbol#endByte}", symbols),
            ordinal ->
            Atlas.State.Symbols(Set.singleton(Repository.Structure.SymbolId.SymbolId(ordinal))))

    /// One select-sort-truncate-project seed panel: hash each identity under
    /// the frozen atlas-signature-seeds-v1 domain-prefix bytes, order by
    /// (digest, identity), keep the first eight, and project to Seeds.
    def panel(domain: Radii.Domain, identities: Vector[String],
              toState: Int32 -> Atlas.State): Vector[Seed] \ IO = {
        let ranked = Vector.mapWithIndex((ordinal, identity) -> (
            ScientificIdentity.sha256("${domainName(domain)}\u0000${identity}"),
            identity,
            ordinal,
            toState(ordinal)
        ), identities)
            |> Vector.sortBy(match (digest, identity, _, _) -> (digest, identity));
        Vector.take(8, ranked)
            |> Vector.map(match (_, identity, ordinal, state) -> {
                domain = domain,
                identity = identity,
                ordinal = ordinal,
                state = state
            })
    }

    def observation(
        repository: Repository.World,
        seed: Atlas.State,
        program: Atlas.Program,
        output: Atlas.State,
        outputs: Map[Vector[Atlas.Atom], Atlas.State]
    ): Result[String, Observation] = {
        let depth = Vector.length(program#steps);
        let prefix = Vector.slice(start = 0, end = depth - 1, program#steps);
        let inputResult = if (Vector.isEmpty(prefix)) Ok(seed)
            else Map.get(prefix, outputs)
                |> Option.toOk("Atlas signature is missing a program prefix");
        inputResult |> Result.flatMap(input ->
            firstExtinction(program#steps, outputs, 1)
            |> Result.map(firstExtinctionDepth -> {
                let inputCardinality = Atlas.cardinality(input);
                let outputCardinality = Atlas.cardinality(output);
                let domainCardinality = domainSize(repository, Atlas.stateDomain(output));
                {
                    program = program,
                    output = output,
                    depth = depth,
                    inputCardinality = inputCardinality,
                    outputCardinality = outputCardinality,
                    domainCardinality = domainCardinality,
                    expansionRatio = if (inputCardinality == 0) None
                        else Some(Int32.toFloat64(outputCardinality) /
                            Int32.toFloat64(inputCardinality)),
                    reachFraction = if (domainCardinality == 0) 0.0
                        else Int32.toFloat64(outputCardinality) /
                            Int32.toFloat64(domainCardinality),
                    extinct = outputCardinality == 0,
                    firstExtinctionDepth = firstExtinctionDepth,
                    sameAsInput = input == output
                }
            }))
    }

    def firstExtinction(
        steps: Vector[Atlas.Atom],
        outputs: Map[Vector[Atlas.Atom], Atlas.State],
        currentDepth: Int32
    ): Result[String, Option[Int32]] =
        if (currentDepth > Vector.length(steps))
            Ok(None)
        else {
            let prefix = Vector.slice(start = 0, end = currentDepth, steps);
            match Map.get(prefix, outputs) {
                case None => Err("Atlas signature is missing an extinction prefix")
                case Some(state) =>
                    if (Atlas.cardinality(state) == 0) Ok(Some(currentDepth))
                    else firstExtinction(steps, outputs, currentDepth + 1)
            }
        }

    def domainSize(repository: Repository.World, domain: Radii.Domain): Int32 = match domain {
        case Radii.Domain.File     => Vector.length(repository#files)
        case Radii.Domain.Symbol   => Vector.length(repository#symbols)
        case Radii.Domain.Location => 0
    }

    def orderedFiles(values: Set[Repository.Structure.FileId]): Vector[String] =
        Set.toVector(values)
            |> Vector.map(match Repository.Structure.FileId.FileId(value) -> value)
            |> Vector.sort
            |> Vector.map(value -> "${value}")

    def orderedSymbols(values: Set[Repository.Structure.SymbolId]): Vector[String] =
        Set.toVector(values)
            |> Vector.map(match Repository.Structure.SymbolId.SymbolId(value) -> value)
            |> Vector.sort
            |> Vector.map(value -> "${value}")
}
