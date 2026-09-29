#!/usr/bin/env python3
"""Run the existing per-world Bazel acquisition launchers one pass at a time.

This is an operator for live, non-hermetic acquisition. It does not derive
scientific tables: each launcher invokes the Families Flix tool, and recorded
evidence becomes declared inputs to the subsequent Bazel graph.
"""

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from seal_evidence import main as seal_evidence


ROOT = Path(__file__).resolve().parents[2]
POPULATION = Path(__file__).with_name("acquisition_population.json")
CAP_USD = 5.0
MIN_FREE_GIB = 5
MIN_AVAILABLE_GIB = 4
PARALLEL_AVAILABLE_GIB = 8.5
# Retained request identities make a restarted transport attempt keyless for
# already recorded exchanges. Wait out short provider outages before giving up.
RETRY_DELAYS_SECONDS = (5, 10, 20, 40, 60, 60, 60)
TRANSIENT_PROVIDER_ERRORS = (
    "java.net.ConnectException",
    "java.net.SocketTimeoutException",
    "java.net.http.HttpTimeoutException",
    "Received RST_STREAM",
    "Connection reset",
    "GOAWAY",
)
TABLES = (
    ("families-embeddings-v1", "documents.parquet"),
    ("families-embeddings-v1", "batches.parquet"),
    ("families-embeddings-v1", "ledger.parquet"),
    ("jev-families-raw-v1", "decisions.parquet"),
    ("jev-families-raw-v1", "outcomes.parquet"),
    ("jev-families-raw-v1", "ledger.parquet"),
)


def available_gib() -> float:
    for line in Path("/proc/meminfo").read_text().splitlines():
        if line.startswith("MemAvailable:"):
            return int(line.split()[1]) / 1024**2
    raise RuntimeError("cannot read available memory")


def guard_resources() -> None:
    free = shutil.disk_usage(ROOT).free / 1024**3
    memory = available_gib()
    if free < MIN_FREE_GIB or memory < MIN_AVAILABLE_GIB:
        raise RuntimeError(f"resource stop: disk={free:.1f} GiB free, memory={memory:.1f} GiB available")


def credential() -> str:
    value = os.environ.get("OPENROUTER_API_KEY", "")
    if value:
        return value
    for line in (ROOT / ".env").read_text().splitlines():
        if line.startswith("OPENROUTER_API_KEY="):
            return line.partition("=")[2].strip().strip('"').strip("'")
    raise RuntimeError("OPENROUTER_API_KEY is absent")


def complete(digest: str) -> bool:
    return all((ROOT / ".attune" / space / digest / name).is_file() for space, name in TABLES)


def launcher(digest: str, script: Path, output_base: Path | None) -> None:
    target = f"//experiments/atlas-families:acquire_world_{digest}"
    command = ["bazel"]
    if output_base is not None:
        command.append(f"--output_base={output_base}")
    command += [
        "run", "--config=buildbuddy-rbe-arm64", "--spawn_strategy=remote",
        "--jobs=4", f"--script_path={script}", target,
    ]
    subprocess.run(command, cwd=ROOT, check=True)


def built_launchers(rows: list[dict], output_base: Path) -> dict[str, Path]:
    """Build every launcher in one Bazel invocation before live calls begin."""
    targets = [f"//experiments/atlas-families:acquire_world_{row['digest']}" for row in rows]
    subprocess.run([
        "bazel", f"--output_base={output_base}", "build",
        "--config=buildbuddy-rbe-arm64", "--spawn_strategy=remote",
        "--jobs=256", *targets,
    ], cwd=ROOT, check=True)
    bin_dir = output_base / "execroot/_main/bazel-out/aarch64-fastbuild/bin/experiments/atlas-families"
    scripts = {row["digest"]: bin_dir / f"acquire_world_{row['digest']}.sh" for row in rows}
    missing = [str(script) for script in scripts.values() if not script.is_file()]
    if missing:
        raise RuntimeError(f"Bazel did not produce {len(missing)} acquisition launchers: {missing[:2]}")
    # Live launchers use their runfiles directly. Release the Bazel server's
    # memory before starting a second JVM on this no-swap desktop.
    subprocess.run(["bazel", f"--output_base={output_base}", "shutdown"], cwd=ROOT, check=True)
    return scripts


