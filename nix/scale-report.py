#!/usr/bin/env python3
"""Render the frozen scale report from canonical Parquet evidence."""

from __future__ import annotations

import argparse
from collections import defaultdict
import json
from pathlib import Path
import re
import sys
from typing import Any

import pyarrow.parquet as pq


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "native" / "parquet"))
from attune_parquet import FORMAT_VERSION, inflate  # noqa: E402

MANIFEST = ROOT / "experiments" / "swe-explore-js-ts-scale" / "MANIFEST.json"
RESULTS = ROOT / "experiments" / "swe-explore-js-ts-scale" / "results.parquet"
CENSORED_RESULTS = (
    ROOT / "experiments" / "swe-explore-js-ts-scale" / "results-censored.parquet"
)
CENSORED_IDS = {
    "mrdoob__three.js-26589",
    "mrdoob__three.js-27395",
}
HISTORICAL = ROOT / "docs" / "research" / "jev" / "localization-results.parquet"
PRIOR_ROOT = ROOT / ".attune" / "semantic-prior-js-ts-scale-v1" / "rankings"
PREDICTION_ROOT = (
    ROOT / ".attune" / "experiments" / "swe-explore-js-ts-scale" / "013-predictions"
)
DECISION_ROOTS = tuple(
    ROOT / ".attune" / "experiments" / "swe-explore-js-ts-scale" / name / "raw"
    for name in (
        "003-force-first-macro",
        "012-pruned-planner-portfolio",
        "013-deep-planner-portfolio",
    )
)
PREPARE_LOG = ROOT / ".attune" / "logs" / "swe-explore-js-ts-scale" / "013-prepare.log"


def fail(message: str) -> None:
    raise SystemExit(message)


def load_tree(path: Path) -> dict[str, Any]:
    if not path.is_file():
        fail(f"missing canonical artifact: {path.relative_to(ROOT)}")
    table = pq.read_table(path)
    if (table.schema.metadata or {}).get(b"attune.format") != FORMAT_VERSION:
        fail(f"unexpected Parquet representation: {path.relative_to(ROOT)}")
    value = inflate(table.to_pylist())
    if not isinstance(value, dict):
        fail(f"expected object root: {path.relative_to(ROOT)}")
    return value


def mean(rows: list[dict[str, Any]], condition: str, metric: str) -> float:
    if not rows:
        return 0.0
    return sum(row[condition]["metrics"][metric] for row in rows) / len(rows)


def aggregate_table(rows: list[dict[str, Any]]) -> list[str]:
    columns = (
        ("F1", "f1_score"),
        ("Precision", "precision"),
        ("Recall", "recall"),
        ("Hit file", "hit_file_rate"),
        ("Hit region", "hit_region_rate"),
        ("Context", "context_efficiency"),
        ("nDCG@100", "ndcg_at_100"),
    )
    lines = [
        "| Condition | " + " | ".join(label for label, _ in columns) + " |",
        "| --- | " + " | ".join("---:" for _ in columns) + " |",
    ]
    for label, condition in (
        ("Semantic prior", "prior"),
        ("Frozen iteration 013", "jev"),
        ("Structural oracle", "structural_oracle"),
    ):
        values = " | ".join(f"{mean(rows, condition, metric):.4f}" for _, metric in columns)
        lines.append(f"| {label} | {values} |")
    return lines


