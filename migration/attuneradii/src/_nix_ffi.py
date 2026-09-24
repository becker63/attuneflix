"""Adapt the generated ctypes ABI into small typed native primitives."""

import ctypes
from contextlib import ExitStack
from typing import NamedTuple, final

import _attune_nix_abi as abi


class NixError(RuntimeError):
    """Raised when the native Nix API reports an error."""


class _CString(NamedTuple):
    """Keep native UTF-8 storage alive beside its pointer."""

    storage: object
    pointer: object


@final
class Receiver:
    """Collect one synchronous callback-owned Nix string."""

    __slots__ = ("callback", "pieces")

    def __init__(self) -> None:
        """Create a callback whose storage lives with this receiver."""
        self.pieces: list[bytes] = []
        self.callback = abi.nix_get_string_callback(self)

    def __call__(
        self,
        start: ctypes.c_void_p,
        length: int,
        _user_data: ctypes.c_void_p,
    ) -> None:
        """Copy borrowed native bytes before the callback returns."""
        self.pieces.append(
            ctypes.string_at(
                start,
                length,
            ),
        )

    def text(self) -> str:
        """Decode all callback fragments as UTF-8."""
        content = b"".join(self.pieces)
        return content.decode("utf-8", errors="replace")


def cstring(value: str) -> _CString:
    """Encode one Python string for the generated Nix ABI."""
    encoded = value.encode() + b"\0"
    storage: object = ctypes.create_string_buffer(encoded)
    pointer: object = ctypes.cast(
        storage,
        ctypes.POINTER(ctypes.c_ubyte),
    )
    return _CString(storage, pointer)


def error(context: object) -> str:
    """Read the current error from one Nix context."""
    with ExitStack() as cleanup:
        scratch = abi.nix_c_context_create()

        if not scratch:
            return "Nix error details unavailable."

        _ = cleanup.callback(abi.nix_c_context_free, scratch)

        receiver = Receiver()

        status = abi.nix_err_info_msg(
            scratch,
            context,
            receiver.callback,
            None,
        )

        if status:
            return f"Nix error details failed with code {status}."

        return receiver.text()


def check(
    context: object,
    status: int,
    operation: str,
) -> None:
    """Raise when one native Nix operation fails."""
    if not status:
        return

    detail = error(context)
    message = f"{operation} failed with code {status}: {detail}"
    raise NixError(message)


def initialize(context: object) -> None:
    """Initialize native Nix libraries in dependency order."""
    check(
        context,
        abi.nix_libutil_init(context),
        "nix_libutil_init",
    )
    check(
        context,
        abi.nix_libstore_init(context),
        "nix_libstore_init",
    )
    check(
        context,
        abi.nix_libexpr_init(context),
        "nix_libexpr_init",
    )
