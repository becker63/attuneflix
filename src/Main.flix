def main(): Unit \ IO = {
    let counts = Atlas.counts(7);
    println("AttuneFlix Atlas depth 7: ${counts#logical} prefixes, ${counts#complete} Symbol programs")
}
