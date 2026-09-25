/// Acquisition executable surface; Starlark or the seam passes the frozen
/// worktree and artifact paths as JVM properties.
def main(): Unit \ IO = AcquisitionDriver.execute()
