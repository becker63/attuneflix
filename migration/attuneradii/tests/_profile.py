"""Render Attune telemetry into the canonical Memray profile."""

import html
import json
import sys
from pathlib import Path
from typing import cast

PROFILE = Path("profile.html")
MARKER = "attune-telemetry"
SECONDS = ".3f"
METRICS = (
    ("total_seconds", SECONDS),
    ("mean_seconds", SECONDS),
    ("time_share", ".1%"),
    ("mean_rss_delta_mb", "+.1f"),
    ("max_hwm_mb", ".1f"),
)
DUPLICATE_MESSAGE = "Attune telemetry already exists in profile.html."
BODY_MESSAGE = "Memray report has no closing body."


def _number(value: object) -> float:
    """Return one numeric telemetry value."""
    if not isinstance(value, int | float):
        raise TypeError(value)
    return float(value)


def _metric(values: dict[str, object], key: str, spec: str) -> str:
    """Render one numeric telemetry field."""
    return format(_number(values[key]), spec)


def _row(name: str, values: dict[str, object]) -> str:
    """Render one phase row."""
    cells = "".join(f"<td>{_metric(values, key, spec)}</td>" for key, spec in METRICS)
    return f'<tr><td style="text-align:left">{html.escape(name)}</td>{cells}</tr>'


def _section(summary: dict[str, object]) -> str:
    """Render the Attune telemetry panel."""
    phases = cast("dict[str, dict[str, object]]", summary["phases"])
    ordered = sorted(
        phases.items(),
        key=lambda item: _number(item[1]["total_seconds"]),
        reverse=True,
    )
    rows = "".join(_row(*item) for item in ordered)
    headline = " · ".join(
        (
            _metric(summary, "cases", ".0f") + " cases",
            _metric(summary, "total_seconds", SECONDS) + "s total",
            _metric(summary, "mean_seconds_per_case", SECONDS) + "s/case",
            _metric(summary, "max_hwm_mb", ".1f") + " MB peak RSS",
        ),
    )
    return (
        f'\n<section id="{MARKER}" style="margin:24px;padding:20px">\n'
        f"<h2>Attune telemetry</h2><p>{headline}</p>\n"
        '<table style="width:100%;text-align:right">\n'
        '<thead><tr><th style="text-align:left">Phase</th>'
        "<th>Total s</th><th>Mean s</th><th>Share</th>"
        "<th>Δ RSS MB</th><th>Peak MB</th></tr></thead>\n"
        f"<tbody>{rows}</tbody></table></section>\n"
    )


def inject(summary_path: Path, profile_path: Path = PROFILE) -> None:
    """Inject telemetry into one generated Memray flamegraph."""
    summary = cast(
        "dict[str, object]",
        json.loads(summary_path.read_text(encoding="utf-8")),
    )
    document = profile_path.read_text(encoding="utf-8")
    if f'id="{MARKER}"' in document:
        raise RuntimeError(DUPLICATE_MESSAGE)
    closing = "</body>"
    if closing not in document:
        raise RuntimeError(BODY_MESSAGE)
    _ = profile_path.write_text(
        document.replace(closing, _section(summary) + closing, 1),
        encoding="utf-8",
    )


if __name__ == "__main__":
    inject(Path(sys.argv[1]), Path(sys.argv[2]))
