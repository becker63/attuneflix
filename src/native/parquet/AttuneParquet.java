package attune.parquet;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.channels.Channels;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Consumer;
import org.apache.arrow.dataset.file.DatasetFileWriter;
import org.apache.arrow.dataset.file.FileFormat;
import org.apache.arrow.dataset.file.FileSystemDatasetFactory;
import org.apache.arrow.dataset.jni.NativeMemoryPool;
import org.apache.arrow.dataset.scanner.ScanOptions;
import org.apache.arrow.memory.BufferAllocator;
import org.apache.arrow.memory.RootAllocator;
import org.apache.arrow.vector.BigIntVector;
import org.apache.arrow.vector.BitVector;
import org.apache.arrow.vector.FieldVector;
import org.apache.arrow.vector.Float8Vector;
import org.apache.arrow.vector.VarCharVector;
import org.apache.arrow.vector.VectorSchemaRoot;
import org.apache.arrow.vector.complex.ListVector;
import org.apache.arrow.vector.ipc.ArrowStreamReader;
import org.apache.arrow.vector.ipc.ArrowStreamWriter;
import org.apache.arrow.vector.types.pojo.ArrowType;
import org.apache.arrow.vector.types.pojo.Field;
import org.apache.arrow.vector.types.pojo.FieldType;
import org.apache.arrow.vector.types.pojo.Schema;

/** Thin Arrow Java seam. Flix owns every scientific schema and row meaning. */
public final class AttuneParquet {
    static { System.setProperty("arrow.allocation.manager.type", "Unsafe"); }

    private static final ObjectMapper JSON = new ObjectMapper();
    private static final TypeReference<List<Row>> ROWS = new TypeReference<>() {};
    private static final TypeReference<List<Map<String, Object>>> TABLE_ROWS = new TypeReference<>() {};
    private static final String FORMAT = "attune-json-tree-v1";
    private static final Schema SCHEMA = new Schema(List.of(
            field("path", new ArrowType.List(), false,
                    List.of(field("element", new ArrowType.Utf8(), true, null))),
            field("node_type", new ArrowType.Utf8(), false, null),
            field("string_value", new ArrowType.Utf8(), true, null),
            field("integer_value", new ArrowType.Int(64, true), true, null),
            field("float_value", new ArrowType.FloatingPoint(
                    org.apache.arrow.vector.types.FloatingPointPrecision.DOUBLE), true, null),
            field("boolean_value", new ArrowType.Bool(), true, null),
            field("format_version", new ArrowType.Utf8(), false, null)),
            Map.of("attune.format", FORMAT));

    private AttuneParquet() {}

    /** Writes rows using an exact Flix-declared schema, then returns admitted rows. */
    public static String writeTable(String name, String schemaPayload, String rowsPayload) {
        try {
            TableSpec spec = JSON.readValue(schemaPayload, TableSpec.class);
            List<Map<String, Object>> rows = JSON.readValue(rowsPayload, TABLE_ROWS);
            Schema schema = tableSchema(spec);
            write(name, schema, root -> fillTable(root, spec, rows));
            return readTable(name, schemaPayload);
        } catch (Exception error) {
            throw new IllegalStateException("cannot write typed Parquet table: " + name, error);
        }
    }

    /** Reads only a table whose physical schema and identity exactly match the declaration. */
    public static String readTable(String name, String schemaPayload) {
        try (BufferAllocator allocator = new RootAllocator()) {
            TableSpec spec = JSON.readValue(schemaPayload, TableSpec.class);
            Schema expected = tableSchema(spec);
            Path path = Path.of(name).toAbsolutePath();
            try (var factory = new FileSystemDatasetFactory(allocator, NativeMemoryPool.getDefault(),
                         FileFormat.PARQUET, path.toUri().toString());
                 var dataset = factory.finish();
                 var scanner = dataset.newScan(new ScanOptions(32_768));
                 var reader = scanner.scanBatches()) {
                if (!expected.getFields().equals(scanner.schema().getFields()))
                    throw new IllegalArgumentException("typed Parquet schema does not match " + spec.format +
                            ": expected=" + expected + ", actual=" + scanner.schema());
                List<Map<String, Object>> rows = new ArrayList<>();
                while (reader.loadNextBatch()) {
                    var root = reader.getVectorSchemaRoot();
                    for (int row = 0; row < root.getRowCount(); row++) {
                        Map<String, Object> values = new LinkedHashMap<>();
                        for (ColumnSpec column : spec.columns)
                            values.put(column.name, read(root.getVector(column.name), column, row));
                        rows.add(values);
                    }
                }
                return JSON.writeValueAsString(rows);
            }
        } catch (Exception error) {
            throw new IllegalStateException("cannot read typed Parquet table: " + name, error);
        }
    }

