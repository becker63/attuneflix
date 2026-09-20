package attune.grit;

import java.nio.file.Files;
import java.nio.file.Path;

/** Dependency-free executable lifetime and semantic checks for the Java facade. */
public final class AttuneGritTest {
    private AttuneGritTest() {}

    private static void require(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }

    public static void main(String[] args) throws Exception {
        String calls = Files.readString(Path.of("native/grit/calls.grit"));
        String nested = "Boolean(verify(name));";
        String first = AttuneGrit.evaluate("typescript", calls, "src/example.ts", nested);
        require(first.contains("\"matched\":true"), first);
        require(first.split("\"path\":", -1).length - 1 == 2, first);
        require(first.split("\"message\":\"call\\\\n\"", -1).length - 1 == 2, first);

        for (int index = 0; index < 100; index++) {
            require(first.equals(AttuneGrit.evaluate("typescript", calls, "src/example.ts", nested)),
                    "repeated native result changed");
        }

        String unicode = AttuneGrit.evaluate(
                "typescript", calls, "unicode.ts", "const π = 'é';\nverify(name);");
        require(unicode.contains("\"start_byte\":17"), unicode);

        String empty = AttuneGrit.evaluate("typescript", calls, "empty.ts", "");
        require(empty.contains("\"matched\":false"), empty);

        String invalid = AttuneGrit.evaluate(
                "typescript",
                "engine marzano(0.1)\nlanguage js(typescript)\nnot_a_node()",
                "invalid.ts",
                "");
        require(invalid.contains("\"kind\":\"compile\""), invalid);

        String large = "// padding\n".repeat(100_000) + "verify(name);\n";
        String largeResult = AttuneGrit.evaluate("typescript", calls, "large.ts", large);
        require(largeResult.contains("\"version\":1"), "large source returned no envelope");

        System.out.println(first);
    }
}
