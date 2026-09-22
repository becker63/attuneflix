let
  pkgs = import (builtins.getFlake
    "github:NixOS/nixpkgs/20b1ddd1aa5ace70c9468305030aa4f9ef79671b") {
      system = builtins.currentSystem;
    };

  benchmarkRevision = "bdb0ae45d7c337d9e1dc3ebfe2a0af6bc7c1fbd9";
  multilingualRevision = "7566cd247075886ef34453ff5582908c0255f5e6";
  proRevision = "a3f0ce9b3057b4656c77656c0317a482d4bf9c20";

  benchmark = builtins.fetchurl {
    url = "https://huggingface.co/datasets/SWE-Explore-Bench/SWE-Explore-Bench/resolve/${benchmarkRevision}/bench.final.public.jsonl";
    sha256 = "sha256-3E8RTs7NC/uYc2HCauXiRARW4szLNq38ywnqU4WuwgI=";
  };
  multilingual = builtins.fetchurl {
    url = "https://huggingface.co/datasets/SWE-bench/SWE-bench_Multilingual/resolve/${multilingualRevision}/data/test-00000-of-00001.parquet";
    sha256 = "sha256-KLf4dOSEljmQd9J2+fKxY6B33fCnDcUHwUjVjagmuqk=";
  };
  pro = builtins.fetchurl {
    url = "https://huggingface.co/datasets/ScaleAI/SWE-bench_Pro/resolve/${proRevision}/test.csv";
    sha256 = "sha256-0oI7PEU0GsQ1hvScnknuNPn7EMT17dykAol1BDlRPCo=";
  };

  # This is a format adapter at the Nix acquisition boundary, not experiment
  # orchestration. It projects only source identity metadata and deliberately
  # omits issue text, patches, tests, trajectories, and SWE-Explore gold.
  projector = pkgs.writers.writePython3 "attune-scale-population-projector" {
    libraries = [ pkgs.python3Packages.pyarrow ];
  } ''
    import csv
    import json
    import sys

    import pyarrow.parquet as pq

    csv.field_size_limit(sys.maxsize)

    benchmark_cases = []
    with open(sys.argv[1], encoding="utf-8") as source:
        for line in source:
            row = json.loads(line)
            benchmark_cases.append({
                "instance_id": row["instance_id"],
                "dataset_family": row["dataset"],
            })

    source_cases = []
    multilingual = pq.read_table(
        sys.argv[2], columns=["instance_id", "repo", "base_commit"]
    )
    for row in multilingual.to_pylist():
        source_cases.append({
            "instance_id": row["instance_id"],
            "dataset_family": "multilingual",
            "repository": row["repo"],
            "base_revision": row["base_commit"],
            "source_language": "javascript/typescript",
        })

    with open(sys.argv[3], encoding="utf-8", newline="") as source:
        for row in csv.DictReader(source):
            identity = row["instance_id"]
            if identity.startswith("instance_"):
                identity = identity[len("instance_"):]
            source_cases.append({
                "instance_id": identity,
                "dataset_family": "pro",
                "repository": row["repo"],
                "base_revision": row["base_commit"],
                "source_language": row["repo_language"],
            })

    result = {
        "version": 1,
        "benchmark_cases": benchmark_cases,
        "source_cases": source_cases,
    }
    with open(sys.argv[4], "w", encoding="utf-8") as output:
        json.dump(result, output, ensure_ascii=False, sort_keys=True,
                  separators=(",", ":"))
  '';

  projection = pkgs.runCommand "attune-swe-explore-population-projection-v1.json" {} ''
    ${projector} ${benchmark} ${multilingual} ${pro} "$out"
  '';
in
builtins.toJSON {
  version = 1;
  inherit benchmarkRevision multilingualRevision proRevision;
  inherit benchmark multilingual pro projection;
}