    public static String readRows(String name) {
        try (BufferAllocator allocator = new RootAllocator()) {
            Path path = Path.of(name).toAbsolutePath();
            try (var factory = new FileSystemDatasetFactory(allocator, NativeMemoryPool.getDefault(),
                         FileFormat.PARQUET, path.toUri().toString());
                 var dataset = factory.finish();
                 var scanner = dataset.newScan(new ScanOptions(32_768));
                 var reader = scanner.scanBatches()) {
                String format = scanner.schema().getCustomMetadata().get("attune.format");
                if (format != null && !FORMAT.equals(format))
                    throw new IllegalArgumentException("unsupported Attune Parquet format");
                List<String> columns = scanner.schema().getFields().stream().map(Field::getName).toList();
                List<String> legacy = List.of("path", "node_type", "string_value", "integer_value",
                        "float_value", "boolean_value");
                List<String> current = List.of("path", "node_type", "string_value", "integer_value",
                        "float_value", "boolean_value", "format_version");
                boolean inlineFormat = columns.equals(current);
                if (!columns.equals(legacy) && !inlineFormat)
                    throw new IllegalArgumentException("unsupported Attune Parquet columns: " + columns);
                // Arrow Dataset does not expose the Parquet footer metadata written by the
                // retained PyArrow bridge.  The exact six-column schema is therefore the
                // explicit legacy-v1 read boundary.  New writes always use inlineFormat.
                List<Row> rows = new ArrayList<>();
                while (reader.loadNextBatch()) {
                    var root = reader.getVectorSchemaRoot();
                    var paths = (ListVector) root.getVector("path");
                    var types = (VarCharVector) root.getVector("node_type");
                    var strings = (VarCharVector) root.getVector("string_value");
                    var integers = (BigIntVector) root.getVector("integer_value");
                    var floats = (Float8Vector) root.getVector("float_value");
                    var booleans = (BitVector) root.getVector("boolean_value");
                    var formats = inlineFormat ? (VarCharVector) root.getVector("format_version") : null;
                    for (int i = 0; i < root.getRowCount(); i++) {
                        if (formats != null && (formats.isNull(i) || !FORMAT.equals(text(formats, i))))
                            throw new IllegalArgumentException("invalid inline Attune Parquet format identity");
                        rows.add(new Row(
                                ((List<?>) paths.getObject(i)).stream().map(Object::toString).toList(),
                                text(types, i), strings.isNull(i) ? null : text(strings, i),
                                integers.isNull(i) ? null : integers.get(i),
                                floats.isNull(i) ? null : floats.get(i),
                                booleans.isNull(i) ? null : booleans.get(i) != 0));
                    }
                }
                return JSON.writeValueAsString(rows);
            }
        } catch (Exception error) {
            throw new IllegalStateException("cannot read Parquet rows: " + name, error);
        }
    }

    public static String writeRows(String name, String payload) {
        try {
            List<Row> rows = JSON.readValue(payload, ROWS);
            write(name, SCHEMA, root -> fill(root, rows));
            return readRows(name);
        } catch (Exception error) {
            throw new IllegalStateException("cannot write Parquet rows: " + name, error);
        }
    }

    public static String canonicalizeRows(String payload) {
        Path directory = null;
        try {
            directory = Files.createTempDirectory("attune-parquet-");
            return writeRows(directory.resolve("object.parquet").toString(), payload);
        } catch (IOException error) {
            throw new IllegalStateException("cannot canonicalize Parquet rows", error);
        } finally {
            if (directory != null) remove(directory);
        }
    }

