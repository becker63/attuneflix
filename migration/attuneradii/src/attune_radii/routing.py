"""Issue-blind structural routing measurements."""

import hashlib
import statistics
from operator import itemgetter
from typing import Literal, NamedTuple, cast

from .algebra.query import Query
from .algebra.relation import Nodes, Relations, SymbolId, nodes
from .algebra.structure import (
    callers,
    calls,
    defined_in,
    defines,
    imported_by,
    imports,
)
from .world import Symbol

type Domain = Literal["file", "symbol"]
type State = tuple[Domain, Nodes[int]]

type TransitionMemo = dict[
    tuple[str, Nodes[int]],
    Nodes[int],
]

type Atom = tuple[
    str,
    Domain,
    Domain,
    Query[int, int],
]

FILE: Domain = "file"
SYMBOL: Domain = "symbol"

DEFAULT_DEPTH = 7
DEFAULT_SEEDS = 8

THRESHOLD_25 = 0.25
THRESHOLD_50 = 0.50
THRESHOLD_90 = 0.90

QUANTILE_COUNT = 10
P90_INDEX = 8

SEED_POLICY = b"attune-structural-seed-v1\\0"


class Step(NamedTuple):
    """One typed structural transition observed during finite search."""

    atom: str
    before: int
    after: int
    source_size: int
    target_size: int

    def input_density(self) -> float:
        """Return frontier density before this transition."""
        if not self.source_size:
            return 0.0

        return self.before / self.source_size

    def output_density(self) -> float:
        """Return frontier density after this transition."""
        if not self.target_size:
            return 0.0

        return self.after / self.target_size

    def crosses(
        self,
        threshold: float,
    ) -> bool:
        """Return whether this transition truly crosses one density threshold."""
        before = self.input_density()
        after = self.output_density()

        return before < threshold <= after

    def extinct(self) -> bool:
        """Return whether this transition produced an empty frontier."""
        return not self.after

    def is_atom(
        self,
        atom: str,
    ) -> bool:
        """Return whether this observation belongs to one primitive."""
        return self.atom == atom

    @classmethod
    def from_atom(
        cls,
        atom: Atom,
        relations: Relations,
        frontier: Nodes[int],
        memo: TransitionMemo,
    ) -> tuple["Step", State]:
        """Apply one compatible primitive to one finite frontier."""
        key = (
            atom[0],
            frontier,
        )

        reached = memo.get(
            key,
        )

        if reached is None:
            reached = atom[3].forward(
                relations,
                frontier,
            )

            memo[key] = reached

        sizes = {
            FILE: relations.defines.shape[0],
            SYMBOL: relations.defines.shape[1],
        }

        return (
            cls(
                atom[0],
                len(frontier),
                len(reached),
                sizes[atom[1]],
                sizes[atom[2]],
            ),
            (
                atom[2],
                reached,
            ),
        )

    @classmethod
    def expand(
        cls,
        relations: Relations,
        states: tuple[State, ...],
        memo: TransitionMemo,
    ) -> tuple[
        tuple["Step", State],
        ...,
    ]:
        """Expand every typed state by every compatible primitive."""
        transitions: list[tuple[Step, State]] = []

        for domain, frontier in states:
            compatible = FILE_ATOMS

            if domain == SYMBOL:
                compatible = SYMBOL_ATOMS

            transitions.extend(
                cls.from_atom(
                    atom,
                    relations,
                    frontier,
                    memo,
                )
                for atom in compatible
            )

        return tuple(
            transitions,
        )


type SearchResult = tuple[
    tuple[Step, ...],
    int,
]


def search(
    relations: Relations,
    seeds: Nodes[SymbolId],
    depth: int,
    memo: TransitionMemo,
) -> SearchResult:
    """Run the complete typed unary path tree through one depth."""
    states: tuple[State, ...] = (
        (
            SYMBOL,
            seeds,
        ),
    )

    steps: tuple[Step, ...] = ()
    symbol_programs = 0

    while depth:
        transitions = Step.expand(
            relations,
            states,
            memo,
        )

        steps += tuple(
            map(
                itemgetter(0),
                transitions,
            ),
        )

        states = tuple(
            map(
                itemgetter(1),
                transitions,
            ),
        )

        symbol_programs += tuple(
            map(
                itemgetter(0),
                states,
            ),
        ).count(
            SYMBOL,
        )

        depth -= 1

    return steps, symbol_programs


_search = search


ATOMS = cast(
    "tuple[Atom, ...]",
    (
        ("defines", FILE, SYMBOL, defines),
        ("defined_in", SYMBOL, FILE, defined_in),
        ("imports", FILE, FILE, imports),
        ("imported_by", FILE, FILE, imported_by),
        ("calls", SYMBOL, SYMBOL, calls),
        ("callers", SYMBOL, SYMBOL, callers),
    ),
)

FILE_ATOMS = (
    ATOMS[0],
    ATOMS[2],
    ATOMS[3],
)
SYMBOL_ATOMS = (
    ATOMS[1],
    ATOMS[4],
    ATOMS[5],
)


