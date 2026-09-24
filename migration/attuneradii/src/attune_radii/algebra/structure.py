"""Semantic structural queries used by localization policies."""

from .query import Query, edge
from .relation import (
    FileId,
    LocationId,
    Nodes,
    Relations,
    SymbolId,
    nodes,
)

defines = edge(
    "defines",
    lambda relations: relations.defines,
)

imports = edge(
    "imports",
    lambda relations: relations.imports,
)

calls = edge(
    "calls",
    lambda relations: relations.calls,
)

parent = edge(
    "parent",
    lambda relations: relations.parent,
)


defined_in = ~defines
imported_by = ~imports

callers = ~calls
callees = calls

same_file = defined_in >> defines

import_neighbors = defined_in >> imports >> defines

importer_neighbors = defined_in >> imported_by >> defines

repository_adjacent = parent | ~parent


def select[Source: int, Target: int](
    relations: Relations,
    query: Query[Source, Target],
    frontier: Nodes[Source],
) -> Nodes[Target]:
    """Execute one typed structural query."""
    return query.forward(
        relations,
        frontier,
    )


class RepositoryQuery:
    """Project symbol frontiers through repository hierarchy."""

    def _locations(
        self,
        relations: Relations,
        frontier: Nodes[SymbolId],
    ) -> Nodes[LocationId]:
        """Map symbols onto aligned repository file locations."""
        files = select(
            relations,
            defined_in,
            frontier,
        )
        return nodes(map(LocationId, files))

    def _walk(
        self,
        relations: Relations,
        locations: Nodes[LocationId],
        radius: int,
    ) -> Nodes[LocationId]:
        """Return repository locations reachable within one radius."""
        seen = locations
        pending = locations

        for _step in range(radius):
            pending = (
                select(
                    relations,
                    repository_adjacent,
                    pending,
                )
                - seen
            )

            if not pending:
                break

            seen = seen | pending

        return seen

    def _files(
        self,
        relations: Relations,
        locations: Nodes[LocationId],
    ) -> Nodes[FileId]:
        """Project aligned repository locations back onto files."""
        file_count = relations.defines.shape[0]
        domain = range(file_count)
        admitted = filter(domain.__contains__, locations)
        return nodes(map(FileId, admitted))

    def neighbors(
        self,
        relations: Relations,
        frontier: Nodes[SymbolId],
        radius: int,
    ) -> Nodes[SymbolId]:
        """Expand symbols through bounded repository locality."""
        locations = self._locations(
            relations,
            frontier,
        )
        locations = self._walk(
            relations,
            locations,
            radius,
        )
        files = self._files(
            relations,
            locations,
        )
        return select(
            relations,
            defines,
            files,
        )


repository = RepositoryQuery()
