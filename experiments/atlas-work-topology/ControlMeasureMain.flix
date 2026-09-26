/// Executable surface for the control work-topology measurement; the shell
/// wrapper passes the committed evidence and artifact paths as JVM properties.
def main(): Unit \ IO = ControlMeasure.execute()