    private static void fill(VectorSchemaRoot root, List<Row> rows) {
        root.allocateNew();
        var paths = (ListVector) root.getVector("path");
        var pathWriter = paths.getWriter();
        var types = (VarCharVector) root.getVector("node_type");
        var strings = (VarCharVector) root.getVector("string_value");
        var integers = (BigIntVector) root.getVector("integer_value");
        var floats = (Float8Vector) root.getVector("float_value");
        var booleans = (BitVector) root.getVector("boolean_value");
        var formats = (VarCharVector) root.getVector("format_version");
        for (int i = 0; i < rows.size(); i++) {
            Row row = rows.get(i);
            pathWriter.setPosition(i); pathWriter.startList();
            for (String component : row.path) pathWriter.writeVarChar(component);
            pathWriter.endList();
            set(types, i, row.type); set(strings, i, row.string);
            if (row.integer == null) integers.setNull(i); else integers.setSafe(i, row.integer);
            if (row.floating == null) floats.setNull(i); else floats.setSafe(i, row.floating);
            if (row.bool == null) booleans.setNull(i); else booleans.setSafe(i, row.bool ? 1 : 0);
            set(formats, i, FORMAT);
        }
        for (var vector : root.getFieldVectors()) vector.setValueCount(rows.size());
        root.setRowCount(rows.size());
    }

    private static Schema tableSchema(TableSpec spec) {
        if (spec.format == null || spec.format.isBlank())
            throw new IllegalArgumentException("typed Parquet format identity is empty");
        if (spec.columns == null || spec.columns.isEmpty())
            throw new IllegalArgumentException("typed Parquet table has no columns");
        Set<String> names = new java.util.HashSet<>();
        List<Field> fields = new ArrayList<>();
        for (ColumnSpec column : spec.columns) {
            if (column.name == null || column.name.isBlank() || !names.add(column.name))
                throw new IllegalArgumentException("invalid or duplicate typed Parquet column");
            fields.add(switch (column.type) {
                case "string" -> field(column.name, new ArrowType.Utf8(), column.nullable, null);
                case "int64" -> field(column.name, new ArrowType.Int(64, true), column.nullable, null);
                case "float64" -> field(column.name, new ArrowType.FloatingPoint(
                        org.apache.arrow.vector.types.FloatingPointPrecision.DOUBLE), column.nullable, null);
                case "boolean" -> field(column.name, new ArrowType.Bool(), column.nullable, null);
                case "list<string>" -> field(column.name, new ArrowType.List(), column.nullable,
                        List.of(field("element", new ArrowType.Utf8(), true, null)));
                default -> throw new IllegalArgumentException("unsupported typed Parquet column: " + column.type);
            });
        }
        // Arrow Dataset preserves the physical Parquet fields but does not
        // expose footer metadata on read. Scientific protocol/version values
        // therefore remain explicit typed columns owned and checked by Flix.
        return new Schema(fields);
    }

    private static void fillTable(VectorSchemaRoot root, TableSpec spec, List<Map<String, Object>> rows) {
        root.allocateNew();
        Set<String> names = spec.columns.stream().map(ColumnSpec::name).collect(java.util.stream.Collectors.toSet());
        for (int row = 0; row < rows.size(); row++) {
            Map<String, Object> values = rows.get(row);
            if (!values.keySet().equals(names))
                throw new IllegalArgumentException("typed Parquet row columns do not match schema");
            for (ColumnSpec column : spec.columns)
                write(root.getVector(column.name), column, row, values.get(column.name));
        }
        for (var vector : root.getFieldVectors()) vector.setValueCount(rows.size());
        root.setRowCount(rows.size());
    }

    private static void write(FieldVector vector, ColumnSpec column, int row, Object value) {
        if (value == null) {
            if (!column.nullable) throw new IllegalArgumentException("null in required column: " + column.name);
            vector.setNull(row);
            return;
        }
        switch (column.type) {
            case "string" -> {
                if (!(value instanceof String text)) throw typeError(column);
                set((VarCharVector) vector, row, text);
            }
            case "int64" -> {
                if (!(value instanceof Byte || value instanceof Short || value instanceof Integer || value instanceof Long))
                    throw typeError(column);
                ((BigIntVector) vector).setSafe(row, ((Number) value).longValue());
            }
            case "float64" -> {
                if (!(value instanceof Number number)) throw typeError(column);
                ((Float8Vector) vector).setSafe(row, number.doubleValue());
            }
            case "boolean" -> {
                if (!(value instanceof Boolean bool)) throw typeError(column);
                ((BitVector) vector).setSafe(row, bool ? 1 : 0);
            }
            case "list<string>" -> {
                if (!(value instanceof List<?> values)) throw typeError(column);
                var writer = ((ListVector) vector).getWriter();
                writer.setPosition(row); writer.startList();
                for (Object item : values) {
                    if (!(item instanceof String text)) throw typeError(column);
                    writer.writeVarChar(text);
                }
                writer.endList();
            }
            default -> throw typeError(column);
        }
    }

