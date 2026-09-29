#!/usr/bin/env python3
"""Index and hydrate Bazel-produced Families evidence archives in BuildBuddy.

The index contains only one SHA-256 and size per snapshot. The archived raw
provider envelopes and six typed tables are action outputs in BuildBuddy's CAS;
hydration restores declared Bazel inputs without invoking a provider. BuildBuddy
is a cache and may evict blobs, so keep the acquired local evidence until a
separate durable retention policy is agreed.
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
ADDRESS_PROTOCOL = "atlas-families-evidence-address-v1"
INDEX_PROTOCOL = "atlas-families-evidence-cas-index-v1"
DIGEST = re.compile(r"[0-9a-f]{64}\Z")
SPACES = {
    "families-embeddings-v1": {"documents.parquet", "batches.parquet", "ledger.parquet"},
    "jev-families-raw-v1": {"decisions.parquet", "outcomes.parquet", "ledger.parquet"},
}


def require_digest(value: str) -> str:
    if not DIGEST.fullmatch(value):
        raise ValueError("invalid snapshot or blob digest")
    return value


def address(data: object) -> dict:
    if not isinstance(data, dict) or data.get("protocol") != ADDRESS_PROTOCOL:
        raise ValueError("unknown evidence address protocol")
    digest = require_digest(data.get("snapshot_digest", ""))
    sha256 = require_digest(data.get("sha256", ""))
    size = data.get("size_bytes")
    if type(size) is not int or size <= 0:
        raise ValueError(f"invalid archive size for {digest}")
    return {"snapshot_digest": digest, "sha256": sha256, "size_bytes": size}


def build_index(addresses: Path, output: Path, expected_worlds: int | None) -> None:
    rows = {}
    for file in addresses.glob("*/evidence-address.json"):
        row = address(json.loads(file.read_text()))
        digest = row["snapshot_digest"]
        if file.parent.name != digest or digest in rows:
            raise ValueError(f"duplicate or mislocated evidence address: {file}")
        rows[digest] = row
    if not rows or (expected_worlds is not None and len(rows) != expected_worlds):
        raise ValueError(f"found {len(rows)} evidence addresses; expected {expected_worlds}")
    if expected_worlds == 78:
        population = json.loads((REPO / "experiments/atlas-families/acquisition_population.json").read_text())
        if set(rows) != {row["digest"] for row in population["worlds"]}:
            raise ValueError("evidence addresses differ from the 78-snapshot population")
    result = {"protocol": INDEX_PROTOCOL, "worlds": [rows[digest] for digest in sorted(rows)]}
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=output.parent, prefix=".evidence-index-", delete=False) as staging:
        json.dump(result, staging, indent=2)
        staging.write("\n")
        temporary = Path(staging.name)
    os.replace(temporary, output)
    print(f"indexed_evidence_worlds={len(rows)} output={output}")


def credential() -> str:
    key = os.environ.get("BUILDBUDDY_API_KEY", "")
    if key:
        return key
    for line in (REPO / ".env").read_text().splitlines():
        if line.startswith("BUILDBUDDY_API_KEY="):
            return line.partition("=")[2].strip().strip('"').strip("'")
    raise ValueError("BUILDBUDDY_API_KEY is absent")


def fetch_archive(row: dict, key: str, *, hydrating: bool = False):
    free = shutil.disk_usage(REPO).free
    # Verification holds only one compressed archive in a temporary file.
    # Hydration also writes missing evidence and keeps the stronger guard.
    needed = 5 * 1024**3 if hydrating else max(2 * 1024**3, row["size_bytes"] + 1024**3)
    if free < needed:
        raise ValueError(f"disk guard: need {needed / 1024**3:.1f} GiB free before evidence access")
    uri = f"bytestream://remote.buildbuddy.io/blobs/{row['sha256']}/{row['size_bytes']}"
    request = urllib.request.Request(
        "https://app.buildbuddy.io/api/v1/GetFile",
        data=json.dumps({"uri": uri}).encode(),
        headers={"Content-Type": "application/json", "x-buildbuddy-api-key": key},
        method="POST",
    )
    archive = tempfile.TemporaryFile()
    sha256 = hashlib.sha256()
    size = 0
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            while chunk := response.read(131072):
                archive.write(chunk)
                sha256.update(chunk)
                size += len(chunk)
        if size != row["size_bytes"] or sha256.hexdigest() != row["sha256"]:
            raise ValueError(f"BuildBuddy archive digest mismatch for {row['snapshot_digest']}")
        archive.seek(0)
        return archive
    except Exception:
        archive.close()
        raise


def entry_path(name: str, digest: str, root: Path) -> Path:
    parts = name.split("/")
    if len(parts) < 4 or parts[:1] != [".attune"] or parts[1] not in SPACES or parts[2] != digest:
        raise ValueError(f"foreign or unsafe evidence entry: {name}")
    if len(parts) == 4:
        if parts[3] not in SPACES[parts[1]]:
            raise ValueError(f"unexpected typed evidence entry: {name}")
    elif len(parts) == 5:
        raw = parts[3] == "raw" and re.fullmatch(r"[0-9a-f]{64}\.json", parts[4])
        passes = parts[3] == "passes" and re.fullmatch(
            r"(?:embeddings|decisions-[0-9]{6}-[0-9]{6})\.json", parts[4]
        )
        if not (raw or passes):
            raise ValueError(f"unexpected acquisition evidence entry: {name}")
    else:
        raise ValueError(f"unsafe evidence entry: {name}")
    return root.joinpath(*parts)


def compare_existing(source, target: Path) -> None:
    with target.open("rb") as local:
        while chunk := source.read(131072):
            if local.read(len(chunk)) != chunk:
                raise ValueError(f"recorded evidence differs from BuildBuddy: {target}")
        if local.read(1):
            raise ValueError(f"recorded evidence has extra bytes: {target}")


def restore(row: dict, root: Path, key: str) -> tuple[int, int]:
    digest = row["snapshot_digest"]
    created = checked = 0
    with fetch_archive(row, key, hydrating=True) as data, zipfile.ZipFile(data) as archive:
        names = archive.namelist()
        if not names or names != sorted(set(names)):
            raise ValueError(f"archive entries are empty, duplicate, or unsorted for {digest}")
        for name in names:
            target = entry_path(name, digest, root)
            with archive.open(name) as source:
                if target.exists():
                    compare_existing(source, target)
                    checked += 1
                    continue
                target.parent.mkdir(parents=True, exist_ok=True)
                with tempfile.NamedTemporaryFile(dir=target.parent, prefix=".hydrate-", delete=False) as staging:
                    temporary = Path(staging.name)
                    shutil.copyfileobj(source, staging, length=131072)
                try:
                    os.link(temporary, target)
                    created += 1
                except FileExistsError:
                    with archive.open(name) as source_again:
                        compare_existing(source_again, target)
                    checked += 1
                finally:
                    temporary.unlink()
    for space, tables in SPACES.items():
        for table in tables:
            if not (root / ".attune" / space / digest / table).is_file():
                raise ValueError(f"hydration omitted {space}/{digest}/{table}")
    return created, checked


def indexed_rows(index: Path, selected: set[str]) -> list[dict]:
    value = json.loads(index.read_text())
    if not isinstance(value, dict) or value.get("protocol") != INDEX_PROTOCOL:
        raise ValueError("unknown evidence CAS index protocol")
    rows = [address({"protocol": ADDRESS_PROTOCOL, **row}) for row in value.get("worlds", [])]
    digests = [row["snapshot_digest"] for row in rows]
    if digests != sorted(set(digests)) or (selected and not selected <= set(digests)):
        raise ValueError("evidence index is unsorted, duplicate, or missing a requested snapshot")
    return [row for row in rows if not selected or row["snapshot_digest"] in selected]


def hydrate(index: Path, root: Path, selected: set[str]) -> None:
    key = credential()
    for row in indexed_rows(index, selected):
        created, checked = restore(row, root, key)
        print(f"hydrated {row['snapshot_digest']} created={created} verified_existing={checked}", flush=True)


def verify(index: Path, selected: set[str]) -> None:
    """Read every indexed remote blob and ZIP entry without duplicating evidence."""
    key = credential()
    for row in indexed_rows(index, selected):
        digest = row["snapshot_digest"]
        with fetch_archive(row, key) as data, zipfile.ZipFile(data) as archive:
            names = archive.namelist()
            if not names or names != sorted(set(names)):
                raise ValueError(f"archive entries are empty, duplicate, or unsorted for {digest}")
            for name in names:
                entry_path(name, digest, REPO)
            for space, tables in SPACES.items():
                for table in tables:
                    if f".attune/{space}/{digest}/{table}" not in names:
                        raise ValueError(f"archive omits {space}/{digest}/{table}")
            corrupt = archive.testzip()
            if corrupt is not None:
                raise ValueError(f"archive entry has invalid CRC: {corrupt}")
            print(f"verified {digest} bytes={row['size_bytes']} entries={len(names)}", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    index = commands.add_parser("index")
    index.add_argument("--addresses", type=Path, required=True)
    index.add_argument("--output", type=Path, required=True)
    index.add_argument("--expected-worlds", type=int)
    restore_command = commands.add_parser("hydrate")
    restore_command.add_argument("--index", type=Path, required=True)
    restore_command.add_argument("--root", type=Path, default=REPO)
    restore_command.add_argument("--digest", action="append", default=[])
    verify_command = commands.add_parser("verify")
    verify_command.add_argument("--index", type=Path, required=True)
    verify_command.add_argument("--digest", action="append", default=[])
    args = parser.parse_args()
    if args.command == "index":
        build_index(args.addresses, args.output, args.expected_worlds)
    elif args.command == "hydrate":
        hydrate(args.index, args.root, {require_digest(value) for value in args.digest})
    else:
        verify(args.index, {require_digest(value) for value in args.digest})


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"evidence CAS operation failed: {error}", file=sys.stderr)
        sys.exit(1)
