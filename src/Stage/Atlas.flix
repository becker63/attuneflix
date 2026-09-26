/// Stage 3B — Atlas exploration: `AdmittedWorld -> AtlasCandidateOutcomes`. It
/// enumerates the finite composition-only six-atom family from the seed's
/// domain, evaluates every program through the memoized physical evaluator, and
/// projects each exact typed state with its depth and reach fraction. The stage
/// is pure and deterministic; its only mutable state is the query-local memo,
/// which cannot escape, and it shares nothing with Stage 3A.
pub mod Stage.Atlas {
    use Kernel.Contract.{AdmittedWorld, Atom, AtlasCandidateOutcomes, AtlasOutcome, Program, State}

    /// Explore the complete Atlas family compatible with the seed domain
    /// through `depth`, reporting each program's exact typed result state.
    pub def explore(world: AdmittedWorld, seed: State, depth: Int32): Result[String, AtlasCandidateOutcomes] =
        if (depth < 1)
            Err("Atlas exploration depth must be at least one")
        else {
            let atlasSeed = seedToAtlas(seed);
            let family = Atlas.programsFrom(Atlas.stateDomain(atlasSeed), depth);
            Atlas.evaluate(world, atlasSeed, family)
                |> Result.map(evaluation -> {
                    let outcomes = Vector.mapWithIndex((index, program) ->
                        outcomeOf(world, evaluation, index, program), family);
                    { outcomes = outcomes }
                })
        }

    /// Project one evaluated program into the kernel outcome ADT: the program,
    /// its exact result state, its depth, and the state's reach fraction.
    def outcomeOf(
        world: AdmittedWorld,
        evaluation: Atlas.Evaluation,
        index: Int32,
        program: Atlas.Program
    ): AtlasOutcome = {
        let output = Vector.get(index, evaluation#outputs);
        {
            program = programToKernel(program),
            state = stateToKernel(output),
            depth = Vector.length(program#steps),
            reach = reachFraction(world, output)
        }
    }

    /// Reach fraction: the result cardinality over the seed domain's admitted
    /// cardinality, so a fully reached domain is 1.0 and an extinct state 0.0.
    def reachFraction(world: AdmittedWorld, state: Atlas.State): Float64 = {
        let total = domainSize(world, Atlas.stateDomain(state));
        if (total == 0) 0.0
        else Int32.toFloat64(Atlas.cardinality(state)) / Int32.toFloat64(total)
    }

    def domainSize(world: AdmittedWorld, domain: Radii.Domain): Int32 = match domain {
        case Radii.Domain.File     => Vector.length(world#files)
        case Radii.Domain.Symbol   => Vector.length(world#symbols)
        case Radii.Domain.Location => 0
    }

    // The kernel contract and the Atlas family declare structurally identical
    // atoms and states. The stage owns the total bridge between them; the
    // frozen Atlas grammar itself is untouched.
    def seedToAtlas(state: State): Atlas.State = match state {
        case State.Files(values)   => Atlas.State.Files(values)
        case State.Symbols(values) => Atlas.State.Symbols(values)
    }

    def stateToKernel(state: Atlas.State): State = match state {
        case Atlas.State.Files(values)   => State.Files(values)
        case Atlas.State.Symbols(values) => State.Symbols(values)
    }

    def programToKernel(program: Atlas.Program): Program = {
        steps = Vector.map(atomToKernel, program#steps)
    }

    def atomToKernel(atom: Atlas.Atom): Atom = match atom {
        case Atlas.Atom.Defines    => Atom.Defines
        case Atlas.Atom.DefinedIn  => Atom.DefinedIn
        case Atlas.Atom.Imports    => Atom.Imports
        case Atlas.Atom.ImportedBy => Atom.ImportedBy
        case Atlas.Atom.Calls      => Atom.Calls
        case Atlas.Atom.Callers    => Atom.Callers
    }
}
