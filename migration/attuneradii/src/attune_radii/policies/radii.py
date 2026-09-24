"""Compiled deterministic localization policy discovered by Attune Radii."""

from itertools import islice
from typing import NamedTuple

from attune_radii.algebra.relation import Nodes, Relations, SymbolId, nodes
from attune_radii.algebra.structure import calls, same_file, select

ANSWER_SIZE = 20
PROTECTED_COUNT = 18
MAX_CENTERS = 8
STASIS_WINDOW = 3

type Ranking = tuple[SymbolId, ...]


class Localization(NamedTuple):
    """One final deterministic localization decision."""

    answer: Ranking
    centers: int
    work: int


def answer(
    ranking: Ranking,
    seen: Nodes[SymbolId],
    limit: int,
) -> Ranking:
    """Project semantic order onto a structurally visible symbol set."""
    visible = filter(seen.__contains__, ranking)
    size = max(0, limit)
    return tuple(islice(visible, size))


def _localization(
    ranking: Ranking,
    relations: Relations,
    center_count: int,
) -> Localization:
    """Evaluate one cumulative P18 F-plus-DF acquisition state."""
    centers = nodes(
        ranking[:center_count],
    )

    down = (
        select(
            relations,
            calls,
            centers,
        )
        - centers
    )

    files = (
        select(
            relations,
            same_file,
            centers,
        )
        - centers
    )

    down_files = select(
        relations,
        same_file,
        down,
    )

    visible = nodes(
        ranking[:PROTECTED_COUNT],
    )

    visible = visible | files
    visible = visible | down_files

    return Localization(
        answer(
            ranking,
            visible,
            ANSWER_SIZE,
        ),
        center_count,
        center_count + len(down),
    )


def localize(
    ranking: Ranking,
    relations: Relations,
) -> Localization:
    """Run the compiled policy until three full packets are unchanged."""
    current = _localization(
        ranking,
        relations,
        0,
    )
    previous = current.answer
    stable = 0

    for center_count in range(
        1,
        MAX_CENTERS + 1,
    ):
        current = _localization(
            ranking,
            relations,
            center_count,
        )

        if current.answer == previous:
            stable += 1
        else:
            stable = 0

        full = len(current.answer) == ANSWER_SIZE
        if full and stable >= STASIS_WINDOW:
            return current

        previous = current.answer

    return current
