{ caseIndex ? 0 }:

let
  benchmarkRevision = "bdb0ae45d7c337d9e1dc3ebfe2a0af6bc7c1fbd9";
  benchmark = builtins.fetchurl {
    url = "https://huggingface.co/datasets/SWE-Explore-Bench/SWE-Explore-Bench/resolve/${benchmarkRevision}/bench.final.public.jsonl";
    sha256 = "sha256-3E8RTs7NC/uYc2HCauXiRARW4szLNq38ywnqU4WuwgI=";
  };

  cases = [
    {
      instanceId = "mrdoob__three.js-26589";
      repository = "mrdoob/three.js";
      baseCommit = "8d9f8d50b923d5f8a673590ae138bc5d86a3a256";
      language = "javascript";
      sha256 = "sha256-oVFlqWonhIgt7qNLyGeLz0Yh8vMZd8z23tYbDqHNO+U=";
    }
    {
      instanceId = "preactjs__preact-2757";
      repository = "preactjs/preact";
      baseCommit = "b17a932342bfdeeaf1dc0fbe4f436c83e258d6c8";
      language = "javascript";
      sha256 = "sha256-HmkVYxjf8vDrJoXITFTT/plQHfVuzmvkQ+C1KH10oMY=";
    }
    {
      instanceId = "vuejs__core-11589";
      repository = "vuejs/core";
      baseCommit = "3653bc0f45d6fedf84e29b64ca52584359c383c0";
      language = "typescript";
      sha256 = "sha256-6yc1TUiKmnbEWDZbqH/v1OM6XOeV+b6ZQfV14KJ6GEY=";
    }
    {
      instanceId = "facebook__docusaurus-9897";
      repository = "facebook/docusaurus";
      baseCommit = "0589b1475d56b0b541348aa56f201ec7c56c56d5";
      language = "typescript";
      sha256 = "sha256-0BMXY7VYiN5eqdFlowKKmnw/2yBjA1dUU5fHu/traRU=";
    }
    {
      instanceId = "babel__babel-13928";
      repository = "babel/babel";
      baseCommit = "5134505bf93013c5fa7df66704df8d04becb7f7d";
      language = "javascript";
      sha256 = "sha256-3QZeF4cjb/tESNz2hsvsKgKnLq+agI9DO2muMvewRbY=";
      excludedPrefixes = [ "packages/babel-parser/test/fixtures" ];
    }
    {
      instanceId = "NodeBB__NodeBB-05f2236193f407cf8e2072757fbd6bb170bc13f0-vf2cf3cbd463b7ad942381f1c6d077626485a1e9e";
      repository = "NodeBB/NodeBB";
      baseCommit = "05f2236193f407cf8e2072757fbd6bb170bc13f0";
      language = "javascript";
      sha256 = "sha256-a+uZAA6W39RTD+bRSUQuAXIdW4xIEp9Ifbc+u2hJ1Yw=";
    }
    {
      instanceId = "element-hq__element-web-33e8edb3d508d6eefb354819ca693b7accc695e7";
      repository = "element-hq/element-web";
      baseCommit = "33e8edb3d508d6eefb354819ca693b7accc695e7";
      language = "typescript";
      sha256 = "sha256-NXLvK75hxq6MOSf8o4gDLEsy6qgpLk8LlAivO+VSHNc=";
    }
    {
      instanceId = "tutao__tutanota-1e516e989b3c0221f4af6b297d9c0e4c43e4adc3-vbc0d9ba8f0071fbe982809910959a6ff8884dbbf";
      repository = "tutao/tutanota";
      baseCommit = "1e516e989b3c0221f4af6b297d9c0e4c43e4adc3";
      language = "typescript";
      sha256 = "sha256-tRZMO9vFgs9Nh/0lz7QMSYmq72+YtBZmOjMfxPxCTj4=";
    }
    {
      instanceId = "protonmail__webclients-09fcf0dbdb87fa4f4a27700800ee4a3caed8b413";
      repository = "protonmail/webclients";
      baseCommit = "09fcf0dbdb87fa4f4a27700800ee4a3caed8b413";
      language = "typescript";
      sha256 = "sha256-178ngcqVVKCOGDITgnjZFONmgi4t3sYICz94fzrULkU=";
    }
    {
      instanceId = "immutable-js__immutable-js-2006";
      repository = "immutable-js/immutable-js";
      baseCommit = "493afba6ec17d9c999dc5a15ac80c71c6bdba1c3";
      language = "javascript";
      sha256 = "sha256-+o+VpPsg87kZxKKQN5H8ZZYsObE32fVOsKaqAdHdD1s=";
    }
    {
      instanceId = "axios__axios-4731";
      repository = "axios/axios";
      baseCommit = "c30252f685e8f4326722de84923fcbc8cf557f06";
      language = "javascript";
      sha256 = "sha256-CKbfznOvFk//B1LhMFpw56rjAt6VmVDdmoiqI5kbJYA=";
    }
  ];

  sourceSuffixes = [ ".ts" ".tsx" ".js" ".jsx" ".mts" ".cts" ".mjs" ".cjs" ];

  hasSuffix = suffix: value:
    let
      suffixLength = builtins.stringLength suffix;
      valueLength = builtins.stringLength value;
    in
      valueLength >= suffixLength
      && builtins.substring (valueLength - suffixLength) suffixLength value == suffix;

  excluded = prefixes: path:
    builtins.any (prefix: path == prefix || builtins.substring 0 (builtins.stringLength prefix + 1) path == "${prefix}/") prefixes;

  readSources = prefixes: relative: directory:
    let entries = builtins.readDir directory;
    in builtins.concatLists (map (name:
      let
        kind = entries.${name};
        path = if relative == "" then name else "${relative}/${name}";
        child = directory + "/${name}";
      in
        if excluded prefixes path then []
        else if kind == "directory" then readSources prefixes path child
        else if kind == "regular" && builtins.any (suffix: hasSuffix suffix path) sourceSuffixes then
          [{ inherit path; file = child; }]
        else []
    ) (builtins.attrNames entries));

  selected0 = builtins.elemAt cases caseIndex;
  snapshot = builtins.fetchTarball {
    url = "https://github.com/${selected0.repository}/archive/${selected0.baseCommit}.tar.gz";
    inherit (selected0) sha256;
  };
  prefixes = selected0.excludedPrefixes or [];
  selected = builtins.removeAttrs selected0 [ "sha256" "excludedPrefixes" ];
in
builtins.toJSON (selected // {
  inherit benchmark benchmarkRevision snapshot;
  sources = readSources prefixes "" snapshot;
})
