{
  description = "AttuneFlix: a small native Flix explanation of Attune Radii";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          flixJar = "${pkgs.flix}/share/java/flix/flix.jar";
          nixComponents = pkgs.nixVersions.nixComponents_2_34;
          nixUtilC = nixComponents."nix-util-c";
          nixStoreC = nixComponents."nix-store-c";
          nixExprC = nixComponents."nix-expr-c";
          nixFetchersC = nixComponents."nix-fetchers-c";
          nixFlakeC = nixComponents."nix-flake-c";
          nixUtilCDev = pkgs.lib.getDev nixUtilC;
          nixStoreCDev = pkgs.lib.getDev nixStoreC;
          nixExprCDev = pkgs.lib.getDev nixExprC;
          nixFetchersCDev = pkgs.lib.getDev nixFetchersC;
          nixFlakeCDev = pkgs.lib.getDev nixFlakeC;
          nixUtilCLib = pkgs.lib.getLib nixUtilC;
          nixStoreCLib = pkgs.lib.getLib nixStoreC;
          nixExprCLib = pkgs.lib.getLib nixExprC;
          nixFetchersCLib = pkgs.lib.getLib nixFetchersC;
          nixFlakeCLib = pkgs.lib.getLib nixFlakeC;
          mavenArtifact = groupId: artifactId: version: hash:
            pkgs.fetchMavenArtifact { inherit groupId artifactId version hash; };
          langchainArtifacts = [
            (mavenArtifact "dev.langchain4j" "langchain4j-open-ai" "1.18.1" "sha256-IAFZZkfR9w/uirH89g1m7ScCbbAYdDZQU+x1c8k8P88=")
            (mavenArtifact "dev.langchain4j" "langchain4j-core" "1.18.1" "sha256-LQ1gVE11ez2F8mZx7Rrs6Aee/Ns8JVyMGelCYT2HYW8=")
            (mavenArtifact "dev.langchain4j" "langchain4j-http-client" "1.18.1" "sha256-yIxhrzzinObzTbtAk0to04YU31nf2ft5xmSfLrs7UUI=")
            (mavenArtifact "dev.langchain4j" "langchain4j-http-client-jdk" "1.18.1" "sha256-9u7LO19a8meJ7CvcnmVn0wf9BCq27I5mGj+Gophw1a0=")
            (mavenArtifact "org.slf4j" "slf4j-api" "2.0.18" "sha256-RFCP0VdlAGiMeQsZCs3Rb+xPjHmj4LkAr9cFA88FX1U=")
            (mavenArtifact "org.slf4j" "slf4j-nop" "2.0.18" "sha256-QOa+J9WD2IQYPKRmzSAgMRJpHyoHWmUOno1cLlGqX0k=")
            (mavenArtifact "org.jspecify" "jspecify" "1.0.0" "sha256-H61ua+dVd4Hk0zcp1Jrhzcj92m/kd7sMxozjUer9+6s=")
            (mavenArtifact "com.fasterxml.jackson.core" "jackson-annotations" "2.22" "sha256-Id21mIB9OlGodnBOuXnZKW4cam9Hqxgm/4jG1qEnotA=")
            (mavenArtifact "com.fasterxml.jackson.core" "jackson-core" "2.22.1" "sha256-lB/wKbzbk+g9IJzlFsGn+4u6wH0KL6Ei9b8ZSyzXtPQ=")
            (mavenArtifact "com.fasterxml.jackson.core" "jackson-databind" "2.22.1" "sha256-fc1+U77B9Wx60ni9HKCEC+vMWV1hzkTWqEOau3W5ZbI=")
            (mavenArtifact "com.knuddels" "jtokkit" "1.1.0" "sha256-FQHOAlmriXxnRsz6+h0gis1AT7F+GsYuFXFy8meLEYM=")
          ];
          gritRevision = "c80b3026471b229f41b279c3eb0c162dcdacfdb1";
          gritSource = pkgs.fetchFromGitHub {
            owner = "getgrit";
            repo = "gritql";
            rev = gritRevision;
            hash = "sha256-uMMDDS2+lH2//7pvyPH4IpUDpZB61UxODxSCi3E00VQ=";
          };
          nativeRustSource = pkgs.lib.fileset.toSource {
            root = ./src/native/grit;
            fileset = pkgs.lib.fileset.unions [
              ./src/native/grit/Cargo.toml
              ./src/native/grit/Cargo.lock
              ./src/native/grit/lib.rs
            ];
          };
          gritCargoDepsRaw = pkgs.rustPlatform.fetchCargoVendor {
            src = nativeRustSource;
            hash = "sha256-OPVmq2VwpnLFNe02pug6+yUYCTB3c9vRXRIiS7sQ0Aw=";
          };
          # Project Marzano's coarse native parser cfg onto the two selected
          # parser crates, then restore node-type JSON referenced outside its
          # Cargo package. Both transformations are pinned to gritRevision.
          gritCargoDeps = pkgs.runCommand "attune-grit-cargo-deps" {} ''
            cp -R ${gritCargoDepsRaw} "$out"
            chmod -R u+w "$out"

            language="$out/source-git-0/marzano-language-0.1.0/src"
            substituteInPlace "$language/javascript.rs" \
              --replace-fail '#[cfg(not(feature = "builtin-parser"))]' '#[cfg(not(feature = "tree-sitter-javascript"))]' \
              --replace-fail '#[cfg(feature = "builtin-parser")]' '#[cfg(feature = "tree-sitter-javascript")]'
            for module in tsx.rs typescript.rs; do
              substituteInPlace "$language/$module" \
                --replace-fail '#[cfg(not(feature = "builtin-parser"))]' '#[cfg(not(feature = "tree-sitter-typescript"))]' \
                --replace-fail '#[cfg(feature = "builtin-parser")]' '#[cfg(feature = "tree-sitter-typescript")]'
            done

            mkdir -p "$out/resources"
            cp -R ${gritSource}/resources/node-types "$out/resources/node-types"
          '';
          attuneGritNative = pkgs.rustPlatform.buildRustPackage {
            pname = "attune-grit-abi";
            version = "0.1.0";
            src = nativeRustSource;
            cargoDeps = gritCargoDeps;
            nativeBuildInputs = [ pkgs.rustfmt ];
            preCheck = "cargo fmt -- --check";
            doCheck = true;
          };
          attuneGritJar = pkgs.runCommand "attune-grit-jar" {
            nativeBuildInputs = [ pkgs.clang pkgs.jdk25 pkgs.jextract ];
          } ''
            generated="$TMPDIR/jextract"
            classes="$TMPDIR/classes"
            java_src="$TMPDIR/java"
            resources="$TMPDIR/resources/grit"
            mkdir -p "$generated" "$classes" "$java_src" "$resources" "$out/share/java"
            cp ${./src/native/grit/AttuneGritNative.java} "$java_src/AttuneGritNative.java"
            cp ${./src/native/grit/AttuneGrit.java} "$java_src/AttuneGrit.java"
            for relation in defines imports calls; do
              mkdir -p "$resources/$relation"
              for dialect in javascript jsx typescript tsx; do
                cp ${./grit}/$relation/$dialect.grit "$resources/$relation/$dialect.grit"
              done
            done

            jextract \
              -I "$(clang -print-resource-dir)/include" \
              -I ${pkgs.glibc.dev}/include \
              --target-package attune.grit.ffi \
              --header-class-name AttuneGritAbi \
              --include-function attune_grit_run \
              --include-function attune_grit_buffer_free \
              --library ":${attuneGritNative}/lib/libattune_grit_abi.so" \
              --output "$generated" \
              ${./src/native/grit/attune_grit.h}

            javac \
              --release 23 \
              -d "$classes" \
              $(find "$generated" -name '*.java' -print) \
              "$java_src/AttuneGritNative.java"

            javac \
              --release 21 \
              -cp "$classes" \
              -d "$classes" \
              "$java_src/AttuneGrit.java"

            jar --create \
              --file "$out/share/java/attune-grit.jar" \
              -C "$classes" . \
              -C "$TMPDIR/resources" .
          '';
          attuneNixJar = pkgs.runCommand "attune-nix-jar" {
            nativeBuildInputs = [ pkgs.clang pkgs.jdk25 pkgs.jextract ];
          } ''
            generated="$TMPDIR/jextract"
            classes="$TMPDIR/classes"
            java_src="$TMPDIR/java"
            mkdir -p "$generated" "$classes" "$java_src" "$out/share/java"
            cp ${./src/native/nix/AttuneNix.java} "$java_src/AttuneNix.java"

            jextract \
              -I "$(clang -print-resource-dir)/include" \
              -I ${pkgs.glibc.dev}/include \
              -I ${nixUtilCDev}/include \
              -I ${nixStoreCDev}/include \
              -I ${nixExprCDev}/include \
              -I ${nixFetchersCDev}/include \
              -I ${nixFlakeCDev}/include \
              --target-package attune.nix.ffi \
              --header-class-name AttuneNixAbi \
              --include-typedef nix_get_string_callback \
              --include-constant NIX_TYPE_STRING \
              --include-function nix_c_context_create \
              --include-function nix_c_context_free \
              --include-function nix_libutil_init \
              --include-function nix_libstore_init \
              --include-function nix_libexpr_init \
              --include-function nix_store_open \
              --include-function nix_store_free \
              --include-function nix_store_real_path \
              --include-function nix_flake_settings_new \
              --include-function nix_flake_settings_free \
              --include-function nix_eval_state_builder_new \
              --include-function nix_eval_state_builder_free \
              --include-function nix_flake_settings_add_to_eval_state_builder \
              --include-function nix_eval_state_build \
              --include-function nix_state_free \
              --include-function nix_alloc_value \
              --include-function nix_value_decref \
              --include-function nix_expr_eval_from_string \
              --include-function nix_value_force \
              --include-function nix_get_type \
              --include-function nix_string_realise \
              --include-function nix_realised_string_get_buffer_start \
              --include-function nix_realised_string_get_buffer_size \
              --include-function nix_realised_string_get_store_path_count \
              --include-function nix_realised_string_get_store_path \
              --include-function nix_realised_string_free \
              --include-function nix_err_info_msg \
              -l :${nixUtilCLib}/lib/libnixutilc.so \
              -l :${nixStoreCLib}/lib/libnixstorec.so \
              -l :${nixExprCLib}/lib/libnixexprc.so \
              -l :${nixFetchersCLib}/lib/libnixfetchersc.so \
              -l :${nixFlakeCLib}/lib/libnixflakec.so \
              --output "$generated" \
              ${./src/native/nix/attune_nix.h}

            javac \
              --release 23 \
              -d "$classes" \
              $(find "$generated" -name '*.java' -print) \
              "$java_src/AttuneNix.java"

            jar --create \
              --file "$out/share/java/attune-nix.jar" \
              -C "$classes" .
          '';
          attuneInferenceJar = pkgs.stdenvNoCC.mkDerivation {
            pname = "attune-inference-jar";
            version = "0.1.0";
            dontUnpack = true;
            nativeBuildInputs = [ pkgs.jdk25 pkgs.setJavaClassPath pkgs.stripJavaArchivesHook ];
            buildInputs = langchainArtifacts;
            buildPhase = ''
              runHook preBuild
              mkdir -p classes source
              cp ${./src/native/inference/AttuneEmbed.java} source/AttuneEmbed.java
              cp ${./src/native/inference/AttuneDecision.java} source/AttuneDecision.java
              javac --release 21 -cp "$CLASSPATH" -d classes source/*.java
              runHook postBuild
            '';
            installPhase = ''
              runHook preInstall
              mkdir -p bundle "$out/share/java"
              old_ifs="$IFS"
              IFS=:
              for dependency in $CLASSPATH; do
                (cd bundle && jar --extract --file "$dependency")
              done
              IFS="$old_ifs"
              rm -f bundle/META-INF/MANIFEST.MF bundle/META-INF/*.SF bundle/META-INF/*.RSA bundle/META-INF/*.DSA
              cp -R classes/. bundle/
              jar --create --file "$out/share/java/attune-inference.jar" -C bundle .
              runHook postInstall
            '';
            };
          attuneParquetJar = pkgs.maven.buildMavenPackage {
            pname = "attune-parquet";
            version = "0.1.0";
            src = ./src/native/parquet;
            mvnJdk = pkgs.jdk25;
            mvnHash = "sha256-3rahVXZqAoR7Qp7UeVvvrqyAcXxHj8aYRXGZnngUxVA=";
            installPhase = ''
              runHook preInstall
              mkdir -p "$out/share/java"
              install -Dm644 target/attune-parquet-0.1.0.jar \
                "$out/share/java/attune-parquet.jar"
              runHook postInstall
            '';
          };
          hoverProvider = pkgs.runCommand "attuneflix-hover-provider" {
            nativeBuildInputs = [ pkgs.jdk25 pkgs.scala_2_13 ];
          } ''
            export JAVA_HOME=${pkgs.jdk25}
            mkdir -p "$out/classes" "$out/share/java"
            scalac \
              -Xsource:3 \
              -release 21 \
              -classpath ${flixJar} \
              -d "$out/classes" \
              ${./zed/HoverProvider.scala}
            jar --create \
              --file "$out/share/java/attuneflix-hover.jar" \
              -C "$out/classes" .
            rm -r "$out/classes"
          '';
          flixJdk25 = pkgs.writeShellScriptBin "flix" ''
            exec ${pkgs.jdk25}/bin/java \
              --enable-native-access=ALL-UNNAMED \
              --add-opens=java.base/java.nio=ALL-UNNAMED \
              -cp ${hoverProvider}/share/java/attuneflix-hover.jar:${flixJar} \
              ca.uwaterloo.flix.Main "$@"
          '';
        in {
          attune-grit-native = attuneGritNative;
          attune-grit-jar = attuneGritJar;
          attune-nix-jar = attuneNixJar;
          attune-inference-jar = attuneInferenceJar;
          attune-parquet-jar = attuneParquetJar;
          flix = flixJdk25;
          flix-hover-provider = hoverProvider;
          libc-dev = pkgs.glibc.dev;
          default = flixJdk25;
        });

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          flixJdk25 = self.packages.${system}.flix;
          buildbuddyCredential = pkgs.writeShellScriptBin "attune-buildbuddy-credential" ''
            set -eu

            if [ "''${1:-}" != get ]; then
              echo "unsupported credential-helper command" >&2
              exit 1
            fi
            read -r _request || true

            workspace="''${ATTUNE_WORKSPACE:-$PWD}"
            if [ ! -f "$workspace/.env" ]; then
              echo "ignored workspace .env not found" >&2
              exit 1
            fi

            key=$(
              ${pkgs.gawk}/bin/awk '
                /^BUILDBUDDY_API_KEY=/ {
                  if (found) exit 2
                  sub(/^[^=]*=/, "")
                  print
                  found = 1
                }
                END { if (!found) exit 1 }
              ' "$workspace/.env"
            )
            case "$key" in
              ""|*[!A-Za-z0-9._~-]*)
                echo "BUILDBUDDY_API_KEY is missing or malformed" >&2
                exit 1
                ;;
            esac

            printf '{"headers":{"x-buildbuddy-api-key":["%s"]}}\n' "$key"
          '';
          bazel = pkgs.writeShellScriptBin "bazel" ''
            set -eu

            workspace="$PWD"
            while [ "$workspace" != / ] && [ ! -f "$workspace/MODULE.bazel" ]; do
              workspace="$(${pkgs.coreutils}/bin/dirname -- "$workspace")"
            done
            ${pkgs.coreutils}/bin/env -i \
              HOME="$HOME" \
              USER="''${USER:-unknown}" \
              ATTUNE_WORKSPACE="$workspace" \
              BAZELISK_SKIP_WRAPPER=true \
              USE_BAZEL_VERSION=8.6.0 \
              PATH=${pkgs.lib.makeBinPath [
                pkgs.bash
                pkgs.bazelisk
                pkgs.coreutils
                pkgs.findutils
                pkgs.gawk
                pkgs.gcc
                pkgs.git
                pkgs.gnugrep
                pkgs.gnused
                pkgs.which
              ]} \
              SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt \
              ${pkgs.bazelisk}/bin/bazelisk "$@" \
                --credential_helper=remote.buildbuddy.io=${buildbuddyCredential}/bin/attune-buildbuddy-credential
          '';
        in {
          default = pkgs.mkShell {
            packages = [
              pkgs.cargo
              bazel
              pkgs.bazel-buildtools
              pkgs.clang
              flixJdk25
              pkgs.jdk25
              pkgs.jextract
              pkgs.jujutsu
              pkgs.rustc
              pkgs.rustfmt
            ];
          };
        });
    };
}
