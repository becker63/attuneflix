"""Compile typed structural queries into finite relation traversals."""

from collections.abc import Callable
from functools import partial
from typing import NamedTuple

from .relation import Nodes, Relation, Relations

type Runner[Source: int, Target: int] = Callable[
    [Relations, Nodes[Source]],
    Nodes[Target],
]

type RelationGetter[Source: int, Target: int] = Callable[
    [Relations],
    Relation[Source, Target],
]


def _forward[Source: int, Target: int](
    getter: RelationGetter[Source, Target],
    world: Relations,
    nodes: Nodes[Source],
) -> Nodes[Target]:
    """Execute one primitive relation forward."""
    return getter(world)[nodes]


def _backward[Source: int, Target: int](
    getter: RelationGetter[Source, Target],
    world: Relations,
    nodes: Nodes[Target],
) -> Nodes[Source]:
    """Execute one primitive relation backward."""
    return getter(world).preimage(
        nodes,
    )


def _compose[
    Source: int,
    Middle: int,
    Target: int,
](
    first: Runner[Source, Middle],
    second: Runner[Middle, Target],
    world: Relations,
    nodes: Nodes[Source],
) -> Nodes[Target]:
    """Execute two compiled traversals in sequence."""
    middle = first(
        world,
        nodes,
    )

    return second(
        world,
        middle,
    )


def _union[
    Source: int,
    Target: int,
](
    left: Runner[Source, Target],
    right: Runner[Source, Target],
    world: Relations,
    nodes: Nodes[Source],
) -> Nodes[Target]:
    """Execute and union two compiled traversals."""
    first = left(
        world,
        nodes,
    )

    second = right(
        world,
        nodes,
    )

    return first | second


class Query[Source: int, Target: int](NamedTuple):
    """A typed immutable structural query and compiled execution plan."""

    name: str
    forward: Runner[Source, Target]
    backward: Runner[Target, Source]

    def __invert__(
        self,
    ) -> "Query[Target, Source]":
        """Reverse query direction without recompilation."""
        return Query(
            f"~{self.name}",
            self.backward,
            self.forward,
        )

    def __rshift__[End: int](
        self,
        other: "Query[Target, End]",
    ) -> "Query[Source, End]":
        """Compile relational composition into one reusable plan."""
        forward = partial(
            _compose,
            self.forward,
            other.forward,
        )

        backward = partial(
            _compose,
            other.backward,
            self.backward,
        )

        return Query(
            f"{self.name} >> {other.name}",
            forward,
            backward,
        )

    def __or__(
        self,
        other: "Query[Source, Target]",
    ) -> "Query[Source, Target]":
        """Compile relational union into one reusable plan."""
        forward = partial(
            _union,
            self.forward,
            other.forward,
        )

        backward = partial(
            _union,
            self.backward,
            other.backward,
        )

        return Query(
            f"{self.name} | {other.name}",
            forward,
            backward,
        )


def edge[Source: int, Target: int](
    name: str,
    getter: RelationGetter[Source, Target],
) -> Query[Source, Target]:
    """Compile one named typed getter into a primitive traversal."""
    return Query(
        name,
        partial(
            _forward,
            getter,
        ),
        partial(
            _backward,
            getter,
        ),
    )
