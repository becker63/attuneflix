mod Repository {
    pub type alias Symbol = {
        path      = String,
        name      = String,
        startByte = Int32,
        endByte   = Int32
    }

    pub type alias World = {
        files             = Vector[String],
        symbols           = Vector[Symbol],
        defines           = Repository.Structure.Defines,
        imports           = Repository.Structure.Imports,
        calls             = Repository.Structure.Calls,
        parents           = Repository.Structure.Parents,
        unresolvedImports = Int32,
        unresolvedCalls   = Int32
    }
}
