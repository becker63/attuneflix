"""Executable laws for Attune Radii structural extraction and algebra."""

from operator import attrgetter, itemgetter
from pathlib import Path

import pytest

from attune_radii.algebra.relation import (
    FileId,
    LocationId,
    Relation,
    Relations,
    SymbolId,
    nodes,
)
from attune_radii.algebra.structure import (
    callees,
    callers,
    import_neighbors,
    importer_neighbors,
    repository,
    same_file,
    select,
)
from attune_radii.grit import (
    SOURCE_SUFFIXES,
    TSX_SOURCE_SUFFIXES,
    Fact,
    Grit,
    GritCompileError,
)
from attune_radii.policies.radii import answer, localize

FILES = 2
SYMBOLS = 4
LOCATIONS = 3

DEFINES = Path("grit/typescript/defines.grit")
IMPORTS_GRIT = Path("grit/typescript/imports.grit")
CALLS_GRIT = Path("grit/typescript/calls.grit")

GRIT_PATH = "src/example.ts"
ENCODING = "utf-8"
SEMICOLON = b";"
TYPED_NAME = "typed"
VIEW_NAME = "view"
COMMON_NAME = "common"

GRIT_SOURCE = """import { verify } from "./verify";

export function greet(name: string): string {
  verify(name);
  return name;
}
"""

GRIT_BYTES = GRIT_SOURCE.encode()
CALL_SOURCE = b"verify(name)"

GRIT_PROGRAMS = (
    DEFINES,
    IMPORTS_GRIT,
    CALLS_GRIT,
)


GRIT_SURFACE_SOURCES = (
    """
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

module.exports = function commonExport(value) { return value; };

Client.prototype.legacy = function legacy(value) { return value; };

export function overload(value: string): string;
export function overload(value: number): number;
export function overload(
  value: string | number,
): string | number {
  return value;
}

const ordinary = createVerifier();
""",
    """
import { verify } from "./verify";
import Client from "./client";
import * as auth from "./auth";
import type { User } from "./types";
import "./setup";
const common = require("./common");
const dynamic = require(moduleName);

export { helper } from "./helper";

async function load(): Promise<unknown> {
  return import("./lazy");
}
""",
    """
async function run(client: Client): Promise<void> {
  verify();
  client.verify();
  client?.optional();
  generic<string>();
  await awaited();
  await import("./lazy");
  require("./common");
  const created = new Client();
  void created;
}
""",
)

NESTED_CALL_SOURCE = "Boolean(verify(name));"
NESTED_CALL_BYTES = NESTED_CALL_SOURCE.encode()

NESTED_CALL_EXPECTED = (
    Fact(
        "call",
        GRIT_PATH,
        NESTED_CALL_BYTES.index(
            b"Boolean",
        ),
        NESTED_CALL_BYTES.index(
            SEMICOLON,
        ),
        "Boolean",
    ),
    Fact(
        "call",
        GRIT_PATH,
        NESTED_CALL_BYTES.index(
            CALL_SOURCE,
        ),
        NESTED_CALL_BYTES.index(
            CALL_SOURCE,
        )
        + len(CALL_SOURCE),
        "verify",
    ),
)


GRIT_SURFACE_EXPECTED = (
    (
        "plain",
        "generic",
        "method",
        "create",
        "genericMethod",
        "field",
        "objectMethod",
        "objectArrow",
        "arrow",
        "expression",
        "namedExpression",
        "commonExport",
        "legacy",
        "overload",
    ),
    (
        '"./verify"',
        '"./client"',
        '"./auth"',
        '"./types"',
        '"./setup"',
        '"./common"',
        "moduleName",
    ),
    (
        "verify",
        "client.verify",
        "client?.optional",
        "generic",
        "awaited",
    ),
)

SUFFIX_SOURCES = (
    (
        ".ts",
        "export function typed(value: string): string { return value; }",
        TYPED_NAME,
    ),
    (".tsx", "export function view() { return <main />; }", VIEW_NAME),
    (".js", "module.exports = function common() {};", COMMON_NAME),
    (".jsx", "module.exports = function view() { return <main />; };", VIEW_NAME),
    (
        ".mts",
        "export function typed(value: string): string { return value; }",
        TYPED_NAME,
    ),
    (
        ".cts",
        "export function typed(value: string): string { return value; }",
        TYPED_NAME,
    ),
    (".mjs", "export function moduleFunction() {}", "moduleFunction"),
    (".cjs", "module.exports = function common() {};", COMMON_NAME),
)
SUFFIX_EXPECTED = (
    (".ts", (TYPED_NAME,), TYPED_NAME),
    (".tsx", (VIEW_NAME,), VIEW_NAME),
    (".js", (COMMON_NAME,), COMMON_NAME),
    (".jsx", (VIEW_NAME,), VIEW_NAME),
    (".mts", (TYPED_NAME,), TYPED_NAME),
    (".cts", (TYPED_NAME,), TYPED_NAME),
    (".mjs", ("moduleFunction",), "moduleFunction"),
    (".cjs", (COMMON_NAME,), COMMON_NAME),
)

