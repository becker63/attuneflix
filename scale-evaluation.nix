{ raw ? false }:

let
  pkgs = import (builtins.getFlake
    "github:NixOS/nixpkgs/20b1ddd1aa5ace70c9468305030aa4f9ef79671b") {
      system = builtins.currentSystem;
    };
  benchmarkRevision = "bdb0ae45d7c337d9e1dc3ebfe2a0af6bc7c1fbd9";
  evaluatorRevision = "5602f031f2d9562d0a805f83402b536e831a5a11";
  benchmark = builtins.fetchurl {
    url = "https://huggingface.co/datasets/SWE-Explore-Bench/SWE-Explore-Bench/resolve/${benchmarkRevision}/bench.final.public.jsonl";
    sha256 = "sha256-3E8RTs7NC/uYc2HCauXiRARW4szLNq38ywnqU4WuwgI=";
  };
  manifest = ./experiments/swe-explore-js-ts-scale/MANIFEST.json;

  # This capability is deliberately separate from scale-case.nix and
  # scale-issues.nix. Solver construction cannot receive this output.
  projector = pkgs.writeText "attune-scale-gold-projector.py" ''
    import json
    import sys

    with open(sys.argv[1], encoding="utf-8") as source:
        manifest = json.load(source)
    wanted = [row["instance_id"] for row in manifest["cases"]]
    wanted_set = set(wanted)
    rows = {}
    with open(sys.argv[2], encoding="utf-8") as source:
        for line in source:
            row = json.loads(line)
            identity = row["instance_id"]
            if identity in wanted_set:
                rows[identity] = row["ground_truth"]
    if set(rows) != wanted_set:
        raise SystemExit(
            f"gold identity mismatch: wanted={len(wanted)} actual={len(rows)}"
        )

    def flatten(mapping):
        result = []
        for values in (mapping or {}).values():
            result.extend(values or [])
        return result

    cases = []
    for identity in wanted:
        gold = rows[identity]
        cases.append({
            "instance_id": identity,
            "core_files": gold.get("read_core_files") or [],
            "core_regions": gold.get("read_core_regions") or [],
            "optional_files": sorted(set(flatten(
                gold.get("read_optional_files_map")
            ))),
            "optional_regions": flatten(
                gold.get("read_optional_regions_map")
            ),
            "main_files": gold.get("main_files") or [],
        })

    with open(sys.argv[3], "w", encoding="utf-8") as output:
        json.dump(
            {
                "version": 1,
                "benchmark_revision": ${builtins.toJSON benchmarkRevision},
                "evaluator_revision": ${builtins.toJSON evaluatorRevision},
                "cases": cases,
            },
            output,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        )
  '';

  goldFixture = pkgs.runCommand
    "attune-swe-explore-js-ts-gold-${builtins.substring 0 12 benchmarkRevision}.json"
    {} ''
      ${pkgs.python3}/bin/python ${projector} ${manifest} ${benchmark} "$out"
    '';
  result = {
    version = 1;
    inherit benchmarkRevision evaluatorRevision goldFixture;
  };
in
if raw then result else builtins.toJSON result
