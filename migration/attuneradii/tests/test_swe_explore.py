"""Laws and staged measurements for the pinned SWE-Explore Atlas."""

import json
import os
import time
import typing
from pathlib import Path

import effect_py as effects
import pytest
import rote

from attune_radii import nix, routing, world
from attune_radii.grit import SOURCE_SUFFIXES

ROOT = Path.cwd()
RUN = os.environ.get("ATTUNE_RUN", "")
OUTPUT = ROOT / ".attune" / "atlas" / "swe-explore-tsjs-v1"
PROGRAMS = tuple(
    (path.stem, path.read_text(encoding="utf-8"))
    for path in sorted((ROOT / "grit" / "typescript").glob("*.grit"))
)

type SourcePath = tuple[str, Path]
type FactTask = tuple[int, str, str, int, tuple[SourcePath, ...]]


def _cases() -> tuple[nix.ExploreCase, ...]:
    """Realise the immutable benchmark and snapshots through Nix FFI."""
    return effects.run_sync(
        nix.swe_explore(origin=ROOT).pipe(effects.provide(nix.live)).or_die(),
    )


def _delta(after: "rote.Stats", before: "rote.Stats") -> dict[str, int]:
    """Return externally observed Rote counter changes."""
    return {
        "hits": after["hits"] - before["hits"],
        "misses": after["misses"] - before["misses"],
    }


def _write(path: Path, payload: object) -> None:
    """Atomically persist one externally observed measurement."""
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(f".{os.getpid()}.tmp")
    _ = temporary.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    _ = temporary.replace(path)


def _sources(case: nix.ExploreCase) -> tuple[SourcePath, ...]:
    """Admit source paths using narrow repository-authored evidence."""
    result: list[SourcePath] = []
    for path in sorted(case.snapshot.rglob("*")):
        relative = path.relative_to(case.snapshot).as_posix()
        excluded = any(
            relative == prefix or relative.startswith(prefix + "/")
            for prefix in case.exclusions()
        )
        if path.is_file() and path.suffix in SOURCE_SUFFIXES and not excluded:
            result.append((relative, path))
    return tuple(result)


def _tasks(cases: tuple[nix.ExploreCase, ...]) -> tuple[FactTask, ...]:
    """Build stable semantic shards without coupling repository revisions."""
    tasks: list[FactTask] = []
    for case_index, case in enumerate(cases):
        buckets: list[list[SourcePath]] = [[] for _ in range(world.FACT_BUCKETS)]
        for source in _sources(case):
            buckets[sum(map(ord, source[0])) % world.FACT_BUCKETS].append(source)
        tasks.extend(
            (case_index, name, program, bucket, tuple(paths))
            for name, program in PROGRAMS
            for bucket, paths in enumerate(buckets)
            if paths
        )
    return tuple(tasks)


def _fact(task: FactTask) -> None:
    """Measure one pure durable Grit shard from outside its cache boundary."""
    case_index = task[0]
    name = task[1]
    program = task[2]
    bucket = task[3]
    paths = task[4]
    case = CASES[case_index]
    filename = "-".join((format(case_index, "02d"), name, format(bucket, "02d")))
    filename += ".json"
    destination = OUTPUT / RUN / filename
    if destination.exists():
        return
    worker = os.environ.get("PYTEST_XDIST_WORKER", "master")
    identity = {
        "instance": case.instance_id,
        "repository": case.repository,
        "revision": case.base_commit,
        "primitive": name,
        "bucket": bucket,
    }
    active = OUTPUT / "active" / f"{RUN}-{worker}.json"
    _write(active, {"identity": identity, "sources": [path for path, _ in paths]})
    batch = tuple((relative, path.read_text()) for relative, path in paths)
    before = rote.stats()
    started = time.perf_counter()
    facts = typing.cast(
        "list[object]",
        json.loads(world.fact_payload(program, batch)),
    )
    elapsed = time.perf_counter() - started
    _write(
        destination,
        {
            "identity": identity,
            "sources": len(batch),
            "source_bytes": sum(len(content.encode()) for _, content in batch),
            "facts": len(facts),
            "reuse": _delta(rote.stats(), before),
            "seconds": elapsed,
        },
    )
    active.unlink(missing_ok=True)


