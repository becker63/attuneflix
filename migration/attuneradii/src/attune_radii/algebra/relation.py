"""Typed finite relations backed directly by immutable Roaring bitmaps.

The representation keeps only four primitive relation families elsewhere in
Attune Radii; this module supplies their common finite binary relation.

Source and target identities are dense zero-based integers. Each source row and
target column is represented by one immutable :class:`pyroaring.FrozenBitMap`.
Frontier image and preimage therefore reduce to native multiway bitmap unions.

Examples
--------
>>> definitions = Relation(
...     2,
...     3,
...     ((FileId(0), SymbolId(0)), (FileId(0), SymbolId(1))),
... )
>>> definitions[FileId(0)] == nodes((SymbolId(0), SymbolId(1)))
True

"""

from collections.abc import Callable, Iterable
from itertools import starmap
from typing import NamedTuple, NewType, cast, final

from pyroaring import BitMap, FrozenBitMap

FileId = NewType("FileId", int)
SymbolId = NewType("SymbolId", int)
LocationId = NewType("LocationId", int)

type Edge[Source: int, Target: int] = tuple[Source, Target]
type Entries[Source: int, Target: int] = tuple[Edge[Source, Target], ...]
type Nodes[Node: int] = FrozenBitMap
type Shape = tuple[int, int]

_BIT_WIDTH = 32
_LIMIT = 1 << _BIT_WIDTH
_EMPTY = FrozenBitMap()


def nodes[Node: int](
    values: Iterable[Node] = (),
) -> Nodes[Node]:
    """Freeze dense node identities into one hashable Roaring frontier."""
    return FrozenBitMap(values)


def _coordinate(value: int, size: int, index: int) -> int:
    """Validate one externally supplied dense relation coordinate."""
    if value not in range(size):
        message = (
            f"Expected element at index {index} to be in "
            f"range({size}), found {value} instead."
        )
        raise ValueError(message)
    return value


def _indexes[
    Source: int,
    Target: int,
](
    shape: Shape,
    entries: Iterable[Edge[Source, Target]],
) -> tuple[
    tuple[FrozenBitMap, ...],
    tuple[FrozenBitMap, ...],
]:
    """Build forward and reverse Roaring adjacency indexes once."""
    forward = [
        BitMap()
        for _ in range(
            shape[0],
        )
    ]
    reverse = [
        BitMap()
        for _ in range(
            shape[1],
        )
    ]

    for edge in entries:
        source = _coordinate(
            int(edge[0]),
            shape[0],
            0,
        )
        target = _coordinate(
            int(edge[1]),
            shape[1],
            1,
        )

        forward[source].add(target)
        reverse[target].add(source)

    return (
        tuple(map(FrozenBitMap, forward)),
        tuple(map(FrozenBitMap, reverse)),
    )


def _image(
    rows: tuple[FrozenBitMap, ...],
    frontier: FrozenBitMap,
) -> FrozenBitMap:
    """Union all adjacency rows selected by one finite frontier."""
    admitted = filter(
        range(
            len(rows),
        ).__contains__,
        frontier,
    )
    getter = rows.__getitem__
    selected = tuple(map(getter, admitted))

    if not selected:
        return nodes()

    first = selected[0]
    remaining = selected[1:]
    return nodes(first.union(*remaining))


type RowOperation = Callable[[FrozenBitMap, FrozenBitMap], FrozenBitMap]

_UNION: RowOperation = FrozenBitMap.union
_INTERSECTION: RowOperation = FrozenBitMap.intersection
_DIFFERENCE: RowOperation = FrozenBitMap.difference


def _rowwise(
    left: tuple[FrozenBitMap, ...],
    right: tuple[FrozenBitMap, ...],
    operation: RowOperation,
) -> tuple[FrozenBitMap, ...]:
    """Apply one exact set operation to aligned adjacency rows."""
    pairs = zip(left, right, strict=True)
    return tuple(starmap(operation, pairs))


