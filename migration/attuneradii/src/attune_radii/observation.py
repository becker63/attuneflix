"""Durable replayable model observations."""

import fcntl
import hashlib
import json
import pathlib
import typing

RequestId = typing.NewType("RequestId", str)

type Mode = typing.Literal["replay", "acquire"]

REPLAY: Mode = "replay"
ACQUIRE: Mode = "acquire"

type Acquisition = typing.Callable[[], bytes]
type Observation = tuple[bytes, Mode]
type ObservationPath = pathlib.Path


def identify(value: object) -> RequestId:
    """Return the canonical identity of provider-visible request data."""
    payload = json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
    ).encode()
    hashed = hashlib.sha256(payload)
    return RequestId(hashed.hexdigest())


@typing.final
class ObservationError(RuntimeError):
    """Failure to replay a required durable observation."""


class ObservationStore(typing.Protocol):
    """Capability for durable replayable model observations."""

    def path(
        self,
        identity: RequestId,
    ) -> pathlib.Path:
        """Return the retained location for one observation."""
        ...

    def observe(
        self,
        identity: RequestId,
        mode: Mode,
        acquire: Acquisition,
    ) -> Observation:
        """Replay or atomically acquire one raw observation."""
        ...


@typing.final
class FileObservationStore:
    """Filesystem observations with per-request process coordination."""

    __slots__ = ("root",)

    def __init__(
        self,
        root: pathlib.Path,
    ) -> None:
        """Create one explicit observation directory."""
        self.root = root
        directory = self.root
        directory.mkdir(parents=True, exist_ok=True)

    def path(
        self,
        identity: RequestId,
    ) -> pathlib.Path:
        """Return the retained path for one request identity."""
        return self.root / f"{identity}.json"

    def _read(self, path: pathlib.Path) -> bytes | None:
        """Read one retained observation if it exists."""
        try:
            return path.read_bytes()
        except FileNotFoundError:
            return None

    def observe(
        self,
        identity: RequestId,
        mode: Mode,
        acquire: Acquisition,
    ) -> Observation:
        """Replay or acquire exactly once across cooperating processes."""
        path = self.path(identity)
        payload = self._read(path)

        if payload is not None:
            return payload, REPLAY

        if mode == REPLAY:
            raise ObservationError(str(identity))

        lock = path.with_suffix(".lock")

        with lock.open("a+b") as handle:
            fcntl.flock(handle, fcntl.LOCK_EX)

            payload = self._read(path)
            if payload is None:
                payload = acquire()
                temporary = path.with_suffix(".tmp")
                _ = temporary.write_bytes(payload)
                _ = temporary.replace(path)
                return payload, ACQUIRE

        return payload, REPLAY
