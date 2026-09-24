{
  description = "AttuneFlix developer shell; Bazel owns project derivation";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          # BuildBuddy authentication stays outside Bazel's declared action
          # inputs. The ignored .env value is returned only to the credential
          # request and is never exported into the client environment.
          buildbuddyCredential = pkgs.writeShellScriptBin
            "attune-buildbuddy-credential" ''
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

          # Bazel receives a small allowlisted client environment rather than
          # the caller's desktop, Nix shell, SSH agent, or provider secrets.
          bazel = pkgs.writeShellScriptBin "bazel" ''
            set -eu
            workspace="$PWD"
            while [ "$workspace" != / ] && [ ! -f "$workspace/MODULE.bazel" ]; do
              workspace="$(${pkgs.coreutils}/bin/dirname -- "$workspace")"
            done
            repin_environment=
            if [ "''${REPIN:-}" = 1 ]; then
              repin_environment=REPIN=1
            fi
            exec ${pkgs.coreutils}/bin/env -i \
              HOME="$HOME" \
              USER="''${USER:-unknown}" \
              ATTUNE_WORKSPACE="$workspace" \
              $repin_environment \
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
              bazel
              pkgs.bazel-buildtools
              pkgs.git
              pkgs.jq
              pkgs.jujutsu
              pkgs.util-linux
            ];
          };
        });
    };
}
