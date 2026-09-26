/// Work-topology experiment executable surface; the shell wrapper passes the
/// frozen worktree and artifact paths as JVM properties, never as ambient
/// environment state.
def main(): Unit \ IO = ControlAcquisition.execute()
