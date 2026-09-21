let
  benchmarkRevision = "bdb0ae45d7c337d9e1dc3ebfe2a0af6bc7c1fbd9";
  baseCommit = "c30252f685e8f4326722de84923fcbc8cf557f06";

  sourceSuffixes = [ ".ts" ".tsx" ".js" ".jsx" ".mts" ".cts" ".mjs" ".cjs" ];

  hasSuffix = suffix: value:
    let
      suffixLength = builtins.stringLength suffix;
      valueLength = builtins.stringLength value;
    in
      valueLength >= suffixLength
      && builtins.substring (valueLength - suffixLength) suffixLength value == suffix;

  isSource = path: builtins.any (suffix: hasSuffix suffix path) sourceSuffixes;

  readSources = relative: directory:
    let
      entries = builtins.readDir directory;
    in
      builtins.concatLists (map (name:
        let
          kind = entries.${name};
          path = if relative == "" then name else "${relative}/${name}";
          child = directory + "/${name}";
        in
          if kind == "directory" then
            readSources path child
          else if kind == "regular" && isSource path then
            [{ inherit path; file = child; }]
          else
            []
      ) (builtins.attrNames entries));

  benchmark = builtins.fetchurl {
    url = "https://huggingface.co/datasets/SWE-Explore-Bench/SWE-Explore-Bench/resolve/${benchmarkRevision}/bench.final.public.jsonl";
    sha256 = "sha256-3E8RTs7NC/uYc2HCauXiRARW4szLNq38ywnqU4WuwgI=";
  };

  snapshot = builtins.fetchTarball {
    url = "https://github.com/axios/axios/archive/${baseCommit}.tar.gz";
    sha256 = "sha256-CKbfznOvFk//B1LhMFpw56rjAt6VmVDdmoiqI5kbJYA=";
  };
in
builtins.toJSON {
  inherit benchmark benchmarkRevision baseCommit snapshot;
  instanceId = "axios__axios-4731";
  language = "javascript";
  repository = "axios/axios";
  sources = readSources "" snapshot;
}
