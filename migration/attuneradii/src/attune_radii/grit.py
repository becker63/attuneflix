"""Small public Python façade over pinned native Grit."""

from functools import partial
from itertools import starmap
from operator import attrgetter
from pathlib import PurePosixPath
from typing import NamedTuple, cast, final

import _attune_grit

type Rejections = tuple[tuple[str, int], ...]
type EvidenceRecord = tuple[int, int, int, list[tuple[str, int]]]

SOURCE_SUFFIXES = (
    ".ts",
    ".tsx",
    ".js",
    ".jsx",
    ".mts",
    ".cts",
    ".mjs",
    ".cjs",
)
TYPESCRIPT_LANGUAGE = "language js(typescript)"
TSX_LANGUAGE = "language js(jsx)"
TSX_SOURCE_SUFFIXES = frozenset(
    (".js", ".jsx", ".mjs", ".cjs", ".tsx"),
)


class Match(NamedTuple):
    """One complete structural match."""

    path: str
    start_byte: int
    end_byte: int

    @property
    def width(self) -> int:
        """Return the matched byte width."""
        return self.end_byte - self.start_byte


class Log(NamedTuple):
    """One Grit log binding projected onto a source range."""

    message: str
    start_byte: int
    end_byte: int


class Evaluation(NamedTuple):
    """One deterministic Grit evaluation."""

    matched: bool
    matches: tuple[Match, ...]
    logs: tuple[Log, ...]


class Fact(NamedTuple):
    """One stable source fact emitted by a Grit primitive."""

    kind: str
    path: str
    start_byte: int
    end_byte: int
    value: str


class PrimitiveEvidence(NamedTuple):
    """Stable accounting from normalized observations to admitted edges."""

    observations: int
    files: int
    admitted: int
    rejections: Rejections

    @property
    def rejected(self) -> int:
        """Return the total rejected observation count."""
        rejected = dict(self.rejections)
        return sum(rejected.values())

    def encode(self) -> EvidenceRecord:
        """Encode stable primitive evidence for JSON telemetry."""
        return (
            self.observations,
            self.files,
            self.admitted,
            list(self.rejections),
        )

    @classmethod
    def decode(
        cls,
        record: EvidenceRecord,
    ) -> "PrimitiveEvidence":
        """Freeze one JSON-decoded primitive evidence record."""
        return cls(
            record[0],
            record[1],
            record[2],
            cast(
                "Rejections",
                tuple(
                    map(
                        tuple,
                        record[3],
                    ),
                ),
            ),
        )


@final
class GritCompileError(ValueError):
    """A fixed Grit program failed to compile."""


@final
class Grit:
    """Compile and execute pinned Grit programs."""

    __slots__ = ()

    @classmethod
    def _fact(
        cls,
        log: Log,
        matches: tuple[Match, ...],
        path: str,
        source: bytes,
    ) -> Fact:
        """Bind one logged value to its smallest enclosing syntax match."""
        candidates: list[Match] = []
        for item in matches:
            if item.start_byte > log.start_byte:
                continue
            if log.end_byte > item.end_byte:
                continue
            candidates.append(item)

        span = min(
            candidates,
            key=attrgetter("width"),
        )
        value = source[
            slice(
                log.start_byte,
                log.end_byte,
            )
        ]
        return Fact(
            log.message.rstrip(),
            path,
            span.start_byte,
            span.end_byte,
            value.decode(),
        )

    def run(
        self,
        program: str,
        path: str,
        content: str,
    ) -> Evaluation:
        """Evaluate one program against one in-memory source file."""
        try:
            native = _attune_grit.run(
                program,
                path,
                content,
            )
        except ValueError as error:
            raise GritCompileError(
                str(error),
            ) from error

        matched, matches, logs = native

        return Evaluation(
            matched,
            tuple(
                starmap(
                    Match,
                    matches,
                ),
            ),
            tuple(
                starmap(
                    Log,
                    logs,
                ),
            ),
        )

    def facts(
        self,
        program: str,
        path: str,
        content: str,
    ) -> tuple[Fact, ...]:
        """Normalize one Grit evaluation into stable source facts."""
        evaluation = self.run(
            program,
            path,
            content,
        )

        source = content.encode()

        facts = map(
            partial(
                self._fact,
                matches=evaluation.matches,
                path=path,
                source=source,
            ),
            evaluation.logs,
        )

        return tuple(
            sorted(
                facts,
                key=attrgetter(
                    "start_byte",
                    "end_byte",
                ),
            ),
        )

    def source_facts(
        self,
        program: str,
        path: str,
        content: str,
    ) -> tuple[Fact, ...]:
        """Evaluate one program under its explicit source parser family."""
        if PurePosixPath(path).suffix in TSX_SOURCE_SUFFIXES:
            if TYPESCRIPT_LANGUAGE not in program:
                message = f"TSX source requires a TypeScript-family program: {path}"
                raise ValueError(message)
            program = program.replace(
                TYPESCRIPT_LANGUAGE,
                TSX_LANGUAGE,
                1,
            )
        return self.facts(
            program,
            path,
            content,
        )
