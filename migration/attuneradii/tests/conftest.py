"""Repository-wide quality laws executed by pytest."""

import json
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import cast

import pytest

from attune_radii.grit import Grit

QUALITY_PATHS = ("src", "tests")
SOURCE_PATH, TEST_PATH = QUALITY_PATHS
NIX_PATHS = ("flake.nix", "nix/swe-explore.nix")
ENCODING = "utf-8"

QUALITY_CHECKS: tuple[tuple[str, ...], ...] = (
    ("ruff", "format", "--check", *QUALITY_PATHS),
    ("ruff", "check", *QUALITY_PATHS),
    ("flake8", *QUALITY_PATHS),
    ("fixit", "test", ".tests.test_architecture"),
    ("basedpyright",),
    ("nixfmt", "--check", *NIX_PATHS),
    (
        "cargo",
        "fmt",
        "--check",
        "--manifest-path",
        "native/grit/Cargo.toml",
    ),
    (
        "cargo",
        "clippy",
        "--manifest-path",
        "native/grit/Cargo.toml",
        "--all-targets",
        "--locked",
        "--",
        "--deny",
        "warnings",
    ),
)

GRIT_EXAMPLE = "// @example "
GRIT_END = "// @end"
GRIT_SOURCE_SYNTAX = "// @syntax source"
GRIT_STRUCTURAL_SYNTAX = "// @syntax structural "


@pytest.hookimpl(tryfirst=True)
def pytest_collection_finish(
    session: pytest.Session,
) -> None:
    """Canonicalize worker order immediately before xdist publishes it."""
    session.items.sort(key=lambda item: item.nodeid)


def _run(
    command: tuple[str, ...],
    root: Path,
    *,
    capture: bool = False,
) -> str:
    """Run one pinned quality tool and fail the pytest session on error."""
    executable = shutil.which(command[0])
    if executable is None:
        pytest.exit(f"quality tool is missing: {command[0]}")

    result = subprocess.run(
        (executable, *command[1:]),
        cwd=root,
        check=False,
        capture_output=capture,
        text=True,
    )
    if result.returncode != 0:
        pytest.exit(
            f"{command[0]} failed with exit code {result.returncode}",
            returncode=result.returncode,
        )
    return result.stdout or ""


type _Snapshot = tuple[frozenset[str], frozenset[str], int]


class _RefactorLaw:
    """Own the frozen refactor subset and compression comparison."""

    BASE: str = "87d1137a"
    TARGET: frozenset[str] = frozenset(
        (
            "src/attune_radii/__init__.py",
            "src/attune_radii/world.py",
            "src/attune_radii/nix.py",
            "src/attune_radii/observation.py",
            "src/attune_radii/model.py",
            "src/attune_radii/grit.py",
            "src/attune_radii/routing.py",
            "src/attune_radii/algebra/__init__.py",
            "src/attune_radii/algebra/relation.py",
            "src/attune_radii/algebra/query.py",
            "src/attune_radii/algebra/structure.py",
            "src/attune_radii/policies/__init__.py",
            "src/attune_radii/policies/radii.py",
            "src/attune_radii/policies/repository.py",
            "src/attune_radii/policies/consumer.py",
            "src/attune_radii/policies/convergence.py",
        ),
    )
    FORBIDDEN: frozenset[str] = frozenset(
        (
            "engine",
            "workflow",
            "providers",
            "managers",
        ),
    )

    @classmethod
    def _sources(
        cls,
        root: Path,
        revision: str,
        scope: str,
    ) -> frozenset[str]:
        """Return tracked Python paths in one scope and revision."""
        command = ("jj", "--no-pager", "file", "list", "-r", revision, scope)
        return frozenset(
            line
            for line in _run(command, root, capture=True).splitlines()
            if line.endswith(".py")
        )

    @classmethod
    def _materialize(
        cls,
        root: Path,
        revision: str,
        sources: frozenset[str],
        destination: Path,
    ) -> None:
        """Materialize tracked Python without changing the worktree."""
        for source in sources:
            path = destination / source
            path.parent.mkdir(parents=True, exist_ok=True)
            command = ("jj", "--no-pager", "file", "show", "-r", revision, source)
            _ = path.write_text(
                _run(command, root, capture=True),
                encoding=ENCODING,
            )

    @classmethod
    def _count(
        cls,
        root: Path,
        destination: Path,
    ) -> int:
        """Count executable Python LOC with the pinned pygount tool."""
        command = (
            "pygount",
            "--duplicates",
            "--suffix=py",
            "--format=json",
            str(destination / SOURCE_PATH),
            str(destination / TEST_PATH),
        )
        report = cast(
            "dict[str, dict[str, int]]",
            json.loads(_run(command, root, capture=True)),
        )
        return report["summary"]["totalCodeCount"]

    @classmethod
    def _snapshot(
        cls,
        root: Path,
        revision: str,
    ) -> _Snapshot:
        """Measure tracked Python paths and LOC at one revision."""
        sources = cls._sources(root, revision, SOURCE_PATH)
        tests = cls._sources(root, revision, TEST_PATH)
        with tempfile.TemporaryDirectory(prefix="attune-refactor-") as temporary:
            destination = Path(temporary)
            cls._materialize(root, revision, sources | tests, destination)
            count = cls._count(root, destination)
        return sources, tests, count

    @classmethod
    def _report(
        cls,
        base: _Snapshot,
        current: _Snapshot,
        invalid: frozenset[str],
    ) -> str:
        """Render exact metrics and path sets for a failed law."""
        added = (current[0] | current[1]) - (base[0] | base[1])
        removed = (base[0] | base[1]) - (current[0] | current[1])
        legacy = current[0] - cls.TARGET
        return "; ".join(
            (
                f"LOC {base[2]} -> {current[2]}",
                f"files {len(base[0] | base[1])} -> {len(current[0] | current[1])}",
                f"added={sorted(added)}",
                f"removed={sorted(removed)}",
                f"legacy={sorted(legacy)}",
                f"invalid={sorted(invalid)}",
            )
        )

    @classmethod
    def enforce(cls, root: Path) -> None:
        """Enforce frozen LOC, file-count, and source-layout laws."""
        base = cls._snapshot(root, cls.BASE)
        current = cls._snapshot(root, "@")
        checks = cls._failures(base, current)
        if checks[0]:
            pytest.exit(
                "refactor law failed: "
                + ", ".join(checks[0])
                + "; "
                + cls._report(base, current, checks[1]),
            )

    @classmethod
    def _failures(
        cls,
        base: _Snapshot,
        current: _Snapshot,
    ) -> tuple[tuple[str, ...], frozenset[str]]:
        """Return every failed compression or source-layout condition."""
        invalid = frozenset(
            source
            for source in current[0] - base[0]
            if source not in cls.TARGET
            or cls.FORBIDDEN.intersection(Path(source).parts)
        )
        return (
            tuple(
                message
                for message, passed in (
                    ("LOC increased", current[2] <= base[2]),
                    (
                        "Python file count increased",
                        len(current[0] | current[1]) <= len(base[0] | base[1]),
                    ),
                    ("source layout expanded", not invalid),
                )
                if not passed
            ),
            invalid,
        )


