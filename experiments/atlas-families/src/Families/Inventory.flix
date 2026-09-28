/// The acquisition inventory of one admitted world: exactly the quantities a
/// families acquisition pass is sized by, derived from the admitted world alone.
///
/// Callables are the admitted `Defines` symbols (the frozen embedding document
/// grain); `callableSourceBytes` sums their exact admitted spans, which bounds
/// the embedding document text before the frozen per-document text limit. No
/// issue, provider, decision, or gold input exists at this boundary.
pub mod Families.Inventory {
    pub type alias Inventory = {
        snapshotId          = String,
        repository          = String,
        files               = Int32,
        callables           = Int32,
        directories         = Int32,
        imports             = Int32,
        calls               = Int32,
        parents             = Int32,
        callableSourceBytes = Int64
    }

    pub def of(identity: Repository.Table.Identity, world: Repository.World): Inventory = {
        snapshotId = identity#snapshotId,
        repository = identity#repository,
        files = Vector.length(world#files),
        callables = Vector.length(world#symbols),
        directories = Vector.length(Repository.Location.directories(world)),
        imports = Set.size(world#imports),
        calls = Set.size(world#calls),
        parents = Set.size(world#parents),
        callableSourceBytes = Vector.foldLeft(
            (total, symbol) -> total + Int32.toInt64(symbol#endByte - symbol#startByte),
            0i64, world#symbols)
    }
}
