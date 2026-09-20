mod Grit {
    import attune.grit.AttuneGrit

    pub enum Language with Eq, Order, ToString, Hash {
        case TypeScript
    }

    /// Stable wire observation. Pure decoding/normalization belongs above the handler.
    pub enum Wire(String) with Eq, Order, ToString, Hash

    /// Source extraction is a narrow capability, not permission for arbitrary IO.
    pub eff Eval {
        def evaluate(language: Language, program: String, path: String, source: String): Wire
    }

    pub def evaluate(language: Language, program: String, path: String, source: String): Wire \ Eval =
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

    def evaluateNative(language: Language, program: String, path: String, source: String): Wire \ IO =
        let name = match language { case Language.TypeScript => "typescript" };
        Wire.Wire(AttuneGrit.evaluate(name, program, path, source))
}
