package attune.grit;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Dependency-free executable lifetime and semantic checks for the Java facade. */
public final class AttuneGritTest {
    private AttuneGritTest() {}

    private static void require(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }

    private static List<String> bindings(String wire, String message, String source) {
        Pattern log = Pattern.compile(
                "\\\"message\\\":\\\"" + Pattern.quote(message)
                        + "\\\\n\\\",\\\"start_byte\\\":([0-9]+),\\\"end_byte\\\":([0-9]+)");
        Matcher matches = log.matcher(wire);
        byte[] bytes = source.getBytes(StandardCharsets.UTF_8);
        List<String> values = new ArrayList<>();
        while (matches.find()) {
            int start = Integer.parseInt(matches.group(1));
            int end = Integer.parseInt(matches.group(2));
            require(0 <= start && start <= end && end <= bytes.length, "invalid byte range: " + wire);
            values.add(new String(bytes, start, end - start, StandardCharsets.UTF_8));
        }
        return values;
    }

    /**
     * The lowest-level proof that one admitted language is inside the native Grit
     * engine: the Java facade (the Attune boundary) selects the language, the
     * engine compiles the pattern against that language, parses the source, and
     * returns exactly the range of the matched call.
     */
    private static void requireSeam(
            String language, String declaration, String path, String source, String call) {
        String program = "engine marzano(0.1)\nlanguage " + declaration + "\n\n"
                + "`$callee($...)` where { log(message=\"call\", variable=$callee) }\n";
        String wire = AttuneGrit.evaluate(language, program, path, source);
        require(wire.contains("\"matched\":true"), language + " did not match: " + wire);
        int start = source.indexOf(call);
        require(start >= 0, language + ": fixture does not contain " + call);
        require(wire.contains("\"path\":\"" + path + "\""
                        + ",\"start_byte\":" + start
                        + ",\"end_byte\":" + (start + call.length()) + "}"),
                language + " returned the wrong range: " + wire);
        require(wire.contains("\"message\":\"call\\n\""), language + " logged nothing: " + wire);
    }

