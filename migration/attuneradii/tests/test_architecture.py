"""Attune-specific architectural laws implemented with Fixit."""

from __future__ import annotations

import typing
from collections.abc import Callable, Mapping

import libcst as cst
from fixit import Invalid, LintRule, Valid
from libcst.metadata import QualifiedNameProvider

type Visitor = Callable[[cst.CSTNode], None]


@typing.final
class AttuneArchitecture(LintRule):
    """Keep effects and durable reuse explicit without conflating them."""

    METADATA_DEPENDENCIES = (QualifiedNameProvider,)

    AD_HOC_CACHE = frozenset(
        (
            "functools.cache",
            "functools.lru_cache",
        ),
    )

    EFFECT = "effect_py.fn"
    ROTE = "rote.cache"
    SERVICE = "effect_py.service"

    RUNNERS = frozenset(
        (
            "effect_py.run_sync",
            "effect_py.run_sync_exit",
        ),
    )

    VALID: typing.ClassVar[list[str | Valid]] = [
        Valid(
            """
            import effect_py as effects

            @effects.fn("example")
            def acquire():
                service = yield from effects.service(Service)
                return service
            """,
        ),
        Valid(
            """
            import rote

            @rote.cache
            def project(values: tuple[int, ...]) -> tuple[int, ...]:
                result = []

                for value in values:
                    result.append(value)

                return tuple(result)
            """,
        ),
        Valid(
            """
            import effect_py as effects
            import rote

            @rote.cache
            @effects.fn("example")
            def replayable():
                store = yield from effects.service(Store)
                return store
            """,
        ),
    ]

    INVALID: typing.ClassVar[list[str | Invalid]] = [
        Invalid(
            """
            import functools

            @functools.cache
            def project(value: int) -> int:
                return value
            """,
        ),
        Invalid(
            """
            import effect_py as effects

            def acquire():
                return effects.service(Service)
            """,
        ),
        Invalid(
            """
            import effect_py as effects

            def execute(effect):
                return effects.run_sync(effect)
            """,
        ),
        Invalid(
            """
            import rote

            state = 0

            @rote.cache
            def compute() -> int:
                global state
                state += 1
                return state
            """,
        ),
        Invalid(
            """
            import rote

            def outer():
                state = 0

                @rote.cache
                def compute() -> int:
                    nonlocal state
                    state += 1
                    return state

                return compute
            """,
        ),
    ]

    cached: list[bool]
    effectful: list[bool]

    def __init__(self) -> None:
        """Create one per-module architectural traversal."""
        super().__init__()

        self.cached = []
        self.effectful = []

    @typing.override
    def get_visitors(self) -> Mapping[str, Visitor]:
        """Expose Ruff-compatible snake-case handlers to LibCST."""
        return {
            "visit_FunctionDef": self.visit_function,
            "leave_FunctionDef": self.leave_function,
            "visit_Call": self.visit_call,
            "visit_Global": self.visit_outer_state,
            "visit_Nonlocal": self.visit_outer_state,
        }

    def _names(
        self,
        node: cst.BaseExpression,
    ) -> frozenset[str]:
        """Return qualified names attached to one expression."""
        values = self.get_metadata(
            QualifiedNameProvider,
            node,
            (),
        )

        return frozenset(value.name for value in values)

    def visit_function(
        self,
        node: cst.CSTNode,
    ) -> None:
        """Enter one function and classify its explicit boundaries."""
        assert isinstance(
            node,
            cst.FunctionDef,
        )

        decorators: set[str] = set()

        for decorator in node.decorators:
            target = decorator.decorator

            if isinstance(
                target,
                cst.Call,
            ):
                target = target.func

            decorators.update(
                self._names(
                    target,
                ),
            )

        ad_hoc = self.AD_HOC_CACHE.intersection(
            decorators,
        )

        if ad_hoc:
            self.report(
                node,
                (
                    "Ad-hoc memoization has no Attune semantic identity: "
                    + ", ".join(
                        sorted(
                            ad_hoc,
                        ),
                    )
                    + "."
                ),
            )

        self.cached.append(
            self.ROTE in decorators,
        )

        self.effectful.append(
            self.EFFECT in decorators,
        )

    def leave_function(
        self,
        node: cst.CSTNode,
    ) -> None:
        """Leave one classified function boundary."""
        assert isinstance(
            node,
            cst.FunctionDef,
        )

        _ = self.cached.pop()
        _ = self.effectful.pop()

    def visit_call(
        self,
        node: cst.CSTNode,
    ) -> None:
        """Enforce capability acquisition and Effect execution boundaries."""
        assert isinstance(
            node,
            cst.Call,
        )

        names = self._names(
            node.func,
        )

        inside_effect = (
            bool(
                self.effectful,
            )
            and self.effectful[-1]
        )

        if self.SERVICE in names and not inside_effect:
            self.report(
                node,
                "effects.service() requires an enclosing @effects.fn boundary.",
            )

        runners = self.RUNNERS.intersection(
            names,
        )

        if runners:
            self.report(
                node,
                (
                    "Library code may construct Effects but may not close them via "
                    + ", ".join(
                        sorted(
                            runners,
                        ),
                    )
                    + "."
                ),
            )

    def visit_outer_state(
        self,
        node: cst.CSTNode,
    ) -> None:
        """Reject hidden outer mutation underneath a Rote boundary."""
        assert isinstance(
            node,
            cst.Global | cst.Nonlocal,
        )

        if not self.cached:
            return

        if not self.cached[-1]:
            return

        kind = type(node).__name__.lower()

        self.report(
            node,
            f"@rote.cache may not mutate outer state with {kind}.",
        )