GRIT_FACT_EXPECTED = (
    (
        Fact(
            "definition",
            GRIT_PATH,
            GRIT_BYTES.index(
                b"function",
            ),
            len(
                GRIT_BYTES.rstrip(
                    b"\n",
                ),
            ),
            "greet",
        ),
    ),
    (
        Fact(
            "import",
            GRIT_PATH,
            GRIT_BYTES.index(
                b"import",
            ),
            GRIT_BYTES.index(
                SEMICOLON,
            )
            + len(SEMICOLON),
            '"./verify"',
        ),
    ),
    (
        Fact(
            "call",
            GRIT_PATH,
            GRIT_BYTES.index(
                CALL_SOURCE,
            ),
            GRIT_BYTES.index(
                CALL_SOURCE,
            )
            + len(CALL_SOURCE),
            "verify",
        ),
    ),
)


AUTH = FileId(0)
TOKENS = FileId(1)
ROOT = LocationId(2)

LOGIN = SymbolId(0)
LOGOUT = SymbolId(1)
VERIFY = SymbolId(2)
SIGN = SymbolId(3)

LOGIN_ONLY = nodes((LOGIN,))
LOGOUT_ONLY = nodes((LOGOUT,))
VERIFY_ONLY = nodes((VERIFY,))
AUTH_SYMBOLS = nodes((LOGIN, LOGOUT))
TOKEN_SYMBOLS = nodes((VERIFY, SIGN))

DEFINITION_EDGES = (
    (AUTH, LOGIN),
    (AUTH, LOGOUT),
    (TOKENS, VERIFY),
    (TOKENS, SIGN),
)

IMPORTS = ((AUTH, TOKENS),)

PARENT_EDGES = (
    (LocationId(0), ROOT),
    (LocationId(1), ROOT),
)

CALLS = (
    (LOGIN, VERIFY),
    (VERIFY, SIGN),
)

CALLER_CASE = (
    (LOGIN, VERIFY),
    (LOGIN, SIGN),
    (LOGOUT, SIGN),
)

RELATIONS = Relations(
    Relation(
        FILES,
        SYMBOLS,
        DEFINITION_EDGES,
    ),
    Relation(
        FILES,
        FILES,
        IMPORTS,
    ),
    Relation(
        SYMBOLS,
        SYMBOLS,
        CALLS,
    ),
    Relation(
        LOCATIONS,
        LOCATIONS,
        PARENT_EDGES,
    ),
)


def test_relation_set_algebra() -> None:
    """Finite relations preserve ordinary set operations."""
    left = Relation(
        FILES,
        SYMBOLS,
        (
            (AUTH, LOGIN),
            (AUTH, LOGOUT),
        ),
    )

    right = Relation(
        FILES,
        SYMBOLS,
        (
            (AUTH, LOGOUT),
            (TOKENS, VERIFY),
        ),
    )

    union = left | right
    intersection = left & right
    difference = left - right

    assert union[AUTH] == AUTH_SYMBOLS
    assert union[TOKENS] == VERIFY_ONLY
    assert intersection[AUTH] == LOGOUT_ONLY
    assert difference[AUTH] == LOGIN_ONLY


def test_frontier_and_reverse() -> None:
    """Indexing unions a frontier and reverse exchanges edge direction."""
    calls_relation = Relation(
        SYMBOLS,
        SYMBOLS,
        CALLER_CASE,
    )

    frontier = nodes(
        (
            LOGIN,
            LOGOUT,
        ),
    )

    assert calls_relation[frontier] == TOKEN_SYMBOLS
    assert calls_relation.reverse[SIGN] == AUTH_SYMBOLS


def test_composition_follows_structural_paths() -> None:
    """Relation composition follows definitions through imports."""
    definitions = Relation(
        FILES,
        SYMBOLS,
        DEFINITION_EDGES,
    )

    imports_relation = Relation(
        FILES,
        FILES,
        IMPORTS,
    )

    imported_files = definitions.reverse.then(
        imports_relation,
    )

    imported = imported_files.then(
        definitions,
    )

    assert imported[LOGIN] == TOKEN_SYMBOLS
    assert imported[LOGOUT] == TOKEN_SYMBOLS


