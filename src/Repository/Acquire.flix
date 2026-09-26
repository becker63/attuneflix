pub mod Repository.Acquire {
    import attune.grit.AttuneGrit

    use Repository.Grit.{Language, Program, Wire}

    /// Run one relation program against one source through the real native Grit
    /// engine. This is the whole program dispatch/native boundary: the language
    /// and the relation select one packaged `.grit` entry point, and the frozen
    /// ABI executes it. Language-specific syntax never leaves this seam. The
    /// typed acquisition stage above it (`Stage.Acquire`) drives the engine
    /// through `eff Grit`; this low-level entry point remains only for the
    /// frozen acquisition instrument that runs the engine directly.
    pub def evaluate(language: Language, program: Program, path: String, source: String): Wire \ IO = {
        let name = Repository.Grit.name(language);
        Wire.Wire(AttuneGrit.evaluate(
            name,
            AttuneGrit.program(name, Repository.Grit.programName(program)),
            path,
            source))
    }
}