    public static void main(String[] args) throws Exception {
        String calls = AttuneGrit.program("typescript", "calls");
        String defines = AttuneGrit.program("typescript", "defines");
        String imports = AttuneGrit.program("typescript", "imports");
        for (String relation : List.of("calls", "defines", "imports")) {
            for (String dialect : List.of("javascript", "jsx", "typescript", "tsx")) {
                String packaged = AttuneGrit.program(dialect, relation);
                Path visible = Path.of("src", "grit", relation, dialect + ".grit");
                require(packaged.equals(Files.readString(visible)),
                        "packaged entry point differs: " + visible);
            }
        }
        String nested = "Boolean(verify(name));";

        if (args.length == 1 && args[0].equals("--fresh-child")) {
            System.out.print(AttuneGrit.evaluate("typescript", calls, "src/example.ts", nested));
            return;
        }

        String first = AttuneGrit.evaluate("typescript", calls, "src/example.ts", nested);
        String expected = "{\"version\":1,\"matched\":true,\"matches\":["
                + "{\"path\":\"src/example.ts\",\"start_byte\":0,\"end_byte\":21},"
                + "{\"path\":\"src/example.ts\",\"start_byte\":8,\"end_byte\":20}],"
                + "\"logs\":[{\"message\":\"call\\n\",\"start_byte\":0,\"end_byte\":7},"
                + "{\"message\":\"call\\n\",\"start_byte\":8,\"end_byte\":14}],"
                + "\"diagnostics\":[]}";
        require(first.equals(expected), first);

        String fixture = "import { verify } from \"./verify\";\n\n"
                + "export function greet(name: string): string {\n"
                + "  verify(name);\n"
                + "  return name;\n"
                + "}\n";
        String definitionExpected = "{\"version\":1,\"matched\":true,\"matches\":["
                + "{\"path\":\"src/example.ts\",\"start_byte\":43,\"end_byte\":114}],"
                + "\"logs\":[{\"message\":\"definition\\n\",\"start_byte\":52,\"end_byte\":57}],"
                + "\"diagnostics\":[]}";
        String definitionActual = AttuneGrit.evaluate("typescript", defines, "src/example.ts", fixture);
        require(definitionActual.equals(definitionExpected), definitionActual);

        String importExpected = "{\"version\":1,\"matched\":true,\"matches\":["
                + "{\"path\":\"src/example.ts\",\"start_byte\":0,\"end_byte\":34}],"
                + "\"logs\":[{\"message\":\"import\\n\",\"start_byte\":23,\"end_byte\":33}],"
                + "\"diagnostics\":[]}";
        String importActual = AttuneGrit.evaluate("typescript", imports, "src/example.ts", fixture);
        require(importActual.equals(importExpected), importActual);

        String callExpected = "{\"version\":1,\"matched\":true,\"matches\":["
                + "{\"path\":\"src/example.ts\",\"start_byte\":84,\"end_byte\":96}],"
                + "\"logs\":[{\"message\":\"call\\n\",\"start_byte\":84,\"end_byte\":90}],"
                + "\"diagnostics\":[]}";
        String callActual = AttuneGrit.evaluate("typescript", calls, "src/example.ts", fixture);
        require(callActual.equals(callExpected), callActual);

        String definitionsSurface = """

export function plain(value: string): string { return value; }

export function generic<T>(value: T): T { return value; }

export class Client {
  constructor(private readonly name: string) {}

  method(value: string): string { return value; }

  static create(): Client {
return new Client("example");
  }

  genericMethod<T>(value: T): T { return value; }

  field = (value: string): string => value;
}

export const tools = {
  objectMethod(value: string): string { return value; },
  objectArrow: (value: string): string => value,
};

export const arrow = (value: string): string => value;

export const expression = function (value: string): string {
  return value;
};

export const namedExpression = function implementation(
  value: string,
): string {
  return value;
};

export function overload(value: string): string;
export function overload(value: number): number;
export function overload(
  value: string | number,
): string | number {
  return value;
}

const ordinary = createVerifier();
""";
        List<String> definitionBindings = bindings(
                AttuneGrit.evaluate("typescript", defines, "surface.ts", definitionsSurface),
                "definition",
                definitionsSurface);
        require(definitionBindings.equals(List.of(
                        "plain", "generic", "method", "create", "genericMethod", "field",
                        "objectMethod", "objectArrow", "arrow", "expression", "namedExpression", "overload")),
                "definition surface changed: " + definitionBindings);

        String importsSurface = """

import { verify } from "./verify";
import Client from "./client";
import * as auth from "./auth";
import type { User } from "./types";
import "./setup";

export { helper } from "./helper";

async function load(): Promise<unknown> {
  return import("./lazy");
}
""";
        List<String> importBindings = bindings(
                AttuneGrit.evaluate("typescript", imports, "surface.ts", importsSurface),
                "import",
                importsSurface);
        require(importBindings.equals(List.of(
                        "\"./verify\"", "\"./client\"", "\"./auth\"", "\"./types\"", "\"./setup\"")),
                "import surface changed: " + importBindings);

        String callsSurface = """

async function run(client: Client): Promise<void> {
  verify();
  client.verify();
  client?.optional();
  generic<string>();
  await awaited();
  await import("./lazy");
  const created = new Client();
  void created;
}
""";
        List<String> callBindings = bindings(
                AttuneGrit.evaluate("typescript", calls, "surface.ts", callsSurface),
                "call",
                callsSurface);
        require(callBindings.equals(List.of("verify", "client.verify", "client?.optional", "generic", "awaited")),
                "call surface changed: " + callBindings);

        // The three polyglot frontends are real packaged entry points (byte
        // identical to the repository-visible files) and produce their expected
        // semantics through the same native engine as JS/TS.
        for (String relation : List.of("defines", "imports", "calls")) {
            for (String language : List.of("java", "flix", "starlark")) {
                String packaged = AttuneGrit.program(language, relation);
                Path visible = Path.of("src", "grit", relation, language + ".grit");
                require(packaged.equals(Files.readString(visible)),
                        "packaged entry point differs: " + visible);
            }
        }

        String javaFixture = "package a;\n\nimport a.Other;\n\npublic class Client {\n"
                + "    public void helper(String name) {}\n"
                + "    public void verify(String name) { helper(name); }\n}\n";
        require(bindings(AttuneGrit.evaluate("java", AttuneGrit.program("java", "defines"),
                        "src/a/Client.java", javaFixture), "definition", javaFixture)
                .equals(List.of("Client", "helper", "verify")), "java defines changed");
        require(bindings(AttuneGrit.evaluate("java", AttuneGrit.program("java", "imports"),
                        "src/a/Client.java", javaFixture), "import", javaFixture)
                .equals(List.of("a.Other")), "java imports changed");
        require(bindings(AttuneGrit.evaluate("java", AttuneGrit.program("java", "calls"),
                        "src/a/Client.java", javaFixture), "call", javaFixture)
                .equals(List.of("helper")), "java calls changed");

        String flixFixture = "mod Demo {\n    use Repository.Structure.FileId\n\n"
                + "    pub def helper(x: Int32): Int32 = x\n"
                + "    pub def run(): Int32 = helper(0)\n}\n";
        require(bindings(AttuneGrit.evaluate("flix", AttuneGrit.program("flix", "defines"),
                        "src/Demo.flix", flixFixture), "definition", flixFixture)
                .equals(List.of("Demo", "helper", "run")), "flix defines changed");
        require(bindings(AttuneGrit.evaluate("flix", AttuneGrit.program("flix", "imports"),
                        "src/Demo.flix", flixFixture), "import", flixFixture)
                .equals(List.of("use Repository.Structure.FileId")), "flix imports changed");
        require(bindings(AttuneGrit.evaluate("flix", AttuneGrit.program("flix", "calls"),
                        "src/Demo.flix", flixFixture), "call", flixFixture)
                .equals(List.of("helper")), "flix calls changed");

        String starlarkFixture = "load(\"//tools:defs.bzl\", \"helper\")\n\n"
                + "def helper(name):\n    pass\n\n"
                + "def run():\n    helper(\"sample\")\n";
        require(bindings(AttuneGrit.evaluate("starlark", AttuneGrit.program("starlark", "defines"),
                        "src/pkg/BUILD", starlarkFixture), "definition", starlarkFixture)
                .equals(List.of("helper", "run")), "starlark defines changed");
        require(bindings(AttuneGrit.evaluate("starlark", AttuneGrit.program("starlark", "imports"),
                        "src/pkg/BUILD", starlarkFixture), "import", starlarkFixture)
                .equals(List.of("\"//tools:defs.bzl\"")), "starlark imports changed");
        require(bindings(AttuneGrit.evaluate("starlark", AttuneGrit.program("starlark", "calls"),
                        "src/pkg/BUILD", starlarkFixture), "call", starlarkFixture)
                .equals(List.of("helper")), "starlark calls changed");

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

        String unsupported = AttuneGrit.evaluate("made-up", calls, "invalid.ts", "");
        require(unsupported.contains("\"kind\":\"unsupported-language\""), unsupported);

        // All five admitted languages run inside the same native engine. The
        // Flix and Starlark seams select the language through this facade, the
        // engine compiles the pattern with that language, parses the source, and
        // returns the expected match and range.
        requireSeam("javascript", "js", "src/helper.js", "helper(1);\n", "helper(1)");
        requireSeam("typescript", "js(typescript)", "src/helper.ts", "helper(1);\n", "helper(1)");
        requireSeam(
                "java",
                "java",
                "src/Helper.java",
                "class Helper {\n    void run() {\n        helper(1);\n    }\n}\n",
                "helper(1)");
        requireSeam("flix", "flix", "src/Main.flix", "def main(): Int32 = helper(1)\n", "helper(1)");
        requireSeam(
                "starlark",
                "starlark",
                "src/build.bzl",
                "def _impl(ctx):\n    return helper(1)\n",
                "helper(1)");

        String embeddedNul = AttuneGrit.evaluate(
                "typescript", calls, "nul.ts", "const value = 'a\u0000b';\nverify(name);");
        require(embeddedNul.contains("\"version\":1"), embeddedNul);

        String large = "// padding\n".repeat(100_000) + "verify(name);\n";
        String largeResult = AttuneGrit.evaluate("typescript", calls, "large.ts", large);
        require(largeResult.contains("\"version\":1"), "large source returned no envelope");

        String java = Path.of(System.getProperty("java.home"), "bin", "java").toString();
        Process child = new ProcessBuilder(
                java,
                "--enable-native-access=ALL-UNNAMED",
                "-Djava.library.path=" + System.getProperty("java.library.path"),
                "-cp", System.getProperty("java.class.path"),
                AttuneGritTest.class.getName(),
                "--fresh-child")
                .start();
        String fresh = new String(child.getInputStream().readAllBytes(), StandardCharsets.UTF_8);
        String freshError = new String(child.getErrorStream().readAllBytes(), StandardCharsets.UTF_8);
        int freshStatus = child.waitFor();
        require(freshStatus == 0, "fresh JVM failed: " + freshError);
        require(first.equals(fresh), "cold-cache fresh JVM changed semantics");

        System.out.println(first);
    }
}
