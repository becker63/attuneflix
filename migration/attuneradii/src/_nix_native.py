"""Own the native Nix evaluator and realised store-path lifetimes."""

import ctypes
from contextlib import ExitStack
from pathlib import Path
from typing import NamedTuple, Self, final

import _attune_nix_abi as abi

from _nix_ffi import NixError, Receiver, check, cstring, error, initialize

WRONG_TYPE = "Nix expression did not evaluate to a string."
APPLICATION_REALISATION = False

type Realised = tuple[str, tuple[Path, ...]]


def _require(
    context: object,
    value: object,
    operation: str,
) -> object:
    """Return one non-null native pointer or raise its Nix error."""
    if value:
        return value

    message = f"{operation} failed: {error(context)}"
    raise NixError(message)


def _store(context: object) -> object:
    """Open the system daemon store."""
    daemon = cstring("daemon")
    return _require(
        context,
        abi.nix_store_open(context, daemon.pointer, None),
        "nix_store_open",
    )


def _state(
    context: object,
    store: object,
) -> tuple[object, object]:
    """Create one flake-aware evaluator and its retained settings."""
    with ExitStack() as cleanup:
        flakes = _require(
            context,
            abi.nix_flake_settings_new(
                context,
            ),
            "nix_flake_settings_new",
        )

        _ = cleanup.callback(abi.nix_flake_settings_free, flakes)
        with ExitStack() as builder_cleanup:
            builder = _require(
                context,
                abi.nix_eval_state_builder_new(
                    context,
                    store,
                ),
                "nix_eval_state_builder_new",
            )
            _ = builder_cleanup.callback(abi.nix_eval_state_builder_free, builder)
            check(
                context,
                abi.nix_flake_settings_add_to_eval_state_builder(
                    context,
                    flakes,
                    builder,
                ),
                "nix_flake_settings_add_to_eval_state_builder",
            )
            state = _require(
                context,
                abi.nix_eval_state_build(context, builder),
                "nix_eval_state_build",
            )

        _ = cleanup.pop_all()

        return state, flakes


def _decref(
    context: object,
    value: object,
) -> None:
    """Release one evaluator-owned value."""
    check(
        context,
        abi.nix_value_decref(context, value),
        "nix_value_decref",
    )


def _evaluate(
    context: object,
    state: object,
    value: object,
    expression: str,
    origin: Path,
) -> None:
    """Evaluate, force, and require one Nix string."""
    encoded_expression = cstring(expression)
    encoded_origin = cstring(str(origin))

    check(
        context,
        abi.nix_expr_eval_from_string(
            context,
            state,
            encoded_expression.pointer,
            encoded_origin.pointer,
            value,
        ),
        "nix_expr_eval_from_string",
    )

    check(
        context,
        abi.nix_value_force(
            context,
            state,
            value,
        ),
        "nix_value_force",
    )

    value_type = abi.nix_get_type(context, value)
    if value_type != abi.NIX_TYPE_STRING:
        raise NixError(WRONG_TYPE)


@final
class Runtime(NamedTuple):
    """Own one live daemon store and flake-aware evaluator."""

    context: object
    store: object
    state: object
    flakes: object

    @classmethod
    def open(cls) -> Self:
        """Open one complete native Nix runtime."""
        with ExitStack() as cleanup:
            context = abi.nix_c_context_create()

            if not context:
                message = "nix_c_context_create failed."
                raise NixError(message)

            _ = cleanup.callback(abi.nix_c_context_free, context)

            initialize(context)

            store = _store(context)
            _ = cleanup.callback(abi.nix_store_free, store)

            evaluator = _state(context, store)
            _ = cleanup.callback(
                abi.nix_flake_settings_free,
                evaluator[1],
            )
            _ = cleanup.callback(
                abi.nix_state_free,
                evaluator[0],
            )

            _ = cleanup.pop_all()

            return cls(
                context,
                store,
                evaluator[0],
                evaluator[1],
            )

    def _physical(
        self,
        native: object,
    ) -> Path:
        """Copy the filesystem location of one borrowed StorePath."""
        receiver = Receiver()

        check(
            self.context,
            abi.nix_store_real_path(
                self.context,
                self.store,
                native,
                receiver.callback,
                None,
            ),
            "nix_store_real_path",
        )

        return Path(receiver.text())

    def _copy(
        self,
        realised: object,
    ) -> Realised:
        """Copy one realised string before its native owner is freed."""
        start = abi.nix_realised_string_get_buffer_start(realised)
        size = abi.nix_realised_string_get_buffer_size(realised)
        paths = [
            self._physical(
                abi.nix_realised_string_get_store_path(
                    realised,
                    index,
                ),
            )
            for index in range(abi.nix_realised_string_get_store_path_count(realised))
        ]

        paths.sort(key=str)

        return (
            ctypes.string_at(start, size).decode(),
            tuple(paths),
        )

    def realise_string(
        self,
        expression: str,
        origin: Path,
    ) -> Realised:
        """Evaluate and realise every store object in one string context."""
        with ExitStack() as cleanup:
            value = _require(
                self.context,
                abi.nix_alloc_value(
                    self.context,
                    self.state,
                ),
                "nix_alloc_value",
            )
            _ = cleanup.callback(
                _decref,
                self.context,
                value,
            )

            _evaluate(
                self.context,
                self.state,
                value,
                expression,
                origin,
            )

            realised = abi.nix_string_realise(
                self.context,
                self.state,
                value,
                APPLICATION_REALISATION,
            )

            if not realised:
                message = error(self.context)
                raise NixError(message)

            _ = cleanup.callback(abi.nix_realised_string_free, realised)

            return self._copy(realised)

    def close(self) -> None:
        """Release evaluator, store, and context in dependency order."""
        abi.nix_state_free(self.state)
        abi.nix_flake_settings_free(self.flakes)
        abi.nix_store_free(self.store)
        abi.nix_c_context_free(self.context)
