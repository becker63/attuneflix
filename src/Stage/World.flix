/// Stage 2 — World Admission: `RawFactManifest -> AdmittedWorld`. A pure
/// transformation: it partitions the raw facts by relation, projects each into
/// the repository fact shape, and admits them into one world with dense ordinal
/// IDs, resolved module imports, and the indexed call graph. No effect appears
/// here — the world is a function of the manifest alone.
pub mod Stage.World {
    use Kernel.Contract.{AdmittedWorld, FactKind, RawFact, RawFactManifest}

    /// Admit the manifest: split the facts by relation, then hand the admitted
    /// files and each relation's facts to the one pure admission rule.
    pub def admit(manifest: RawFactManifest): Result[World.Error, AdmittedWorld] =
        World.Admission.admit(
            manifest#files,
            factsOf(FactKind.Defines, manifest#facts),
            factsOf(FactKind.Imports, manifest#facts),
            factsOf(FactKind.Calls, manifest#facts)
        )

    /// Project the raw facts of one relation into the repository fact shape.
    /// `kind` restores the Grit log message the language rules already speak.
    def factsOf(kind: FactKind, facts: Vector[RawFact]): Vector[Repository.Grit.Fact] =
        Vector.filterMap(fact ->
            if (fact#kind != kind) None
            else Some({
                kind      = kindName(kind),
                path      = fact#path,
                startByte = fact#startByte,
                endByte   = fact#endByte,
                value     = fact#value
            }), facts)

    def kindName(kind: FactKind): String = match kind {
        case FactKind.Defines => "definition"
        case FactKind.Imports => "import"
        case FactKind.Calls   => "call"
    }
}
