{ caseIndex ? 0 }:

let
  manifest = builtins.fromJSON
    (builtins.readFile ./experiments/swe-explore-js-ts-scale/MANIFEST.json);
  selected = builtins.elemAt manifest.cases caseIndex;

  # The URL names an exact commit. The realised Nix store path is retained as
  # the immutable acquisition result. No Git history or dependencies enter.
  snapshot = builtins.fetchTarball {
    url = "https://github.com/${selected.repository}/archive/${selected.base_revision}.tar.gz";
  };

  sourceSuffixes = [ ".ts" ".tsx" ".js" ".jsx" ".mts" ".cts" ".mjs" ".cjs" ];
  hasSuffix = suffix: value:
    let
      suffixLength = builtins.stringLength suffix;
      valueLength = builtins.stringLength value;
    in valueLength >= suffixLength
       && builtins.substring (valueLength - suffixLength) suffixLength value == suffix;
  readSources = relative: directory:
    let entries = builtins.readDir directory;
    in builtins.concatLists (map (name:
      let
        kind = entries.${name};
        path = if relative == "" then name else "${relative}/${name}";
        child = directory + "/${name}";
      in if kind == "directory" then readSources path child
         else if kind == "regular" && builtins.any (suffix: hasSuffix suffix path) sourceSuffixes
              then [{ inherit path; file = child; }]
              else []) (builtins.attrNames entries));
in
  builtins.toJSON (selected // {
    inherit snapshot;
    manifest_index = caseIndex;
    sources = readSources "" snapshot;
  })
