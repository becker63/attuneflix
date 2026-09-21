{ caseIndex ? 0, issuesOnly ? false }:

let
  # Exact nixpkgs revision from flake.lock. This expression is also evaluated
  # through the runtime Nix boundary, so it may not rely on an ambient NIX_PATH.
  pkgs = import (builtins.getFlake
    "github:NixOS/nixpkgs/20b1ddd1aa5ace70c9468305030aa4f9ef79671b") {
      system = builtins.currentSystem;
    };

  issueRevision = "7566cd247075886ef34453ff5582908c0255f5e6";
  issueDataset = builtins.fetchurl {
    url = "https://huggingface.co/datasets/SWE-bench/SWE-bench_Multilingual/resolve/${issueRevision}/data/test-00000-of-00001.parquet";
    sha256 = "sha256-KLf4dOSEljmQd9J2+fKxY6B33fCnDcUHwUjVjagmuqk=";
  };

  cases = [
    { instanceId = "axios__axios-4731"; repository = "axios/axios"; baseCommit = "c30252f685e8f4326722de84923fcbc8cf557f06"; sha256 = "sha256-CKbfznOvFk//B1LhMFpw56rjAt6VmVDdmoiqI5kbJYA="; }
    { instanceId = "axios__axios-5085"; repository = "axios/axios"; baseCommit = "85740c3e7a1fa48346dfcbd4497f463ccb1c1b05"; sha256 = "sha256-vctNvIzOxiLLISk8oNyAXynOO/cMlxTORh9fKv++vSU="; }
    { instanceId = "immutable-js__immutable-js-2005"; repository = "immutable-js/immutable-js"; baseCommit = "77434b3cbbc8ee21206f4cc6965e1c9b09cc92b6"; sha256 = "sha256-JjHdUV7gG1RbEITAyvEcjMhkukAKr6TqHDzS/vvRXVM="; }
    { instanceId = "immutable-js__immutable-js-2006"; repository = "immutable-js/immutable-js"; baseCommit = "493afba6ec17d9c999dc5a15ac80c71c6bdba1c3"; sha256 = "sha256-+o+VpPsg87kZxKKQN5H8ZZYsObE32fVOsKaqAdHdD1s="; }
    { instanceId = "preactjs__preact-2757"; repository = "preactjs/preact"; baseCommit = "b17a932342bfdeeaf1dc0fbe4f436c83e258d6c8"; sha256 = "sha256-HmkVYxjf8vDrJoXITFTT/plQHfVuzmvkQ+C1KH10oMY="; }
    { instanceId = "preactjs__preact-2896"; repository = "preactjs/preact"; baseCommit = "a9f7e676dc03b5008b8483e0937fc27c1af8287f"; sha256 = "sha256-/O+JX9+hC8amzlglyN290xWgIjcxRFKAVEjpdJAqcOI="; }
    { instanceId = "preactjs__preact-3010"; repository = "preactjs/preact"; baseCommit = "c12331064f4ea967641cd5e419204422af050fbb"; sha256 = "sha256-+DRJo2YJDF1ilekspdwUso4APxiNwsDBYO+ACjIY4q0="; }
    { instanceId = "preactjs__preact-3454"; repository = "preactjs/preact"; baseCommit = "00c8d1ff1498084c15408cf0014d4c7facdb5dd7"; sha256 = "sha256-TWIo5VCWFWjYZWszCSt0igc6SQ/S7GLu2aadQG/2whI="; }
    { instanceId = "preactjs__preact-3562"; repository = "preactjs/preact"; baseCommit = "0b9a9275b47e446106e6e97c78011896f7db2a61"; sha256 = "sha256-gVUPzopV1A+oMddlqEQQ0sKExYkk5FtryVAEFqpbolE="; }
    { instanceId = "preactjs__preact-3689"; repository = "preactjs/preact"; baseCommit = "9457b221fdacd1052ffdb385918e1bab4b10e833"; sha256 = "sha256-e22j7a1OMlipwlrsaiE5diWZkxAdrLZXNbLR+7J4ylY="; }
    { instanceId = "preactjs__preact-3739"; repository = "preactjs/preact"; baseCommit = "2cafedee2ddf7c73795e887ef1970df4be2bca90"; sha256 = "sha256-LeULMvUicqbJ9gWIqIqBVIaLu0QauRTImHcooqSV0N4="; }
    { instanceId = "preactjs__preact-3763"; repository = "preactjs/preact"; baseCommit = "e968a5a4000dfa9bec7e8d7b26543b23def6d29d"; sha256 = "sha256-o8J9m2+EbQz2jCPxJtCf/TMF15AJ/7jSO5Ax7pgo+VQ="; }
    { instanceId = "preactjs__preact-4152"; repository = "preactjs/preact"; baseCommit = "9c5a82efcc3dcbd0035c694817a3022d81264687"; sha256 = "sha256-1Wma7pOcpet/9zeqT5ntJffyDYyc14Z7xchSk4nc1/Y="; }
    { instanceId = "preactjs__preact-4182"; repository = "preactjs/preact"; baseCommit = "66cb6a78776b263a2fe4d1283426e699961095d2"; sha256 = "sha256-ft3mmKq6MgcppzzY9LW6BUGhQOhLzaZuauZojAGikU0="; }
    { instanceId = "preactjs__preact-4436"; repository = "preactjs/preact"; baseCommit = "db0f4f2e7a2338ea40050f623f05505a798fc1a4"; sha256 = "sha256-7NTAm383x5DxSx47QwwVM1/nN1VKFt8E/FqzKwRizLo="; }
  ];
  wantedPython = builtins.concatStringsSep "\n"
    (map (case: "    ${builtins.toJSON case.instanceId},") cases);

  issueProjector = pkgs.writers.writePython3 "attune-issue-projector" {
    libraries = [ pkgs.python3Packages.pyarrow ];
  } ''
    import json
    import sys
    import pyarrow.parquet as pq

    wanted = [
    ${wantedPython}
    ]
    table = pq.read_table(
        sys.argv[1],
        columns=["instance_id", "repo", "base_commit", "problem_statement"],
    )
    rows = {
        row["instance_id"]: row
        for row in table.to_pylist()
        if row["instance_id"] in wanted
    }
    if set(rows) != set(wanted):
        raise SystemExit(
            f"issue identity mismatch: wanted={len(wanted)} actual={len(rows)}"
        )
    projected = []
    for identity in wanted:
        row = rows[identity]
        if not row["problem_statement"]:
            raise SystemExit(f"empty problem_statement: {identity}")
        projected.append({
            "instanceId": identity,
            "repository": row["repo"],
            "baseCommit": row["base_commit"],
            "problemStatement": row["problem_statement"],
        })
    envelope = {
        "version": 1,
        "revision": ${builtins.toJSON issueRevision},
        "issues": projected,
    }
    with open(sys.argv[2], "w", encoding="utf-8") as output:
        json.dump(
            envelope,
            output,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        )
  '';

  issueFixture = pkgs.runCommand "attune-localization-issues-${builtins.substring 0 12 issueRevision}.json" {} ''
    ${issueProjector} ${issueDataset} "$out"
  '';

  sourceSuffixes = [ ".ts" ".tsx" ".js" ".jsx" ".mts" ".cts" ".mjs" ".cjs" ];
  hasSuffix = suffix: value:
    let suffixLength = builtins.stringLength suffix; valueLength = builtins.stringLength value;
    in valueLength >= suffixLength
       && builtins.substring (valueLength - suffixLength) suffixLength value == suffix;
  readSources = relative: directory:
    let entries = builtins.readDir directory;
    in builtins.concatLists (map (name:
      let kind = entries.${name};
          path = if relative == "" then name else "${relative}/${name}";
          child = directory + "/${name}";
      in if kind == "directory" then readSources path child
         else if kind == "regular" && builtins.any (suffix: hasSuffix suffix path) sourceSuffixes
              then [{ inherit path; file = child; }]
              else []) (builtins.attrNames entries));

  selected0 = builtins.elemAt cases caseIndex;
  snapshot = builtins.fetchTarball {
    url = "https://github.com/${selected0.repository}/archive/${selected0.baseCommit}.tar.gz";
    inherit (selected0) sha256;
  };
  selected = builtins.removeAttrs selected0 [ "sha256" ];
in
if issuesOnly then issueFixture else
  builtins.toJSON (selected // {
    inherit issueFixture issueRevision snapshot;
    sources = readSources "" snapshot;
  })
