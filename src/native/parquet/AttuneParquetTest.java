package attune.parquet;

import java.nio.file.Files;
import java.nio.file.Path;

public final class AttuneParquetTest {
    private AttuneParquetTest() {}

    public static void main(String[] args) throws Exception {
        Path directory = Files.createTempDirectory("attune-parquet-test-");
        Path table = directory.resolve("typed.parquet");
        String schema = "{\"format\":\"attune-test-rows-v1\",\"columns\":[" +
                "{\"name\":\"identity\",\"type\":\"string\",\"nullable\":false}," +
                "{\"name\":\"depth\",\"type\":\"int32\",\"nullable\":false}," +
                "{\"name\":\"ordinal\",\"type\":\"int64\",\"nullable\":false}," +
                "{\"name\":\"score\",\"type\":\"float64\",\"nullable\":true}," +
                "{\"name\":\"extinct\",\"type\":\"boolean\",\"nullable\":false}," +
                "{\"name\":\"route\",\"type\":\"list<string>\",\"nullable\":false}]}";
        String tableRows = "[{\"identity\":\"seed-0\",\"depth\":7,\"ordinal\":0,\"score\":null," +
                "\"extinct\":false,\"route\":[\"calls\",\"defined_in\"]}]";
        String admitted = AttuneParquet.writeTable(table.toString(), schema, tableRows);
        if (!tableRows.equals(admitted) || !tableRows.equals(AttuneParquet.readTable(table.toString(), schema))) {
            throw new AssertionError("typed Parquet round-trip changed rows: " + admitted);
        }
        try {
            AttuneParquet.readTable(table.toString(), schema.replace("\"ordinal\",\"type\":\"int64\"",
                    "\"ordinal\",\"type\":\"string\""));
            throw new AssertionError("typed Parquet admitted the wrong physical schema");
        } catch (IllegalStateException expected) {
            // Exact column names, types, and nullability are part of admission.
        }
        byte[] magic = Files.readAllBytes(table);
        if (magic.length < 8 || magic[0] != 'P' || magic[1] != 'A' ||
                magic[2] != 'R' || magic[3] != '1') {
            throw new AssertionError("artifact is not Parquet");
        }
        Files.delete(table);
        Files.delete(directory);
    }
}
