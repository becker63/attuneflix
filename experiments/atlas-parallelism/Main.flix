/// Executable surface of the self-signature parallelism experiment. Starlark
/// passes typed artifact paths as indexed JVM properties; the scientific
/// meaning lives in Parallelism (see PREREGISTRATION.md).
def main(): Unit \ IO = Parallelism.execute()
