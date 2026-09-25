use Repository.Grit.{Fact, Language, Program, Wire}

/// Focused polyglot acquisition fixtures: tiny Java/Flix/Starlark sources whose
/// frontend envelopes (captured from the real native Grit engine and re-verified
/// live by //src/native/grit:attune_grit_test) flow through the ONE fact
/// protocol, ordinary Repository admission, and explicit per-language
/// resolution into one canonical Repository.World.

def span(path: String, range: (Int32, Int32)): String =
    let (start, end) = range;
    "{\"path\":\"${path}\",\"start_byte\":${start},\"end_byte\":${end}}"

def log(message: String, range: (Int32, Int32)): String =
    let (start, end) = range;
    "{\"message\":\"${message}\",\"start_byte\":${start},\"end_byte\":${end}}"

/// Rebuild the exact native envelope shape from byte ranges.
def envelope(path: String, matches: List[(Int32, Int32)], logs: List[(String, (Int32, Int32))]): Wire =
    Wire.Wire(
        "{\"version\":1,\"matched\":true,\"matches\":["
        + String.flatten(List.intersperse(",", List.map(range -> span(path, range), matches)))
        + "],\"logs\":["
        + String.flatten(List.intersperse(",", List.map(entry -> {
            let (message, range) = entry;
            log(message, range)
        }, logs)))
        + "],\"diagnostics\":[]}")

def facts(path: String, source: String, wire: Wire): Vector[Fact] \ Assert =
    match Repository.Grit.facts(path, source, wire) {
        case Ok(facts)   => facts
        case Err(error)  => { Assert.fail(ToString.toString(error)); Vector.empty() }
    }

def fileId(index: Int32): Repository.Structure.FileId = Repository.Structure.FileId.FileId(index)
def symbolId(index: Int32): Repository.Structure.SymbolId = Repository.Structure.SymbolId.SymbolId(index)

@Test
def languageDetectionRoutesEveryAdmittedFileKind(): Unit \ Assert = {
    let cases = Vector#{
        ("src/helper.js", Some(Language.JavaScript)),
        ("src/helper.mjs", Some(Language.JavaScript)),
        ("src/view.jsx", Some(Language.Jsx)),
        ("src/helper.ts", Some(Language.TypeScript)),
        ("src/view.tsx", Some(Language.Tsx)),
        ("src/native/grit/AttuneGrit.java", Some(Language.Java)),
        ("src/Repository.flix", Some(Language.Flix)),
        ("src/pkg/defs.bzl", Some(Language.Starlark)),
        ("src/pkg/BUILD", Some(Language.Starlark)),
        ("src/pkg/BUILD.bazel", Some(Language.Starlark)),
        ("WORKSPACE", Some(Language.Starlark)),
        ("README.md", None)
    };
    Vector.forEach(match (path, expected) ->
        Assert.assertEq(expected = expected, Repository.language(path)), cases)
}

