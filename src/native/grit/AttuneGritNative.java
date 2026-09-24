package attune.grit;

import static attune.grit.ffi.AttuneGritAbi.attune_grit_buffer_free;
import static attune.grit.ffi.AttuneGritAbi.attune_grit_run;

import java.lang.foreign.Arena;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.ValueLayout;
import java.nio.charset.StandardCharsets;

/** Package-private ownership adapter over generated FFM bindings. */
final class AttuneGritNative {
    private static final int ABI_OK = 0;
    private static final int ABI_HOST_ERROR = 1;

    private record Input(MemorySegment data, long length) {}

    private AttuneGritNative() {}

    private static Input input(Arena arena, String value) {
        byte[] bytes = value.getBytes(StandardCharsets.UTF_8);
        MemorySegment data = arena.allocate(Math.max(1, bytes.length), 1);
        data.asSlice(0, bytes.length).copyFrom(MemorySegment.ofArray(bytes));
        return new Input(data, bytes.length);
    }

    static String evaluate(String language, String program, String path, String source) {
        try (Arena arena = Arena.ofConfined()) {
            Input lang = input(arena, language);
            Input grit = input(arena, program);
            Input name = input(arena, path);
            Input text = input(arena, source);
            MemorySegment outData = arena.allocate(ValueLayout.ADDRESS);
            MemorySegment outLength = arena.allocate(ValueLayout.JAVA_LONG);

            int status = attune_grit_run(
                    lang.data(), lang.length(),
                    grit.data(), grit.length(),
                    name.data(), name.length(),
                    text.data(), text.length(),
                    outData, outLength);

            MemorySegment data = outData.get(ValueLayout.ADDRESS, 0);
            long length = outLength.get(ValueLayout.JAVA_LONG, 0);
            byte[] owned;
            try {
                if (length < 0 || (data.address() == 0 && length != 0)) {
                    throw new IllegalStateException("invalid Attune Grit output buffer");
                }
                owned = data.reinterpret(length).toArray(ValueLayout.JAVA_BYTE);
            } finally {
                if (data.address() != 0) attune_grit_buffer_free(data, length);
            }

            // Rust classifies normal compile/language failures in the envelope.
            // ABI_HOST_ERROR likewise carries a stable host-error envelope.
            if (status != ABI_OK && status != ABI_HOST_ERROR) {
                throw new IllegalStateException("unknown Attune Grit ABI status: " + status);
            }
            if (status == ABI_HOST_ERROR && owned.length == 0) {
                throw new IllegalStateException("Attune Grit host failure returned no envelope");
            }

            // Decode only after Rust-owned memory has been released. Any Java
            // exception from here onward therefore cannot leak a native buffer.
            return new String(owned, StandardCharsets.UTF_8);
        }
    }
}
