/// Frozen experiment population after admission from external benchmark data.
pub mod Population {
    pub enum Outcome with Eq, ToString {
        case Completed
        case Censored(String)
    }

    pub type alias Protocol = {
        benchmarkRevision   = String,
        multilingualRevision = String,
        proRevision         = String,
        sourceRouting       = String,
        atlasProtocol       = String,
        maxDepth            = Int32,
        centerCount         = Int32,
        logicalRoutes       = Int32,
        symbolRoutes        = Int32
    }

    pub type alias Case = {
        ordinal        = Int32,
        instanceId     = String,
        repository     = String,
        baseRevision   = String,
        datasetFamily  = String,
        language       = String,
        population     = String,
        split          = String,
        sourceRouting  = String,
        sourceIdentity = String,
        outcome        = Outcome
    }

    pub type alias Frozen = {
        protocol = Protocol,
        cases    = Vector[Case]
    }
}