@final
class Relation[Source: int, Target: int]:
    """Immutable typed binary relation over dense finite integer domains."""

    __slots__ = (
        "columns",
        "rows",
        "shape",
    )

    def __init__(
        self,
        source_size: int,
        target_size: int,
        entries: Iterable[Edge[Source, Target]],
    ) -> None:
        """Index one finite edge set in both directions."""
        if source_size < 0 or target_size < 0:
            message = "Relation dimensions must be non-negative."
            raise ValueError(message)
        if source_size > _LIMIT or target_size > _LIMIT:
            message = "PyRoaring relations require 32-bit node identities."
            raise NotImplementedError(message)
        shape = source_size, target_size

        forward, reverse = _indexes(
            shape,
            entries,
        )

        self.shape = shape
        self.rows = forward
        self.columns = reverse

    @classmethod
    def _from_indexes(
        cls,
        shape: Shape,
        forward: tuple[FrozenBitMap, ...],
        reverse: tuple[FrozenBitMap, ...],
    ) -> "Relation[Source, Target]":
        """Wrap already-computed immutable indexes without rebuilding."""
        relation = object.__new__(cls)

        relation.shape = shape
        relation.rows = forward
        relation.columns = reverse

        return relation

    def __len__(
        self,
    ) -> int:
        """Return the number of admitted finite edges."""
        return sum(map(len, self.rows))

    def entries(
        self,
    ) -> Entries[Source, Target]:
        """Return stable admitted relation entries."""
        return tuple(
            cast(
                "Edge[Source, Target]",
                (
                    source,
                    target,
                ),
            )
            for source, row in enumerate(
                self.rows,
            )
            for target in row
        )

    def __getitem__(
        self,
        source: Source | Nodes[Source],
    ) -> Nodes[Target]:
        """Return targets adjacent to one source or finite frontier."""
        if isinstance(source, int):
            coordinate = int(source)

            if coordinate not in range(
                self.shape[0],
            ):
                return _EMPTY

            return self.rows[coordinate]

        return _image(
            self.rows,
            source,
        )

    def preimage(
        self,
        target: Target | Nodes[Target],
    ) -> Nodes[Source]:
        """Return sources adjacent to one target or target frontier."""
        if isinstance(target, int):
            coordinate = int(target)

            if coordinate not in range(
                self.shape[1],
            ):
                return _EMPTY

            return self.columns[coordinate]

        return _image(
            self.columns,
            target,
        )

    def _compatible(
        self,
        other: "Relation[Source, Target]",
    ) -> None:
        """Require aligned finite domains for relation set algebra."""
        if self.shape != other.shape:
            message = "Relation set algebra requires identical shapes."
            raise ValueError(message)

    def _set_operation(
        self,
        other: "Relation[Source, Target]",
        operation: RowOperation,
    ) -> "Relation[Source, Target]":
        """Apply one exact set operation to both immutable indexes."""
        self._compatible(other)
        return self._from_indexes(
            self.shape,
            _rowwise(
                self.rows,
                other.rows,
                operation,
            ),
            _rowwise(
                self.columns,
                other.columns,
                operation,
            ),
        )

    def __or__(
        self,
        other: "Relation[Source, Target]",
    ) -> "Relation[Source, Target]":
        """Return relational union."""
        return self._set_operation(other, _UNION)

    def __and__(
        self,
        other: "Relation[Source, Target]",
    ) -> "Relation[Source, Target]":
        """Return relational intersection."""
        return self._set_operation(other, _INTERSECTION)

    def __sub__(
        self,
        other: "Relation[Source, Target]",
    ) -> "Relation[Source, Target]":
        """Return relational difference."""
        return self._set_operation(other, _DIFFERENCE)

    @property
    def reverse(
        self,
    ) -> "Relation[Target, Source]":
        """Reverse direction by exchanging immutable native indexes."""
        return cast(
            "Relation[Target, Source]",
            Relation._from_indexes(
                (
                    self.shape[1],
                    self.shape[0],
                ),
                self.columns,
                self.rows,
            ),
        )

    def then[End: int](
        self,
        other: "Relation[Target, End]",
    ) -> "Relation[Source, End]":
        """Compose two relations through native adjacency unions."""
        middle_size = self.shape[1]
        if middle_size != other.shape[0]:
            message = "Relation composition requires aligned middle domains."
            raise ValueError(message)

        forward = tuple(
            _image(
                other.rows,
                middle,
            )
            for middle in self.rows
        )

        reverse = tuple(
            _image(
                self.columns,
                middle,
            )
            for middle in other.columns
        )

        return cast(
            "Relation[Source, End]",
            Relation._from_indexes(
                (
                    self.shape[0],
                    other.shape[1],
                ),
                forward,
                reverse,
            ),
        )


class Relations(NamedTuple):
    """The complete primitive structural vocabulary of Attune Radii."""

    defines: Relation[FileId, SymbolId]
    imports: Relation[FileId, FileId]
    calls: Relation[SymbolId, SymbolId]
    parent: Relation[LocationId, LocationId]