def usage(manifest_cases: list[dict[str, Any]]) -> dict[str, Any]:
    totals: dict[str, Any] = {
        "prior_live": 0,
        "prior_replayed": 0,
        "prior_input": 0,
        "prior_total": 0,
        "decisions": 0,
        "decision_input": 0,
        "decision_output": 0,
        "decision_cost": 0.0,
        "decision_cost_observed": 0,
        "decision_cost_missing": 0,
        "models": set(),
    }
    for case in manifest_cases:
        revision = case["base_revision"]
        prior = load_tree(PRIOR_ROOT / f"{revision}.parquet")
        prior_case = prior.get("cases", [{}])[0]
        if prior_case.get("instance_id") != case["instance_id"]:
            fail(f"semantic-prior identity mismatch: {case['instance_id']}")
        totals["prior_live"] += prior["live"]
        totals["prior_replayed"] += prior["replayed"]
        totals["prior_input"] += prior["input_tokens"]
        totals["prior_total"] += prior["total_tokens"]

        prediction = load_tree(PREDICTION_ROOT / f"{revision}.parquet")
        if prediction.get("instance_id") != case["instance_id"]:
            fail(f"prediction identity mismatch: {case['instance_id']}")
        decisions = prediction["decisions"]
        if prediction["decision_count"] != len(decisions):
            fail(f"decision cardinality mismatch: {case['instance_id']}")
        totals["decisions"] += len(decisions)
        for decision in decisions:
            if decision["input_tokens"] is not None:
                totals["decision_input"] += decision["input_tokens"]
            if decision["output_tokens"] is not None:
                totals["decision_output"] += decision["output_tokens"]
            if decision["cost"] is None:
                totals["decision_cost_missing"] += 1
            else:
                totals["decision_cost"] += decision["cost"]
                totals["decision_cost_observed"] += 1
            totals["models"].add(decision["actual_model"])
    return totals


def retained_provider_usage() -> dict[str, Any]:
    totals: dict[str, Any] = {
        "observations": 0,
        "input": 0,
        "output": 0,
        "cost": 0.0,
        "cost_observed": 0,
        "cost_missing": 0,
    }
    for root in DECISION_ROOTS:
        if not root.is_dir():
            fail(f"missing retained decision observation store: {root.relative_to(ROOT)}")
        for path in root.glob("*.json"):
            envelope = json.loads(path.read_text(encoding="utf-8"))
            response = json.loads(envelope["response"])
            usage0 = response.get("usage") or {}
            totals["observations"] += 1
            totals["input"] += usage0.get("input_tokens") or 0
            totals["output"] += usage0.get("output_tokens") or 0
            if usage0.get("cost") is None:
                totals["cost_missing"] += 1
            else:
                totals["cost"] += usage0["cost"]
                totals["cost_observed"] += 1
    return totals


def measured_precompute() -> str:
    if not PREPARE_LOG.is_file():
        return "No structural precompute timing log was retained; no timing is claimed."
    match = re.search(
        r"SCALE_013 mode=prepare cases=(\d+) calls=(\d+) precompute_nanos=(\d+)",
        PREPARE_LOG.read_text(encoding="utf-8", errors="replace"),
    )
    if match is None:
        return "The local preparation log has no complete aggregate; no timing is claimed."
    cases, calls, nanos = map(int, match.groups())
    if cases != 63 or calls != 0:
        fail("unexpected structural preparation aggregate")
    return (
        f"The retained keyless preparation run measured {nanos / 1_000_000_000:.3f} "
        f"elapsed seconds inside structural precompute across {cases} cases "
        "(sum of per-case `System.nanoTime` intervals; not provider latency)."
    )


