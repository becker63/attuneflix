package attune.nix;

/** Dependency-free smoke and failure checks for the Nix FFM façade. */
public final class AttuneNixTest {
    private AttuneNixTest() {}

    private static void require(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }

    public static void main(String[] args) {
        String origin = System.getProperty("user.dir");
        String plain = AttuneNix.realise("\"hello\"", origin);
        require(plain.equals("{\"version\":1,\"text\":\"hello\",\"store_paths\":[]}"), plain);

        String owned = AttuneNix.realise(
                "builtins.toString (builtins.toFile \"attune-nix-smoke\" \"hello\")", origin);
        require(owned.contains("\"store_paths\":[\"/nix/store/"), owned);
        require(owned.contains("-attune-nix-smoke"), owned);

        String wrongType = AttuneNix.realise("42", origin);
        require(wrongType.contains("\"kind\":\"nix\""), wrongType);
        require(wrongType.contains("did not evaluate to a string"), wrongType);

        String repeated = AttuneNix.realise("\"hello\"", origin);
        require(repeated.equals(plain), repeated);

        String rejected = AttuneNix.readUtf8("/tmp/not-nix-owned");
        require(rejected.contains("\"kind\":\"nix\""), rejected);
        require(rejected.contains("not an absolute Nix store path"), rejected);
        System.out.println(owned);
    }
}
