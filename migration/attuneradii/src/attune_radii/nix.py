"""Typed Effect access to immutable Nix inputs."""

import functools
import json
import pathlib
import types
import typing

import effect_py as effects

import _nix_ffi as ffi
import _nix_native as native

NixError = ffi.NixError
NixPath = typing.NewType("NixPath", pathlib.Path)
INCOMPLETE_NIX_IDENTITY = "Nix did not realise the complete SWE-Explore identity."
SOURCE_EXCLUSIONS = types.MappingProxyType(
    {
        "babel/babel": (".yarn/plugins", "packages/babel-parser/test/fixtures"),
        "facebook/docusaurus": ("jest/vendor",),
        "mrdoob/three.js": (
            "build",
            "editor/js/libs",
            "examples/jsm/libs",
            "examples/jsm/lights/RectAreaLightUniformsLib.js",
            "playground/libs",
        ),
        "protonmail/webclients": (
            "applications/drive/public/assets/sandbox.js",
            "applications/mail/public/assets/sandbox.js",
        ),
        "tutao/tutanota": (
            "libs",
            "packages/tutanota-crypto/lib/internal/crypto-jsbn-2012-08-09_1.js",
        ),
    },
)

type Finalizer = effects.Effect[object, typing.Never, typing.Never]
type RealisedString = tuple[str, tuple[NixPath, ...]]


class ExploreCase(typing.NamedTuple):
    """One issue-blind SWE-Explore repository identity realised by Nix."""

    instance_id: str
    repository: str
    base_commit: str
    language: str
    benchmark: NixPath
    snapshot: NixPath

    def exclusions(self) -> tuple[str, ...]:
        """Return repository-authored generated and vendor source prefixes."""
        return SOURCE_EXCLUSIONS.get(self.repository, ())

    @classmethod
    def decode(
        cls,
        payload: RealisedString,
    ) -> tuple["ExploreCase", ...]:
        """Decode and validate the realised Nix-owned case population."""
        manifest = typing.cast(
            "dict[str, object]",
            json.loads(payload[0]),
        )
        benchmark = NixPath(
            pathlib.Path(
                typing.cast("str", manifest["benchmark"]),
            ),
        )
        cases = tuple(
            cls(
                record["instanceId"],
                record["repository"],
                record["baseCommit"],
                record["language"],
                benchmark,
                NixPath(pathlib.Path(record["snapshot"])),
            )
            for record in typing.cast(
                "list[dict[str, str]]",
                manifest["cases"],
            )
        )
        paths = (
            benchmark,
            *(case.snapshot for case in cases),
        )
        realised = frozenset(payload[1])
        if frozenset(paths) != realised:
            raise NixError(INCOMPLETE_NIX_IDENTITY)
        return cases


class Nix(typing.Protocol):
    """Capability for realising immutable Nix inputs."""

    def realise_string(
        self,
        expression: str,
        origin: pathlib.Path,
    ) -> RealisedString:
        """Realise one Nix string and its store context."""
        ...


@typing.final
class _LiveNix:
    """Native implementation of the Nix capability."""

    __slots__ = ("_runtime",)

    def __init__(self) -> None:
        """Open one native runtime."""
        self._runtime = native.Runtime.open()

    def realise_string(
        self,
        expression: str,
        origin: pathlib.Path,
    ) -> RealisedString:
        """Realise and brand one immutable Nix string."""
        text, paths = self._runtime.realise_string(
            expression,
            origin,
        )
        realised = map(NixPath, paths)
        return text, tuple(realised)

    def close(self) -> None:
        """Release the native runtime."""
        self._runtime.close()

    def release(
        self,
        _exit: effects.Exit[object, object],
    ) -> Finalizer:
        """Release one scoped native Nix service."""
        return effects.sync(self.close)


def _catch_nix(exception: Exception) -> NixError:
    """Keep expected Nix failures in the typed error channel."""
    if isinstance(exception, NixError):
        return exception

    raise exception


@effects.fn("nix.realise")
def realise(
    expression: str,
    *,
    origin: pathlib.Path | None = None,
) -> effects.EffectGen[RealisedString, NixError, Nix]:
    """Realise one immutable input through the Nix capability."""
    nix = yield from effects.service(Nix)

    invoke = functools.partial(
        nix.realise_string,
        expression,
        origin or pathlib.Path.cwd(),
    )

    return (
        yield from effects.try_(
            invoke,
            _catch_nix,
        )
    )


@effects.fn("nix.swe_explore")
def swe_explore(
    *,
    origin: pathlib.Path | None = None,
) -> effects.EffectGen[
    tuple[ExploreCase, ...],
    NixError,
    Nix,
]:
    """Realise the pinned issue-blind SWE-Explore source population."""
    payload = yield from realise(
        "import ./nix/swe-explore.nix",
        origin=origin,
    )
    return ExploreCase.decode(payload)


live = effects.layer.effect(
    Nix,
    effects.acquire_release(
        effects.try_(
            _LiveNix,
            _catch_nix,
        ),
        _LiveNix.release,
    ),
)
