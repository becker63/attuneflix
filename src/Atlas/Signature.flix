pub mod Atlas.Signature {
    /// One exact observation from applying one Atlas program to one seed.
    pub type alias Observation = {
        program              = Atlas.Program,
        input                = Atlas.State,
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
            let family = Atlas.programs(depth);
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
                    input = input,
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
}
