package attune.grit;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

/** The only JVM surface visible to Flix. */
public final class AttuneGrit {
    private AttuneGrit() {}

    /** Runs one fixed Grit program and returns its stable UTF-8 JSON envelope. */
    public static String evaluate(String language, String program, String path, String source) {
        return AttuneGritNative.evaluate(language, program, path, source);
    }

    /** Returns one Nix-packaged, admitted Attune Grit program. */
    public static String program(String name) {
        String resource = switch (name) {
            case "defines", "imports", "calls" -> "/attune/grit/programs/" + name + ".grit";
            default -> throw new IllegalArgumentException("unknown Attune Grit program: " + name);
        };
        try (InputStream stream = AttuneGrit.class.getResourceAsStream(resource)) {
            if (stream == null) throw new IllegalStateException("missing Attune Grit resource: " + resource);
            return new String(stream.readAllBytes(), StandardCharsets.UTF_8);
        } catch (IOException error) {
            throw new IllegalStateException("cannot read Attune Grit resource: " + resource, error);
        }
    }
}