def render(censored_three_context: bool) -> str:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    cases = manifest["cases"]
    historical_cases = [case for case in cases if case["population"] == "historical-development"]
    new_cases = [case for case in cases if case["population"] == "new"]
    optimization = [case for case in new_cases if case["repository_group_split"] == "optimization-development"]
    validation = [case for case in new_cases if case["repository_group_split"] == "post-optimization-validation"]
    if (len(cases), len(historical_cases), len(new_cases), len(optimization), len(validation)) != (78, 15, 63, 42, 21):
        fail("frozen manifest cardinalities changed")

    result_path = CENSORED_RESULTS if censored_three_context else RESULTS
    results = load_tree(result_path)
    expected_protocol = "attune-jev-policy-hillclimb-013-deep-planner-portfolio-v1"
    if censored_three_context:
        expected_protocol += "-censored-three-context"
    if results.get("protocol") != expected_protocol:
        fail("scale result protocol identity changed")
    rows = results["cases"]
    by_id = {row["instance_id"]: row for row in rows}
    expected_ids = {case["instance_id"] for case in new_cases}
    missing_ids = expected_ids - set(by_id)
    expected_missing = CENSORED_IDS if censored_three_context else set()
    if len(rows) != 63 - len(expected_missing) or missing_ids != expected_missing:
        fail("scale result population is incomplete or contains unexpected cases")

    historical = load_tree(HISTORICAL)["cases"]
    if {row["instance_id"] for row in historical} != {case["instance_id"] for case in historical_cases}:
        fail("historical result population does not match the frozen manifest")

    completed_cases = [case for case in new_cases if case["instance_id"] in by_id]
    optimization_rows = [by_id[case["instance_id"]] for case in optimization if case["instance_id"] in by_id]
    validation_rows = [by_id[case["instance_id"]] for case in validation if case["instance_id"] in by_id]
    usage_totals = usage(completed_cases)
    provider_totals = retained_provider_usage()

    repositories: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        repositories[row["repository"]].append(row)

    lines = [
        "# Frozen SWE-Explore JavaScript/TypeScript scale result",
        "",
        "This report is generated from canonical Parquet evidence by " + (
            "`nix develop --command python nix/scale-report.py --censored-three-context`. "
            if censored_three_context
            else "`nix develop --command python nix/scale-report.py`. "
        )
        + "The policy, semantic "
        "prior, case order, prediction budget, evaluator, and population splits were "
        "frozen before scale gold was opened.",
        "",
        "## Populations",
        "",
        "| Population | Cases | Role |",
        "| --- | ---: | --- |",
        "| Historical development | 15 | Earlier evidence reused; not reacquired |",
        "| Expanded optimization development | 42 | New frozen-policy evaluation |",
        f"| Post-optimization validation | {len(validation_rows)} completed / 21 frozen | Untouched until predictions were frozen |",
        f"| Completed new cases | {len(rows)} / 63 | Frozen iteration-013 result |",
        "",
        "## Historical development evidence",
        "",
        *aggregate_table(historical),
        "",
        "These 15 cases retain their original evidence and are reported separately; "
        "they are not counted as new scale acquisition.",
        "",
        "## Expanded optimization-development result",
        "",
        *aggregate_table(optimization_rows),
        "",
        "## Post-optimization-validation result",
        "",
        *aggregate_table(validation_rows),
        "",
    ]
    if censored_three_context:
        lines.extend([
            "Two frozen validation cases are censored: `mrdoob__three.js-26589` and "
            "`mrdoob__three.js-27395`. In each case the exact unchanged "
            "48,000-codepoint semantic-prior request tokenized to 40,961 tokens, "
            "exceeding the provider/model 40,960-token context limit. Changing the "
            "clipping, model, or document population would create a new scientific "
            "condition. The frozen validation denominator remains 21; metrics below "
            "cover the 19 admissible completed cases.",
            "",
        ])
    lines.extend([
        f"## All {len(rows)} completed new cases",
        "",
        *aggregate_table(rows),
        "",
        "| Repository | Cases | Prior F1 | Frozen 013 F1 | Oracle F1 | 013 − prior |",
        "| --- | ---: | ---: | ---: | ---: | ---: |",
    ])
    for repository in sorted(repositories):
        repo_rows = repositories[repository]
        prior = mean(repo_rows, "prior", "f1_score")
        selected = mean(repo_rows, "jev", "f1_score")
        oracle = mean(repo_rows, "structural_oracle", "f1_score")
        lines.append(
            f"| {repository} | {len(repo_rows)} | {prior:.4f} | {selected:.4f} | "
            f"{oracle:.4f} | {selected - prior:+.4f} |"
        )

    model_text = ", ".join(sorted(usage_totals["models"])) or "none retained"
    cost_text = (
        f"${usage_totals['decision_cost']:.6f} across "
        f"{usage_totals['decision_cost_observed']} calls"
        if usage_totals["decision_cost_observed"]
        else "not returned by the provider"
    )
    if usage_totals["decision_cost_missing"]:
        cost_text += f"; {usage_totals['decision_cost_missing']} calls have no retained cost"
    provider_cost_text = (
        f"${provider_totals['cost']:.6f} across {provider_totals['cost_observed']} observations"
        if provider_totals["cost_observed"]
        else "not returned by the provider"
    )
    if provider_totals["cost_missing"]:
        provider_cost_text += (
            f"; {provider_totals['cost_missing']} observations have no retained cost"
        )
    lines.extend([
        "",
        "## Retained acquisition and compute accounting",
        "",
        f"- Semantic-prior observations: {usage_totals['prior_live']} acquired and "
        f"{usage_totals['prior_replayed']} replayed during acquisition; "
        f"{usage_totals['prior_input']} input tokens and {usage_totals['prior_total']} total tokens.",
        f"- Retained portfolio-search provider observations: {provider_totals['observations']}; "
        f"{provider_totals['input']} input tokens and {provider_totals['output']} output tokens; "
        f"retained cost: {provider_cost_text}.",
        f"- Decisions selected into frozen predictions: {usage_totals['decisions']}; "
        f"{usage_totals['decision_input']} input tokens and "
        f"{usage_totals['decision_output']} output tokens; actual model(s): {model_text}.",
        f"- Selected-decision cost subset: {cost_text}.",
        f"- Structural compute: {measured_precompute()}",
        "- Provider latency was not measured and is not reported.",
        "",
        "## Interpretation and limitations",
        "",
        "This is a repository-localization experiment, not an end-to-end coding-agent "
        "benchmark. The structural oracle measures available headroom within the frozen "
        "Atlas language and region budget; it is not a deployable predictor. Development "
        "and post-optimization-validation results are kept separate, and no policy tuning "
        "was performed after validation gold was opened.",
        "",
        "## Reproduction and replay",
        "",
        "```sh",
        "env -u OPENROUTER_API_KEY ATTUNE_SCALE_MODE=facts "
        "ATTUNE_CASE_SHARD=0/2 nix develop --command flix test",
        "env -u OPENROUTER_API_KEY ATTUNE_SCALE_MODE=facts "
        "ATTUNE_CASE_SHARD=1/2 nix develop --command flix test",
        "env -u OPENROUTER_API_KEY ATTUNE_SCALE_MODE=prior-prepare "
        "nix develop --command flix test",
        "env -u OPENROUTER_API_KEY ATTUNE_SCALE_MODE=prior-replay "
        "nix develop --command flix test",
        "env -u OPENROUTER_API_KEY ATTUNE_SCALE_GENERALIZATION_MODE=prepare "
        "nix develop --command flix test",
        "env -u OPENROUTER_API_KEY ATTUNE_SCALE_GENERALIZATION_MODE=replay "
        "nix develop --command flix test",
        (
            "ATTUNE_JEV_EVALUATE=scale-censored-three-context nix develop --command flix test"
            if censored_three_context
            else "ATTUNE_JEV_EVALUATE=scale nix develop --command flix test"
        ),
        (
            "nix develop --command python nix/scale-report.py --censored-three-context"
            if censored_three_context
            else "nix develop --command python nix/scale-report.py"
        ),
        "nix develop --command ./verify",
        "```",
        "",
        "The fact/prior/prediction commands require retained local evidence but no "
        "provider key. The "
        "evaluator command is the only listed step that opens scale gold.",
        "",
    ])
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "experiments" / "swe-explore-js-ts-scale" / "REPORT.md",
    )
    parser.add_argument(
        "--censored-three-context",
        action="store_true",
        help="render the authorized 61-case result with two exact context-limit censors",
    )
    args = parser.parse_args()
    report = render(args.censored_three_context)
    args.output.write_text(report, encoding="utf-8")
    cases = 61 if args.censored_three_context else 63
    print(f"SCALE_REPORT output={args.output} cases={cases}")


if __name__ == "__main__":
    main()
