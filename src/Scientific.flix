/// Scientific data root: the pure table semantics (`Scientific.Schema`,
/// `Scientific.Value`, `Scientific.Row`) are read-only meaning over the kernel
/// schema types, and `Scientific.Parquet` is the one isolated Parquet/Arrow
/// transport seam. Nothing else in the tree talks to the native transport.
pub mod Scientific {}
