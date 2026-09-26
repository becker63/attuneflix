/// Executable surface for the control signature instrument; the shell wrapper
/// passes the committed evidence and artifact paths as JVM properties.
def main(): Unit \ IO = ControlSignature.execute()
