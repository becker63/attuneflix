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
          gritRevision = "c80b3026471b229f41b279c3eb0c162dcdacfdb1";
          gritSource = pkgs.fetchFromGitHub {
            owner = "getgrit";
            repo = "gritql";
            rev = gritRevision;
            hash = "sha256-uMMDDS2+lH2//7pvyPH4IpUDpZB61UxODxSCi3E00VQ=";
          };
          nativeRustSource = pkgs.lib.fileset.toSource {
            root = ./native/grit;
            fileset = pkgs.lib.fileset.unions [
              ./native/grit/Cargo.toml
              ./native/grit/Cargo.lock
              ./native/grit/lib.rs
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
            resources="$TMPDIR/resources/attune/grit/programs"
            mkdir -p "$generated" "$classes" "$java_src" "$resources" "$out/share/java"
            cp ${./native/grit/AttuneGritNative.java} "$java_src/AttuneGritNative.java"
            cp ${./native/grit/AttuneGrit.java} "$java_src/AttuneGrit.java"
            cp ${./native/grit/defines.grit} "$resources/defines.grit"
            cp ${./native/grit/imports.grit} "$resources/imports.grit"
            cp ${./native/grit/calls.grit} "$resources/calls.grit"

            jextract \
              -I "$(clang -print-resource-dir)/include" \
              -I ${pkgs.glibc.dev}/include \
              --target-package attune.grit.ffi \
              --header-class-name AttuneGritAbi \
              --include-function attune_grit_run \
              --include-function attune_grit_buffer_free \
              --library ":${attuneGritNative}/lib/libattune_grit_abi.so" \
              --output "$generated" \
              ${./native/grit/attune_grit.h}

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
              -cp ${hoverProvider}/share/java/attuneflix-hover.jar:${flixJar} \
              ca.uwaterloo.flix.Main "$@"
          '';
        in {
          attune-grit-native = attuneGritNative;
          attune-grit-jar = attuneGritJar;
          flix = flixJdk25;
          flix-hover-provider = hoverProvider;
          libc-dev = pkgs.glibc.dev;
          default = flixJdk25;
        });

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          flixJdk25 = self.packages.${system}.flix;
        in {
          default = pkgs.mkShell {
            packages = [
              pkgs.cargo
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
