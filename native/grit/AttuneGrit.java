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

    /** Returns one Nix-packaged, admitted Attune Grit dialect entry point. */
    public static String program(String language, String name) {
        // Flix owns both closed enums and therefore the admitted cross-product.
        // This Java leaf only loads the corresponding immutable JAR resource.
        String resource = "/attune/grit/programs/" + name + "/" + language + ".grit";
        try (InputStream stream = AttuneGrit.class.getResourceAsStream(resource)) {
            if (stream == null) throw new IllegalStateException("missing Attune Grit resource: " + resource);
            return new String(stream.readAllBytes(), StandardCharsets.UTF_8);
        } catch (IOException error) {
            throw new IllegalStateException("cannot read Attune Grit resource: " + resource, error);
        }
    }
}
