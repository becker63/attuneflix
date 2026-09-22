"""Pinned Parquet boundary used by AttuneFlix.

The JVM passes one JSON object over stdin. JSON is only the process-local
control envelope; the durable file is a typed Parquet tree with one row per
semantic node. Keeping scalar types and structural paths in Arrow columns
preserves the established scientific shape without encoding a JSON blob in
Parquet.
"""

import json
import os
from pathlib import Path
import sys
import tempfile
from typing import NoReturn

import pyarrow as pa
import pyarrow.parquet as pq


FORMAT_VERSION = b"attune-json-tree-v1"
LEGACY_FORMAT_VERSION = b"attune-parquet-object-v1"

TREE_SCHEMA = pa.schema([
    pa.field("path", pa.list_(pa.string()), nullable=False),
    pa.field("node_type", pa.string(), nullable=False),
    pa.field("string_value", pa.string()),
    pa.field("integer_value", pa.int64()),
    pa.field("float_value", pa.float64()),
    pa.field("boolean_value", pa.bool_()),
])


def fail(message: str) -> NoReturn:
    raise SystemExit(message)


def read_object(path: Path) -> None:
    table = pq.read_table(path)
    metadata = table.schema.metadata or {}
    version = metadata.get(b"attune.format")
    if version == LEGACY_FORMAT_VERSION:
        rows = table.to_pylist()
        if len(rows) != 1:
            fail(f"Attune object Parquet must contain exactly one row: {path}")
        value = rows[0]
    elif version == FORMAT_VERSION:
        value = inflate(table.to_pylist())
    else:
        fail(f"unsupported Attune Parquet format: {path}")
    json.dump(value, sys.stdout, ensure_ascii=False, sort_keys=True,
              separators=(",", ":"), allow_nan=False)


def write_object(path: Path) -> None:
    value = json.load(sys.stdin)
    if not isinstance(value, dict):
        fail("Attune object Parquet input must be a JSON object")

    rows = []
    flatten(value, [], rows)
    table = pa.Table.from_pylist(rows, schema=TREE_SCHEMA)
    table = table.replace_schema_metadata({
        **(table.schema.metadata or {}),
        b"attune.format": FORMAT_VERSION,
    })
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
    )
    os.close(descriptor)
    temporary = Path(temporary_name)
    try:
        pq.write_table(
            table,
            temporary,
            compression="zstd",
            compression_level=9,
            data_page_version="2.0",
            use_dictionary=True,
            write_statistics=True,
        )
        with temporary.open("rb") as handle:
            os.fsync(handle.fileno())
        os.replace(temporary, path)
        directory_fd = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        temporary.unlink(missing_ok=True)


def flatten(value: object, path: list[str], rows: list[dict]) -> None:
    row = {
        "path": path,
        "node_type": "",
        "string_value": None,
        "integer_value": None,
        "float_value": None,
        "boolean_value": None,
    }
    if value is None:
        row["node_type"] = "null"
    elif isinstance(value, bool):
        row["node_type"] = "boolean"
        row["boolean_value"] = value
    elif isinstance(value, int):
        row["node_type"] = "integer"
        row["integer_value"] = value
    elif isinstance(value, float):
        row["node_type"] = "float"
        row["float_value"] = value
    elif isinstance(value, str):
        row["node_type"] = "string"
        row["string_value"] = value
    elif isinstance(value, list):
        row["node_type"] = "array"
    elif isinstance(value, dict):
        row["node_type"] = "object"
    else:
        fail(f"unsupported JSON value: {type(value).__name__}")
    rows.append(row)
    if isinstance(value, list):
        for index, child in enumerate(value):
            flatten(child, [*path, f"i:{index}"], rows)
    elif isinstance(value, dict):
        for key in sorted(value):
            flatten(value[key], [*path, f"k:{key}"], rows)


def inflate(rows: list[dict]) -> object:
    nodes = {tuple(row["path"]): row for row in rows}
    if len(nodes) != len(rows) or () not in nodes:
        fail("invalid Attune JSON-tree node paths")
    children_by_parent: dict[tuple[str, ...], list[str]] = {}
    for path in nodes:
        if not path:
            continue
        parent = path[:-1]
        if parent not in nodes:
            fail("Attune JSON-tree contains an orphan node")
        children_by_parent.setdefault(parent, []).append(path[-1])
    visited: set[tuple[str, ...]] = set()

    def build(path: tuple[str, ...]) -> object:
        visited.add(path)
        row = nodes[path]
        kind = row["node_type"]
        if kind == "null":
            return None
        if kind == "boolean":
            return row["boolean_value"]
        if kind == "integer":
            return row["integer_value"]
        if kind == "float":
            return row["float_value"]
        if kind == "string":
            return row["string_value"]
        children = sorted(children_by_parent.get(path, []))
        if kind == "object":
            if any(not component.startswith("k:") for component in children):
                fail("object node has a non-key child")
            return {
                component[2:]: build((*path, component))
                for component in children
            }
        if kind == "array":
            if any(not component.startswith("i:") for component in children):
                fail("array node has a non-index child")
            indexed = sorted(
                (int(component[2:]), component) for component in children
            )
            if [index for index, _ in indexed] != list(range(len(indexed))):
                fail("array node indices are not contiguous")
            return [build((*path, component)) for _, component in indexed]
        fail(f"unknown node type: {kind}")

    value = build(())
    if visited != set(nodes):
        fail("Attune JSON-tree contains unreachable nodes")
    return value


def main() -> None:
    if len(sys.argv) != 3:
        fail("usage: attune-parquet (read-object|write-object) PATH")
    operation = sys.argv[1]
    path = Path(sys.argv[2])
    if operation == "read-object":
        read_object(path)
    elif operation == "write-object":
        write_object(path)
    else:
        fail(f"unknown operation: {operation}")


if __name__ == "__main__":
    main()
