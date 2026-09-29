#!/usr/bin/env python3
"""Declare completed local Families evidence to Bazel without editing it."""

import json
import os
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
EXPERIMENT = Path(__file__).resolve().parent
PREACT = "6e2bef41bf19f638be084df8cb82127e4832d4abbafa8ca20ebd5db9be3ac8a9"
SPACES = {
    "families-embeddings-v1": ("batches.parquet", "documents.parquet", "ledger.parquet"),
    "jev-families-raw-v1": ("decisions.parquet", "ledger.parquet", "outcomes.parquet"),
}


def complete(digest: str) -> bool:
    return all(
        all((ROOT / ".attune" / space / digest / name).is_file() for name in names)
        and any((ROOT / ".attune" / space / digest / "raw").glob("*.json"))
        for space, names in SPACES.items()
    )


def declaration(space: str, digest: str, names: tuple[str, ...]) -> str:
    if digest == PREACT:
        # Preserve the committed exemplar's existing evidence target exactly.
        kind = "embedding" if space == "families-embeddings-v1" else "Jev decision"
        lines = [
            f"# Atlas Families {kind} evidence for preactjs/preact",
            f"# (repository-snapshot-v1:{digest}):",
            "# retained raw exchanges and their typed projections. Read-only once recorded.",
            "filegroup(",
            '    name = "evidence",',
            '    srcs = glob(["raw/*.json"]) + [',
        ]
    else:
        lines = [
            f"# Recorded {space} evidence for repository-snapshot-v1:{digest}.",
            "# Raw provider envelopes are immutable; Bazel declares them as inputs.",
            "filegroup(",
            '    name = "evidence",',
            '    srcs = glob(["raw/*.json"]) + glob(',
            '        ["passes/*.json"],',
            '        allow_empty = True,',
            '    ) + [',
        ]
    lines += [f'        "{name}",' for name in names]
    lines += [
        "    ],",
        '    visibility = ["//experiments/atlas-families:__pkg__"],',
        ")",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    population = json.loads((EXPERIMENT / "acquisition_population.json").read_text())
    digests = [row["digest"] for row in population["worlds"] if complete(row["digest"])]
    if PREACT not in digests:
        raise RuntimeError("the Preact exemplar is missing or incomplete")
    for digest in digests:
        for space, names in SPACES.items():
            build = ROOT / ".attune" / space / digest / "BUILD.bazel"
            if not build.exists() or build.read_text() != declaration(space, digest, names):
                build.write_text(declaration(space, digest, names))
    ordered = [PREACT] + sorted(digest for digest in digests if digest != PREACT)
    content = (
        '"""Completed Families acquisitions declared as inputs to the Bazel graph.\n\n'
        '`seal_evidence.py` updates this list only after all six typed tables exist.\n'
        'The Preact exemplar remains the historical tracked evidence space.\n"""\n\n'
        'ACQUIRED_DIGESTS = [\n'
        + "".join(f'    "{digest}",\n' for digest in ordered)
        + "]\n"
    )
    target = EXPERIMENT / "acquired_worlds.bzl"
    if not target.exists() or target.read_text() != content:
        with tempfile.NamedTemporaryFile(mode="w", dir=EXPERIMENT, prefix=".acquired-worlds-", delete=False) as staging:
            staging.write(content)
            name = staging.name
        os.replace(name, target)
    print(f"sealed_worlds={len(ordered)}")


if __name__ == "__main__":
    main()
