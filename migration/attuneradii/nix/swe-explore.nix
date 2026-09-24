let
  benchmarkRevision = "bdb0ae45d7c337d9e1dc3ebfe2a0af6bc7c1fbd9";
  benchmark = builtins.fetchurl {
    url = "https://huggingface.co/datasets/SWE-Explore-Bench/SWE-Explore-Bench/resolve/${benchmarkRevision}/bench.final.public.jsonl";
    sha256 = "sha256-3E8RTs7NC/uYc2HCauXiRARW4szLNq38ywnqU4WuwgI=";
  };

  cases = [
    {
      instanceId = "NodeBB__NodeBB-05f2236193f407cf8e2072757fbd6bb170bc13f0-vf2cf3cbd463b7ad942381f1c6d077626485a1e9e";
      repository = "NodeBB/NodeBB";
      baseCommit = "05f2236193f407cf8e2072757fbd6bb170bc13f0";
      dataset = "pro";
      language = "javascript";
      sha256 = "sha256-a+uZAA6W39RTD+bRSUQuAXIdW4xIEp9Ifbc+u2hJ1Yw=";
    }
    {
      instanceId = "NodeBB__NodeBB-0c81642997ea1d827dbd02c311db9d4976112cd4-vf2cf3cbd463b7ad942381f1c6d077626485a1e9e";
      repository = "NodeBB/NodeBB";
      baseCommit = "0c81642997ea1d827dbd02c311db9d4976112cd4";
      dataset = "pro";
      language = "javascript";
      sha256 = "sha256-8SRxeIZnfntaNYltQUFNmFxP1D+cLDnO4Z9wMtkrOdQ=";
    }
    {
      instanceId = "axios__axios-4731";
      repository = "axios/axios";
      baseCommit = "c30252f685e8f4326722de84923fcbc8cf557f06";
      dataset = "multilingual";
      language = "javascript";
      sha256 = "sha256-CKbfznOvFk//B1LhMFpw56rjAt6VmVDdmoiqI5kbJYA=";
    }
    {
      instanceId = "axios__axios-5085";
      repository = "axios/axios";
      baseCommit = "85740c3e7a1fa48346dfcbd4497f463ccb1c1b05";
      dataset = "multilingual";
      language = "javascript";
      sha256 = "sha256-vctNvIzOxiLLISk8oNyAXynOO/cMlxTORh9fKv++vSU=";
    }
    {
      instanceId = "babel__babel-13928";
      repository = "babel/babel";
      baseCommit = "5134505bf93013c5fa7df66704df8d04becb7f7d";
      dataset = "multilingual";
      language = "javascript";
      sha256 = "sha256-3QZeF4cjb/tESNz2hsvsKgKnLq+agI9DO2muMvewRbY=";
    }
    {
      instanceId = "element-hq__element-web-18c03daa865d3c5b10e52b669cd50be34c67b2e5-vnan";
      repository = "element-hq/element-web";
      baseCommit = "18c03daa865d3c5b10e52b669cd50be34c67b2e5";
      dataset = "pro";
      language = "typescript";
      sha256 = "sha256-B7vwNMa/AannW7Ur64lCigq22tGPKML39wLOp+q0hsE=";
    }
    {
      instanceId = "element-hq__element-web-33e8edb3d508d6eefb354819ca693b7accc695e7";
      repository = "element-hq/element-web";
      baseCommit = "33e8edb3d508d6eefb354819ca693b7accc695e7";
      dataset = "pro";
      language = "typescript";
      sha256 = "sha256-NXLvK75hxq6MOSf8o4gDLEsy6qgpLk8LlAivO+VSHNc=";
    }
    {
      instanceId = "facebook__docusaurus-10130";
      repository = "facebook/docusaurus";
      baseCommit = "02e38d8ccf7811af27a9c15ddbadf4d26cfc0eab";
      dataset = "multilingual";
      language = "typescript";
      sha256 = "sha256-dCHPXdaybqhWOVfgmAu2Gl/nu9F0oesELstJGpppTdg=";
    }
    {
      instanceId = "facebook__docusaurus-10309";
      repository = "facebook/docusaurus";
      baseCommit = "5e9e1d051b2217b95498ecbc10f7e33f64e7a4d3";
      dataset = "multilingual";
      language = "typescript";
      sha256 = "sha256-9hSBYJgBswUS7UPxsmBimV4uwPro9y77FgZs4SBe1A4=";
    }
    {
      instanceId = "facebook__docusaurus-9897";
      repository = "facebook/docusaurus";
      baseCommit = "0589b1475d56b0b541348aa56f201ec7c56c56d5";
      dataset = "multilingual";
      language = "typescript";
      sha256 = "sha256-0BMXY7VYiN5eqdFlowKKmnw/2yBjA1dUU5fHu/traRU=";
    }
    {
      instanceId = "immutable-js__immutable-js-2005";
      repository = "immutable-js/immutable-js";
      baseCommit = "77434b3cbbc8ee21206f4cc6965e1c9b09cc92b6";
      dataset = "multilingual";
      language = "javascript";
      sha256 = "sha256-JjHdUV7gG1RbEITAyvEcjMhkukAKr6TqHDzS/vvRXVM=";
    }
    {
      instanceId = "immutable-js__immutable-js-2006";
      repository = "immutable-js/immutable-js";
      baseCommit = "493afba6ec17d9c999dc5a15ac80c71c6bdba1c3";
      dataset = "multilingual";
      language = "javascript";
      sha256 = "sha256-+o+VpPsg87kZxKKQN5H8ZZYsObE32fVOsKaqAdHdD1s=";
    }
    {
      instanceId = "mrdoob__three.js-26589";
      repository = "mrdoob/three.js";
      baseCommit = "8d9f8d50b923d5f8a673590ae138bc5d86a3a256";
      dataset = "multilingual";
      language = "javascript";
      sha256 = "sha256-oVFlqWonhIgt7qNLyGeLz0Yh8vMZd8z23tYbDqHNO+U=";
    }
    {
      instanceId = "mrdoob__three.js-27395";
      repository = "mrdoob/three.js";
      baseCommit = "b99b3fd955864f534b1e2649518112f7e50fef21";
      dataset = "multilingual";
      language = "javascript";
      sha256 = "sha256-f7sm1IWVOSoDKVC+aoZ6bnstRgaIkoXOzMD1DLTi2Kc=";
    }
    {
      instanceId = "preactjs__preact-2757";
      repository = "preactjs/preact";
      baseCommit = "b17a932342bfdeeaf1dc0fbe4f436c83e258d6c8";
      dataset = "multilingual";
      language = "javascript";
      sha256 = "sha256-HmkVYxjf8vDrJoXITFTT/plQHfVuzmvkQ+C1KH10oMY=";
    }
    {
      instanceId = "preactjs__preact-2896";
      repository = "preactjs/preact";
      baseCommit = "a9f7e676dc03b5008b8483e0937fc27c1af8287f";
      dataset = "multilingual";
      language = "javascript";
      sha256 = "sha256-/O+JX9+hC8amzlglyN290xWgIjcxRFKAVEjpdJAqcOI=";
    }
    {
      instanceId = "preactjs__preact-3010";
      repository = "preactjs/preact";
      baseCommit = "c12331064f4ea967641cd5e419204422af050fbb";
      dataset = "multilingual";
      language = "javascript";
      sha256 = "sha256-+DRJo2YJDF1ilekspdwUso4APxiNwsDBYO+ACjIY4q0=";
    }
    {
      instanceId = "preactjs__preact-3454";
      repository = "preactjs/preact";
      baseCommit = "00c8d1ff1498084c15408cf0014d4c7facdb5dd7";
      dataset = "multilingual";
      language = "javascript";
      sha256 = "sha256-TWIo5VCWFWjYZWszCSt0igc6SQ/S7GLu2aadQG/2whI=";
    }
    {
      instanceId = "preactjs__preact-3562";
      repository = "preactjs/preact";
      baseCommit = "0b9a9275b47e446106e6e97c78011896f7db2a61";
      dataset = "multilingual";
      language = "javascript";
      sha256 = "sha256-gVUPzopV1A+oMddlqEQQ0sKExYkk5FtryVAEFqpbolE=";
    }
    {
      instanceId = "preactjs__preact-3689";
      repository = "preactjs/preact";
      baseCommit = "9457b221fdacd1052ffdb385918e1bab4b10e833";
      dataset = "multilingual";
      language = "javascript";
      sha256 = "sha256-e22j7a1OMlipwlrsaiE5diWZkxAdrLZXNbLR+7J4ylY=";
    }
    {
      instanceId = "preactjs__preact-3739";
      repository = "preactjs/preact";
      baseCommit = "2cafedee2ddf7c73795e887ef1970df4be2bca90";
      dataset = "multilingual";
      language = "javascript";
      sha256 = "sha256-LeULMvUicqbJ9gWIqIqBVIaLu0QauRTImHcooqSV0N4=";
    }
    {
      instanceId = "preactjs__preact-3763";
      repository = "preactjs/preact";
      baseCommit = "e968a5a4000dfa9bec7e8d7b26543b23def6d29d";
      dataset = "multilingual";
      language = "javascript";
      sha256 = "sha256-o8J9m2+EbQz2jCPxJtCf/TMF15AJ/7jSO5Ax7pgo+VQ=";
    }
    {
      instanceId = "preactjs__preact-4152";
      repository = "preactjs/preact";
      baseCommit = "9c5a82efcc3dcbd0035c694817a3022d81264687";
      dataset = "multilingual";
      language = "javascript";
      sha256 = "sha256-1Wma7pOcpet/9zeqT5ntJffyDYyc14Z7xchSk4nc1/Y=";
    }
    {
      instanceId = "preactjs__preact-4182";
      repository = "preactjs/preact";
      baseCommit = "66cb6a78776b263a2fe4d1283426e699961095d2";
      dataset = "multilingual";
      language = "javascript";
      sha256 = "sha256-ft3mmKq6MgcppzzY9LW6BUGhQOhLzaZuauZojAGikU0=";
    }
    {
      instanceId = "preactjs__preact-4436";
      repository = "preactjs/preact";
      baseCommit = "db0f4f2e7a2338ea40050f623f05505a798fc1a4";
      dataset = "multilingual";
      language = "javascript";
      sha256 = "sha256-7NTAm383x5DxSx47QwwVM1/nN1VKFt8E/FqzKwRizLo=";
    }
    {
      instanceId = "protonmail__webclients-01b519cd49e6a24d9a05d2eb97f54e420740072e";
      repository = "protonmail/webclients";
      baseCommit = "01b519cd49e6a24d9a05d2eb97f54e420740072e";
      dataset = "pro";
      language = "typescript";
      sha256 = "sha256-KvRGrQ1gfrLFeZdqZtI+lJB2DFxsnhTUkljvaDkqqB0=";
    }
    {
      instanceId = "protonmail__webclients-09fcf0dbdb87fa4f4a27700800ee4a3caed8b413";
      repository = "protonmail/webclients";
      baseCommit = "09fcf0dbdb87fa4f4a27700800ee4a3caed8b413";
      dataset = "pro";
      language = "typescript";
      sha256 = "sha256-178ngcqVVKCOGDITgnjZFONmgi4t3sYICz94fzrULkU=";
    }
    {
      instanceId = "tutao__tutanota-1e516e989b3c0221f4af6b297d9c0e4c43e4adc3-vbc0d9ba8f0071fbe982809910959a6ff8884dbbf";
      repository = "tutao/tutanota";
      baseCommit = "1e516e989b3c0221f4af6b297d9c0e4c43e4adc3";
      dataset = "pro";
      language = "typescript";
      sha256 = "sha256-tRZMO9vFgs9Nh/0lz7QMSYmq72+YtBZmOjMfxPxCTj4=";
    }
    {
      instanceId = "vuejs__core-11589";
      repository = "vuejs/core";
      baseCommit = "3653bc0f45d6fedf84e29b64ca52584359c383c0";
      dataset = "multilingual";
      language = "typescript";
      sha256 = "sha256-6yc1TUiKmnbEWDZbqH/v1OM6XOeV+b6ZQfV14KJ6GEY=";
    }
    {
      instanceId = "vuejs__core-11739";
      repository = "vuejs/core";
      baseCommit = "cb843e0be31f9e563ccfc30eca0c06f2a224b505";
      dataset = "multilingual";
      language = "typescript";
      sha256 = "sha256-7Fwwds+LUiLt+d3kLW/AwN8EaLE4PTLIMpYtQyN6Awo=";
    }
    {
      instanceId = "vuejs__core-11870";
      repository = "vuejs/core";
      baseCommit = "67d6596d40b1807b9cd8eb0d9282932ea77be3c0";
      dataset = "multilingual";
      language = "typescript";
      sha256 = "sha256-f+iO5e6ZRpBAhh+zyqZu0jCsZttkCI16oJsW/yjBizQ=";
    }
    {
      instanceId = "vuejs__core-11915";
      repository = "vuejs/core";
      baseCommit = "d0b513eb463f580e29378e43d112ff6859aa366e";
      dataset = "multilingual";
      language = "typescript";
      sha256 = "sha256-Az14sRMsokpeHrXNNKHjZXTkTVkHz6h4O40f51LnT8o=";
    }
  ];

  realise =
    case:
    builtins.removeAttrs case [ "sha256" ]
    // {
      snapshot = builtins.fetchTarball {
        url = "https://github.com/${case.repository}/archive/${case.baseCommit}.tar.gz";
        inherit (case) sha256;
      };
    };
in
builtins.toJSON {
  inherit
    benchmark
    benchmarkRevision
    ;
  cases = map realise cases;
}