class ThresholdFractions(NamedTuple):
    """Fractions observed at the three locked Atlas density thresholds."""

    at_25: float
    at_50: float
    at_90: float

    @classmethod
    def _output_fraction(
        cls,
        values: tuple[float, ...],
        threshold: float,
    ) -> float:
        """Measure outputs at or above one density threshold."""
        reached = 0

        for value in values:
            if value >= threshold:
                reached += 1

        return reached / len(values)

    @classmethod
    def outputs(
        cls,
        values: tuple[float, ...],
    ) -> "ThresholdFractions":
        """Measure how often output is already at or above each threshold."""
        return cls(
            cls._output_fraction(
                values,
                THRESHOLD_25,
            ),
            cls._output_fraction(
                values,
                THRESHOLD_50,
            ),
            cls._output_fraction(
                values,
                THRESHOLD_90,
            ),
        )

    @classmethod
    def _crossing_fraction(
        cls,
        steps: tuple[Step, ...],
        threshold: float,
    ) -> float:
        """Measure true crossings of one density threshold."""
        crossed = 0

        for step in steps:
            if step.crosses(
                threshold,
            ):
                crossed += 1

        return crossed / len(steps)

    @classmethod
    def crossings(
        cls,
        steps: tuple[Step, ...],
    ) -> "ThresholdFractions":
        """Measure true crossings from below each threshold."""
        return cls(
            cls._crossing_fraction(
                steps,
                THRESHOLD_25,
            ),
            cls._crossing_fraction(
                steps,
                THRESHOLD_50,
            ),
            cls._crossing_fraction(
                steps,
                THRESHOLD_90,
            ),
        )


class RelationSignature(NamedTuple):
    """One primitive direction's issue-blind structural signature."""

    median_density: float
    p90_density: float
    output_fraction: ThresholdFractions
    crossing_fraction: ThresholdFractions
    extinction_fraction: float
    logical_transitions: int

    @classmethod
    def from_steps(
        cls,
        steps: tuple[Step, ...],
        atom: str,
    ) -> "RelationSignature":
        """Reduce all observations of one primitive direction."""
        selected = tuple(
            step
            for step in steps
            if step.is_atom(
                atom,
            )
        )

        if not selected:
            empty = ThresholdFractions(
                0.0,
                0.0,
                0.0,
            )

            return cls(
                0.0,
                0.0,
                empty,
                empty,
                0.0,
                0,
            )

        densities = tuple(
            map(
                Step.output_density,
                selected,
            ),
        )

        p90 = densities[0]

        if len(densities) > 1:
            p90 = float(
                statistics.quantiles(
                    densities,
                    n=QUANTILE_COUNT,
                    method="inclusive",
                )[P90_INDEX],
            )

        return cls(
            float(
                statistics.median(
                    densities,
                ),
            ),
            p90,
            ThresholdFractions.outputs(
                densities,
            ),
            ThresholdFractions.crossings(
                selected,
            ),
            sum(
                map(
                    Step.extinct,
                    selected,
                ),
            )
            / len(selected),
            len(selected),
        )


class StructuralSignature(NamedTuple):
    """One repository's issue-blind structural Atlas signature."""

    depth: int
    counts: tuple[tuple[str, int], ...]
    relations: tuple[tuple[str, RelationSignature], ...]
    logical_programs: int
    symbol_programs: int


def issue_blind(
    symbols: tuple[Symbol, ...],
    count: int = DEFAULT_SEEDS,
) -> Nodes[SymbolId]:
    """Choose deterministic issue-independent repository symbol seeds."""
    if count < 0:
        raise ValueError(count)

    ranked: list[tuple[bytes, SymbolId]] = []

    for index, symbol in enumerate(
        symbols,
    ):
        ranked.append(
            (
                hashlib.sha256(
                    SEED_POLICY
                    + "\\0".join(
                        map(
                            str,
                            symbol,
                        ),
                    ).encode(),
                ).digest(),
                SymbolId(index),
            ),
        )

    ranked.sort()
    ranked = ranked[:count]

    return nodes(
        map(
            itemgetter(1),
            ranked,
        ),
    )


def structural_signature(
    relations: Relations,
    seeds: Nodes[SymbolId],
    depth: int = DEFAULT_DEPTH,
) -> StructuralSignature:
    """Measure one fixed issue-blind typed structural search."""
    if depth < 1:
        raise ValueError(depth)

    steps, symbol_programs = search(
        relations,
        seeds,
        depth,
        {},
    )

    counts = (
        (
            "files",
            relations.defines.shape[0],
        ),
        (
            "symbols",
            relations.defines.shape[1],
        ),
        (
            "defines",
            len(relations.defines),
        ),
        (
            "imports",
            len(relations.imports),
        ),
        (
            "calls",
            len(relations.calls),
        ),
        (
            "parent",
            len(relations.parent),
        ),
    )

    return StructuralSignature(
        depth,
        counts,
        tuple(
            (
                atom[0],
                RelationSignature.from_steps(
                    steps,
                    atom[0],
                ),
            )
            for atom in ATOMS
        ),
        len(steps),
        symbol_programs,
    )
