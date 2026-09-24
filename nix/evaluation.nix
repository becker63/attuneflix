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
  parquetHelper = pkgs.writers.writePython3 "attune-parquet" {
    libraries = [ pkgs.python3Packages.pyarrow ];
  } (builtins.readFile ../src/native/parquet/attune_parquet.py);

  wanted = [
    "axios__axios-4731"
    "axios__axios-5085"
    "immutable-js__immutable-js-2005"
    "immutable-js__immutable-js-2006"
    "preactjs__preact-2757"
    "preactjs__preact-2896"
    "preactjs__preact-3010"
    "preactjs__preact-3454"
    "preactjs__preact-3562"
    "preactjs__preact-3689"
    "preactjs__preact-3739"
    "preactjs__preact-3763"
    "preactjs__preact-4152"
    "preactjs__preact-4182"
    "preactjs__preact-4436"
  ];

  projector = pkgs.writeText "attune-localization-gold-projector.py" ''
    import json
    import sys

    wanted = ${builtins.toJSON wanted}
    rows = {}
    with open(sys.argv[1], encoding="utf-8") as source:
        for line in source:
            row = json.loads(line)
            identity = row["instance_id"]
            if identity in wanted:
                rows[identity] = row["ground_truth"]

    if set(rows) != set(wanted):
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
            "optional_files": sorted(set(flatten(gold.get("read_optional_files_map")))),
            "optional_regions": flatten(gold.get("read_optional_regions_map")),
            "main_files": gold.get("main_files") or [],
        })

    result = {
        "version": 1,
        "benchmark_revision": ${builtins.toJSON benchmarkRevision},
        "evaluator_revision": ${builtins.toJSON evaluatorRevision},
        "cases": cases,
    }
    with open(sys.argv[2], "w", encoding="utf-8") as output:
        json.dump(result, output, ensure_ascii=False, sort_keys=True,
                  separators=(",", ":"))
  '';

  goldFixture = pkgs.runCommand
    "attune-jev-localization-gold-${builtins.substring 0 12 benchmarkRevision}.parquet"
    {} ''
      ${pkgs.python3}/bin/python ${projector} ${benchmark} "$TMPDIR/gold.json"
      ${parquetHelper} write-object "$out" < "$TMPDIR/gold.json"
    '';
in
builtins.toJSON {
  version = 1;
  inherit benchmarkRevision evaluatorRevision goldFixture;
}
