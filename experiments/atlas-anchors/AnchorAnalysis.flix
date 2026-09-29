/// The frozen sixteen-seed, depth-seven signature is evaluated identically
/// for baseline and every boundary mask. This module owns new reductions only.
pub mod AnchorAnalysis {
    pub type alias Run = {seed = Atlas.Signature.Seed, signature = Atlas.Signature.Signature}
    pub type alias Domain = {
        decomposition = Anchor.Decomposition,
        reachP90 = Float64
    }
    pub type alias Scenario = {
        intervention = String,
        maskedImports = Int32,
        maskedCalls = Int32,
        crossingVolume = Int32,
        file = Domain,
        symbol = Domain,
        physicalCompression = Float64,
        physicalReuse = Float64
    }

    pub def evaluate(world: Repository.World, seeds: Vector[Atlas.Signature.Seed]): Result[String, Vector[Run]] =
        Vector.traverse(seed -> Atlas.Signature.compute(world, seed#state, 7)
            |> Result.map(signature -> {seed = seed, signature = signature}), seeds)

    pub def outputs(runs: Vector[Run], domain: Radii.Domain): Vector[Atlas.State] =
        Vector.filter(row -> row#seed#domain == domain, runs)
            |> Vector.flatMap(row -> Vector.map(observation -> observation#output,
                row#signature#observations))

    def domain(runs: Vector[Run], seedDomain: Radii.Domain): Domain = {
        let observations = Vector.filter(row -> row#seed#domain == seedDomain, runs)
            |> Vector.flatMap(row -> row#signature#observations);
        {
            decomposition = Anchor.decompose(Vector.map(row -> row#output, observations)),
            reachP90 = Atlas.Signature.Summary.quantile(
                Vector.map(row -> row#reachFraction, observations), 90)
        }
    }

    pub def scenario(original: Repository.World, world: Repository.World,
                     intervention: String, runs: Vector[Run]): Scenario = {
        let compressions = Vector.map(row -> ScientificTable.ratio(
            row#signature#logicalPrograms, row#signature#physicalTransitions), runs)
            |> Vector.sort;
        let length = Vector.length(compressions);
        let compression = if (length == 0) 0.0
            else if (Int32.remainder(length, 2) == 1) Vector.get(length / 2, compressions)
            else (Vector.get(length / 2 - 1, compressions) + Vector.get(length / 2, compressions)) / 2.0;
        let evaluations = Vector.foldLeft((sum, row) -> sum + row#signature#physicalTransitions, 0, runs);
        let reuses = Vector.foldLeft((sum, row) -> sum + row#signature#transitionReuses, 0, runs);
        {
            intervention = intervention,
            maskedImports = Set.size(original#imports) - Set.size(world#imports),
            maskedCalls = Set.size(original#calls) - Set.size(world#calls),
            crossingVolume = Set.size(original#imports) - Set.size(world#imports) +
                Set.size(original#calls) - Set.size(world#calls),
            file = domain(runs, Radii.Domain.File),
            symbol = domain(runs, Radii.Domain.Symbol),
            physicalCompression = compression,
            physicalReuse = ScientificTable.ratio(reuses, evaluations + reuses)
        }
    }
}
