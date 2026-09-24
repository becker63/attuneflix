{ raw ? false }:

let
  pkgs = import (builtins.getFlake
    "github:NixOS/nixpkgs/20b1ddd1aa5ace70c9468305030aa4f9ef79671b") {
      system = builtins.currentSystem;
    };

  multilingualRevision = "7566cd247075886ef34453ff5582908c0255f5e6";
  proRevision = "a3f0ce9b3057b4656c77656c0317a482d4bf9c20";
  multilingual = builtins.fetchurl {
    url = "https://huggingface.co/datasets/SWE-bench/SWE-bench_Multilingual/resolve/${multilingualRevision}/data/test-00000-of-00001.parquet";
    sha256 = "sha256-KLf4dOSEljmQd9J2+fKxY6B33fCnDcUHwUjVjagmuqk=";
  };
  pro = builtins.fetchurl {
    url = "https://huggingface.co/datasets/ScaleAI/SWE-bench_Pro/resolve/${proRevision}/test.csv";
    sha256 = "sha256-0oI7PEU0GsQ1hvScnknuNPn7EMT17dykAol1BDlRPCo=";
  };
  manifest = ../experiments/swe-explore-js-ts-scale/MANIFEST.json;
  parquetHelper = pkgs.writers.writePython3 "attune-parquet" {
    libraries = [ pkgs.python3Packages.pyarrow ];
  } (builtins.readFile ../src/native/parquet/attune_parquet.py);

  # Format conversion only. The output is the solver-visible issue projection:
  # no patch, tests, changed-file labels, trajectory, or SWE-Explore gold.
  projector = pkgs.writers.writePython3 "attune-scale-issue-projector" {
    libraries = [ pkgs.python3Packages.pyarrow ];
  } ''
    import csv
    import json
    import sys

    import pyarrow.parquet as pq

    csv.field_size_limit(sys.maxsize)
    with open(sys.argv[1], encoding="utf-8") as source:
        manifest = json.load(source)
    wanted = {row["instance_id"]: row for row in manifest["cases"]}

    found = {}
    table = pq.read_table(
        sys.argv[2],
        columns=["instance_id", "repo", "base_commit", "problem_statement"],
    )
    for row in table.to_pylist():
        identity = row["instance_id"]
        if identity in wanted:
            found[identity] = {
                "instanceId": identity,
                "repository": row["repo"],
                "baseCommit": row["base_commit"],
                "problemStatement": row["problem_statement"],
            }

    with open(sys.argv[3], encoding="utf-8", newline="") as source:
        for row in csv.DictReader(source):
            identity = row["instance_id"]
            if identity.startswith("instance_"):
                identity = identity[len("instance_"):]
            if identity in wanted:
                found[identity] = {
                    "instanceId": identity,
                    "repository": row["repo"],
                    "baseCommit": row["base_commit"],
                    "problemStatement": row["problem_statement"],
                }

    if set(found) != set(wanted):
        missing = sorted(set(wanted) - set(found))
        extra = sorted(set(found) - set(wanted))
        raise SystemExit(
            f"issue identity mismatch: missing={missing} extra={extra}"
        )
    issues = []
    for case in manifest["cases"]:
        row = found[case["instance_id"]]
        if row["repository"] != case["repository"]:
            raise SystemExit(f"repository mismatch: {row['instanceId']}")
        if row["baseCommit"] != case["base_revision"]:
            raise SystemExit(f"base revision mismatch: {row['instanceId']}")
        if not row["problemStatement"]:
            raise SystemExit(f"empty problem statement: {row['instanceId']}")
        issues.append(row)

    with open(sys.argv[4], "w", encoding="utf-8") as output:
        json.dump(
            {"version": 1, "issues": issues},
            output,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        )
  '';

  issueFixture = pkgs.runCommand "attune-swe-explore-js-ts-issues-v1.parquet" {} ''
    ${projector} ${manifest} ${multilingual} ${pro} "$TMPDIR/issues.json"
    ${parquetHelper} write-object "$out" < "$TMPDIR/issues.json"
  '';
  result = {
  version = 1;
  inherit multilingualRevision proRevision issueFixture;
  };
in
if raw then result else builtins.toJSON result
