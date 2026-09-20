package attune.grit;

/** The only JVM surface visible to Flix. */
public final class AttuneGrit {
    private AttuneGrit() {}

    /** Runs one fixed Grit program and returns its stable UTF-8 JSON envelope. */
    public static String evaluate(String language, String program, String path, String source) {
        return AttuneGritNative.evaluate(language, program, path, source);
    }
}
