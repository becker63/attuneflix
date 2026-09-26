/// Stage 1 — Acquisition: `SourceManifest -> RawFactManifest`. The stage detects
/// each file's language from its path, runs the three canonical relation
/// programs through `eff Grit`, and normalizes every language's syntax into the
/// one `RawFact` shape. No native seam, no source parsing, and no admission rule
/// appears here: the effect handler owns the engine, and admission owns the
/// world.
pub mod Stage.Acquire {
    use Kernel.Contract.{FactKind, RawFact, RawFactManifest, SourceFile, SourceManifest}
    use Kernel.Effect.CapabilityError

    /// Acquire one manifest: every file contributes its Defines/Imports/Calls
    /// facts in that canonical order and the manifest carries them forward.
    pub def acquire(manifest: SourceManifest): Result[CapabilityError, RawFactManifest] \ Kernel.Effect.Grit =
        Vector.traverse(file -> fileFacts(file), manifest#files)
            |> Result.map(groups -> {
                repository = manifest#repository,
                revision   = manifest#revision,
                files      = manifest#files,
                facts      = Vector.flatten(groups)
            })

    /// A file with no admitted language contributes nothing; otherwise the three
    /// relation programs run in the frozen Defines/Imports/Calls order.
    def fileFacts(file: SourceFile): Result[CapabilityError, Vector[RawFact]] \ Kernel.Effect.Grit =
        match Repository.Grit.language(file#path) {
            case None => Ok(Vector.empty())
            case Some(language) =>
                let name = Repository.Grit.name(language);
                forM (
                    definitions <- Kernel.Effect.Grit.extract(name, FactKind.Defines, file#path, file#content);
                    imports <- Kernel.Effect.Grit.extract(name, FactKind.Imports, file#path, file#content);
                    calls <- Kernel.Effect.Grit.extract(name, FactKind.Calls, file#path, file#content)
                ) yield Vector.append(definitions, Vector.append(imports, calls))
        }
}
