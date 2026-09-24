"""Repository-native structural Atlas laws."""

import multiprocessing
import typing
from operator import attrgetter, itemgetter
from pathlib import Path

import rote

from attune_radii.algebra.relation import FileId, LocationId, SymbolId, nodes
from attune_radii.routing import issue_blind, structural_signature
from attune_radii.world import Atlas

AUTH = FileId(0)
TOKENS = FileId(1)

LOGIN = SymbolId(0)
LOGOUT = SymbolId(1)
SIGN = SymbolId(2)

ROOT = LocationId(2)
SRC = LocationId(3)

ATLAS_DEPTH = 7
LOGICAL_PROGRAMS = 3279
SYMBOL_PROGRAMS = 1643

EXPECTED_COUNTS = (
    ("files", 2),
    ("symbols", 5),
    ("defines", 5),
    ("imports", 1),
    ("calls", 1),
    ("parent", 3),
)
ENCODING = "utf-8"

AUTH_PREFIX = (
    'import { sign } from "./tokens";\n'
    'import "./missing";\n\n'
    "export function login(name: string): string {\n"
)
AUTH_SOURCE = (
    AUTH_PREFIX
    + "  name = name;\n" * (LOGICAL_PROGRAMS // ATLAS_DEPTH)
    + "  duplicate();\n"
    + "  return sign(name);\n"
    + "}\n\n"
    + "export function logout(): void {}\n"
)

TOKENS_MODULE = (
    "export function sign(value: string): string {\n"
    + "  value = value;\n" * (LOGICAL_PROGRAMS // ATLAS_DEPTH)
    + "  return value;\n"
    + "}\n\n"
    + "export function duplicate(): void {}\n"
    + "export function duplicate(): void {}\n"
)

type InvalidationRun = tuple[tuple[int, int], ...]


def _write_repository(root: Path) -> Path:
    """Write the stable two-blob Atlas fixture."""
    source = root / "repository" / "src"
    source.mkdir(parents=True)
    auth = source / "auth.ts"
    tokens = source / "tokens.ts"
    _ = auth.write_text(AUTH_SOURCE, encoding=ENCODING)
    _ = tokens.write_text(TOKENS_MODULE, encoding=ENCODING)
    return source.parent


class _CacheLaw(typing.NamedTuple):
    """Own fresh-process Rote invalidation observations."""

    repository: Path
    grit: Path
    cache: Path

    def _configure(self) -> None:
        """Point the fresh process at its isolated durable store."""
        configure = rote.configure
        cache = self.cache
        _ = configure(cache_dir=cache, min_duration_s=0.0)

    def _write(self, path: Path, content: str) -> None:
        """Write one stable UTF-8 fixture artifact."""
        _ = path.write_text(content, encoding=ENCODING)

    def _measure(self) -> tuple[int, int]:
        """Observe Rote work around one deterministic Atlas build."""
        before = rote.stats()
        location = self.repository, self.grit
        _ = Atlas.build(*location)
        after = rote.stats()
        hits = after["hits"]
        misses = after["misses"]
        hits -= before["hits"]
        misses -= before["misses"]
        return hits, misses

    def run(self) -> InvalidationRun:
        """Exercise blob and primitive invalidation in a fresh process."""
        self._configure()
        measure = self._measure
        runs = [measure()]
        runs.append(measure())
        target = self.repository / "src" / "auth.ts"
        content = AUTH_SOURCE.replace("logout", "signout")
        self._write(target, content)
        runs.append(measure())
        target = self.grit / "calls.grit"
        content = target.read_text(encoding=ENCODING)
        self._write(target, content + "\n// identity change\n")
        runs.append(measure())
        return tuple(runs)

    def copy_grit(self) -> None:
        """Copy the three fixed programs into a mutable fixture directory."""
        self.grit.mkdir()
        for program in Path("grit/typescript").glob("*.grit"):
            content = program.read_text(encoding=ENCODING)
            target = self.grit / program.name
            self._write(target, content)

    def __call__(self) -> InvalidationRun:
        """Run invalidation observation in an independent interpreter."""
        context = multiprocessing.get_context("spawn")
        with context.Pool(1) as pool:
            action = self.run
            return pool.apply(action)


def test_repository_native_atlas(tmp_path: Path) -> None:
    """Source facts compile directly into deterministic finite relations."""
    atlas = Atlas.build(_write_repository(tmp_path))

    signature = structural_signature(
        atlas.relations,
        issue_blind(
            atlas.symbols,
        ),
        depth=ATLAS_DEPTH,
    )

    assert (
        atlas.files,
        tuple(symbol.name for symbol in atlas.symbols),
        (
            atlas.relations.defines[AUTH],
            atlas.relations.defines[TOKENS],
        ),
        (
            atlas.relations.imports[AUTH],
            atlas.relations.imports[TOKENS],
        ),
        (
            atlas.relations.calls[LOGIN],
            atlas.relations.calls[LOGOUT],
        ),
        (
            atlas.relations.parent[LocationId(AUTH)],
            atlas.relations.parent[LocationId(TOKENS)],
            atlas.relations.parent[SRC],
        ),
        (
            atlas.evidence[1].rejected,
            atlas.evidence[2].rejected,
        ),
    ) == (
        (
            "src/auth.ts",
            "src/tokens.ts",
        ),
        (
            "login",
            "logout",
            "sign",
            "duplicate",
            "duplicate",
        ),
        (
            nodes(
                (
                    LOGIN,
                    LOGOUT,
                ),
            ),
            nodes(
                (
                    SIGN,
                    SymbolId(3),
                    SymbolId(4),
                ),
            ),
        ),
        (
            nodes(
                (TOKENS,),
            ),
            nodes(),
        ),
        (
            nodes(
                (SIGN,),
            ),
            nodes(),
        ),
        (
            nodes(
                (SRC,),
            ),
            nodes(
                (SRC,),
            ),
            nodes(
                (ROOT,),
            ),
        ),
        (
            1,
            1,
        ),
    )

    assert atlas.evidence == (
        (5, 2, 5, ()),
        (2, 1, 1, (("relative target absent", 1),)),
        (2, 1, 1, (("global target ambiguous", 1),)),
    )

    assert (
        len(
            issue_blind(
                atlas.symbols,
            ),
        ),
        signature.depth,
        signature.logical_programs,
        signature.symbol_programs,
        signature.counts,
    ) == (
        len(atlas.symbols),
        ATLAS_DEPTH,
        LOGICAL_PROGRAMS,
        SYMBOL_PROGRAMS,
        EXPECTED_COUNTS,
    )

    assert (
        sum(
            map(
                attrgetter("logical_transitions"),
                map(
                    itemgetter(1),
                    signature.relations,
                ),
            ),
        )
        == LOGICAL_PROGRAMS
    )


def test_rote_invalidation_stays_blob_and_primitive_local(tmp_path: Path) -> None:
    """Rote reuses unchanged blobs and primitives after narrow changes."""
    repository = _write_repository(tmp_path / "invalidation")
    law = _CacheLaw(
        repository,
        tmp_path / "invalidation" / "grit",
        tmp_path / "rote",
    )
    law.copy_grit()
    observations = law()
    assert observations[0] == (0, 10)
    assert observations[1] == (4, 0)
    assert observations[2] == (3, 7)
    changed = observations[3]
    assert min(changed) >= len(changed)
