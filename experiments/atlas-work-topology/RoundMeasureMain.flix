/// Executable surface for the Round 1 candidate measurement; the shell wrapper
/// passes the committed evidence and artifact paths as JVM properties.
def main(): Unit \ IO = RoundMeasure.execute()