@Test
def javaSourceAdmitsTheExpectedFacts(): Unit \ Assert = {
    let path = "src/a/Client.java";
    let source = "package a;\n\nimport a.Other;\n\npublic class Client {\n    public void helper(String name) {}\n    public void verify(String name) { helper(name); }\n}\n";
    let sources = Vector#{
        {path = path, content = source},
        {path = "src/a/Other.java", content = ""}
    };
    let definitions = facts(path, source, envelope(path,
        (29, 145) :: (55, 89) :: (94, 143) :: Nil,
        ("definition", (42, 48)) :: ("definition", (67, 73)) :: ("definition", (106, 112)) :: Nil));
    let imports = facts(path, source, envelope(path, (12, 27) :: Nil, ("import", (19, 26)) :: Nil));
    let calls = facts(path, source, envelope(path, (128, 140) :: Nil, ("call", (128, 134)) :: Nil));
    match Repository.admit(sources, definitions, imports, calls) {
        case Err(error) => Assert.fail(ToString.toString(error))
        case Ok(world) => {
            Assert.assertEq(expected = Vector#{"definition", "definition", "definition"},
                Vector.map(fact -> fact#kind, definitions));
            Assert.assertEq(expected = Vector#{"Client", "helper", "verify"},
                Vector.map(symbol -> symbol#name, world#symbols));
            Assert.assertEq(expected = Set#{(fileId(0), fileId(1))}, world#imports);
            Assert.assertEq(expected = Set#{(symbolId(2), symbolId(1))}, world#calls);
            Assert.assertEq(expected = 0, world#unresolvedImports);
            Assert.assertEq(expected = 0, world#unresolvedCalls)
        }
    }
}

@Test
def flixSourceAdmitsTheExpectedFacts(): Unit \ Assert = {
    let path = "src/Demo.flix";
    let source = "mod Demo {\n    use Repository.Structure.FileId\n\n    pub def helper(x: Int32): Int32 = x\n    pub def run(): Int32 = helper(0)\n}\n";
    let sources = Vector#{
        {path = path, content = source},
        {path = "src/Repository/Structure.flix", content = ""}
    };
    let definitions = facts(path, source, envelope(path,
        (0, 126) :: (52, 87) :: (92, 124) :: Nil,
        ("definition", (4, 8)) :: ("definition", (60, 66)) :: ("definition", (100, 103)) :: Nil));
    let imports = facts(path, source, envelope(path, (15, 46) :: Nil, ("import", (15, 46)) :: Nil));
    let calls = facts(path, source, envelope(path, (115, 124) :: Nil, ("call", (115, 121)) :: Nil));
    match Repository.admit(sources, definitions, imports, calls) {
        case Err(error) => Assert.fail(ToString.toString(error))
        case Ok(world) => {
            Assert.assertEq(expected = Vector#{"Demo", "helper", "run"},
                Vector.map(symbol -> symbol#name, world#symbols));
            Assert.assertEq(expected = Set#{(fileId(0), fileId(1))}, world#imports);
            Assert.assertEq(expected = Set#{(symbolId(2), symbolId(1))}, world#calls);
            Assert.assertEq(expected = 0, world#unresolvedImports);
            Assert.assertEq(expected = 0, world#unresolvedCalls)
        }
    }
}

@Test
def starlarkSourceAdmitsTheExpectedFacts(): Unit \ Assert = {
    let path = "src/pkg/BUILD";
    let source = "load(\"//tools:defs.bzl\", \"helper\")\n\ndef helper(name):\n    pass\n\ndef run():\n    helper(\"sample\")\n";
    let sources = Vector#{
        {path = path, content = source},
        {path = "src/tools/defs.bzl", content = ""}
    };
    let definitions = facts(path, source, envelope(path,
        (36, 62) :: (64, 95) :: Nil,
        ("definition", (40, 46)) :: ("definition", (68, 71)) :: Nil));
    let imports = facts(path, source, envelope(path, (5, 23) :: Nil, ("import", (5, 23)) :: Nil));
    let calls = facts(path, source, envelope(path, (79, 95) :: Nil, ("call", (79, 85)) :: Nil));
    match Repository.admit(sources, definitions, imports, calls) {
        case Err(error) => Assert.fail(ToString.toString(error))
        case Ok(world) => {
            Assert.assertEq(expected = Vector#{"helper", "run"},
                Vector.map(symbol -> symbol#name, world#symbols));
            Assert.assertEq(expected = Set#{(fileId(0), fileId(1))}, world#imports);
            Assert.assertEq(expected = Set#{(symbolId(1), symbolId(0))}, world#calls);
            Assert.assertEq(expected = 0, world#unresolvedImports);
            Assert.assertEq(expected = 0, world#unresolvedCalls)
        }
    }
}

/// A surviving admitted target is admitted; an ambiguous one is rejected, not
/// guessed. This is the same conservative admission law the JavaScript path
/// already obeys, now applied per language.
@Test
def ambiguousJavaReferencesAreConservativelyRejected(): Unit \ Assert = {
    let path = "src/a/App.java";
    let source = "package a;\n\nimport a.Client;\n\npublic class App {}\n";
    let definitions = facts(path, source, envelope(path, (30, 49) :: Nil, ("definition", (43, 46)) :: Nil));
    let imports = facts(path, source, envelope(path, (12, 28) :: Nil, ("import", (19, 27)) :: Nil));
    let unique = Vector#{
        {path = path, content = source},
        {path = "src/a/Client.java", content = ""}
    };
    let ambiguous = Vector#{
        {path = path, content = source},
        {path = "src/one/Client.java", content = ""},
        {path = "src/two/Client.java", content = ""}
    };
    match Repository.admit(unique, definitions, imports, Vector.empty()) {
        case Err(error) => Assert.fail(ToString.toString(error))
        case Ok(world) => {
            Assert.assertEq(expected = Set#{(fileId(0), fileId(1))}, world#imports);
            Assert.assertEq(expected = 0, world#unresolvedImports)
        }
    };
    match Repository.admit(ambiguous, definitions, imports, Vector.empty()) {
        case Err(error) => Assert.fail(ToString.toString(error))
        case Ok(ambiguousWorld) => {
            Assert.assertEq(expected = Set.empty(), ambiguousWorld#imports);
            Assert.assertEq(expected = 1, ambiguousWorld#unresolvedImports)
        }
    }
}
