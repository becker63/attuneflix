/// Small execution shell shared by Bazel experiment actions.
///
/// Starlark passes declared artifact paths as indexed JVM properties. These
/// strings are action transport, not scientific data: the files themselves
/// carry typed Parquet schemas and identities.
pub mod Experiment {
    import java.lang.System
    import java.lang.Integer

    pub def property(name: String): String \ IO = System.getProperty(name)

    pub def count(prefix: String): Int32 \ IO =
        Integer.parseInt(property("${prefix}.count"))

    pub def paths(prefix: String): Vector[String] \ IO =
        Vector.map(index -> property("${prefix}.${index}"), Vector.range(0, count(prefix)))

    pub def require(result: Result[String, a]): a = match result {
        case Ok(value) => value
        case Err(error) => bug!(error)
    }
}
