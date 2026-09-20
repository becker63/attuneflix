package attune.grit;

import static attune.grit.ffi.AttuneGritAbi.attune_grit_buffer_free;
import static attune.grit.ffi.AttuneGritAbi.attune_grit_run;

import java.lang.foreign.Arena;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.ValueLayout;
import java.nio.charset.StandardCharsets;

/** Package-private ownership adapter over generated FFM bindings. */
final class AttuneGritNative {
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

            attune_grit_run(
                    lang.data(), lang.length(),
                    grit.data(), grit.length(),
                    name.data(), name.length(),
                    text.data(), text.length(),
                    outData, outLength);

            MemorySegment data = outData.get(ValueLayout.ADDRESS, 0);
            long length = outLength.get(ValueLayout.JAVA_LONG, 0);
            try {
                byte[] owned = data.reinterpret(length).toArray(ValueLayout.JAVA_BYTE);
                return new String(owned, StandardCharsets.UTF_8);
            } finally {
                attune_grit_buffer_free(data, length);
            }
        }
    }
}