def project(script: Path, source: Path) -> tuple[float, int, int]:
    env = dict(os.environ, ATTUNE_WORKSPACE=str(ROOT))
    result = subprocess.run([str(script), str(source), "project"], cwd=ROOT,
                            env=env, check=True, text=True, capture_output=True)
    match = re.search(r"projected_usd=([0-9.eE+-]+) envelope_usd=([0-9.eE+-]+)", result.stdout)
    if match is None:
        raise RuntimeError(f"projection output has no cost bound: {result.stdout[-1000:]}")
    if float(match.group(2)) != CAP_USD:
        raise RuntimeError("launcher does not use the approved $5 pass cap")
    print(result.stdout.strip(), flush=True)
    seeds = re.search(r"\bseeds=([0-9]+)\b", result.stdout)
    bounded = re.search(r"\bbounded_seeds=([0-9]+)\b", result.stdout)
    if seeds is None or bounded is None or int(bounded.group(1)) <= 0:
        raise RuntimeError("projection output has no original seed count or bounded pass size")
    return float(match.group(1)), int(seeds.group(1)), int(bounded.group(1))


def retry_transport(error_text: str, digest: str, kind: str, attempt: int) -> None:
    """Retry only transient provider failures; report a key-free failure class."""
    marker = next((part for part in TRANSIENT_PROVIDER_ERRORS if part in error_text), None)
    provider_status = re.search(r"\bhttp-(408|429|5[0-9]{2})\b", error_text)
    if marker is None and provider_status is not None:
        marker = provider_status.group(0)
    if marker is None:
        classification = re.search(r"\bhttp-[0-9]{3}\b", error_text)
        if classification is None:
            classification = re.search(
                r"\b(?:No space left on device|OutOfMemoryError|[A-Za-z]+Exception)\b",
                error_text,
            )
        failure = classification.group(0) if classification is not None else "unknown"
        raise RuntimeError(f"{kind} pass failed for {digest}: non-transient launcher error ({failure})")
    if attempt > len(RETRY_DELAYS_SECONDS):
        raise RuntimeError(f"{kind} pass failed for {digest}: {marker} after {attempt} attempts")
    delay = RETRY_DELAYS_SECONDS[attempt - 1]
    print(f"RETRY {digest} {kind} transport={marker} attempt={attempt + 1} after={delay}s; retained exchanges reused", flush=True)
    time.sleep(delay)


def bounded_pass(script: Path, source: Path, digest: str, kind: str,
                 start: int | None = None, count: int | None = None) -> None:
    space = "families-embeddings-v1" if kind == "embeddings" else "jev-families-raw-v1"
    name = "embeddings.json" if kind == "embeddings" else f"decisions-{start:06d}-{start + count:06d}.json"
    ledger = ROOT / ".attune" / space / digest / "passes" / name
    if ledger.exists():
        existing = json.loads(ledger.read_text())
        if (existing.get("protocol") != "atlas-families-bounded-pass-v1"
                or existing.get("snapshot_digest") != digest
                or existing.get("kind") != kind
                or existing.get("start") != start
                or existing.get("count") != count
                or existing.get("cap_usd") != CAP_USD):
            raise RuntimeError(f"retained pass ledger disagrees with {name}")
        print(f"SKIP recorded pass {digest} {name}", flush=True)
        return
    guard_resources()
    command = "prefill-embeddings" if kind == "embeddings" else "prefill-decisions"
    args = [str(script), str(source), command]
    if start is not None:
        args += [str(start), str(count)]
    env = dict(os.environ, ATTUNE_WORKSPACE=str(ROOT), OPENROUTER_API_KEY=credential())
    summary = None
    for attempt in range(1, len(RETRY_DELAYS_SECONDS) + 2):
        guard_resources()
        summary = None
        with tempfile.TemporaryFile(mode="w+") as errors:
            with subprocess.Popen(args, cwd=ROOT, env=env, text=True, bufsize=1,
                                  stdout=subprocess.PIPE, stderr=errors) as process:
                assert process.stdout is not None
                for line in process.stdout:
                    print(line, end="", flush=True)
                    if line.startswith("ATLAS_FAMILIES_PREFILL_"):
                        summary = re.search(
                            r"acquired=([0-9]+) recorded=([0-9]+) spent_usd=([0-9.eE+-]+) reported_usd=([0-9.eE+-]+)",
                            line,
                        )
                status = process.wait()
            if status == 0:
                break
            errors.seek(0)
            retry_transport(errors.read(), digest, f"bounded {kind} seed={start}", attempt)
    if summary is None:
        raise RuntimeError(f"bounded {kind} pass returned without cost statistics")
    # The successful attempt's `spent` covers only its new calls; `reported`
    # includes retained responses from earlier failed attempts as well. The
    # pass ledger must reflect the whole bounded pass, not only its last try.
    newly_acquired_usd = float(summary.group(3))
    reported_usd = float(summary.group(4))
    if newly_acquired_usd > reported_usd + 1e-9:
        raise RuntimeError(f"bounded {kind} pass has more new spend than recorded provider cost")
    evidence = {
        "protocol": "atlas-families-bounded-pass-v1",
        "snapshot_digest": digest,
        "kind": kind,
        "start": start,
        "count": count,
        "cap_usd": CAP_USD,
        "acquired": int(summary.group(1)),
        "recorded": int(summary.group(2)),
        "spent_usd": reported_usd,
        "reported_usd": reported_usd,
    }
    if evidence["spent_usd"] > CAP_USD or evidence["reported_usd"] > CAP_USD:
        raise RuntimeError(f"bounded {kind} pass exceeded the approved envelope")
    ledger.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=ledger.parent,
                                     prefix=".pass-", delete=False) as staging:
        json.dump(evidence, staging, sort_keys=True, separators=(",", ":"))
        staging.write("\n")
        temporary = staging.name
    os.replace(temporary, ledger)


