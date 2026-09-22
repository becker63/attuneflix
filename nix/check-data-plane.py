"""Small executable laws for AttuneFlix's scientific data plane."""

from pathlib import Path
import subprocess
import sys

import pyarrow.parquet as pq


FORBIDDEN_SUFFIXES = {
    ".csv", ".tsv", ".jsonl", ".ndjson", ".arrow", ".feather",
    ".ipc", ".pickle", ".pkl", ".sqlite", ".sqlite3", ".db", ".duckdb",
}
IMPLEMENTATION_SUFFIXES = {".flix", ".java", ".py", ".rs", ".sh"}
SOURCE_FORMAT_MARKERS = (".csv", ".tsv", ".jsonl", ".ndjson")
JSON_TREE_COLUMNS = {
    "path", "node_type", "string_value", "integer_value", "float_value",
    "boolean_value",
}
INLINE_JSON_TREE_COLUMNS = JSON_TREE_COLUMNS | {"format_version"}


def forbidden_dataset_paths(paths: list[str]) -> list[str]:
    return sorted(path for path in paths if Path(path).suffix.lower() in FORBIDDEN_SUFFIXES)


def direct_source_format_consumers(root: Path, paths: list[str]) -> list[str]:
    violations = []
    for name in paths:
        path = Path(name)
        if path.suffix.lower() not in IMPLEMENTATION_SUFFIXES:
            continue
        text = (root / path).read_text(encoding="utf-8")
        if is_direct_source_format_consumer(path, text):
            violations.append(name)
    return sorted(violations)


def is_direct_source_format_consumer(path: Path, text: str) -> bool:
    if path.parts[0] == "nix" or path.parts[:2] == ("native", "parquet"):
        return False
    return any(marker in text.lower() for marker in SOURCE_FORMAT_MARKERS)


def validate_parquet(root: Path, paths: list[str]) -> list[str]:
    violations = []
    for name in sorted(path for path in paths if path.endswith(".parquet")):
        path = root / name
        if not path.exists():
            continue
        with path.open("rb") as handle:
            if handle.read(4) != b"PAR1":
                violations.append(f"{name}: missing Parquet magic")
                continue
        table = pq.read_table(path)
        metadata = table.schema.metadata or {}
        format_name = metadata.get(b"attune.format")
        inline_format = (
            set(table.column_names) == INLINE_JSON_TREE_COLUMNS
            and set(table.column("format_version").to_pylist()) == {"attune-json-tree-v1"}
        )
        if format_name == b"attune-json-tree-v1" or inline_format:
            expected_columns = (
                INLINE_JSON_TREE_COLUMNS if inline_format else JSON_TREE_COLUMNS
            )
            if set(table.column_names) != expected_columns:
                violations.append(f"{name}: wrong JSON-tree schema")
            roots = sum(1 for value in table.column("path").to_pylist() if value == [])
            if roots != 1:
                violations.append(f"{name}: expected one JSON-tree root, found {roots}")
        elif format_name == b"attune-tabular-v1":
            if metadata.get(b"attune.dataset") != b"replication":
                violations.append(f"{name}: unknown tabular dataset")
        else:
            violations.append(f"{name}: missing or unknown attune.format")
        if not any(path.parent.glob("*.md")):
            violations.append(f"{name}: no nearby Markdown description")
    return violations


def tracked_paths(root: Path) -> list[str]:
    result = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard"],
        cwd=root,
        check=True,
        capture_output=True,
        text=True,
    )
    return [line for line in result.stdout.splitlines() if line]


def self_test() -> None:
    assert forbidden_dataset_paths(["data.csv", "rows.DUCKDB"]) == [
        "data.csv", "rows.DUCKDB"
    ]
    assert forbidden_dataset_paths([
        "MANIFEST.json", "report.md", "facts.parquet", "flake.lock"
    ]) == []
    assert ".json" not in FORBIDDEN_SUFFIXES
    assert is_direct_source_format_consumer(Path("src/Experiment.flix"), '"data.csv"')
    assert not is_direct_source_format_consumer(Path("nix/ingest.py"), '"source.csv"')
    print("DATA_PLANE_POLICY_SELF_TEST acceptance=5 rejection=3")


def main() -> None:
    if sys.argv[1:] == ["--self-test"]:
        self_test()
        return
    if sys.argv[1:]:
        raise SystemExit("usage: check-data-plane.py [--self-test]")
    root = Path(__file__).resolve().parent.parent
    paths = [path for path in tracked_paths(root) if (root / path).exists()]
    violations = []
    violations.extend(
        f"forbidden canonical dataset extension: {path}"
        for path in forbidden_dataset_paths(paths)
    )
    violations.extend(
        f"direct source-format consumption outside nix/: {path}"
        for path in direct_source_format_consumers(root, paths)
    )
    violations.extend(validate_parquet(root, paths))
    if violations:
        raise SystemExit("\n".join(violations))
    parquet_count = sum(path.endswith(".parquet") for path in paths)
    print(f"DATA_PLANE_POLICY tracked_parquet={parquet_count} violations=0")


if __name__ == "__main__":
    main()