def test_external_coordinates_cannot_wrap() -> None:
    """Coordinates outside the finite domain are rejected."""
    outside = FileId(FILES)
    invalid = ((outside, LOGIN),)

    with pytest.raises(
        ValueError,
        match="Expected element at index 0",
    ):
        _ = Relation(
            FILES,
            SYMBOLS,
            invalid,
        )


def test_queries_preserve_structural_meaning() -> None:
    """Native facts and typed queries preserve structural meaning."""
    assert (
        select(
            RELATIONS,
            callees,
            LOGIN_ONLY,
        ),
        select(
            RELATIONS,
            callers,
            VERIFY_ONLY,
        ),
        select(
            RELATIONS,
            same_file,
            LOGIN_ONLY,
        ),
        select(
            RELATIONS,
            import_neighbors,
            LOGIN_ONLY,
        ),
        select(
            RELATIONS,
            importer_neighbors,
            VERIFY_ONLY,
        ),
    ) == (
        VERIFY_ONLY,
        LOGIN_ONLY,
        AUTH_SYMBOLS,
        TOKEN_SYMBOLS,
        AUTH_SYMBOLS,
    )

    for item in zip(
        GRIT_PROGRAMS,
        GRIT_SURFACE_SOURCES,
        GRIT_SURFACE_EXPECTED,
        strict=True,
    ):
        assert (
            tuple(
                fact.value
                for fact in Grit().facts(
                    item[0].read_text(
                        encoding=ENCODING,
                    ),
                    GRIT_PATH,
                    item[1],
                )
            )
            == item[2]
        )

    assert (
        tuple(
            Grit().facts(
                item.read_text(
                    encoding=ENCODING,
                ),
                GRIT_PATH,
                GRIT_SOURCE,
            )
            for item in GRIT_PROGRAMS
        )
        == GRIT_FACT_EXPECTED
    )

    assert (
        Grit().facts(
            CALLS_GRIT.read_text(
                encoding=ENCODING,
            ),
            GRIT_PATH,
            NESTED_CALL_SOURCE,
        )
        == NESTED_CALL_EXPECTED
    )

    assert (
        tuple(map(itemgetter(0), SUFFIX_SOURCES)),
        TSX_SOURCE_SUFFIXES,
        tuple(
            (
                case[0],
                tuple(
                    map(
                        attrgetter("value"),
                        Grit().source_facts(
                            DEFINES.read_text(encoding=ENCODING),
                            "example" + case[0],
                            case[1],
                        ),
                    ),
                ),
                case[2],
            )
            for case in SUFFIX_SOURCES
        ),
    ) == (
        SOURCE_SUFFIXES,
        frozenset((".js", ".jsx", ".mjs", ".cjs", ".tsx")),
        SUFFIX_EXPECTED,
    )

    with pytest.raises(
        GritCompileError,
    ):
        _ = Grit().run(
            """engine marzano(0.1)
language js(typescript)

definitely_not_a_typescript_node()
""",
            GRIT_PATH,
            GRIT_SOURCE,
        )


def test_repository_query_generates_locality() -> None:
    """Repository parenthood derives bounded source-tree locality."""
    assert (
        repository.neighbors(
            RELATIONS,
            LOGIN_ONLY,
            1,
        )
        == AUTH_SYMBOLS
    )

    assert repository.neighbors(
        RELATIONS,
        LOGIN_ONLY,
        2,
    ) == (AUTH_SYMBOLS | TOKEN_SYMBOLS)
    ranking = LOGIN, LOGOUT, VERIFY, SIGN
    candidates = nodes((LOGIN, VERIFY))
    expected = LOGIN, VERIFY
    assert answer(ranking, candidates, 2) == expected
    empty = answer(ranking, TOKEN_SYMBOLS, -1)
    assert empty == ()
    localization = localize(ranking, RELATIONS)
    assert localization == (ranking, 8, 8)


def test_structural_microscopes_are_extensionally_distinct() -> None:
    """One finite witness proves the current microscopes are non-equivalent."""
    microscopes = (
        same_file,
        callees,
        callers,
        import_neighbors,
        importer_neighbors,
    )

    outputs = tuple(
        select(
            RELATIONS,
            microscope,
            VERIFY_ONLY,
        )
        for microscope in microscopes
    )

    assert outputs == (
        TOKEN_SYMBOLS,
        nodes((SIGN,)),
        LOGIN_ONLY,
        nodes(),
        AUTH_SYMBOLS,
    )

    # A single common input on which every result differs is a constructive
    # witness that no pair of these queries denotes the same function.
    distinct = frozenset(
        outputs,
    )

    assert len(distinct) == len(microscopes)
