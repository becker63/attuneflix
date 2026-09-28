/// Deterministic Markdown projections of recorded families tables. The charter
/// report embeds these blocks verbatim and `report_test` requires them to match
/// the regenerated projection byte for byte, so report numbers are never typed
/// by hand.
pub mod Families.Report {
    /// The inventory table in the given (declared) world order, with a totals row.
    pub def inventory(values: Vector[Families.Inventory.Inventory]): String = {
        let header = Vector#{
            "| repository | snapshot | files | callables | directories | imports | calls | parents | callable source bytes |",
            "|---|---|---:|---:|---:|---:|---:|---:|---:|"
        };
        let total = Vector.foldLeft((sum, value) -> sum + value#callableSourceBytes, 0i64, values);
        let footer = "| **total** | | ${sumOf(value -> value#files, values)} | ${sumOf(value -> value#callables, values)} | " +
            "${sumOf(value -> value#directories, values)} | ${sumOf(value -> value#imports, values)} | " +
            "${sumOf(value -> value#calls, values)} | ${sumOf(value -> value#parents, values)} | ${total} |";
        Vector.join("\n", Vector.append(Vector.append(header, Vector.map(line, values)), Vector#{footer})) + "\n"
    }

    def line(value: Families.Inventory.Inventory): String =
        "| ${value#repository} | `${shortSnapshot(value#snapshotId)}` | ${value#files} | ${value#callables} | " +
        "${value#directories} | ${value#imports} | ${value#calls} | ${value#parents} | ${value#callableSourceBytes} |"

    def sumOf(field: Families.Inventory.Inventory -> Int32, values: Vector[Families.Inventory.Inventory]): Int32 =
        Vector.foldLeft((sum, value) -> sum + field(value), 0, values)

    /// The first twelve hex digits of the snapshot digest, the census display form.
    def shortSnapshot(snapshotId: String): String = {
        let digest = match String.indexOfRight(substr = ":", snapshotId) {
            case None => snapshotId
            case Some(index) => String.sliceRight(start = index + 1, snapshotId)
        };
        String.sliceLeft(end = 12, digest)
    }
}