def _grit_example(
    path: Path,
) -> tuple[str, str, bool]:
    """Read and validate one Grit program's documented source example."""
    program = path.read_text(
        encoding=ENCODING,
    )

    parts = (
        program.partition(
            GRIT_EXAMPLE,
        )[2]
        .partition(
            GRIT_END,
        )[0]
        .partition(
            "\n",
        )
    )

    lines = parts[2].splitlines()

    return (
        program,
        "\n".join(line.removeprefix("//").removeprefix(" ") for line in lines).strip(),
        all(
            (
                program.count(GRIT_EXAMPLE) == 1,
                program.count(GRIT_END) == 1,
                bool(parts[0].strip()),
                bool(parts[1]),
                bool(lines),
                all(line.startswith("//") for line in lines),
                program.count(GRIT_SOURCE_SYNTAX)
                + program.count(GRIT_STRUCTURAL_SYNTAX)
                == 1,
                GRIT_SOURCE_SYNTAX not in program
                or any(
                    line.lstrip().startswith(
                        (
                            "`",
                            'js"',
                        ),
                    )
                    for line in program.splitlines()
                ),
                GRIT_STRUCTURAL_SYNTAX not in program
                or any(
                    line.startswith(
                        GRIT_STRUCTURAL_SYNTAX,
                    )
                    and bool(
                        line.removeprefix(
                            GRIT_STRUCTURAL_SYNTAX,
                        ).strip(),
                    )
                    for line in program.splitlines()
                ),
            ),
        ),
    )


def _lint_grit_specs(root: Path) -> None:
    """Require each Grit primitive to explain and execute its semantics."""
    for path in sorted((root / "grit").rglob("*.grit")):
        program, source, documented = _grit_example(
            path,
        )

        if not documented:
            pytest.exit(
                (f"Grit semantic documentation failed: {path.relative_to(root)}."),
            )

        if (
            not Grit()
            .run(
                program,
                path.with_suffix(".ts").as_posix(),
                f"{source}\n",
            )
            .matched
        ):
            pytest.exit(
                f"Grit documented example does not match: {path.relative_to(root)}.",
            )


def _lint_telemetry(root: Path) -> None:
    """Keep all tracked telemetry behind the canonical HTML profile."""
    tests = root / QUALITY_PATHS[1]
    profile = tests / "_profile.py"

    if not profile.is_file():
        pytest.exit("Telemetry renderer tests/_profile.py is missing.")

    if 'PROFILE = Path("profile.html")' not in profile.read_text(
        encoding=ENCODING,
    ):
        pytest.exit("Telemetry must render to root profile.html.")

    markers = (
        "ATTUNE_TELEMETRY",
        "telemetry_case",
        "VmRSS",
        "VmHWM",
        "memray",
    )

    candidates = tuple(
        candidate
        for folder in QUALITY_PATHS
        for candidate in (root / folder).rglob("*.py")
        if candidate
        not in (
            profile,
            tests / "conftest.py",
        )
    )

    offenders = tuple(
        str(candidate.relative_to(root))
        for candidate in candidates
        if any(
            marker
            in candidate.read_text(
                encoding=ENCODING,
            )
            for marker in markers
        )
    )

    if offenders:
        pytest.exit(
            f"Telemetry must flow through tests/_profile.py; found {list(offenders)}.",
        )


def pytest_sessionstart(session: pytest.Session) -> None:
    """Enforce repository quality laws once, before scientific tests run."""
    if hasattr(session.config, "workerinput"):
        return

    root = session.config.rootpath

    _lint_telemetry(root)
    _lint_grit_specs(root)
    _RefactorLaw.enforce(root)

    for command in QUALITY_CHECKS:
        _ = _run(command, root)

    tracked = _run(
        (
            "jj",
            "--no-pager",
            "file",
            "list",
            "-r",
            "@",
            "src",
        ),
        root,
        capture=True,
    )

    _ = _run(
        (
            "fixit",
            "lint",
            *(source for source in tracked.splitlines() if source.endswith(".py")),
        ),
        root,
    )

    _ = _run(("interrogate", *QUALITY_PATHS), root)
