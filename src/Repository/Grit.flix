pub mod Repository.Grit {
    /// Stable source observation after byte-range projection.
    pub type alias Fact = {
        kind      = String,
        path      = String,
        startByte = Int32,
        endByte   = Int32,
        value     = String
    }
}
