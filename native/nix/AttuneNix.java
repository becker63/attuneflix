package attune.nix;

import static attune.nix.ffi.AttuneNixAbi.*;

import attune.nix.ffi.nix_get_string_callback;
import java.io.ByteArrayOutputStream;
import java.lang.foreign.Arena;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.ValueLayout;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/** Ordinary JVM values over the generated Nix C API bindings. */
public final class AttuneNix {
    private AttuneNix() {}

    private static final class Holder {
        private static final Runtime RUNTIME = Runtime.open();
        static {
            java.lang.Runtime.getRuntime().addShutdownHook(new Thread(RUNTIME::close, "attune-nix-close"));
        }
    }

    /** Evaluates one explicit Nix expression and returns a stable JSON envelope. */
    public static String realise(String expression, String origin) {
        try {
            return success(Holder.RUNTIME.realise(expression, origin));
        } catch (RuntimeException error) {
            return failure(error.getMessage() == null ? error.getClass().getName() : error.getMessage());
        }
    }

    /** Reads one Nix-selected store file without routing its bytes through a Nix string. */
    public static String readUtf8(String file) {
        try {
            Path path = Path.of(file).normalize();
            if (!path.isAbsolute() || !path.startsWith("/nix/store/")) {
                return failure("source is not an absolute Nix store path: " + file);
            }
            return success(new Realised(
                    new String(Files.readAllBytes(path), StandardCharsets.UTF_8), List.of()));
        } catch (Exception error) {
            return failure(error.getMessage() == null ? error.getClass().getName() : error.getMessage());
        }
    }

    private record Realised(String text, List<String> paths) {}

    private static final class Runtime implements AutoCloseable {
        private MemorySegment context = MemorySegment.NULL;
        private MemorySegment store = MemorySegment.NULL;
        private MemorySegment settings = MemorySegment.NULL;
        private MemorySegment state = MemorySegment.NULL;
        private boolean closed;

        private Runtime() {}

        static Runtime open() {
            Runtime runtime = new Runtime();
            try (Arena arena = Arena.ofConfined()) {
                runtime.context = require(
                        nix_c_context_create.makeInvoker().apply(), "nix_c_context_create", MemorySegment.NULL);
                runtime.check(nix_libutil_init(runtime.context), "nix_libutil_init");
                runtime.check(nix_libstore_init(runtime.context), "nix_libstore_init");
                runtime.check(nix_libexpr_init(runtime.context), "nix_libexpr_init");
                runtime.store = require(
                        nix_store_open(runtime.context, cstring(arena, "daemon"), MemorySegment.NULL),
                        "nix_store_open", runtime.context);
                runtime.settings = require(
                        nix_flake_settings_new(runtime.context), "nix_flake_settings_new", runtime.context);
                MemorySegment builder = require(
                        nix_eval_state_builder_new(runtime.context, runtime.store),
                        "nix_eval_state_builder_new", runtime.context);
                try {
                    runtime.check(
                            nix_flake_settings_add_to_eval_state_builder(runtime.context, runtime.settings, builder),
                            "nix_flake_settings_add_to_eval_state_builder");
                    runtime.state = require(
                            nix_eval_state_build(runtime.context, builder),
                            "nix_eval_state_build", runtime.context);
                } finally {
                    nix_eval_state_builder_free(builder);
                }
                return runtime;
            } catch (RuntimeException error) {
                runtime.close();
                throw error;
            }
        }

        synchronized Realised realise(String expression, String origin) {
            if (closed) throw new IllegalStateException("Nix runtime is closed");
            try (Arena arena = Arena.ofConfined()) {
                MemorySegment value = require(
                        nix_alloc_value(context, state), "nix_alloc_value", context);
                try {
                    check(nix_expr_eval_from_string(
                            context, state, cstring(arena, expression), cstring(arena, origin), value),
                            "nix_expr_eval_from_string");
                    check(nix_value_force(context, state, value), "nix_value_force");
                    if (nix_get_type(context, value) != NIX_TYPE_STRING()) {
                        throw new IllegalStateException("Nix expression did not evaluate to a string");
                    }
                    MemorySegment realised = require(
                            nix_string_realise(context, state, value, false),
                            "nix_string_realise", context);
                    try {
                        long size = nix_realised_string_get_buffer_size(realised);
                        if (size < 0 || size > Integer.MAX_VALUE) {
                            throw new IllegalStateException("Nix string is too large: " + size);
                        }
                        MemorySegment start = nix_realised_string_get_buffer_start(realised);
                        String text = utf8(start, size);
                        long count = nix_realised_string_get_store_path_count(realised);
                        if (count < 0 || count > Integer.MAX_VALUE) {
                            throw new IllegalStateException("Nix store context is too large: " + count);
                        }
                        List<String> paths = new ArrayList<>((int) count);
                        for (long index = 0; index < count; index++) {
                            MemorySegment path = require(
                                    nix_realised_string_get_store_path(realised, index),
                                    "nix_realised_string_get_store_path", context);
                            paths.add(realPath(path));
                        }
                        Collections.sort(paths);
                        return new Realised(text, List.copyOf(paths));
                    } finally {
                        nix_realised_string_free(realised);
                    }
                } finally {
                    check(nix_value_decref(context, value), "nix_value_decref");
                }
            }
        }

