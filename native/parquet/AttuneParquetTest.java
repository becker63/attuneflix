package attune.parquet;

import java.nio.file.Files;
import java.nio.file.Path;

public final class AttuneParquetTest {
    private AttuneParquetTest() {}

    public static void main(String[] args) throws Exception {
        if (args.length == 1) {
            String retained = AttuneParquet.readRows(args[0]);
            if (!retained.startsWith("[{") || !retained.contains("\"path\"")) {
                throw new AssertionError("retained Parquet did not decode as tree rows");
            }
            return;
        }
        Path directory = Files.createTempDirectory("attune-parquet-test-");
        Path artifact = directory.resolve("nested.parquet");
        String payload = "[{\"path\":[],\"type\":\"object\",\"string\":null," +
                "\"integer\":null,\"floating\":null,\"bool\":null}," +
                "{\"path\":[\"k:value\"],\"type\":\"integer\",\"string\":null," +
                "\"integer\":1,\"floating\":null,\"bool\":null}]";
        AttuneParquet.writeRows(artifact.toString(), payload);
        String actual = AttuneParquet.readRows(artifact.toString());
        if (!payload.equals(actual)) {
            throw new AssertionError("Parquet semantic round-trip changed the object: " + actual);
        }
        if (!payload.equals(AttuneParquet.canonicalizeRows(payload))) {
            throw new AssertionError("canonicalization changed tree rows");
        }
        byte[] magic = Files.readAllBytes(artifact);
        if (magic.length < 8 || magic[0] != 'P' || magic[1] != 'A' ||
                magic[2] != 'R' || magic[3] != '1') {
            throw new AssertionError("artifact is not Parquet");
        }
        Files.delete(artifact);
        Files.delete(directory);
    }
}