    private static Object read(FieldVector vector, ColumnSpec column, int row) {
        if (vector.isNull(row)) {
            if (!column.nullable) throw new IllegalArgumentException("null in required column: " + column.name);
            return null;
        }
        return switch (column.type) {
            case "string" -> text((VarCharVector) vector, row);
            case "int64" -> ((BigIntVector) vector).get(row);
            case "float64" -> ((Float8Vector) vector).get(row);
            case "boolean" -> ((BitVector) vector).get(row) != 0;
            case "list<string>" -> ((List<?>) ((ListVector) vector).getObject(row)).stream()
                    .map(Object::toString).toList();
            default -> throw typeError(column);
        };
    }

    private static IllegalArgumentException typeError(ColumnSpec column) {
        return new IllegalArgumentException("invalid value for " + column.name + ": " + column.type);
    }

    private static void write(String name, Schema schema, Consumer<VectorSchemaRoot> fill) throws IOException {
        Path target = Path.of(name).toAbsolutePath();
        Files.createDirectories(target.getParent());
        Path directory = Files.createTempDirectory(target.getParent(), ".parquet-");
        try (BufferAllocator allocator = new RootAllocator();
             VectorSchemaRoot root = VectorSchemaRoot.create(schema, allocator)) {
            fill.accept(root);
            var bytes = new ByteArrayOutputStream();
            try (var writer = new ArrowStreamWriter(root, null, Channels.newChannel(bytes))) {
                writer.start(); writer.writeBatch(); writer.end();
            }
            try (var reader = new ArrowStreamReader(new ByteArrayInputStream(bytes.toByteArray()), allocator)) {
                DatasetFileWriter.write(allocator, reader, FileFormat.PARQUET,
                        directory.toUri().toString(), new String[0], 1, "part-{i}.parquet");
                reader.getVectorSchemaRoot().clear();
            }
            root.clear();
            awaitNativeRelease(allocator);
            try (var files = Files.walk(directory)) {
                List<Path> output = files.filter(Files::isRegularFile)
                        .filter(path -> path.toString().endsWith(".parquet")).toList();
                if (output.size() != 1) throw new IOException("Arrow writer did not produce one file");
                Files.move(output.getFirst(), target, StandardCopyOption.ATOMIC_MOVE,
                        StandardCopyOption.REPLACE_EXISTING);
            }
        } finally {
            remove(directory);
        }
    }

    private static Field field(String name, ArrowType type, boolean nullable, List<Field> children) {
        return new Field(name, new FieldType(nullable, type, null), children);
    }

    private static String text(VarCharVector vector, int i) {
        return new String(vector.get(i), StandardCharsets.UTF_8);
    }

    private static void set(VarCharVector vector, int i, String value) {
        if (value == null) vector.setNull(i); else vector.setSafe(i, value.getBytes(StandardCharsets.UTF_8));
    }

    private static void awaitNativeRelease(BufferAllocator allocator) {
        long deadline = System.nanoTime() + 5_000_000_000L;
        while (allocator.getAllocatedMemory() != 0 && System.nanoTime() < deadline) Thread.yield();
    }

    private static void remove(Path directory) {
        try (var paths = Files.walk(directory)) {
            paths.sorted(Comparator.reverseOrder()).forEach(path -> {
                try { Files.deleteIfExists(path); } catch (IOException error) { throw new UncheckedIOException(error); }
            });
        } catch (IOException error) { throw new UncheckedIOException(error); }
    }

    private record Row(List<String> path, String type, String string,
                       Long integer, Double floating, Boolean bool) {}
    private record ColumnSpec(String name, String type, boolean nullable) {}
    private record TableSpec(String format, List<ColumnSpec> columns) {}
}