def acquire_bounded(script: Path, source: Path, digest: str, seeds: int, bounded_seeds: int) -> None:
    bounded_pass(script, source, digest, "embeddings")
    for start in range(0, seeds, bounded_seeds):
        bounded_pass(script, source, digest, "decisions", start, min(bounded_seeds, seeds - start))
    guard_resources()
    env = dict(os.environ, ATTUNE_WORKSPACE=str(ROOT))
    env.pop("OPENROUTER_API_KEY", None)
    subprocess.run([str(script), str(source), "materialize"], cwd=ROOT, env=env, check=True)


def acquire_under_cap(script: Path, source: Path, digest: str) -> None:
    """Resume retained exchanges after a transient live-provider failure."""
    env = dict(os.environ, ATTUNE_WORKSPACE=str(ROOT), OPENROUTER_API_KEY=credential())
    for attempt in range(1, len(RETRY_DELAYS_SECONDS) + 2):
        guard_resources()
        with tempfile.TemporaryFile(mode="w+") as errors:
            status = subprocess.run([str(script), str(source), "acquire"], cwd=ROOT, env=env,
                                    stderr=errors).returncode
            if status == 0:
                return
            errors.seek(0)
            retry_transport(errors.read(), digest, "live", attempt)


def acquire_row(row: dict, script: Path, run: bool) -> bool:
    """Acquire one independent snapshot; sealing stays with the caller."""
    digest = row["digest"]
    guard_resources()
    source = ROOT / row["source_root_hint"]
    if not source.is_dir():
        raise RuntimeError(f"retained source root missing for {digest}: {source}")
    bound, seeds, bounded_seeds = project(script, source)
    if bound > CAP_USD:
        print(f"BOUNDED {digest} live whole-world projection ${bound:.3f} exceeds ${CAP_USD:.2f} per pass", flush=True)
    if not run:
        return False
    if bound > CAP_USD:
        print(f"ACQUIRE_BOUNDED {digest} {row['repository']} seeds={seeds}", flush=True)
        acquire_bounded(script, source, digest, seeds, bounded_seeds)
    else:
        print(f"ACQUIRE {digest} {row['repository']} projected_usd={bound:.4f}", flush=True)
        acquire_under_cap(script, source, digest)
    if not complete(digest):
        raise RuntimeError(f"acquisition returned without all six typed tables for {digest}")
    print(f"COMPLETE {digest}", flush=True)
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true", help="invoke the provider for under-cap worlds")
    parser.add_argument("--digest", help="select one snapshot digest")
    parser.add_argument("--repository", help="select one repository name")
    parser.add_argument("--max-worlds", type=int, help="bound this invocation's acquisitions")
    parser.add_argument("--workers", type=int, choices=(1, 2), default=1,
                        help="independent live JVMs; two require at least 8.5 GiB available memory")
    parser.add_argument("--output-base", type=Path,
                        help="separate Bazel output base for a safely concurrent remote build")
    args = parser.parse_args()
    population = json.loads(POPULATION.read_text())
    if population["protocol"] != "atlas-families-acquisition-population-v1" or population["cap_usd"] != CAP_USD:
        raise RuntimeError("acquisition population protocol or pass cap drifted")
    worlds = population["worlds"]
    if len(worlds) != 78 or len({row["digest"] for row in worlds}) != 78:
        raise RuntimeError("acquisition population does not cover 78 unique snapshots")
    selected = [row for row in worlds
                if (args.digest is None or row["digest"] == args.digest)
                and (args.repository is None or row["repository"] == args.repository)]
    selected.sort(key=lambda row: (row["projected_usd"], row["digest"]))
    if not selected:
        raise RuntimeError("no snapshot matched the requested selection")
    if args.workers == 2:
        if args.output_base is None:
            raise RuntimeError("two workers require a dedicated --output-base")
        pending = [row for row in selected if not complete(row["digest"])]
        if args.max_worlds is not None:
            pending = pending[:args.max_worlds]
        if not pending:
            print("completed_new_worlds=0", flush=True)
            return 0
        guard_resources()
        scripts = built_launchers(pending, args.output_base)
        acquired = 0
        for offset in range(0, len(pending), 2):
            pair = pending[offset:offset + 2]
            # Wait for both live passes before sealing. A concurrent pass may
            # have created its final table path but not finished writing it.
            if len(pair) == 2 and available_gib() < PARALLEL_AVAILABLE_GIB:
                print(f"RESOURCE serial fallback: available={available_gib():.1f} GiB", flush=True)
                for row in pair:
                    acquired += int(acquire_row(row, scripts[row["digest"]], args.run))
                    if args.run:
                        seal_evidence()
            else:
                with ThreadPoolExecutor(max_workers=len(pair)) as pool:
                    futures = {pool.submit(acquire_row, row, scripts[row["digest"]], args.run): row
                               for row in pair}
                    results = []
                    errors = []
                    for future in as_completed(futures):
                        row = futures[future]
                        try:
                            results.append(future.result())
                        except Exception as error:
                            errors.append(error)
                            print(f"PASS_ERROR {row['digest']} {type(error).__name__}: {error}", flush=True)
                if args.run:
                    seal_evidence()
                acquired += sum(results)
                if errors:
                    raise RuntimeError(f"{len(errors)} concurrent pass(es) failed: {errors[0]}")
            print(f"sealed_worlds={len([row for row in worlds if complete(row['digest'])])}", flush=True)
        print(f"completed_new_worlds={acquired}", flush=True)
        return 0
    acquired = 0
    with tempfile.TemporaryDirectory(prefix="atlas-families-acquire-") as directory:
        for row in selected:
            digest = row["digest"]
            if complete(digest):
                print(f"SKIP {digest} complete", flush=True)
                continue
            if row["projected_usd"] > CAP_USD and not args.run:
                print(f"DEFER {digest} conservative projection ${row['projected_usd']:.3f} exceeds ${CAP_USD:.2f}; use --run for bounded passes", flush=True)
                continue
            guard_resources()
            source = ROOT / row["source_root_hint"]
            # The hint is a retained Nix-store symlink, never a new
            # scientific identity or a path supplied by a provider.
            if not source.is_dir():
                raise RuntimeError(f"retained source root missing for {digest}: {source}")
            script = Path(directory) / f"acquire_{digest}.sh"
            launcher(digest, script, args.output_base)
            bound, seeds, bounded_seeds = project(script, source)
            if bound > CAP_USD:
                print(f"BOUNDED {digest} live whole-world projection ${bound:.3f} exceeds ${CAP_USD:.2f} per pass", flush=True)
            if not args.run:
                continue
            if bound > CAP_USD:
                print(f"ACQUIRE_BOUNDED {digest} {row['repository']} seeds={seeds}", flush=True)
                acquire_bounded(script, source, digest, seeds, bounded_seeds)
            else:
                print(f"ACQUIRE {digest} {row['repository']} projected_usd={bound:.4f}", flush=True)
                acquire_under_cap(script, source, digest)
            if not complete(digest):
                raise RuntimeError(f"acquisition returned without all six typed tables for {digest}")
            seal_evidence()
            acquired += 1
            if args.max_worlds is not None and acquired >= args.max_worlds:
                break
    print(f"completed_new_worlds={acquired}", flush=True)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, subprocess.CalledProcessError) as error:
        print(f"acquisition stopped: {error}", file=sys.stderr)
        sys.exit(1)