        private String realPath(MemorySegment path) {
            try (Arena arena = Arena.ofConfined()) {
                ByteArrayOutputStream bytes = new ByteArrayOutputStream();
                MemorySegment callback = callback(arena, bytes);
                check(nix_store_real_path(context, store, path, callback, MemorySegment.NULL),
                        "nix_store_real_path");
                return bytes.toString(StandardCharsets.UTF_8);
            }
        }

        private void check(int status, String operation) {
            if (status != 0) throw new IllegalStateException(operation + " failed: " + error(context));
        }

        @Override
        public synchronized void close() {
            if (closed) return;
            closed = true;
            if (!nullPointer(state)) nix_state_free(state);
            if (!nullPointer(settings)) nix_flake_settings_free(settings);
            if (!nullPointer(store)) nix_store_free(store);
            if (!nullPointer(context)) nix_c_context_free(context);
            state = settings = store = context = MemorySegment.NULL;
        }
    }

    private static MemorySegment callback(Arena arena, ByteArrayOutputStream bytes) {
        return nix_get_string_callback.allocate((start, length, _userData) -> {
            long size = Integer.toUnsignedLong(length);
            bytes.writeBytes(start.reinterpret(size).toArray(ValueLayout.JAVA_BYTE));
        }, arena);
    }

    private static String error(MemorySegment readContext) {
        MemorySegment scratch = nix_c_context_create.makeInvoker().apply();
        if (nullPointer(scratch)) return "Nix error details unavailable";
        try (Arena arena = Arena.ofConfined()) {
            ByteArrayOutputStream bytes = new ByteArrayOutputStream();
            int status = nix_err_info_msg(scratch, readContext, callback(arena, bytes), MemorySegment.NULL);
            return status == 0 ? bytes.toString(StandardCharsets.UTF_8)
                    : "Nix error details failed with code " + status;
        } finally {
            nix_c_context_free(scratch);
        }
    }

    private static MemorySegment require(MemorySegment value, String operation, MemorySegment context) {
        if (!nullPointer(value)) return value;
        String detail = nullPointer(context) ? "no context" : error(context);
        throw new IllegalStateException(operation + " failed: " + detail);
    }

    private static boolean nullPointer(MemorySegment value) {
        return value == null || value.address() == 0;
    }

    private static MemorySegment cstring(Arena arena, String value) {
        if (value.indexOf('\0') >= 0) throw new IllegalArgumentException("Nix input contains NUL");
        byte[] encoded = (value + "\0").getBytes(StandardCharsets.UTF_8);
        MemorySegment result = arena.allocate(encoded.length, 1);
        result.copyFrom(MemorySegment.ofArray(encoded));
        return result;
    }

    private static String utf8(MemorySegment start, long size) {
        if (size == 0) return "";
        if (nullPointer(start)) throw new IllegalStateException("Nix returned a null string buffer");
        return new String(start.reinterpret(size).toArray(ValueLayout.JAVA_BYTE), StandardCharsets.UTF_8);
    }

    private static String success(Realised realised) {
        StringBuilder result = new StringBuilder("{\"version\":1,\"text\":");
        quoted(result, realised.text());
        result.append(",\"store_paths\":[");
        for (int index = 0; index < realised.paths().size(); index++) {
            if (index > 0) result.append(',');
            quoted(result, realised.paths().get(index));
        }
        return result.append("]}").toString();
    }

    private static String failure(String message) {
        StringBuilder result = new StringBuilder("{\"version\":1,\"error\":{\"kind\":\"nix\",\"message\":");
        quoted(result, message);
        return result.append("}}").toString();
    }

    private static void quoted(StringBuilder result, String value) {
        result.append('"');
        for (int index = 0; index < value.length(); index++) {
            char character = value.charAt(index);
            switch (character) {
                case '"' -> result.append("\\\"");
                case '\\' -> result.append("\\\\");
                case '\b' -> result.append("\\b");
                case '\f' -> result.append("\\f");
                case '\n' -> result.append("\\n");
                case '\r' -> result.append("\\r");
                case '\t' -> result.append("\\t");
                default -> {
                    if (character < 0x20) result.append(String.format("\\u%04x", (int) character));
                    else result.append(character);
                }
            }
        }
        result.append('"');
    }
}
