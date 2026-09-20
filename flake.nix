{
  description = "AttuneFlix: a small native Flix explanation of Attune Radii";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    crane.url = "github:ipetkov/crane";
  };

  outputs = { self, nixpkgs, crane }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          flixJar = "${pkgs.flix}/share/java/flix/flix.jar";
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
            ];
            ATTUNE_GLIBC_DEV = "${pkgs.glibc.dev}";
          };
        });
    };
}