def _threshold(value: routing.ThresholdFractions) -> dict[str, float]:
    """Encode the locked Atlas density thresholds."""
    return {"25": value.at_25, "50": value.at_50, "90": value.at_90}


def _relation(value: routing.RelationSignature) -> dict[str, object]:
    """Encode one directed primitive signature."""
    return {
        "median_density": value.median_density,
        "p90_density": value.p90_density,
        "outputs": _threshold(value.output_fraction),
        "crossings": _threshold(value.crossing_fraction),
        "extinction_fraction": value.extinction_fraction,
    }


def _atlas(case: nix.ExploreCase) -> None:
    """Measure one issue-blind depth-seven repository Atlas."""
    before = rote.stats()
    started = time.perf_counter()
    atlas = world.Atlas.build(case.snapshot, exclude=case.exclusions())
    build_seconds = time.perf_counter() - started
    memo: routing.TransitionMemo = {}
    started = time.perf_counter()
    steps, symbol_programs = routing.search(
        atlas.relations,
        routing.issue_blind(atlas.symbols),
        routing.DEFAULT_DEPTH,
        memo,
    )
    route_seconds = time.perf_counter() - started
    relations = {
        atom[0]: _relation(routing.RelationSignature.from_steps(steps, atom[0]))
        for atom in routing.ATOMS
    }
    identity = dict(
        zip(
            ("instance", "repository", "revision", "language"),
            case[:4],
            strict=True,
        ),
    ) | {"snapshot": str(case.snapshot)}
    payload = {
        "identity": identity,
        "admission": {
            "excluded_prefixes": case.exclusions(),
            "files": len(atlas.files),
            "symbols": len(atlas.symbols),
        },
        "relations": {
            "defines": len(atlas.relations.defines),
            "imports": len(atlas.relations.imports),
            "calls": len(atlas.relations.calls),
            "parent": len(atlas.relations.parent),
        },
        "evidence": {
            name: value.encode()
            for name, value in zip(
                ("definitions", "imports", "calls"), atlas.evidence, strict=True
            )
        },
        "atlas": {
            "logical_programs": len(steps),
            "symbol_programs": symbol_programs,
            "relations": relations,
            "physical_transitions": len(memo),
            "physical_input_members": sum(len(frontier) for _, frontier in memo),
            "physical_output_members": sum(map(len, memo.values())),
        },
        "reuse": _delta(rote.stats(), before),
        "timing_seconds": {
            "total": build_seconds + route_seconds,
        },
    }
    index = CASES.index(case)
    filename = format(index, "02d") + ".json"
    _write(OUTPUT / RUN / filename, payload)
    assert (len(steps), symbol_programs) == (3279, 1643)


def test_nix_effect_preserves_types_and_failures() -> None:
    """Nix realization remains typed until the pytest execution boundary."""
    pending = nix.realise("42").pipe(effects.provide(nix.live))
    _ = typing.assert_type(
        pending,
        effects.Effect[nix.RealisedString, nix.NixError, typing.Never],
    )
    assert isinstance(effects.run_sync_exit(pending), effects.Failure)


def test_swe_explore_atlas() -> None:
    """The official Axios snapshot retains fixed structural semantics."""
    cases = _cases()
    axios = next(case for case in cases if case.instance_id == "axios__axios-4731")
    atlas = world.Atlas.build(axios.snapshot)
    signature = routing.structural_signature(
        atlas.relations,
        routing.issue_blind(atlas.symbols),
        depth=7,
    )
    assert (len(cases), len({case.repository for case in cases})) == (32, 11)
    assert (
        len(atlas.files),
        len(atlas.symbols),
        len(atlas.relations.imports),
        len(atlas.relations.calls),
        signature.logical_programs,
        signature.symbol_programs,
    ) == (114, 295, 140, 220, 3279, 1643)


CASES = _cases() if RUN in {"cold-facts", "warm-facts", "cold", "warm"} else ()
if RUN.endswith("-facts"):
    TASKS = _tasks(CASES)
    test_swe_measurement = pytest.mark.parametrize("task", TASKS)(_fact)
elif RUN in {"cold", "warm"}:
    test_swe_measurement = pytest.mark.parametrize("case", CASES)(_atlas)
